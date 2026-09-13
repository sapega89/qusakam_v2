# ✅ Реалізація системи квест-менеджменту

## Створені файли

### 1. Resource класи

- **`QuestStageResource.gd`** - Resource для налаштування етапу
  - Містить список обов'язкових діалогів
  - Містить список доступних сцен для переходу
  - Підтримує опціональні квестові флаги

- **`SceneQuestConfig.gd`** - Resource для конфігурації всієї сцени
  - Містить масив етапів (QuestStageResource)
  - Налаштування поведінки (require_all_stages, allow_progressive_unlock)

### 2. Компоненти

- **`SceneQuestManager.gd`** - Основний менеджер квестів
  - Відстежує прогрес діалогів через EventBus
  - Визначає поточний етап
  - Розблоковує сцени після завершення етапів
  - Емітує сигнали для інтеграції

- **`QuestProgressUI.gd`** - UI компонент для відображення прогресу
  - Показує поточний етап
  - Відображає прогрес-бар
  - Показує список діалогів зі статусами

- **`QuestDialogueItem.gd`** - Елемент списку діалогів
  - Відображає назву діалогу
  - Показує статус (завершено/не завершено)

### 3. Інтеграція

- **`Canyon.gd`** - Додано опціональну підтримку SceneQuestManager
  - Автоматичне знаходження менеджера в сцені
  - Методи для перевірки готовності до переходу
  - Обробники сигналів від менеджера

- **`Village.gd`** - Додано опціональну підтримку SceneQuestManager
  - Автоматичне знаходження менеджера в сцені
  - Методи для перевірки готовності до переходу
  - Обробники сигналів від менеджера

## Як використовувати

### 1. Створення конфігурації в Godot Editor

1. **Створити QuestStageResource:**
   - Right-click → New Resource → QuestStageResource
   - Налаштувати:
     - `stage_name`: "Вступ"
     - `stage_id`: "canyon_intro"
     - `required_dialogues`: ["Canyon_Intro", "Canyon_StartMonologue"]
     - `available_scenes`: ["Village.tscn"]

2. **Створити SceneQuestConfig:**
   - Right-click → New Resource → SceneQuestConfig
   - Налаштувати:
     - `scene_name`: "Canyon"
     - `stages`: [додати створені QuestStageResource]
     - `require_all_stages`: true
     - `allow_progressive_unlock`: false

3. **Зберегти Resource:**
   - Зберегти як `Canyon_Quest.tres` в `SampleProject/Resources/Quest/`

### 2. Підключення до сцени

1. **Відкрити сцену** (наприклад, `Canyon.tscn`)

2. **Додати SceneQuestManager:**
   - Додати Node (назвати `SceneQuestManager`)
   - Призначити скрипт: `res://SampleProject/Scripts/Quest/SceneQuestManager.gd`
   - В Inspector призначити `quest_config`: `Canyon_Quest.tres`

3. **Опціонально додати QuestProgressUI:**
   - Додати Control (назвати `QuestProgressUI`)
   - Призначити скрипт: `res://SampleProject/Scripts/Quest/QuestProgressUI.gd`
   - Налаштувати UI структуру (VBoxContainer, Label, ProgressBar, тощо)

### 3. Використання в коді

Scene managers автоматично знаходять SceneQuestManager, якщо він є в сцені:

```gdscript
# В Canyon.gd або Village.gd
func can_transition_to_village() -> bool:
    return can_transition_to_scene("Village.tscn")

func get_available_scenes() -> Array[String]:
    return get_available_scenes_from_quest()
```

## Сигнали SceneQuestManager

- `stage_completed(stage_id, stage_name)` - етап завершено
- `all_stages_completed()` - всі етапи завершені
- `dialogue_completed(dialogue_id)` - діалог завершено
- `scene_unlocked(scene_name)` - сцена розблокована
- `progress_updated(completed, total)` - прогрес оновлено

## Переваги

1. **Візуальне налаштування** - все в Godot Editor через Resource файли
2. **Гнучкість** - легко додавати/змінювати етапи
3. **Автоматичне відстеження** - інтеграція з EventBus
4. **Опціональність** - працює з існуючими scene managers без змін
5. **Розширюваність** - легко додавати нові функції

## Наступні кроки

1. Створити конфігурації для всіх сцен в Godot Editor
2. Додати SceneQuestManager до сцен
3. Протестувати відстеження прогресу
4. Налаштувати UI для відображення прогресу (опціонально)
