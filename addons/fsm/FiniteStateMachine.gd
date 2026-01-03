@icon("res://addons/fsm/icon.png")

class_name FiniteStateMachine extends Node

var state: FSMState

func _ready():
	for i in get_children(): 
		i.actor = get_parent()
		i.set_physics_process(false)
	_change_state(get_child(0))

func _change_state(new_state: FSMState):
	if state is FSMState: # Will skip if current state is null.
		state.set_physics_process(false) 
		state._exit_state()
	if new_state is FSMState:
		state = new_state
		state.set_physics_process(true)
		state._enter_state()

func link(source_state,signal_name,linked_state):
	source_state.connect(signal_name,Callable(self, "_change_state").bind(linked_state))
