extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name GameMenuState

## B149: сцена меню вантажиться при відкритті, а не preload'ом. preload вантажить її під час компіляції цього
## скрипта, а компіляція тримає спільний замок кешу GDScript. Меню ділить base_menu.tscn, bottom_bar.tscn і
## party_status_panel.tscn з крамницею, яку RoomPreloader вантажить у фоні (SceneWarmer); головний потік чекав
## на воркер, що вантажив ту саму сцену, а воркер — на замок, щоб скомпілювати її скрипти.
const GAME_MENU_SCENE_PATH := "res://SampleProject/Scenes/Menus/Game/game_menu.tscn"
## Завантажена при першому відкритті й тримається до кінця гри.
static var _menu_scene: PackedScene = null

var menu_instance: Control = null

func _enter_state() -> void:
	if _menu_scene == null:
		_menu_scene = load(GAME_MENU_SCENE_PATH)
	menu_instance = _menu_scene.instantiate()
	ui_manager.get_state_root().add_child(menu_instance)
	get_tree().paused = true

func _exit_state() -> void:
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
	menu_instance = null
	if get_tree().paused:
		get_tree().paused = false
