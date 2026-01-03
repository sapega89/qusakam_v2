extends Control

@onready var menu: VBoxContainer = $Menu
@onready var press_any_button_container: HBoxContainer = $PressAnyButtonContainer
@onready var press_any_button_label: Label = $PressAnyButtonContainer/PressAnyButtonLabel
@onready var game_title: Control = $GameTitle
@onready var background: TextureRect = $Background

var is_title_screen_mode: bool = true
var blink_tween: Tween
var options_component: Control = null

func _ready() -> void:
	_load_game_cover()
	menu.visible = false
	game_title.visible = true
	press_any_button_container.visible = true
	set_process_input(true)
	_check_save_file_exists()
	start_blink_animation()

func _load_game_cover() -> void:
	"""Загружает обкладинку игры, если файл существует"""
	const COVER_PATH = "res://SampleProject/Resources/Art/game_cover.png"
	const COVER_PATH_JPG = "res://SampleProject/Resources/Art/game_cover.jpg"
	if not background:
		print("⚠️ MainMenu: background node not found, skipping cover load")
		return
	
	# Пробуем загрузить PNG
	if ResourceLoader.exists(COVER_PATH):
		var texture = load(COVER_PATH)
		if texture:
			background.texture = texture
			print("✅ MainMenu: Game cover loaded from ", COVER_PATH)
			return
	
	# Пробуем загрузить JPG
	if ResourceLoader.exists(COVER_PATH_JPG):
		var texture = load(COVER_PATH_JPG)
		if texture:
			background.texture = texture
			print("✅ MainMenu: Game cover loaded from ", COVER_PATH_JPG)
			return
	
	# Если обкладинка не найдена, используем чёрный фон
	print("ℹ️ MainMenu: Game cover not found, using black background")
	# Создаём чёрный ColorRect как fallback
	var color_rect = ColorRect.new()
	color_rect.name = "FallbackBackground"
	color_rect.color = Color(0, 0, 0, 1)
	color_rect.anchors_preset = Control.PRESET_FULL_RECT
	add_child(color_rect)
	move_child(color_rect, 0)  # Перемещаем в начало

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
	press_any_button_container.visible = false
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
	print("🆕 MainMenu: Starting new game (save file will not be loaded)")
	get_tree().change_scene_to_file("res://SampleProject/Game.tscn")

func load_game_button_up() -> void:
	# Открываем сцену выбора сохранения
	print("📂 MainMenu: Opening load game menu")
	get_tree().change_scene_to_file("res://SampleProject/Scenes/Menus/LoadGameMenu.tscn")

func _check_save_file_exists() -> void:
	# Проверяем наличие сохранения MetSys
	const METSYS_SAVE_PATH = "user://example_save_data.sav"
	var has_metsys_save = FileAccess.file_exists(METSYS_SAVE_PATH)
	
	# Проверяем наличие сохранения SaveSystem
	var has_savesystem_save = false
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			var save_system = service_locator.get_save_system()
			if save_system and save_system.has_method("has_save_file"):
				has_savesystem_save = save_system.has_save_file()
			else:
				# Если save_system null или не имеет метода, просто продолжаем
				pass
	
	var has_any_save = has_metsys_save or has_savesystem_save
	
	# Включаем/выключаем кнопку Continue в зависимости от наличия сохранения
	var continue_button = menu.get_node_or_null("continue")
	if continue_button:
		continue_button.disabled = not has_any_save
		if has_any_save:
			print("✅ MainMenu: Save file found, Continue button enabled")
		else:
			print("ℹ️ MainMenu: No save file found, Continue button disabled")
	
	# Кнопка Load Game всегда активна (позволяет выбрать сохранение даже если его нет)
	var load_game_button = menu.get_node_or_null("load_game")
	if load_game_button:
		load_game_button.disabled = false
		print("✅ MainMenu: Load Game button enabled")

func _on_exit_pressed() -> void:
	get_tree().quit()

func options_button_up() -> void:
	"""Открывает меню опций"""
	print("⚙️ MainMenu: Opening options menu")
	show_options_menu()

func show_options_menu() -> void:
	"""Показывает меню опций с анимацией"""
	# Скрываем главное меню с анимацией
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(menu, "modulate:a", 0.0, 0.3)
	await fade_out_tween.finished
	menu.visible = false
	
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
