extends Node2D

## 🏜️ Canyon Scene Manager
## States: INTRO, MONOLOGUE, EXPLORATION, CUTSCENE_ABDUCTION, TO_VILLAGE, RELIC_PICKUP, TO_DESERT_ROAD
## Follows Robust State-Flow Pattern (StepType + Guards + Addressable Dialogues)

enum State {
	INTRO,
	MONOLOGUE,
	EXPLORATION,
	CUTSCENE_ABDUCTION,
	TO_VILLAGE,
	RELIC_PICKUP,  # Возврат из деревни за реликвией
	EXIT_CUTSCENE,  # Катсцена спуска с каньона
	TO_DESERT_ROAD
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.INTRO:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
var _previous_state: State = State.INTRO  # Предыдущее состояние для события
signal state_complete(state: State)

func _ready() -> void:
	if Engine.has_singleton("ServiceLocator"):
		var loc = Engine.get_singleton("ServiceLocator")
		if not loc.is_node_ready():
			await loc.ready
	
	# Определяем начальное состояние на основе текущей сцены/room_id
	_determine_initial_state()
	
	_on_state_changed(current_state)

func _determine_initial_state() -> void:
	"""Определяет начальное состояние на основе room_id текущей сцены"""
	# Проверяем доступность MetSys
	if not Engine.has_singleton("MetSys"):
		DebugLogger.warning("🏜️ Canyon: MetSys singleton not found", "Canyon")
		return
	
	var metsys = Engine.get_singleton("MetSys")
	if not metsys or not metsys.current_room:
		DebugLogger.warning("🏜️ Canyon: MetSys.current_room not available", "Canyon")
		return
	
	var room_id = metsys.current_room.room_id
	DebugLogger.info("🏜️ Canyon: Current room_id: %s" % room_id, "Canyon")
	
	# Определяем состояние на основе room_id
	# Обладунки находятся в крайней сцене каньона (у выхода в пустыню)
	if "relic" in room_id.to_lower() or "relik" in room_id.to_lower() or "end" in room_id.to_lower() or "exit" in room_id.to_lower() or "final" in room_id.to_lower():
		# Если мы в крайней сцене каньона с реликвией (возврат из деревни)
		current_state = State.RELIC_PICKUP
		DebugLogger.info("🏜️ Canyon: Detected final/relic room, setting state to RELIC_PICKUP", "Canyon")
	elif "meditation" in room_id.to_lower() or "medit" in room_id.to_lower():
		# Если мы в сцене медитации
		current_state = State.EXPLORATION  # Игрок может исследовать, катсцена сработает при входе в зону
		DebugLogger.info("🏜️ Canyon: Detected meditation room, setting state to EXPLORATION", "Canyon")
	else:
		# Начальная сцена - начинаем с INTRO
		current_state = State.INTRO
		DebugLogger.info("🏜️ Canyon: Starting scene detected, setting state to INTRO", "Canyon")

func trigger_abduction_cutscene() -> void:
	"""Вызывается из Area2D триггера при входе в зону катсцены"""
	if current_state == State.EXPLORATION:
		current_state = State.CUTSCENE_ABDUCTION

func change_state_by_name(state_name: String) -> void:
	"""Изменяет состояние по имени (для StateChangeTrigger)"""
	var state_key = state_name.to_upper()
	
	# Пытаемся найти состояние в enum
	if State.keys().has(state_key):
		var new_state = State[state_key]
		current_state = new_state
		DebugLogger.info("🏜️ Canyon: State changed to %s via StateChangeTrigger" % state_key, "Canyon")
	else:
		DebugLogger.warning("🏜️ Canyon: Unknown state name: %s" % state_name, "Canyon")

func get_current_state_name() -> String:
	"""Возвращает имя текущего состояния (для проверки в триггерах)"""
	return State.keys()[current_state]

func trigger_exit_cutscene(target_room: String = "") -> void:
	"""Вызывается из CanyonExitTrigger при входе в зону выхода"""
	# Сохраняем target_room для перехода после катсцены
	if target_room.is_empty():
		target_room = "DesertRoad.tscn"
	
	# Устанавливаем target_room для перехода
	_exit_target_room = target_room
	
	# Переходим в состояние катсцены выхода
	if current_state == State.RELIC_PICKUP:
		current_state = State.EXIT_CUTSCENE
	else:
		# Если игрок дошел до выхода без реликвии, все равно показываем катсцену
		current_state = State.EXIT_CUTSCENE

var _exit_target_room: String = "DesertRoad.tscn"  # Комната для перехода после катсцены

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	
	# Эмитим событие смены состояния
	_emit_state_changed_event(_previous_state, new_state)
	
	# Сохраняем текущее состояние как предыдущее
	_previous_state = new_state
	
	DebugLogger.info("🏜️ Canyon: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _emit_state_changed_event(old_state: State, new_state: State) -> void:
	"""Эмитит событие смены состояния через GameFlow (State Manager)"""
	var old_state_name = State.keys()[old_state] if old_state >= 0 else "NONE"
	var new_state_name = State.keys()[new_state]
	
	# Пытаемся использовать GameFlow (State Manager) через ServiceLocator
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_game_flow"):
			var game_flow = service_locator.get_game_flow()
			if game_flow and game_flow.has_signal("scene_state_changed"):
				game_flow.scene_state_changed.emit("Canyon", old_state_name, new_state_name)
				DebugLogger.info("🏜️ Canyon: Event emitted via GameFlow - state changed from %s to %s" % [old_state_name, new_state_name], "Canyon")
				return
	
	# Fallback: используем EventBus, если GameFlow недоступен
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		if event_bus and event_bus.has_signal("scene_state_changed"):
			event_bus.scene_state_changed.emit("Canyon", old_state_name, new_state_name)
			DebugLogger.info("🏜️ Canyon: Event emitted via EventBus (fallback) - state changed from %s to %s" % [old_state_name, new_state_name], "Canyon")

func _apply_state_logic(state: State, run_id: int) -> void:
	match state:
		State.INTRO:
			# Начало - игрок появляется в каньоне
			_execute_step(StepType.DIALOGUE, "Canyon_Intro", run_id)
		State.MONOLOGUE:
			# Монолог персонажа в начальной сцене - о глупом деде и шамане
			_execute_step(StepType.DIALOGUE, "Canyon_StartMonologue", run_id)
		State.EXPLORATION:
			# Изучение окружения - персонаж осматривается, затем свободное исследование
			# Катсцена сработает при входе в зону через trigger_abduction_cutscene()
			_execute_step(StepType.DIALOGUE, "Canyon_Exploration", run_id)
			# После диалога игрок может свободно исследовать, катсцена сработает при входе в зону
		State.CUTSCENE_ABDUCTION:
			# Катсцена - показывают как уводят жителей, персонаж чувствует что-то не так
			_execute_step(StepType.DIALOGUE, "Canyon_AbductionCutscene", run_id)
		State.TO_VILLAGE:
			# Переход в деревню - персонаж бежит туда
			_execute_step(StepType.TRANSITION, "", run_id)
		State.RELIC_PICKUP:
			# Возврат из деревни - медитация возле священных обладунков
			_execute_step(StepType.DIALOGUE, "Canyon_MeditationAtRelic", run_id)
		State.EXIT_CUTSCENE:
			# Катсцена спуска с каньона - показываем как Кусакам спускается
			_execute_step(StepType.DIALOGUE, "Canyon_ExitCutscene", run_id)
		State.TO_DESERT_ROAD:
			# Переход в пустыню после катсцены спуска
			_execute_step(StepType.TRANSITION, "", run_id)

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
	
	# EXPLORATION не переходит автоматически - ждет триггера зоны
	if current_state != State.EXPLORATION:
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
				break
			if run_id != state_run_id: return

func advance_state() -> void:
	state_complete.emit(current_state)
	# EXIT_CUTSCENE переходит в TO_DESERT_ROAD, который затем вызывает переход
	if current_state == State.EXIT_CUTSCENE:
		current_state = State.TO_DESERT_ROAD
		# TO_DESERT_ROAD сразу вызывает переход
		_transition_to_next_scene()
	elif current_state < State.TO_DESERT_ROAD:
		current_state = (current_state + 1) as State
	else:
		_transition_to_next_scene()

func _transition_to_next_scene() -> void:
	if current_state == State.TO_VILLAGE:
		DebugLogger.info("🏜️ Canyon: Demo flow moving to Village...", "Scene")
		# Переход в деревню через MetSys
		_transition_to_room("Village.tscn")
	elif current_state == State.TO_DESERT_ROAD:
		DebugLogger.info("🏜️ Canyon: Demo flow moving to Desert Road...", "Scene")
		# Переход в пустыню через MetSys
		_transition_to_room(_exit_target_room)

func _transition_to_room(room_name: String) -> void:
	"""Переход в другую комнату через MetSys"""
	if room_name.is_empty():
		DebugLogger.warning("🏜️ Canyon: room_name is empty, cannot transition", "Canyon")
		return
	
	# Используем Game.get_singleton() для загрузки комнаты через MetSys
	var game = Game.get_singleton()
	if game and game.has_method("load_room"):
		DebugLogger.info("🏜️ Canyon: Loading room %s via Game.load_room()" % room_name, "Canyon")
		# load_room асинхронный, но мы не можем await здесь, так как это вызывается из _transition_to_next_scene
		# Метод сам обработает переход
		game.load_room(room_name)
	else:
		DebugLogger.warning("🏜️ Canyon: Game.get_singleton() failed or doesn't have load_room method", "Canyon")

func set_state_for_relic_pickup() -> void:
	"""Вызывается при возврате из деревни для подбора реликвии"""
	current_state = State.RELIC_PICKUP

func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator").get_dialogue_manager()
	return null
