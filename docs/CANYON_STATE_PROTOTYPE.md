# 🏜️ Canyon State Prototype - Компонентна архітектура

## Огляд

Цей документ описує компонентну архітектуру для управління стейтами сцени Canyon з інтеграцією діалогів.

## Архітектура

### Компоненти

1. **ISceneStateManager** (Інтерфейс)
   - Уніфікований доступ до стейт-менеджерів
   - Методи: `is_implemented_by()`, `safe_get_current_state_name()`, `safe_change_state_by_name()`
   - Файл: `SampleProject/Scripts/Core/Interfaces/ISceneStateManager.gd`

2. **SceneStateManager** (Базовий компонент)
   - Базовий клас для управління стейтами
   - Використовується в сценах як компонент
   - Файл: `SampleProject/Scripts/Gameplay/Components/SceneStateManager.gd`

3. **CanyonStateManager** (Спеціалізований компонент)
   - Розширює SceneStateManager для сцени Canyon
   - Містить enum State та логіку стейтів
   - Файл: `SampleProject/Scripts/Gameplay/Scenes/CanyonStateManager.gd`

4. **DialogueStateTrigger** (Компонент тригера)
   - Спеціалізований тригер для інтеграції діалогів зі стейтами
   - Запускає діалог і автоматично змінює стейт після завершення
   - Файл: `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`

## Використання в сцені

### 1. Додавання CanyonStateManager до сцени

1. Відкрити `Canyon.tscn` в Godot Editor
2. Додати `Node` → назвати `CanyonStateManager`
3. Присвоїти скрипт: `SampleProject/Scripts/Gameplay/Scenes/CanyonStateManager.gd`
4. Налаштувати `scene_name` = "Canyon"

### 2. Додавання DialogueStateTrigger для діалогів

Для кожного діалогу, який має змінювати стейт:

1. Додати `Area2D` → назвати `DialogueStateTrigger_Intro` (або інша назва)
2. Присвоїти скрипт: `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`
3. Додати `CollisionShape2D` з потрібною формою
4. Налаштувати параметри:
   - **dialogue_id**: "Canyon_Intro"
   - **target_state**: "MONOLOGUE" (стейт після завершення діалогу)
   - **require_state**: "INTRO" (опціонально, якщо потрібен конкретний стейт)
   - **one_shot**: true (якщо спрацьовує один раз)

### 3. Приклад налаштування тригерів

#### Тригер для INTRO → MONOLOGUE
```
DialogueStateTrigger_Intro:
  - dialogue_id: "Canyon_Intro"
  - target_state: "MONOLOGUE"
  - require_state: "INTRO"
  - one_shot: true
```

#### Тригер для MONOLOGUE → EXPLORATION
```
DialogueStateTrigger_Monologue:
  - dialogue_id: "Canyon_StartMonologue"
  - target_state: "EXPLORATION"
  - require_state: "MONOLOGUE"
  - one_shot: true
```

#### Тригер для EXPLORATION (без зміни стейту)
```
DialogueStateTrigger_Exploration:
  - dialogue_id: "Canyon_Exploration"
  - target_state: ""  # Не змінює стейт, тільки запускає діалог
  - require_state: "EXPLORATION"
  - one_shot: true
```

## Переваги компонентної архітектури

1. **Розділення відповідальностей**: Логіка стейтів в компонентах, а не в скриптах
2. **Повторне використання**: DialogueStateTrigger можна використовувати в будь-якій сцені
3. **Легке тестування**: Компоненти можна тестувати окремо
4. **Візуальна настройка**: Всі параметри налаштовуються в редакторі
5. **Інтерфейси**: Уніфікований доступ через ISceneStateManager

## Тестування

### Тест 1: Перевірка зміни стейту через діалог

1. Запустити гру
2. Зайти в зону тригера `DialogueStateTrigger_Intro`
3. Перевірити, що:
   - Діалог запустився
   - Після завершення діалогу стейт змінився на MONOLOGUE
   - EventBus.scene_state_changed емітується з правильними параметрами

### Тест 2: Перевірка require_state

1. Встановити стейт на EXPLORATION
2. Зайти в зону тригера з `require_state: "INTRO"`
3. Перевірити, що тригер НЕ спрацював

### Тест 3: Перевірка one_shot

1. Зайти в зону тригера (діалог запустився)
2. Завершити діалог
3. Зайти в зону тригера знову
4. Перевірити, що тригер НЕ спрацював (one_shot=true)

## Міграція зі старої архітектури

### Старий підхід (Canyon.gd)
- Логіка стейтів в скрипті
- Діалоги запускаються через `_play_dialogue()`
- Зміна стейту через `current_state = State.NEW_STATE`

### Новий підхід (Компоненти)
- Логіка стейтів в `CanyonStateManager` (компонент в сцені)
- Діалоги запускаються через `DialogueStateTrigger` (компонент в сцені)
- Зміна стейту автоматично після завершення діалогу

## Наступні кроки

1. Створити прототип сцени Canyon з компонентами
2. Додати всі DialogueStateTrigger для кожного діалогу
3. Протестувати зміну стейтів через діалоги
4. Застосувати той самий підхід до інших сцен (Village, Laboratory, тощо)
