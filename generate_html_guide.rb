# Encoding: UTF-8
# ==============================================================================
# ПРОЕКТ 4020-НМ / v77.6 -- СЖАТЫЙ ВЕБ-ГЕНЕРАТОР PDF/HTML (ПОБЛОЧНАЯ СБОРКА)
# Файл: generate_html_guide.rb — ЧАСТЬ 1: БЭКЕНД И УМНЫЙ ПАРСЕР ТАБЛИЦЫ v76.6
# ==============================================================================

require 'json'
require 'fileutils'

BASE_DIR = "D:/pechnik-engineering-hub"
SPEC_FILE = File.join(BASE_DIR, "02_specifications/specification_summary.txt")
OUTPUT_HTML = File.join(BASE_DIR, "03_web_guide/index.html")

# Встроенный справочник постоянных технологических заметок к рядам
DEFAULT_NOTES = {
  1 => "Фундаментный ряд. Проверить диагонали основания и горизонталь по уровню.",
  2 => "Монтаж поддувальной дверцы. Уложить базальтовый картон 5 мм по периметру тоннеля.",
  5 => "Формирование пода топливника. Выдерживать тепловой зазор между шамотом и облицовкой.",
  12 => "Перекрытие топочной дверцы. Проверить надежность замкового кирпича."
}

def parse_specification(file_path)
  rows_data = {}
  current_section = :none
  
  return nil unless File.exist?(file_path)

  File.foreach(file_path, encoding: 'utf-8:utf-8') do |line|
    clean_line = line.strip
    next if clean_line.empty?
    up_line = clean_line.upcase

    # Строгий вход в таблицу по маркеру ядра v76.6
    if up_line.include?("МАТРИЦА ПОРЯДОВОГО РАСХОДА")
      current_section = :matrix
      next
    elsif up_line.include?("ПЕЧНОЕ ЛИТЬЕ И ИНЖЕНЕРНОЕ ОБОРУДОВАНИЕ") || up_line.include?("ИТОГОВЫЙ СВОДНЫЙ РАСХОД")
      current_section = :none
    end

    # Считываем строки таблицы
    if current_section == :matrix && clean_line =~ /^[Рр]яд\s*(\d+)/
      row_num = $1.to_i
      parts = clean_line.split('|').map(&:strip)

      if parts.length >= 5
        # Безопасное извлечение флоатов (для учета половинок кирпичей по 0.5 шт)
        f_val  = parts.at(1).gsub(/[^\d.]/, '').to_f rescue 0.0
        s_val  = parts.at(2).gsub(/[^\d.]/, '').to_f rescue 0.0
        sh_val = parts.at(3).gsub(/[^\d.]/, '').to_f rescue 0.0
        
        # Разбор литья в ячейке
        raw_cast = parts.at(4).gsub(/^[Лл]итье\s*:\s*/i, '').strip rescue "Нет"
        
        if raw_cast != "Нет" && !raw_cast.empty?
          h_counts = Hash. new(0)
          raw_cast.split(',').each do |it|
            it.strip!
            next if it.empty?
            # Группируем элементы, если они повторяются
            nm, ct = it =~ /^(.*)\s*\((\d+)\s*шт\)/i ? [$1.strip, $2.to_i] : [it, 1]
            h_counts[nm] += ct
          end
          c_val = h_counts.map { |k, v| "#{k} (#{v} шт)" }.join(', ')
        else
          c_val = "Нет"
        end

        rows_data[row_num] = {
          'facade'  => f_val,
          'stroit'  => s_val,
          'shamot'  => sh_val,
          'casting' => c_val,
          'note'    => DEFAULT_NOTES.fetch(row_num, "Технические примечания отсутствуют.")
        }
      end
    end
  end
  rows_data
end
# ==============================================================================
# ЧАСТЬ 2.1: АВТОМАТИЧЕСКИЙ СБОРЩИК ИНТЕРФЕЙСА И CSS-ПЕЧАТИ PDF (v77.6)
# ==============================================================================
def generate_html
  puts "[+] Старт сборки интерактивного веб-руководства v77.6..."
  rows_data = parse_specification(SPEC_FILE)
  
  if rows_data.nil? || rows_data.empty?
    puts "[-] Сборка аварийно остановлена: данные в матрице не найдены."
    return
  end

  FileUtils.mkdir_p(File.dirname(OUTPUT_HTML))
  rows_json = JSON.generate(rows_data)

  html_lines = []
  html_lines << "<!DOCTYPE html><html lang='ru'><head><meta charset='UTF-8'>"
  html_lines << "<meta name='viewport' content='width=device-width,initial-scale=1.0'>"
  html_lines << "<title>Руководство: Проект 4020-НМ</title><style>"

  # Переменные темы и базовые стили экрана
  html_lines << ":root{--bg-main:#121214;--bg-card:#1a1a1e;--accent:#ff5722;--text-main:#e1e1e6;--text-muted:#a8a8b3;--border:#29292e;--success:#4caf50;--info-bg:#1e1e24;}"
  html_lines << "*{box-sizing:border-box;margin:0;padding:0;font-family:system-ui,sans-serif;}"
  html_lines << "body{background:#fff!important;color:#000!important;display:block!important;overflow:visible!important;height:auto!important;}"
  html_lines << ".sidebar,.top-bar,.info-panel,#rowNoteBlock,.viewer-container,.modal-overlay{display:none!important;}"

  # Стили отображения раскрытой книги на экране и в PDF
  # Стили раскрытой книги с максимальным размером чертежей
  html_lines << "body{background:#fff!important;color:#000!important;display:block!important;overflow:visible!important;height:auto!important;}"
  html_lines << ".sidebar,.top-bar,.info-panel,#rowNoteBlock,.modal-overlay{display:none!important;}"
  html_lines << ".print-only-deck{display:block!important;background:#fff!important;color:#000!important;padding:5px;width:100%!important;height:auto!important;position:static!important;}"
  html_lines << ".print-page{page-break-after:always!important;page-break-inside:avoid!important;break-inside:avoid-page!important;display:block!important;width:100%!important;height:auto!important;padding-top:2mm!important;margin-bottom:10px!important;}"
  html_lines << ".print-row-title{display:block!important;font-size:22pt!important;color:#000!important;font-weight:bold!important;margin-bottom:8px!important;border-bottom:2px solid #000!important;padding-bottom:2px!important;}"
  
  # Окна для картинок: увеличиваем высоту до 115мм!
  html_lines << ".viewer-container{display:block!important;height:auto!important;margin-bottom:8px!important;page-break-inside:avoid!important;width:100%!important;}"
  html_lines << ".view-pane{border:1px solid #aaa!important;background:#fff!important;width:49%!important;display:inline-block!important;vertical-align:top!important;height:115mm!important;position:relative!important;margin-right:1%!important;}"
  html_lines << ".view-pane:last-child{margin-right:0!important;}"
  html_lines << ".pane-title{position:absolute!important;top:4px!important;left:4px!important;background:#000!important;color:#fff!important;padding:2px 5px!important;font-size:8pt!important;font-weight:bold!important;border-left:3px solid #ff5722!important;}"
  html_lines << ".img-wrapper{display:block!important;width:100%!important;height:100%!important;text-align:center!important;padding:4px!important;background:#fff!important;}"
  
  # Чертежи растягиваются под размер увеличенных рамок (до 105мм вместо 58мм)
  html_lines << ".img-wrapper img{display:inline-block!important;height:105mm!important;width:auto!important;max-width:100%!important;object-fit:contain!important;filter:brightness(1.05)!important;}"
  
  # Сверхкомпактный блок ИНФО (уменьшаем отступы и размер шрифта)
  html_lines << ".note-container{background:#f5f5f5!important;border:1px solid #aaa!important;border-left:5px solid #ff5722!important;color:#000!important;padding:4px 8px!important;margin-bottom:6px!important;height:auto!important;page-break-inside:avoid!important;display:block!important;}"
  html_lines << ".note-text{color:#000!important;font-size:9.5pt!important;line-height:1.2!important;}.note-text span{font-weight:bold!important;color:#ff5722!important;}"
  
  # Плотная и аккуратная таблица сметы под чертежами
  html_lines << ".info-panel{background:#fff!important;border:1px solid #aaa!important;color:#000!important;height:auto!important;padding:4px 8px!important;display:grid!important;grid-template-columns:repeat(4,1fr)!important;gap:5px!important;page-break-inside:avoid!important;}"
  html_lines << ".stat-block{border-right:1px dashed #aaa!important;padding-right:3px!important;display:flex!important;flex-direction:column!important;justify-content:center!important;}"
  html_lines << ".stat-block:last-child{border-right:none!important;}.stat-label{color:#555!important;font-size:8pt!important;text-transform:uppercase!important;margin-bottom:1px!important;}"
  html_lines << ".stat-value,.stat-value span{color:#000!important;font-size:11pt!important;font-weight:bold!important;}"


  # Интерфейс планшета для стройки
  html_lines << ".print-only-deck{display:block!important;background:#fff!important;color:#000!important;padding:20px;}"
  html_lines << ".pdf-download-btn{padding:6px 12px;background-color:#2e7d32;border:none;border-radius:4px;color:#fff;cursor:pointer;font-size:0.85rem;font-weight:bold;margin-right:15px;transition:background 0.2s;}"
  html_lines << ".pdf-download-btn:hover{background-color:#1b5e20;}"
  html_lines << ".sidebar{width:320px;background-color:var(--bg-card);border-right:1px solid var(--border);display:flex;flex-direction:column;}"
  html_lines << ".sidebar-header{padding:20px;border-bottom:1px solid var(--border);}"
  html_lines << ".sidebar-header h1{font-size:1.1rem;color:#fff;margin-bottom:4px;}"
  html_lines << ".sidebar-header p{font-size:0.75rem;color:var(--text-muted);}"
  html_lines << ".total-summary-btn{margin:10px;padding:12px;background-color:#202024;border:1px dashed var(--accent);border-radius:6px;color:#fff;text-align:center;font-size:0.85rem;font-weight:bold;cursor:pointer;transition:background 0.2s;}"
  html_lines << ".total-summary-btn:hover{background-color:rgba(255,87,34,0.1);}"
  html_lines << ".row-selector{flex:1;overflow-y:auto;padding:0 10px 10px 10px;}"
  html_lines << ".row-btn{width:100%;padding:10px 12px;background:none;border:1px solid transparent;border-radius:6px;color:var(--text-main);text-align:left;font-size:0.9rem;cursor:pointer;display:flex;justify-content:space-between;margin-bottom:4px;}"
  html_lines << ".row-btn:hover{background-color:var(--border);}.row-btn.active{background-color:var(--accent);color:#fff;font-weight:bold;}"
  html_lines << ".row-btn .brick-count{font-size:0.75rem;opacity:0.8;}"
  html_lines << ".main-content{flex:1;display:flex;flex-direction:column;overflow:hidden;}"
  html_lines << ".top-bar{height:50px;background-color:var(--bg-card);border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;padding:0 20px;}"
  html_lines << ".mode-switch{display:flex;background-color:#202024;padding:3px;border-radius:6px;border:1px solid var(--border);}"
  html_lines << ".mode-tab{padding:4px 10px;font-size:0.75rem;border-radius:4px;cursor:pointer;border:none;color:var(--text-muted);background:none;}"
  html_lines << ".mode-tab.active{background-color:var(--accent);color:#fff;font-weight:bold;}"
  html_lines << ".nav-btn{padding:6px 12px;background-color:var(--border);border:none;border-radius:4px;color:#fff;cursor:pointer;font-size:0.85rem;margin-left:5px;}"
  html_lines << ".nav-btn:hover{background-color:var(--accent);}"
  html_lines << ".viewer-container{flex:1;display:flex;gap:15px;padding:15px 15px 5px 15px;overflow:hidden;}"
  html_lines << ".view-pane{flex:1;background-color:var(--bg-card);border:1px solid var(--border);border-radius:8px;display:flex;flex-direction:column;overflow:hidden;position:relative;}"
  html_lines << ".pane-title{position:absolute;top:10px;left:10px;background:rgba(0,0,0,0.75);padding:4px 8px;border-radius:4px;font-size:0.75rem;font-weight:bold;z-index:10;border-left:3px solid var(--accent);}"
  html_lines << ".note-container{height:65px;margin:0 15px 10px 15px;padding:10px 15px;background-color:var(--info-bg);border:1px solid var(--border);border-left:4px solid var(--border);border-radius:4px;display:flex;align-items:center;overflow-y:auto;}"
  html_lines << ".note-container.has-note{border-left-color:var(--accent);background-color:#1f1a16;}"
  html_lines << ".note-text{font-size:0.85rem;line-height:1.3;color:var(--text-main);}"
  html_lines << ".note-text span{font-weight:bold;color:var(--accent);margin-right:5px;}"
  html_lines << ".info-panel{height:90px;background-color:var(--bg-card);border-top:1px solid var(--border);padding:15px 20px;display:flex;gap:30px;overflow-x:auto;}"
  html_lines << ".stat-block{display:flex;flex-direction:column;justify-content:center;min-width:120px;}"
  html_lines << ".stat-label{font-size:0.7rem;color:var(--text-muted);text-transform:uppercase;margin-bottom:2px;}"
  html_lines << ".stat-value{font-size:1.2rem;font-weight:bold;color:#fff;}.stat-value span{color:var(--accent);}.stat-value.accum span {color:var(--success);}"
  html_lines << ".modal-overlay{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.85);z-index:1000;align-items:center;justify-content:center;}"
  html_lines << ".modal-content{background:var(--bg-card);border:1px solid var(--border);border-radius:8px;width:500px;max-width:90%;padding:25px;box-shadow:0 10px 30px rgba(0,0,0,0.5);}"
  html_lines << ".modal-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;border-bottom:1px solid var(--border);padding-bottom:10px;}"
  html_lines << ".modal-close{background:none;border:none;color:var(--text-muted);font-size:1.4rem;cursor:pointer;}"
  html_lines << ".modal-close:hover{color:var(--accent);}.summary-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px dashed #29292e;font-size:0.9rem;}"
  html_lines << ".summary-row strong{color:var(--accent);}"
  html_lines << ".img-wrapper{flex:1;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#0f0f11;padding:10px;}"
  html_lines << ".img-wrapper img{max-width:100%;max-height:100%;object-fit:contain;transition:transform 0.2s;cursor:zoom-in;transform-origin:center center;}"
  html_lines << ".img-wrapper img.zoomed{transform:scale(2.2);cursor:zoom-out;max-width:none;max-height:none;}"
  html_lines << "</style></head><body>"
  # Интерактивный HTML-скелет полевого руководства
  html_lines << "<div class='sidebar'><div class='sidebar-header'><h1>🚀 ПРОЕКТ 4020-НМ</h1><p>Полевой веб-интерфейс v77.6 | Александр</p></div>"
  html_lines << "<div class='total-summary-btn' onclick='toggleModal(true)'>📋 ОБЩАЯ СМЕТА ОБЪЕКТА</div>"
  html_lines << "<div class='row-selector' id='rowSelector'></div></div>"
  
  # ФИКС: Четко задан id='currentRowTitle', чтобы скрипт не падал при обновлении номера ряда
  html_lines << "<div class='main-content'><div class='top-bar'><h2 id='currentRowTitle'>РЯД --</h2>"
  html_lines << "<div style='display:flex;align-items:center;'>"
  html_lines << "<button class='pdf-download-btn' onclick='window.print()'>📥 СКАЧАТЬ PDF КНИГУ</button>"
  html_lines << "<div class='mode-switch'>"
  html_lines << "<button class='mode-tab active' id='tabRow' onclick='setMode(\"row\")'>НА РЯД</button>"
  html_lines << "<button class='mode-tab' id='tabAccum' onclick='setMode(\"accum\")'>НАКОПИТЕЛЬНО</button>"
  html_lines << "</div></div>"
  html_lines << "<div class='controls'><button class='nav-btn' onclick='changeRow(-1)'>◀</button>"
  html_lines << "<button class='nav-btn' onclick='changeRow(1)'>▶</button></div></div>"
  
  html_lines << "<div class='viewer-container'>"
  html_lines << "<div class='view-pane'><div class='pane-title'>ПЛАН (ТОП-ВЬЮ)</div><div class='img-wrapper'><img id='topViewImg' src='' onclick='toggleZoom(this)'></div></div>"
  html_lines << "<div class='view-pane'><div class='pane-title'>ИЗОМЕТРИЯ (НАКОПИТЕЛЬНО)</div><div class='img-wrapper'><img id='isoViewImg' src='' onclick='toggleZoom(this)'></div></div></div>"
  html_lines << "<div class='note-container' id='rowNoteBlock'><div class='note-text' id='rowNoteText'>Технические примечания отсутствуют.</div></div>"
  
  # Невидимый на экране контейнер (на белом фоне) для авторазметки PDF-книги А4 на принтер
  html_lines << "<div class='print-only-deck' id='pdfPrintDeck'></div>"
  html_lines << "<div class='info-panel' id='infoPanel'></div></div>"
  html_lines << "<div class='modal-overlay' id='summaryModal' onclick='if(event.target===this) toggleModal(false)'>"
  html_lines << "<div class='modal-content'><div class='modal-header'><h3>📊 Итоговая смета объекта</h3>"
  html_lines << "<button class='modal-close' onclick='toggleModal(false)'>&times;</button></div><div id='modalSummaryBody'></div></div></div>"

  # Начало JavaScript движка
  html_lines << "<script>"
  html_lines << "const matrixData = #{rows_json};"
  html_lines << "const sortedRows = Object.keys(matrixData).map(Number).sort((a,b)=>a-b);"
  html_lines << "let currentRow = sortedRows.length > 0 ? sortedRows[0] : 1; let displayMode = 'row';"
  html_lines << "const topPath = '../01_scenes/top_view/'; const isoPath = '../01_scenes/iso_view/';"
  html_lines << "function init() {"
  html_lines << " const selector = document.getElementById('rowSelector');"
  html_lines << " if (sortedRows.length === 0) { selector.innerHTML = '<p>Данные отсутствуют</p>'; return; }"
  html_lines << " sortedRows.forEach(i => {"
  html_lines << " const btn = document.createElement('button');"
  html_lines << " btn.className = 'row-btn' + (i === currentRow ? ' active' : ''); btn.id = 'btn_' + i;"
  html_lines << " btn.onclick = function() { selectRow(i); };"
  html_lines << " const data = matrixData[i] || { 'facade': 0, 'stroit': 0, 'shamot': 0 };"
  html_lines << " const total = (Number(data['facade']) || 0) + (Number(data['stroit']) || 0) + (Number(data['shamot']) || 0);"
  html_lines << " btn.innerHTML = '<span>Ряд ' + String(i).padStart(2,'0') + '</span> <span class=\"brick-count\">' + total.toFixed(1) + ' шт.</span>';"
  html_lines << " selector.appendChild(btn);"
  html_lines << " });"
  html_lines << " buildTotalSummary(); buildPdfPrintDeck(); selectRow(currentRow);"
  html_lines << "}"
  
  html_lines << "function buildTotalSummary() {"
  html_lines << " let tF = 0, tS = 0, tSh = 0; let cList = new Set();"
  html_lines << " sortedRows.forEach(i => {"
  html_lines << " const d = matrixData[i] || {}; tF += Number(d['facade']) || 0; tS += Number(d['stroit']) || 0; tSh += Number(d['shamot']) || 0;"
  html_lines << " if (d['casting'] && d['casting'] !== 'Нет') d['casting'].split(',').forEach(c => cList.add(c.trim()));"
  html_lines << " });"
  html_lines << " const b = document.getElementById('modalSummaryBody'); let cH = ''; cList.forEach(c => { cH += '<div style=\"font-size:0.85rem;color:#ffb74d;\">• ' + c + '</div>'; });"
  html_lines << " b.innerHTML = '<div class=\"summary-row\"><span>Облицовка:</span><strong>'+tF.toFixed(1)+' шт.</strong></div><div class=\"summary-row\"><span>Забутовка:</span><strong>'+tS.toFixed(1)+' шт.</strong></div><div class=\"summary-row\"><span>Шамот:</span><strong>'+tSh.toFixed(1)+' шт.</strong></div><div class=\"summary-row\" style=\"border-bottom:1px solid var(--border);margin-bottom:15px;\"><span>Всего:</span><strong>'+(tF+tS+tSh).toFixed(1)+' шт.</strong></div><h4 style=\"font-size:0.85rem;margin-bottom:8px;text-transform:uppercase;color:var(--text-muted)\">Литье:</h4>' + cH;"
  html_lines << "}"
  
  html_lines << "function buildPdfPrintDeck() {"
  html_lines << " const deck = document.getElementById('pdfPrintDeck'); deck.innerHTML = '';"
  html_lines << " sortedRows.forEach(i => {"
  html_lines << " const d = matrixData[i] || {}; const fIdx = String(i).padStart(2, '0'); const page = document.createElement('div'); page.className = 'print-page';"
  html_lines << " page.innerHTML = '<div class=\"print-row-title\">РЯД ' + fIdx + '</div><div class=\"viewer-container\"><div class=\"view-pane\"><div class=\"pane-title\">ПЛАН</div><div class=\"img-wrapper\"><img src=\"' + topPath + 'row_' + fIdx + '.png\"></div></div><div class=\"view-pane\"><div class=\"pane-title\">ИЗОМЕТРИЯ</div><div class=\"img-wrapper\"><img src=\"' + isoPath + 'row_' + fIdx + '.png\"></div></div></div><div class=\"note-container has-note\"><div class=\"note-text\"><span>ИНФО:</span>' + (d['note'] || 'Примечания отсутствуют.') + '</div></div><div class=\"info-panel\"><div class=\"stat-block\"><div class=\"stat-label\">Облицовка</div><div class=\"stat-value\">' + (d['facade'] || 0) + ' шт.</div></div><div class=\"stat-block\"><div class=\"stat-label\">Забутовка</div><div class=\"stat-value\">' + (d['stroit'] || 0) + ' шт.</div></div><div class=\"stat-block\"><div class=\"stat-label\">Шамот</div><div class=\"stat-value\">' + (d['shamot'] || 0) + ' шт.</div></div><div class=\"stat-block\"><div class=\"stat-label\">Литье</div><div class=\"stat-value\" style=\"font-size:9pt;\">' + (d['casting'] || 'Нет') + '</div></div></div>';"
  html_lines << " deck.appendChild(page);"
  html_lines << " });"
  html_lines << "}"
  
  html_lines << "function setMode(m) { displayMode = m; document.getElementById('tabRow').classList.toggle('active', m === 'row'); document.getElementById('tabAccum').classList.toggle('active', m === 'accum'); updateMetrics(currentRow); }"
  
  html_lines << "function selectRow(r) {"
  html_lines << " const oB = document.getElementById('btn_' + currentRow); if (oB) oB.classList.remove('active'); currentRow = r; const aB = document.getElementById('btn_' + currentRow);"
  html_lines << " if (aB) { aB.classList.add('active'); aB.scrollIntoView({ block: 'nearest', behavior: 'smooth' }); }"
  html_lines << " const mR = Math.max(...sortedRows);"
  html_lines << " document.getElementById('currentRowTitle').innerText = 'РЯД ' + String(currentRow).padStart(2, '0') + ' / ' + String(mR).padStart(2, '0');"
  html_lines << " document.getElementById('topViewImg').src = topPath + 'row_' + String(currentRow).padStart(2, '0') + '.png';"
  html_lines << " document.getElementById('isoViewImg').src = isoPath + 'row_' + String(currentRow).padStart(2, '0') + '.png'; updateMetrics(currentRow);"
  html_lines << "}"
  
  html_lines << "function updateMetrics(r) {"
  html_lines << " const p = document.getElementById('infoPanel'); const nB = document.getElementById('rowNoteBlock'); const nT = document.getElementById('rowNoteText');"
  html_lines << " let f = 0, s = 0, sh = 0; let cT = 'Нет'; const cD = matrixData[r] || {}; const rN = cD['note'] || 'Технические примечания отсутствуют.';"
  html_lines << " if (displayMode === 'row') {"
  html_lines << " f = Number(cD['facade']) || 0; s = Number(cD['stroit']) || 0; sh = Number(cD['shamot']) || 0; cT = cD['casting'] || 'Нет';"
  html_lines << " if (rN.includes('отсутствуют')) { nB.classList.remove('has-note'); nT.innerHTML = rN; } else { nB.classList.add('has-note'); nT.innerHTML = '<span>ИНФО:</span>' + rN; }"
  html_lines << " } else {"
  html_lines << " sortedRows.forEach(i => { if (i <= r) { const d = matrixData[i] || {}; f += Number(d['facade']) || 0; s += Number(d['stroit']) || 0; sh += Number(d['shamot']) || 0; } });"
  html_lines << " cT = 'Смотри в общей смете'; nB.classList.remove('has-note'); nT.innerHTML = 'Накопительный итог с 1 по ' + r + ' ряд.';"
  html_lines << " }"
  html_lines << " const suf = displayMode === 'row' ? '' : ' (Всего)'; const vCl = displayMode === 'row' ? 'stat-value' : 'stat-value accum';"
  html_lines << " p.innerHTML = '<div class=\"stat-block\"><div class=\"stat-label\">Облицовка'+suf+'</div><div class=\"'+vCl+'\"><span>'+f.toFixed(1)+'</span> шт.</div></div><div class=\"stat-block\"><div class=\"stat-label\">Забутовка'+suf+'</div><div class=\"'+vCl+'\"><span>'+s.toFixed(1)+'</span> шт.</div></div><div class=\"stat-block\"><div class=\"stat-label\">Шамот'+suf+'</div><div class=\"'+vCl+'\"><span>'+sh.toFixed(1)+'</span> шт.</div></div><div class=\"stat-block\"><div class=\"stat-label\">Литье</div><div class=\"stat-value\" style=\"font-size:0.85rem;color:#ffb74d;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;\" title=\"'+cT+'\">'+cT+'</div></div>';"
  html_lines << "}"
  
  html_lines << "function changeRow(d) { const c = sortedRows.indexOf(currentRow); const t = c + d; if (t >= 0 && t < sortedRows.length) selectRow(sortedRows[t]); }"
  html_lines << "function toggleZoom(i) { i.classList.toggle('zoomed'); } function toggleModal(s) { document.getElementById('summaryModal').style.display = s ? 'flex' : 'none'; }"
  
  html_lines << "document.addEventListener('keydown', function(e) { if (e.key === 'ArrowRight' || e.key === 'ArrowDown') changeRow(1); if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') changeRow(-1); if (e.key === 'Escape') toggleModal(false); });"
  html_lines << "window.onload = init;"
  html_lines << "</script></body></html>"

  full_html_page = html_lines.join("\n")
  File.write(OUTPUT_HTML, full_html_page, mode: 'w:utf-8')
  puts "[+] Полевой интерфейс v77.6 с PDF-модулем успешно сгенерирован: #{OUTPUT_HTML}"
end

generate_html
