extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name SaveGameState

const LOAD_MENU_SCENE = preload("res://SampleProject/Scenes/Menus/LoadGameMenu.tscn")

var menu_instance: Control = null

func _enter_state() -> void:
	menu_instance = LOAD_MENU_SCENE.instantiate()
	menu_instance.set_use_state_navigation(true)
	menu_instance.set_mode("save")
	menu_instance.menu_closed.connect(_on_menu_closed)
	ui_manager.get_state_root().add_child(menu_instance)

func _exit_state() -> void:
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
	menu_instance = null

func _physics_process(_delta: float) -> void:
	pass

func _on_menu_closed(action: String = "") -> void:
	finish({"action": action})

