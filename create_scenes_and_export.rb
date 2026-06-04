# Encoding: UTF-8
# ==============================================================================
# ПРОЕКТ 4020-НМ / PECHNIK-ENGINEERING-HUB (v68.8)
# ПОЛНЫЙ МОНОЛИТ: КОНВЕЙЕР ПО ЭТАЛОНУ АЛЕКСАНДРА + БЕЗУПРЕЧНАЯ СМЕТА С ПОРЯДОВКОЙ
# ==============================================================================
require 'fileutils'
require 'sketchup'

module PechnikEngineeringHub
  class SceneExporter
    class << self

      def ensure_project_folders
        base_path = "D:/pechnik-engineering-hub"
        ["#{base_path}/00_my-scripts", "#{base_path}/01_scenes", "#{base_path}/02_specifications"].each do |folder|
          FileUtils.mkdir_p(folder) unless Dir.exist?(folder)
        end
      end

      # ========================================================================
      # ЗАДАЧА 1: УНИВЕРСАЛЬНЫЙ ГРАФИЧЕСКИЙ КОНВЕЙЕР v52.2 (ЭТАЛОН СЛОЕВ ПОД FIGMA)
      # ========================================================================
      def export_scenes_to_png(mode = :custom)
        ensure_project_folders
        model = Sketchup.active_model
        view = model.active_view
        layers = model.layers
        scenes = model.pages

        puts "🧹 Шаг 1: Очистка старых сцен..."
        scenes.to_a.reverse_each { |scene| scenes.erase(scene) } 

        init_scene = scenes.add("00_Базовый_Ракурс")
        scenes.selected_page = init_scene
        model.options["PageOptions"]["TransitionTime"] = 0.0

        case mode
        when :top
          sub_folder = "top_view"
        when :iso
          sub_folder = "iso_view"
        else
          sub_folder = "custom_view"
        end

        # 🔥 ИНЖЕНЕРНЫЙ ФИКСАТОР МАСШТАБА:
        puts "📐 Расчет крупного масштаба съемки по текущему ракурсу..."
        oven_entities = []
        model.active_entities.each do |e|
          if (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) && e.layer.name.downcase =~ /row_/
            oven_entities << e
          end
        end

        if !oven_entities.empty?
          view.zoom(oven_entities)
        else
          view.zoom_extents
        end
        
        fixed_camera = view.camera
        output_dir = File.join("D:/pechnik-engineering-hub/01_scenes/", sub_folder)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        options = {
          :width => 2400, :height => 1800, :transparent => true,
          :antialias => true, :compression => 9, :show_summary => false
        }

        puts "🏗 ========================================================"
        puts "🚀 СКОРОСТНОЙ КОНВЕЙЕР v52.2: Послойный экспорт кадров под Figma"
        puts "============================================================"

        (1..54).each do |current_row|
          
          # Управляем видимостью строго по эталонной схеме Александра
          layers.each do |layer|
            layer_name = layer.name.downcase
            
            if layer_name =~ /row_(\d+)/ || layer_name =~ /ряд_(\d+)/
              row_num = $1.to_i
              if mode == :top
                # 🔥 ЭТАЛОН ПЛАНОВ: Включаем ТОЛЬКО ОДИН текущий ряд, остальные гасим
                layer.visible = (row_num == current_row)
              else
                # ЭТАЛОН ИЗОМЕТРИИ: Строим накопительно снизу вверх
                layer.visible = (row_num <= current_row)
              end
            
            # Теги финиша (столешницы/плиты) включаем только на финальном ряду
            elsif layer_name.start_with?("finish_")
              layer.visible = (current_row == 54)
              
            # 🔥 ТЕГИ ПАЛИТР И НЕПОМЕЧЕННЫЕ ВСЕГДА ДОЛЖНЫ БЫТЬ ВКЛЮЧЕНЫ
            elsif layer_name.start_with?("palette_") || layer_name == "untagged" || layer_name.include?("непомеченные")
              layer.visible = true
            end
          end

          view.camera = fixed_camera

          temp_page = scenes.add("temp_render")
          temp_page.update(2) # Намертво зашиваем состояние слоев в кадр
          scenes.selected_page = temp_page

          view.invalidate
          view.refresh
          sleep(0.15)

          options[:filename] = File.join(output_dir, "row_#{sprintf('%02d', current_row)}.png")
          view.write_image(options)

          scenes.erase(temp_page)
          puts "[#{sprintf('%02d', current_row)}/54] УСПЕХ: Кадр зафиксирован по эталону слоев."
        end

        UI.messagebox("🎉 [ПАКЕТНЫЙ КОНВЕЙЕР v52.2 ВЫПОЛНЕН]\nВсе 54 кадра сохранены в /01_scenes/#{sub_folder}/")
      end
      # ========================================================================
      # ЗАДАЧА 2: ТОТАЛЬНЫЙ СИНТЕЗ ОБЩЕЙ СПЕЦИФИКАЦИИ С ПОРЯДОВЫМ УЧЕТОМ v68.8
      # ========================================================================
  def export_materials_specification
    ensure_project_folders
    model = Sketchup.active_model

    @facade_bricks = Hash.new(0)
    @building_bricks = Hash.new(0)
    @refractory_bricks = Hash.new(0)
    @iron_hardware = Hash.new(0)
    @total_finish_table_area = 0.0
    @row_brick_matrix = Hash.new { |h, k| h[k] = Hash.new(0) }

    # Рекурсивный сканер геометрии внутри одного конкретного ряда
    scan_entities = ->(entities, current_row, transform = Geom::Transformation.new) {
      entities.each do |instance|
        next unless instance.is_a?(Sketchup::ComponentInstance) || instance.is_a?(Sketchup::Group)
        
        layer_name = instance.layer.name.downcase
        combined_transform = transform * (instance.respond_to?(:transformation) ? instance.transformation : Geom::Transformation.new)
        
        if instance.respond_to?(:definition)
          def_name = instance.definition.name
          clean_name = def_name.gsub(/#\d+/, '').strip
          clean_name_down = clean_name.downcase

          # Сбор площади керамогранита столешниц
          if layer_name.include?('finish_table') || clean_name_down.include?('finish_table')
            instance.definition.entities.each do |e|
              if e.is_a?(Sketchup::Face)
                global_normal = e.normal.transform(combined_transform)
                if global_normal.z > 0.99
                  t_arr = combined_transform.to_a
                  s_x = Math.sqrt(t_arr[0]**2 + t_arr[1]**2 + t_arr[2]**2)
                  s_y = Math.sqrt(t_arr[4]**2 + t_arr[5]**2 + t_arr[6]**2)
                  @total_finish_table_area += (e.area * s_x * s_y) * 0.00064516
                end
              end
            end
          # Подсчет кирпичей и литья с жесткой привязкой к перебираемому ряду
          elsif layer_name.include?('palette_brick_facade') || clean_name_down.include?('лицевой') || clean_name =~ /^LF/
            @facade_bricks[clean_name] += 1
            len = clean_name =~ /-(\d+)-/ ? $1.to_i : 250
            @row_brick_matrix[current_row]["LF"] += (len > 120) ? 1.0 : 0.5
          elsif layer_name.include?('palette_brick_building') || clean_name_down.include?('кирпич') || clean_name =~ /^SP/
            @building_bricks[clean_name] += 1
            len = clean_name =~ /-(\d+)-/ ? $1.to_i : 250
            @row_brick_matrix[current_row]["SP"] += (len > 120) ? 1.0 : 0.5
          elsif layer_name.include?('palette_brick_refractory') || clean_name_down.include?('шамот') || clean_name =~ /^SH8/
            @refractory_bricks[clean_name] += 1
            len = clean_name =~ /-(\d+)-/ ? $1.to_i : 250
            @row_brick_matrix[current_row]["SH8"] += (len > 124) ? 1.0 : 0.5
          elsif layer_name.include?('palette_iron') || clean_name_down.include?('дверка') || clean_name_down.include?('литье')
            @iron_hardware[clean_name] += 1
          end

          # Проваливаемся глубже внутрь вложенных групп
          if instance.definition.entities
            scan_entities.call(instance.definition.entities, current_row, combined_transform)
          end
        end
      end
    }

    puts "🔍 Шаг 2: Послойный тотальный перебор 54 рядов модели..."
    
    # Жесткий цикл по каждому ряду исключает потерю данных
    (1..54).each do |current_row|
      # Собираем объекты, которые принадлежат текущему ряду по имени слоя
      target_entities = model.active_entities.select do |e|
        if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          ln = e.layer.name.downcase
          ln =~ /row_#{current_row}\b/ || ln =~ /ряд_#{current_row}\b/ || ln =~ /row_0#{current_row}\b/ || ln =~ /ряд_0#{current_row}\b/
        else
          false
        end
      end
      
      scan_entities.call(target_entities, current_row) unless target_entities.empty?
    end

    output_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
    total_lf_pcs = 0.0
    total_sp_pcs = 0.0
    total_sh8_pcs = 0.0

    File.open(output_path, "w:UTF-8") do |file|

          unless @building_bricks.empty?
            file.puts "\n [ПАЛИТРА: СТРОИТЕЛЬНЫЙ КИРПИЧ / PALETTE_BRICK_BUILDING]"
            @building_bricks.keys.sort.each do |name|
              len = name =~ /-(\d+)-/ ? $1.to_i : 250
              label = (len > 120) ? "FULL (1.0)" : "HALF (0.5)"
              file.puts sprintf(" %-50s | %-15s | %-10d", name, label, @building_bricks[name])
              total_sp_pcs += (len > 120) ? @building_bricks[name] : (@building_bricks[name] * 0.5)
            end
          end

          unless @refractory_bricks.empty?
            file.puts "\n [ПАЛИТРА: ОГНЕУПОРНЫЙ КИРПИЧ / PALETTE_BRICK_REFRACTORY]"
            @refractory_bricks.keys.sort.each do |name|
              len = name =~ /-(\d+)-/ ? $1.to_i : 250
              label = (len > 124) ? "FULL (1.0)" : "HALF (0.5)"
              file.puts sprintf(" %-50s | %-15s | %-10d", name, label, @refractory_bricks[name])
              total_sh8_pcs += (len > 124) ? @refractory_bricks[name] : (@refractory_bricks[name] * 0.5)
            end
          end

          unless @iron_hardware.empty?
            file.puts "\n [ПАЛИТРА: ПЕЧНОЕ ЛИТЬЕ И ФУРНИТУРА / PALETTE_IRON]"
            @iron_hardware.keys.sort.each do |name|
              file.puts sprintf(" %-50s | %-15s | %-10d", name, "PIECE", @iron_hardware[name])
            end
          end

          # Таблица порядового расхода для Figma
          file.puts "\n====================================================================================="
          file.puts "                     МАТРИЦА ПОРЯДОВОГО РАСХОДА КИРПИЧА (УЧЕТ В УСЛОВНЫХ ШТУКАХ)     "
          file.puts "====================================================================================="
          file.puts sprintf(" %-12s | %-18s | %-20s | %-18s", "НОМЕР РЯДА", "ЛИЦЕВОЙ LF (ШТ)", "СТРОИТЕЛЬНЫЙ SP (ШТ)", "ШАМОТНЫЙ SH8 (ШТ)")
          file.puts "-------------------------------------------------------------------------------------"
          
          @row_brick_matrix.keys.sort.each do |row|
            lf_cnt  = @row_brick_matrix[row]["LF"]
            sp_cnt  = @row_brick_matrix[row]["SP"]
            sh8_cnt = @row_brick_matrix[row]["SH8"]
            
            lf_str  = lf_cnt  > 0 ? (lf_cnt % 1 == 0 ? lf_cnt.to_i.to_s : lf_cnt.to_s) : "-"
            sp_str  = sp_cnt  > 0 ? (sp_cnt % 1 == 0 ? sp_cnt.to_i.to_s : sp_cnt.to_s) : "-"
            sh8_str = sh8_cnt > 0 ? (sh8_cnt % 1 == 0 ? sh8_cnt.to_i.to_s : sh8_cnt.to_s) : "-"
            
            file.puts sprintf(" Ряд %02d      | %-18s | %-20s | %-18s", row, lf_str, sp_str, sh8_str)
          end

          mix_red_kg = ((total_lf_pcs + total_sp_pcs) * 1.1).round(1)
          mix_sh8_kg = (total_sh8_pcs * 0.6).round(1)

          file.puts "\n====================================================================================="
          file.puts "                            ИТОГОВЫЙ СВОДНЫЙ РАСХОД МАТЕРИАЛОВ                       "
          file.puts "====================================================================================="
          file.puts sprintf(" %-45s : %12s pcs", "LF (Всего кирпича лицевого по палитре)", total_lf_pcs.to_i.to_s.gsub('.', ','))
          file.puts sprintf(" %-45s : %12s pcs", "SP (Всего кирпича строительного по палитре)", total_sp_pcs.to_i.to_s.gsub('.', ','))
          file.puts sprintf(" %-45s : %12s pcs", "SH8 (Всего кирпича огнеупорного по палитре)", total_sh8_pcs.to_i.to_s.gsub('.', ','))

          if @total_finish_table_area > 0.0
            file.puts sprintf(" %-45s : %12s m2", "FINISH-TABLE (Керамогранит столешницы)", sprintf("%.2f", @total_finish_table_area).gsub('.', ','))
          end

          file.puts "-------------------------------------------------------------------------------------"
          file.puts "                                ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ                           "
          file.puts "-------------------------------------------------------------------------------------"
          file.puts sprintf(" Глиняно-песчаная смесь (красный кирпич * 1.1 кг) : %10.1f кг", mix_red_kg)
          file.puts sprintf(" Огнеупорный мертель (шамотный кирпич * 0.6 кг)   : %10.1f кг", mix_sh8_kg)
          file.puts "====================================================================================="
        end

        UI.messagebox("🎉 [ПОРЯДОВЫЙ СИНТЕЗ v68.4 ВЫПОЛНЕН]\nСпецификация граней столешниц и порядовая матрица сохранены!")
      end

    end
  end
end
