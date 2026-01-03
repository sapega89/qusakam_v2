extends Node2D

## 🌳 Laboratory Outside Scene Manager
## States: EXIT_LAB, DEMO_CLOSING
## Follows Robust State-Flow Pattern

enum State {
	EXIT_LAB,
	DEMO_CLOSING
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.EXIT_LAB:
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
	DebugLogger.info("🌳 LabOutside: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
	match state:
		State.EXIT_LAB:
			_execute_step(StepType.DIALOGUE, "Laboratory_Outside", run_id)
		State.DEMO_CLOSING:
			_execute_step(StepType.DIALOGUE, "Demo_End", run_id)

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
				break
			if run_id != state_run_id: return

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.DEMO_CLOSING:
		current_state = (current_state + 1) as State
	else:
		_finish_demo()

func _finish_demo() -> void:
	DebugLogger.info("🌳 LabOutside: DEMO FINISHED.", "Scene")
	if Engine.has_singleton("ServiceLocator"):
		var flow = Engine.get_singleton("ServiceLocator").get_game_flow()
		if flow:
			flow.advance_story() # StoryState.DEMO_END

func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator").get_dialogue_manager()
	return null
