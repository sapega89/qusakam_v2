extends Control

## Головне меню + Splash. Figma: main-menu 9:26, UI/Splash Screen 258:5140.
## Splash: чорний фон, титул, "PRESS ANY BUTTON" між ромбовими розділювачами.
## Меню: New Game / Continue / Settings / Quit Game (D72 — окремої Load Game немає;
## Continue відкриває Save Slot Selection у режимі LOAD).

const LOAD_MENU_PATH := "res://SampleProject/Scenes/Menus/LoadGameMenu.tscn"

@onready var menu: VBoxContainer = $Center/Menu
@onready var press_any_button_container: VBoxContainer = $Center/PressAnyButtonContainer
@onready var press_any_button_label: Label = $Center/PressAnyButtonContainer/PressAnyButtonLabel
@onready var game_title: Control = %GameTitle
@onready var background: TextureRect = $Background
@onready var _center: VBoxContainer = %Center
@onready var _overlay: ColorRect = %MenuOverlay
@onready var _menu_divider: Control = %MenuDivider

var is_title_screen_mode: bool = true
var blink_tween: Tween
var options_component: Control = null

func _ready() -> void:
	var show_title_screen = get_tree().get_meta("show_title_screen", true)
	if get_tree().has_meta("show_title_screen"):
		get_tree().remove_meta("show_title_screen")
	is_title_screen_mode = show_title_screen
	_apply_tokens()
	_setup_menu_items()
	_check_save_file_exists()
	_apply_screen_mode(show_title_screen)
	set_process_input(true)
	_apply_localized_text()
	print("MainMenu: _ready menu=%s" % (menu != null))
	_debug_connect_menu_signals()
	call_deferred("_debug_dump_menu_state")
	if show_title_screen:
		start_blink_animation()
	else:
		_focus_first_item.call_deferred()

## Розміри й кольори — лише з UITokens (Figma 9:26 / 258:5140).
func _apply_tokens() -> void:
	%SplashBackground.color = UITokens.SPLASH_BG
	_overlay.color = UITokens.MAIN_MENU_OVERLAY
	game_title.custom_minimum_size.x = UITokens.TITLE_BLOCK_WIDTH
	$Center/GameTitle/TopRule.custom_minimum_size.x = UITokens.TITLE_RULE_OUTER
	$Center/GameTitle/MiddleRule.custom_minimum_size.x = UITokens.TITLE_RULE_MIDDLE
	$Center/GameTitle/BottomRule.custom_minimum_size.x = UITokens.TITLE_RULE_OUTER
	for divider in [$Center/PressAnyButtonContainer/DividerTop,
			$Center/PressAnyButtonContainer/DividerBottom, _menu_divider]:
		for line in [divider.get_node("Line1"), divider.get_node("Line2")]:
			line.custom_minimum_size.x = UITokens.DIVIDER_LINE
	var copyright: Label = %CopyrightLabel
	copyright.offset_top = -UITokens.SCREEN_PAD_BOTTOM - copyright.get_minimum_size().y
	copyright.offset_bottom = -UITokens.SCREEN_PAD_BOTTOM

## Пункти меню Figma UI/Menu Item: активний (фокус) — SemiBold + шеврон.
func _setup_menu_items() -> void:
	for item in menu.get_children():
		if item is Button:
			item.custom_minimum_size.x = UITokens.MENU_ITEM_WIDTH
			item.focus_entered.connect(_on_item_focus.bind(item, true))
			item.focus_exited.connect(_on_item_focus.bind(item, false))
			item.mouse_entered.connect(func(): if not item.disabled: item.grab_focus())

func _on_item_focus(item: Button, focused: bool) -> void:
	item.theme_type_variation = &"MainMenuItemOn" if focused else &"MainMenuItem"

func _focus_first_item() -> void:
	for item in menu.get_children():
		if item is Button and item.visible and not item.disabled:
			item.grab_focus()
			return

## Splash і меню — один екран: однаковий титул, різні фон/нижня частина.
func _apply_screen_mode(title_mode: bool) -> void:
	background.visible = not title_mode
	_overlay.visible = not title_mode
	press_any_button_container.visible = title_mode
	menu.visible = not title_mode
	_menu_divider.visible = not title_mode
	_center.theme_type_variation = &"SplashCenter" if title_mode else &"MainMenuCenter"

func start_blink_animation() -> void:
	if blink_tween:
		blink_tween.kill()
	blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(press_any_button_label, "modulate:a", 0.3, 1.0)
	blink_tween.tween_property(press_any_button_label, "modulate:a", 1.0, 1.0)

func transition_to_main_menu() -> void:
	if not is_title_screen_mode:
		return
	is_title_screen_mode = false
	if blink_tween:
		blink_tween.kill()
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(press_any_button_container, "modulate:a", 0.0, 0.3)
	await fade_out_tween.finished
	_apply_screen_mode(false)
	background.modulate.a = 0.0
	menu.modulate.a = 0.0
	_menu_divider.modulate.a = 0.0
	var fade_in_tween = create_tween()
	fade_in_tween.set_parallel(true)
	fade_in_tween.tween_property(background, "modulate:a", 1.0, 0.5)
	fade_in_tween.tween_property(menu, "modulate:a", 1.0, 0.5)
	fade_in_tween.tween_property(_menu_divider, "modulate:a", 1.0, 0.5)
	for i in range(menu.get_child_count()):
		var child = menu.get_child(i)
		if child:
			child.modulate.a = 0.0
			var delay = i * 0.08
			fade_in_tween.tween_property(child, "modulate:a", 1.0, 0.3).set_delay(delay)
	_focus_first_item()
	_log_input_state("after_transition")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_log_mouse_click(event)
	if is_title_screen_mode:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if event.pressed:
				_log_input_state("before_transition")
				transition_to_main_menu()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _log_mouse_click(event: InputEventMouseButton) -> void:
	var viewport = get_viewport()
	if viewport and viewport.has_method("gui_pick"):
		var picked = viewport.gui_pick(event.position)
		print("MainMenu: gui_pick node=%s" % (picked.name if picked else "null"))
	elif viewport and viewport.has_method("gui_get_focus_owner"):
		var focused = viewport.gui_get_focus_owner()
		print("MainMenu: gui_focus node=%s" % (focused.name if focused else "null"))
	print("MainMenu: mouse_button index=%s pressed=%s pos=%s" % [
		event.button_index,
		event.pressed,
		event.position
	])

func _debug_connect_menu_signals() -> void:
	if menu and not menu.gui_input.is_connected(_on_menu_gui_input):
		menu.mouse_filter = Control.MOUSE_FILTER_STOP
		menu.gui_input.connect(_on_menu_gui_input)
	for child in menu.get_children():
		if child is BaseButton:
			var button := child as BaseButton
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			if not button.pressed.is_connected(_on_menu_button_pressed.bind(button)):
				button.pressed.connect(_on_menu_button_pressed.bind(button))
			if not button.button_up.is_connected(_on_menu_button_up.bind(button)):
				button.button_up.connect(_on_menu_button_up.bind(button))
			if not button.mouse_entered.is_connected(_on_menu_button_hover.bind(button, true)):
				button.mouse_entered.connect(_on_menu_button_hover.bind(button, true))
			if not button.mouse_exited.is_connected(_on_menu_button_hover.bind(button, false)):
				button.mouse_exited.connect(_on_menu_button_hover.bind(button, false))
		elif child is Control:
			var control := child as Control
			if not control.gui_input.is_connected(_on_menu_child_gui_input.bind(control)):
				control.gui_input.connect(_on_menu_child_gui_input.bind(control))
	_debug_dump_menu_state()

func _on_menu_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		print("MainMenu: menu gui_input button=%s pressed=%s pos=%s" % [
			mb.button_index,
			mb.pressed,
			mb.position
		])

func _on_menu_child_gui_input(event: InputEvent, node: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		print("MainMenu: child gui_input name=%s button=%s pressed=%s pos=%s" % [
			node.name,
			mb.button_index,
			mb.pressed,
			mb.position
		])

func _on_menu_button_pressed(button: BaseButton) -> void:
	print("MainMenu: button pressed name=%s" % button.name)

func _on_menu_button_up(button: BaseButton) -> void:
	print("MainMenu: button_up name=%s" % button.name)

func _on_menu_button_hover(button: BaseButton, hovered: bool) -> void:
	print("MainMenu: button hover name=%s hovered=%s" % [button.name, hovered])

func _debug_dump_menu_state() -> void:
	if not menu:
		print("MainMenu: menu node missing")
		return
	print("MainMenu: menu state visible=%s mouse_filter=%s rect=%s" % [
		menu.visible,
		menu.mouse_filter,
		menu.get_global_rect()
	])
	for child in menu.get_children():
		if child is Control:
			var control := child as Control
			var disabled = control.disabled if control is BaseButton else "n/a"
			print("MainMenu: child name=%s type=%s visible=%s disabled=%s mouse_filter=%s rect=%s focus_mode=%s" % [
				control.name,
				control.get_class(),
				control.visible,
				disabled,
				control.mouse_filter,
				control.get_global_rect(),
				control.focus_mode
			])

func _log_input_state(context: String) -> void:
	var paused = get_tree().paused
	var root = get_tree().root
	var black_screen = root.get_node_or_null("BlackScreen") if root else null
	var black_rect = black_screen.get_node_or_null("ColorRect") if black_screen else null
	var transition_layer = root.get_node_or_null("TransitionCanvasLayer") if root else null
	var transition_rect = transition_layer.get_node_or_null("TransitionOverlay") if transition_layer else null
	var modal_layer = root.get_node_or_null("ModalLayer") if root else null
	var modal_blocker = modal_layer.get_node_or_null("Blocker") if modal_layer else null
	print("MainMenu: %s paused=%s title=%s menu=%s press_any=%s" % [
		context,
		paused,
		is_title_screen_mode,
		menu.visible,
		press_any_button_container.visible
	])
	if black_rect:
		print("MainMenu: BlackScreen visible=%s alpha=%.2f mouse_filter=%s" % [
			black_rect.visible,
			black_rect.modulate.a,
			black_rect.mouse_filter
		])
	if transition_rect:
		print("MainMenu: TransitionOverlay visible=%s alpha=%.2f mouse_filter=%s" % [
			transition_rect.visible,
			transition_rect.modulate.a,
			transition_rect.mouse_filter
		])
	if modal_blocker:
		print("MainMenu: ModalBlocker visible=%s mouse_filter=%s" % [
			modal_blocker.visible,
			modal_blocker.mouse_filter
		])

func new_game_button_up() -> void:
	# Set flag to indicate this is a new game (don't load save)
	# Save file will remain but won't be loaded until explicitly loaded
	get_tree().set_meta("start_new_game", true)
	print("🆕 MainMenu: Starting new game (save file will not be loaded)")
	get_tree().change_scene_to_file("res://SampleProject/Game.tscn")

## Continue → Save Slot Selection у режимі LOAD (D72, D75). Вибір слота — там.
func continue_pressed() -> void:
	print("MainMenu: Continue → save slot selection (LOAD)")
	get_tree().change_scene_to_file(LOAD_MENU_PATH)

## Continue вимкнений, поки немає жодного сейва.
func _check_save_file_exists() -> void:
	var has_any_save = false
	var save_system = ServiceLocatorHelper.get_manager("get_save_system")
	if save_system and save_system.has_method("has_save_file"):
		has_any_save = save_system.has_save_file()

	var continue_button = menu.get_node_or_null("continue")
	if continue_button:
		continue_button.disabled = not has_any_save
		continue_button.focus_mode = Control.FOCUS_ALL if has_any_save else Control.FOCUS_NONE

func _on_exit_pressed() -> void:
	get_tree().quit()

func _apply_localized_text() -> void:
	if press_any_button_label:
		press_any_button_label.text = tr("Press Any Button")
	var continue_button = menu.get_node_or_null("continue")
	if continue_button:
		continue_button.text = tr("Continue")
	var new_button = menu.get_node_or_null("new_game")
	if new_button:
		new_button.text = tr("New Game")
	var options_button = menu.get_node_or_null("options")
	if options_button:
		options_button.text = tr("Settings")
	var exit_button = menu.get_node_or_null("exit")
	if exit_button:
		exit_button.text = tr("Quit Game")


func options_button_up() -> void:
	print("Options: Opening options menu")
	show_options_menu()


func show_options_menu() -> void:
	"""Показывает меню опций с анимацией"""
	# Скрываем главное меню с анимацией
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(menu, "modulate:a", 0.0, 0.3)
	await fade_out_tween.finished
	menu.visible = false
	_menu_divider.visible = false

	# Загружаем сцену опций
	var options_scene = load("res://SampleProject/Scenes/Menus/Game/options_component.tscn")
	if not options_scene:
		push_error("❌ MainMenu: Failed to load options_component.tscn")
		# Возвращаемся к главному меню
		show_main_menu()
		return
	
	# Создаем экземпляр опций
	options_component = options_scene.instantiate()
	if not options_component:
		push_error("❌ MainMenu: Failed to instantiate options component")
		show_main_menu()
		return
	
	# Устанавливаем режим "main_menu" ДО добавления в сцену
	options_component.mode = "main_menu"
	
	# Добавляем в сцену
	add_child(options_component)
	
	# Ждем, пока компонент будет готов (чтобы @onready переменные инициализировались)
	await get_tree().process_frame
	
	# Теперь настраиваем режим (после инициализации @onready переменных)
	if options_component.has_method("_setup_mode"):
		options_component._setup_mode()
	
	# Анимация появления
	options_component.modulate.a = 0.0
	options_component.visible = true
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(options_component, "modulate:a", 1.0, 0.3)

func show_main_menu() -> void:
	"""Показывает главное меню (возврат из опций)"""
	# Удаляем меню опций
	if options_component and is_instance_valid(options_component):
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(options_component, "modulate:a", 0.0, 0.3)
		await fade_out_tween.finished
		options_component.queue_free()
		options_component = null
	
	# Показываем главное меню с анимацией
	menu.visible = true
	menu.modulate.a = 0.0
	var fade_in_tween = create_tween()
	fade_in_tween.set_parallel(true)
	fade_in_tween.tween_property(menu, "modulate:a", 1.0, 0.5)
	for i in range(menu.get_child_count()):
		var child = menu.get_child(i)
		if child:
			child.visible = true
			child.modulate.a = 0.0
			var delay = i * 0.08
			fade_in_tween.tween_property(child, "modulate:a", 1.0, 0.3).set_delay(delay)
	_menu_divider.visible = true
	_focus_first_item()
