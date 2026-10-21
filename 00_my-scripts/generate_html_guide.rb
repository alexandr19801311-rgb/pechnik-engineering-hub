# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ v82.0 — СБОРЩИК АЛЬБОМА (ПРЕМИУМ-ОБЛОЖКА)
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
    
    total_bricks = p_data['lf'].to_i + p_data['sp'].to_i + p_data['sh8'].to_i

    # CSS СТИЛИ
    styles = <<~CSS
      @page { size: A4 landscape; margin: 0; }
      body { margin: 0; padding: 0; font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #7f8c8d; -webkit-print-color-adjust: exact; }
      .page { width: 297mm; height: 210mm; page-break-after: always; position: relative; background: #ffffff; box-sizing: border-box; padding: 12mm 15mm; overflow: hidden; display: flex; flex-direction: column; }
      .header-meta { display: flex; justify-content: space-between; font-size: 8pt; color: #7f8c8d; text-transform: uppercase; border-bottom: 2px solid #f3f3f3; padding-bottom: 2mm; margin-bottom: 4mm; font-weight: bold; }
      h1 { font-size: 19pt; color: #2c3e50; margin: 0 0 4mm 0; text-transform: uppercase; font-weight: 800; letter-spacing: -0.5px; }
      
      /* Обновленный блок заголовка ряда */
      .row-header-area { display: flex !important; justify-content: space-between !important; align-items: center !important; width: 100% !important; margin-bottom: 3mm !important; }
      .row-header-area h1 { font-size: 22pt; color: #2c3e50; margin: 0; text-transform: uppercase; font-weight: 800; letter-spacing: -0.5px; white-space: nowrap; }
      
      .row-badge { display: flex; flex-direction: column; gap: 1.5mm; background-color: #fdf2e9; color: #4a3728; padding: 2mm 4mm; font-size: 10pt; font-weight: bold; border-radius: 6px; border: 1px solid #e67e22; width: 78% !important; box-sizing: border-box; }
      .casting-badge { display: block !important; background-color: #d35400 !important; color: #ffffff !important; padding: 1.5mm 3mm !important; margin: 1mm 0 0 0 !important; border-radius: 4px !important; font-size: 9.5pt !important; font-weight: 500; line-height: 1.3; }
      
      .row-container { display: flex; gap: 5mm; width: 100%; height: 135mm; box-sizing: border-box; }
      .row-container .image-box { flex: 1; border: 1px solid #bdc3c7; padding: 3mm; text-align: center; border-radius: 6px; background: #ffffff; box-sizing: border-box; height: 100%; display: flex; flex-direction: column; position: relative !important; }
      .row-container .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; position: relative !important; }
      
      .extra-overlay-badge { position: absolute; width: 30%; height: 30%; border: 1px solid #555555; box-shadow: 0 2px 6px rgba(0,0,0,0.15); z-index: 999 !important; background: rgba(255, 255, 255, 0.10); backdrop-filter: blur(1px); -webkit-backdrop-filter: blur(1px); display: flex; align-items: center; justify-content: center; overflow: hidden; border-radius: 4px; }
      .extra-overlay-badge img { width: 100%; height: 100%; object-fit: contain; mix-blend-mode: multiply; }
      .overlay-bottom-right { bottom: 10px; left: 10px; }
      .overlay-top-right { top: 2px; right: 2px; }
      
      .foundation-container { display: flex; gap: 6mm; align-items: stretch; width: 100%; height: 122mm; box-sizing: border-box; }
      .foundation-container .image-box { flex: 1.3; border: 1px solid #bdc3c7; padding: 3mm; background: #ffffff; border-radius: 6px; height: 100%; }
      .foundation-container .img-wrapper { height: 110mm; display: flex; align-items: center; justify-content: center; overflow: hidden; }
      
      .materials-container { display: flex; flex-direction: row; gap: 6mm; width: 100%; height: 140mm; box-sizing: border-box; }
      .materials-container .image-box-wrapper { display: flex; flex-direction: column; flex: 1; height: 100%; }
      .materials-container .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; border: 1px solid #bdc3c7; border-radius: 6px; background: #ffffff; height: 125mm !important; }
      .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; }
      .image-title { font-size: 9.5pt; color: #7f8c8d; text-transform: uppercase; margin-bottom: 2mm; font-weight: bold; }
      
      /* ОБНОВЛЕННАЯ ТАБЛИЦА */
      table.spec-table { width: 100%; border-collapse: collapse; margin-top: 2mm; font-size: 10pt; }
      table.spec-table th { background-color: #2c3e50; color: white; padding: 3mm; text-align: left; font-weight: bold; text-transform: uppercase; font-size: 9pt; }
      table.spec-table td { padding: 2mm 3mm; border-bottom: 1px solid #e2e8f0; color: #334155; }
      table.spec-table td:last-child { text-align: right; font-weight: bold; font-variant-numeric: tabular-nums; }
      
      /* КАРТОЧКИ С ИТОГАМИ */
      .dashboard-grid { display: flex; gap: 4mm; margin-top: 6mm; width: 100%; }
      .dash-card { flex: 1; background: #2c3e50; color: white; padding: 4mm; border-radius: 8px; display: flex; flex-direction: column; justify-content: space-between; border-bottom: 4px solid #d35400; }
      .dash-title { font-size: 9pt; text-transform: uppercase; opacity: 0.8; margin-bottom: 2mm; letter-spacing: 0.5px; }
      .dash-value { font-size: 20pt; font-weight: bold; color: #f39c12; }

      /* ТИТУЛЬНЫЙ ЛИСТ (ПРЕМИАЛЬНЫЙ) */
      .page-cover { background: linear-gradient(135deg, #d35400 0%, #e67e22 100%); padding: 0; color: white; position: relative; overflow: hidden; }
      .page-cover::before { content: ""; position: absolute; top: 0; left: 0; width: 100%; height: 100%; background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.05'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E"); opacity: 0.6; z-index: 0; }
      .cover-content { position: relative; z-index: 1; display: flex; flex-direction: column; height: 100%; padding: 25mm 25mm; box-sizing: border-box; }
      
      /* Верхняя часть обложки */
      .cover-top { display: flex; justify-content: space-between; align-items: flex-start; }
      .cover-logo { font-size: 14pt; font-weight: 900; letter-spacing: 2px; text-transform: uppercase; border-bottom: 3px solid white; padding-bottom: 3mm; display: inline-block; }
      
      /* Центральная часть */
      .cover-center { flex: 1; display: flex; flex-direction: column; justify-content: center; margin-top: -20mm; z-index: 2; }
      .cover-title { font-size: 42pt; font-weight: 900; margin: 0 0 5mm 0; line-height: 1.1; text-shadow: 0 4px 12px rgba(0,0,0,0.2); max-width: 60%; }
      .cover-subtitle { font-size: 18pt; font-weight: 300; opacity: 0.9; max-width: 50%; }
      
      /* КАРТОЧКА С ФОТО НА ОБЛОЖКЕ */
      .cover-image-card {
          position: absolute;
          right: 20mm;
          bottom: 30mm;
          transform: rotate(3deg);
          width: 95mm;
          background: white;
          padding: 3mm 3mm 10mm 3mm;
          border-radius: 4px;
          box-shadow: 0 20px 40px rgba(0,0,0,0.3);
          z-index: 1;
      }
      .cover-image-card img {
          width: 100%;
          height: auto;
          display: block;
          border-radius: 2px;
      }
      .cover-image-caption {
          text-align: center;
          color: #2c3e50;
          font-size: 9pt;
          font-weight: bold;
          margin-top: 3mm;
          text-transform: uppercase;
          letter-spacing: 1px;
      }
      
      /* Нижняя карточка с контактами */
      .cover-bottom { display: flex; justify-content: space-between; align-items: flex-end; z-index: 2; }
      .contact-card { background: #2c3e50; padding: 6mm; border-radius: 8px; display: flex; gap: 6mm; align-items: center; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
      .contact-info { display: flex; flex-direction: column; justify-content: center; }
      .contact-info div { font-size: 10pt; margin-bottom: 1.5mm; color: #bdc3c7; }
      .contact-info div b { color: white; font-size: 11pt; }
      .qr-placeholder { width: 25mm; height: 25mm; background: white; padding: 1.5mm; border-radius: 4px; display: flex; align-items: center; justify-content: center; }
      
      .cover-footer { position: absolute; bottom: 0; left: 0; width: 100%; height: 10mm; background: #2c3e50; display: flex; justify-content: space-between; align-items: center; padding: 0 25mm; box-sizing: border-box; font-size: 9pt; color: #bdc3c7; z-index: 3; }

      /* БЛОК ЗАМЕТОК */
      .notes-block { display: flex; align-items: center; width: 100%; height: 12mm; background: #fffdf9; border: 1px solid #e9d5c5; border-radius: 6px; margin-top: 3mm; padding: 0 4mm; box-sizing: border-box; font-size: 8.5pt; position: relative; }
      .notes-badge { color: #ffffff; background-color: #d35400; padding: 1mm 2.5mm; border-radius: 4px; margin-right: 4mm; text-transform: uppercase; letter-spacing: 0.7px; font-size: 7.5pt; font-weight: bold; display: flex; align-items: center; gap: 2px; }
      .notes-content { flex: 1; font-family: sans-serif; font-style: italic; color: #555; padding-top: 1mm; line-height: 1.2; }
      .notes-empty { height: 100%; background-image: linear-gradient(to bottom, transparent 95%, #eedcd0 95%); background-size: 100% 6mm; margin-top: 1mm; opacity: 0.8; }
      
      .page-number { position: absolute; bottom: 4mm; right: 15mm; font-size: 11pt; font-weight: bold; color: #2c3e50; }
	  
      @media print { body { background: none; } .page { box-shadow: none; margin: 0; } }
    CSS

    html = +""
    html << "<!DOCTYPE html><html><head><meta charset='UTF-8'><style>#{styles}</style></head><body>"
    
    # Стр. 1: Обложка (Премиальная с фото и QR-кодом)
    html << "<div class='page page-cover'><div class='cover-content'>" \
            "<div class='cover-top'>" \
            "<div class='cover-logo'>PECHNIK-NOVOSIB.RU</div>" \
            "</div>" \
            "<div class='cover-center'>" \
            "<div class='cover-title'>Барбекю комплекс<br>«#{model_title}»</div>" \
            "<div class='cover-subtitle'>Порядовое инженерное руководство повышенной точности</div>" \
            "</div>" \
            "<div class='cover-image-card'>" \
            "<img src='#{base_dir}/01_scenes/drawings/main_preview.png' alt='3D Модель'>" \
            "<div class='cover-image-caption'>Общий вид изделия</div>" \
            "</div>" \
            "<div class='cover-bottom'>" \
            "<div class='contact-card'>" \
            "<div class='contact-info'>" \
            "<div>Телефон: <b>+7 (913) 894-10-74</b></div>" \
            "<div>Почта: <b>master-pechi@mail.ru</b></div>" \
            "<div>Сайт: <b>pechnik-novosib.ru</b></div>" \
            "</div>" \
            "<div class='qr-placeholder'>" \
            "<img src='http://qrcoder.ru/code/?https%3A%2F%2Fpechnik-novosib.ru%2Fproekty%2F&8&0' style='width: 25mm; height: 25mm; display: block;' alt='QR'>" \
            "</div>" \
            "</div>" \
            "</div>" \
            "</div>" \
            "<div class='cover-footer'><span>Инженерные традиции · Работа на поколения</span><span>Новосибирск — #{Time.now.strftime('%d.%m.%Y')}</span></div>" \
            "</div>"

    # Стр. 2: Введение
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code}</span><span>Введение</span></div>" \
            "<h1>Состав технической документации</h1><div class='intro-box'><div class='intro-text-side'>" \
            "<p>Настоящее рабочее руководство содержит исчерпывающие архитектурные разрезы, спецификацию материалов фундаментного основания, полную карту снабжения артикулов строительной керамики и порядовые схемы сборки отопительного комплекса.</p>" \
            "<p>Каждый этап прорисован в двух ракурсах для исключения ошибок на объекте. Кладочные работы рекомендуется вести строго в соответствии с технологическими предписаниями, контролируя толщину швов и зазоры термокомпенсации.</p></div>" \
            "<div class='intro-quote-side'><b>Контакты автора:</b><br><br>Телефон: <b>+7 (913) 894-10-74</b><br><small>WhatsApp, звонки</small><br><br>Почта: <b>master-pechi@mail.ru</b><br>Сайт: <b>pechnik-novosib.ru</b></div></div>" \
            "<div class='page-number'>2</div></div>"

    # Стр. 3-6
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 3</span><span>Общий вид изделия</span></div><h1>Общий вид готового комплекса</h1><div class='img-wrapper' style='height:145mm; border:1px solid #bdc3c7; border-radius:6px; background:#fff;'><img src='#{base_dir}/01_scenes/drawings/main_preview.png'></div><div class='page-number'>3</div></div>"
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 4</span><span>Карта материалов</span></div><h1>Карта материалов — Облицовка и строительный кирпич</h1><div class='materials-container'><div class='image-box-wrapper'><div class='image-title'>Лицевой фасадный кирпич (LF)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_brick_facade.png'></div></div><div class='image-box-wrapper'><div class='image-title'>Строительный кирпич наполнения (SP)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_brick_building.png'></div></div></div><div class='page-number'>4</div></div>"
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 5</span><span>Карта материалов</span></div><h1>Карта материалов — Шамот и печная фурнитура</h1><div class='materials-container'><div class='image-box-wrapper'><div class='image-title'>Шамотное ядро топки (ШБ-8 / SH8)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_firebrick.png'></div></div><div class='image-box-wrapper'><div class='image-title'>Печное чугунное литье и узлы монтажа</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/palette_iron.png'></div></div></div><div class='page-number'>5</div></div>"
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 6</span><span>Конструктивные сечения</span></div><h1>Технические разрезы комплекса</h1><div class='materials-container'><div class='image-box-wrapper'><div class='image-title'>Продольный разрез</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/section_1.png'></div></div><div class='image-box-wrapper'><div class='image-title'>Поперечный разрез</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/drawings/section_2.png'></div></div></div><div class='page-number'>6</div></div>"

    # Стр. 7 (Регламент старта)
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Страница 7</span><span>Регламент старта</span></div><h1 style='margin-bottom: 3mm;'>Руководство по старту и общие правила кладки</h1><div style='display: flex; gap: 5mm; height: 135mm; align-items: stretch; box-sizing: border-box;'><div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'><div><h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>1. Размещение на участке</h3><div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'><b>• Дистанция безопасности:</b> Минимум 5 метров от стен дома.<br><b>• Граница участка:</b> Не менее 1 метра от забора.<br><b>• Зеленая зона:</b> До веток ближайших деревьев — минимум 2 метра.<br><b>• Основа плиты:</b> Монолит шире печи на 100 мм.</div></div><div style='background: #edf7ed; padding: 3mm; border-radius: 4px; border-left: 4px solid #2e7d32; margin-top: 2mm;'><h3 style='margin: 0 0 1mm 0; color: #2e7d32; font-size: 10pt; text-transform: uppercase;'>💧 Подготовка материалов</h3><div style='font-size: 9pt; line-height: 1.35; color: #1b5e20;'><b>Красный кирпич:</b> Окунайте в воду на 1-2 минуты перед кладкой.<br><b>Шамотный кирпич:</b> Вымачивать нельзя! Смахните пыль.</div></div></div><div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'><div><h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>2. Контроль геометрии</h3><div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'><b>• Метод прутка:</b> Используйте стальной квадрат 10 мм.<br><b>• Шамотное ядро:</b> Швы 4 мм горизонт, 2 мм вертикаль.<br><b>• Правило 3 шагов:</b> Проверяйте трижды: уровень, угольник, рулетка.</div></div><div style='background: #fff4e5; padding: 3mm; border-radius: 4px; border-left: 4px solid #ff9800; margin-top: 2mm;'><h3 style='margin: 0 0 1mm 0; color: #b78103; font-size: 10pt; text-transform: uppercase;'>🌡 Физика печи (Критично)</h3><div style='font-size: 9pt; line-height: 1.35; color: #5c3e00;'><b>«Дом в доме»:</b> Внутреннее шамотное ядро расширяется сильнее наружных стен. Их нельзя связывать раствором!<br>Забивайте зазор базальтовым картоном 5-10 мм.</div></div></div><div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'><div><h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>3. Раствор и швабровка</h3><div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'><b>• Разные смеси:</b> Красный — ГПС, Шамот — мертель.<br><b>• Тест мастерка:</b> Раствор не должен стекать при наклоне 45°.<br><b>• Швабровка каналов:</b> Швы внутри затирайте мокрой тряпкой.</div></div><div style='background: #e3f2fd; padding: 3mm; border-radius: 4px; border-left: 4px solid #0288d1; margin-top: 2mm;'><h3 style='margin: 0 0 1mm 0; color: #0d47a1; font-size: 10pt; text-transform: uppercase;'>🛠 Набор новичка</h3><div style='font-size: 8.5pt; line-height: 1.35; color: #01579b; font-style: italic;'>Уровень 60-80 см • Резиновая киянка • Кельма • Болгарка с алмазным диском • Рулетка • Угольник • Очки и маска.</div></div></div></div><div class='notes-block'><b class='notes-badge'>✍️ Заметки</b><div class='notes-content'>#{notes[7].empty? ? '<div class=\"notes-empty\"></div>' : notes[7]}</div></div><div class='page-number'>7</div></div>"

    # Спецификация Часть 1 и 2
    raw_items = [
      "🧱 Кирпич 1НФ Лицевой (LF артикул)|#{p_data['lf']} шт.",
      "🧱 Кирпич 1НФ Строительный полнотелый (SP артикул)|#{p_data['sp']} шт.",
      "🧱 Кирпич Шамотный огнеупорный (ШБ-8 / SH8)|#{p_data['sh8']} шт."
    ]
    raw_items << "📐 Керамогранит столешницы (FINISH-TABLE)|#{p_data['finish_table_m2']} м²" if p_data['finish_table_m2'] > 0
    iron_materials.each { |k, v| raw_items << "⚙️ #{k}|#{v} шт." }
    raw_items << "🧪 Глиняно-песчаная смесь (Красный швы 10мм)|#{p_data['mix_red_kg']} кг"
    raw_items << "🧪 Огнеупорный мертель (Шамот швы 4/2мм)|#{p_data['mix_sh8_kg']} кг"

    half_size = (raw_items.size / 2.0).ceil
    part1 = raw_items.first(half_size)
    part2 = raw_items.last(raw_items.size - half_size)

    # Стр. 8
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 8</span><span>Сводная спецификация</span></div><h1>Сводная спецификация материалов (Часть 1)</h1><table class='spec-table'><thead><tr><th style='width: 75%;'>Наименование элемента снабжения</th><th style='width: 25%; text-align: right;'>Расчетное количество</th></tr></thead><tbody>"
    part1.each { |item| name, qty = item.split('|'); html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
    html << "</tbody></table>"
    
    # Блок карточек
    html << "<div class='dashboard-grid'>"
    html << "<div class='dash-card'><div class='dash-title'>Всего кирпича</div><div class='dash-value'>#{total_bricks} шт.</div></div>"
    html << "<div class='dash-card'><div class='dash-title'>Вес кладки</div><div class='dash-value'>#{p_data['tonnage']} т</div></div>"
    if p_data['finish_table_m2'] > 0
      html << "<div class='dash-card'><div class='dash-title'>Столешницы</div><div class='dash-value'>#{p_data['finish_table_m2']} м²</div></div>"
    else
      html << "<div class='dash-card'><div class='dash-title'>Смеси (всего)</div><div class='dash-value'>#{p_data['mix_red_kg'].to_i + p_data['mix_sh8_kg'].to_i} кг</div></div>"
    end
    html << "</div>"
    
    html << "<div class='page-number'>8</div></div>"

    # Стр. 9
    html << "<div class='page'><div class='header-meta'><span>Проект #{project_code} — Стр. 9</span><span>Сводная спецификация</span></div><h1>Сводная спецификация материалов (Часть 2)</h1><table class='spec-table'><thead><tr><th style='width: 75%;'>Наименование печной фурнитуры и смесей</th><th style='width: 25%; text-align: right;'>Расчетное количество</th></tr></thead><tbody>"
    part2.each { |item| name, qty = item.split('|'); html << "<tr><td>#{name}</td><td>#{qty}</td></tr>" }
    html << "</tbody></table><div class='page-number'>9</div></div>"

    # Стр. 10
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
      
      # Логика вывода плашки монтажа
      if info['casting'] && info['casting'] != "Нет"
        items = info['casting'].split(',').map(&:strip)
        counts = Hash.new(0)
        items.each { |item| counts[item.gsub(/\s*\(\d+\s*шт\)/, '').strip] += 1 }
        summary_pts = counts.map { |name, count| "#{name} (#{count} шт)" }
        html << "<span class='casting-badge'>Монтаж: #{summary_pts.join(', ')}</span>"
      end
      
      html << "</div></div><div class='row-container'><div class='image-box'><div class='image-title'>Вид сверху (План раскладки швов)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/top_view/row_#{rf}.png'>#{overlay_view3_html}</div></div><div class='image-box'><div class='image-title'>Изометрия (Объемное накопление)</div><div class='img-wrapper'><img src='#{base_dir}/01_scenes/iso_view/row_#{rf}.png'>#{overlay_view4_html}</div></div></div><div class='notes-block'><b class='notes-badge'>✍️ Заметки</b><div class='notes-content'>#{notes[r].nil? || notes[r].empty? ? '<div class=\"notes-empty\"></div>' : notes[r]}</div></div><div class='page-number'>#{cp}</div></div>"
    end

    html << "</body></html>"
    File.open(output_html_path, "w:UTF-8") { |f| f.write(html) }
    UI.messagebox("АЛЬБОМ v82.0 УСПЕШНО СОБРАН!\n\nОбложка с фото готова к печати.")
  end
end