# ⚠️ ВАЖЛИВО: Виправлення ВСІХ конфліктів аддонів

## Проблеми

1. **Конфлікт `maaacks_input_remapping` та `maaacks_menus_template`**
   - Обидва мають однакові класи (`InputActionsList`, `InputActionsTree` тощо)

2. **Конфлікт `maaacks_scene_loader` та `maaacks_menus_template`**
   - Обидва мають клас `SceneLoaderClass`
   - Обидва намагаються додати autoload `SceneLoader`

## Рішення

### Крок 1: Перейменуйте або видаліть папку `maaacks_input_remapping`

**ОБОВ'ЯЗКОВО:** Закрийте Godot перед цим!

1. Відкрийте Провідник Windows
2. Перейдіть до `addons/` в проекті
3. Знайдіть папку `maaacks_input_remapping`
4. Перейменуйте її на `maaacks_input_remapping.disabled`
   - Або видаліть папку, якщо вона не потрібна

### Крок 2: Перейменуйте або видаліть папку `maaacks_scene_loader`

**ОБОВ'ЯЗКОВО:** Закрийте Godot перед цим!

1. Відкрийте Провідник Windows
2. Перейдіть до `addons/` в проекті
3. Знайдіть папку `maaacks_scene_loader`
4. Перейменуйте її на `maaacks_scene_loader.disabled`
   - Або видаліть папку, якщо вона не потрібна

**Чому:** `maaacks_menus_template` вже містить весь функціонал обох аддонів!

### Крок 3: Відкрийте Godot

Після перейменування/видалення папок:
- Всі помилки "Class hides a global script class" мають зникнути
- WARNING про UID duplicate також зникнуть
- `SceneLoader` буде доступний через `maaacks_menus_template`

## Що вже зроблено

✅ Вимкнено `maaacks_input_remapping` в `project.godot`  
✅ Вимкнено `maaacks_scene_loader` в `project.godot`  
✅ Додано `SceneLoader` в autoload з `maaacks_menus_template`  
✅ Оновлено посилання в `input_options_menu.tscn` на використання `maaacks_menus_template`  
✅ Видалено дублікати перекладів  
✅ Видалено секції конфліктуючих аддонів з `project.godot`

## Після виконання

Після перейменування/видалення папок в консолі Godot НЕ повинно бути:
- ❌ `ERROR: Class "InputActionsList" hides a global script class`
- ❌ `ERROR: Class "SceneLoaderClass" hides a global script class`
- ❌ `ERROR: Identifier "SceneLoader" not declared`
- ❌ WARNING про `maaacks_input_remapping` або `maaacks_scene_loader`

## Альтернатива: Використовувати тільки окремі аддони

Якщо ви хочете використовувати окремі аддони замість `maaacks_menus_template`:
1. Вимкніть `maaacks_menus_template`
2. Увімкніть `maaacks_input_remapping` та `maaacks_scene_loader`
3. Додайте `SceneLoader` в autoload з `maaacks_scene_loader`

Але **рекомендовано** використовувати `maaacks_menus_template`, оскільки він містить весь функціонал плюс додаткові меню.
