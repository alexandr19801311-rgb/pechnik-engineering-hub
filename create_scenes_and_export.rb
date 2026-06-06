# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ v77.78 — АВТОМАТИЗАЦИЯ И СМЕТНЫЙ СИНТЕЗ
# МОДУЛЬНАЯ СБОРКА: ЧАСТЬ 1.1 (ИНИЦИАЛИЗАЦИЯ И СИНХРОНИЗАЦИЯ ПАПОК)
# ==============================================================================

require 'fileutils'
require 'sketchup'

module PechnikEngineeringHub
  # Константы веса кирпича (кг/уел. шт)
  WEIGHT_LF  = 3.7
  WEIGHT_SP  = 3.5
  WEIGHT_SH8 = 3.4

  # Автоматическое создание структуры директорий на диске D
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
  # Основной метод экспорта с защитой слоев от загрязнения рабочей среды
  def self.export_scenes_to_png(mode = :iso)
    ensure_project_folders
    model = Sketchup.active_model
    view = model.active_view
    layers = model.layers

    # Запоминаем исходное состояние видимости слоев инженера
    original_visibility = {}
    layers.each { |layer| original_visibility[layer] = layer.visible? }

    # Нативная конфигурация ракурсов под графический движок Overdrive в SketchUp 2025
    if mode == :top
      sub_folder = "top_view"
      view.camera.perspective = false
      Sketchup.send_action("viewTop:")
    else
      sub_folder = "iso_view"
      view.camera.perspective = true
      Sketchup.send_action("viewIso:")
    end
    
    sleep(0.1) # Гарантированная пауза для разворота камеры движком
    view.zoom_extents
    fixed_camera = view.camera

    output_dir = File.join("D:/pechnik-engineering-hub/01_scenes", sub_folder)
    
    # Настройки рендера упакованы строго в хэш-структуру во избежание ArgumentError
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
      # ФИКС КАМЕРЫ v77.78: Временно гасим палитры для точного зума порядовок
      layers.each do |layer|
        l_name = layer.name.downcase
        layer.visible = false if l_name.start_with?("palette_") || l_name.start_with?("finish_")
      end
      
      # ФИЧА "ЖИВАЯ КАМЕРА" v77.78: Полная заморозка ракурса экрана инженера
      if mode == :top
        view.camera.perspective = false
        Sketchup.send_action("viewTop:")
        view.zoom_extents
        view.zoom(1.12)
      else
        # Железобетонно фиксируем текущую камеру инженера без сбросов
        puts "[+] Ракурс ISO успешно зафиксирован с экрана на верочку."
      end
      
      fixed_camera_focused = view.camera
      
      # ЖЕЛЕЗОБЕТОННАЯ ПАУЗА: Даем ядру Overdrive полностью перестроиться перед первым кадром
      view.refresh
      sleep(0.6)
      
      (1..54).each do |current_row|
        layers.each do |layer|
          layer_name = layer.name.downcase
          
          if layer_name =~ /row_(\d+)|ряд_(\d+)/
            row_num = ($1 || $2).to_i
            layer.visible = (mode == :top ? row_num == current_row : row_num <= current_row)
          elsif layer_name.start_with?("finish_")
            layer.visible = false
          elsif layer_name.start_with?("palette_") || layer_name == "untagged"
            layer.visible = true
          end
        end

        # Применяем зафиксированную живую камеру инженера без зуммирования
        view.camera = fixed_camera_focused
        view.refresh
        sleep(0.08)


        # Добавляем имя файла в хэш настроек и рендерим
        options[:filename] = File.join(output_dir, "row_#{sprintf('%02d', current_row)}.png")
        view.write_image(options)
        puts "[#{sprintf('%02d', current_row)}/54] Кадр успешно экспортирован"
      end
    ensure
      # Гарантированное восстановление слоев инженера в исходное состояние
      original_visibility.each { |layer, vis| layer.visible = vis }
      model.commit_operation
      view.refresh
      puts "[+] Рабочая область инженера успешно восстановлена."
    end
  end
  # Основной метод сметного калькулятора и анализа геометрии модели
  def self.export_materials_specification
    ensure_project_folders
    model = Sketchup.active_model
    model_title = model.title.empty? ? "Барбекю комплекс Солнечный терракот" : model.title
    
    brick_data = Hash.new(0)
    hardware_data = Hash.new(0)
    total_finish_table_area = 0.0
    
    # Инициализация пустой матрицы порядового расхода на 54 ряда
    row_matrix = Array.new(54) { { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0, "casting" => "Нет" } }

    # Всеядный рекурсивный сканер слоев и вложенных компонентов
    scan_spec = ->(instance, current_row = "Вне рядов", transform = Geom::Transformation.new) do
      layer_name = instance.layer.name.downcase.strip
      
      # Определение принадлежности к ряду (поддержка кириллицы и регистра)
      if layer_name =~ /row_(\d+)|ряд_(\d+)/
        current_row = sprintf("row_%02d", ($1 || $2).to_i)
      elsif layer_name =~ /^\d+$/
        current_row = sprintf("row_%02d", layer_name.to_i)
      end

      # Расчет глобальной трансформации с учетом масштабирования
      combined_transform = transform * (instance.respond_to?(:transformation) ? instance.transformation : Geom::Transformation.new)

      if instance.respond_to?(:definition)
        clean_name = instance.definition.name.gsub(/#\d+/, '').strip
        clean_name_down = clean_name.downcase
        # 1. ГЕОМЕТРИЧЕСКИЙ РАСЧЕТ СТОЛЕШНИЦ (FINISH-TABLE)
        if clean_name_down.include?('finish_table') || clean_name_down.include?('столешниц') || clean_name_down.include?('керамогранит')
          instance.definition.entities.each do |e|
            if e.is_a?(Sketchup::Face)
              global_normal = e.normal.transform(combined_transform)
              if global_normal.z > 0.99
                mat_arr = combined_transform.to_a
                p_sx = Math.sqrt(mat_arr[0]**2 + mat_arr[1]**2 + mat_arr[2]**2)
                p_sy = Math.sqrt(mat_arr[4]**2 + mat_arr[5]**2 + mat_arr[6]**2)
                # Конвертация площади из дюймов² в м²
                total_finish_table_area += (e.area * p_sx * p_sy) * 0.00064516
              end
            end
          end

        # 2. АНАЛИЗ И СОРТИРОВКА КИРПИЧЕЙ (LF, SP, SH8)
        elsif clean_name_down.include?('кирпич') || clean_name_down.include?('palette_brick') || clean_name_down.include?('шб') || clean_name_down.include?('шамот') || clean_name =~ /^(LF|SP|SH8)/
          if clean_name =~ /^LF/ || clean_name_down.include?('лицевой') || clean_name_down.include?('облицовка')
            mat_code = "LF"
          elsif clean_name =~ /^SH8|^ШБ/ || clean_name_down.include?('шамот')
            mat_code = "SH8"
          else
            mat_code = "SP"
          end

          # Определение фактической длины кирпича в мм
          length_mm = (clean_name =~ /-(\d+)-/) ? $1.to_i : (instance.definition.bounds.width.to_mm).round
          final_sku = "#{mat_code}-#{length_mm}-ST"
          
          brick_data.store([current_row, final_sku], brick_data.fetch([current_row, final_sku], 0) + 1)
        # 3. ПОШТУЧНЫЙ УЧЕТ ПЕЧНОГО ЛИТЬЯ И ОБОРУДОВАНИЯ
        else
          unless clean_name_down.include?('temp') || clean_name_down.include?('init') || clean_name.empty? || clean_name_down == 'group' || clean_name_down == 'группа'
            hardware_data.store(clean_name, hardware_data.fetch(clean_name, 0) + 1)

            # Синхронизация литья с матрицей рядов по текущему слою объекта
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

      # Рекурсивный спуск по иерархии вложенных групп и компонентов
      entities_to_parse = instance.respond_to?(:definition) ? instance.definition.entities : (instance.respond_to?(:entities) ? instance.entities : nil)
      if entities_to_parse
        entities_to_parse.each { |child| scan_spec.call(child, current_row, combined_transform) if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group) }
      end
    end

    # Запуск сквозного анализа геометрии по всем объектам модели
    puts "Запуск сквозного анализа геометрии..."
    model.active_entities.each { |e| scan_spec.call(e) if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

    # Передача собранных данных в метод физического синтеза отчета
    write_specification_report(model_title, brick_data, hardware_data, row_matrix, total_finish_table_area)
  end
  # Физический синтез отчета и математический расчет веса
  def self.write_specification_report(model_title, brick_data, hardware_data, row_matrix, total_finish_table_area)
    output_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
    totals = { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0 }

    # Агрегация данных порядовой матрицы кирпича с учетом коэффициентов половинчатости
    brick_data.each do |key_pair, count|
      row_str = key_pair[0]
      sku     = key_pair[1]
      
      next unless row_str =~ /row_(\d+)/
      row_idx = $1.to_i - 1
      next unless row_idx.between?(0, 53)

      sku_parts = sku.split('-')
      mat_type  = sku_parts[0]
      length    = sku_parts[1].to_i

      limit  = (mat_type == "SH8") ? 124 : 120
      weight = (length > limit) ? 1.0 : 0.5

      row_matrix[row_idx][mat_type] += (count * weight)
    end

    # Расчет финального сметного тоннажа в эквиваленте целых кирпичей
    brick_data.keys.sort.each do |key_arr|
      sku_id = key_arr[1]
      count  = brick_data[key_arr]
      sku_parts = sku_id.split('-')
      mat_type  = sku_parts[0]
      length    = sku_parts[1].to_i

      limit = (mat_type == "SH8") ? 124 : 120
      added_weight = (length > limit) ? count : (count * 0.5)
      totals[mat_type] += added_weight
    end

    # Авторасчет массы кирпичного ядра в тоннах (LF*3.7 + SP*3.5 + SH8*3.4)
    total_brick_weight = (totals["LF"] * WEIGHT_LF) + (totals["SP"] * WEIGHT_SP) + (totals["SH8"] * WEIGHT_SH8)
    total_tonnage = (total_brick_weight / 1000.0).round(2)

    # Расчет смесей (10 мм красный кирпич -> 1.1 кг, 4/2 мм шамот -> 0.6 кг)
    mix_red_kg = ((totals["LF"] + totals["SP"]) * 1.1).round(0)
    mix_sh8_kg = (totals["SH8"] * 0.6).round(0)
    # Физическое открытие и наполнение текстового отчета на диске D
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
        count  = brick_data[key_arr]
        sku_parts = sku_id.split('-')
        mat_type  = sku_parts[0]
        length    = sku_parts[1].to_i
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

    # Системный вывод всплывающего окна для полевого инженера
    UI.messagebox("СМЕТНЫЙ СИНТЕЗ v77.78 ВЫПОЛНЕН УСПЕШНО!\n\n" \
                 "Вес кирпичного ядра: #{total_tonnage} т\n" \
                 "Площадь столешниц: #{total_finish_table_area.round(2)} м²\n" \
                 "Данные сохранены в спецификацию.")
  end
end
# ==============================================================================
# ПОЛНАЯ СБОРКА СКРИПТА СИНТАКСИСА v77.78 ЗАВЕРШЕНА УСПЕШНО
# ==============================================================================
