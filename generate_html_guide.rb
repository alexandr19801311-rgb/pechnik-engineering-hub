# ==============================================================================
# АРХИТЕКТУРНЫЙ СЛЕПОК ПРОЕКТА v77.8 — ТЕХНИЧЕСКИЙ АЛЬБОМ А4 (ЧАСТЬ А)
# ==============================================================================

module PechnikEngineeringHub
  module HtmlGenerator
    def self.generate
      base_dir = "D:/pechnik-engineering-hub"
      output_dir = "#{base_dir}/03_web_guide"
      drawings_dir = "#{base_dir}/01_scenes/drawings"
      file_path = "#{output_dir}/index.html"
      
      # Инициализация базовой разметки HTML и стилей альбома
      html = ""
      html << "<!DOCTYPE html>\n<html>\n<head>\n<meta charset='utf-8'>\n"
      html << "<style>\n"
      html << "  @page { size: A4 landscape; margin: 12mm 10mm 10mm 10mm; }\n"
      html << "  body { font-family: Arial, sans-serif; margin: 0; padding: 0; background: #fff; }\n"
      html << "  .tech-page { page-break-after: always; box-sizing: border-box; height: 185mm; position: relative; }\n"
      html << "  .grid-2-col { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }\n"
      html << "  .palette-card { border: 1px solid #ccc; padding: 12px; background: #fafafa; text-align: center; }\n"
      html << "  .palette-card img { max-width: 100%; height: 110mm; object-fit: contain; }\n"
      html << "  .poryadovka-start { counter-reset: page 8; page-break-before: always; }\n"
      html << "  h2 { color: #d35400; border-bottom: 2px solid #d35400; padding-bottom: 5px; margin-top: 0; }\n"
      html << "  h3 { color: #2c3e50; margin-top: 10px; margin-bottom: 5px; }\n"
      html << "  ul { margin-top: 5px; padding-left: 20px; }\n"
      html << "  li { margin-bottom: 5px; }\n"
      html << "</style>\n</head>\n<body>\n"

      # --- СТРАНИЦА 3: Главное превью проекта ---
      html << "<div class='tech-page' id='page-3'>\n"
      html << "  <h2>СТРАНИЦА 3: ОБЩИЙ ВИД ОТОПИТЕЛЬНОГО КОМПЛЕКСА (МОДЕЛЬ 4020-HM)</h2>\n"
      html << "  <div style='text-align:center; margin-top:10px;'>\n"
      html << "    <img src='#{drawings_dir}/main_preview.png' style='width:85%; max-height:150mm; object-fit:contain; border:1px solid #ddd; padding:5px;'>\n"
      html << "  </div>\n"
      html << "</div>\n"

      # --- СТРАНИЦА 4: Карта материалов (Часть 1 — Основной кирпич) ---
      html << "<div class='tech-page' id='page-4'>\n"
      html << "  <h2>СТРАНИЦА 4: КАРТА МАТЕРИАЛОВ — СТРОИТЕЛЬНАЯ КЕРАМИКА</h2>\n"
      html << "  <div class='grid-2-col' style='margin-top:15px;'>\n"
      html << "    <div class='palette-card'><h4>Лицевой кирпич (LF)</h4><img src='#{drawings_dir}/palette_brick_facade.png'><p style='font-size:10pt; font-weight:bold; margin-top:5px;'>Внешний контур комплекса (Шов 10 мм)</p></div>\n"
      html << "    <div class='palette-card'><h4>Строительный кирпич (SP)</h4><img src='#{drawings_dir}/palette_brick_building.png'><p style='font-size:10pt; font-weight:bold; margin-top:5px;'>Забутовка и внутренние ряды (Шов 10 мм)</p></div>\n"
      html << "  </div>\n"
      html << "</div>\n"

      # --- СТРАНИЦА 5: Карта материалов (Часть 2 — Огнеупоры и Литье) ---
      html << "<div class='tech-page' id='page-5'>\n"
      html << "  <h2>СТРАНИЦА 5: КАРТА МАТЕРИАЛОВ — ОГНЕУПОРЫ И ПЕЧНОЕ ЛИТЬЕ</h2>\n"
      html << "  <div class='grid-2-col' style='margin-top:15px;'>\n"
      html << "    <div class='palette-card'><h4>Шамот ШБ-8 (SH8)</h4><img src='#{drawings_dir}/palette_firebrick.png'><p style='font-size:10pt; font-weight:bold; margin-top:5px;'>Огнеупорное ядро топки (Горизонт 4 мм / Верт. 2 мм)</p></div>\n"
      html << "    <div class='palette-card'><h4>Печное литье (СГГО)</h4><img src='#{drawings_dir}/palette_iron.png'><p style='font-size:10pt; font-weight:bold; margin-top:5px;'>Фурнитура, задвижки и элементы монтажа литья</p></div>\n"
      html << "  </div>\n"
      html << "</div>\n"
      # --- СТРАНИЦА 6: Технические разрезы комплекса (Вид 1 и Вид 2 бок о бок) ---
      html << "<div class='tech-page' id='page-6'>\n"
      html << "  <h2>СТРАНИЦА 6: ТЕХНИЧЕСКИЕ РАЗРЕЗЫ КОМПЛЕКСА (ПРОФИЛИ И ВНУТРЕННИЕ КАНАЛЫ)</h2>\n"
      html << "  <div class='grid-2-col' style='margin-top:15px;'>\n"
      html << "    <div style='text-align:center; border:1px solid #eee; padding:5px; background:#fafafa;'>\n"
      html << "      <h4 style='margin-top:0; color:#2c3e50;'>Фронтальное сечение печи</h4>\n"
      html << "      <img src='#{drawings_dir}/section_1.png' style='width:100%; height:130mm; object-fit:contain;'>\n"
      html << "    </div>\n"
      html << "    <div style='text-align:center; border:1px solid #eee; padding:5px; background:#fafafa;'>\n"
      html << "      <h4 style='margin-top:0; color:#2c3e50;'>Продольное сечение (Дымообороты)</h4>\n"
      html << "      <img src='#{drawings_dir}/section_2.png' style='width:100%; height:130mm; object-fit:contain;'>\n"
      html << "    </div>\n"
      html << "  </div>\n"
      html << "</div>\n"

      # --- СТРАНИЦА 7: Общие правила строительства ---
      html << "<div class='tech-page' id='page-7'>\n"
      html << "  <h2>СТРАНИЦА 7: ОБЩИЕ ПРАВИЛА СТРОИТЕЛЬСТВА БАРБЕКЮ</h2>\n"
      html << "  <div class='grid-2-col' style='margin-top:15px; line-height: 1.5; font-size:11pt;'>\n"
      html << "    <div>\n"
      html << "      <h3>1. Противопожарные требования</h3>\n"
      html << "      <ul>\n"
      html << "        <li>Отступ от горючих конструкций стен: от 380 мм (без защиты) до 250 мм (с защитой асбестом 5 мм).</li>\n"
      html << "        <li>Проход кровельного перекрытия: термоизоляционная разделка из суперсила или базальтовой ваты.</li>\n"
      html << "        <li>Предтопочный лист: укладывается на пол перед топкой (металл или плитка, размер не менее 500х700 мм).</li>\n"
      html << "      </ul>\n"
      html << "      <h3>2. Подготовка и гидроизоляция</h3>\n"
      html << "      <ul>\n"
      html << "        <li>Обязательная укладка двух слоев рубероида на мастику поверх готовой бетонной плиты.</li>\n"
      html << "        <li>Выведение нулевого (подготовительного) ряда кирпича строго по строительному горизонту.</li>\n"
      html << "      </ul>\n"
      html << "    </div>\n"
      html << "    <div>\n"
      html << "      <h3>3. Технология кладки и растворы</h3>\n"
      html << "      <ul>\n"
      html << "        <li><b>Лицевой кирпич (LF):</b> укладывается на готовую печную смесь, толщина шва строго <b>10 мм</b>.</li>\n"
      html << "        <li><b>Забутовочный кирпич (SP):</b> толщина шва составляет <b>10 мм</b> для идеального совпадения рядов.</li>\n"
      html << "        <li><b>Шамотное ядро (SH8):</b> собирается на мертель. <b>Горизонтальный шов — 4 мм, вертикальный шов — 2 мм</b>.</li>\n"
      html << "        <li><b>Тепловой зазор:</b> жесткая перевязка красного кирпича с шамотным запрещена. Зазор 5–10 мм заполняется базальтовым картоном.</li>\n"
      html << "      </ul>\n"
      html << "      <h3>4. Просушка комплекса</h3>\n"
      html << "      <ul>\n"
      html << "        <li>Естественная сушка: не менее 10–14 дней при полностью открытых задвижках и дверцах.</li>\n"
      html << "        <li>Контрольный разгон: первые 3 дня топить исключительно сухой щепой не более 20 минут за сессию.</li>\n"
      html << "      </ul>\n"
      html << "    </div>\n"
      html << "  </div>\n"
      html << "</div>\n"

      # --- СТРАНИЦА 8: Инженерная спецификация фундамента ---
      html << "<div class='tech-page' id='page-8'>\n"
      html << "  <h2>СТРАНИЦА 8: ТЕХНОЛОГИЯ ФУНДАМЕНТА (УГЛОВОЙ РАЗРЕЗ ПЛИТЫ)</h2>\n"
      html << "  <div class='grid-2-col' style='margin-top:15px;'>\n"
      html << "    <div style='text-align:center;'>\n"
      html << "      <img src='#{drawings_dir}/foundation.png' style='max-width:100%; max-height:145mm; object-fit:contain; border:1px solid #ccc; padding:3px; background:#fff;'>\n"
      html << "    </div>\n"
      html << "    <div style='font-size:10.5pt; line-height:1.4;'>\n"
      html << "      <h3>Конструктивный пирог основания (Общая толщина 600 мм)</h3>\n"
      html << "      <table style='width:100%; border-collapse:collapse; margin-bottom:15px; font-size:10pt;' border='1' cellpadding='6' cellspacing='0'>\n"
      html << "        <tr style='background:#f2f2f2; text-align:left;'><th>№ Слоя (снизу вверх)</th><th>Толщина</th><th>Технические требования</th></tr>\n"
      html << "        <tr><td>1. Песчаная подготовка</td><td>100 мм</td><td>Намывной песок, послойное трамбование с проливкой водой</td></tr>\n"
      html << "        <tr><td>2. Дренажный слой</td><td>200 мм</td><td>Гранитный щебень фракции 20–40 мм для отвода грунтовых вод</td></tr>\n"
      html << "        <tr><td>3. Разделитель</td><td>—</td><td>Плотная полиэтиленовая пленка для удержания цементного молочка</td></tr>\n"
      html << "        <tr><td>4. Монолитная плита</td><td>300 мм</td><td>Товарный бетон марки М300 (В22.5) с обязательным вибрированием</td></tr>\n"
      html << "      </table>\n"
      html << "      <h3>Регламент двухъярусного армирования</h3>\n"
      html << "      <ul>\n"
      html << "        <li><b>Нижний ярус:</b> рабочая арматура А500С Ø12 мм, ячейка 150х150 мм. Защитный слой бетона снизу — 50 мм (на фиксаторах).</li>\n"
      html << "        <li><b>Верхний ярус:</b> рабочая арматура А500С Ø12 мм, ячейка 150х150 мм. Защитный слой бетона сверху — 30 мм.</li>\n"
      html << "        <li><b>Связка контуров:</b> вертикальные П-образные поддерживающие хомуты Ø8 мм с шагом 400 мм.</li>\n"
      html << "      </ul>\n"
      html << "    </div>\n"
      html << "  </div>\n"
      html << "</div>\n"
      
      # Сдвиг порядовок на страницу 9
      html << "<div class='poryadovka-start'>\n"
      html << "<!-- МЕСТО ДЛЯ ПОДКЛЮЧЕНИЯ РЯДОВ КЛАДКИ -->\n"
      html << "</div>\n"
      html << "</body>\n</html>"
      
      # Принудительное открытие дескриптора файла на перезапись
      begin
        File.open(file_path, "w:utf-8") { |f| f.write(html) }
        puts "[УСПЕХ] Файл принудительно перезаписан в папке 03_web_guide!"
      rescue => e
        puts "[ОШИБКА] Ошибка записи: #{e.message}"
      end
    end
  end
end

PechnikEngineeringHub::HtmlGenerator.generate
