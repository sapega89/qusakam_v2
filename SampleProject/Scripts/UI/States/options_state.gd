extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name OptionsState

var settings_manager: Node = null
var opened: bool = false

func _enter_state() -> void:
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_settings_manager"):
			settings_manager = service_locator.get_settings_manager()

	if settings_manager and settings_manager.has_method("open_settings"):
		var root = _get_state_root()
		settings_manager.open_settings(root, true)
		opened = true

	get_tree().paused = true

func _exit_state() -> void:
	if settings_manager and settings_manager.has_method("close_settings"):
		settings_manager.close_settings()
	if get_tree().paused:
		get_tree().paused = false

func _physics_process(_delta: float) -> void:
	if opened and settings_manager and settings_manager.has_method("is_open"):
		if not settings_manager.is_open():
			finish()

func _get_state_root() -> Node:
	if ui_manager and ui_manager.has_method("get_state_root"):
		return ui_manager.get_state_root()
	return null
