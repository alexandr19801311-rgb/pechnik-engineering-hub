# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ — ПАКЕТНЫЙ ЭКСПОРТЕР И СМЕТНЫЙ КАЛЬКУЛЯТОР v77.75
# ЧАСТЬ 1 ИЗ 3: РЕКУРСИВНЫЙ ОБХОД МОДЕЛИ И ПОДСЧЕТ МАССЫ В ТОННАХ
# ==============================================================================

require 'fileutils'
require 'sketchup'

module PechnikEngineeringHub
  class SceneExporter

    WEIGHT_LF  = 3.7  
    WEIGHT_SP  = 3.5  
    WEIGHT_SH8 = 3.4  

    def self.ensure_project_folders
      base_path = "D:/pechnik-engineering-hub"
      ["#{base_path}/00_my_scripts", "#{base_path}/01_scenes", "#{base_path}/02_specifications"].each do |folder|
        FileUtils.mkdir_p(folder) unless Dir.exist?(folder)
      end
    end

    def self.calculate_and_export_all
      ensure_project_folders
      model = Sketchup.active_model
      model_title = model.title.empty? ? "Новый проект барбекю" : model.title

      totals = { lf: 0.0, sp: 0.0, sh8: 0.0, finish_table_area: 0.0 }
      iron_items = Hash.new(0)
      row_matrix = Array.new(54) { { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0, "casting" => "Нет" } }
      brick_data = Hash.new(0)

      scan_spec = ->(instance, current_row = "Вне рядов", transform = Geom::Transformation.new) do
        layer_name = instance.layer.name.upcase.strip
        
        if layer_name =~ /(?:ROW|РЯД)[_\s-]*(\d+)/
          current_row = sprintf("row_%02d", $1.to_i)
        elsif layer_name =~ /^\d+$/
          current_row = sprintf("row_%02d", layer_name.to_i)
        end

        combined_transform = transform * (instance.respond_to?(:transformation) ? instance.transformation : Geom::Transformation.new)

        if instance.respond_to?(:definition)
          clean_name = instance.definition.name.gsub(/#\d+/, '').strip
          clean_name_down = clean_name.downcase

          if clean_name_down.include?('finish_table') || clean_name_down.include?('столешниц') || clean_name_down.include?('керамогранит')
            instance.definition.entities.each do |e|
              if e.is_a?(Sketchup::Face) && e.normal.transform(combined_transform).z > 0.99
                mat_arr = combined_transform.to_a
                p_sx = Math.sqrt(mat_arr[0]**2 + mat_arr[1]**2 + mat_arr[2]**2)
                p_sy = Math.sqrt(mat_arr[4]**2 + mat_arr[5]**2 + mat_arr[6]**2)
                totals[:finish_table_area] += (e.area * p_sx * p_sy) * 0.00064516
              end
            end
          elsif clean_name_down.include?('кирпич') || clean_name_down.include?('palette_brick') || clean_name_down.include?('шб') || clean_name_down.include?('шамот') || clean_name =~ /^(LF|SP|SH8)/
            mat_code = (clean_name =~ /^LF/ || clean_name_down.include?('лицевой')) ? "LF" : ((clean_name =~ /^SH8|^ШБ/ || clean_name_down.include?('шамот')) ? "SH8" : "SP")
            length_mm = (clean_name =~ /-(\d+)-/) ? $1.to_i : (instance.definition.bounds.width.to_mm).round
            brick_data.store([current_row, "#{mat_code}-#{length_mm}-ST"], brick_data.fetch([current_row, "#{mat_code}-#{length_mm}-ST"], 0) + 1)
          else
            unless clean_name_down.include?('temp') || clean_name_down.include?('init') || clean_name.empty? || clean_name_down == 'group' || clean_name_down == 'группа'
              iron_items[clean_name] += 1
              if current_row =~ /row_(\d+)/
                target_idx = $1.to_i - 1
                if target_idx.between?(0, 53)
                  old_cast = row_matrix[target_idx]["casting"]
                  row_matrix[target_idx]["casting"] = (old_cast == "Нет") ? "#{clean_name} (1 шт)" : "#{old_cast}, #{clean_name} (1 шт)"
                end
              end
            end
          end
        end

        entities_to_parse = instance.respond_to?(:definition) ? instance.definition.entities : (instance.respond_to?(:entities) ? instance.entities : nil)
        if entities_to_parse
          entities_to_parse.each { |child| scan_spec.call(child, current_row, combined_transform) if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group) }
        end
      end

      model.active_entities.each { |e| scan_spec.call(e) if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

      brick_data.each do |key_pair, count|
        row_str, sku = key_pair[0], key_pair[1]
        next unless row_str =~ /row_(\d+)/
        row_idx = $1.to_i - 1
        next unless row_idx.between?(0, 53)
        sku_parts = sku.split('-')
        mat_type = sku_parts[0]
        length = sku_parts[1].to_i
        limit = (mat_type == "SH8") ? 124 : 120
        weight = (length > limit) ? 1.0 : 0.5
        row_matrix[row_idx][mat_type] = row_matrix[row_idx][mat_type] + (count * weight)
        totals[mat_type.downcase.to_sym] += (count * weight)
      end

      total_brick_weight = (totals[:lf] * WEIGHT_LF) + (totals[:sp] * WEIGHT_SP) + (totals[:sh8] * WEIGHT_SH8)
      total_tonnage = (total_brick_weight / 1000.0).round(2)

      write_specification_file(model_title, totals, iron_items, row_matrix, total_tonnage)
    end
    # ==============================================================================
    # ЧАСТЬ 2 ИЗ 3: СИСТЕМНЫЙ МЕТОД ГЕНЕРАЦИИ ТЕКСТОВОГО ОТЧЕТА НА ДИСКЕ D:
    # ==============================================================================
    def self.write_specification_file(model_title, totals, iron_items, row_matrix, total_tonnage)
      output_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"

      File.open(output_path, "w:UTF-8") do |file|
        # Передаем динамический маркер названия Способа А для HTML-сборщика
        file.puts "[MODEL_TITLE] : #{model_title}"
        file.puts "=" * 80
        file.puts " ИТОГОВЫЙ СВОДНЫЙ РАСХОД МАТЕРИАЛОВ "
        file.puts "=" * 80
        file.puts "Кирпич Лицевой LF : #{totals[:lf].to_i} шт"
        file.puts "Кирпич Строительный SP : #{totals[:sp].to_i} шт"
        file.puts "Кирпич Шамотный SH8 : #{totals[:sh8].to_i} шт"
        
        if totals[:finish_table_area] > 0.0
          file.puts "FINISH-TABLE (Керамогранит столешницы) : #{totals[:finish_table_area].round(2)} m2"
        end
        file.puts "РАСЧЕТНЫЙ ВЕС КИРПИЧНОЙ КЛАДКИ : #{total_tonnage} т"
        file.puts "\n"

        file.puts "=" * 80
        file.puts "ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ (ПОШТУЧНЫЙ УЧЕТ)"
        file.puts "=" * 80
        if iron_items.empty?
          file.puts "Нет зарегистрированного литья"
        else
          iron_items.keys.sort.each { |name| file.puts "#{name} | #{iron_items[name]}" }
        end
        file.puts "\n"

        file.puts "=" * 80
        file.puts "ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ"
        file.puts "=" * 80
        mix_red_kg = ((totals[:lf] + totals[:sp]) * 1.1).round(0)
        mix_sh8_kg = (totals[:sh8] * 0.6).round(0)
        file.puts "Глиняно-песчаная смесь (красный кирпич * 1.1 кг) : #{mix_red_kg} кг"
        file.puts "Огнеупорный мертель (шамотный кирпич * 0.6 кг) : #{mix_sh8_kg} кг"
        file.puts "\n"

        file.puts "=" * 80
        file.puts "МАТРИЦА ПОРЯДОВОГО РАСХОДА"
        file.puts "=" * 80
        file.puts " Номер ряда | Фасад (шт) | Строит (шт) | Шамот (шт) | Литье"
        file.puts "-" * 80
        row_matrix.each_with_index do |data, idx|
          file.puts sprintf("Ряд %02d | %-14.1f | %-14.1f | %-14.1f | Литье: %s",
                          idx + 1, data["LF"], data["SP"], data["SH8"], data["casting"])
        end

        file.puts "\n" \
                  "=====================================================================================\n" \
                  "TOTAL PRODUCTION SPECIFICATION\n" \
                  "====================================================================================="
        row_matrix.each_with_index do |data, idx|
          r = idx + 1
          file.puts "row_#{r} | LF-Brick | | #{data['LF'].to_i}" if data['LF'] > 0
          file.puts "row_#{r} | SP-Brick | | #{data['SP'].to_i}" if data['SP'] > 0
          file.puts "row_#{r} | SH8-Brick | | #{data['SH8'].to_i}" if data['SH8'] > 0
        end
      end

      UI.messagebox("СМЕТНЫЙ СИНТЕЗ ВЫПОЛНЕН УСПЕШНО!\nВес: #{total_tonnage} т\nСтолешницы: #{totals[:finish_table_area].round(2)} м²")
    end
    # ==============================================================================
    # ЧАСТЬ 3 ИЗ 3: ПАКЕТНЫЙ ГЕНЕРАТОР PNG-ПОРЯДОВОК И ЗАКРЫТИЕ КЛАССА
    # ==============================================================================
    def self.export_scenes_to_png(mode = :iso)
      ensure_project_folders
      model = Sketchup.active_model
      view = model.active_view
      layers = model.layers
      scenes = model.pages

      puts "Очистка рендер-кадров..."
      scenes.to_a.reverse_each { |scene| scenes.erase(scene) if scene.name.start_with?("Pechnik_") }
      
      render_page = scenes.add("Pechnik_Render_A")
      scenes.selected_page = render_page
      model.options["PageOptions"]["TransitionTime"] = 0.0

      if mode == :top
        sub_folder = "top_view"
        view.camera.perspective = false
        Sketchup.send_action("viewTop:")
      else
        sub_folder = "iso_view"
        view.camera.perspective = true
        Sketchup.send_action("viewIso:")
      end

      sleep(0.1)
      view.zoom_extents
      fixed_camera = view.camera
      output_dir = "D:/pechnik-engineering-hub/01_scenes/#{sub_folder}"
      FileUtils.mkdir_p(output_dir)

      # Конфигурация альбомного разрешения А4 для коммерческой печати
      options = { 
        width: 2480, 
        height: 1754, 
        transparent: true, 
        antialias: true, 
        compression: 9, 
        show_summary: false 
      }

      puts "ПАКЕТНЫЙ ВЫВОД ПОРЯДОВОК — Режим: #{mode.to_s.upcase}"
      model.start_operation("Пакетный экспорт", true)

      (1..54).each do |current_row|
        layers.each do |layer|
          layer_name = layer.name.downcase
          if layer_name =~ /row_(\d+)/ || layer_name =~ /ряд_(\d+)/
            row_num = $1.to_i
            layer.visible = (mode == :top) ? (row_num == current_row) : (row_num <= current_row)
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

        options[:filename] = File.join(output_dir, "row_#{sprintf('%02d', current_row)}.png")
        view.write_image(options)
      end

      model.commit_operation
      puts "[+] Пакетный экспорт PNG-порядовок успешно завершен."
    end

  end # Конец класса SceneExporter
end # Конец модуля PechnikEngineeringHub
