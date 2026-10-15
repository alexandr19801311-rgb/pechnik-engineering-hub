# Pechnik Engineering Hub

Инструменты для разработки, экспорта и выдачи проектов барбекю-комплексов «Печных дел Мастер».

**Сайт:** [pechnik-novosib.ru](https://pechnik-novosib.ru)  
**Контакт:** master-pechi@mail.ru

---

## Что это

Набор скриптов и веб-интерфейсов для:
- Генерации порядовочных чертежей из 3D-моделей SketchUp
- Сборки технических альбомов (A4 landscape, HTML → PDF)
- Выдачи PDF-проектов и 3D-моделей покупателям по кодам активации
- Генерации полиграфических буклетов для маркетплейсов

---

## Структура

| Папка | Назначение |
|---|---|
| `00_my-scripts/` | Ruby-скрипты для SketchUp (экспорт порядовок, генератор альбома) |
| `02_specifications/` | Спецификации материалов |
| `project-4020-nm/` | Данные проекта 4020-НМ (JSON-спецификации, манифест) |
| — | — |
| `.gitignore` | Правила игнорирования (PNG, HDRI, `.glb`, `keys.json`) |
| `generate.py` | Генератор PDF-буклетов (Python) |
| `manifest_4020_nm.json` | Манифест проекта 4020-НМ |
| `notes.txt` | Заметки к рядам кладки |
| `pechnik_brain.txt` | Логика/справочник проекта |
| `player.html` | 3D-плеер на Three.js |
| `projects.json` | База 26 проектов (для буклет-генератора) |
| `template.html` | Шаблон буклета A4 landscape |
| `wc.php` | Серверная проверка кодов активации |

---

## Быстрый старт

### Экспорт порядовок из SketchUp

1. Открыть модель в SketchUp
2. Extensions → Pechnik Engineering Hub → Export scenes
3. Результат: `01_scenes/top_view/row_NN.png` + `01_scenes/iso_view/row_NN.png`

### Генерация PDF-буклета

```bash
python generate.py <КОД> <АРТИКУЛ>
# Пример: python generate.py 6143 3188-p2
