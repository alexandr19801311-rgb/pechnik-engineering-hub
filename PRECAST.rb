# ==============================================================================
# ПРОЕКТ 4020-НМ / PECHNIK-ENGINEERING-HUB (v55.2)
# ЗАВОДСКОЙ СМЕТНЫЙ МОДУЛЬ PRECAST С ИСПРАВЛЕННЫМ ОБНУЛЕНИЕМ ХЭША
# Разработчик: Александр
# ==============================================================================

def generate_factory_specification
  model = Sketchup.active_model
  
  # Жестко задаем дефолтное значение 0 для всех новых ключей хэша
  spec_data = Hash.new(0)
  @total_finish_table_area = 0.0

  # Рекурсивный сбор артикулов по рядам "матрешки"
  parse_component = ->(instance, current_row = "Вне рядов", transform = Geom::Transformation.new) {
    layer_name = instance.layer.name
    if layer_name =~ /row_(\d{1,2})/ || layer_name =~ /Ряд_(\d{1,2})/
      current_row = sprintf("row_%02d", $1.to_i)
    end

    combined_transform = transform * (instance.respond_to?(:transformation) ? instance.transformation : Geom::Transformation.new)

    if instance.respond_to?(:definition)
      def_name = instance.definition.name
      
      # Расчет площади керамогранита finish_table
      if def_name.downcase.include?('finish_table') || (instance.material && instance.material.name.downcase.include?('finish_table'))
        instance.definition.entities.each do |e|
          if e.is_a?(Sketchup::Face)
            global_normal = e.normal.transform(combined_transform)
            if global_normal.z > 0.99
              p_sx = Math.sqrt(combined_transform.to_a[0]**2 + combined_transform.to_a[1]**2 + combined_transform.to_a[2]**2)
              p_sy = Math.sqrt(combined_transform.to_a[4]**2 + combined_transform.to_a[5]**2 + combined_transform.to_a[6]**2)
              @total_finish_table_area += (e.area * p_sx * p_sy) * 0.00064516
            end
          end
        end
      # Сбор кирпичных заводских кодов (формат XX-XXX-XX)
      elsif def_name =~ /^(LF|SP|SH8)-\d+-[A-Z0-9]+$/
        spec_data[[current_row, def_name]] += 1
      end
    end

    if instance.respond_to?(:definition)
      instance.definition.entities.each do |child|
        if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
          parse_component.call(child, current_row, combined_transform)
        end
      end
    end
  }

  model.active_entities.each do |e| 
    if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      parse_component.call(e) 
    end
  end

  # Запись индустриального TXT-отчета на диск D:
  output_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
  totals = Hash.new(0.0)

  File.open(output_path, "w:UTF-8") do |file|
    file.puts "====================================================================================="
    file.puts "                 PRODUCTION SPECIFICATION REPORT (FACTORY STANDARD DE/SE)            "
    file.puts "====================================================================================="
    file.puts sprintf("  %-14s | %-25s | %-15s | %-10s", "PRODUCTION ROW", "FACTORY SKU / ELEMENT ID", "FORMAT TYPE", "QTY (PCS)")
    file.puts "-------------------------------------------------------------------------------------"

    spec_data.keys.sort.each do |key|
      row, sku = key
      count = spec_data[key]
      
      parts = sku.split('-')
      mat_type = parts[0]
      length = parts[1].to_i
      
      limit = (mat_type == "SH8") ? 124 : 120
      type_label = (length > limit) ? "FULL (1.0)" : "HALF (0.5)"
      
      file.puts sprintf("  %-14s | %-25s | %-15s | %-10d", row, sku, type_label, count)
      
      # Считаем сметный объем: цельные как 1, половинки как 0.5
      totals[mat_type] += (length > limit) ? count : (count * 0.5)
    end

    file.puts "\n"
    file.puts "====================================================================================="
    file.puts "                           TOTAL FACTORY MATERIAL SUMMARY                            "
    file.puts "====================================================================================="
    file.puts sprintf("  %-40s : %12s pcs", "LF (Кирпич 1нф лицевой)", totals["LF"].to_s.gsub('.', ','))
    file.puts sprintf("  %-40s : %12s pcs", "SP (Кирпич 1нф строительный полнотелый)", totals["SP"].to_s.gsub('.', ','))
    file.puts sprintf("  %-40s : %12s pcs", "SH8 (Кирпич шамотный ШБ-8)", totals["SH8"].to_s.gsub('.', ','))
    if @total_finish_table_area > 0.0
      file.puts sprintf("  %-40s : %12s m2", "FINISH-TABLE (Керамогранит верх)", sprintf("%.2f", @total_finish_table_area).gsub('.', ','))
    end
    file.puts "====================================================================================="
  end
  
  UI.messagebox("Заводской отчет успешно сгенерирован в:\n#{output_path}")
end

# Автозапуск модуля
generate_factory_specification
