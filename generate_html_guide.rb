# Encoding: UTF-8
# ==============================================================================
# ПРОЕКТ 4020-НМ / v69.0 -- МОДУЛЬ ГЕНЕРАЦИИ ВЕБ-РУКОВОДСТВА
# Файл: D:/pechnik-engineering-hub/00_my-scripts/generate_html_guide.rb
# Исполнители: ИИ-Ассистент / Полевой инженер Александр
# ==============================================================================

require 'json'       # Стандартная библиотека для конвертации массивов данных в формат JS
require 'fileutils'  # Библиотека для работы с файловой системой (создание папок)

# 1. ГЛОБАЛЬНАЯ ЛОКАЛЬНАЯ КОНФИГУРАЦИЯ ПУТЕЙ (ДИСК D)
BASE_DIR        = "D:/pechnik-engineering-hub"
SPEC_FILE       = File.join(BASE_DIR, "02_specifications/specification_summary.txt")
PNG_DIR         = File.join(BASE_DIR, "01_scenes")
OUTPUT_HTML     = File.join(BASE_DIR, "03_web_guide/index.html")

# 2. ФУНКЦИЯ ПАРСИНГА СМЕТНОГО BIM-ОТЧЕТА
def parse_specification(file_path)
  rows_data = {}        # Хэш-таблица, где ключом будет номер ряда, а значением - метрики кирпича
  total_summary = ""    # Буфер для накопления общей итоговой спецификации объекта
  current_section = :none # Флаг текущего состояния парсера при чтении файла

  # Проверка физического наличия файла сметы на диске D
  unless File.exist?(file_path)
    puts "[-] Ошибка конвейера: Файл сметы не найден по пути: #{file_path}"
    return nil, nil
  end

  # Построчное чтение файла с принудительной кодировкой UTF-8
  File.foreach(file_path, encoding: 'utf-8:utf-8') do |line|
    line.strip! # Удаляем лишние пробелы и символы переноса строки по краям
    next if line.empty? # Пропускаем пустые строки, чтобы не тратить ресурсы

    # Маркер начала блока итоговой спецификации всего объекта
    if line.include?("ИТОГОВАЯ СПЕЦИФИКАЦИЯ ОБЪЕКТА")
      current_section = :summary
      next
    # Маркер начала блока порядовой матрицы для Figma/Web
    elsif line.include?("МАТРИЦА ПОРЯДОВОГО РАСХОДА")
      current_section = :matrix
      next
    end

    # Если мы находимся внутри секции итога, просто аккумулируем строки
    if current_section == :summary
      total_summary << line << "\n"
    # Если мы внутри секции матрицы — разбираем регулярным выражением каждую строчку ряда
    elsif current_section == :matrix
      # Шаблон ищет: "Ряд [цифры] | [все остальное]"
      if line =~ /^Ряд\s+(\d+)\s*\|\s*(.*)$/
        row_num = $1.to_i      # Выделяем номер ряда и переводим в число (например, 1)
        metrics_str = $2       # Выделяем текстовую часть с метриками
        metrics = {}           # Локальный хэш для хранения пар Ключ:Значение текущего ряда
        
        # Разбиваем строку по разделителю "|" на отдельные параметры
        metrics_str.split('|').each do |part|
          key, val = part.split(':').map(&:strip) # Разделяем по ":" и чистим пробелы
          if key && val
            # Если значение состоит только из цифр — пишем как число, иначе — как текст (для литья)
            metrics[key] = val =~ /^\d+$/ ? val.to_i : val
          end
        end
        rows_data[row_num] = metrics # Записываем метрики ряда в общую базу данных
      end
    end
  end
  
  return rows_data, total_summary # Возвращаем собранные данные назад в точку вызова
end
# 3. ОСНОВНОЙ МЕТОД СБОРКИ ВЕБ-РУКОВОДСТВА
def generate_html
  puts "[+] Старт сборки интерактивного веб-руководства..."
  
  # Вызываем парсер из Шага 1 и получаем данные сметы
  rows_data, total_summary = parse_specification(SPEC_FILE)
  if rows_data.nil?
    puts "[-] Сборка аварийно остановлена из-за ошибок парсинга."
    return
  end

  # Автоматически создаем папку 03_web_guide на диске D, если её еще нет
  FileUtils.mkdir_p(File.dirname(OUTPUT_HTML))

  # Преобразуем собранный Ruby-хэш сметы в текстовую строку формата JSON для JavaScript
  rows_json = JSON.pretty_generate(rows_data)

  # Начинаем формировать текстовое тело HTML-документа
  html_content = <<~HTML
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Инженерное руководство: Проект 4020-НМ</title>
        <style>
            /* Глобальные цветовые переменные (ТЕМНАЯ ТЕМА для контраста на объекте) */
            :root {
                --bg-main: #121214;       /* Фон всей страницы */
                --bg-card: #1a1a1e;       /* Фон панелей и карточек */
                --accent: #ff5722;        /* Оранжевый печной акцент (активные элементы) */
                --accent-hover: #f4511e;  /* Цвет кнопок при наведении */
                --text-main: #e1e1e6;     /* Главный текст */
                --text-muted: #a8a8b3;    /* Второстепенный тусклый текст */
                --border: #29292e;        /* Тонкие разделительные границы */
            }
            
            /* Базовый сброс отступов и привязка системных шрифтов */
            * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }
            body { background-color: var(--bg-main); color: var(--text-main); display: flex; height: 100vh; overflow: hidden; }
            
            /* --- БОКОВАЯ ПАНЕЛЬ С КНОПКАМИ РЯДОВ --- */
            .sidebar { width: 320px; background-color: var(--bg-card); border-right: 1px solid var(--border); display: flex; flex-direction: column; }
            .sidebar-header { padding: 20px; border-bottom: 1px solid var(--border); }
            .sidebar-header h1 { font-size: 1.2rem; color: #fff; margin-bottom: 5px; display: flex; align-items: center; gap: 8px; }
            .sidebar-header p { font-size: 0.8rem; color: var(--text-muted); }
            
            /* Прокручиваемый контейнер с кнопками (чтобы меню не уходило за экран) */
            .row-selector { flex: 1; overflow-y: auto; padding: 10px; }
            
            /* Стили больших кнопок рядов для удобного нажатия пальцем на планшете */
            .row-btn { width: 100%; padding: 12px 15px; background: none; border: 1px solid transparent; border-radius: 6px; color: var(--text-main); text-align: left; font-size: 0.95rem; cursor: pointer; display: flex; justify-content: space-between; margin-bottom: 4px; transition: all 0.2s; }
            .row-btn:hover { background-color: var(--border); }
            .row-btn.active { background-color: var(--accent); color: #fff; font-weight: bold; }
            .row-btn .brick-count { font-size: 0.8rem; opacity: 0.8; }

            /* --- ГЛАВНАЯ РАБОЧАЯ ОБЛАСТЬ (ЭКРАНЫ И ПОДВАЛ) --- */
            .main-content { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
            
            /* Верхняя навигационная полоса */
            .top-bar { height: 60px; background-color: var(--bg-card); border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; padding: 0 30px; }
            .controls { display: flex; gap: 10px; }
            .nav-btn { padding: 8px 16px; background-color: var(--border); border: none; border-radius: 4px; color: #fff; cursor: pointer; font-weight: 600; }
            .nav-btn:hover { background-color: #3e3e44; }

            /* Контейнер двух графических окон (План и Изометрия) */
            .viewer-container { flex: 1; display: flex; gap: 20px; padding: 20px; overflow: hidden; }
            .view-pane { flex: 1; background-color: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; display: flex; flex-direction: column; overflow: hidden; position: relative; }
            
            /* Всплывающие ярлыки поверх чертежей */
            .pane-title { position: absolute; top: 15px; left: 15px; background: rgba(0,0,0,0.7); padding: 6px 12px; border-radius: 4px; font-size: 0.85rem; font-weight: bold; z-index: 10; border-left: 3px solid var(--accent); }
            
            /* Окна вывода PNG с центрированием и логикой соосного зума */
            .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; padding: 10px; }
            .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; transform: scale(1); transition: transform 0.2s; cursor: zoom-in; }

            /* --- ИНФОРМАЦИОННЫЙ ПОДВАЛ ДЛЯ СМЕТЫ РЯДА --- */
            .info-panel { height: 120px; background-color: var(--bg-card); border-top: 1px solid var(--border); padding: 20px 30px; display: flex; gap: 40px; }
            .stat-block { display: flex; flex-direction: column; justify-content: center; }
            .stat-label { font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 4px; }
            .stat-value { font-size: 1.4rem; font-weight: bold; color: #fff; }
            .stat-value span { color: var(--accent); }
        </style>
    </head>
    <body>
        <!-- 1. БОКОВАЯ ПАНЕЛЬ С КНОПКАМИ СЕЛЕКТОРА РЯДОВ -->
        <div class="sidebar">
            <div class="sidebar-header">
                <h1>🚀 ПРОЕКТ 4020-НМ</h1>
                <p>Полевой интерфейс v69.0 | Инженер: Александр</p>
            </div>
            <!-- Сюда функция init() автоматически добавит 54 кнопки -->
            <div class="row-selector" id="rowSelector"></div>
        </div>

        <!-- 2. ГЛАВНАЯ РАБОЧАЯ ОБЛАСТЬ (ЗАГОЛОВОК, КНОПКИ, ОКНА С ЧЕРТЕЖАМИ) -->
        <div class="main-content">
            <div class="top-bar">
                <h2 id="currentRowTitle">Ряд --</h2>
                <div class="controls">
                    <button class="nav-btn" onclick="changeRow(-1)">◀ Пред. Ряд</button>
                    <button class="nav-btn" onclick="changeRow(1)">След. Ряд ▶</button>
                </div>
            </div>

            <!-- Контейнер для двух независимых окон графического конвейера -->
            <div class="viewer-container">
                <!-- Левое окно: изолированный вид сверху -->
                <div class="view-pane">
                    <div class="pane-title">ПЛАН (ИЗОЛИРОВАННЫЙ ТОП-ВЬЮ)</div>
                    <div class="img-wrapper">
                        <img id="topViewImg" src="" alt="Top View" onclick="toggleZoom(this)">
                    </div>
                </div>
                <!-- Правое окно: накопительная изометрия ряда -->
                <div class="view-pane">
                    <div class="pane-title">ИЗОМЕТРИЯ (НАКОПИТЕЛЬНАЯ СБОРКА)</div>
                    <div class="img-wrapper">
                        <img id="isoViewImg" src="" alt="Iso View" onclick="toggleZoom(this)">
                    </div>
                </div>
            </div>

            <!-- 3. НИЖНИЙ ИНФОРМАЦИОННЫЙ ПОДВАЛ ДЛЯ ДИНАМИЧЕСКОЙ СМЕТЫ ТЕКУЩЕГО РЯДА -->
            <div class="info-panel" id="infoPanel"></div>
        </div>

        <!-- ============================================================================== -->
        <!-- БЛОК ИНТЕРАКТИВНОЙ СКРИПТОВОЙ ЛОГИКИ (JAVASCRIPT) -->
        <!-- ============================================================================== -->
        <script>
            const totalRows = 54; // Заданная высотность конструкции печи
            let currentRow = 1;   // Указатель на текущий активный ряд
            
            // Внедрение порядовой матрицы расхода, сгенерированной Ruby-парсером
            const matrixData = #{rows_json};

            // Относительные пути от index.html к графическому архиву PNG
            const topPath = "../01_scenes/top_view/";
            const isoPath = "../01_scenes/iso_view/";

            // Функция инициализации: генерирует кнопки рядов при загрузке страницы
            function init() {
                const selector = document.getElementById('rowSelector');
                for (let i = 1; i <= totalRows; i++) {
                    const btn = document.createElement('button');
                    btn.className = `row-btn ${i === 1 ? 'active' : ''}`;
                    btn.id = `btn_${i}`;
                    btn.onclick = () => selectRow(i);
                    
                    const data = matrixData[i] || {};
                    const totalBricks = (data['Фасад'] || 0) + (data['Строит'] || 0) + (data['Шамот'] || 0);
                    
                    btn.innerHTML = `<span>Ряд ${String(i).padStart(2, '0')}</span> <span class="brick-count">${totalBricks} шт.</span>`;
                    selector.appendChild(btn);
                }
                selectRow(1); // Активируем первый ряд по умолчанию
            }

            // Главный контроллер: переключение рядов, обновление картинок и скролл к кнопке
            function selectRow(rowNum) {
                document.getElementById(`btn_${currentRow}`).classList.remove('active');
                currentRow = rowNum;
                
                const activeBtn = document.getElementById(`btn_${currentRow}`);
                activeBtn.classList.add('active');
                activeBtn.scrollIntoView({ block: 'nearest', behavior: 'smooth' });

                document.getElementById('currentRowTitle').innerText = `РЯД ${String(currentRow).padStart(2, '0')} / 54`;

                const fileIndex = String(currentRow).padStart(2, '0');
                
                // Подмена изображений в графических панелях чертежей
                document.getElementById('topViewImg').src = `${topPath}row_${fileIndex}.png`;
                document.getElementById('isoViewImg').src = `${isoPath}row_${fileIndex}.png`;

                updateMetrics(currentRow); // Обновляем смету ряда в подвале
            }

            // Функция динамической отрисовки сметных показателей текущего ряда в подвале
            function updateMetrics(rowNum) {
                const panel = document.getElementById('infoPanel');
                const data = matrixData[rowNum] || { 'Фасад': 0, 'Строит': 0, 'Шамот': 0, 'Литье': 'Нет' };

                panel.innerHTML = `
                    <div class="stat-block">
                        <div class="stat-label">Облицовка (Фасад)</div>
                        <div class="stat-value"><span>${data['Фасад'] || 0}</span> шт.</div>
                    </div>
                    <div class="stat-block">
                        <div class="stat-label">Забутовка (Строит.)</div>
                        <div class="stat-value"><span>${data['Строит'] || 0}</span> шт.</div>
                    </div>
                    <div class="stat-block">
                        <div class="stat-label">Огнеупор (Шамот)</div>
                        <div class="stat-value"><span>${data['Шамот'] || 0}</span> шт.</div>
                    </div>
                    <div class="stat-block">
                        <div class="stat-label">Печное литье</div>
                        <div class="stat-value" style="font-size: 1.1rem; color: #ffb74d;">${data['Литье'] || '—'}</div>
                    </div>
                `;
            }

            // Функция инкремента/декремента шага для кнопок «Вперед / Назад»
            function changeRow(direction) {
                let target = currentRow + direction;
                if (target >= 1 && target <= totalRows) {
                    selectRow(target);
                }
            }

            // Функция соосного крупного зума (2.2х) при клике на чертеж для детального изучения швов
            function toggleZoom(img) {
                if (img.style.transform === "scale(2.2)") {
                    img.style.transform = "scale(1)";
                    img.style.cursor = "zoom-in";
                } else {
                    img.style.transform = "scale(2.2)";
                    img.style.cursor = "zoom-out";
                }
            }

            // Управление с клавиатуры: стрелки влево/вверх (назад) и вправо/вниз (вперед)
            document.addEventListener('keydown', (e) => {
                if (e.key === 'ArrowRight' || e.key === 'ArrowDown') changeRow(1);
                if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') changeRow(-1);
            });

            // Назначение стартового триггера загрузки
            window.onload = init;
        </script>
    </body>
    </html>
  HTML

  # Запись сформированной строки в файл index.html в кодировке UTF-8
  File.write(OUTPUT_HTML, html_content, mode: 'w:utf-8')
  puts "[+] Веб-руководство успешно сгенерировано: #{OUTPUT_HTML}"
end

# Запуск генератора при прямом автономном вызове (например, из BAT-файла)
generate_html if __FILE__ == $0
