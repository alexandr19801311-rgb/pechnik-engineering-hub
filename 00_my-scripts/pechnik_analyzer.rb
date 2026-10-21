# frozen_string_literal: true
# Encoding: UTF-8
# ==============================================================================
# ПЕЧНОЙ ИНЖЕНЕРНЫЙ ХАБ — АНАЛИЗАТОР v4.0 (ORIGIN + СЕТКА)
# ==============================================================================
require 'sketchup'
require 'json'
require_relative 'pechnik_config'

module PechnikEngineeringHub
  module Analyzer
    def self.analyze_current_model
      model = Sketchup.active_model
      anatomy = { model_title: model.title, rows: {} }

      get_ents = ->(inst) { inst.is_a?(Sketchup::Group) ? inst.entities : (inst.is_a?(Sketchup::ComponentInstance) ? inst.definition.entities : []) }

      collect_bricks = ->(entities, parent_transform, row_data) do
        entities.each do |ent|
          if ent.is_a?(Sketchup::ComponentInstance) && ent.definition.name =~ /^(LF|SP|SH8)/
            def_name = ent.definition.name.gsub(/#\d+/, '').strip
            final_tr = parent_transform * ent.transformation
            
            # 1. Берем ГЛОБАЛЬНУЮ точку вставки (Origin)
            origin = final_tr.origin
            
            # 2. Вычисляем поворот (0, 90, 180, -90)
            x_axis = final_tr.xaxis
            angle = Math.atan2(x_axis.y, x_axis.x).radians.round
            
            # 3. Округляем до сетки (65 для LF/SP, 63 для SH8)
            grid = def_name.start_with?("SH8") ? 63 : 65
            snapped_x = (origin.x.to_mm / grid).round * grid
            snapped_y = (origin.y.to_mm / grid).round * grid
            
            row_data[:bricks] << {
              sku: def_name,
              x: snapped_x,
              y: snapped_y,
              rot: angle
            }
          elsif ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
            next_tr = parent_transform * (ent.respond_to?(:transformation) ? ent.transformation : Geom::Transformation.new)
            collect_bricks.call(get_ents.call(ent), next_tr, row_data)
          end
        end
      end

      find_rows = ->(entities, parent_transform) do
        entities.each do |ent|
          next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
          layer_name = ent.layer.name.downcase
          
          if layer_name =~ /row_(\d+)|ряд_(\d+)/
            row_num = ($1 || $2).to_i
            anatomy[:rows][row_num] ||= { bricks: [] }
            tr = parent_transform * (ent.respond_to?(:transformation) ? ent.transformation : Geom::Transformation.new)
            collect_bricks.call(get_ents.call(ent), tr, anatomy[:rows][row_num])
          else
            tr = parent_transform * (ent.respond_to?(:transformation) ? ent.transformation : Geom::Transformation.new)
            find_rows.call(get_ents.call(ent), tr)
          end
        end
      end

      find_rows.call(model.active_entities, Geom::Transformation.new)

      anatomy[:rows].each { |r, data| data[:bricks].sort_by! { |b| [b[:y], b[:x]] } }

      output_path = "#{Config::BASE_DIR}/02_specifications/project_anatomy_exact.json"
      File.write(output_path, JSON.pretty_generate(anatomy))
      UI.messagebox("АНАЛИЗ v4.0 ЗАВЕРШЕН!\nКоординаты Origin привязаны к сетке.")
    end
  end
end

PechnikEngineeringHub::Analyzer.analyze_current_model