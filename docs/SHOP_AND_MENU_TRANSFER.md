# Перенос Shop и Game Menu

## Перенесенные скрипты

### Shop System
- ✅ `SampleProject/Scripts/Shop/shop_ui.gd` - Основной скрипт магазина
- ✅ `SampleProject/Scripts/Shop/buy_item_list_display.gd` - Отображение товаров для покупки
- ✅ `SampleProject/Scripts/Shop/sell_item_list_display.gd` - Отображение инвентаря для продажи
- ✅ `SampleProject/Scripts/Shop/tooltip.gd` - Подсказка с информацией о предмете
- ⚠️ `SampleProject/Scripts/Shop/item_list_display.gd` - **ТРЕБУЕТ АДДОН** `godot_tree_table` (класс Table)

### Game Menu System
- ✅ `SampleProject/Scripts/Menus/Game/game_menu.gd` - Основной скрипт игрового меню
- ✅ `SampleProject/Scripts/Menus/Game/game menu_central_panel_manager.gd` - Менеджер центральной панели

### Components
- ✅ `SampleProject/Scripts/Components/base_menu.gd` - Базовый класс для всех меню

## Требования

### Обязательные аддоны
1. **godot_tree_table** - Для работы `ItemListDisplay` (класс `Table`)
   - Без него `shop_menu.tscn` не будет работать полностью
   - Можно создать упрощенную версию без таблиц

### Опциональные зависимости
- Текстуры и темы из исходного проекта (можно заменить на свои)

## Сцены

Сцены (`shop_menu.tscn`, `game_menu.tscn`, `base_menu.tscn` и т.д.) требуют:
1. Установки аддона `godot_tree_table`
2. Адаптации путей к ресурсам (текстуры, темы)
3. Настройки структуры узлов

**Рекомендация:** Создайте сцены вручную в Godot Editor, используя перенесенные скрипты как основу.

## Адаптации

Все скрипты адаптированы для использования `Engine.get_singleton("ServiceLocator")` вместо прямого доступа к `ServiceLocator`.

## Следующие шаги

1. Установите аддон `godot_tree_table` (если нужен полный функционал магазина)
2. Создайте сцены вручную или адаптируйте пути в исходных `.tscn` файлах
3. Настройте пути к ресурсам (текстуры, темы, JSON файлы)
4. Протестируйте работу магазина и игрового меню

