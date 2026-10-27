extends Node

## Машина станів UI (S4, замість addons/fsm): тримає один активний UIState.
## Перший нащадок (NullState у ui_root.tscn) — стан на старті; UIManager додає нові стани й перемикає їх.

var state: UIState = null

func _ready() -> void:
	change_state(get_child(0))

func change_state(new_state: UIState) -> void:
	if state:
		state._exit_state()
	state = new_state
	state._enter_state()
