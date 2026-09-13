# 🏜️ План налаштування Canyon Scene

## 📋 Загальний план

### 1. Виправлення StateChangeTrigger ✅
- Виправлено логіку переключення стейтів
- Тепер тригер правильно знаходить enum State в сцені Canyon
- Додано підтримку різних методів зміни стейту

### 2. Система квестів ✅
- Додано сигнали `quest_flag_changed` та `quest_completed` в Game.gd
- Метод `set_quest_flag()` тепер емітить сигнали при зміні квестів
- Система інтегрована з SaveSystem

### 3. GateController ✅
- Створено скрипт `GateController.gd` для управління брамами
- Брами відкриваються/закриваються на основі виконання квестів
- Автоматична перевірка статусу квестів при завантаженні

### 4. Налаштування Canyon.tscn (ПОТРІБНО ЗРОБИТИ)

#### 4.1. Додати GateController до брам

Для кожної брами (Gate та Gate2) потрібно:

1. **Відкрити Canyon.tscn в Godot Editor**
2. **Знайти TileMap → Gate (або Gate2)**
3. **Додати до Gate Node2D з GateController скриптом:**

```gdscript
# Створіть Node2D як дочірній вузол Gate
# Назвіть його "GateController1" (для Gate) або "GateController2" (для Gate2)
# Призначте скрипт: res://SampleProject/Scripts/Gameplay/GateController.gd
```

4. **Налаштуйте параметри в Inspector:**
   - `gate_layer_name`: "Gate" (для першої брами) або "Gate2" (для другої)
   - `required_quest_id`: ID квеста, який потрібно виконати (наприклад, "canyon_quest_1")
   - `quest_completion_flag`: Флаг завершення (зазвичай залишити порожнім, буде використано `required_quest_id + "_completed"`)
   - `open_by_default`: false (брама закрита за замовчуванням)

#### 4.2. Налаштування тригерів

У Canyon.tscn вже є три тригери:
- `StateChangeTrigger1` (position: 1667, 381) - target_state: 2 (EXPLORATION)
- `StateChangeTrigger2` (position: 806, 392) - target_state: 3 (CUTSCENE_ABDUCTION)
- `StateChangeTrigger3` (position: 180, 392) - target_state: 4 (TO_VILLAGE)

**Перевірте налаштування:**

1. **StateChangeTrigger1:**
   - `target_state`: EXPLORATION (2)
   - `dialogue_id`: "Canyon_Exploration"
   - `action_mode`: BOTH (і стейт, і діалог)

2. **StateChangeTrigger2:**
   - `target_state`: CUTSCENE_ABDUCTION (3)
   - `dialogue_id`: "Canyon_AbductionCutscene"
   - `action_mode`: BOTH

3. **StateChangeTrigger3:**
   - `target_state`: TO_VILLAGE (4)
   - `dialogue_id`: "RoadToVillage"
   - `action_mode`: BOTH

### 5. Створення квестів

#### 5.1. Визначте квести для брам

Наприклад:
- **Quest 1**: "canyon_exploration_complete" - виконається після діалогу Canyon_Exploration
- **Quest 2**: "canyon_abduction_complete" - виконається після діалогу Canyon_AbductionCutscene

#### 5.2. Додайте завершення квестів у скрипт Canyon.gd

У методі `_execute_step()` після завершення діалогу:

```gdscript
func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	match type:
		StepType.DIALOGUE:
			await _play_dialogue(dialogue_id, run_id)
			# Додайте завершення квеста після діалогу
			if dialogue_id == "Canyon_Exploration":
				_complete_quest("canyon_exploration_complete")
			elif dialogue_id == "Canyon_AbductionCutscene":
				_complete_quest("canyon_abduction_complete")
		# ... інші типи
```

Додайте метод у Canyon.gd:

```gdscript
func _complete_quest(quest_id: String) -> void:
	"""Завершує квест і встановлює флаг"""
	if Engine.has_singleton("Game"):
		var game = Engine.get_singleton("Game")
		if game and game.has_method("set_quest_flag"):
			game.set_quest_flag(quest_id + "_completed", true)
			DebugLogger.info("🏜️ Canyon: Квест %s завершено" % quest_id, "Canyon")
```

### 6. Прив'язка брам до квестів

У GateController для кожної брами встановіть:

**GateController1 (для Gate):**
- `required_quest_id`: "canyon_exploration_complete"
- Брама відкриється після завершення діалогу Canyon_Exploration

**GateController2 (для Gate2):**
- `required_quest_id`: "canyon_abduction_complete"
- Брама відкриється після завершення діалогу Canyon_AbductionCutscene

## 🔧 Технічні деталі

### StateChangeTrigger
- Використовує enum `CanyonState` для вибору цільового стейту
- Автоматично конвертує enum в ім'я стейту для виклику `change_state_by_name()`
- Підтримує перевірку поточного стейту перед спрацюванням

### GateController
- Автоматично знаходить TileMapLayer з брамою
- Підписується на сигнали квестів через Game singleton
- Оновлює видимість брами при зміні статусу квеста
- Перевіряє статус квестів при завантаженні сцени

### Система квестів
- Квести зберігаються в `Game.quest_flags`
- Флаги автоматично зберігаються через SaveSystem
- Сигнали `quest_completed` та `quest_flag_changed` емітуються при зміні

## 📝 Приклад використання

### Завершення квеста з діалогу:

```gdscript
# У Canyon.gd після завершення діалогу
func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	# ... код запуску діалогу ...
	await dialogue_finished
	
	# Завершуємо квест
	if dialogue_id == "Canyon_Exploration":
		_complete_quest("canyon_exploration_complete")
```

### Перевірка статусу квеста:

```gdscript
# У будь-якому скрипті
if Engine.has_singleton("Game"):
	var game = Engine.get_singleton("Game")
	var completed = game.get_quest_flag("canyon_exploration_complete_completed", false)
	if completed:
		print("Квест виконано!")
```

## ✅ Чеклист налаштування

- [x] ✅ Виправлено require_state в тригерах (було встановлено на той самий стейт)
- [x] ✅ Створено DialogueSystem.tscn
- [x] ✅ Додано DialogueSystem до Canyon.tscn
- [x] ✅ Додано логи до тригерів та стейтів
- [x] ✅ Додано метод `_complete_quest()` в Canyon.gd
- [x] ✅ Додано виклики `_complete_quest()` після відповідних діалогів
- [ ] Додати GateController до Gate в Canyon.tscn (в Godot Editor)
- [ ] Додати GateController до Gate2 в Canyon.tscn (в Godot Editor)
- [ ] Налаштувати параметри GateController для кожної брами
- [ ] Протестувати відкриття брам після виконання квестів
- [ ] Перевірити збереження/завантаження статусу квестів

## 🔧 Виправлення проблем

### Проблема 1: Тригери не спрацьовують ✅ ВИПРАВЛЕНО
**Причина:** `require_state` було встановлено на той самий стейт, що і `target_state`

**Виправлення:**
- `StateChangeTrigger1`: `require_state = 0` (NONE) - спрацює в будь-якому стейті, переключить на EXPLORATION
- `StateChangeTrigger2`: `require_state = 2` (EXPLORATION) - спрацює тільки в EXPLORATION, переключить на CUTSCENE_ABDUCTION
- `StateChangeTrigger3`: `require_state = 3` (CUTSCENE_ABDUCTION) - спрацює тільки в CUTSCENE_ABDUCTION, переключить на TO_VILLAGE

### Проблема 2: Діалоги не запускаються ✅ ВИПРАВЛЕНО
**Причина:** Відсутній DialogueSystem в сцені Canyon.tscn

**Виправлення:**
- Створено `DialogueSystem.tscn` з компонентами:
  - DialoguePlayer
  - DialogueBox
  - ChoiceMenu
- Додано DialogueSystem до Canyon.tscn

### Проблема 3: Немає логів ✅ ВИПРАВЛЕНО
**Виправлення:**
- Додано детальні логи до StateChangeTrigger
- Додано логи до кожного стейту в Canyon.gd
- Додано логи до кожної дії (діалоги, переходи)
- Додано перевірку DialogueSystem при завантаженні сцени

## 🐛 Відомі проблеми та рішення

### Проблема: Тригер не переключає стейт
**Рішення:** Перевірте, що сцена має метод `change_state_by_name()` або властивість `current_state` з setter

### Проблема: Брама не відкривається
**Рішення:** 
1. Перевірте, що `required_quest_id` встановлено правильно
2. Перевірте, що квест завершується через `Game.set_quest_flag()`
3. Перевірте, що `gate_layer_name` відповідає імені TileMapLayer

### Проблема: Квест не зберігається
**Рішення:** Перевірте, що SaveSystem правильно зберігає `quest_flags` з Game.gd
