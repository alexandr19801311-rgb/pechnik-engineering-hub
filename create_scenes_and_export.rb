# Encoding: UTF-8
# ==============================================================================
# ПРОЕКТ 4020-НМ / v76.6 -- СКЕТЧАП-ЯДРО ПЛАТФОРМЫ (ПОБЛОЧНАЯ СБОРКА)
# Файл: create_scenes_and_export.rb — ЧАСТЬ 1: ОРГАНИЗАЦИЯ И ЭКСПОРТ PNG (SKETCHUP 2025)
# ==============================================================================

require 'fileutils'
require 'sketchup'

module PechnikEngineeringHub
  class SceneExporter
    class << self

      def ensure_project_folders
        base_path = "D:/pechnik-engineering-hub"
        ["#{base_path}/00_my_scripts", "#{base_path}/01_scenes", "#{base_path}/02_specifications"].each do |folder|
          FileUtils.mkdir_p(folder) unless Dir.exist?(folder)
        end
      end

      def export_scenes_to_png(mode = :iso)
        ensure_project_folders
        model = Sketchup.active_model
        view = model.active_view
        layers = model.layers
        scenes = model.pages

        puts "Шаг 1: Полная очистка старых сцен во избежание конфликтов..."
        scenes.to_a.reverse_each { |scene| scenes.erase(scene) }
        
        render_page = scenes.add("Pechnik_Render_A")
        scenes.selected_page = render_page
        model.options["PageOptions"]["TransitionTime"] = 0.0

        # Нативная конфигурация ракурсов под новый графический движок Overdrive в SketchUp 2025
        case mode
        when :top
          sub_folder = "top_view"
          view.camera.perspective = false
          Sketchup.send_action("viewTop:")
        when :iso
          sub_folder = "iso_view"
          view.camera.perspective = true
          Sketchup.send_action("viewIso:")
        else
          sub_folder = "custom_view"
        end

        # Даем микропаузу движку 2025 для гарантированного разворота камеры
        sleep(0.1)

        puts "Автоматическое центрирование и фиксация камеры..."
        view.zoom_extents
        fixed_camera = view.camera
        
        output_dir = File.join("D:/pechnik-engineering-hub/01_scenes/", sub_folder)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        options = {}
        options.store(:width, 2400)
        options.store(:height, 1800)
        options.store(:transparent, true)
        options.store(:antialias, true)
        options.store(:compression, 9)
        options.store(:show_summary, false)

        puts "ПАКЕТНЫЙ ВЫВОД ПОРЯДОВОК — Режим: #{mode.to_s.upcase}"
        model.start_operation("Пакетный экспорт", true)

        (1..54).each do |current_row|
          layers.each do |layer|
            layer_name = layer.name.downcase
            if layer_name =~ /row_(\d+)/ || layer_name =~ /ряд_(\d+)/
              row_num = $1.to_i
              if mode == :top
                layer.visible = (row_num == current_row)
              else
                layer.visible = (row_num <= current_row)
              end
            elsif layer_name.start_with?("finish_")
              layer.visible = (current_row == 54)
            elsif layer_name.start_with?("palette_") || layer_name == "untagged"
              layer.visible = true
            end
          end

          view.camera = fixed_camera
          render_page.update(1)
          view.invalidate
          view.refresh
          
          sleep(0.05)

          options.store(:filename, File.join(output_dir, "row_#{sprintf('%02d', current_row)}.png"))
          view.write_image(options)
          
          puts "[#{sprintf('%02d', current_row)}/54] Кадр зафиксирован движком Overdrive"
        end

        model.commit_operation
        puts "[+] Пакетный экспорт завершен"
      end

      # ========================================================================
      # ЧАСТЬ 2: ИНИЦИАЛИЗАЦИЯ И СКВОЗНОЙ АНАЛИЗ ГЕОМЕТРИИ МОДЕЛИ v76.6
      # ========================================================================
      def export_materials_specification
        ensure_project_folders
        model = Sketchup.active_model
        
        brick_data = Hash.new(0)
        hardware_data = Hash.new(0)
        @total_finish_table_area = 0.0
        
        # Матрица готова к приему данных литья
        row_matrix = Array.new(54) { { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0, "casting" => "Нет" } }

        scan_spec = ->(instance, current_row = "Вне рядов", transform = Geom::Transformation.new) do
          layer_name = instance.layer.name
          
          if layer_name =~ /row_(\d{1,2})/ || layer_name =~ /Ряд_(\d{1,2})/
            current_row = sprintf("row_%02d", $1.to_i)
          end

          combined_transform = transform * (instance.respond_to?(:transformation) ? instance.transformation : Geom::Transformation.new)

          if instance.respond_to?(:definition)
            def_name = instance.definition.name
            clean_name = def_name.gsub(/#\d+/, '').strip
            clean_name_down = clean_name.downcase

            # 1. Геометрический обсчет площади столешниц
            if clean_name_down.include?('finish_table') || clean_name_down.include?('столешниц')
              instance.definition.entities.each do |e|
                if e.is_a?(Sketchup::Face)
                  global_normal = e.normal.transform(combined_transform)
                  if global_normal.z > 0.99
                    mat_arr = combined_transform.to_a
                    p_sx = Math.sqrt(mat_arr.at(0)**2 + mat_arr.at(1)**2 + mat_arr.at(2)**2)
                    p_sy = Math.sqrt(mat_arr.at(4)**2 + mat_arr.at(5)**2 + mat_arr.at(6)**2)
                    @total_finish_table_area += (e.area * p_sx * p_sy) * 0.00064516
                  end
                end
              end

            # 2. Фильтрация и парсинг кирпичей
            elsif clean_name_down.include?('кирпич') || clean_name_down.include?('palette_brick') || clean_name_down.include?('шб') || clean_name =~ /^(LF|SP|SH8)/
              if clean_name =~ /^LF/ || clean_name_down.include?('лицевой') || clean_name_down.include?('облицовка')
                mat_code = "LF"
              elsif clean_name =~ /^SH8/ || clean_name_down.include?('шб') || clean_name_down.include?('шамот')
                mat_code = "SH8"
              else
                mat_code = "SP"
              end

              if clean_name =~ /-(\d+)-/
                length_mm = $1.to_i
              else
                length_mm = (instance.definition.bounds.width.to_mm).round
              end

              final_sku = "#{mat_code}-#{length_mm}-ST"
              brick_data.store([current_row, final_sku], brick_data.fetch([current_row, final_sku], 0) + 1)
            # 3. Литье и фурнитура (Прямая порядовая привязка по тегу объекта)
            else
              unless clean_name_down.include?('temp') || clean_name_down.include?('init') || clean_name.empty? || clean_name_down == 'group' || clean_name_down == 'группа'
                hardware_data.store(clean_name, hardware_data.fetch(clean_name, 0) + 1)
                
                # Читаем тег (слой) элемента прямо во время обхода геометрии
                obj_layer = instance.layer.name.downcase
                if obj_layer =~ /row_(\d+)/ || obj_layer =~ /ряд_(\d+)/
                  target_idx = $1.to_i - 1
                  if target_idx.between?(0, 53)
                    old_cast = row_matrix.at(target_idx).fetch("casting")
                    new_cast = (old_cast == "Нет") ? "#{clean_name} (1 шт)" : "#{old_cast}, #{clean_name} (1 шт)"
                    row_matrix.at(target_idx).store("casting", new_cast)
                  end
                end
              end
            end
          end

          entities_to_parse = instance.respond_to?(:definition) ? instance.definition.entities : (instance.respond_to?(:entities) ? instance.entities : nil)
          if entities_to_parse
            entities_to_parse.each do |child|
              if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
                scan_spec.call(child, current_row, combined_transform)
              end
            end
          end
        end

        puts "Сканирование геометрии модели..."
        model.active_entities.each { |e| scan_spec.call(e) if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

        # ========================================================================
        # ЧАСТЬ 3: МАТЕМАТИЧЕСКАЯ АГРЕГАЦИЯ КИРПИЧНОЙ МАТРИЦЫ
        # ========================================================================
        output_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
        totals = Hash.new(0.0)

        brick_data.each do |key_pair, count|
          row_str = key_pair.at(0)
          sku     = key_pair.at(1)
          next unless row_str =~ /row_(\d+)/
          row_idx = $1.to_i - 1
          next unless row_idx.between?(0, 53)

          sku_parts = sku.split('-')
          mat_type  = sku_parts.at(0)
          length    = sku_parts.at(1).to_i
          
          limit = (mat_type == "SH8") ? 124 : 120
          weight = (length > limit) ? 1.0 : 0.5
          
          row_matrix.at(row_idx).store(mat_type, row_matrix.at(row_idx).fetch(mat_type) + (count * weight))
        end
        # ========================================================================
        # ЧАСТЬ 4: ФИЗИЧЕСКАЯ ЗАПИСЬ ОТЧЕТА НА ДИСК D: И ЗАКРЫТИЕ СТРУКТУРЫ
        # ========================================================================
        File.open(output_path, "w:UTF-8") do |file|
          file.puts "====================================================================================="
          file.puts " TOTAL PRODUCTION SPECIFICATION REPORT (COMPONENT SYSTEM v76.6) "
          file.puts "====================================================================================="
          file.puts sprintf(" %-14s | %-25s | %-15s | %-10s", "PRODUCTION ROW", "FACTORY SKU / ELEMENT ID", "FORMAT TYPE", "QTY (PCS)")
          file.puts "-------------------------------------------------------------------------------------"
          
          brick_data.keys.sort.each do |key_arr|
            row_id = key_arr.at(0)
            sku_id = key_arr.at(1)
            count  = brick_data.fetch(key_arr)
            sku_parts = sku_id.split('-')
            mat_type  = sku_parts.at(0)
            length    = sku_parts.at(1).to_i
            limit = (mat_type == "SH8") ? 124 : 120
            type_label = (length > limit) ? "FULL (1.0)" : "HALF (0.5)"
            file.puts sprintf(" %-14s | %-25s | %-15s | %-10d", row_id, sku_id, type_label, count)
            current_total = totals.fetch(mat_type, 0.0)
            added_weight  = (length > limit) ? count : (count * 0.5)
            totals.store(mat_type, current_total + added_weight)
          end

          file.puts "\n====================================================================================="
          file.puts " МАТРИЦА ПОРЯДОВОГО РАСХОДА КИРПИЧА И ЛИТЬЯ (v76.6) "
          file.puts "====================================================================================="
          file.puts " Номер ряда   | Фасад (шт)     | Строит (шт)    | Шамот (шт)     | Литье"
          file.puts "-------------------------------------------------------------------------------------"
          
          row_matrix.each_with_index do |data, idx|
            row_title = sprintf("Ряд %02d", idx + 1)
            file.puts sprintf(" %-12s | %-14.1f | %-14.1f | %-14.1f | Литье: %s", 
                            row_title, data.fetch("LF"), data.fetch("SP"), data.fetch("SH8"), data.fetch("casting"))
          end

          unless hardware_data.empty?
            file.puts "\n-------------------------------------------------------------------------------------"
            file.puts " ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ (ПОШТУЧНЫЙ УЧЕТ)"
            file.puts "-------------------------------------------------------------------------------------"
            hardware_data.keys.sort.each do |hw_name|
              file.puts sprintf(" %-50s | %-30d", hw_name, hardware_data.fetch(hw_name))
            end
          end

          total_red = totals.fetch("SP", 0.0) + totals.fetch("LF", 0.0)
          total_sh8 = totals.fetch("SH8", 0.0)
          mix_red_kg = (total_red * 1.1).round(1)
          mix_sh8_kg = (total_sh8 * 0.6).round(1)

          file.puts "\n====================================================================================="
          file.puts " ИТОГОВЫЙ СВОДНЫЙ РАСХОД МАТЕРИАЛОВ "
          file.puts "====================================================================================="
          file.puts sprintf(" %-45s : %12s pcs", "LF (Кирпич 1нф лицевой)", totals.fetch("LF", 0.0).to_i.to_s)
          file.puts sprintf(" %-45s : %12s pcs", "SP (Кирпич 1нф строительный полнотелый)", totals.fetch("SP", 0.0).to_i.to_s)
          file.puts sprintf(" %-45s : %12s pcs", "SH8 (Кирпич шамотный ШБ-8)", totals.fetch("SH8", 0.0).to_i.to_s)
          if @total_finish_table_area > 0.0
            file.puts sprintf(" %-45s : %12.2f m2", "FINISH-TABLE (Керамогранит столешницы)", @total_finish_table_area)
          end
          file.puts "-------------------------------------------------------------------------------------"
          file.puts " ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ "
          file.puts "-------------------------------------------------------------------------------------"
          file.puts sprintf(" Глиняно-песчаная смесь (красный кирпич * 1.1 кг) : %10.1f кг", mix_red_kg)
          file.puts sprintf(" Огнеупорный мертель (шамотный кирпич * 0.6 кг) : %10.1f кг", mix_sh8_kg)
          file.puts "====================================================================================="
        end

        UI.messagebox("СМЕТНЫЙ СИНТЕЗ v76.6 ВЫПОЛНЕН успешно")
      end

    end # class << self
  end # class SceneExporter
end # module PechnikEngineeringHub
