# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ v78.2 — ЭКСПОРТЕР (ЧИСТАЯ СПЕЦИФИКАЦИЯ)
# ==============================================================================
require 'fileutils'
require 'sketchup'
require 'json'
require_relative 'pechnik_config'

module PechnikEngineeringHub
  def self.ensure_project_folders
    folders = [
      "#{Config::BASE_DIR}/00_my-scripts",
      "#{Config::BASE_DIR}/01_scenes/top_view",
      "#{Config::BASE_DIR}/01_scenes/iso_view",
      "#{Config::BASE_DIR}/01_scenes/drawings",
      "#{Config::BASE_DIR}/02_specifications",
      "#{Config::BASE_DIR}/03_web_guide"
    ]
    folders.each { |folder| FileUtils.mkdir_p(folder) unless Dir.exist?(folder) }
  end

  def self.export_scenes_to_png(mode = :iso)
    ensure_project_folders
    model = Sketchup.active_model
    view = model.active_view
    layers = model.layers
    original_visibility = {}
    layers.each { |layer| original_visibility[layer] = layer.visible? }

    if mode == :top
      sub_folder = "top_view"
      view.camera.perspective = false
      layers.each do |layer|
        l_name = layer.name.downcase
        layer.visible = false if l_name.start_with?("palette_") || l_name.start_with?("finish_")
      end
      view.refresh
      sleep(0.40)
    else
      sub_folder = "iso_view"
    end

    fixed_camera_focused = view.camera
    output_dir = File.join("#{Config::BASE_DIR}/01_scenes", sub_folder)
    options = { width: 2480, height: 1754, transparent: true, antialias: true, compression: 9, show_summary: false }

    model.start_operation("Экспорт порядовок", true)
    begin
      (1..Config::TOTAL_ROWS).each do |current_row|
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

        view.camera = fixed_camera_focused
        view.invalidate
        view.refresh
        sleep(Config::EXPORT_SLEEP_SEC) if Config::EXPORT_SLEEP_SEC > 0
        options[:filename] = File.join(output_dir, "row_#{sprintf('%02d', current_row)}.png")
        view.write_image(options)
      end
    ensure
      original_visibility.each { |layer, vis| layer.visible = vis }
      model.commit_operation
      view.refresh
    end
  end

  def self.export_materials_specification
    ensure_project_folders
    model = Sketchup.active_model
    model_title = model.title.empty? ? "Барбекю комплекс" : model.title
    
    brick_data = Hash.new(0)
    hardware_data = Hash.new(0)
    total_finish_table_area = 0.0
    row_matrix = Array.new(Config::TOTAL_ROWS) { { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0, "casting" => "Нет" } }

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

        # 1. Обработка кирпичей
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
        
        # 2. Обработка литья и прочего (СТРОГИЙ ФИЛЬТР)
        else
          # Игнорируем пустые имена, временные группы, системные "Группа 1", "Компонент" и т.д.
          is_ignored = clean_name.empty? || 
                       clean_name_down.include?('temp') || 
                       clean_name_down.include?('init') || 
                       clean_name_down =~ /^(group|группа|компонент|component|различие|четверть)\s*\d*$/ ||
                       clean_name_down.start_with?('group', 'группа', 'компонент', 'component') ||
                       clean_name_down == 'лицевой' || 
                       clean_name_down == 'забутовка' || 
                       clean_name_down == 'шамот'

          unless is_ignored
            hardware_data.store(clean_name, hardware_data.fetch(clean_name, 0) + 1)
            if layer_name =~ /row_(\d+)|ряд_(\d+)/
              target_idx = ($1 || $2).to_i - 1
              if target_idx.between?(0, Config::TOTAL_ROWS - 1)
                old_cast = row_matrix[target_idx]["casting"]
                if old_cast == "Нет"
                  row_matrix[target_idx]["casting"] = "#{clean_name} (1 шт)"
                elsif !old_cast.include?(clean_name)
                  row_matrix[target_idx]["casting"] = "#{old_cast}, #{clean_name} (1 шт)"
                end
              end
            end
          end
        end
      end

      # Рекурсия
      entities_to_parse = instance.respond_to?(:definition) ? instance.definition.entities : (instance.respond_to?(:entities) ? instance.entities : nil)
      if entities_to_parse
        entities_to_parse.each { |child| scan_spec.call(child, current_row, combined_transform) if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group) }
      end
    end

    model.active_entities.each { |e| scan_spec.call(e) if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
    
    self.write_specification_report(model_title, brick_data, hardware_data, row_matrix, total_finish_table_area)
  end

  def self.write_specification_report(model_title, brick_data, hardware_data, row_matrix, total_finish_table_area)
    output_path_txt = "#{Config::BASE_DIR}/02_specifications/specification_summary.txt"
    output_path_json = "#{Config::BASE_DIR}/02_specifications/specification.json"
    totals = { "LF" => 0.0, "SP" => 0.0, "SH8" => 0.0 }

    brick_data.each do |key_pair, count|
      row_str = key_pair[0]
      sku = key_pair[1]
      next unless row_str =~ /row_(\d+)/
      row_idx = $1.to_i - 1
      next unless row_idx.between?(0, Config::TOTAL_ROWS - 1)

      sku_parts = sku.split('-')
      mat_type = sku_parts[0]
      length = sku_parts[1].to_i
      limit = Config::HALF_THRESHOLD[mat_type] || 120
      
      weight = (length > limit) ? 1.0 : 0.5
      row_matrix[row_idx][mat_type] += (count * weight)
    end

    brick_data.each do |key_pair, count|
      sku = key_pair[1]
      sku_parts = sku.split('-')
      mat_type = sku_parts[0]
      length = sku_parts[1].to_i
      limit = Config::HALF_THRESHOLD[mat_type] || 120
      
      added_weight = (length > limit) ? count : (count * 0.5)
      totals[mat_type] += added_weight
    end

    total_brick_weight = (totals["LF"] * Config::WEIGHT_LF) + (totals["SP"] * Config::WEIGHT_SP) + (totals["SH8"] * Config::WEIGHT_SH8)
    total_tonnage = (total_brick_weight / 1000.0).round(2)
    mix_red_kg = ((totals["LF"] + totals["SP"]) * 1.1).round(0)
    mix_sh8_kg = (totals["SH8"] * 0.6).round(0)

    File.open(output_path_txt, "w:UTF-8") do |file|
      file.puts "[MODEL_TITLE] : #{model_title}"
      file.puts "=" * 85
      file.puts " TOTAL PRODUCTION SPECIFICATION REPORT (v78.2) "
      file.puts "=" * 85
      file.puts sprintf(" %-14s | %-25s | %-15s | %-10s", "PRODUCTION ROW", "FACTORY SKU / ELEMENT ID", "FORMAT TYPE", "QTY (PCS)")
      file.puts "-" * 85
      
      brick_data.keys.sort.each do |key_arr|
        row_id = key_arr[0]
        sku_id = key_arr[1]
        count = brick_data[key_arr]
        sku_parts = sku_id.split('-')
        mat_type = sku_parts[0]
        length = sku_parts[1].to_i
        limit = Config::HALF_THRESHOLD[mat_type] || 120
        type_label = (length > limit) ? "FULL (1.0)" : "HALF (0.5)"
        file.puts sprintf(" %-14s | %-25s | %-15s | %-10d", row_id, sku_id, type_label, count)
      end

      file.puts "\n" + "=" * 85
      file.puts " МАТРИЦА ПОРЯДОВОГО РАСХОДА КИРПИЧА И ЛИТЬЯ "
      file.puts "=" * 85
      file.puts " Номер ряда | Фасад (шт) | Строит (шт) | Шамот (шт) | Литье"
      file.puts "-" * 85
      
      row_matrix.each_with_index do |data, idx|
        row_title = sprintf("Ряд %02d", idx + 1)
        casting_text = data["casting"] == "Нет" ? "" : "Литье: #{data['casting']}"
        file.puts sprintf(" %-12s | %-14.1f | %-14.1f | %-14.1f | %s",
                     row_title, data["LF"], data["SP"], data["SH8"], casting_text)
      end

      unless hardware_data.empty?
        file.puts "\n" + "-" * 85
        file.puts " ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ (ПОШТУЧНЫЙ УЧЕТ)"
        file.puts "-" * 85
        hardware_data.keys.sort.each do |hw_name|
          file.puts sprintf(" %-50s | %-30d", hw_name, hardware_data[hw_name])
        end
      end

      file.puts "\n" + "=" * 85
      file.puts " ИТОГОВЫЙ СВОДНЫЙ РАСХОД МАТЕРИАЛОВ "
      file.puts "=" * 85
      file.puts sprintf(" %-45s : %12s pcs", "LF (Кирпич 1нф лицевой)", totals["LF"].to_s)
      file.puts sprintf(" %-45s : %12s pcs", "SP (Кирпич 1нф строительный полнотелый)", totals["SP"].to_s)
      file.puts sprintf(" %-45s : %12s pcs", "SH8 (Кирпич шамотный ШБ-8)", totals["SH8"].to_s)
      
      if total_finish_table_area > 0.0
        file.puts sprintf(" %-45s : %12.2f m2", "FINISH-TABLE (Керамогранит столешницы)", total_finish_table_area)
      end
      file.puts sprintf(" %-45s : %12.2f t", "РАСЧЕТНЫЙ ВЕС КИРПИЧНОЙ КЛАДКИ", total_tonnage)
      file.puts "-" * 85
      file.puts " ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ (УЧЕТ ШВОВ) "
      file.puts "-" * 85
      file.puts sprintf(" Глиняно-песчаная смесь (красный кирпич * 1.1 кг) : %10d кг", mix_red_kg)
      file.puts sprintf(" Огнеупорный мертель (шамотный кирпич * 0.6 кг) : %10d кг", mix_sh8_kg)
      file.puts "=" * 85
    end

    json_data = {
      model_title: model_title,
      totals: {
        lf: totals["LF"].ceil,
        sp: totals["SP"].ceil,
        sh8: totals["SH8"].ceil,
        finish_table_m2: total_finish_table_area.round(2),
        tonnage: total_tonnage,
        mix_red_kg: mix_red_kg,
        mix_sh8_kg: mix_sh8_kg
      },
      hardware: hardware_data,
      rows: row_matrix.each_with_index.map do |data, idx|
        { row: idx + 1, lf: data["LF"], sp: data["SP"], sh8: data["SH8"], casting: data["casting"] }
      end,
      details: brick_data.map { |k, v| { row: k[0], sku: k[1], qty: v } }
    }
    File.write(output_path_json, JSON.pretty_generate(json_data))

    UI.messagebox("СМЕТНЫЙ СИНТЕЗ v78.2 ВЫПОЛНЕН!\n\nВес кирпичного ядра: #{total_tonnage} т\nПлощадь столешниц: #{total_finish_table_area.round(2)} м²\nДанные сохранены в TXT и JSON.")
  end
end