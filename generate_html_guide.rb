# Encoding: UTF-8
# ==============================================================================
# ПРОЕКТ 4020-НМ / v76.6 -- ВЕБ-ГЕНЕРАТОР РУКОВОДСТВА (ПОБЛОЧНАЯ СБОРКА)
# Файл: generate_html_guide.rb — ЧАСТЬ 1: РУБИ-ЯДРО И ПАРСЕР СМЕТЫ
# ==============================================================================

require 'json'
require 'fileutils'

# Жесткие константы путей окружения (База D:)
BASE_DIR = "D:/pechnik-engineering-hub"
SPEC_FILE = File.join(BASE_DIR, "02_specifications/specification_summary.txt")
OUTPUT_HTML = File.join(BASE_DIR, "03_web_guide/index.html")

# Справочник постоянных технологических заметок к рядам (Заполняется один раз)
DEFAULT_NOTES = {
  1  => "Фундаментный ряд. Проверить диагонали основания и горизонталь по уровню.",
  2  => "Монтаж поддувальной дверцы. Уложить базальтовый картон 5 мм по периметру тоннеля.",
  5  => "Формирование пода топливника. Выдерживать тепловой зазор между шамотом и облицовкой.",
  12 => "Перекрытие топочной дверцы. Проверить надежность замкового кирпича.",
  # Для остальных рядов, которых нет в этом списке, система сама напишет дефолтный текст.
}

def parse_specification(file_path)
  rows_data = {}
  current_section = :none

  unless File.exist?(file_path)
    puts "[-] Ошибка: Текстовый файл сметы не обнаружен по пути: #{file_path}"
    return nil
  end

  File.foreach(file_path, encoding: 'utf-8:utf-8') do |line|
    clean_line = line.strip
    next if clean_line.empty?

    up_line = clean_line.upcase

    if up_line.include?("МАТРИЦА ПОРЯДОВОГО РАСХОДА")
      current_section = :matrix
      next
    elsif up_line.include?("ИТОГОВЫЙ СВОДНЫЙ РАСХОД") || up_line.include?("ПРАКТИЧЕСКИЙ РАСХОД")
      current_section = :none
    end

    if current_section == :matrix
      if clean_line =~ /^[Рр]яд\s*(\d+)/
        row_num = $1.to_i
        
        parts = clean_line.split('|').map(&:strip)
        if parts.length >= 5
          facade_val = parts.at(1) ? parts.at(1).gsub(/[^\d.]/, '').to_f : 0.0
          stroit_val = parts.at(2) ? parts.at(2).gsub(/[^\d.]/, '').to_f : 0.0
          shamot_val = parts.at(3) ? parts.at(3).gsub(/[^\d.]/, '').to_f : 0.0
          
          raw_casting = parts.at(4) ? parts.at(4).gsub(/^[Лл]итье\s*:\s*/i, '').strip : "Нет"
          
          # Группировка повторяющегося литья
          if raw_casting != "Нет" && !raw_casting.empty?
            items_counts = Hash.new(0)
            raw_casting.split(',').each do |item|
              item.strip!
              next if item.empty?
              
              if item =~ /^(.*)\s*\((\d+)\s*шт\)/i
                name = $1.strip
                count = $2.to_i
              else
                name = item
                count = 1
              end
              items_counts[name] += count
            end
            
            grouped_arr = []
            items_counts.each do |name, total_qty|
              grouped_arr << "#{name} (#{total_qty} шт)"
            end
            casting_val = grouped_arr.join(', ')
          else
            casting_val = "Нет"
          end

          # --- ЖЕСТКАЯ ПРИВЯЗКА ВСТРОЕННЫХ ЗАМЕТОК ИЗ СПРАВОЧНИКА ---
          # Ищем заметку в нашей карте DEFAULT_NOTES по номеру ряда
          note_val = DEFAULT_NOTES.fetch(row_num, "Технические примечания к данному ряду отсутствуют.")

          rows_data[row_num] = {
            'facade' => facade_val,
            'stroit' => stroit_val,
            'shamot' => shamot_val,
            'casting' => casting_val,
            'note'    => note_val # Заметка улетает во фронтенд намертво
          }
        end
      end
    end
  end

  rows_data
end
# ==============================================================================
# ЧАСТЬ 2: ГЕНЕРАТОР HTML И CSS СТИЛИ ИНТЕРФЕЙСА (v77.1 С ВСТРОЕННЫМИ СНОСКАМИ)
# ==============================================================================

def generate_html
  puts "[+] Старт сборки интерактивного веб-руководства v77.1..."
  rows_data = parse_specification(SPEC_FILE)

  if rows_data.nil? || rows_data.empty?
    puts "[-] Сборка аварийно остановлена: данные в матрице не найдены."
    return
  end

  FileUtils.mkdir_p(File.dirname(OUTPUT_HTML))
  rows_json = JSON.generate(rows_data)

  html_content = <<~HTML
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Руководство: Проект 4020-НМ</title>
        <style>
            :root {
                --bg-main: #121214;
                --bg-card: #1a1a1e;
                --accent: #ff5722;
                --text-main: #e1e1e6;
                --text-muted: #a8a8b3;
                --border: #29292e;
                --success: #4caf50;
                --info-bg: #1e1e24;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, sans-serif; }
            body { background-color: var(--bg-main); color: var(--text-main); display: flex; height: 100vh; overflow: hidden; }
            
            /* Боковая панель */
            .sidebar { width: 320px; background-color: var(--bg-card); border-right: 1px solid var(--border); display: flex; flex-direction: column; }
            .sidebar-header { padding: 20px; border-bottom: 1px solid var(--border); }
            .sidebar-header h1 { font-size: 1.1rem; color: #fff; margin-bottom: 4px; }
            .sidebar-header p { font-size: 0.75rem; color: var(--text-muted); }
            
            .total-summary-btn { margin: 10px; padding: 12px; background-color: #202024; border: 1px dashed var(--accent); border-radius: 6px; color: #fff; text-align: center; font-size: 0.85rem; font-weight: bold; cursor: pointer; transition: background 0.2s; }
            .total-summary-btn:hover { background-color: rgba(255, 87, 34, 0.1); }
            
            .row-selector { flex: 1; overflow-y: auto; padding: 0 10px 10px 10px; }
            
            .row-btn { width: 100%; padding: 10px 12px; background: none; border: 1px solid transparent; border-radius: 6px; color: var(--text-main); text-align: left; font-size: 0.9rem; cursor: pointer; display: flex; justify-content: space-between; margin-bottom: 4px; }
            .row-btn:hover { background-color: var(--border); }
            .row-btn.active { background-color: var(--accent); color: #fff; font-weight: bold; }
            .row-btn .brick-count { font-size: 0.75rem; opacity: 0.8; }
            
            /* Основная зона */
            .main-content { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
            .top-bar { height: 50px; background-color: var(--bg-card); border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; padding: 0 20px; }
            
            .mode-switch { display: flex; background-color: #202024; padding: 3px; border-radius: 6px; border: 1px solid var(--border); }
            .mode-tab { padding: 4px 10px; font-size: 0.75rem; border-radius: 4px; cursor: pointer; border: none; color: var(--text-muted); background: none; }
            .mode-tab.active { background-color: var(--accent); color: #fff; font-weight: bold; }
            
            .nav-btn { padding: 6px 12px; background-color: var(--border); border: none; border-radius: 4px; color: #fff; cursor: pointer; font-size: 0.85rem; }
            .nav-btn:hover { background-color: var(--accent); }
            
            /* Экраны чертежей */
            .viewer-container { flex: 1; display: flex; gap: 15px; padding: 15px 15px 5px 15px; overflow: hidden; }
            .view-pane { flex: 1; background-color: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; display: flex; flex-direction: column; overflow: hidden; position: relative; }
            .pane-title { position: absolute; top: 10px; left: 10px; background: rgba(0, 0, 0, 0.75); padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: bold; z-index: 10; border-left: 3px solid var(--accent); }
            
            /* Виджет информационных сносок */
            .note-container { height: 65px; margin: 0 15px 10px 15px; padding: 10px 15px; background-color: var(--info-bg); border: 1px solid var(--border); border-left: 4px solid var(--border); border-radius: 4px; display: flex; align-items: center; overflow-y: auto; }
            .note-container.has-note { border-left-color: var(--accent); background-color: #1f1a16; }
            .note-text { font-size: 0.85rem; line-height: 1.3; color: var(--text-main); }
            .note-text span { font-weight: bold; color: var(--accent); margin-right: 5px; }

            /* Нижний виджет подсчета материалов */
            .info-panel { height: 90px; background-color: var(--bg-card); border-top: 1px solid var(--border); padding: 15px 20px; display: flex; gap: 30px; overflow-x: auto; }
            .stat-block { display: flex; flex-direction: column; justify-content: center; min-width: 120px; }
            .stat-label { font-size: 0.7rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 2px; }
            .stat-value { font-size: 1.2rem; font-weight: bold; color: #fff; }
            .stat-value span { color: var(--accent); }
            .stat-value.accum span { color: var(--success); }
            
            /* Модальное окно */
            .modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); z-index: 1000; align-items: center; justify-content: center; }
            .modal-content { background: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; width: 500px; max-width: 90%; padding: 25px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
            .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 1px solid var(--border); padding-bottom: 10px; }
            .modal-close { background: none; border: none; color: var(--text-muted); font-size: 1.4rem; cursor: pointer; }
            .modal-close:hover { color: var(--accent); }
            .summary-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px dashed #29292e; font-size: 0.9rem; }
            .summary-row strong { color: var(--accent); }
            
            .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; background: #0f0f11; padding: 10px; }
            .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; transition: transform 0.2s; cursor: zoom-in; transform-origin: center center; }
            .img-wrapper img.zoomed { transform: scale(2.2); cursor: zoom-out; max-width: none; max-height: none; }
        </style>
    </head>
    <body>
        <div class="sidebar">
            <div class="sidebar-header">
                <h1>🚀 ПРОЕКТ 4020-НМ</h1>
                <p>Полевой веб-интерфейс v77.1 | Александр</p>
            </div>
            <div class="total-summary-btn" onclick="toggleModal(true)">📋 ОБЩАЯ СМЕТА ОБЪЕКТА</div>
            <div class="row-selector" id="rowSelector"></div>
        </div>
        <div class="main-content">
            <div class="top-bar">
                <h2 id="currentRowTitle">Ряд --</h2>
                <div class="mode-switch">
                    <button class="mode-tab active" id="tabRow" onclick="setMode('row')">НА РЯД</button>
                    <button class="mode-tab" id="tabAccum" onclick="setMode('accum')">НАКОПИТЕЛЬНО</button>
                </div>
                <div class="controls">
                    <button class="nav-btn" onclick="changeRow(-1)">◀ Пред.</button>
                    <button class="nav-btn" onclick="changeRow(1)">След. ▶</button>
                </div>
            </div>
            
            <div class="viewer-container">
                <div class="view-pane">
                    <div class="pane-title">ПЛАН (ТОП-ВЬЮ)</div>
                    <div class="img-wrapper"><img id="topViewImg" src="" onclick="toggleZoom(this)"></div>
                </div>
                <div class="view-pane">
                    <div class="pane-title">ИЗОМЕТРИЯ (НАКОПИТЕЛЬНО)</div>
                    <div class="img-wrapper"><img id="isoViewImg" src="" onclick="toggleZoom(this)"></div>
                </div>
            </div>
            
            <div class="note-container" id="rowNoteBlock">
                <div class="note-text" id="rowNoteText">Технические примечания к данному ряду отсутствуют.</div>
            </div>
            
            <div class="info-panel" id="infoPanel"></div>
        </div>

        <div class="modal-overlay" id="summaryModal" onclick="if(event.target===this) toggleModal(false)">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>📊 Итоговая смета объекта</h3>
                    <button class="modal-close" onclick="toggleModal(false)">&times;</button>
                </div>
                <div id="modalSummaryBody"></div>
            </div>
        </div>
  HTML
  # Формируем JavaScript-движок и закрываем HTML структуру
  html_javascript = <<~HTML
        <script>
            // Прямая интерполяция сгенерированной JSON-строки из Ruby
            const matrixData = #{rows_json};
            
            // Получаем строго отсортированный массив номеров рядов
            const sortedRows = Object.keys(matrixData).map(Number).sort((a, b) => a - b);
            
            // Задаем начальные параметры рабочего режима
            let currentRow = sortedRows.length > 0 ? sortedRows[0] : 1;
            let displayMode = 'row'; 
            
            const topPath = "../01_scenes/top_view/";
            const isoPath = "../01_scenes/iso_view/";

            function init() {
                const selector = document.getElementById('rowSelector');
                if (sortedRows.length === 0) {
                    selector.innerHTML = '<p style="padding: 10px; color: var(--text-muted);">Данные рядов отсутствуют</p>';
                    return;
                }

                // Выводим интерактивные кнопки только для существующих в смете рядов
                sortedRows.forEach(i => {
                    const btn = document.createElement('button');
                    btn.className = 'row-btn' + (i === currentRow ? ' active' : '');
                    btn.id = 'btn_' + i;
                    btn.onclick = function() { selectRow(i); };

                    const data = matrixData[i] || { 'facade': 0, 'stroit': 0, 'shamot': 0 };
                    const total = (Number(data['facade']) || 0) + (Number(data['stroit']) || 0) + (Number(data['shamot']) || 0);
                    
                    btn.innerHTML = '<span>Ряд ' + String(i).padStart(2, '0') + '</span> <span class="brick-count">' + total.toFixed(1) + ' шт.</span>';
                    selector.appendChild(btn);
                });

                buildTotalSummary();
                selectRow(currentRow);
            }

            // Математический расчет общей сметы объекта по всей матрице
            function buildTotalSummary() {
                let totalFacade = 0, totalStroit = 0, totalShamot = 0;
                let castingList = new Set();

                sortedRows.forEach(i => {
                    const data = matrixData[i] || {};
                    totalFacade += Number(data['facade']) || 0;
                    totalStroit += Number(data['stroit']) || 0;
                    totalShamot += Number(data['shamot']) || 0;
                    
                    if (data['casting'] && data['casting'] !== 'Нет') {
                        data['casting'].split(',').forEach(c => castingList.add(c.trim ? c.trim() : c));
                    }
                });

                const modalBody = document.getElementById('modalSummaryBody');
                let castingHtml = '';
                castingList.forEach(c => { castingHtml += '<div style="font-size:0.85rem;color:#ffb74d;">• ' + c + '</div>'; });
                if(!castingHtml) castingHtml = '<div style="color:var(--text-muted)">Не обнаружено</div>';

                modalBody.innerHTML = 
                    '<div class="summary-row"><span>Облицовка (LF):</span><strong>' + totalFacade.toFixed(1) + ' шт.</strong></div>' +
                    '<div class="summary-row"><span>Забутовка (SP):</span><strong>' + totalStroit.toFixed(1) + ' шт.</strong></div>' +
                    '<div class="summary-row"><span>Шамот (SH8):</span><strong>' + totalShamot.toFixed(1) + ' шт.</strong></div>' +
                    '<div class="summary-row" style="border-bottom:1px solid var(--border);margin-bottom:15px;"><span>Всего кирпича:</span><strong>' + (totalFacade + totalStroit + totalShamot).toFixed(1) + ' шт.</strong></div>' +
                    '<h4 style="font-size:0.85rem;margin-bottom:8px;text-transform:uppercase;color:var(--text-muted)">Сводное литье на объекте:</h4>' + castingHtml;
            }

            function setMode(mode) {
                displayMode = mode;
                document.getElementById('tabRow').classList.toggle('active', mode === 'row');
                document.getElementById('tabAccum').classList.toggle('active', mode === 'accum');
                updateMetrics(currentRow);
            }

            function selectRow(rowNum) {
                const oldBtn = document.getElementById('btn_' + currentRow);
                if (oldBtn) oldBtn.classList.remove('active');
                
                currentRow = rowNum;
                
                const activeBtn = document.getElementById('btn_' + currentRow);
                if (activeBtn) {
                    activeBtn.classList.add('active');
                    activeBtn.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
                }

                const maxRow = Math.max(...sortedRows);
                document.getElementById('currentRowTitle').innerText = 'РЯД ' + String(currentRow).padStart(2, '0') + ' / ' + String(maxRow).padStart(2, '0');
                
                const fileIndex = String(currentRow).padStart(2, '0');
                document.getElementById('topViewImg').src = topPath + 'row_' + fileIndex + '.png';
                document.getElementById('isoViewImg').src = isoPath + 'row_' + fileIndex + '.png';
                
                updateMetrics(currentRow);
            }
  HTML
  # Финальный JavaScript-хвост и закрывающие теги HTML структуры
  html_javascript_tail = <<~HTML
            function updateMetrics(rowNum) {
                const panel = document.getElementById('infoPanel');
                const noteBlock = document.getElementById('rowNoteBlock');
                const noteText = document.getElementById('rowNoteText');
                
                let facadeQty = 0, stroitQty = 0, shamotQty = 0;
                let castingText = 'Нет';
                
                // Извлекаем примечание ряда из JSON
                const currentData = matrixData[rowNum] || {};
                const rowNote = currentData['note'] || 'Технические примечания к данному ряду отсутствуют.';

                if (displayMode === 'row') {
                    facadeQty = Number(currentData['facade']) || 0;
                    stroitQty = Number(currentData['stroit']) || 0;
                    shamotQty = Number(currentData['shamot']) || 0;
                    castingText = currentData['casting'] || 'Нет';
                    
                    // В режиме "НА РЯД" выводим встроенную сноску текущего ряда
                    if (rowNote.includes('отсутствуют')) {
                        noteBlock.classList.remove('has-note');
                        noteText.innerHTML = rowNote;
                    } else {
                        noteBlock.classList.add('has-note');
                        noteText.innerHTML = '<span>ИНФО:</span>' + rowNote;
                    }
                } else {
                    // Режим НАКОПИТЕЛЬНОГО ИТОГА
                    sortedRows.forEach(i => {
                        if (i <= rowNum) {
                            const data = matrixData[i] || {};
                            facadeQty += Number(data['facade']) || 0;
                            stroitQty += Number(data['stroit']) || 0;
                            shamotQty += Number(data['shamot']) || 0;
                        }
                    });
                    castingText = 'Смотри послойно в общей смете объекта';
                    
                    // В накопительном режиме временно переключаем подсказку виджета
                    noteBlock.classList.remove('has-note');
                    noteText.innerHTML = 'Включен режим накопительного итога с 1 по ' + rowNum + ' ряд. Сноски доступны в режиме "НА РЯД".';
                }
                
                const labelSuffix = displayMode === 'row' ? '' : ' (Всего)';
                const valClass = displayMode === 'row' ? 'stat-value' : 'stat-value accum';

                panel.innerHTML = 
                    '<div class="stat-block"><div class="stat-label">Облицовка' + labelSuffix + '</div><div class="' + valClass + '"><span>' + facadeQty.toFixed(1) + '</span> шт.</div></div>' +
                    '<div class="stat-block"><div class="stat-label">Забутовка' + labelSuffix + '</div><div class="' + valClass + '"><span>' + stroitQty.toFixed(1) + '</span> шт.</div></div>' +
                    '<div class="stat-block"><div class="stat-label">Шамот' + labelSuffix + '</div><div class="' + valClass + '"><span>' + shamotQty.toFixed(1) + '</span> шт.</div></div>' +
                    '<div class="stat-block"><div class="stat-label">Печное литье</div><div class="stat-value" style="font-size: 0.85rem; color: #ffb74d; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="' + castingText + '">' + castingText + '</div></div>';
            }

            function changeRow(direction) {
                const currentIndex = sortedRows.indexOf(currentRow);
                const targetIndex = currentIndex + direction;
                if (targetIndex >= 0 && targetIndex < sortedRows.length) {
                    selectRow(sortedRows[targetIndex]);
                }
            }

            function toggleZoom(img) {
                img.classList.toggle('zoomed');
            }

            function toggleModal(show) {
                document.getElementById('summaryModal').style.display = show ? 'flex' : 'none';
            }

            document.addEventListener('keydown', function(e) {
                if (e.key === 'ArrowRight' || e.key === 'ArrowDown') changeRow(1);
                if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') changeRow(-1);
                if (e.key === 'Escape') toggleModal(false);
            });

            window.onload = init;
        </script>
    </body>
    </html>
  HTML

  # Полная склейка макета и фиксация на диске
  full_html = html_content + html_javascript + html_javascript_tail
  File.write(OUTPUT_HTML, full_html, mode: 'w:utf-8')
  puts "[+] Полевой интерфейс v77.1 успешно сгенерирован: #{OUTPUT_HTML}"
end

# Автоматический запуск сборщика при вызове скрипта
generate_html
