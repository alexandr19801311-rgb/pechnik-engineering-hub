# frozen_string_literal: true
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ — ОБЪЕДИНЕННЫЙ СБОРЩИК АЛЬБОМА v77.12 (A4 LANDSCAPE)
# ЧАСТЬ 1 ИЗ 3: СТРУКТУРНЫЕ МОДУЛИ, ТЕХ.ЗАМЕТКИ И ПАРСЕР ГЕОМЕТРИИ МОДЕЛИ
# ==============================================================================

require 'fileutils'

module PechnikEngineeringHub
  module HtmlGenerator
    # Технологические предписания для критических узлов отопительного комплекса
    DEFAULT_NOTES = {
      1 => "Основание комплекса. Выкладывается строго по уровню. Проверка диагоналей обязательна.",
      2 => "Второй ряд основания. Начало формирования поддувального канала и нижних подверток.",
      3 => "Формирование зольника и фиксация нижних прочистных дверок. Герметизация стыков шнуром.",
      4 => "Сужение поддувального канала. Подготовка ложа для укладки колосниковой решетки.",
      5 => "Установка топочной дверцы. Обеспечить обязательный тепловой зазор 5 мм по всему периметру.",
      6 => "Начало футеровки топливника шамотным кирпичом. Шамот и красный кирпич НЕ перевязывать!",
      12 => "Перекрытие топочной камеры. Использовать шамотный кирпич ШБ-8 на ребро на мертель.",
      38 => "Установка задвижки летнего хода. Контроль плавности хода полотна внутри пазов кладки.",
      54 => "Финальный ряд перекрытия печи. Выравнивание плоскости под начало разделки потолочного прохода."
    }.freeze

    def self.read_specification
      spec_path = "D:/pechnik-engineering-hub/02_specifications/specification_summary.txt"
      data = {
        total_lf: 0, total_sp: 0, total_sh8: 0, total_finish_table: 0.0,
        bricks_per_row: {}, iron_materials: {}, mixtures: {},
        metadata: { project_code: "4020-HM", version: "v77.12", author: "Александр", date: "06.06.2026" }
      }

      (1..54).each { |r| data[:bricks_per_row][r] = { lf: 0, sp: 0, sh8: 0, iron: nil } }

      if File.exist?(spec_path)
        current_section = nil
        File.foreach(spec_path, chomp: true) do |line|
          cleaned = line.strip
          next if cleaned.empty? || cleaned.start_with?('-') || cleaned.start_with?('=')

          if cleaned.include?("TOTAL PRODUCTION SPECIFICATION") then current_section = :prod; next
          elsif cleaned.include?("МАТРИЦА ПОРЯДОВОГО РАСХОДА") then current_section = :matrix; next
          elsif cleaned.include?("ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ") then current_section = :iron; next
          elsif cleaned.include?("ИТОГОВЫЙ СВОДНЫЙ РАСХОД МАТЕРИАЛОВ") then current_section = :totals; next
          elsif cleaned.include?("ПРАКТИЧЕСКИЙ РАСХОД СМЕСЕЙ") then current_section = :mix; next
          end

          case current_section
          when :prod
            if cleaned =~ /^row_(\d+)\s*\|\s*([A-Z0-9]+)-.*?\|\s*.*?\|\s*(\d+)/
              r_num, sku, qty = $1.to_i, $2, $3.to_i
              data[:bricks_per_row][r_num][sku.downcase.to_sym] += qty if r_num.between?(1, 54) && data[:bricks_per_row][r_num][sku.downcase.to_sym]
            end
          when :matrix
            if cleaned =~ /^(?:Ряд|РЯД)\s*(\d+)\s*\|\s*[\d.]+\s*\|\s*[\d.]+\s*\|\s*[\d.]+\s*\|\s*(.*)/
              r_num, iron_text = $1.to_i, $2.to_s.gsub("Литье:", "").strip
              data[:bricks_per_row][r_num][:iron] = iron_text.split(',').map(&:strip).uniq.join(', ') if r_num.between?(1, 54) && iron_text != "Нет"
            end
          when :iron
            if cleaned =~ /^(.+?)\s*\|\s*(\d+)/
              name = $1.strip
              data[:iron_materials][name] = $2.to_i unless ["Компонент", "Различие", "Внешняя оболочка"].include?(name)
            end
          when :totals
            if cleaned =~ /FINISH-TABLE.*?:\s*([\d.]+)\s*m2/
              data[:total_finish_table] = $1.to_f
            end
          when :mix
            data[:mixtures][$1.strip] = "#{$2} кг" if cleaned =~ /^(.+?)\s*:\s*([\d.]+)\s*кг/
          end
        end

        (1..54).each do |r|
          data[:total_lf] += data[:bricks_per_row][r][:lf]
          data[:total_sp] += data[:bricks_per_row][r][:sp]
          data[:total_sh8] += data[:bricks_per_row][r][:sh8]
        end
      end
      data
    end
    # ==============================================================================
    # ЧАСТЬ 2.1 ИЗ 3: ИНИЦИАЛИЗАЦИЯ ИТОГОВОГО ГЕНЕРАТОРА И CSS ПЕЧАТИ (СТР. 1 - 3)
    # ==============================================================================
    def self.generate
      p_data = read_specification

      # Стили, гарантирующие отсутствие разрывов страниц и скрытие индексов "1/7"
      styles = '
        @page { size: A4 landscape; margin: 0; }
        body { font-family: "Segoe UI", Arial, sans-serif; color: #2c3e50; margin: 0; padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        .page { page-break-after: always; page-break-inside: avoid; position: relative; height: 210mm; width: 297mm; box-sizing: border-box; padding: 12mm 15mm; overflow: hidden; }
        .cover-page { text-align: center; display: flex; flex-direction: column; justify-content: space-between; height: 210mm; padding: 25mm 15mm; border: 8px double #d35400; box-sizing: border-box; background: #fff; }
        .cover-logo { font-size: 38pt; font-weight: 900; color: #d35400; font-family: "Arial Black", sans-serif; }
        .cover-title { font-size: 28pt; font-weight: bold; margin-top: 10mm; }
        .cover-subtitle { font-size: 16pt; color: #e67e22; margin-top: 4mm; }
        .cover-footer { font-size: 12pt; font-weight: bold; border-top: 2px solid #e67e22; padding-top: 5mm; color: #7f8c8d; text-transform: uppercase; }
        h1 { font-size: 18pt; border-bottom: 3px solid #d35400; padding-bottom: 2mm; margin: 0 0 4mm 0; text-transform: uppercase; }
        h2 { font-size: 18pt; color: #d35400; margin: 0; }
        .spec-table { width: 100%; border-collapse: collapse; margin-top: 2mm; table-layout: fixed; }
        .spec-table th { background-color: #34495e; color: #ffffff; padding: 2mm 3mm; text-align: left; text-transform: uppercase; font-size: 9.5pt; }
        .spec-table td { border: 1px solid #bdc3c7; padding: 2mm 3mm; font-size: 10pt; word-wrap: break-word; }
        .spec-table tr:nth-child(even) { background-color: #f8f9fa; }
        .row-header-panel { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #bdc3c7; padding-bottom: 2mm; margin-bottom: 3mm; }
        .row-badge { background-color: #e67e22; color: #ffffff; padding: 1.5mm 3mm; font-size: 10pt; font-weight: bold; border-radius: 4px; }
        .row-container { display: flex; gap: 5mm; width: 100%; }
        .image-box { flex: 1; border: 1px solid #bdc3c7; padding: 2mm; text-align: center; border-radius: 4px; background: #fff; display: flex; flex-direction: column; }
        .image-title { font-size: 9pt; color: #7f8c8d; text-transform: uppercase; margin-bottom: 2mm; font-weight: 600; border-bottom: 1px solid #f2f2f2; padding-bottom: 1mm; }
        .img-wrapper { height: 130mm; display: flex; align-items: center; justify-content: center; }
        .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; }
        .notes-box { margin-top: 3mm; padding: 2mm 3mm; background: #fff9f2; border-left: 6px solid #ff9800; }
        .notes-header { font-weight: bold; color: #d35400; font-size: 9pt; }
        .notes-body { color: #34495e; font-size: 9.5pt; }
        .header-meta { font-size: 8.5pt; color: #95a5a6; border-bottom: 1px solid #ecf0f1; padding-bottom: 1mm; margin-bottom: 3mm; text-transform: uppercase; display: flex; justify-content: space-between; }
        .page-number { position: absolute; bottom: 4mm; right: 15mm; font-size: 11pt; font-weight: bold; color: #2c3e50; border-top: 2px solid #2c3e50; padding-top: 1mm; width: 15mm; text-align: center; }
      '

      html = +"<!DOCTYPE html><html><head><meta charset='UTF-8'><style>#{styles}</style></head><body>"

      # СТРАНИЦА 1: ТИТУЛ
      html << "<div class='page cover-page'><div class='cover-logo'>PECHNIK-NOVOSIB.RU</div><div><div class='cover-title'>Отопительный комплекс Проект #{p_data[:metadata][:project_code]}</div><div class='cover-subtitle'>Порядовое рабочее руководство (Версия #{p_data[:metadata][:version]})</div></div><div class='cover-footer'>Новосибирск — #{p_data[:metadata][:date].split('.').last}</div></div>"

      # СТРАНИЦА 2: ВВЕДЕНИЕ
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]}</span><span>Введение</span></div><h1>Состав технической документации</h1><div style='font-size:12pt; line-height:1.8; margin-top:10mm;'>Настоящее руководство содержит архитектурные разрезы, спецификацию материалов фундаментного основания, полную карту заводских артикулов строительной керамики и порядовые схемы сборки отопительного комплекса. Кладочные работы вести строго в соответствии с технологическими предписаниями.</div><div class='page-number'>2</div></div>"

      # СТРАНИЦА 3: ОБЩИЙ ВИД
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 3</span><span>Общий вид изделия</span></div><h1>Общий вид отопительного комплекса (Модель 4020-HM)</h1><div class='row-container'><div class='image-box' style='height:145mm;'><div class='img-wrapper' style='height:140mm;'><img src='../01_scenes/drawings/main_preview.png'></div></div></div><div class='page-number'>3</div></div>"
      # ==============================================================================
      # ЧАСТЬ 2.2 ИЗ 3: КАРТЫ МАТЕРИАЛОВ, РАЗРЕЗЫ И СМЕТА ЧАСТЬ 1 (СТР. 4 - 8)
      # ==============================================================================

      # СТРАНИЦА 4: КАРТА МАТЕРИАЛОВ — СТРОИТЕЛЬНАЯ КЕРАМИКА
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 4</span><span>Карта материалов</span></div><h1>Карта материалов — Строительная керамика</h1><div class='row-container'><div class='image-box'><div class='image-title'>Лицевой кирпич (LF)</div><div class='img-wrapper'><img src='../01_scenes/drawings/palette_brick_facade.png'></div></div><div class='image-box'><div class='image-title'>Строительный кирпич (SP)</div><div class='img-wrapper'><img src='../01_scenes/drawings/palette_brick_building.png'></div></div></div><div class='page-number'>4</div></div>"

      # СТРАНИЦА 5: КАРТА МАТЕРИАЛОВ — ШАМОТ И ЛИТЬЕ
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 5</span><span>Карта футеровки и узлов</span></div><h1>Карта материалов — Шамот и печное литье</h1><div class='row-container'><div class='image-box'><div class='image-title'>Шамотное ядро (ШБ-8 / SH8)</div><div class='img-wrapper'><img src='../01_scenes/drawings/palette_firebrick.png'></div></div><div class='image-box'><div class='image-title'>Печное литье и фурнитура</div><div class='img-wrapper'><img src='../01_scenes/drawings/palette_iron.png'></div></div></div><div class='page-number'>5</div></div>"

      # СТРАНИЦА 6: ТЕХНИЧЕСКИЕ РАЗРЕЗЫ БОК О БОК
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 6</span><span>Конструктивные сечения</span></div><h1>Технические разрезы комплекса бок о бок</h1><div class='row-container'><div class='image-box'><div class='image-title'>Продольный разрез (Сечение 1)</div><div class='img-wrapper'><img src='../01_scenes/drawings/section_1.png'></div></div><div class='image-box'><div class='image-title'>Поперечный разрез (Сечение 2)</div><div class='img-wrapper'><img src='../01_scenes/drawings/section_2.png'></div></div></div><div class='page-number'>6</div></div>"

      # СТРАНИЦА 7: ОБЩИЕ ПРАВИЛА КЛАДКИ
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 7</span><span>Инженерный регламент</span></div><h1>Общие правила проведения кладочных работ</h1><div style='font-size:11pt; line-height:1.6; margin-top:2mm;'><ul><li><b>Технологические швы наружного контура:</b> Для лицевого (LF) и забутовочного строительного (SP) кирпича толщина шва фиксируется строго 10 мм.</li><li><b>Швы огнеупорного ядра:</b> Для шамотной кладки (ШБ-8) горизонтальный шов составляет ровно 4 мм, вертикальный — 2 мм. Кладка ведется на термостойкий мертель.</li><li><b>Тепловой зазор футеровки:</b> Между шамотным ядром и наружными стенками из красного кирпича обязательно оставлять зазор 10–15 мм. Перевязка шамота с красным кирпичом строго запрещена! Зазор заполняется базальтовым картоном.</li><li><b>Монтаж печного литья:</b> Установка топочной, поддувальной и прочистных дверок выполняется с применением термостойкого уплотнительного шнура (кремнеземного или базальтового) для компенсации расширения металла.</li></ul></div><div class='page-number'>7</div></div>"

      # Подготовка массива снабжения для деления по спецификациям
      all_items = []
      all_items << ["■ <b>Кирпич 1НФ Лицевой (LF артикул)</b>", "<b>#{p_data[:total_lf]} шт.</b>"]
      all_items << ["■ <b>Кирпич 1НФ Строительный полнотелый (SP артикул)</b>", "<b>#{p_data[:total_sp]} шт.</b>"]
      all_items << ["■ <b>Кирпич Шамотный огнеупорный (ШБ-8 / SH8)</b>", "<b>#{p_data[:total_sh8]} шт.</b>"]
      
      if p_data[:total_finish_table] > 0.0
        all_items << ["■ <span style='color:#27ae60;'><b>Керамогранит столешницы (FINISH-TABLE)</b></span>", "<b>#{p_data[:total_finish_table]} м²</b>"]
      end
      
      p_data[:iron_materials].each { |k, v| all_items << ["<span style='color:#e67e22;'>■</span> #{k}", "<b>#{v} шт.</b>"] }
      p_data[:mixtures].each { |k, v| all_items << ["<span style='color:#3498db;'>■</span> #{k}", "<b>#{v}</b>"] }

      half_size = (all_items.size / 2.0).ceil
      part1 = all_items.first(half_size)
      part2 = all_items.last(all_items.size - half_size)

      # СТРАНИЦА 8: СМЕТА ЧАСТЬ 1 (ПОЛНАЯ СТРАНИЦА БЕЗ КАРТИНКИ ФУНДАМЕНТА)
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 8</span><span>Сводная смета материалов (Часть 1)</span></div><h1>Сводная спецификация материалов конструкции</h1><div style='max-height:160mm;'><table class='spec-table'><thead><tr><th>Наименование материала / Инженерная позиция</th><th>Точное количество</th></tr></thead><tbody>"
      part1.each { |name, qty| html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
      html << "</tbody></table></div><div class='page-number'>8</div></div>"
      # ==============================================================================
      # ЧАСТЬ 3 (А) ИЗ 3: СМЕТА ЧАСТЬ 2 И ПОЛНОСТРАНИЧНЫЙ ФУНДАМЕНТНЫЙ УЗЕЛ (СТР. 9 - 10)
      # ==============================================================================

      # СТРАНИЦА 9: СМЕТА ЧАСТЬ 2 (ПОЛНАЯ СТРАНИЦА)
      html << "<div class='page'><div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 9</span><span>Сводная смета материалов (Часть 2)</span></div><h1>Сводная спецификация материалов конструкции (Часть 2)</h1><div style='max-height:160mm;'><table class='spec-table'><thead><tr><th>Наименование материала / Инженерная позиция</th><th>Точное количество</th></tr></thead><tbody>"
      part2.each { |name, qty| html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
      html << "</tbody></table></div><div class='page-number'>9</div></div>"

      # СТРАНИЦА 10: СПЕЦИФИКАЦИЯ ФУНДАМЕНТА (ВЫДЕЛЕННАЯ ПОЛНАЯ СТРАНИЦА)
      html << "<div class='page'>" \
                "<div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Стр. 10</span><span>Конструкция основания</span></div>" \
                "<h1>Спецификация фундаментного основания комплекса</h1>" \
                "<div class='row-container' style='gap:6mm; align-items: stretch; height: 155mm;'>" \
                  "<div class='image-box' style='flex: 1.3; height: 100%;'>" \
                    "<div class='image-title'>Угловой 3D-разрез фундаментной плиты</div>" \
                    "<div class='img-wrapper' style='height: 140mm;'><img src='../01_scenes/drawings/foundation.png'></div>" \
                  "</div>" \
                  "<div style='flex: 1; display: flex; flex-direction: column; justify-content: flex-start; font-size: 11pt; line-height: 1.6; background: #fdfdfd; border: 1px solid #bdc3c7; border-radius: 4px; padding: 4mm 5mm; box-sizing: border-box;'>" \
                    "<h3 style='margin: 0 0 3mm 0; color: #d35400; border-bottom: 2px solid #e67e22; padding-bottom: 1mm; text-transform: uppercase; font-size: 12pt;'>Параметры монолитной плиты</h3>" \
                    "<ul style='margin: 0; padding-left: 5mm;'>" \
                      "<li><b>Тип конструкции:</b> Мелкозаглубленная монолитная железобетонная плита.</li>" \
                      "<li><b>Марка бетона:</b> Прочностной класс не ниже Б22.5 (М300). Высокая влагостойкость.</li>" \
                      "<li><b>Армирование:</b> Двухслойная пространственная сетка из арматуры класса А500С Ø 12 мм.</li>" \
                      "<li><b>Шаг ячейки сетки:</b> Строго 200×200 мм или 250×250 мм согласно расчетным нагрузкам.</li>" \
                      "<li><b>Подстилающие слои:</b> Подушка из речного песка с послойным трамбованием и уплотненный щебень фракции 20-40 мм.</li>" \
                      "<li><b>Гидроизоляция:</b> Обязательный защитный барьер (два слоя гидроизола или рубероида) поверх бетонной подготовки.</li>" \
                    "</ul>" \
                  "</div>" \
                "</div>" \
                "<div class='page-number'>10</div>" \
              "</div>"

      # ГЕНЕРАЦИЯ ПОРЯДОВОК: Корректировка стартового индекса (Ряд №1 начинается со Страницы 11)
      (1..54).each do |r|
        rf = r.to_s.rjust(2, '0')
        cp = r + 10 # Жесткое выравнивание под новую структуру: Ряд 1 = Страница 11

        info = p_data[:bricks_per_row][r]
        pts = []
        pts << "Лицевой LF: #{info[:lf]} шт." if info[:lf] > 0
        pts << "Строительный SP: #{info[:sp]} шт." if info[:sp] > 0
        pts << "Шамотный ШБ-8: #{info[:sh8]} шт." if info[:sh8] > 0

        if info[:iron]
          pts << "<span style='color:#fff000; font-weight:800; text-shadow: 1px 1px 0px #000;'> Монтаж: #{info[:iron]}</span>"
        end

        note = DEFAULT_NOTES[r] ? "<div class='notes-box'><div class='notes-header'>ЗАМЕТКА:</div><div class='notes-body'>#{DEFAULT_NOTES[r]}</div></div>" : ""
        # Многострочная структура страницы ряда со сдвигом на Стр. 11, защищенная от схлопывания
        html << "<div class='page'>" \
                  "<div class='header-meta'><span>Проект #{p_data[:metadata][:project_code]} — Страница #{cp}</span><span>Порядовая сборка</span></div>" \
                  "<div class='row-header-panel'>" \
                    "<h2>Ряд №#{r}</h2>" \
                    "<div class='row-badge'>#{pts.join(' | ')}</div>" \
                  "</div>" \
                  "<div class='row-container'>" \
                    "<div class='image-box'>" \
                      "<div class='image-title'>Вид сверху (План раскладки швов)</div>" \
                      "<div class='img-wrapper'><img src='../01_scenes/top_view/row_#{rf}.png'></div>" \
                    "</div>" \
                    "<div class='image-box'>" \
                      "<div class='image-title'>Изометрия (Объемное накопление)</div>" \
                      "<div class='img-wrapper'><img src='../01_scenes/iso_view/row_#{rf}.png'></div>" \
                    "</div>" \
                  "</div>" \
                  "#{note}" \
                  "<div class='page-number'>#{cp}</div>" \
                "</div>"
      end

      html << "</body></html>"

      # Запись готового коммерческого альбома в рабочую директорию
      output_dir = "D:/pechnik-engineering-hub/03_web_guide"
      FileUtils.mkdir_p(output_dir)
      File.write("#{output_dir}/index.html", html)

      puts "[УСПЕХ] Объединенный альбом v77.21 собран: спецификации разделены, фундамент выведен отдельно на Стр. 10."
    end
  end
end

# Автоматический запуск генерации при вызове скрипта
PechnikEngineeringHub::HtmlGenerator.generate
