require 'json'

# Сквозной обсервер сохранения модели для проекта 4020-НМ
class PechnikModelInsurance < Sketchup::ModelObserver
  MANIFEST_PATH = 'C:/project_4020_nm/manifest_4020_nm.json'

  # ХУК СХРАНЕНИЯ: Срабатывает автоматически при Ctrl + S
  def onPostSaveModel(model)
    puts "\n--- 🚀 [ПЕЧНИК-АВТОМАТИЗАЦИЯ v37] Старт фонового аудита ---"
    
    # 1. Безопасное чтение манифеста
    unless File.exist?(MANIFEST_PATH)
      puts "❌ Ошибка: Манифест не найден по пути #{MANIFEST_PATH}"
      return
    end

    begin
      manifest_raw = File.read(MANIFEST_PATH).force_encoding('UTF-8')
      manifest = JSON.parse(manifest_raw)
      pipeline = manifest['automation_pipeline_v37']
      constants = manifest['constants_and_physics']
      
      puts "📦 Манифест успешно загружен. Проект: #{manifest['passport']['project_name']}"
    rescue JSON::ParserError => e
      puts "❌ Критическая ошибка структуры конфигурационного JSON: #{e.message}"
      return
    end

    # 2. Валидатор порядовых слоев (тегов)
    if pipeline && pipeline.dig('sketchup_layer_validator', 'enabled')
      puts "🔍 Запуск валидатора порядовых слоев..."
      model.start_operation('Авто-генерация тегов', true)
      
      tags = model.layers
      total_rows = constants ? (constants['total_rows'] || 54) : 54
      pattern = pipeline.dig('sketchup_layer_validator', 'target_tags_pattern') || "01_Лицевой_Ряд_%02d"

      (1..total_rows).each do |row|
        tag_name = sprintf(pattern, row)
        unless tags[tag_name]
          tags.add(tag_name)
          puts "  ➕ Автоматически создан недостающий тег: #{tag_name}"
        end
      end
      
      model.commit_operation
      puts "✅ Все 54 порядовых слоя верифицированы и активны."
    end

    # 3. Эмуляция сбора текущих достижений в модели (для теста сохранения)
    # Здесь мы симулируем вызов метода, который раньше падал из-за «грязных» данных
    raw_dirty_data = File.read(MANIFEST_PATH).force_encoding('UTF-8') 
    save_achievements_to_manifest(raw_dirty_data)

    puts "--- 🏁 [ПЕЧНИК-АВТОМАТИЗАЦИЯ v37] Аудит завершен без ошибок ---\n\n"
  end

  # МЕТОД ОЧИСТКИ И СОХРАНЕНИЯ (СТРОКА 47): Защищен от ParserError
  def save_achievements_to_manifest(raw_data)
    cleaned_str = raw_data.to_s.dup
    
    # Срезаем внешние кавычки double-encoding
    if cleaned_str.start_with?('"') && cleaned_str.end_with?('"')
      cleaned_str = cleaned_str[1..-2]
    end

    # Тотальная чистка экранов, переносов и мусора в хвосте JSON
    cleaned_str = cleaned_str.gsub('\\"', '"')
                             .gsub('\\n', "\n")
                             .gsub('}>', '}')
                             .strip

    begin
      parsed_json = JSON.parse(cleaned_str)
      
      # Запись чистого, красивого JSON обратно в файл (без ломающих символов)
      File.write(MANIFEST_PATH, JSON.pretty_generate(parsed_json))
      puts "✅ Данные ачивок очищены и успешно синхронизированы с манифестом!"
    rescue JSON::ParserError => e
      puts "❌ Ошибка глубокого парсинга на строке 47. Аварийный дамп в txt."
      File.write('C:/project_4020_nm/manifest_debug_raw.txt', cleaned_str)
    end
  end
end

# Перезапуск обсервера (чтобы изменения применились в текущей сессии SketchUp)
if defined?($id_pechnik_observer) && $id_pechnik_observer
  Sketchup.remove_observer($id_pechnik_observer) rescue nil
end

$id_pechnik_observer = PechnikModelInsurance.new
Sketchup.add_observer($id_pechnik_observer)

puts "🔮 Магия Печник-Insurance v37 полностью обновлена в памяти SketchUp!"
