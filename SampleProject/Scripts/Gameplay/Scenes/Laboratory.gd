extends Node2D

## 🧪 Laboratory Scene
## States: Explore, Companion_01, Companion_02, Companion_03, LimitTest, BossFight, AfterBoss
## Згідно з ЕТАПОМ 3: КРОК 2

enum State {
	EXPLORE,
	COMPANION_01,
	COMPANION_02,
	COMPANION_03,
	LIMIT_TEST,
	BOSS_FIGHT,
	AFTER_BOSS
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.EXPLORE:
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
	
	_on_state_changed(current_state)

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🧪 Laboratory: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
	match state:
		State.EXPLORE:
			_execute_step(StepType.LOOP, "", run_id)
		State.COMPANION_01:
			_execute_step(StepType.DIALOGUE, "Lab_Companion_01", run_id)
		State.COMPANION_02:
			_execute_step(StepType.DIALOGUE, "Lab_Companion_02", run_id)
		State.COMPANION_03:
			_execute_step(StepType.DIALOGUE, "Lab_Companion_03", run_id)
		State.LIMIT_TEST:
			_execute_step(StepType.DIALOGUE, "Lab_LimitTest", run_id)
		State.BOSS_FIGHT:
			_execute_step(StepType.COMBAT, "Laboratory_BossFight", run_id)
		State.AFTER_BOSS:
			_execute_step(StepType.DIALOGUE, "Laboratory_AfterBoss", run_id)

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	match type:
		StepType.DIALOGUE:
			await _play_dialogue(dialogue_id, run_id)
		StepType.COMBAT:
			# Fast Path: Імітуємо бій діалогом
			await _play_dialogue(dialogue_id, run_id)
		StepType.LOOP:
			# Fast Path: Чекаємо 1 сек
			await get_tree().create_timer(1.0).timeout
		StepType.TRANSITION:
			pass
	
	if run_id != state_run_id: return
	advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	var dm = _get_dialogue_manager()
	if not dm: 
		await get_tree().create_timer(0.5).timeout
		return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)
	
	if Engine.has_singleton("EventBus"):
		while true:
			var finished_id = await EventBus.dialogue_finished
			# Адресна перевірка: чекаємо саме наш діалог (або шлях до нього)
			if finished_id == path or finished_id == dialogue_id:
				break
			# Якщо стейт змінився поки ми чекали - виходимо
			if run_id != state_run_id: return

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.AFTER_BOSS:
		current_state = (current_state + 1) as State
	else:
		_transition_to_outside()

func _transition_to_outside() -> void:
	DebugLogger.info("🧪 Laboratory: All steps complete. Moving to Outside.", "Scene")
	# Logic for scene change

func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator").get_dialogue_manager()
	return null
