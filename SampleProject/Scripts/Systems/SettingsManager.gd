extends Node
class_name SettingsManager

## ⚙️ SettingsManager - Обгортка для аддону basic_settings_menu
## Інтегрує SettingsUI з аддону в систему менеджерів

# Путь к сцене настроек (можно заменить на свою реализацию)
const SettingsScene: String = "res://addons/basic_settings_menu/settings.tscn"
const SettingsVerticalScene: String = "res://SampleProject/Scenes/Menus/settings_vertical_menu.tscn"

var settings_instance: Control = null
var is_settings_open: bool = false
var is_opening: bool = false  # Флаг для предотвращения одновременных вызовов

func _ready():
	"""Ініціалізація SettingsManager"""
	print("⚙️ SettingsManager: Initialized")
	# Включаємо обробку необробленого вводу для Escape
	set_process_unhandled_input(true)

func open_settings(parent: Node = null, as_popup: bool = false):
	"""Відкриває меню налаштувань з аддону
	
	Args:
		parent: Батьківський вузол для додавання меню (за замовчуванням - root)
		as_popup: Відкрити як popup (для ігрового меню)
	"""
	# Защита от одновременных вызовов
	if is_opening:
		push_warning("⚠️ SettingsManager: open_settings() already in progress, ignoring duplicate call")
		return
	
	is_opening = true
	
	# Перевіряємо, чи меню вже відкрите
	if is_settings_open and settings_instance:
		# Перевіряємо, чи вузол дійсно в дереві
		if is_instance_valid(settings_instance) and settings_instance.get_parent():
			print("⚙️ SettingsManager: Settings already open")
			is_opening = false
			return
		else:
			# Якщо вузол не в дереві, очищаємо посилання
			settings_instance = null
			is_settings_open = false
	
	# Закрываем предыдущий экземпляр, если он существует
	if settings_instance and is_instance_valid(settings_instance):
		var old_parent = settings_instance.get_parent()
		if old_parent:
			old_parent.remove_child(settings_instance)
		settings_instance.queue_free()
		settings_instance = null
		is_settings_open = false
	
	# Используем вертикальное меню, если оно существует, иначе используем старое
	var scene_to_load = SettingsVerticalScene
	if not ResourceLoader.exists(SettingsVerticalScene):
		scene_to_load = SettingsScene
		if not ResourceLoader.exists(SettingsScene):
			push_error("❌ SettingsManager: Settings scene not found. Create your own settings UI or install basic_settings_menu addon.")
			is_opening = false
			return
	
	var settings_scene = load(scene_to_load)
	if not settings_scene:
		push_error("❌ SettingsManager: Failed to load settings scene")
		is_opening = false
		return
	
	settings_instance = settings_scene.instantiate()
	if not settings_instance:
		push_error("❌ SettingsManager: Failed to instantiate settings scene")
		is_opening = false
		return
	
	# ВАЖНО: Убеждаемся, что новый экземпляр не имеет родителя перед добавлением
	if settings_instance.get_parent():
		var existing_parent = settings_instance.get_parent()
		existing_parent.remove_child(settings_instance)
		push_warning("⚠️ SettingsManager: New instance had a parent, removed it")
	
	# Встановлюємо батьківський вузол
	var target_parent = parent if parent else get_tree().root
	
	# Проверяем, что target_parent существует и валиден
	if not target_parent or not is_instance_valid(target_parent):
		push_error("❌ SettingsManager: Invalid target parent")
		settings_instance.queue_free()
		settings_instance = null
		is_opening = false
		return
	
	# Финальная проверка: убеждаемся, что settings_instance не имеет родителя
	if settings_instance.get_parent():
		var final_parent = settings_instance.get_parent()
		push_warning("⚠️ SettingsManager: Instance still has parent, removing: ", final_parent.name)
		final_parent.remove_child(settings_instance)
		await get_tree().process_frame
	
	# Проверяем, что settings_instance еще не является дочерним узлом target_parent
	if settings_instance.get_parent() == target_parent:
		push_warning("⚠️ SettingsManager: Instance already child of target parent")
		is_opening = false
		return
	
	# Добавляем в дерево
	target_parent.add_child(settings_instance)
	
	# Убеждаемся, что узел правильно добавлен
	if not settings_instance.get_parent():
		push_error("❌ SettingsManager: Failed to add instance to parent")
		settings_instance.queue_free()
		settings_instance = null
		is_settings_open = false
		is_opening = false
		return
	
	# Встановлюємо process_mode для всіх елементів, щоб меню працювало навіть під час паузи
	_set_process_mode_recursive(settings_instance, Node.PROCESS_MODE_ALWAYS)
	
	# Якщо це popup, встановлюємо відповідний прапорець
	if settings_instance.has_method("set_is_popup"):
		settings_instance.set_is_popup(as_popup)
	else:
		var props = settings_instance.get_property_list()
		var has_is_pop_up = false
		for prop in props:
			if prop.get("name") == "is_pop_up":
				has_is_pop_up = true
				break
		
		if has_is_pop_up:
			settings_instance.is_pop_up = as_popup
	
	is_settings_open = true
	print("⚙️ SettingsManager: Settings opened")
	
	# Чекаємо, поки сцена буде повністю готова
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Підписуємося на закриття меню
	if settings_instance.has_signal("ready"):
		if not settings_instance.ready.is_connected(_on_settings_ready):
			settings_instance.ready.connect(_on_settings_ready)
	
	# Якщо це popup, перевизначаємо обробник кнопки Back
	if as_popup:
		get_tree().paused = true
		call_deferred("_setup_popup_back_button")
		call_deferred("_setup_escape_handler")
	
	call_deferred("_verify_ui_elements")
	
	# Снимаем флаг открытия
	is_opening = false

func close_settings():
	"""Закриває меню налаштувань"""
	if not is_settings_open or not settings_instance:
		return
	
	# Зберігаємо налаштування перед закриттям
	var settings_data = _get_settings_data()
	if settings_data:
		if settings_data.has_method("save_settings"):
			settings_data.save_settings()
	
	# Знімаємо паузу, якщо була встановлена
	if get_tree().paused:
		get_tree().paused = false
	
	# Видаляємо меню
	if is_instance_valid(settings_instance):
		var instance_class = settings_instance.get_class()
		
		if instance_class == "Window":
			if settings_instance.has_method("hide"):
				settings_instance.hide()
			settings_instance.queue_free()
		elif instance_class == "AcceptDialog" or instance_class == "ConfirmationDialog":
			if settings_instance.has_method("hide"):
				settings_instance.hide()
			settings_instance.queue_free()
		else:
			var parent_node = settings_instance.get_parent()
			if parent_node:
				if settings_instance.get_parent() == parent_node:
					parent_node.remove_child(settings_instance)
			
			settings_instance.queue_free()
	
	settings_instance = null
	is_settings_open = false
	
	print("⚙️ SettingsManager: Settings closed")

func _get_settings_data():
	"""Безпечно отримує SettingsData singleton"""
	if Engine.has_singleton("SettingsData"):
		return Engine.get_singleton("SettingsData")
	if is_inside_tree():
		var tree = get_tree()
		if tree and tree.root:
			return tree.root.get_node_or_null("SettingsData")
	return null

func _on_settings_ready():
	"""Обробник готовності меню налаштувань"""
	print("⚙️ SettingsManager: Settings menu ready")

func _setup_popup_back_button():
	"""Налаштовує кнопку Back для popup режиму"""
	if not settings_instance or not is_instance_valid(settings_instance):
		return
	
	var back_button = settings_instance.get_node_or_null("MarginContainer/VBoxContainer/BottomContainer/BackButton")
	if not back_button:
		back_button = _find_node_by_name(settings_instance, "BackButton")
	
	if back_button:
		var is_popup = false
		var props = settings_instance.get_property_list()
		for prop in props:
			if prop.get("name") == "is_pop_up":
				is_popup = settings_instance.is_pop_up
				break
		
		if not is_popup:
			var value = settings_instance.get("is_pop_up")
			if value != null:
				is_popup = value
		
		if is_popup:
			if not back_button.pressed.is_connected(_on_back_button_pressed):
				back_button.pressed.connect(_on_back_button_pressed)
			print("⚙️ SettingsManager: Back button connected for popup mode")

func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode):
	"""Рекурсивно встановлює process_mode для всіх дочірніх елементів"""
	node.process_mode = mode
	
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)

func _find_node_by_name(node: Node, node_name: String) -> Node:
	"""Рекурсивно знаходить вузол за ім'ям"""
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	
	return null

func _on_back_button_pressed():
	"""Обробник натискання кнопки Back в popup режимі"""
	close_settings()

func _setup_escape_handler():
	"""Налаштовує обробку ESC для закриття меню"""
	if not settings_instance or not is_instance_valid(settings_instance):
		return
	
	if not settings_instance.has_method("_unhandled_input"):
		settings_instance.set_meta("_escape_handler_setup", true)

func _unhandled_input(event):
	"""Обробляє ESC для закриття меню налаштувань"""
	if not is_settings_open or not settings_instance:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_settings()
		get_viewport().set_input_as_handled()

func _verify_ui_elements():
	"""Перевіряє, чи всі UI елементи правильно налаштовані"""
	if not settings_instance or not is_instance_valid(settings_instance):
		return
	
	var tab_container = settings_instance.get_node_or_null("MarginContainer/VBoxContainer/TabContainer")
	if tab_container:
		print("⚙️ SettingsManager: TabContainer found")
		if tab_container.get_tab_count() > 0:
			print("⚙️ SettingsManager: Found ", tab_container.get_tab_count(), " tabs")
	
	var back_button = _find_node_by_name(settings_instance, "BackButton")
	if back_button:
		print("⚙️ SettingsManager: BackButton found")

func is_open() -> bool:
	"""Перевіряє, чи відкрите меню налаштувань"""
	return is_settings_open and is_instance_valid(settings_instance)

func get_language() -> String:
	"""Получает текущий язык"""
	var save_system = null
	if Engine.has_singleton("ServiceLocator"):
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_save_system"):
				save_system = service_locator.get_save_system()
	if save_system and save_system.has("game_settings"):
		return save_system.game_settings.get("language", "en")
	return "en"

func set_language(language: String):
	"""Устанавливает язык"""
	var save_system = null
	if Engine.has_singleton("ServiceLocator"):
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_save_system"):
				save_system = service_locator.get_save_system()
	if save_system and save_system.has("game_settings"):
		save_system.game_settings["language"] = language
		if save_system.has_method("save_game_settings"):
			save_system.save_game_settings()

