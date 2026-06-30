# frozen_string_literal: true
# Encoding: UTF-8

# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ v77.78 — ГЕНЕРАТОР ИНЖЕНЕРНОГО АЛЬБОМА
# С поддержкой наложения дополнительных видов поверх основных
# ==============================================================================

require 'fileutils'
require 'sketchup'

module PechnikEngineeringHub
  # ----------------------------------------------------------------------------
  # КОНФИГУРАЦИЯ ПРОЕКТА
  # ----------------------------------------------------------------------------
  module Config
    BASE_DIR          = "D:/pechnik-engineering-hub"
    SCENES_DIR        = "01_scenes"
    DRAWINGS_DIR      = "drawings"
    TOP_VIEW_DIR      = "top_view"
    ISO_VIEW_DIR      = "iso_view"
    ADDITIONAL_VIEWS_DIR = "additional_views"
    SPEC_FILE         = "02_specifications/specification_summary.txt"
    OUTPUT_FILE       = "03_web_guide/index.html"
    NOTES_FILE        = "notes.txt"

    def self.drawings_path(filename)
      File.join(BASE_DIR, SCENES_DIR, DRAWINGS_DIR, filename)
    end

    def self.top_view_path(filename)
      File.join(BASE_DIR, SCENES_DIR, TOP_VIEW_DIR, filename)
    end

    def self.iso_view_path(filename)
      File.join(BASE_DIR, SCENES_DIR, ISO_VIEW_DIR, filename)
    end

    def self.additional_views_pattern(row_num)
      File.join(
        BASE_DIR,
        SCENES_DIR,
        ADDITIONAL_VIEWS_DIR,
        "row_#{row_num.to_s.rjust(2, '0')}_view*.png"
      )
    end
  end

  # ----------------------------------------------------------------------------
  # МОДУЛЬ ЗАГРУЗКИ ЗАМЕТОК
  # ----------------------------------------------------------------------------
  module NotesLoader
    def self.load_notes(base_dir)
      notes = Array.new(70, "")
      notes_file = File.join(base_dir, Config::NOTES_FILE)

      if File.exist?(notes_file)
        begin
          File.readlines(notes_file, encoding: 'utf-8').each do |line|
            line = line.strip
            next if line.empty? || line.start_with?('#')
            if line =~ /^(\d+)\|(.+)$/
              row_num = $1.to_i
              note_text = $2.strip
              notes[row_num] = note_text if row_num.between?(0, 69)
            end
          end
          puts "[+] Заметки загружены из файла: #{notes_file}"
        rescue => e
          puts "[-] Ошибка чтения файла заметок: #{e.message}. Использую резерв."
          notes = default_notes
        end
      else
        puts "[-] Файл заметок не найден: #{notes_file}. Использую резерв."
        notes = default_notes
      end
      notes
    end

    def self.default_notes
      notes = Array.new(70, "")
      notes[1]  = "Особое внимание горизонтальности, точности выставления вертикальных швов и проверка диагоналей. Этот ряд определит финальные размеры комплекса."
      notes[2]  = "Тоннель монтажный к поддувальной дверце крепить на заклепки из нержавейки."
      notes[3]  = "Каждый ряд проверяем рулеткой."
      notes[4]  = "Проверить горизонтальный уровень всего комплекса. Лазерный уровень для это будет хорошим решением"
      notes[5]  = "При перекрытии поддувала оставить зазор в 20 мм. Это дополнительный воздушный барьер от копоти на стекле дверцы."
      notes[6]  = "Тоннель монтажный к топочной дверце крепить на заклепки из нержавейки. По периметру проложить базальтовый картон. Колосник не должен быть зажат."
      notes[7]  = " "
      notes[9]  = "В топке печи тепловой зазор 5-10 мм базальта, между шамотным и прилегающими кирпичами."
      notes[10] = "Дымоход d-150 мм нержавейка толщина 1 мм. Собирать на жаростойкий герметик. Примыкание к шамотному кирпичу проложить базальтовым картоном."
      notes[12] = "Высота шамотного ряда в печи определяется от финальной высоты столешницы+полоска базальтового картона 5 мм."
      notes[15] = "На задней стенке шамотного ряда при помощи среза нижнего угла у 3х кирпичей 32*32 мм организовывается площадка опора для шампуров."
      notes[20] = "На шамотном ряду размер двух боковых кирпичей регулирует высоту и уровень перемычки из шамотного кирпича на шпильке м10. Кирпичи на задней стенки со срезом формируют наклон 42°. Обратите внимание! Для соблюдения послойности выдачи этот шамотный слой состоит из 2х."
      notes[21] = "Устанавливаютя перемычки из лицевого и шамотного кирпича. На задней стенке топки мангала сформировался наклон 42°."
      notes[22] = "Устанавливаетя подсветка."
      notes[23] = "На шамотном ряду боковые кирпичи формируют наклон 42°."
      notes[24] = "На шамотном ряду передние и боковые кирпичи формируют наклон 42°."
      notes[25] = "На шамотном ряду передние кирпичи формируют наклон 42°."
      notes[26] = "Шамотный ряд весь выставлен из цельных кирпичей. Может потребоваться подрезка для свободного хода поворотных шиберов ЗВП-2."
      notes[27] = " "
      notes[28] = "Финальная настройка и проверка работы поворотных шиберов."
      notes[30] = "Примыкание выхода дымохода проложить базальтовым картоном."
      notes[33] = "На забутовочном ряду с двух сторон боковые кирпичи свормировали переход 42° под основное сечение дымохода."
      notes[35] = "Далее выкладывается дымоход согласно проекту до 54 ряда. Возможны корректировки высот."
      notes
    end
  end

  # ----------------------------------------------------------------------------
  # ПАРСЕР СПЕЦИФИКАЦИИ
  # ----------------------------------------------------------------------------
  class SpecificationParser
    attr_reader :model_title, :project_code, :bricks_per_row, :casting_per_row,
                :total_lf, :total_sp, :total_sh8, :total_finish_table,
                :mixtures, :iron_materials

    def initialize(spec_path)
      @spec_path = spec_path
      @bricks_per_row = Array.new(55) { { lf: 0, sp: 0, sh8: 0 } }
      @casting_per_row = Array.new(55, "Нет")
      @total_lf = 0
      @total_sp = 0
      @total_sh8 = 0
      @total_finish_table = 0.0
      @mixtures = {}
      @iron_materials = {}
      @model_title = ""
      @project_code = ""
      parse!
    end

    private

    def parse!
      raise "Файл спецификации не найден: #{@spec_path}" unless File.exist?(@spec_path)

      File.readlines(@spec_path, encoding: 'utf-8').each do |line|
        line.strip!
        next if line.empty?

        if line =~ /^\[MODEL_TITLE\]\s*:\s*(.*)/
          @model_title = $1.strip
          extract_project_code
        end

        if line =~ /row_(\d+)\s*\|\s*(LF-\d+-ST)\s*\|\s*.*\|\s*(\d+)/
          @bricks_per_row[$1.to_i][:lf] += $3.to_i if $1.to_i.between?(0, 54)
        elsif line =~ /row_(\d+)\s*\|\s*(SH8-\d+-ST)\s*\|\s*.*\|\s*(\d+)/
          @bricks_per_row[$1.to_i][:sh8] += $3.to_i if $1.to_i.between?(0, 54)
        elsif line =~ /row_(\d+)\s*\|\s*(SP-\d+-ST)\s*\|\s*.*\|\s*(\d+)/
          @bricks_per_row[$1.to_i][:sp] += $3.to_i if $1.to_i.between?(0, 54)
        end

        if line =~ /Ряд\s*(\d+)\s*\|.*\|\s*Литье:\s*(.*)/
          @casting_per_row[$1.to_i] = $2.strip if $1.to_i.between?(0, 54) && $2.strip != "Нет"
        end

        if line =~ /LF \(Кирпич 1нф лицевой\)\s*:\s*(\d+)/
          @total_lf = $1.to_i
        elsif line =~ /SP \(Кирпич 1нф строительный полнотелый\)\s*:\s*(\d+)/
          @total_sp = $1.to_i
        elsif line =~ /SH8 \(Кирпич шамотный ШБ-8\)\s*:\s*(\d+)/
          @total_sh8 = $1.to_i
        elsif line =~ /FINISH-TABLE \(Керамогранит столешницы\)\s*:\s*([\d.]+)/
          @total_finish_table = $1.to_f
        elsif line =~ /Глиняно-песчаная смесь.*:\s*(\d+)\s*кг/
          @mixtures["Глиняно-песчаная смесь (Красный швы 10мм)"] = "#{$1} кг"
        elsif line =~ /Огнеупорный мертель.*:\s*(\d+)\s*кг/
          @mixtures["Огнеупорный мертель (Шамот швы 4/2мм)"] = "#{$1} кг"
        elsif line =~ /^\s*([^|]+)\s*\|\s*(\d+)\s*$/ && !line.include?("PRODUCTION") && !line.include?("Номер")
          @iron_materials[$1.strip] = $2.to_i
        end
      end
    end

    def extract_project_code
      if @model_title =~ /[«"']([^»"']+)[»"']/
        @project_code = $1.strip
      elsif @model_title =~ /комплекс\s+(.*)/i
        @project_code = $1.strip
      else
        @project_code = @model_title.gsub("Барбекю комплекс", "").strip
      end
      @project_code = "У-3240-НМ" if @project_code.empty?
    end
  end

  # ----------------------------------------------------------------------------
  # ГЕНЕРАТОР HTML-АЛЬБОМА
  # ----------------------------------------------------------------------------
  class HtmlAlbumGenerator
    def initialize(spec_parser, notes, model_title, project_code)
      @spec = spec_parser
      @notes = notes
      @model_title = model_title
      @project_code = project_code
      @html = +""
    end

    def generate
      build_css
      build_cover_page
      build_intro_page
      build_general_view
      build_material_pages
      build_section_pages
      build_start_guide_page
      build_specification_pages
      build_foundation_page
      build_masonry_pages
      @html
    end

    private

    def build_css
      css = <<~CSS
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
        .image-box { flex: 1; border: 1px solid #bdc3c7; padding: 3mm; text-align: center; border-radius: 6px; background: #ffffff; box-sizing: border-box; height: 100%; display: flex; flex-direction: column; position: relative; }
        .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; width: 100%; height: 100%; }
        .img-wrapper img { max-width: 100%; max-height: 100%; object-fit: contain; }
        .image-title { font-size: 9.5pt; color: #7f8c8d; text-transform: uppercase; margin-bottom: 2mm; font-weight: bold; }
        .extra-overlay { position: absolute; width: 30%; max-width: 80mm; background: rgba(255,255,255,0.85); border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.25); padding: 2mm; box-sizing: border-box; border: 1px solid #e67e22; }
        .extra-overlay img { width: 100%; height: auto; display: block; }
        .extra-top-left { top: 2mm; left: 2mm; }
        .extra-top-right { top: 10mm; right: 2mm; }
        .extra-bottom-left { bottom: 2mm; left: 2mm; }
        .extra-bottom-right { bottom: 2mm; right: 2mm; }
        .foundation-container { display: flex; gap: 6mm; align-items: stretch; width: 100%; height: 122mm; box-sizing: border-box; }
        .foundation-container .image-box { flex: 1.3; border: 1px solid #bdc3c7; padding: 3mm; background: #ffffff; border-radius: 6px; height: 100%; }
        .foundation-container .img-wrapper { height: 110mm; display: flex; align-items: center; justify-content: center; overflow: hidden; }
        .materials-container { display: flex; flex-direction: row; gap: 6mm; width: 100%; height: 140mm; box-sizing: border-box; }
        .materials-container .image-box-wrapper { display: flex; flex-direction: column; flex: 1; height: 100%; }
        .materials-container .img-wrapper { flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden; border: 1px solid #bdc3c7; border-radius: 6px; background: #ffffff; height: 125mm !important; }
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
      @html << "<!DOCTYPE html><html><head><meta charset='UTF-8'><style>#{css}</style></head><body>"
    end

    def page_header(title)
      "<div class='header-meta'><span>Проект #{@project_code}</span><span>#{title}</span></div>"
    end

    def note_block(row_num)
      note = @notes[row_num].nil? || @notes[row_num].empty? ? "" : @notes[row_num]
      <<~HTML
        <div style='display: flex; align-items: center; width: 100%; height: 12mm; background: #fffdf9; border: 1px solid #e9d5c5; border-radius: 6px; margin-top: 3mm; padding: 0 4mm; box-sizing: border-box; font-size: 8.5pt; position: relative;'>
          <b style='color: #ffffff; background-color: #d35400; padding: 1mm 2.5mm; border-radius: 4px; margin-right: 4mm; text-transform: uppercase; letter-spacing: 0.7px; font-size: 7.5pt; font-weight: bold;'>Заметки</b>
          <div style='flex: 1; font-family: sans-serif; font-style: italic; color: #555; padding-top: 1mm; line-height: 1.2;'>
            #{note.empty? ? "<div style='height: 100%; background-image: linear-gradient(to bottom, transparent 95%, #eedcd0 95%); background-size: 100% 6mm; margin-top: 1mm; opacity: 0.8;'></div>" : note}
          </div>
        </div>
      HTML
    end

    def additional_views_for_row(row_num)
      pattern = Config.additional_views_pattern(row_num)
      Dir.glob(pattern).sort
    end

    # Возвращает путь к дополнительному изображению для указанного типа ('top' или 'iso')
def extra_image_for_type(row_num, type)
  images = additional_views_for_row(row_num)
  images.find { |path| File.basename(path).downcase.include?("_#{type}") }
end

    def build_cover_page
      @html << "<div class='page page-cover'><div class='cover-logo'>PECHNIK-NOVOSIB.RU</div>" \
               "<div class='cover-title'>Барбекю комплекс «#{@model_title}»</div>" \
               "<div class='cover-subtitle'>Порядовое инженерное руководство повышенной точности</div>" \
               "<div class='cover-footer'>Новосибирск — #{Time.now.strftime('%d.%m.%Y')}</div></div>"
    end

    def build_intro_page
      @html << "<div class='page'>#{page_header('Введение')}<h1>Состав технической документации</h1>" \
               "<div class='intro-box'><div class='intro-text-side'>" \
               "<p>Настоящее рабочее руководство содержит исчерпывающие архитектурные разрезы, спецификацию материалов фундаментного основания, полную карту снабжения артикулов строительной керамики и порядовые схемы сборки отопительного комплекса.</p>" \
               "<p>Каждый этап прорисован в двух ракурсах для исключения ошибок на объекте. Кладочные работы рекомендуется вести строго в соответствии с технологическими предписаниями, контролируя толщину швов и зазоры термокомпенсации.</p></div>" \
               "<div class='intro-quote-side'><b>Контакты автора:</b><br><br>Телефон: <b>+7 (913) 894-10-74</b><br><small>WhatsApp, звонки</small><br><br>Почта: <b>master-pechi@mail.ru</b><br>Сайт: <b>pechnik-novosib.ru</b></div></div>" \
               "<div class='page-number'>2</div></div>"
    end

    def build_general_view
      @html << "<div class='page'>#{page_header('Общий вид изделия')}<h1>Общий вид готового комплекса</h1>" \
               "<div class='img-wrapper' style='height:145mm; border:1px solid #bdc3c7; border-radius:6px; background:#fff;'>" \
               "<img src='#{Config.drawings_path('main_preview.png')}'></div>" \
               "<div class='page-number'>3</div></div>"
    end

    def build_material_pages
      @html << "<div class='page'>#{page_header('Карта материалов')}<h1>Карта материалов — Облицовка и строительный кирпич</h1>" \
               "<div class='materials-container'>" \
               "<div class='image-box-wrapper'><div class='image-title'>Лицевой фасадный кирпич (LF)</div><div class='img-wrapper'><img src='#{Config.drawings_path('palette_brick_facade.png')}'></div></div>" \
               "<div class='image-box-wrapper'><div class='image-title'>Строительный кирпич наполнения (SP)</div><div class='img-wrapper'><img src='#{Config.drawings_path('palette_brick_building.png')}'></div></div></div>" \
               "<div class='page-number'>4</div></div>"
      @html << "<div class='page'>#{page_header('Карта материалов')}<h1>Карта материалов — Шамот и печная фурнитура</h1>" \
               "<div class='materials-container'>" \
               "<div class='image-box-wrapper'><div class='image-title'>Шамотное ядро топки (ШБ-8 / SH8)</div><div class='img-wrapper'><img src='#{Config.drawings_path('palette_firebrick.png')}'></div></div>" \
               "<div class='image-box-wrapper'><div class='image-title'>Печное чугунное литье и узлы монтажа</div><div class='img-wrapper'><img src='#{Config.drawings_path('palette_iron.png')}'></div></div></div>" \
               "<div class='page-number'>5</div></div>"
    end

    def build_section_pages
      @html << "<div class='page'>#{page_header('Конструктивные сечения')}<h1>Технические разрезы комплекса бок о бок</h1>" \
               "<div class='materials-container'>" \
               "<div class='image-box-wrapper'><div class='image-title'>Продольный разрез (Сечение 1)</div><div class='img-wrapper'><img src='#{Config.drawings_path('section_1.png')}'></div></div>" \
               "<div class='image-box-wrapper'><div class='image-title'>Поперечный разрез (Сечение 2)</div><div class='img-wrapper'><img src='#{Config.drawings_path('section_2.png')}'></div></div></div>" \
               "<div class='page-number'>6</div></div>"
    end

    def build_start_guide_page
      note7 = @notes[7].nil? || @notes[7].empty? ? "" : @notes[7]
      @html << <<~HTML
        <div class='page'>
          #{page_header('Регламент старта')}
          <h1 style='margin-bottom: 3mm;'>Руководство по старту и общие правила кладки</h1>
          <div style='display: flex; gap: 5mm; height: 135mm; align-items: stretch; box-sizing: border-box;'>
            <div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'>
              <div>
                <h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>1. Размещение на участке</h3>
                <div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'>
                  <b>• Дистанция безопасности:</b> Минимум 5 метров от стен дома и построек.<br>
                  <b>• Граница участка:</b> Не менее 1 метра от забора соседей. Учтите розу ветров.<br>
                  <b>• Зеленая зона:</b> До веток ближайших деревьев — минимум 2 метра свободного места.<br>
                  <b>• Основа плиты:</b> Монолит шире печи на 100 мм со всех сторон. Перед 1-м рядом уложите 2 слоя рубероида.
                </div>
              </div>
              <div style='background: #edf7ed; padding: 3mm; border-radius: 4px; border-left: 4px solid #2e7d32; margin-top: 2mm;'>
                <h3 style='margin: 0 0 1mm 0; color: #2e7d32; font-size: 10pt; text-transform: uppercase;'>💧 Подготовка материалов</h3>
                <div style='font-size: 9pt; line-height: 1.35; color: #1b5e20;'>
                  <b>Красный кирпич:</b> Окунайте в воду на 1-2 минуты перед кладкой, иначе он выпьет всю воду из раствора.<br>
                  <b>Шамотный кирпич:</b> Вымачивать нельзя! Только быстро смахните влажной кистью пыль.
                </div>
              </div>
            </div>
            <div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'>
              <div>
                <h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>2. Контроль геометрии</h3>
                <div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'>
                  <b>• Метод прутка:</b> Для красного кирпича используйте стальной квадрат 10 мм как шаблон идеального шва.<br>
                  <b>• Шамотное ядро:</b> Швы очень тонкие (4 мм горизонт, 2 мм вертикаль). Используйте plastic-крестики.<br>
                  <b>• Правило 3 шагов:</b> Каждый ряд проверяйте трижды: пузырьковым уровнем вдоль, угольником на углах и рулеткой по диагоналям.
                </div>
              </div>
              <div style='background: #fff4e5; padding: 3mm; border-radius: 4px; border-left: 4px solid #ff9800; margin-top: 2mm;'>
                <h3 style='margin: 0 0 1mm 0; color: #b78103; font-size: 10pt; text-transform: uppercase;'>🌡️ Физика печи (Критично)</h3>
                <div style='font-size: 9pt; line-height: 1.35; color: #5c3e00;'>
                  <b>«Дом в доме»:</b> Внутреннее шамотное ядро расширяется сильнее наружных стен. Их никогда нельзя связывать раствором!<br>
                  Забивайте зазор только базальтовым картоном 5-10 мм. Не допускайте падения раствора в этот шов.
                </div>
              </div>
            </div>
            <div style='flex: 1; background: #fafafa; border: 1px solid #bdc3c7; padding: 4mm; border-radius: 6px; display: flex; flex-direction: column; justify-content: space-between; box-sizing: border-box;'>
              <div>
                <h3 style='margin: 0 0 2mm 0; color: #d35400; font-size: 10.5pt; border-bottom: 2px solid #eedcd0; padding-bottom: 1mm; text-transform: uppercase;'>3. Раствор и швабровка</h3>
                <div style='font-size: 9.5pt; line-height: 1.45; color: #2c3e50;'>
                  <b>• Разные смеси:</b> Красный кирпич — на глиняно-песчаную смесь (ГПС). Шамот — строго на огнеупорный мертель.<br>
                  <b>• Тест мастерка:</b> Раствор не должен стекать при наклоне в 45°, но плавно сползает, если его слегка тряхнуть.<br>
                  <b>• Швабровка каналов:</b> Швы внутри затирайте мокрой тряпкой. Гладкие каналы обеспечат мощную тягу.
                </div>
              </div>
              <div style='background: #e3f2fd; padding: 3mm; border-radius: 4px; border-left: 4px solid #0288d1; margin-top: 2mm;'>
                <h3 style='margin: 0 0 1mm 0; color: #0d47a1; font-size: 10pt; text-transform: uppercase;'>🛠️ Набор новичка</h3>
                <div style='font-size: 8.5pt; line-height: 1.35; color: #01579b; font-style: italic;'>
                  Уровень 60-80 см • Резиновая белая киянка • Кельма печника • Болгарка с алмазным диском • Рулетка • Угольник • Защитные очки и маска.
                </div>
              </div>
            </div>
          </div>
          <div style='display: flex; align-items: center; width: 100%; height: 12mm; background: #fffdf9; border: 1px solid #e9d5c5; border-radius: 6px; margin-top: 3mm; padding: 0 4mm; box-sizing: border-box; font-size: 8.5pt; position: relative;'>
            <b style='color: #ffffff; background-color: #d35400; padding: 1mm 2.5mm; border-radius: 4px; margin-right: 4mm; text-transform: uppercase; letter-spacing: 0.7px; font-size: 7.5pt; font-weight: bold;'>Заметки</b>
            <div style='flex: 1; font-family: sans-serif; font-style: italic; color: #555; padding-top: 1mm; line-height: 1.2;'>
              #{note7.empty? ? "<div style='height: 100%; background-image: linear-gradient(to bottom, transparent 95%, #eedcd0 95%); background-size: 100% 6mm; margin-top: 1mm; opacity: 0.8;'></div>" : note7}
            </div>
          </div>
          <div class='page-number'>7</div>
        </div>
      HTML
    end

    def build_specification_pages
      all_items = [
        "■ Кирпич 1НФ Лицевой (LF артикул): <b>#{@spec.total_lf} шт.</b>",
        "■ Кирпич 1НФ Строительный полнотелый (SP артикул): <b>#{@spec.total_sp} шт.</b>",
        "■ Кирпич Шамотный огнеупорный (ШБ-8 / SH8): <b>#{@spec.total_sh8} шт.</b>"
      ]
      all_items << "■ Керамогранит столешницы (FINISH-TABLE): <b>#{@spec.total_finish_table.round(2)} м²</b>" if @spec.total_finish_table > 0
      @spec.iron_materials.each { |k, v| all_items << "■ #{k}: <b>#{v} шт.</b>" }
      @spec.mixtures.each { |k, v| all_items << "■ #{k}: <b>#{v}</b>" }

      half = (all_items.size / 2.0).ceil
      part1 = all_items.first(half)
      part2 = all_items.last(all_items.size - half)

      @html << "<div class='page'>#{page_header('Сводная спецификация материалов')}<h1>Сводная спецификация материалов конструкции (Часть 1)</h1>" \
               "<table class='spec-table'><thead><tr><th>Наименование элемента снабжения</th><th>Расчетное количество</th></tr></thead><tbody>"
      part1.each do |item|
        name, qty = item.split(':')
        @html << "<tr><td>#{name}</td><td>#{qty}</td></tr>"
      end
      @html << "</tbody></table><div class='page-number'>8</div></div>"

      @html << "<div class='page'>#{page_header('Сводная спецификация материалов')}<h1>Сводная спецификация материалов конструкции (Часть 2)</h1>" \
               "<table class='spec-table'><thead><tr><th>Наименование печной фурнитуры и смесей</th><th>Расчетное количество</th></tr></thead><tbody>"
      part2.each do |item|
        name, qty = item.split(':')
        @html << "<tr><td>#{name}</td><td>#{qty}</td></tr>"
      end
      @html << "</tbody></table><div class='page-number'>9</div></div>"
    end

    def build_foundation_page
      @html << <<~HTML
        <div class='page'>
          #{page_header('Конструкция основания')}
          <h1>Спецификация фундаментного основания комплекса</h1>
          <div class='foundation-container'>
            <div class='image-box'><div class='image-title'>Угловой 3D-разрез фундаментной плиты</div><div class='img-wrapper'><img src='#{Config.drawings_path('foundation.png')}'></div></div>
            <div style='flex:1; display:flex; flex-direction:column; justify-content:flex-start; font-size:10pt;'>
              <h3 style='margin:0 0 2mm 0; color:#d35400; border-bottom:2px solid #d35400; padding-bottom:1mm;'>Технические параметры плиты:</h3>
              <ul style='margin:0; padding-left:5mm; line-height:1.4;'>
                <li><b>Тип конструкции:</b> Монолитная плита</li>
                <li><b>Марка бетона:</b> Не ниже B22.5 (М300)</li>
                <li><b>Армирование:</b> Сетка из арматуры Ø 12 мм</li>
                <li><b>Шаг ячейки:</b> 200х200 мм</li>
                <li><b>Гидроизоляция:</b> Два слоя рубероида</li>
              </ul>
            </div>
          </div>
          <div class='page-number'>10</div>
        </div>
      HTML
    end

    def build_masonry_pages
      (1..54).each do |r|
        rf = r.to_s.rjust(2, '0')
        cp = r + 10
        info = @spec.bricks_per_row[r]

        pts = []
        pts << "Лицевой LF: #{info[:lf]} шт." if info[:lf] > 0
        pts << "Строительный SP: #{info[:sp]} шт." if info[:sp] > 0
        pts << "Шамотный ШБ-8: #{info[:sh8]} шт." if info[:sh8] > 0
        brick_text = pts.join(" | ")

        # Получаем дополнительные изображения для этого ряда
        extra_top = extra_image_for_type(r, 'top')
        extra_iso = extra_image_for_type(r, 'iso')

        @html << "<div class='page'>#{page_header('Порядовая сборка')}<div class='row-header-area'>" \
                 "<h1>Ряд №#{r}</h1>" \
                 "<div class='row-badge' style='width: 78%; max-width: 78%; margin-bottom: 0;'>#{brick_text}"

        if @spec.casting_per_row[r] != "Нет"
          items = @spec.casting_per_row[r].split(',').map(&:strip)
          counts = Hash.new(0)
          items.each do |item|
            clean = item.gsub(/\s*\(\d+\s*шт\)/, '').strip
            counts[clean] += 1
          end
          summary = counts.map { |name, cnt| "#{name} (#{cnt} шт)" }
          @html << "<span>Монтаж: #{summary.join(', ')}</span>"
        end

        @html << "</div></div>"

        # Вид сверху
        @html << "<div class='row-container'>"
        @html << "<div class='image-box'>"
        @html << "<div class='image-title'>Вид сверху (План раскладки швов)</div>"
        @html << "<div class='img-wrapper'><img src='#{Config.top_view_path("row_#{rf}.png")}'></div>"
        if extra_top
          @html << "<div class='extra-overlay extra-bottom-left'><img src='#{extra_top}'></div>"
        end
        @html << "</div>"

        # Изометрия
        @html << "<div class='image-box'>"
        @html << "<div class='image-title'>Изометрия (Объемное накопление)</div>"
        @html << "<div class='img-wrapper'><img src='#{Config.iso_view_path("row_#{rf}.png")}'></div>"
        if extra_iso
          @html << "<div class='extra-overlay extra-top-right'><img src='#{extra_iso}'></div>"
        end
        @html << "</div>"
        @html << "</div>"

        # Блок заметок
        @html << note_block(r)
        @html << "<div class='page-number'>#{cp}</div></div>"
      end
    end
  end

  # ----------------------------------------------------------------------------
  # ТОЧКА ВХОДА
  # ----------------------------------------------------------------------------
  def self.generate_html_guide
    model = Sketchup.active_model
    model_title = model.title.empty? ? "Барбекю комплекс" : model.title

    base_dir = Config::BASE_DIR
    spec_path = File.join(base_dir, Config::SPEC_FILE)
    output_path = File.join(base_dir, Config::OUTPUT_FILE)

    FileUtils.mkdir_p(File.dirname(output_path))

    notes = NotesLoader.load_notes(base_dir)

    begin
      parser = SpecificationParser.new(spec_path)
    rescue => e
      UI.messagebox("ОШИБКА: #{e.message}")
      return
    end

    model_title = parser.model_title.empty? ? model_title : parser.model_title
    project_code = parser.project_code

    generator = HtmlAlbumGenerator.new(parser, notes, model_title, project_code)
    html_content = generator.generate

    File.open(output_path, "w:UTF-8") { |f| f.write(html_content) }
    puts "[+] Альбом успешно сгенерирован: #{output_path}"
    UI.messagebox("Альбом сгенерирован!\nФайл: #{output_path}")
  rescue => e
    UI.messagebox("Критическая ошибка: #{e.message}\n#{e.backtrace.join("\n")}")
  end
end

PechnikEngineeringHub.generate_html_guide if __FILE__ == $0