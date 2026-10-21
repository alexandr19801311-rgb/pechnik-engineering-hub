# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ v78.0 — СБОРЩИК АЛЬБОМА
# ==============================================================================
require 'fileutils'
require 'sketchup'
require 'json'
require_relative 'pechnik_config'

module PechnikEngineeringHub
  def self.generate_html_guide
    model = Sketchup.active_model
    model_title = model.title.empty? ? "Барбекю комплекс" : model.title
    
    base_dir = Config::BASE_DIR
    notes_path = File.join(base_dir, "notes.txt")
    json_path = File.join(base_dir, "02_specifications/specification.json")
    output_html_path = File.join(base_dir, "03_web_guide/index.html")
    
    FileUtils.mkdir_p(File.dirname(output_html_path))
    
    unless File.exist?(json_path)
      UI.messagebox("ОШИБКА: Сначала запустите сметный калькулятор!\nНе найден файл: #{json_path}")
      return
    end

    # 1. Чтение заметок из файла
    notes = Array.new(Config::TOTAL_ROWS + 20, "")
    if File.exist?(notes_path)
      File.readlines(notes_path, encoding: 'utf-8').each do |line|
        next if line.strip.empty? || line.start_with?('#')
        num, text = line.split('|', 2)
        notes[num.to_i] = text.to_s.strip if num.to_i > 0
      end
    end

    # 2. Чтение JSON спецификации
    data = JSON.parse(File.read(json_path, encoding: 'utf-8'))
    model_title = data["model_title"] if data["model_title"]
    
    project_code = "У-3240-НМ"
    if model_title =~ /[«"']([^»"']+)[»"']/
      project_code = $1.strip
    elsif model_title =~ /комплекс\s+(.*)/i
      project_code = $1.strip
    else
      project_code = model_title.gsub("Барбекю комплекс", "").strip
    end
    project_code = "У-3240-НМ" if project_code.empty?

    p_data = data["totals"]
    iron_materials = data["hardware"]
    bricks_per_row = data["rows"]
    
    # CSS СТИЛИ (оставлены без изменений, они отличные)
    styles = <<~CSS
      @page { size: A4 landscape; margin: 0; }
      body { margin: 0; padding: 0; font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #7f8c8d; -webkit-print-color-adjust: exact; }
      .page { width: 297mm; height: 210mm; page-break-after: always; position: relative; background: #ffffff; box-sizing: border-box; padding: 12mm 15mm; overflow: hidden; display: flex; flex-direction: column; }
      .header-meta { display: flex; justify-content: space-between; font-size: 8pt; color: #7f8c8d; text-transform: uppercase; border-bottom: 2px solid #f3f3f3; padding-bottom: 2mm; margin-bottom: 4mm; font-weight: bold; }
      h1 { font-size: 19pt; color: #2c3e50; margin: 0 0 4mm 0; text-transform: uppercase; font-weight: 800; letter-spacing: -0.5px; }
      .row-header-area { display: flex !important; justify-content: space-between !important; align-items: center !important; width: 100% !important; margin-bottom: 3mm !important; }
      .row-header-area h1 { font-size: 19pt; color: #2c3e50; margin: 0; text-transform: uppercase; font-weight: 800; letter-spacing: -0.5px; white-space: nowrap; }
      .row-badge { display: flex; flex-direction: column; gap: 1.5mm; background-color: #fdf2e9; color: #4a3728; padding: 2mm 4mm; font-size: 10pt; font-weight: bold; border-radius: 6px; border: 1px solid #e67e22; width: 78% !important; box-sizing: border-box; }
      .row-badge span { display: block !important; background-color: #d35400 !important; color: #ffffff !important; padding: 1.5mm 3mm !important; margin: 1mm 0 0 0 !important; border-radius: 4px !important; font-size: 9.5pt !important; font-weight: 500; line-height: 1.3; }
      .row-container { display: flex; gap: 5mm; width: 100%; height: 135mm; box-sizing: border-box; }
      .row-container .image-box { flex: 1; border: 1px solid #bdc3c7; padding: 3mm; text-align: center; border-radius: 6px; background: #ffffff; box-sizing: border-box; height: 100%; display: flex; flex-direction: column; position: relative !important; }
      .row-container .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; position: relative !important; }
      .extra-overlay-badge { position: absolute; width: 30%; height: 30%; border: 1px solid #555555; box-shadow: 0 2px 6px rgba(0,0,0,0.15); z-index: 999 !important; background: rgba(255, 255, 255, 0.10); backdrop-filter: blur(1px); -webkit-backdrop-filter: blur(1px); display: flex; align-items: center; justify-content: center; overflow: hidden; border-radius: 4px; }
      .extra-overlay-badge img { width: 100%; height: 100%; object-fit: contain; mix-blend-mode: multiply; }
      .overlay-bottom-right { bottom: 10px; left: 10px; }
      .overlay-top-right { top: 2px; right: 2px; }
      .extra-overlay-badge img { width: 100%; height: 100%; object-fit: contain; }
      .foundation-container { display: flex; gap: 6mm; align-items: stretch; width: 100%; height: 122mm; box-sizing: border-box; }
      .foundation-container .image-box { flex: 1.3; border: 1px solid #bdc3c7; padding: 3mm; background: #ffffff; border-radius: 6px; height: 100%; }
      .foundation-container .img-wrapper { height: 110mm; display: flex; align-items: center; justify-content: center; overflow: hidden; }
      .materials-container { display: flex; flex-direction: row; gap: 6mm; width: 100%; height: 140mm; box-sizing: border-box; }
      .materials-container .image-box-wrapper { display: flex; flex-direction: column; flex: 1; height: 100%; }
      .materials-container .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; border: 1px solid #bdc3c7; border-radius: 6px; background: #ffffff; height: 125mm !important; }
      .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; }
      .image-title { font-size: 9.5pt; color: #7f8c8d; text-transform: uppercase; margin-bottom: 2mm; font-weight: bold; }
      table.spec-table { width: 100%; border-collapse: collapse; margin-top: 2mm; font-size: 10pt; }
      table.spec-table th { background-color: #2c3e50; color: white; padding: 3mm; text-align: left; font-weight: bold; text-transform: uppercase; font-size: 9pt; }
      table.spec-table td { padding: 2.5mm 3mm; border-bottom: 1px solid #e2e8f0; color: #334155; }
      table.spec-table tr:nth-child(even) { background-color: #f8fafc; }
      .page-number { position: absolute; bottom: 4mm; right: 15mm; font-size: 11pt; font-weight: bold; color: #2c3e50; }
      .page-cover { background: linear-gradient(135deg, #d35400 0%, #e67e22 100%); padding: 30mm 25mm; color: white; }
      .cover-logo { font-size: 14pt; font-weight: 900; letter-spacing: 2px; text-transform: uppercase; border-bottom: 3px solid white; padding-bottom: 3mm; display: inline-block; }
      .cover-title { font-size: 32pt; font-weight: 900; margin: 25mm 0 2mm 0; line-height: 1.1; }
      .cover-subtitle { font-size: 16pt; font-weight: 300; opacity: 0.9; }
      .cover-footer { position: absolute; bottom: 15mm; left: 25mm; font-size: 10pt; opacity: 0.8; font-weight: bold; }
      .intro-box { display: flex; gap: 8mm; margin-top: 4mm; }
      .intro-text-side { flex: 1.6; font-size: 10.5pt; line-height: 1.6; color: #34495e; text-align: justify; }
      .intro-quote-side { flex: 1; background: #fff2e6; border-left: 4px solid #e67e22; padding: 5mm; border-radius: 4px; height: fit-content; }
      @media print { body { background: none; } .page { box-shadow: none; margin: 0; } }
    CSS

    html = +""
    html << "<!DOCTYPE html><html><head><meta charset='UTF-8'><style>#{styles}</style></head><body>"
    
    # Стр. 1: Обложка
    html << "<div class='page page-cover'><div class='cover-logo'>PECHNIK-NOVOSIB.RU</div>" \
            "<div class='cover-title'>Барбекю комплекс «#{model_title}»</div>" \
            "<div class='cover-subtitle'>Порядовое инженерное руководство повышенной точности</div>" \
            "<div class='cover-footer'>Новосибирск — #{Time.now.strftime('%d.%m.%Y')}</div></div>"

    # Стр. 2: Введение
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code}</span><span>Введение</span></div>" \
            "<h1>Состав технической документации</h1><div class='intro-box'><div class='intro-text-side'>" \
            "<p>Настоящее рабочее руководство содержит исчерпывающие архитектурные разрезы, спецификацию материалов фундаментного основания, полную карту снабжения артикулов строительной керамики и порядовые схемы сборки отопительного комплекса.</p>" \
            "<p>Каждый этап прорисован в двух ракурсах для исключения ошибок на объекте. Кладочные работы рекомендуется вести строго в соответствии с технологическими предписаниями, контролируя толщину швов и зазоры термокомпенсации.</p></div>" \
            "<div class='intro-quote-side'><b>Контакты автора:</b><br><br>Телефон: <b>+7 (913) 894-10-74</b><br><small>WhatsApp, звонки</small><br><br>Почта: <b>master-pechi@mail.ru</b><br>Сайт: <b>pechnik-novosib.ru</b></div></div>" \
            "<div class='page-number'>2</div></div>"

    # Стр. 3-6 (без изменений, копирую для компактности)
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 3</span><span>Общий вид изделия</span></div><h1>Общий вид готового комплекса</h1><div class='img-wrapper' style='height:145mm; border:1px solid #bdc3c7; border-radius:6px; background:#fff;'><img src='#{base_dir}/01_scenes/drawings/main_preview.png'></div><div class='page-number'>3</div></div>"
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 4</span><span>Карта материалов</span></div><h1>Карта материалов — Облицовка и строительный кирпич</h1><div class='materials-container'><div class='image-box-wrapper'><div class='image-title'>Лицевой фасадный кирпич (LF)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_brick_facade.png'></div></div><div class='image-box-wrapper'><div class='image-title'>Строительный кирпич наполнения (SP)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_brick_building.png'></div></div></div><div class='page-number'>4</div></div>"
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 5</span><span>Карта материалов</span></div><h1>Карта материалов — Шамот и печная фурнитура</h1><div class='materials-container'><div class='image-box-wrapper'><div class='image-title'>Шамотное ядро топки (ШБ-8 / SH8)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_firebrick.png'></div></div><div class='image-box-wrapper'><div class='image-title'>Печное чугунное литье и узлы монтажа</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_iron.png'></div></div></div><div class='page-number'>5</div></div>"
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 6</span><span>Конструктивные сечения</span></div><h1>Технические разрезы комплекса</h1><div class='materials-container'><div class='image-box-wrapper'><div class='image-title'>Продольный разрез</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/section_1.png'></div></div><div class='image-box-wrapper'><div class='image-title'>Поперечный разрез</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/section_2.png'></div></div></div><div class='page-number'>6</div></div>"

    # Стр. 7 (Регламент старта, без изменений)
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Страница 7</span><span>Регламент старта</span></div><h1 style='margin-bottom: 3mm;'>Руководство по старту и общие правила кладки</h1><div style='display: flex; gap: 5mm; height: 135mm; align-items: stretch; box-sizing: border-box;'><div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'><div><h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>1. Размещение на участке</h3><div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'><b>• Дистанция безопасности:</b> Минимум 5 метров от стен дома.<br><b>• Граница участка:</b> Не менее 1 метра от забора.<br><b>• Зеленая зона:</b> До веток ближайших деревьев — минимум 2 метра.<br><b>• Основа плиты:</b> Монолит шире печи на 100 мм.</div></div><div style='background: #edf7ed; padding: 3mm; border-radius: 4px; border-left: 4px solid #2e7d32; margin-top: 2mm;'><h3 style='margin: 0 0 1mm 0; color: #2e7d32; font-size: 10pt; text-transform: uppercase;'>💧 Подготовка материалов</h3><div style='font-size: 9pt; line-height: 1.35; color: #1b5e20;'><b>Красный кирпич:</b> Окунайте в воду на 1-2 минуты перед кладкой.<br><b>Шамотный кирпич:</b> Вымачивать нельзя! Смахните пыль.</div></div></div><div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'><div><h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>2. Контроль геометрии</h3><div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'><b>• Метод прутка:</b> Используйте стальной квадрат 10 мм.<br><b>• Шамотное ядро:</b> Швы 4 мм горизонт, 2 мм вертикаль.<br><b>• Правило 3 шагов:</b> Проверяйте трижды: уровень, угольник, рулетка.</div></div><div style='background: #fff4e5; padding: 3mm; border-radius: 4px; border-left: 4px solid #ff9800; margin-top: 2mm;'><h3 style='margin: 0 0 1mm 0; color: #b78103; font-size: 10pt; text-transform: uppercase;'>🌡 Физика печи (Критично)</h3><div style='font-size: 9pt; line-height: 1.35; color: #5c3e00;'><b>«Дом в доме»:</b> Внутреннее шамотное ядро расширяется сильнее наружных стен. Их нельзя связывать раствором!<br>Забивайте зазор базальтовым картоном 5-10 мм.</div></div></div><div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'><div><h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>3. Раствор и швабровка</h3><div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'><b>• Разные смеси:</b> Красный — ГПС, Шамот — мертель.<br><b>• Тест мастерка:</b> Раствор не должен стекать при наклоне 45°.<br><b>• Швабровка каналов:</b> Швы внутри затирайте мокрой тряпкой.</div></div><div style='background: #e3f2fd; padding: 3mm; border-radius: 4px; border-left: 4px solid #0288d1; margin-top: 2mm;'><h3 style='margin: 0 0 1mm 0; color: #0d47a1; font-size: 10pt; text-transform: uppercase;'>🛠 Набор новичка</h3><div style='font-size: 8.5pt; line-height: 1.35; color: #01579b; font-style: italic;'>Уровень 60-80 см • Резиновая киянка • Кельма • Болгарка с алмазным диском • Рулетка • Угольник • Очки и маска.</div></div></div></div><div style='display: flex; align-items: center; width: 100%; height: 12mm; background: #fffdf9; border: 1px solid #e9d5c5; border-radius: 6px; margin-top: 3mm; padding: 0 4mm; box-sizing: border-box; font-size: 8.5pt; position: relative;'><b style='color: #ffffff; background-color: #d35400; padding: 1mm 2.5mm; border-radius: 4px; margin-right: 4mm; text-transform: uppercase; letter-spacing: 0.7px; font-size: 7.5pt; font-weight: bold;'>Заметки</b><div style='flex: 1; font-family: sans-serif; font-style: italic; color: #555; padding-top: 1mm; line-height: 1.2;'>#{notes[7].empty? ? '<div style=\"height: 100%; background-image: linear-gradient(to bottom, transparent 95%, #eedcd0 95%); background-size: 100% 6mm; margin-top: 1mm; opacity: 0.8;\"></div>' : notes[7]}</div></div><div class='page-number'>7</div></div>"

    # Спецификация Часть 1 и 2
    all_items = [
      "■ Кирпич 1НФ Лицевой (LF артикул): <b>#{p_data['lf']} шт.</b>",
      "■ Кирпич 1НФ Строительный полнотелый (SP артикул): <b>#{p_data['sp']} шт.</b>",
      "■ Кирпич Шамотный огнеупорный (ШБ-8 / SH8): <b>#{p_data['sh8']} шт.</b>"
    ]
    all_items << "■ Керамогранит столешницы (FINISH-TABLE): <b>#{p_data['finish_table_m2']} м²</b>" if p_data['finish_table_m2'] > 0
    iron_materials.each { |k, v| all_items << "■ #{k}: <b>#{v} шт.</b>" }
    all_items << "■ Глиняно-песчаная смесь (Красный швы 10мм): <b>#{p_data['mix_red_kg']} кг</b>"
    all_items << "■ Огнеупорный мертель (Шамот швы 4/2мм): <b>#{p_data['mix_sh8_kg']} кг</b>"

    half_size = (all_items.size / 2.0).ceil
    part1 = all_items.first(half_size)
    part2 = all_items.last(all_items.size - half_size)

    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 8</span><span>Сводная спецификация</span></div><h1>Сводная спецификация материалов (Часть 1)</h1><table class='spec-table'><thead><tr><th>Наименование элемента снабжения</th><th>Расчетное количество</th></tr></thead><tbody>"
    part1.each { |item| name, qty = item.split(':'); html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
    html << "</tbody></table><div class='page-number'>8</div></div>"

    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 9</span><span>Сводная спецификация</span></div><h1>Сводная спецификация материалов (Часть 2)</h1><table class='spec-table'><thead><tr><th>Наименование печной фурнитуры и смесей</th><th>Расчетное количество</th></tr></thead><tbody>"
    part2.each { |item| name, qty = item.split(':'); html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
    html << "</tbody></table><div class='page-number'>9</div></div>"

    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 10</span><span>Конструкция основания</span></div><h1>Спецификация фундаментного основания комплекса</h1><div class='foundation-container'><div class='image-box'><div class='image-title'>Угловой 3D-разрез фундаментной плиты</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/foundation.png'></div></div><div style='flex:1; display:flex; flex-direction:column; justify-content:flex-start; font-size:10pt;'><h3 style='margin:0 0 2mm 0; color:#d35400; border-bottom:2px solid #d35400; padding-bottom:1mm;'>Технические параметры плиты:</h3><ul style='margin:0; padding-left:5mm; line-height:1.4;'><li><b>Тип конструкции:</b> Монолитная плита</li><li><b>Марка бетона:</b> Не ниже B22.5 (М300)</li><li><b>Армирование:</b> Сетка из арматуры Ø 12 мм</li><li><b>Шаг ячейки:</b> 200х200 мм</li><li><b>Гидроизоляция:</b> Два слоя рубероида</li></ul></div></div><div class='page-number'>10</div></div>"

    # Порядовки 1-54
    (1..Config::TOTAL_ROWS).each do |r|
      rf = r.to_s.rjust(2, '0')
      cp = r + 10
      info = bricks_per_row.find { |x| x["row"] == r } || { "lf" => 0, "sp" => 0, "sh8" => 0, "casting" => "Нет" }
      
      pts = []
      pts << "Лицевой LF: #{info['lf'].to_i} шт." if info['lf'].to_i > 0
      pts << "Строительный SP: #{info['sp'].to_i} шт." if info['sp'].to_i > 0
      pts << "Шамотный ШБ-8: #{info['sh8'].to_i} шт." if info['sh8'].to_i > 0
      brick_text = pts.join(" | ")

      img3_path = "#{base_dir}/01_scenes/additional_views/row_#{rf}_view3_top.png"
      img4_path = "#{base_dir}/01_scenes/additional_views/row_#{rf}_view4_iso.png"

      overlay_view3_html = File.exist?(img3_path) ? "<div class='extra-overlay-badge overlay-bottom-right'><img src='#{img3_path}'></div>" : ""
      overlay_view4_html = File.exist?(img4_path) ? "<div class='extra-overlay-badge overlay-top-right'><img src='#{img4_path}'></div>" : ""

      html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Страница #{cp}</span><span>Порядовая сборка</span></div><div class='row-header-area'><h1>Ряд №#{r}</h1><div class='row-badge' style='width: 78%; max-width: 78%; margin-bottom: 0;'>#{brick_text}"
      
      if info['casting'] && info['casting'] != "Нет"
        items = info['casting'].split(',').map(&:strip)
        counts = Hash.new(0)
        items.each { |item| counts[item.gsub(/\s*\(\d+\s*шт\)/, '').strip] += 1 }
        summary_pts = counts.map { |name, count| "#{name} (#{count} шт)" }
        html << "<span>Монтаж: #{summary_pts.join(', ')}</span>"
      end
      
      html << "</div></div><div class='row-container'><div class='image-box'><div class='image-title'>Вид сверху (План раскладки швов)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/top_view/row_#{rf}.png'>#{overlay_view3_html}</div></div><div class='image-box'><div class='image-title'>Изометрия (Объемное накопление)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/iso_view/row_#{rf}.png'>#{overlay_view4_html}</div></div></div><div style='display: flex; align-items: center; width: 100%; height: 12mm; background: #fffdf9; border: 1px solid #e9d5c5; border-radius: 6px; margin-top: 3mm; padding: 0 4mm; box-sizing: border-box; font-size: 8.5pt; position: relative; box-shadow: inset 0 1px 3px rgba(0,0,0,0.02);'><b style='color: #ffffff; background-color: #d35400; padding: 1mm 2.5mm; border-radius: 4px; margin-right: 4mm; text-transform: uppercase; letter-spacing: 0.7px; font-size: 7.5pt; font-weight: bold;'>Заметки</b><div style='flex: 1; font-family: sans-serif; font-style: italic; color: #555; padding-top: 1mm; line-height: 1.2;'>#{notes[r].nil? || notes[r].empty? ? '<div style=\"height: 100%; background-image: linear-gradient(to bottom, transparent 95%, #eedcd0 95%); background-size: 100% 6mm; margin-top: 1mm; opacity: 0.8;\"></div>' : notes[r]}</div></div><div class='page-number'>#{cp}</div></div>"
    end

    html << "</body></html>"
    File.open(output_html_path, "w:UTF-8") { |f| f.write(html) }
    UI.messagebox("АЛЬБОМ v78.0 УСПЕШНО СОБРАН!\n\nФайл: #{output_html_path}")
  end
end