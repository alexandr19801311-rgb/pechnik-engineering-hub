# Encoding: UTF-8
# Модуль BIM-сканера модели (v37.0)
# Проект 4020-НМ (Печник-Новосиб)

require 'sketchup'
require 'json'

module PechnikEngine
  def self.run_bim_scanner
    model = Sketchup.active_model
    entities = model.active_entities
    manifest_path = "D:/pechnik-engineering-hub/manifest_4020_nm.json"

    @furniture_log = {
      "building" => 1,
      "shb8" => 0,
      "red_brick" => 0,
      "errors_shov" => 0,
      "errors_ktr" => 0
    }

    puts ">>> ЗАПУСК BIM-СКАНЕРА: ПРОВЕРКА ШВОВ И КТР  e
      puts "[BIM ERROR] Ошибка записи манифеста: #{e.message}"
    end

    puts ">>> СКАН ИНЖЕНЕРНОГО ЯДРА ЗАВЕРШЕН <<<"
    puts "Найдено: Красный: #{@furniture_log['red_brick']} шт., Шамот: #{@furniture_log['shb8']} шт."
    
    # Автоматически выводим загруженность после сканирования
    PechnikEngine.show_session_load
  end

  # Модуль мониторинга загруженности сессии
  def self.show_session_load
    model = Sketchup.active_model
    
    # Сбор метрик SketchUp
    scenes_count = model.pages.length
    layers_count = model.layers.length
    definitions_count = model.definitions.length
    
    # Потребление памяти (приблизительное для Ruby GC)
    gc_stats = GC.stat
    heap_slots = gc_stats[:heap_live_slots] || 0
    
    puts "\n============================================="
    puts "📊 МОНИТОРИНГ ЗАГРУЖЕННОСТИ СЕССИИ (v37.0)"
    puts "============================================="
    puts "📍 Проект: 4020-НМ / Главный Разработчик: Александр"
    puts "🎬 Сцен в модели: #{scenes_count} / 54 порядовок"
    puts "🗂️ Активных слоев: #{layers_count}"
    puts "🧱 Уникальных компонентов (BIM): #{definitions_count}"
    puts "🧠 Живых объектов в памяти Ruby: #{heap_slots} слотов"
    puts "🧹 Статус сборщика мусора (GC): Свободен"
    puts "=============================================\n"
  end
end
