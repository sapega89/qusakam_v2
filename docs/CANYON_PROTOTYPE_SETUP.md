# 🏗️ Інструкція зі створення прототипу сцени Canyon

## Крок 1: Підготовка компонентів

### 1.1 Перевірка наявності скриптів

Переконайтеся, що всі скрипти створені:

- ✅ `SampleProject/Scripts/Core/Interfaces/ISceneStateManager.gd`
- ✅ `SampleProject/Scripts/Gameplay/Components/SceneStateManager.gd`
- ✅ `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`
- ✅ `SampleProject/Scripts/Gameplay/Scenes/CanyonStateManager.gd`

### 1.2 Створення .uid файлів (якщо потрібно)

Godot автоматично створює .uid файли, але якщо їх немає:

1. Відкрити кожен скрипт в Godot Editor
2. Зберегти файл (Ctrl+S)
3. Godot автоматично створить .uid файл

## Крок 2: Створення прототипу сцени

### 2.1 Відкриття сцени Canyon

1. Відкрити `SampleProject/Maps/Canyon.tscn` в Godot Editor
2. Або створити нову сцену `Canyon_Prototype.tscn` для тестування

### 2.2 Додавання CanyonStateManager

1. В корені сцени додати `Node` → назвати `CanyonStateManager`
2. В Inspector:
   - **Script**: `SampleProject/Scripts/Gameplay/Scenes/CanyonStateManager.gd`
   - **Scene Name**: "Canyon" (автоматично встановлюється)
3. Перевірити, що компонент правильно ініціалізується

### 2.3 Додавання DialogueStateTrigger для кожного діалогу

Для кожного діалогу, який має змінювати стейт:

#### Тригер для INTRO → MONOLOGUE

1. Додати `Area2D` → назвати `DialogueStateTrigger_Intro`
2. В Inspector:
   - **Script**: `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`
   - **Dialogue ID**: "Canyon_Intro"
   - **Target State**: "MONOLOGUE"
   - **Require State**: "INTRO"
   - **One Shot**: ✅ (включено)
   - **State Change Delay**: 0.0
3. Додати дочірній вузол `CollisionShape2D`
4. В Inspector CollisionShape2D:
   - **Shape**: `RectangleShape2D` (або інша форма)
   - Розмістити в потрібному місці сцени

#### Тригер для MONOLOGUE → EXPLORATION

1. Додати `Area2D` → назвати `DialogueStateTrigger_Monologue`
2. В Inspector:
   - **Script**: `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`
   - **Dialogue ID**: "Canyon_StartMonologue"
   - **Target State**: "EXPLORATION"
   - **Require State**: "MONOLOGUE"
   - **One Shot**: ✅
3. Додати `CollisionShape2D` з потрібною формою

#### Тригер для EXPLORATION (без зміни стейту)

1. Додати `Area2D` → назвати `DialogueStateTrigger_Exploration`
2. В Inspector:
   - **Script**: `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`
   - **Dialogue ID**: "Canyon_Exploration"
   - **Target State**: "" (порожня - не змінює стейт)
   - **Require State**: "EXPLORATION"
   - **One Shot**: ✅
3. Додати `CollisionShape2D`

#### Тригер для CUTSCENE_ABDUCTION → TO_VILLAGE

1. Додати `Area2D` → назвати `DialogueStateTrigger_Abduction`
2. В Inspector:
   - **Script**: `SampleProject/Scripts/Gameplay/Components/DialogueStateTrigger.gd`
   - **Dialogue ID**: "Canyon_AbductionCutscene"
   - **Target State**: "TO_VILLAGE"
   - **Require State**: "CUTSCENE_ABDUCTION"
   - **One Shot**: ✅
3. Додати `CollisionShape2D`

## Крок 3: Перевірка налаштувань

### 3.1 Перевірка CanyonStateManager

1. Відкрити сцену
2. Вибрати `CanyonStateManager`
3. Перевірити в Inspector:
   - ✅ Script присвоєно
   - ✅ Scene Name = "Canyon"
   - ✅ State Name To Value не порожній (після запуску)

### 3.2 Перевірка DialogueStateTrigger

Для кожного тригера:

1. Вибрати тригер
2. Перевірити в Inspector:
   - ✅ Script присвоєно
   - ✅ Dialogue ID вказано
   - ✅ Target State вказано (якщо потрібно)
   - ✅ CollisionShape2D додано

## Крок 4: Тестування

### 4.1 Запуск гри

1. Запустити гру (F5)
2. Перевірити в консолі:
   - ✅ CanyonStateManager ініціалізовано
   - ✅ Початковий стейт = INTRO

### 4.2 Тест зміни стейту через діалог

1. Зайти в зону `DialogueStateTrigger_Intro`
2. Перевірити:
   - ✅ Діалог запустився
   - ✅ Після завершення діалогу стейт змінився на MONOLOGUE
   - ✅ В консолі: "SceneStateManager: Подія зміни стейту емітована"

### 4.3 Тест require_state

1. Встановити стейт на EXPLORATION (через консоль або код)
2. Зайти в зону тригера з `require_state: "INTRO"`
3. Перевірити:
   - ✅ Тригер НЕ спрацював
   - ✅ В консолі: "Поточний стейт не відповідає вимогам"

### 4.4 Тест one_shot

1. Зайти в зону тригера (діалог запустився)
2. Завершити діалог
3. Зайти в зону тригера знову
4. Перевірити:
   - ✅ Тригер НЕ спрацював
   - ✅ В консолі: "Тригер вже спрацював (one_shot=true)"

## Крок 5: Налаштування воріт (опціонально)

Якщо в сцені є ворота (GateController):

1. Переконайтеся, що `CanyonStateManager` має доступ до GateController
2. Ворота автоматично оновлюються при зміні стейту через `_update_gates_for_state()`

## Можливі проблеми та рішення

### Проблема: CanyonStateManager не ініціалізується

**Рішення:**
- Перевірити, що скрипт правильно присвоєно
- Перевірити, що всі залежності (MetSys, Game, ServiceLocator) доступні
- Перевірити консоль на помилки

### Проблема: DialogueStateTrigger не спрацьовує

**Рішення:**
- Перевірити, що CollisionShape2D додано
- Перевірити, що гравець в групі "PLAYER"
- Перевірити require_state (якщо вказано)
- Перевірити, що DialogueManager доступний

### Проблема: Стейт не змінюється після діалогу

**Рішення:**
- Перевірити, що target_state вказано правильно
- Перевірити, що діалог правильно завершується
- Перевірити підключення сигналу dialogue_finished
- Перевірити консоль на помилки

## Наступні кроки

Після успішного тестування прототипу:

1. Застосувати той самий підхід до інших сцен (Village, Laboratory, тощо)
2. Створити узагальнений SceneStateManager для інших сцен
3. Додати більше тестів для покриття всіх сценаріїв
4. Документувати всі стейти та переходи
