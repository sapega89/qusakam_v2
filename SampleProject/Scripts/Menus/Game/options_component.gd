extends BaseOptionsComponent
class_name OptionsComponent

## Компонент опций - универсальный, работает в обоих режимах
## Наследуется от BaseOptionsComponent для общей логики
## Использует режим для адаптации поведения

# Mode: "main_menu" or "game_menu"
var mode: String = "game_menu"

@onready var exit_to_main_menu_button: Button = $ScrollContainer/VBoxContainer/ExitToMainMenuContainer/ExitToMainMenuButton
@onready var back_button: Button = $BackButton

func _setup_mode():
	"""Configure component based on usage mode"""
	if mode == "main_menu":
		# Show back button, hide exit to main menu button
		if back_button:
			back_button.visible = true
			# Отключаем фокус на кнопке back, чтобы Enter не активировал ее
			back_button.focus_mode = Control.FOCUS_NONE
			if not back_button.pressed.is_connected(_on_back_button_pressed):
				back_button.pressed.connect(_on_back_button_pressed)
		if exit_to_main_menu_button:
			exit_to_main_menu_button.visible = false
			if exit_to_main_menu_button.get_parent():
				exit_to_main_menu_button.get_parent().visible = false
	else:
		# Hide back button, show exit to main menu button
		if back_button:
			back_button.visible = false
			# Отключаем фокус на кнопке back, даже если она скрыта
			back_button.focus_mode = Control.FOCUS_NONE
		if exit_to_main_menu_button:
			exit_to_main_menu_button.visible = true
			if exit_to_main_menu_button.get_parent():
				exit_to_main_menu_button.get_parent().visible = true
			# Отключаем фокус на кнопке exit to main menu
			exit_to_main_menu_button.focus_mode = Control.FOCUS_NONE
			if not exit_to_main_menu_button.pressed.is_connected(_on_exit_to_main_menu_pressed):
				exit_to_main_menu_button.pressed.connect(_on_exit_to_main_menu_pressed)

func _unhandled_input(event):
	"""Handle Escape key to close menu (only in main menu mode)"""
	if mode == "main_menu" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_options_menu()

func _on_back_button_pressed() -> void:
	"""Handle back button press (main menu mode)"""
	close_options_menu()

func _on_exit_to_main_menu_pressed() -> void:
	"""Handle exit to main menu button (game menu mode)"""
	close_options_menu()

func close_options_menu():
	"""Close options menu - behavior depends on mode"""
	if mode == "main_menu":
		_close_main_menu_mode()
	else:
		_close_game_menu_mode()

func _close_main_menu_mode():
	"""Close options menu (main menu mode)"""
	# Save settings when closing options menu
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator and service_locator.has_method("get_save_system"):
		var save_system = service_locator.get_save_system()
		if save_system and save_system.has_method("save_game_settings"):
			save_system.save_game_settings()
			print("💾 OptionsComponent: Settings auto-saved on menu close")
	
	# Get main menu and call its function (animation will be inside)
	var main_menu = get_parent()
	if main_menu and main_menu.has_method("show_main_menu"):
		# Animation will be handled in show_main_menu()
		main_menu.show_main_menu()
	else:
		# Fallback: simple close animation if no parent
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(self, "modulate:a", 0.0, 0.2)
		await fade_out_tween.finished
		visible = false
		modulate.a = 1.0
	
	# Resume game (if it was paused)
	if get_tree().paused:
		get_tree().paused = false

func _close_game_menu_mode():
	"""Close options menu (game menu mode)"""
	# Use game_manager from BaseMenuComponent (inherited through BaseOptionsComponent)
	if not game_manager:
		game_manager = ServiceLocatorHelper.get_service_locator().get_game_manager()
	if game_manager:
		# Save settings first
		var service_locator = ServiceLocatorHelper.get_service_locator()
		if service_locator and service_locator.has_method("get_save_system"):
			var save_system = service_locator.get_save_system()
			if save_system and save_system.has_method("save_game_settings"):
				save_system.save_game_settings()
		
		# Close game menu properly
		if game_manager.game_menu_instance != null:
			# Close menu through GameManager
			game_manager.toggle_game_menu()
		else:
			# Fallback: try to close through game_menu node
			var game_menu = get_node_or_null("/root/GameMenu")
			if game_menu and game_menu.has_method("close_game_menu"):
				game_menu.close_game_menu()
		
		# Ensure game is not paused
		get_tree().paused = false
		
		# Transition to main menu
		get_tree().change_scene_to_file("res://SampleProject/Scenes/Menus/Main/main_menu.tscn")
	else:
		# Fallback
		get_tree().paused = false
		get_tree().change_scene_to_file("res://SampleProject/Scenes/Menus/Main/main_menu.tscn")
