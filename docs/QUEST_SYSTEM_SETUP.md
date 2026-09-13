# 🎯 Налаштування системи квест-менеджменту

## Огляд

Система квест-менеджменту дозволяє налаштувати етапи сцени через Resource файли в Godot Editor. Кожна сцена має свою конфігурацію з етапами, діалогами та доступними сценами для переходу.

## Структура

### QuestStageResource
Resource для налаштування одного етапу:
- `stage_name` - назва етапу
- `stage_id` - унікальний ID
- `required_dialogues` - список обов'язкових діалогів
- `available_scenes` - список доступних сцен для переходу
- `required_flags` - опціональні квестові флаги

### SceneQuestConfig
Resource для конфігурації всієї сцени:
- `scene_name` - назва сцени
- `stages` - масив QuestStageResource (лінійні етапи)
- `require_all_stages` - чи потрібно завершити всі етапи
- `allow_progressive_unlock` - чи дозволити поступове розблокування

### SceneQuestManager
Компонент, який підключається до сцени:
- Відстежує прогрес діалогів
- Визначає поточний етап
- Розблоковує сцени після завершення етапів
- Емітує сигнали для інтеграції

## Створення конфігурацій

### 1. Створення QuestStageResource

1. В Godot Editor: **Right-click** → **New Resource**
2. Вибрати `QuestStageResource`
3. Налаштувати:
   - `stage_name`: "Початок каньону"
   - `stage_id`: "canyon_intro"
   - `required_dialogues`: ["Canyon_Intro", "Canyon_StartMonologue"]
   - `available_scenes`: ["Village.tscn"]

### 2. Створення SceneQuestConfig

1. В Godot Editor: **Right-click** → **New Resource**
2. Вибрати `SceneQuestConfig`
3. Налаштувати:
   - `scene_name`: "Canyon"
   - `stages`: [додати створені QuestStageResource]
   - `require_all_stages`: true/false
   - `allow_progressive_unlock`: true/false

### 3. Приклад конфігурації для Canyon

**Stage 1: Intro**
- `stage_name`: "Вступ"
- `stage_id`: "canyon_intro"
- `required_dialogues`: ["Canyon_Intro", "Canyon_StartMonologue"]
- `available_scenes`: []

**Stage 2: Exploration**
- `stage_name`: "Дослідження"
- `stage_id`: "canyon_exploration"
- `required_dialogues`: ["Canyon_Exploration"]
- `available_scenes`: []

**Stage 3: Abduction**
- `stage_name`: "Викрадення"
- `stage_id`: "canyon_abduction"
- `required_dialogues`: ["Canyon_AbductionCutscene", "RoadToVillage"]
- `available_scenes`: ["Village.tscn"]

### 4. Приклад конфігурації для Village

**Stage 1: Arrival**
- `stage_name`: "Прибуття"
- `stage_id`: "village_arrival"
- `required_dialogues`: ["VillageAbduction", "ArrivalToVillage"]
- `available_scenes`: []

**Stage 2: Fight**
- `stage_name`: "Бій"
- `stage_id`: "village_fight"
- `required_dialogues`: ["FightWithBandit"]
- `available_scenes`: []

**Stage 3: Old Man**
- `stage_name`: "Дід"
- `stage_id`: "village_oldman"
- `required_dialogues`: ["OldMan_Outside", "OldMan_Healing", "OldMan_Decision"]
- `available_scenes`: []

**Stage 4: Leaving**
- `stage_name`: "Вихід"
- `stage_id`: "village_leaving"
- `required_dialogues`: ["LeavingVillage"]
- `available_scenes`: ["Canyon.tscn"]

## Підключення до сцени

### 1. Додати SceneQuestManager до сцени

В `Canyon.tscn`:
1. Додати **Node** (назвати `SceneQuestManager`)
2. Призначити скрипт: `res://SampleProject/Scripts/Quest/SceneQuestManager.gd`
3. В Inspector призначити `quest_config`: `Canyon_Quest.tres`

### 2. Інтеграція з Scene Manager

В `Canyon.gd`:

```gdscript
@onready var quest_manager: SceneQuestManager = $SceneQuestManager

func _ready() -> void:
    if quest_manager:
        quest_manager.all_stages_completed.connect(_on_all_stages_completed)
        quest_manager.scene_unlocked.connect(_on_scene_unlocked)

func _on_all_stages_completed() -> void:
    DebugLogger.info("Canyon: Всі етапи завершені!", "Canyon")

func _on_scene_unlocked(scene_name: String) -> void:
    DebugLogger.info("Canyon: Сцена '%s' розблокована" % scene_name, "Canyon")
```

## Використання

### Перевірка готовності до переходу

```gdscript
func can_transition_to_village() -> bool:
    if quest_manager:
        return quest_manager.can_transition_to_scene("Village.tscn")
    return false
```

### Отримання доступних сцен

```gdscript
func get_available_scenes() -> Array[String]:
    if quest_manager:
        return quest_manager.get_available_scenes()
    return []
```

### Перевірка прогресу

```gdscript
func get_progress() -> float:
    if quest_manager:
        return quest_manager.get_progress_percentage()
    return 0.0
```

## Сигнали

- `stage_completed(stage_id, stage_name)` - етап завершено
- `all_stages_completed()` - всі етапи завершені
- `dialogue_completed(dialogue_id)` - діалог завершено
- `scene_unlocked(scene_name)` - сцена розблокована
- `progress_updated(completed, total)` - прогрес оновлено

## Переваги

1. **Візуальне налаштування** - все в Godot Editor
2. **Гнучкість** - легко додавати/змінювати етапи
3. **Автоматичне відстеження** - інтеграція з EventBus
4. **Розширюваність** - легко додавати нові функції
