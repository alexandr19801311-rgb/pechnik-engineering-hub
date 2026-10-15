require "sketchup"

module PechnikBlackBox
  LOG_PATH = "D:/pechnik-engineering-hub/pechnik_brain.txt"

  # Наблюдатель за конкретными изменениями внутри модели
  class PechnikEntitiesObserver < Sketchup::EntitiesObserver
    def onElementAdded(entities, entity)
      return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
      PechnikBlackBox.write_log("ДОБАВЛЕН КИРПИЧ/УЗЕЛ: ID=#{entity.entityID} (Тэг: #{entity.layer.name})")
    end

    def onElementRemoved(entities, entity_id)
      PechnikBlackBox.write_log("УДАЛЕН КИРПИЧ/УЗЕЛ: ID=#{entity_id} (Поиск альтернативного решения)")
    end
  end

  # Наблюдатель, который автоматически включается при сохранении и изменении слоев
  class PechnikModelObserver < Sketchup::ModelObserver
    def onTransactionCommit(model)
      # Фиксируем изменения Тэгов у выделенных элементов
      model.selection.each do |e|
        if (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) && e.layer
          PechnikBlackBox.write_log("ИЗМЕНЕН ТЭГ: Элемент ID=#{e.entityID} переведен на Тэг [#{e.layer.name}]")
        end
      end
    end

    def onPostSaveModel(model)
      PechnikBlackBox.write_log("💾 ИЗМЕНЕНИЯ СОХРАНЕНЫ: Мастер-модель зафиксирована на диске D. Версия обновлена.")
    end
  end

  # Шпион автозапуска для отслеживания открытия файлов
  class PechnikAppObserver < Sketchup::AppObserver
    def onNewModel(model) PechnikBlackBox.attach_observers(model) end
    def onOpenModel(model) PechnikBlackBox.attach_observers(model) end
  end

  def self.attach_observers(model)
    model.entities.add_observer(PechnikEntitiesObserver.new)
    model.add_observer(PechnikModelObserver.new)
  end

  def self.write_log(message)
    # Создаем файл лога, если его нет
    File.write(LOG_PATH, "") unless File.exist?(LOG_PATH)
    
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    File.open(LOG_PATH, "a") do |f|
      f.puts "[#{timestamp}] #{message}"
    end
  end

  # Инициализация при старте SketchUp
  if !@loaded
    Sketchup.add_observer(PechnikAppObserver.new)
    PechnikBlackBox.attach_observers(Sketchup.active_model) if Sketchup.active_model
    PechnikBlackBox.write_log("🚀 ИНЖЕНЕРНОЕ ЯДРО ПЕЧНИКА ЗАПУЩЕНО. Начинаю фиксацию опыта проектирования...")
    @loaded = true
  end
end