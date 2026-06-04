# Encoding: UTF-8
# ==============================================================================
# ПРОЕКТ 4020-НМ / v74.1 -- ВЕБ-ГЕНЕРАТОР РУКОВОДСТВА (ЧАСТЬ 1: ЧИСТЫЙ ПАРСЕР)
# Файл: D:/pechnik-engineering-hub/00_my-scripts/generate_html_guide.rb
# ==============================================================================

require 'json'
require 'fileutils'

# 1. ЖЕСТКАЯ СИНХРОНИЗАЦИЯ СМЕТНОГО КАНАЛА
BASE_DIR        = "D:/pechnik-engineering-hub"
SPEC_FILE       = File.join(BASE_DIR, "02_specifications/specification_summary.txt")
OUTPUT_HTML     = File.join(BASE_DIR, "03_web_guide/index.html")

def parse_specification(file_path)
  rows_data = {}
  current_section = :none

  unless File.exist?(file_path)
    puts "[-] Ошибка: Файл сметы не найден по пути: #{file_path}"
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
      if clean_line =~ /[Рр]яд\s*(\d+)/
        row_num = $1.to_i
        
        # Режем строго по вертикальной черте |
        parts = clean_line.split('|').map(&:strip)
        
        if parts.length >= 4
          # ЧЕТКИЕ ИНДЕКСЫ КОЛОНОК БЕЗ СБОЕВ ПЕРЕДАЧИ ТЕКСТА
          facade_val   = parts[1] ? parts[1].gsub(/[^\d.]/, '').to_f : 0.0
          stroit_val   = parts[2] ? parts[2].gsub(/[^\d.]/, '').to_f : 0.0
          shamot_val   = parts[3] ? parts[3].gsub(/[^\d.]/, '').to_f : 0.0
          
          # Литье забираем чистым текстом из 5-й ячейки (индекс 4)
          casting_val = parts[4] ? parts[4].gsub(/[Лл]итье\s*:\s*/, '').strip : "Нет"

          rows_data[row_num] = {
            'facade'  => facade_val,
            'stroit'  => stroit_val,
            'shamot'  => shamot_val,
            'casting' => casting_val
          }
        end
      end
    end
  end
  rows_data
end
# 3. МЕТОД СБОРКИ ВЕБ-РУКОВОДСТВА
def generate_html
  puts "[+] Старт сборки интерактивного веб-руководства..."
  rows_data = parse_specification(SPEC_FILE)
  if rows_data.nil?
    puts "[-] Сборка аварийно остановлена."
    return
  end

  FileUtils.mkdir_p(File.dirname(OUTPUT_HTML))
  
  # ПРИНУДИТЕЛЬНАЯ ГЕНЕРАЦИЯ ЧИСТОГО JSON БЕЗ СИМВОЛЬНЫХ КЛЮЧЕЙ
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
                --bg-main: #121214; --bg-card: #1a1a1e;
                --accent: #ff5722; --text-main: #e1e1e6;
                --text-muted: #a8a8b3; --border: #29292e;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, sans-serif; }
            body { background-color: var(--bg-main); color: var(--text-main); display: flex; height: 100vh; overflow: hidden; }
            .sidebar { width: 320px; background-color: var(--bg-card); border-right: 1px solid var(--border); display: flex; flex-direction: column; }
            .sidebar-header { padding: 20px; border-bottom: 1px solid var(--border); }
            .sidebar-header h1 { font-size: 1.1rem; color: #fff; margin-bottom: 4px; }
            .sidebar-header p { font-size: 0.75rem; color: var(--text-muted); }
            .row-selector { flex: 1; overflow-y: auto; padding: 10px; }
            .row-btn { width: 100%; padding: 10px 12px; background: none; border: 1px solid transparent; border-radius: 6px; color: var(--text-main); text-align: left; font-size: 0.9rem; cursor: pointer; display: flex; justify-content: space-between; margin-bottom: 4px; }
            .row-btn:hover { background-color: var(--border); }
            .row-btn.active { background-color: var(--accent); color: #fff; font-weight: bold; }
            .row-btn .brick-count { font-size: 0.75rem; opacity: 0.8; }
            .main-content { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
            .top-bar { height: 50px; background-color: var(--bg-card); border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; padding: 0 20px; }
            .nav-btn { padding: 6px 12px; background-color: var(--border); border: none; border-radius: 4px; color: #fff; cursor: pointer; font-size: 0.85rem; }
            .viewer-container { flex: 1; display: flex; gap: 15px; padding: 15px; overflow: hidden; }
            .view-pane { flex: 1; background-color: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; display: flex; flex-direction: column; overflow: hidden; position: relative; }
            .pane-title { position: absolute; top: 10px; left: 10px; background: rgba(0,0,0,0.75); padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: bold; z-index: 10; border-left: 3px solid var(--accent); }
            .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; }
            .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; transition: transform 0.2s; cursor: zoom-in; }
            .info-panel { height: 90px; background-color: var(--bg-card); border-top: 1px solid var(--border); padding: 15px 20px; display: flex; gap: 30px; }
            .stat-block { display: flex; flex-direction: column; justify-content: center; }
            .stat-label { font-size: 0.7rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 2px; }
            .stat-value { font-size: 1.2rem; font-weight: bold; color: #fff; }
            .stat-value span { color: var(--accent); }
        </style>
    </head>
    <body>
        <div class="sidebar">
            <div class="sidebar-header">
                <h1>🚀 ПРОЕКТ 4020-НМ</h1>
                <p>Полевой веб-интерфейс v74.7 | Александр</p>
            </div>
            <div class="row-selector" id="rowSelector"></div>
        </div>
        <div class="main-content">
            <div class="top-bar">
                <h2 id="currentRowTitle">Ряд --</h2>
                <div class="controls">
                    <button class="nav-btn" onclick="changeRow(-1)">◀ Пред.</button>
                    <button class="nav-btn" onclick="changeRow(1)">След. ▶</button>
                </div>
            </div>
            <div class="viewer-container">
                <div class="view-pane"><div class="pane-title">ПЛАН (ТОП-ВЬЮ)</div><div class="img-wrapper"><img id="topViewImg" src="" onclick="toggleZoom(this)"></div></div>
                <div class="view-pane"><div class="pane-title">ИЗОМЕТРИЯ (НАКОПИТЕЛЬНО)</div><div class="img-wrapper"><img id="isoViewImg" src="" onclick="toggleZoom(this)"></div></div>
            </div>
            <div class="info-panel" id="infoPanel"></div>
        </div>
        <script>
            const totalRows = 54; let currentRow = 1;
            
            // Прямая вставка JSON-строки
            const matrixData = #{rows_json};
            const topPath = "../01_scenes/top_view/"; const isoPath = "../01_scenes/iso_view/";

            function init() {
                const selector = document.getElementById('rowSelector');
                for (let i = 1; i <= totalRows; i++) {
                    const btn = document.createElement('button');
                    btn.className = `row-btn \${i === 1 ? 'active' : ''}`;
                    btn.id = `btn_\${i}`; btn.onclick = () => selectRow(i);
                    
                    // Защита от неопределенного значения ключа ряда конструктора
                    const data = matrixData[String(i)] || matrixData[i] || { 'facade': 0, 'stroit': 0, 'shamot': 0 };
                    const total = (Number(data['facade']) || 0) + (Number(data['stroit']) || 0) + (Number(data['shamot']) || 0);
                    
                    btn.innerHTML = `<span>Ряд \${String(i).padStart(2, '0')}</span> <span class="brick-count">\${total.round(1)} шт.</span>`;
                    selector.appendChild(btn);
                }
                selectRow(1);
            }
            Number.prototype.round = function(p) { const n = Math.pow(10, p); return Math.round(this * n) / n; };

            function selectRow(rowNum) {
                document.getElementById(`btn_\${currentRow}`).classList.remove('active');
                currentRow = rowNum;
                const activeBtn = document.getElementById(`btn_\${currentRow}`);
                activeBtn.classList.add('active'); activeBtn.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
                document.getElementById('currentRowTitle').innerText = `РЯД \${String(currentRow).padStart(2, '0')} / 54`;
                const fileIndex = String(currentRow).padStart(2, '0');
                document.getElementById('topViewImg').src = `\${topPath}row_\${fileIndex}.png`;
                document.getElementById('isoViewImg').src = `\${isoPath}row_\${fileIndex}.png`;
                updateMetrics(currentRow);
            }

            function updateMetrics(rowNum) {
                const panel = document.getElementById('infoPanel');
                const data = matrixData[String(rowNum)] || matrixData[rowNum] || { 'facade': 0, 'stroit': 0, 'shamot': 0, 'casting': 'Нет' };
                panel.innerHTML = `
                    <div class="stat-block"><div class="stat-label">Облицовка (Фасад)</div><div class="stat-value"><span>\${data['facade'] || 0}</span> шт.</div></div>
                    <div class="stat-block"><div class="stat-label">Забутовка (Строит)</div><div class="stat-value"><span>\${data['stroit'] || 0}</span> шт.</div></div>
                    <div class="stat-block"><div class="stat-label">Шамот</div><div class="stat-value"><span>\${data['shamot'] || 0}</span> шт.</div></div>
                    <div class="stat-block"><div class="stat-label">Печное литье</div><div class="stat-value" style="font-size: 1rem; color: #ffb74d;">\${data['casting'] || '—'}</div></div>
                `;
            }

            function changeRow(direction) { let target = currentRow + direction; if (target >= 1 && target <= totalRows) selectRow(target); }
            function toggleZoom(img) { img.style.transform = (img.style.transform === "scale(2.2)") ? "scale(1)" : "scale(2.2)"; }
            document.addEventListener('keydown', (e) => {
                if (e.key === 'ArrowRight' || e.key === 'ArrowDown') changeRow(1);
                if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') changeRow(-1);
            });
            window.onload = init;
        </script>
    </body>
    </html>
  HTML

  File.write(OUTPUT_HTML, html_content, mode: 'w:utf-8')
  puts "[+] Руководство успешно сгенерировано: #{OUTPUT_HTML}"
end

generate_html
