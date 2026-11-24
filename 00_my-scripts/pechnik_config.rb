# frozen_string_literal: true
# Pechnik Engineering Hub — Глобальная конфигурация (v1.0)
require 'sketchup'

module PechnikEngineeringHub
  module Config
    # --- ГЕОМЕТРИЯ И СЕТКИ ---
    # Лицевой (LF) и Забутовка (SP): 1НФ 250x120x65
    LF_SP_BRICK_L = 250
    LF_SP_BRICK_W = 120
    LF_SP_BRICK_H = 65
    LF_SP_JOINT_H = 10
    LF_SP_JOINT_V = 10
    LF_SP_GRID = 65         # Шаг привязки X/Y
    LF_SP_ROW_HEIGHT = 75   # 65 + 10
    
    # Шамот (SH8): ШБ-8 250x124x65
    SH8_BRICK_L = 250
    SH8_BRICK_W = 124
    SH8_BRICK_H = 65
    SH8_JOINT_H = 4
    SH8_JOINT_V = 2
    SH8_GRID = 63           # Шаг привязки X/Y
    SH8_ROW_HEIGHT = 69     # 65 + 4

    # --- ВЕСА И РАСХОД ---
    WEIGHT_LF  = 3.7
	WEIGHT_LF_DARK = 3.7
    WEIGHT_SP  = 3.5
    WEIGHT_SH8 = 3.4
    
    # Пороги для определения половинок (в мм)
    HALF_THRESHOLD = {
      "LF" => 120,
	  "LF_DARK" => 120,
      "SP" => 120,
      "SH8" => 124
    }

    # --- НАСТРОЙКИ ЭКСПОРТА ---
    EXPORT_SLEEP_SEC = 0.50 # Поставь 0.0 для быстрых тестов
    TOTAL_ROWS = 54
    BASE_DIR = "D:/pechnik-engineering-hub"
  end
end