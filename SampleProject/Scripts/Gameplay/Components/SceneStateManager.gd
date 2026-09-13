extends Node
class_name SceneStateManager

## 🎭 SceneStateManager - Компонент для управління стейтами сцен
## Використовується в сценах (.tscn) як компонент, а не в скриптах
## Дотримується принципу Component-Based Architecture

## Назва сцени (для ідентифікації в EventBus)
@export var scene_name: String = ""

## Поточний стейт (визначається через enum в дочірніх класах)
var current_state: Variant = null

## Попередній стейт (для подій)
var previous_state: Variant = null

## ID прогону стейту (для відміни старих асинхронних задач)
var state_run_id: int = 0

## Сигнали
signal state_changed(old_state: Variant, new_state: Variant)
signal state_complete(state: Variant)

## Словник маппінгу назв стейтів до значень enum
var state_name_to_value: Dictionary = {}

## Ініціалізація (викликається з дочірніх класів)
func _ready() -> void:
	_initialize_state_mapping()
	_determine_initial_state()
	
	# Підключаємося до EventBus для відстеження діалогів
	if Engine.has_singleton("EventBus"):
		EventBus.dialogue_finished.connect(_on_dialogue_finished)

## Ініціалізація маппінгу стейтів (перевизначається в дочірніх класах)
func _initialize_state_mapping() -> void:
	push_error("SceneStateManager: _initialize_state_mapping() має бути перевизначено в дочірньому класі!")
	pass

## Визначення початкового стейту (перевизначається в дочірніх класах)
func _determine_initial_state() -> void:
	push_error("SceneStateManager: _determine_initial_state() має бути перевизначено в дочірньому класі!")
	pass

## Змінює стейт за назвою (для тригерів)
func change_state_by_name(state_name: String) -> void:
	if not state_name_to_value.has(state_name):
		DebugLogger.warning("SceneStateManager: Стейт '%s' не знайдено в маппінгу!" % state_name, "SceneStateManager")
		return
	
	var new_state = state_name_to_value[state_name]
	_set_state(new_state)

## Отримує назву поточного стейту
func get_current_state_name() -> String:
	if current_state == null:
		return "UNKNOWN"
	
	# Шукаємо назву в маппінгу
	for state_name in state_name_to_value:
		if state_name_to_value[state_name] == current_state:
			return state_name
	
	return "UNKNOWN"

## Встановлює початковий стейт без еміту подій (для ініціалізації)
func _set_initial_state(new_state: Variant) -> void:
	"""Встановлює початковий стейт без еміту подій та запуску логіки"""
	previous_state = null
	current_state = new_state
	state_run_id = 0

## Встановлює новий стейт
func _set_state(new_state: Variant) -> void:
	# Сравниваем состояния - если они одинаковые, не меняем
	# Используем явное сравнение для надежности
	if current_state != null and new_state != null:
		# Если оба не null, сравниваем напрямую
		# Для enum значений сравнение должно работать правильно
		if current_state == new_state:
			# Состояния одинаковые, не меняем и не эмитируем сигнал
			return
	elif current_state == null and new_state == null:
		# Если оба null, тоже не меняем
		return
	
	# Состояния разные, меняем
	previous_state = current_state
	current_state = new_state
	
	# Інкрементуємо ID прогону
	state_run_id += 1
	var run_id = state_run_id
	
	# Емітуємо подію (синхронно, до await)
	state_changed.emit(previous_state, new_state)
	
	# Емітуємо подію через EventBus/GameFlow
	_emit_state_changed_event(previous_state, new_state)
	
	# Застосовуємо логіку стейту
	_apply_state_logic(new_state, run_id)

## Застосування логіки стейту (перевизначається в дочірніх класах)
func _apply_state_logic(state: Variant, run_id: int) -> void:
	push_error("SceneStateManager: _apply_state_logic() має бути перевизначено в дочірньому класі!")
	pass

## Емітує подію зміни стейту через GameFlow/EventBus
func _emit_state_changed_event(old_state: Variant, new_state: Variant) -> void:
	var old_state_name = _get_state_name(old_state)
	var new_state_name = _get_state_name(new_state)
	
	# Використовуємо GameFlow через ServiceLocator
	if ServiceLocator and ServiceLocator.has_method("get_game_flow"):
		var game_flow = ServiceLocator.get_game_flow()
		if game_flow and game_flow.has_signal("scene_state_changed"):
			game_flow.scene_state_changed.emit(scene_name, old_state_name, new_state_name)
			DebugLogger.info("SceneStateManager: Подія зміни стейту емітована через GameFlow: %s -> %s" % [old_state_name, new_state_name], "SceneStateManager")
			return
	
	# Fallback: EventBus
	if Engine.has_singleton("EventBus"):
		EventBus.scene_state_changed.emit(scene_name, old_state_name, new_state_name)
		DebugLogger.info("SceneStateManager: Подія зміни стейту емітована через EventBus: %s -> %s" % [old_state_name, new_state_name], "SceneStateManager")

## Отримує назву стейту (допоміжний метод)
func _get_state_name(state: Variant) -> String:
	if state == null:
		return "NONE"
	
	# Шукаємо назву в маппінгу
	for state_name in state_name_to_value:
		if state_name_to_value[state_name] == state:
			return state_name
	
	return "UNKNOWN"

## Обробник завершення діалогу
func _on_dialogue_finished(dialogue_id: String) -> void:
	# Перевизначається в дочірніх класах для обробки конкретних діалогів
	pass

## Перевіряє, чи стейт все ще актуальний
func is_state_current(run_id: int) -> bool:
	return run_id == state_run_id
