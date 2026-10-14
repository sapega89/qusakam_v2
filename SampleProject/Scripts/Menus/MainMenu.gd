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
	# Сюди приходять і з паузи (Misc → Exit to Main Menu, Game Over, налаштування).
	# Пауза дерева пережила б зміну сцени, і меню не реагувало б ні на що.
	get_tree().paused = false
	var show_title_screen = get_tree().get_meta("show_title_screen", true)
	if get_tree().has_meta("show_title_screen"):
		get_tree().remove_meta("show_title_screen")
	is_title_screen_mode = show_title_screen
	_apply_tokens()
	_setup_menu_items()
	_check_save_file_exists()
	_apply_screen_mode(show_title_screen)
	set_process_input(true)
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
	_fade_in_menu([background, menu, _menu_divider])

func _input(event: InputEvent) -> void:
	if is_title_screen_mode:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if event.pressed:
				transition_to_main_menu()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func new_game_button_up() -> void:
	# Set flag to indicate this is a new game (don't load save)
	# Save file will remain but won't be loaded until explicitly loaded
	get_tree().set_meta("start_new_game", true)
	get_tree().change_scene_to_file("res://SampleProject/Game.tscn")

## Continue → Save Slot Selection у режимі LOAD (D72, D75). Вибір слота — там.
func continue_pressed() -> void:
	get_tree().change_scene_to_file(LOAD_MENU_PATH)

## Continue вимкнений, поки немає жодного сейва.
func _check_save_file_exists() -> void:
	# Напряму з autoload: при старті гри MainMenu._ready() іде раніше, ніж
	# CoreServiceRegistry знайде SaveSystem, і ServiceLocator повертав null.
	var has_any_save: bool = SaveSystem.has_save_file()

	var continue_button: Button = menu.get_node("continue")
	continue_button.disabled = not has_any_save
	continue_button.focus_mode = Control.FOCUS_ALL if has_any_save else Control.FOCUS_NONE

func _on_exit_pressed() -> void:
	get_tree().quit()

func options_button_up() -> void:
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
	_menu_divider.visible = true
	_fade_in_menu([menu, _menu_divider])


## Поява меню: блоки за 0.5 с, пункти по черзі з кроком 0.08 с.
func _fade_in_menu(blocks: Array) -> void:
	var tween := create_tween().set_parallel(true)
	for block in blocks:
		block.modulate.a = 0.0
		tween.tween_property(block, "modulate:a", 1.0, 0.5)
	for i in menu.get_child_count():
		var item: Control = menu.get_child(i)
		item.modulate.a = 0.0
		tween.tween_property(item, "modulate:a", 1.0, 0.3).set_delay(i * 0.08)
	_focus_first_item()
