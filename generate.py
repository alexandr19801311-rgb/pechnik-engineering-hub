"""
Генератор буклетов «Печных дел Мастер»
Использование:
    python generate.py <КОД> <АРТИКУЛ_ПРОЕКТА>
Пример:
    python generate.py 6143 3188-p2
"""

import sys
import json


def main():
    # 1. Проверяем аргументы
    if len(sys.argv) != 3:
        print("Использование: python generate.py <КОД> <АРТИКУЛ>")
        print("Пример:        python generate.py 6143 3188-p2")
        sys.exit(1)

    code = sys.argv[1].strip()
    project_key = sys.argv[2].strip().lower()

    # 2. Проверяем код
    if not code.isdigit() or len(code) < 3:
        print(f"Ошибка: код '{code}' должен состоять минимум из 3 цифр.")
        sys.exit(1)

    # 3. Читаем базу проектов
    try:
        with open("projects.json", "r", encoding="utf-8") as f:
            projects = json.load(f)
    except FileNotFoundError:
        print("Ошибка: файл projects.json не найден в текущей папке.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Ошибка в projects.json: {e}")
        sys.exit(1)

    # 4. Ищем проект
    if project_key not in projects:
        print(f"Ошибка: проект '{project_key}' не найден в базе.")
        print("Доступные артикулы:")
        for key in sorted(projects.keys()):
            print(f"  - {key}")
        sys.exit(1)

    project = projects[project_key]

    # 5. Читаем шаблон
    try:
        with open("template.html", "r", encoding="utf-8") as f:
            template = f.read()
    except FileNotFoundError:
        print("Ошибка: файл template.html не найден.")
        sys.exit(1)

    # 6. Подставляем значения
    html = template
    html = html.replace("{{CODE}}", code)
    html = html.replace("{{NAME}}", project["name"])
    html = html.replace("{{COVER_TITLE}}", project["cover_title"])
    html = html.replace("{{RENDER}}", project["render"])
    html = html.replace("{{LENGTH_MM}}", str(project["length_mm"]))
    html = html.replace("{{WIDTH_MM}}", str(project["width_mm"]))
    html = html.replace("{{MANGAL_MM}}", str(project["mangal_mm"]))
    html = html.replace("{{PLITA_MM}}", project["plita_mm"])

    # 7. Сохраняем результат
    output_file = f"buklet_{code}_{project_key}.html"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✓ Готово: {output_file}")
    print(f"  Проект: {project['name']}")
    print(f"  Код: {code}")
    print("")
    print("Откройте файл в Chrome и нажмите Ctrl+P для сохранения в PDF.")


if __name__ == "__main__":
    main()