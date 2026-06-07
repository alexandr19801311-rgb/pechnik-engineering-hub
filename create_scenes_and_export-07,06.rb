# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ v77.78 — СТАБИЛИЗИРОВАННЫЙ ЭКСПОРТЕР (МОНОЛИТ. ЧАСТЬ 1)
# ==============================================================================

require 'fileutils'
require 'sketchup'

module PechnikEngineeringHub

  WEIGHT_LF  = 3.7
  WEIGHT_SP  = 3.5
  WEIGHT_SH8 = 3.4

  # 1. СИНХРОНИЗАЦИЯ ДИРЕКТОРИЙ НА ДИСКЕ D
  def self.ensure_project_folders
    base_path = "D:/pechnik-engineering-hub"
    folders = [
      "#{base_path}/00_my-scripts",
      "#{base_path}/01_scenes/top_view",
      "#{base_path}/01_scenes/iso_view",
      "#{base_path}/01_scenes/drawings",
      "#{base_path}/02_specifications",
      "#{base_path}/03_web_guide"
    ]
    folders.each { |folder| FileUtils.mkdir_p(folder) unless Dir.exist?(folder) }
  end

  # 2. ПАКЕТНЫЙ ЭКСПОРТЕР PNG — МОНОЛИТНЫЙ СТАБИЛЬНЫЙ БЛОК (v77.78 - ЖИВАЯ КАМЕРА)
  def self.export_scenes_to_png(mode = :iso)
    ensure_project_folders
    model = Sketchup.active_model
    view = model.active_view
    layers = model.layers

    # Запоминаем исходное состояние видимости слоев инженера
    original_visibility = {}
    layers.each { |layer| original_visibility[layer] = layer.visible? }

    if mode == :top
      sub_folder = "top_view"
      view.camera.perspective = false
      
      # РЕЖИМ "ЖИВАЯ КАМЕРА": Временно прячем палитры и отделку.
      # Масштаб и центрирование скрипт вообще не трогает — берет то, что сейчас у тебя на экране!
      layers.each do |layer|
        l_name = layer.name.downcase
        layer.visible = false if l_name.start_with?("palette_") || l_name.start_with?("finish_")
      end
      
      view.refresh
      sleep(0.40) # Пауза Х2 на стабилизацию графического конвейера
    else
      sub_folder = "iso_view"
      puts "[+] Ракурс ISO зафиксирован с экрана один в один."
    end

    # Намертво замораживаем текущий настроенный инженером ракурс перед циклом
    fixed_camera_focused = view.camera
    output_dir = File.join("D:/pechnik-engineering-hub/01_scenes", sub_folder)

    options = {
      width: 2480,
      height: 1754,
      transparent: true,
      antialias: true,
      compression: 9,
      show_summary: false
    }

    model.start_operation("Экспорт порядовок", true)
    begin
      (1..54).each do |current_row|
        layers.each do |layer|
          layer_name = layer.name.downcase
          
          if layer_name =~ /row_(\d+)|ряд_(\d+)/
            row_num = ($1 || $2).to_i
            # Для вида сверху — строго один текущий ряд. Для изометрии — накопительное возведение.
            layer.visible = (mode == :top ? row_num == current_row : row_num <= current_row)
          elsif layer_name.start_with?("finish_")
            layer.visible = false # Столешницы всегда скрыты на порядовках
          elsif layer_name.start_with?("palette_") || layer_name == "untagged"
            layer.visible = true # Палитры всегда отображаются
          end
        end

        # Восстанавливаем ракурс и принудительно держим твой ручной масштаб на каждом ряду
        view.camera = fixed_camera_focused
        
        view.invalidate # Стираем старый кэш видеокарты (железобетонный фикс черноты)
        view.refresh    # Перерисовываем геометрию ряда с нуля
        
        # КРИТИЧЕСКАЯ УДВОЕННАЯ ЗАДЕРЖКА ПАУЗА Х2 (ДЛЯ НАВЕРОЧКИ)
        sleep(0.50)

        options[:filename] = File.join(output_dir, "row_#{sprintf('%02d', current_row)}.png")
        view.write_image(options)
        puts "[#{sprintf('%02d', current_row)}/54] Кадр порядовки успешно сохранен"
      end

    ensure
      # Гарантированное восстановление видимости слоев рабочей зоны инженера
      original_visibility.each { |layer, vis| layer.visible = vis }
      model.commit_operation
      view.refresh
      puts "[+] Рабочая область инженера успешно восстановлена."
    end
  end # def self.export_scenes_to_png

  # ==============================================================================
  # 3. СКВОЗНОЙ РЕКУРСИВНЫЙ СКАНЕР МОДЕЛИ И РАСЧЕТ СТОЛЕШНИЦ (ЧАСТЬ 3)
  # ==============================================================================
  def self.export_materials_specification
    ensure_project_folders
    model = Sketchup.active_model
    model_title = model.title.empty? ? "Барбекю комплекс Солнечный терракот" : model.title
    
    brick_data = Hash.new(0)
    hardware_data = Hash.new(0)
    total_finish_table_area = 0.0
    row_matrix = Array.new(54) { { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0, "casting" => "Нет" } }

    scan_spec = ->(instance, current_row = "Вне рядов", transform = Geom::Transformation.new) do
      layer_name = instance.layer.name.downcase.strip
      if layer_name =~ /row_(\d+)|ряд_(\d+)/
        current_row = sprintf("row_%02d", ($1 || $2).to_i)
      elsif layer_name =~ /^\d+$/
        current_row = sprintf("row_%02d", layer_name.to_i)
      end

      combined_transform = transform * (instance.respond_to?(:transformation) ? instance.transformation : Geom::Transformation.new)

      if layer_name.include?('finish_table') || layer_name.include?('finish-table')
        ents = instance.respond_to?(:definition) ? instance.definition.entities : (instance.respond_to?(:entities) ? instance.entities : [])
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            global_normal = e.normal.transform(combined_transform)
            if global_normal.z > 0.98
              mat_arr = combined_transform.to_a
              scale_x = Math.sqrt(mat_arr[0]**2 + mat_arr[1]**2 + mat_arr[2]**2)
              scale_y = Math.sqrt(mat_arr[4]**2 + mat_arr[5]**2 + mat_arr[6]**2)
              total_finish_table_area += (e.area * scale_x * scale_y) * 0.00064516
            end
          end
        end
      elsif instance.respond_to?(:definition)
        clean_name = instance.definition.name.gsub(/#\d+/, '').strip
        clean_name_down = clean_name.downcase

        if clean_name_down.include?('кирпич') || clean_name_down.include?('palette_brick') || clean_name_down.include?('шб') || clean_name_down.include?('шамот') || clean_name =~ /^(LF|SP|SH8)/
          if clean_name =~ /^LF/ || clean_name_down.include?('лицевой') || clean_name_down.include?('облицовка')
            mat_code = "LF"
          elsif clean_name =~ /^SH8|^ШБ/ || clean_name_down.include?('шамот')
            mat_code = "SH8"
          else
            mat_code = "SP"
          end

          length_mm = (clean_name =~ /-(\d+)-/) ? $1.to_i : (instance.definition.bounds.width.to_mm).round
          final_sku = "#{mat_code}-#{length_mm}-ST"
          brick_data.store([current_row, final_sku], brick_data.fetch([current_row, final_sku], 0) + 1)
        else
          unless clean_name_down.include?('temp') || clean_name_down.include?('init') || clean_name.empty? || clean_name_down == 'group' || clean_name_down == 'группа'
            hardware_data.store(clean_name, hardware_data.fetch(clean_name, 0) + 1)
            if layer_name =~ /row_(\d+)|ряд_(\d+)/
              target_idx = ($1 || $2).to_i - 1
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

    puts "Запуск сквозного анализа геометрии..."
    model.active_entities.each { |e| scan_spec.call(e) if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
    
    # ЖЕСТКАЯ ФИКСАЦИЯ КОНТЕКСТА: Вызов через self.
    self.write_specification_report(model_title, brick_data, hardware_data, row_matrix, total_finish_table_area)
  end

  # ==============================================================================
  # 4. ФИЗИЧЕСКИЙ СИНТЕЗ ОТЧЕТА И МАТЕМАТИЧЕСКИЙ РАСЧЕТ ВЕСА
  # ==============================================================================
  def self.write_specification_report(model_title, brick_data, hardware_data, row_matrix, total_finish_table_area)
    output_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
    totals = { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0 }

    brick_data.each do |key_pair, count|
      row_str = key_pair[0]
      sku = key_pair[1]
      next unless row_str =~ /row_(\d+)/
      row_idx = $1.to_i - 1
      next unless row_idx.between?(0, 53)

      sku_parts = sku.split('-')
      mat_type = sku_parts[0]
      length = sku_parts[1].to_i
      limit = (mat_type == "SH8") ? 124 : 120
      weight = (length > limit) ? 1.0 : 0.5
      row_matrix[row_idx][mat_type] += (count * weight)
    end

    brick_data.each do |key_pair, count|
      sku = key_pair[1]
      sku_parts = sku.split('-')
      mat_type = sku_parts[0]
      length = sku_parts[1].to_i
      limit = (mat_type == "SH8") ? 124 : 120
      added_weight = (length > limit) ? count : (count * 0.5)
      totals[mat_type] += added_weight
    end

    total_brick_weight = (totals["LF"] * WEIGHT_LF) + (totals["SP"] * WEIGHT_SP) + (totals["SH8"] * WEIGHT_SH8)
    total_tonnage = (total_brick_weight / 1000.0).round(2)
    mix_red_kg = ((totals["LF"] + totals["SP"]) * 1.1).round(0)
    mix_sh8_kg = (totals["SH8"] * 0.6).round(0)

    File.open(output_path, "w:UTF-8") do |file|
      file.puts "[MODEL_TITLE] : #{model_title}"
      file.puts "====================================================================================="
      file.puts " TOTAL PRODUCTION SPECIFICATION REPORT (COMPONENT SYSTEM v77.78) "
      file.puts "====================================================================================="
      file.puts sprintf(" %-14s | %-25s | %-15s | %-10s", "PRODUCTION ROW", "FACTORY SKU / ELEMENT ID", "FORMAT TYPE", "QTY (PCS)")
      file.puts "-------------------------------------------------------------------------------------"
      
      brick_data.keys.sort.each do |key_arr|
        row_id = key_arr[0]
        sku_id = key_arr[1]
        count = brick_data[key_arr]
        sku_parts = sku_id.split('-')
        mat_type = sku_parts[0]
        length = sku_parts[1].to_i
        limit = (mat_type == "SH8") ? 124 : 120
        type_label = (length > limit) ? "FULL (1.0)" : "HALF (0.5)"
        file.puts sprintf(" %-14s | %-25s | %-15s | %-10d", row_id, sku_id, type_label, count)
      end

      file.puts "\n====================================================================================="
      file.puts " МАТРИЦА ПОРЯДОВОГО РАСХОДА КИРПИЧА И ЛИТЬЯ (v77.78) "
      file.puts "====================================================================================="
      file.puts " Номер ряда | Фасад (шт) | Строит (шт) | Шамот (шт) | Литье"
      file.puts "-------------------------------------------------------------------------------------"
      
      row_matrix.each_with_index do |data, idx|
        row_title = sprintf("Ряд %02d", idx + 1)
        file.puts sprintf(" %-12s | %-14.1f | %-14.1f | %-14.1f | Литье: %s",
                     row_title, data["LF"], data["SP"], data["SH8"], data["casting"])
      end

      unless hardware_data.empty?
        file.puts "\n-------------------------------------------------------------------------------------"
        file.puts " ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ (ПОШТУЧНЫЙ УЧЕТ)"
        file.puts "-------------------------------------------------------------------------------------"
        hardware_data.keys.sort.each do |hw_name|
          file.puts sprintf(" %-50s | %-30d", hw_name, hardware_data[hw_name])
        end
      end

      file.puts "\n====================================================================================="
      file.puts " ИТОГОВЫЙ СВОДНЫЙ РАСХОД МАТЕРИАЛОВ "
      file.puts "====================================================================================="
      file.puts sprintf(" %-45s : %12s pcs", "LF (Кирпич 1нф лицевой)", totals["LF"].to_i.to_s)
      file.puts sprintf(" %-45s : %12s pcs", "SP (Кирпич 1нф строительный полнотелый)", totals["SP"].to_i.to_s)
      file.puts sprintf(" %-45s : %12s pcs", "SH8 (Кирпич шамотный ШБ-8)", totals["SH8"].to_i.to_s)
      
      if total_finish_table_area > 0.0
        file.puts sprintf(" %-45s : %12.2f m2", "FINISH-TABLE (Керамогранит столешницы)", total_finish_table_area)
      end
      file.puts sprintf(" %-45s : %12.2f t", "РАСЧЕТНЫЙ ВЕС КИРПИЧНОЙ КЛАДКИ", total_tonnage)
      file.puts "-------------------------------------------------------------------------------------"
      file.puts " ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ (УЧЕТ ШВОВ v77.78) "
      file.puts "-------------------------------------------------------------------------------------"
      file.puts sprintf(" Глиняно-песчаная смесь (красный кирпич * 1.1 кг) : %10d кг", mix_red_kg)
      file.puts sprintf(" Огнеупорный мертель (шамотный кирпич * 0.6 кг) : %10d кг", mix_sh8_kg)
      file.puts "====================================================================================="
    end

    UI.messagebox("СМЕТНЫЙ СИНТЕЗ v77.78 ВЫПОЛНЕН УСПЕШНО!\n\n" \
                  "Вес кирпичного ядра: #{total_tonnage} т\n" \
                  "Площадь столешниц: #{total_finish_table_area.round(2)} м²\n" \
                  "Данные сохранены в спецификацию.")
  end

end # module PechnikEngineeringHub
