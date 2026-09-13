# 🎮 Найкращі практики переходів між сценами з MetSys

## ⚠️ ВАЖЛИВО: MetSys вже обробляє переходи автоматично!

**MetSys автоматично обробляє переходи між кімнатами через room connections.**

Коли гравець доходить до межі кімнати (border), MetSys:
1. Виявляє room connection до наступної кімнати
2. Автоматично завантажує наступну кімнату через `load_room()`
3. Позиціонує гравця в правильній позиції
4. Емітує сигнал `room_loaded`

**НЕ потрібно викликати `Game.load_room()` вручну в Scene Managers!**

Ручні переходи були додані раніше і конфліктували з автоматичними переходами MetSys, викликаючи:
- Подвійну телепортацію
- Неправильне позиціонування гравця
- Конфлікти між системами

## 📋 Принципи архітектури переходів

### 1. **Розділення відповідальності (Separation of Concerns)**

```
┌─────────────────────────────────────────────────────────┐
│ MetSys (Room Management)                                │
│ - Керує завантаженням кімнат                            │
│ - Обробляє автоматичні переходи через room connections │
│ - Зберігає позицію гравця між кімнатами                │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ Scene Managers (Canyon.gd, DesertRoad.gd, etc.)         │
│ - Керують станом сцени (State Machine)                  │
│ - Обробляють діалоги та квести                         │
│ - Встановлюють об'єктиви                                │
│ - НЕ викликають ручні переходи (крім спеціальних випадків)│
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ Game.gd (Coordinator)                                   │
│ - Координує завантаження кімнат через MetSys            │
│ - Обробляє init_room() для позиціонування гравця       │
│ - Зберігає стан гри                                      │
└─────────────────────────────────────────────────────────┘
```

## 🎯 Типи переходів та коли їх використовувати

### ✅ **Автоматичні переходи через MetSys Room Connections** (Рекомендовано)

**Коли використовувати:**
- Звичайні переходи між суміжними кімнатами
- Переходи, які гравець активує сам (йде до межі кімнати)
- Переходи, які мають бути доступні після виконання квесту

**Як налаштувати:**
1. В MetSys Editor налаштуйте room connections між кімнатами
2. Встановіть правильні координати переходів (borders)
3. Scene Manager НЕ викликає `Game.load_room()` - MetSys обробляє автоматично

**Приклад:**
```gdscript
# Canyon.gd - НЕ викликаємо ручний перехід
func _on_to_village_state(run_id: int) -> void:
    # Встановлюємо об'єктив
    _set_objective("Йти до села")
    # MetSys автоматично обробить перехід, коли гравець дійде до межі кімнати
    # НЕ викликаємо: game.load_room("Village.tscn")
```

### ⚠️ **Ручні переходи через Game.load_room()** (Тільки для спеціальних випадків)

**Коли використовувати:**
- Катсцени з телепортацією
- Спеціальні переходи (портал, ліфт)
- Переходи, які не можуть бути оброблені через room connections

**Приклад:**
```gdscript
# Тільки для спеціальних випадків
func _trigger_special_teleport() -> void:
    var game = Game.get_singleton()
    if game:
        game.load_room("SpecialRoom.tscn")
```

## 🏗️ Архітектура Scene Manager

### **State Machine Pattern** (Вже реалізовано)

Кожна сцена має State Machine, яка керує прогресом:

```gdscript
enum State {
    INTRO,
    EXPLORATION,
    TRANSITION_READY,
    COMPLETED
}

@export var current_state: State = State.INTRO:
    set(val):
        current_state = val
        _on_state_changed(val)
```

### **Quest Flags для збереження прогресу**

```gdscript
# Встановлюємо флаг після завершення діалогу
func _complete_quest_for_dialogue(dialogue_id: String) -> void:
    var game = Game.get_singleton()
    if not game: return
    
    match dialogue_id:
        "Canyon_Intro":
            game.set_quest_flag("canyon_intro_complete", true)
        # ... інші діалоги
```

### **Перевірка прогресу при завантаженні сцени**

```gdscript
func _determine_initial_state() -> void:
    var game = Game.get_singleton()
    if not game: return
    
    # Перевіряємо quest flags для визначення початкового стану
    if game.get_quest_flag("canyon_exploration_complete", false):
        current_state = State.EXPLORATION
    elif game.get_quest_flag("canyon_intro_complete", false):
        current_state = State.MONOLOGUE
    else:
        current_state = State.INTRO
```

## 🔄 Рекомендована логіка переходів

### **1. Canyon → Village**

```gdscript
# Canyon.gd
func _on_to_village_state(run_id: int) -> void:
    # Запускаємо діалог (якщо потрібно)
    await _play_dialogue("RoadToVillage", run_id)
    
    # Встановлюємо об'єктив
    _set_objective("Йти до села")
    
    # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
    # Гравець йде до межі кімнати, MetSys виявляє room connection і завантажує Village
```

**Налаштування MetSys:**
- Налаштуйте room connection: Canyon → Village
- Встановіть правильні координати переходу (border)
- Перехід активується, коли гравець доходить до межі

### **2. Canyon → DesertRoad**

```gdscript
# Canyon.gd
func _on_to_desert_road_state(run_id: int) -> void:
    # Запускаємо катсцену спуску
    await _play_dialogue("Canyon_ExitCutscene", run_id)
    
    # Встановлюємо об'єктив
    _set_objective("Спуститися до дороги")
    
    # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
    # Гравець йде до межі кімнати, MetSys виявляє room connection і завантажує DesertRoad
```

**Налаштування MetSys:**
- Налаштуйте room connection: Canyon → DesertRoad
- Встановіть правильні координати переходу (border)
- Перехід активується після катсцени, коли гравець доходить до межі

### **3. DesertRoad → CityGates**

```gdscript
# DesertRoad.gd
func _apply_state_logic(state: State, run_id: int) -> void:
    match state:
        State.TRANSITION_TO_CITY:
            _set_objective("Дійти до воріт міста")
            # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
            # Гравець йде до межі кімнати, MetSys виявляє room connection
```

**Налаштування MetSys:**
- Налаштуйте room connection: DesertRoad → CityGates
- Встановіть правильні координати переходу (border)

## 🚫 Що НЕ робити

### ❌ **НЕ викликайте Game.load_room() в Scene Managers**

```gdscript
# ❌ Погано
func advance_state() -> void:
    if current_state == State.TRANSITION_TO_CITY:
        Game.get_singleton().load_room("CityGates.tscn")  # НЕ РОБІТЬ ЦЕ

# ✅ Добре
func advance_state() -> void:
    if current_state == State.TRANSITION_TO_CITY:
        _set_objective("Дійти до воріт міста")
        # MetSys обробить перехід автоматично через room connections
```

### ❌ **НЕ створюйте подвійні переходи**

```gdscript
# ❌ Погано - і ручний перехід, і MetSys room connection
func _on_transition_state() -> void:
    Game.get_singleton().load_room("NextRoom.tscn")  # Ручний перехід
    # Але також налаштовано MetSys room connection - конфлікт!

# ✅ Добре - тільки MetSys room connection
func _on_transition_state() -> void:
    _set_objective("Йти до наступної кімнати")
    # Тільки MetSys обробляє перехід
```

## 📐 Рекомендована структура Scene Manager

```gdscript
extends Node2D

## Scene Manager Template
## States: INTRO, PROGRESS, TRANSITION_READY, COMPLETED

enum State {
    INTRO,
    PROGRESS,
    TRANSITION_READY,
    COMPLETED
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.INTRO:
    set(val):
        current_state = val
        _on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

func _ready() -> void:
    if Engine.has_singleton("ServiceLocator"):
        var loc = Engine.get_singleton("ServiceLocator")
        if not loc.is_node_ready():
            await loc.ready
    
    _determine_initial_state()
    _on_state_changed(current_state)

func _determine_initial_state() -> void:
    """Визначає початковий стан на основі quest flags"""
    var game = Game.get_singleton()
    if not game:
        current_state = State.INTRO
        return
    
    # Перевіряємо прогрес через quest flags
    if game.get_quest_flag("scene_completed", false):
        current_state = State.COMPLETED
    elif game.get_quest_flag("scene_progress_complete", false):
        current_state = State.TRANSITION_READY
    elif game.get_quest_flag("scene_intro_complete", false):
        current_state = State.PROGRESS
    else:
        current_state = State.INTRO

func _on_state_changed(new_state: State) -> void:
    state_run_id += 1
    var run_id = state_run_id
    DebugLogger.info("Scene: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
    _apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
    var game = Game.get_singleton()
    match state:
        State.INTRO:
            if game and game.get_quest_flag("scene_intro_complete", false):
                # Діалог вже прочитаний, пропускаємо
                return
            _set_objective("Початок сцени")
            _execute_step(StepType.DIALOGUE, "Scene_Intro", run_id)
        
        State.PROGRESS:
            if game and game.get_quest_flag("scene_progress_complete", false):
                # Прогрес вже завершено, пропускаємо
                return
            _set_objective("Продовжити прогрес")
            _execute_step(StepType.DIALOGUE, "Scene_Progress", run_id)
        
        State.TRANSITION_READY:
            _set_objective("Йти до наступної кімнати")
            # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
            DebugLogger.info("Scene: Стейт TRANSITION_READY - перехід обробляється через MetSys", "Scene")
        
        State.COMPLETED:
            _set_objective("Сцена завершена")
            # Сцена завершена, гравець може вільно переміщатися

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
    match type:
        StepType.DIALOGUE:
            await _play_dialogue(dialogue_id, run_id)
        StepType.COMBAT:
            await _play_dialogue(dialogue_id, run_id)
        StepType.LOOP:
            await get_tree().create_timer(1.0).timeout
        StepType.TRANSITION:
            await get_tree().create_timer(0.5).timeout
    
    if run_id != state_run_id: return
    advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
    var dm = _get_dialogue_manager()
    if not dm: return

    var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
    dm.start_dialogue(path)
    
    if Engine.has_singleton("EventBus"):
        while true:
            var finished_id = await EventBus.dialogue_finished
            if finished_id == path or finished_id == dialogue_id:
                _complete_quest_for_dialogue(dialogue_id)
                break
            if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
    """Встановлює квестові флаги для діалогів"""
    var game = Game.get_singleton()
    if not game: return
    
    match dialogue_id:
        "Scene_Intro":
            game.set_quest_flag("scene_intro_complete", true)
        "Scene_Progress":
            game.set_quest_flag("scene_progress_complete", true)

func advance_state() -> void:
    state_complete.emit(current_state)
    if current_state < State.COMPLETED:
        current_state = (current_state + 1) as State
    else:
        # Сцена завершена
        DebugLogger.info("Scene: Сцена завершена", "Scene")

func _set_objective(text: String) -> void:
    """Встановлює об'єктив для гравця"""
    var game = Game.get_singleton()
    if game and game.has_method("set_objective"):
        game.set_objective(text)

func _get_dialogue_manager() -> Node:
    if Engine.has_singleton("ServiceLocator"):
        return Engine.get_singleton("ServiceLocator").get_dialogue_manager()
    return null
```

## 🎯 Чеклист для кожної сцени

### ✅ **Обов'язкові елементи:**

1. **State Machine з enum State**
   - Визначає прогрес сцени
   - Керується через quest flags

2. **Quest Flags для збереження прогресу**
   - Кожен діалог має відповідний quest flag
   - Перевірка прогресу при завантаженні сцени

3. **Перевірка вже прочитаних діалогів**
   - Не запускати діалоги повторно
   - Пропускати автоматичні переходи, якщо прогрес вже завершено

4. **Об'єктиви для гравця**
   - Встановлювати об'єктив на кожному етапі
   - Оновлювати об'єктив при зміні стану

5. **НЕ викликати Game.load_room()**
   - Використовувати тільки MetSys room connections
   - Ручні переходи тільки для спеціальних випадків

## 🔧 Налаштування MetSys Room Connections

### **Крок 1: Відкрийте MetSys Editor**

1. Відкрийте проект в Godot
2. Перейдіть до MetSys Editor (якщо доступний)
3. Або налаштуйте room connections через MapData

### **Крок 2: Налаштуйте Room Connections**

Для кожного переходу між кімнатами:

```
Canyon → Village:
  - Room ID: Canyon → Village
  - Border coordinates: (x, y) - координати переходу
  - Direction: Right/Left/Up/Down - напрямок переходу

Canyon → DesertRoad:
  - Room ID: Canyon → DesertRoad
  - Border coordinates: (x, y) - координати переходу
  - Direction: Down - напрямок переходу (спуск)
```

### **Крок 3: Перевірте координати переходів**

- Переконайтеся, що координати переходів відповідають фізичним межам кімнат
- Гравець має змогу дійти до межі кімнати
- MetSys автоматично виявить перехід і завантажить наступну кімнату

## 📊 Порівняння підходів

| Підхід | Переваги | Недоліки | Коли використовувати |
|--------|----------|----------|---------------------|
| **MetSys Room Connections** | ✅ Автоматичні переходи<br>✅ Збереження позиції<br>✅ Плавні переходи | ⚠️ Потрібно налаштувати в MetSys Editor | Звичайні переходи між кімнатами |
| **Game.load_room()** | ✅ Контроль над переходом<br>✅ Можна додати катсцену | ❌ Може викликати проблеми з позиціонуванням<br>❌ Потрібно вручну керувати | Спеціальні переходи (телепорт, катсцена) |

## 🎮 Приклад повної реалізації

### **Canyon.gd - Рекомендована структура**

```gdscript
extends Node2D

## 🏜️ Canyon Scene Manager
## States: INTRO, MONOLOGUE, EXPLORATION, CUTSCENE_ABDUCTION, TO_VILLAGE, RELIC_PICKUP, TO_DESERT_ROAD

enum State {
    INTRO,
    MONOLOGUE,
    EXPLORATION,
    CUTSCENE_ABDUCTION,
    TO_VILLAGE,
    RELIC_PICKUP,
    EXIT_CUTSCENE,
    TO_DESERT_ROAD
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.INTRO:
    set(val):
        current_state = val
        _on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

func _ready() -> void:
    # Ініціалізація
    _determine_initial_state()
    if state_run_id == 0:
        _on_state_changed(current_state)

func _determine_initial_state() -> void:
    """Визначає початковий стан на основі quest flags"""
    var game = Game.get_singleton()
    if not game:
        current_state = State.INTRO
        return
    
    # Перевіряємо прогрес через quest flags
    if game.get_quest_flag("village_left_complete", false):
        current_state = State.RELIC_PICKUP
    elif game.get_quest_flag("canyon_abduction_complete", false):
        if not game.get_quest_flag("village_abduction_complete", false):
            current_state = State.TO_VILLAGE
        else:
            current_state = State.RELIC_PICKUP
    elif game.get_quest_flag("canyon_exploration_complete", false):
        current_state = State.CUTSCENE_ABDUCTION
    elif game.get_quest_flag("canyon_intro_complete", false):
        current_state = State.EXPLORATION
    else:
        current_state = State.INTRO

func _on_state_changed(new_state: State) -> void:
    state_run_id += 1
    var run_id = state_run_id
    DebugLogger.info("🏜️ Canyon: >>> STATE CHANGED TO: %s (RunID: %d)" % [State.keys()[new_state], run_id], "Canyon")
    _apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
    var game = Game.get_singleton()
    match state:
        State.INTRO:
            if game and game.get_quest_flag("canyon_intro_complete", false):
                return  # Діалог вже прочитаний
            _set_objective("Explore the Canyon")
            _execute_step(StepType.DIALOGUE, "Canyon_Intro", run_id)
        
        State.TO_VILLAGE:
            if game and game.get_quest_flag("village_abduction_complete", false):
                _set_objective("Повернутися до села")
                return  # Діалог вже прочитаний
            _set_objective("Йти до села")
            _execute_step(StepType.DIALOGUE, "RoadToVillage", run_id)
            # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
        
        State.TO_DESERT_ROAD:
            if game and game.get_quest_flag("canyon_exit_cutscene_complete", false):
                _set_objective("Спуститися до дороги")
                return  # Діалог вже прочитаний
            _set_objective("Спуститися до дороги")
            _execute_step(StepType.DIALOGUE, "Canyon_ExitCutscene", run_id)
            # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
        
        # ... інші стани

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
    match type:
        StepType.DIALOGUE:
            if _is_dialogue_completed(dialogue_id):
                return  # Діалог вже прочитаний
            await _play_dialogue(dialogue_id, run_id)
            _complete_quest_for_dialogue(dialogue_id)
        # ... інші типи
    
    if run_id != state_run_id: return
    advance_state()

func advance_state() -> void:
    state_complete.emit(current_state)
    if current_state == State.EXIT_CUTSCENE:
        current_state = State.TO_DESERT_ROAD
    elif current_state < State.TO_DESERT_ROAD:
        current_state = (current_state + 1) as State
    # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично
```

## 🎯 Висновки

1. **Використовуйте MetSys room connections для всіх звичайних переходів**
2. **Scene Managers керують тільки станом сцени, не переходами**
3. **Quest Flags зберігають прогрес між сесіями**
4. **Ручні переходи тільки для спеціальних випадків (телепорт, катсцена)**
5. **Об'єктиви допомагають гравцю розуміти, куди йти**

Ця архітектура забезпечує:
- ✅ Чітке розділення відповідальності
- ✅ Легке додавання нових сцен
- ✅ Збереження прогресу між сесіями
- ✅ Плавні переходи між кімнатами
- ✅ Відсутність конфліктів між системами
