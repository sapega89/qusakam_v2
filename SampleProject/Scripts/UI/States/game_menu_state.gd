extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name GameMenuState

const GAME_MENU_SCENE = preload("res://SampleProject/Scenes/Menus/Game/game_menu.tscn")

var menu_instance: Control = null

func _enter_state() -> void:
	if GAME_MENU_SCENE:
		menu_instance = GAME_MENU_SCENE.instantiate()
		var root = _get_state_root()
		if root:
			root.add_child(menu_instance)
		else:
			add_child(menu_instance)
	get_tree().paused = true

func _exit_state() -> void:
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
	menu_instance = null
	if get_tree().paused:
		get_tree().paused = false

func _physics_process(_delta: float) -> void:
	pass

func _get_state_root() -> Node:
	if ui_manager and ui_manager.has_method("get_state_root"):
		return ui_manager.get_state_root()
	return null
