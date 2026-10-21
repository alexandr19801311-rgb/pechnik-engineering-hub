# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ — ЗАГРУЗЧИК БИБЛИОТЕКИ
# ==============================================================================
require 'sketchup'
require_relative 'pechnik_config'

module PechnikEngineeringHub
  module LibraryLoader
    LIBRARY_PATH = File.join(Config::BASE_DIR, "04_library")

    def self.load_all
      model = Sketchup.active_model
      
      unless Dir.exist?(LIBRARY_PATH)
        UI.messagebox("ОШИБКА: Папка библиотеки не найдена!\nСоздайте: #{LIBRARY_PATH}")
        return
      end

      # Находим все .skp файлы рекурсивно
      files = Dir.glob(File.join(LIBRARY_PATH, "**", "*.skp"))
      
      if files.empty?
        UI.messagebox("В папке библиотеки нет .skp файлов.")
        return
      end

      loaded_count = 0
      model.start_operation("Загрузка библиотеки", true)

      files.each do |file|
        file_name = File.basename(file, ".skp")
        
        # Проверяем, есть ли уже такое определение в модели
        exists = model.definitions.any? { |d| d.name.gsub(/#\d+/, '').strip == file_name }
        next if exists

        begin
          # Загружаем компонент (path, status)
          defn = model.definitions.load(file)
          if defn
            # Переименовываем, чтобы убрать пути
            defn.name = file_name
            loaded_count += 1
          end
        rescue => e
          puts "Ошибка загрузки #{file}: #{e.message}"
        end
      end

      model.commit_operation
      UI.messagebox("БИБЛИОТЕКА ЗАГРУЖЕНА!\nНайдено файлов: #{files.size}\nНовых компонентов: #{loaded_count}")
    end
  end
end

# Запуск
PechnikEngineeringHub::LibraryLoader.load_all