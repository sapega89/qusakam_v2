# Обзор систем проекта

Этот документ описывает все системы, перенесенные из проекта "пролог гейм" в текущий проект.

## Структура систем

### Core Systems (Ядро)

#### ServiceLocator
- **Путь:** `SampleProject/Scripts/Core/ServiceLocator.gd`
- **Описание:** Сервис-локатор для централизованного доступа к менеджерам и сервисам
- **Autoload:** `ServiceLocator` (сцена: `SampleProject/Scenes/ServiceLocator.tscn`)
- **Использование:** `ServiceLocator.get_*_manager()` для получения менеджеров

#### EventBus
- **Путь:** `SampleProject/Scripts/Core/EventBus.gd`
- **Описание:** Централизованная система событий (Observer Pattern)
- **Autoload:** `EventBus` (сцена: `SampleProject/Scenes/EventBus.tscn`)
- **Сигналы:** player_health_changed, enemy_died, item_added, inventory_updated, dialogue_finished, scene_transition_completed и др.

#### GameGroups
- **Путь:** `SampleProject/Scripts/Core/GameGroups.gd`
- **Описание:** Централизованные константы для групп узлов с кэшированием
- **Использование:** `GameGroups.get_player()`, `GameGroups.get_enemies()` и др.

#### ResourcePaths
- **Путь:** `SampleProject/Scripts/Core/ResourcePaths.gd`
- **Описание:** Централизованные пути к ресурсам (сцены, скрипты, данные)

#### GameSettings
- **Путь:** `SampleProject/Scripts/Core/GameSettings.gd`
- **Описание:** Централизованные настройки игры (константы, дефолтные значения)
- **Исключено:** level, experience, stat_points (используется система из текущего проекта)

### Systems (Системы)

#### Inventory & Items
- **Inventory.gd** - Resource класс для инвентаря
- **InventoryManager.gd** - Менеджер инвентаря (добавление/удаление предметов)
- **ItemDatabase.gd** - База данных предметов (загрузка из JSON)
- **LootSystem.gd** - Система дропа лута с врагов

#### Save System
- **SaveSystem.gd** - Система сохранения/загрузки
- **Autoload:** `SaveSystem` (сцена: `SampleProject/Scenes/Systems/SaveSystem.tscn`)
- **Исключено:** level, experience, experience_to_next_level, stat_points
- **Поддержка:** Флаги квестов, диалогов, катсцен, боссов, локаций через Game.gd

#### Dialogue System
- **DialogueManager.gd** - Менеджер диалогов (интеграция с DialogueQuest)
- **DialogueRunner.gd** - Запуск диалогов по ID
- **DialogueTrigger.gd** - Триггер для запуска диалогов (Area2D)

#### Cutscene System
- **CutsceneManager.gd** - Менеджер катсцен
- **CutsceneStep.gd** - Базовый класс для шагов катсцены
- **CutsceneDialogueStep.gd** - Шаг катсцены с диалогом
- **CutsceneImageStep.gd** - Шаг катсцены с изображением
- **CutsceneVideoStep.gd** - Шаг катсцены с видео

#### Audio & Display
- **AudioManager.gd** - Менеджер аудио (звуковые эффекты)
- **MusicManager.gd** - Менеджер музыки (фоновые треки)
- **DisplayManager.gd** - Менеджер отображения (fullscreen, vsync)
- **SettingsManager.gd** - Менеджер настроек игры
- **LocalizationManager.gd** - Менеджер локализации

#### Other Systems
- **VFXHooks.gd** - Хуки для визуальных эффектов
- **StatCalculator.gd** - Калькулятор производных статов
- **CharacterAttributes.gd** - Resource класс для атрибутов персонажа
- **ForgeSystem.gd** - Система улучшения оружия/брони (заглушка)

### Managers (Менеджеры)

#### Gameplay Managers
- **PlayerStateManager.gd** - Управление состоянием игрока (БЕЗ level/experience)
- **CharacterManager.gd** - Управление персонажами (БЕЗ level/experience)
- **EquipmentManager.gd** - Управление экипировкой
- **EnemyStateManager.gd** - Управление состоянием врагов (мертв/жив)
- **CompanionManager.gd** - Управление спутниками

#### Scene Managers
- **SceneManager.gd** - Управление переходами между сценами
- **TransitionManager.gd** - Управление переходами между комнатами/зонами (Metroidvania)
- **ParallaxManager.gd** - Управление параллакс-слоями

#### UI Managers
- **UIManager.gd** - Централизованный доступ к UI элементам
- **UIUpdateManager.gd** - Автоматическое обновление UI через EventBus
- **MenuManager.gd** - Управление игровым меню

#### Other Managers
- **TimeManager.gd** - Управление временем игры (пауза, time scale)
- **GameMusicManager.gd** - Управление музыкой игры
- **DebugManager.gd** - Управление режимом отладки

### Combat System (Боевая система)

#### Core
- **CombatSystem.gd** - Основная система боя
- **CombatBody2D.gd** - Базовый класс для боевых сущностей (extends CharacterBody2D)
- **ICombatant.gd** - Интерфейс для боевых сущностей
- **IDamageable.gd** - Интерфейс для получающих урон
- **IDamageDealer.gd** - Интерфейс для наносящих урон

#### Components
- **HealthComponent.gd** - Компонент здоровья
- **HurtboxComponent.gd** - Компонент зоны получения урона
- **DamageApplier.gd** - Компонент нанесения урона

#### UI
- **HealthBar.gd** - Полоса здоровья (базовая)
- **EnemyHealthBar.gd** - Полоса здоровья врага (с автоскрытием)

### Gameplay Components (Игровые компоненты)

#### Enemies
- **DefaultEnemy.gd** - Базовый класс врага (extends CombatBody2D)
- **EnemyMelee.gd** - Враг ближнего боя
- **EnemyRanged.gd** - Враг дальнего боя
- **EnemyFast.gd** - Быстрый враг
- **EnemyTank.gd** - Танковый враг
- **EnemyLogic.gd** - Логика AI врага
- **EnemyView.gd** - Визуальное представление врага

#### Bosses
- **DemoBoss.gd** - Демо-босс с фазами и специальными атаками

#### Companions
- **CompanionShield.gd** - Спутник-щит
- **CompanionHealer.gd** - Спутник-лекарь
- **CompanionFire.gd** - Спутник-огонь
- **CompanionUtility.gd** - Спутник-утилита (скорость, телепорт, стан)

#### NPCs
- **Merchant.gd** - Торговец (открывает магазин)

#### Objects
- **SpawnPortal.gd** - Порталы спавна игрока
- **Potion.gd** - Зелье (UI компонент)
- **PlayerProjectile.gd** - Снаряд игрока

### UI Components

#### Basic UI
- **HealthBar.gd** - Полоса здоровья
- **EnemyHealthBar.gd** - Полоса здоровья врага
- **GoldDisplay.gd** - Отображение золота
- **TimerDisplay.gd** - Отображение времени игры
- **UIPanel.gd** - Панель UI (контейнер)
- **GameTitle.gd** - Заголовок игры
- **YesNoDialog.gd** - Диалог подтверждения
- **DialogueUI.gd** - UI для диалогов
- **InventoryUI.gd** - UI инвентаря
- **PauseMenu.gd** - Меню паузы
- **ItemInfoTooltip.gd** - Подсказка с информацией о предмете

### Scenes (Сцены)

#### UI Scenes
- `health_bar.tscn` - Сцена полосы здоровья
- `enemy_health_bar.tscn` - Сцена полосы здоровья врага
- `gold_display.tscn` - Сцена отображения золота
- `timer_display.tscn` - Сцена отображения времени
- `ui_panel.tscn` - Сцена панели UI
- `yes_no_dialog.tscn` - Сцена диалога подтверждения
- `game_title.tscn` - Сцена заголовка игры

#### Gameplay Scenes
- `potion.tscn` - Сцена зелья
- `merchant.tscn` - Сцена торговца
- `spawn_portal.tscn` - Сцена портала спавна
- `player_projectile.tscn` - Сцена снаряда игрока

## Интеграция с текущим проектом

### Game.gd
- **Модифицирован** для поддержки флагов квестов, диалогов, катсцен, боссов и локаций
- **Методы:** `get_quest_flags()`, `set_quest_flags()`, `get_cutscene_flags()`, и т.д.
- **Интеграция:** Сохранение/загрузка флагов через SaveSystem

### Исключения
- **НЕ перенесено:** Система уровней (level, experience, experience_to_next_level, stat_points)
- **НЕ перенесено:** GameState.gd (используется Game.gd + MetSys SaveManager)
- **НЕ перенесено:** WorldMapManager.gd (уже есть своя система)

### Autoload Singletons
- `MetSys` - Metroidvania System
- `EventBus` - Система событий
- `DialogueQuest` - Плагин диалогов
- `SaveSystem` - Система сохранения
- `ServiceLocator` - Сервис-локатор

## Зависимости

### Обязательные аддоны
- **DialogueQuest** - Для системы диалогов
  - Установка: Asset Library или GitHub
  - Путь: `addons/dialogue_quest/`
  - Autoload: `DialogueQuest`

### Опциональные аддоны
- **item_database** - Не требуется (ItemDatabase.gd работает с JSON)
- **basic_settings_menu** - Не требуется (можно создать свой UI)

## Использование

### Получение менеджеров
```gdscript
var inventory_manager = ServiceLocator.get_inventory_manager()
var scene_manager = ServiceLocator.get_scene_manager()
var save_system = ServiceLocator.get_save_system()
```

### Работа с EventBus
```gdscript
# Подписка на события
EventBus.player_health_changed.connect(_on_player_health_changed)
EventBus.item_added.connect(_on_item_added)

# Отправка событий
EventBus.player_health_changed.emit(80, 100)
EventBus.item_added.emit("potion", 1)
```

### Работа с GameGroups
```gdscript
# Получение игрока
var player = GameGroups.get_player()

# Получение всех врагов
var enemies = GameGroups.get_enemies()

# Получение первого врага
var enemy = GameGroups.get_first_node_in_group(GameGroups.ENEMIES)
```

### Работа с флагами в Game.gd
```gdscript
# Установка флага квеста
Game.get_singleton().set_quest_flag("quest_1_completed", true)

# Получение флага квеста
var completed = Game.get_singleton().get_quest_flag("quest_1_completed", false)

# Сохранение флагов (автоматически через SaveSystem)
Game.get_singleton().save_game()
```

## Документация

- **Combat System:** `docs/Combat/COMBAT_SYSTEM_ARCHITECTURE.md`
- **Combat Setup:** `docs/Combat/COMBAT_SETUP_GUIDE.md`
- **Addons:** `docs/ADDONS_REQUIRED.md`
- **Collision Layers:** `docs/Combat/COLLISION_LAYERS_SETUP.md`

## Примечания

- Все системы адаптированы под текущий проект
- Исключены все упоминания level/experience/stat_points
- Интеграция с GameGroups, EventBus и ServiceLocator
- Сохранение флагов через SaveSystem и Game.gd
- Использование MetSys SaveManager для совместимости с Metroidvania System

