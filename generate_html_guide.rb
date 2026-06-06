# frozen_string_literal: true
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ — ПОШАГОВАЯ СБОРКА АЛЬБОМА v77.7 (А4 LANDSCAPE)
# ЧАСТЬ 1 ИЗ 3: ЛОГИКА РАЗБОРА ВЫГРУЗКИ ЯДРА v76.6 ИЗ GITHUB СПЕЦИФИКАЦИИ
# ==============================================================================

require 'fileutils'

module PechnikEngineeringHub
  module HtmlGenerator
    DEFAULT_NOTES = {
      1 => "Основание печи. Выкладывается строго по уровню. Проверка геометрических диагоналей обязательна.",
      2 => "Второй ряд основания. Начало формирования поддувального канала, зольной камеры и нижних подверток.",
      3 => "Формирование зольника и фиксация нижних прочистных дверок. Герметизация стыков шнуром.",
      4 => "Сужение поддувального канала. Подготовка ложа для укладки колосниковой решетки.",
      5 => "Установка топочной дверцы. Обеспечить обязательный тепловой зазор 5 мм по всему периметру.",
      6 => "Начало футеровки топливника шамотным кирпичом. Шамот и красный кирпич не перевязывать!",
      12 => "Перекрытие топочной камеры. Использовать шамотный кирпич ШБ-8 на ребро на мертель.",
      38 => "Установка задвижки летнего хода. Контроль плавности хода полотна внутри пазов кладки.",
      54 => "Финальный ряд перекрытия печи. Выравнивание плоскости под начало разделки потолочного прохода."
    }.freeze

    def self.read_specification
      spec_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
      data = { 
        total_lf: 0, total_sp: 0, total_sh8: 0, 
        bricks_per_row: {}, iron_materials: {}, mixtures: {}, 
        metadata: { project_code: "4020-HM", version: "v77.7", author: "Александр", date: "06.06.2026" } 
      }
      
      # Предварительная инициализация массивов для 54 рядов
      (1..54).each { |r| data[:bricks_per_row][r] = { lf: 0, sp: 0, sh8: 0, iron: nil } }

      if File.exist?(spec_path)
        current_section = nil
        File.foreach(spec_path, chomp: true) do |line|
          cleaned = line.strip
          next if cleaned.empty? || cleaned.start_with?('-') || cleaned.start_with?('=')
          
          if cleaned.include?("TOTAL PRODUCTION SPECIFICATION") then current_section = :prod; next
          elsif cleaned.include?("МАТРИЦА ПОРЯДОВОГО РАСХОДА") then current_section = :matrix; next
          elsif cleaned.include?("ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ") then current_section = :iron; next
          elsif cleaned.include?("ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ") then current_section = :mix; next
          end

          case current_section
          when :prod
            if cleaned =~ /^row_(\d+)\s*\|\s*([A-Z0-9]+)-.*?\|\s*.*?\|\s*(\d+)/
              r_num, sku, qty = $1.to_i, $2, $3.to_i
              data[:bricks_per_row][r_num][sku.downcase.to_sym] += qty if r_num > 0 && r_num <= 54 && data[:bricks_per_row][r_num][sku.downcase.to_sym]
            end
          when :matrix
            if cleaned =~ /^(?:Ряд|РЯД)\s*(\d+)\s*\|\s*[\d.]+\s*\|\s*[\d.]+\s*\|\s*[\d.]+\s*\|\s*(.*)/
              r_num, iron_text = $1.to_i, $2.to_s.gsub("Литье:", "").strip
              data[:bricks_per_row][r_num][:iron] = iron_text.split(',').map(&:strip).uniq.join(', ') if r_num > 0 && r_num <= 54 && iron_text != "Нет"
            end
          when :iron
            if cleaned =~ /^(.+?)\s*\|\s*(\d+)/
              name = $1.strip
              data[:iron_materials][name] = $2.to_i unless ["Компонент", "Различие", "Внешняя оболочка", "Группа13"].include?(name)
            end
          when :mix
            data[:mixtures][$1.strip] = "#{$2} кг" if cleaned =~ /^(.+?)\s*:\s*([\d.]+)\s*кг/
          end
        end
        (1..54).each { |r| data[:total_lf] += data[:bricks_per_row][r][:lf]; data[:total_sp] += data[:bricks_per_row][r][:sp]; data[:total_sh8] += data[:bricks_per_row][r][:sh8] }
      end
      data
    end
    def self.generate
      p_data = read_specification
      
      styles = '@page { size: A4 landscape; margin: 15mm; } ' \
               'body { font-family: "Segoe UI", Arial, sans-serif; color: #2c3e50; margin: 0; padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' \
               '.page { page-break-after: always; position: relative; height: 175mm; box-sizing: border-box; } ' \
               '.cover-page { text-align: center; display: flex; flex-direction: column; justify-content: space-between; height: 175mm; padding: 25mm 15mm; border: 4px double #d35400; box-sizing: border-box; background: #fff; } ' \
               '.cover-logo { font-size: 38pt; font-weight: 900; color: #d35400; font-family: "Arial Black", sans-serif; } ' \
               '.cover-title { font-size: 28pt; font-weight: bold; margin-top: 10mm; } ' \
               '.cover-subtitle { font-size: 16pt; color: #e67e22; margin-top: 4mm; } ' \
               '.cover-footer { font-size: 11pt; font-weight: bold; border-top: 2px solid #e67e22; padding-top: 5mm; color: #7f8c8d; text-transform: uppercase; } ' \
               'h1 { font-size: 22pt; border-bottom: 3px solid #d35400; padding-bottom: 2mm; margin: 0 0 4mm 0; } ' \
               'h2 { font-size: 20pt; color: #d35400; margin: 0; } ' \
               '.spec-table { width: 100%; border-collapse: collapse; margin-top: 3mm; } ' \
               '.spec-table th { background-color: #34495e; color: #ffffff; padding: 3mm; text-align: left; text-transform: uppercase; font-size: 9.5pt; } ' \
               '.spec-table td { border: 1px solid #bdc3c7; padding: 2.5mm 3mm; font-size: 10.5pt; } ' \
               '.spec-table tr:nth-child(even) { background-color: #f8f9fa; } ' \
               '.row-header-panel { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #bdc3c7; padding-bottom: 2mm; margin-bottom: 3mm; } ' \
               '.row-badge { background-color: #e67e22; color: #ffffff; padding: 2mm 4mm; font-size: 11pt; font-weight: bold; border-radius: 4px; line-height: 1.35; text-align: right; } ' \
               '.row-container { display: flex; gap: 5mm; } ' \
               '.image-box { flex: 1; border: 1px solid #bdc3c7; padding: 2.5mm; text-align: center; border-radius: 4px; background: #fff; } ' \
               '.image-title { font-size: 8.5pt; color: #7f8c8d; text-transform: uppercase; margin-bottom: 2mm; font-weight: 600; } ' \
               '.img-wrapper { height: 95mm; display: flex; align-items: center; justify-content: center; } ' \
               '.img-wrapper img { max-width: 100%; max-height: 95mm; object-fit: contain; } ' \
               '.notes-box { margin-top: 3mm; padding: 2.5mm 3mm; background: #fff9f2; border-left: 6px solid #ff9800; } ' \
               '.notes-header { font-weight: bold; color: #d35400; font-size: 9pt; } ' \
               '.notes-body { color: #34495e; font-size: 10.5pt; } ' \
               '.header-meta { font-size: 8pt; color: #95a5a6; border-bottom: 1px solid #ecf0f1; padding-bottom: 1mm; margin-bottom: 3mm; text-transform: uppercase; } ' \
               '.footer-copyright { position: absolute; bottom: 2mm; left: 0; font-size: 8pt; color: #95a5a6; } ' \
               '.page-number { position: absolute; bottom: 1mm; right: 0; font-size: 12pt; font-weight: bold; border-top: 2px solid #2c3e50; padding-top: 0.5mm; }'

      html = +"<!DOCTYPE html><html><head><meta charset='UTF-8'><style>#{styles}</style></head><body>"
      html << "<div class='page cover-page'><div class='cover-logo'>PECHNIK-NOVOSIB.RU</div><div><div class='cover-title'>Проект отопительного комплекса #{p_data[:metadata][:project_code]}</div><div class='cover-subtitle'>Порядовое руководство (Версия #{p_data[:metadata][:version]})</div></div><div class='cover-footer'>Новосибирск — 2026</div></div>"
      
      html << "<div class='page'><div class='header-meta'>Проект #{p_data[:metadata][:project_code]} — Сметная ведомость</div><h1>Сводная спецификация материалов конструкции</h1><div style='max-height:142mm; overflow-y:auto;'><table class='spec-table'><thead><tr><th>Наименование материала / Инженерная позиция</th><th>Точное количество</th></tr></thead><tbody>"
      html << "<tr><td>■ <b>Кирпич 1НФ Лицевой (LF артикул)</b></td><td><b>#{p_data[:total_lf]} шт.</b></td></tr>"
      html << "<tr><td>■ <b>Кирпич 1НФ Строительный полнотелый (SP артикул)</b></td><td><b>#{p_data[:total_sp]} шт.</b></td></tr>"
      html << "<tr><td>■ <b>Кирпич Шамотный огнеупорный (ШБ-8 / SH8 артикул)</b></td><td><b>#{p_data[:total_sh8]} шт.</b></td></tr>"
      
      p_data[:iron_materials].each { |k, v| html << "<tr><td><span style='color:#e67e22;'>■</span> #{k}</td><td><b>#{v} шт.</b></td></tr>" }
      p_data[:mixtures].each { |k, v| html << "<tr><td><span style='color:#3498db;'>■</span> #{k}</td><td><b>#{v}</b></td></tr>" }
      html << "</tbody></table></div><div class='page-number'>2</div></div>"
      compiled_rows_html = ""
      (1..54).each do |r|
        rf = r.to_s.rjust(2, '0')
        cp = r + 6
        info = p_data[:bricks_per_row][r]
        pts = []
        pts << "Лицевой LF: #{info[:lf]} шт." if info[:lf] > 0
        pts << "Строительный SP: #{info[:sp]} шт." if info[:sp] > 0
        pts << "Шамотный ШБ-8: #{info[:sh8]} шт." if info[:sh8] > 0
        pts << "<br><span style='color:#fff000; font-weight:800; text-shadow: 1px 1px 0px #000;'> Монтаж: #{info[:iron]}</span>" if info[:iron]
        
        note = DEFAULT_NOTES[r] ? "<div class='notes-box'><div class='notes-header'>ЗАМЕТКА:</div><div class='notes-body'>#{DEFAULT_NOTES[r]}</div></div>" : ""
        
        html << "<div class='page'><div class='header-meta'>Проект #{p_data[:metadata][:project_code]} — Страница #{cp}</div><div class='row-header-panel'><h2>Ряд №#{r}</h2><div class='row-badge'>#{pts.join(' | ')}</div></div><div class='row-container'><div class='image-box'><div class='image-title'>Вид сверху</div><div class='img-wrapper'><img src='../01_scenes/top_view/row_#{rf}.png'></div></div><div class='image-box'><div class='image-title'>Изометрия</div><div class='img-wrapper'><img src='../01_scenes/iso_view/row_#{rf}.png'></div></div></div>#{note}<div class='page-number'>#{cp}</div></div>"
      end

      html << "</body></html>"
      output_dir = "D:/pechnik-engineering-hub/03_web_guide"
      FileUtils.mkdir_p(output_dir)
      File.write("#{output_dir}/index.html", html)
      puts "[УСПЕХ] Финальный альбом v77.7 полностью синхронизирован со спецификацией GitHub!"
    end
  end
end

PechnikEngineeringHub::HtmlGenerator.generate
