# ⚠️ ВАЖЛИВО: Виправлення конфлікту аддонів

## Проблема

Godot виявляє конфлікт між `maaacks_input_remapping` та `maaacks_menus_template`, оскільки обидва аддони мають однакові класи (`InputActionsList`, `InputActionsTree` тощо).

**Godot сканує ВСІ файли в `addons/`, навіть якщо аддон вимкнений!**

## Рішення (ОБОВ'ЯЗКОВО)

Оскільки `maaacks_menus_template` містить весь функціонал `maaacks_input_remapping` плюс додаткові меню, потрібно **перейменувати або видалити папку** `maaacks_input_remapping`.

### Варіант 1: Перейменувати папку (рекомендовано)

**КРОК 1:** Закрийте Godot повністю

**КРОК 2:** Перейменуйте папку:
- Відкрийте Провідник Windows
- Перейдіть до `addons/` в проекті
- Знайдіть папку `maaacks_input_remapping`
- Перейменуйте її на `maaacks_input_remapping.disabled` (права кнопка миші → Перейменувати)
- Або запустіть `disable_input_remapping.bat` (якщо Godot закритий)

**КРОК 3:** Відкрийте Godot знову

### Варіант 2: Видалити папку

Якщо ви впевнені, що не будете використовувати `maaacks_input_remapping`:

1. Закрийте Godot
2. Видаліть папку `addons/maaacks_input_remapping` (права кнопка миші → Видалити)
3. Відкрийте Godot знову

## Що вже зроблено

✅ Вимкнено `maaacks_input_remapping` в `project.godot`  
✅ Оновлено посилання в `input_options_menu.tscn` на використання `maaacks_menus_template`  
✅ Видалено дублікати перекладів  
✅ Видалено секцію `[maaacks_input_remapping]` з `project.godot`

## ⚠️ Після виконання

Після перейменування або видалення папки:
- Помилки "Class hides a global script class" мають зникнути
- WARNING про UID duplicate також зникнуть
- Проект буде використовувати тільки `maaacks_menus_template`

## Перевірка

Після перейменування/видалення папки в консолі Godot НЕ повинно бути:
- `ERROR: Class "InputActionsList" hides a global script class`
- WARNING про `maaacks_input_remapping` (тільки про `maaacks_menus_template`)
