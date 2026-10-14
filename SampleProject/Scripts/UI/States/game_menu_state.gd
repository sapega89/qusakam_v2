extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name GameMenuState

const GAME_MENU_SCENE = preload("res://SampleProject/Scenes/Menus/Game/game_menu.tscn")

var menu_instance: Control = null

func _enter_state() -> void:
	menu_instance = GAME_MENU_SCENE.instantiate()
	ui_manager.get_state_root().add_child(menu_instance)
	get_tree().paused = true

func _exit_state() -> void:
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
	menu_instance = null
	if get_tree().paused:
		get_tree().paused = false

func _physics_process(_delta: float) -> void:
	pass

