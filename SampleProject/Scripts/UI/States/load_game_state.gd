extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name LoadGameState

const LOAD_MENU_SCENE = preload("res://SampleProject/Scenes/Menus/LoadGameMenu.tscn")

var menu_instance: Control = null

func _enter_state() -> void:
	if LOAD_MENU_SCENE:
		menu_instance = LOAD_MENU_SCENE.instantiate()
		if menu_instance and menu_instance.has_method("set_use_state_navigation"):
			menu_instance.set_use_state_navigation(true)
		if menu_instance and menu_instance.has_method("set_mode"):
			menu_instance.set_mode("load")
		if menu_instance and menu_instance.has_signal("menu_closed"):
			menu_instance.menu_closed.connect(_on_menu_closed)
		var root = _get_state_root()
		if root:
			root.add_child(menu_instance)
		else:
			add_child(menu_instance)

func _exit_state() -> void:
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
	menu_instance = null

func _physics_process(_delta: float) -> void:
	pass

func _on_menu_closed(action: String = "") -> void:
	if action == "load":
		return_state = ""
	finish({"action": action})

func _get_state_root() -> Node:
	if ui_manager and ui_manager.has_method("get_state_root"):
		return ui_manager.get_state_root()
	return null
