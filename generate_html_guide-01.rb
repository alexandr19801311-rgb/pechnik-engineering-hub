# frozen_string_literal: true

# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ — ПОШАГОВАЯ СБОРКА АЛЬБОМА v77.8 (А4 LANDSCAPE)
# ЧАСТЬ 1 ИЗ 5: ИНИЦИАЛИЗАЦИЯ И ТЕХНОЛОГИЧЕСКИЕ ЗАМЕТКИ СЛОЕВ
# ==============================================================================

require 'fileutils'

module PechnikEngineeringHub
  module HtmlGenerator
    # Жестко зафиксированные инженерные предписания для критически важных узлов кладки
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
    # ЧАСТЬ 2 ИЗ 5: ЛОГИКА РАЗБОРА ВЫГРУЗКИ ЯДРА ИЗ GITHUB СПЕЦИФИКАЦИИ
    def self.read_specification
      spec_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
      data = {
        total_lf: 0, total_sp: 0, total_sh8: 0,
        bricks_per_row: {}, iron_materials: {}, mixtures: {},
        metadata: { project_code: "4020-HM", version: "v77.8", author: "Александр", date: "06.06.2026" }
      }

      # Предварительная инициализация массивов для 54 рядов печи
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

        # Агрегация суммарного количества кирпича по всему объекту
        (1..54).each do |r| 
          data[:total_lf] += data[:bricks_per_row][r][:lf]
          data[:total_sp] += data[:bricks_per_row][r][:sp]
          data[:total_sh8] += data[:bricks_per_row][r][:sh8]
        end
      end
      data
    end
    # ЧАСТЬ 3 ИЗ 5: ИНИЦИАЛИЗАЦИЯ СБОРЩИКА И СТИЛИ КОММЕРЧЕСКОЙ ПЕЧАТИ
    def self.generate
      p_data = read_specification
      
      # Профессиональный CSS-пакет для альбомной печати без разрывов элементов
      styles = '
        @page { size: A4 landscape; margin: 12mm 15mm 12mm 15mm; } 
        body { font-family: "Segoe UI", Arial, sans-serif; color: #2c3e50; margin: 0; padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; } 
        .page { page-break-after: always; page-break-inside: avoid; position: relative; height: 180mm; box-sizing: border-box; } 
        .cover-page { text-align: center; display: flex; flex-direction: column; justify-content: space-between; height: 180mm; padding: 25mm 15mm; border: 4px double #d35400; box-sizing: border-box; background: #fff; page-break-inside: avoid; } 
        .cover-logo { font-size: 38pt; font-weight: 900; color: #d35400; font-family: "Arial Black", sans-serif; } 
        .cover-title { font-size: 28pt; font-weight: bold; margin-top: 10mm; } 
        .cover-subtitle { font-size: 16pt; color: #e67e22; margin-top: 4mm; } 
        .cover-footer { font-size: 11pt; font-weight: bold; border-top: 2px solid #e67e22; padding-top: 5mm; color: #7f8c8d; text-transform: uppercase; } 
        h1 { font-size: 20pt; border-bottom: 3px solid #d35400; padding-bottom: 2mm; margin: 0 0 4mm 0; } 
        h2 { font-size: 20pt; color: #d35400; margin: 0; } 
        .spec-table { width: 100%; border-collapse: collapse; margin-top: 3mm; table-layout: fixed; } 
        .spec-table th { background-color: #34495e; color: #ffffff; padding: 2.5mm 3mm; text-align: left; text-transform: uppercase; font-size: 9.5pt; } 
        .spec-table td { border: 1px solid #bdc3c7; padding: 2.5mm 3mm; font-size: 10pt; word-wrap: break-word; } 
        .spec-table tr:nth-child(even) { background-color: #f8f9fa; } 
        .row-header-panel { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #bdc3c7; padding-bottom: 2mm; margin-bottom: 3mm; } 
        .row-badge { background-color: #e67e22; color: #ffffff; padding: 2mm 4mm; font-size: 11pt; font-weight: bold; border-radius: 4px; line-height: 1.35; text-align: right; } 
        .row-container { display: flex; gap: 5mm; } 
        .image-box { flex: 1; border: 1px solid #bdc3c7; padding: 2mm; text-align: center; border-radius: 4px; background: #fff; } 
        .image-title { font-size: 8.5pt; color: #7f8c8d; text-transform: uppercase; margin-bottom: 2mm; font-weight: 600; } 
        .img-wrapper { height: 90mm; display: flex; align-items: center; justify-content: center; } 
        .img-wrapper img { max-width: 100%; max-height: 90mm; object-fit: contain; } 
        .notes-box { margin-top: 3mm; padding: 2.5mm 3mm; background: #fff9f2; border-left: 6px solid #ff9800; page-break-inside: avoid; } 
        .notes-header { font-weight: bold; color: #d35400; font-size: 9pt; } 
        .notes-body { color: #34495e; font-size: 10pt; } 
        .header-meta { font-size: 8pt; color: #95a5a6; border-bottom: 1px solid #ecf0f1; padding-bottom: 1mm; margin-bottom: 3mm; text-transform: uppercase; } 
        .page-number { position: absolute; bottom: 1mm; right: 0; font-size: 12pt; font-weight: bold; border-top: 2px solid #2c3e50; padding-top: 0.5mm; }
      '

      html = +"<!DOCTYPE html><html><head><meta charset='UTF-8'><style>#{styles}</style></head><body>"
      # ЧАСТЬ 4 ИЗ 5: ГЕНЕРАЦИЯ СТАРТОВОГО ПАКЕТА (3 ЛИСТА ПО 2 ОКНА) И ДВУХСТРАНИЧНОЙ СМЕТЫ
      
      # Лист 1: Премиальная обложка альбома
      html << "<div class='page cover-page'><div class='cover-logo'>PECHNIK-NOVOSIB.RU</div><div><div class='cover-title'>Проект отопительного комплекса #{p_data[:metadata][:project_code]}</div><div class='cover-subtitle'>Порядовое руководство (Версия #{p_data[:metadata][:version]})</div></div><div class='cover-footer'>Новосибирск — 2026</div></div>"
      
      # Листы 2, 3, 4: 3 страницы, на каждой из которых по 2 презентационных окошка (всего 6 окон)
      titles = [
        ["Продольный разрез А-А", "Поперечный разрез Б-Б"],
        ["Конструктивный разрез В-В", "Схема каналов и футеровки"],
        ["Фасадный вид (Передок)", "Тыльный / Боковой фасад"]
      ]

      (2..4).each do |p|
        t1, t2 = titles[p - 2]
        html << "<div class='page'>" \
                  "<div class='header-meta'>Проект #{p_data[:metadata][:project_code]} — Технический раздел</div>" \
                  "<h1 style='color:#7f8c8d; text-transform:uppercase;'>Чертежи и графические сечения печи</h1>" \
                  "<div class='row-container'>" \
                    "<div class='image-box'>" \
                      "<div class='image-title'>#{t1}</div>" \
                      "<div class='img-wrapper' style='height:115mm; border:2px dashed #bdc3c7; color:#95a5a6; font-style:italic; display:flex; align-items:center; justify-content:center;'>" \
                        "Окно импорта графики при склейке PDF" \
                      "</div>" \
                    "</div>" \
                    "<div class='image-box'>" \
                      "<div class='image-title'>#{t2}</div>" \
                      "<div class='img-wrapper' style='height:115mm; border:2px dashed #bdc3c7; color:#95a5a6; font-style:italic; display:flex; align-items:center; justify-content:center;'>" \
                        "Окно импорта графики при склейке PDF" \
                      "</div>" \
                    "</div>" \
                  "</div>" \
                  "<div class='page-number'>#{p}</div>" \
                "</div>"
      end

      # Подготовка массива всех позиций снабжения для деления пополам
      all_items = []
      all_items << ["■ <b>Кирпич 1НФ Лицевой (LF артикул)</b>", "<b>#{p_data[:total_lf]} шт.</b>"]
      all_items << ["■ <b>Кирпич 1НФ Строительный полнотелый (SP артикул)</b>", "<b>#{p_data[:total_sp]} шт.</b>"]
      all_items << ["■ <b>Кирпич Шамотный огнеупорный (ШБ-8 / SH8 артикул)</b>", "<b>#{p_data[:total_sh8]} шт.</b>"]
      
      p_data[:iron_materials].each { |k, v| all_items << ["<span style='color:#e67e22;'>■ </span> #{k}", "<b>#{v} шт.</b>"] }
      p_data[:mixtures].each { |k, v| all_items << ["<span style='color:#3498db;'>■ </span> #{k}", "<b>#{v}</b>"] }
      
      # Делим массив позиций на две равные части
      half_size = (all_items.size / 2.0).ceil
      part1 = all_items.first(half_size)
      part2 = all_items.last(all_items.size - half_size)

      # --- ЛИСТ 5: Спецификация материалов (Часть 1) ---
      html << "<div class='page'><div class='header-meta'>Проект #{p_data[:metadata][:project_code]} — Сметная ведомость (Начало)</div><h1>Сводная спецификация материалов конструкции (Часть 1)</h1><div style='max-height:148mm;'><table class='spec-table'><thead><tr><th>Наименование материала / Инженерная позиция</th><th>Точное количество</th></tr></thead><tbody>"
      part1.each { |name, qty| html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
      html << "</tbody></table></div><div class='page-number'>5</div></div>"

      # --- ЛИСТ 6: Спецификация материалов (Часть 2) ---
      html << "<div class='page'><div class='header-meta'>Проект #{p_data[:metadata][:project_code]} — Сметная ведомость (Окончание)</div><h1>Сводная спецификация материалов конструкции (Часть 2)</h1><div style='max-height:148mm;'><table class='spec-table'><thead><tr><th>Наименование материала / Инженерная позиция</th><th>Точное количество</th></tr></thead><tbody>"
      part2.each { |name, qty| html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
      html << "</tbody></table></div><div class='page-number'>6</div></div>"
      # ЧАСТЬ 5 ИЗ 5: ЦИКЛ ПОЯДОРОВОК СО СДВИГОМ НА СТРАНИЦУ 7 И ЗАВЕРШЕНИЕ
      
      # Листы 7 и далее: Порядовки (Ряд №1 стартует строго со страницы 7 альбома)
      (1..54).each do |r|
        rf = r.to_s.rjust(2, '0')
        cp = r + 6 # Ряд 1 = Страница 7
        info = p_data[:bricks_per_row][r]
        
        pts = []
        pts << "Лицевой LF: #{info[:lf]} шт." if info[:lf] > 0
        pts << "Строительный SP: #{info[:sp]} шт." if info[:sp] > 0
        pts << "Шамотный ШБ-8: #{info[:sh8]} шт." if info[:sh8] > 0
        
        # Вывод монтажа литья с контрастным выделением
        if info[:iron]
          pts << "<br><span style='color:#fff000; font-weight:800; text-shadow: 1px 1px 0px #000;'> Монтаж: #{info[:iron]}</span>"
        end
        
        note = DEFAULT_NOTES[r] ? "<div class='notes-box'><div class='notes-header'>ЗАМЕТКА:</div><div class='notes-body'>#{DEFAULT_NOTES[r]}</div></div>" : ""
        
        # Многострочная структура страницы ряда, защищенная от "схлопывания"
        html << "<div class='page'>" \
                  "<div class='header-meta'>Проект #{p_data[:metadata][:project_code]} — Страница #{cp}</div>" \
                  "<div class='row-header-panel'>" \
                    "<h2>Ряд №#{r}</h2>" \
                    "<div class='row-badge'>#{pts.join(' | ')}</div>" \
                  "</div>" \
                  "<div class='row-container'>" \
                    "<div class='image-box'>" \
                      "<div class='image-title'>Вид сверху</div>" \
                      "<div class='img-wrapper'><img src='../01_scenes/top_view/row_#{rf}.png'></div>" \
                    "</div>" \
                    "<div class='image-box'>" \
                      "<div class='image-title'>Изометрия</div>" \
                      "<div class='img-wrapper'><img src='../01_scenes/iso_view/row_#{rf}.png'></div>" \
                    "</div>" \
                  "</div>" \
                  "#{note}" \
                  "<div class='page-number'>#{cp}</div>" \
                "</div>"
      end

      html << "</body></html>"

      # Запись готового альбома в рабочую директорию
      output_dir = "D:/pechnik-engineering-hub/03_web_guide"
      FileUtils.mkdir_p(output_dir)
      File.write("#{output_dir}/index.html", html)
      
      puts "[УСПЕХ] Альбом v77.8 собран: чертежи сгруппированы, порядовки выровнены на страницу 7."
    end
  end
end

# Автоматический запуск генерации при вызове скрипта
PechnikEngineeringHub::HtmlGenerator.generate
