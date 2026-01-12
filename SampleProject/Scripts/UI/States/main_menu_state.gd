extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name MainMenuState

const MAIN_MENU_SCENE = preload("res://SampleProject/MainMenu.tscn")

var menu_instance: Control = null

func _enter_state() -> void:
	print("MainMenuState: _enter_state")
	if MAIN_MENU_SCENE:
		menu_instance = MAIN_MENU_SCENE.instantiate()
		var root = _get_state_root()
		if root:
			root.add_child(menu_instance)
		else:
			add_child(menu_instance)

func _exit_state() -> void:
	print("MainMenuState: _exit_state")
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
	menu_instance = null

func _physics_process(_delta: float) -> void:
	print("MainMenuState: _physics_process")

func _get_state_root() -> Node:
	if ui_manager and ui_manager.has_method("get_state_root"):
		return ui_manager.get_state_root()
	return null
