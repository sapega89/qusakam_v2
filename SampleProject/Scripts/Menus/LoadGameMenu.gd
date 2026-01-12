extends Control

signal menu_closed(action: String)

# Сцена выбора сохранения для загрузки игры

@onready var save_slots_container: VBoxContainer = $MainPanel/VBoxContainer/SaveSlotsContainer
@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var load_button: Button = $MainPanel/VBoxContainer/ButtonsContainer/LoadButton
@onready var back_button: Button = $MainPanel/VBoxContainer/ButtonsContainer/BackButton
@onready var delete_button: Button = $MainPanel/VBoxContainer/ButtonsContainer/DeleteButton

var selected_slot: int = -1
var save_slots: Array[Dictionary] = []
var mode: String = "load"
var use_state_navigation: bool = false
var _pending_save_slot: int = -1
var _pending_save_file_path: String = ""
var _pending_delete_slot: int = -1
var _pending_delete_file_path: String = ""

func set_use_state_navigation(value: bool) -> void:
	use_state_navigation = value


const SAVE_SLOTS_COUNT = 4
const DEFAULT_SLOT_PATH_TEMPLATE = "user://saves/slot_%02d.sav"
const MODAL_TEMPLATES = preload("res://SampleProject/Scripts/UI/modal_templates.gd")

func set_mode(new_mode: String) -> void:
	mode = new_mode
	if is_inside_tree():
		_update_mode_label()

func _update_mode_label() -> void:
	if load_button:
		load_button.text = tr("Save") if mode == "save" else tr("Load")
	if title_label:
		title_label.text = tr("Save Game") if mode == "save" else tr("Load Game")
	if delete_button:
		delete_button.text = tr("Delete")


func _ready() -> void:
	# Подключаем кнопки
	back_button.pressed.connect(_on_back_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_button_pressed)
	_update_mode_label()
	_connect_ui_refresh()
	
	# Загружаем данные SaveSystem для получения информации о локациях
	_load_savesystem_data()
	
	# Загружаем информацию о сохранениях
	_load_save_slots_info()
	_update_slots_display()

func _load_savesystem_data() -> void:
	"""Загружает данные SaveSystem для получения информации о сохранениях"""
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			var save_system = service_locator.get_save_system()
			if save_system and save_system.has_method("load_player_data"):
				# Загружаем данные, чтобы получить информацию о локациях
				save_system.load_player_data()

func _load_save_slots_info() -> void:
	"""Loads save slot info for UI display."""
	save_slots.clear()

	for i in range(1, SAVE_SLOTS_COUNT + 1):
		var slot_data = _get_save_slot_info(i)
		save_slots.append(slot_data)

func _get_save_slot_info(slot_number: int) -> Dictionary:
	"""Returns save slot metadata."""
	var slot_data = {
		"slot_number": slot_number,
		"exists": false,
		"location": "",
		"time": "",
		"playtime_sec": 0.0,
		"collectibles": 0,
		"file_path": ""
	}

	var save_system = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			save_system = service_locator.get_save_system()

	var slot_path = DEFAULT_SLOT_PATH_TEMPLATE % slot_number
	if save_system and save_system.has_method("get_slot_path"):
		slot_path = save_system.get_slot_path(slot_number)

	if FileAccess.file_exists(slot_path):
		slot_data["exists"] = true
		slot_data["file_path"] = slot_path
		var save_manager = SaveManager.new()
		save_manager.data = {}
		save_manager.load_from_text(slot_path)
		slot_data["collectibles"] = save_manager.get_value("collectible_count", 0)
		var current_room = save_manager.get_value("current_room", "")
		if current_room:
			slot_data["location"] = current_room

	if save_system and save_system.has_method("get_slot_metadata"):
		var meta = save_system.get_slot_metadata(slot_number)
		if meta.has("location"):
			slot_data["location"] = meta["location"]
		if meta.has("timestamp"):
			slot_data["time"] = meta["timestamp"]
		if meta.has("playtime_sec"):
			slot_data["playtime_sec"] = float(meta["playtime_sec"])

	return slot_data

func _update_slots_display() -> void:
	"""Обновляет отображение слотов сохранений"""
	for i in range(save_slots_container.get_child_count()):
		var slot_button = save_slots_container.get_child(i) as Button
		if slot_button:
			var slot_data: Dictionary = {}
			if i < save_slots.size():
				slot_data = save_slots[i]
			if slot_data.has("exists") and slot_data["exists"]:
				# Формируем текст для слота с сохранением
				var slot_text = "Slot %d: " % (i + 1)
				# Используем сохраненное название локации
				var location_name = slot_data["location"]
				if location_name.is_empty():
					# Только если название не найдено, используем fallback
					location_name = "Unknown Location"
				slot_text += location_name
				
				# Добавляем информацию о предметах
				if slot_data["collectibles"] > 0:
					slot_text += " (%d/6 предметов)" % slot_data["collectibles"]
				
				# Добавляем время сохранения
				if not slot_data["time"].is_empty():
					slot_text += "\n%s" % slot_data["time"]
				if slot_data.has("playtime_sec") and float(slot_data["playtime_sec"]) > 0.0:
					slot_text += "\nPlaytime: %s" % _format_playtime_seconds(slot_data["playtime_sec"])
				
				slot_button.text = slot_text
				slot_button.disabled = false
			else:
				# Пустой слот
				slot_button.text = "Slot %d: Empty" % (i + 1)
				slot_button.disabled = false
			
			# Подключаем сигнал нажатия
			if not slot_button.pressed.is_connected(_on_slot_button_pressed):
				slot_button.pressed.connect(_on_slot_button_pressed.bind(i))
	if delete_button and selected_slot < 0:
		delete_button.disabled = true

func _format_playtime_seconds(value: Variant) -> String:
	var total = int(max(0.0, float(value)))
	var hours = int(total / 3600.0)
	var minutes = int((total % 3600) / 60.0)
	var seconds = total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]

func _on_slot_button_pressed(slot_index: int) -> void:
	"""Обработка нажатия на слот сохранения"""
	selected_slot = slot_index
	
	# Выделяем выбранный слот
	for i in range(save_slots_container.get_child_count()):
		var slot_button = save_slots_container.get_child(i) as Button
		if slot_button:
			if i == slot_index:
				slot_button.modulate = Color(1.2, 1.2, 1.0, 1.0)  # Выделяем выбранный
			else:
				slot_button.modulate = Color(1, 1, 1, 1)  # Обычный цвет
	
	# Включаем кнопку загрузки, если слот содержит сохранение
	if mode == "save":
		load_button.disabled = false
		if delete_button:
			delete_button.disabled = not save_slots[slot_index]["exists"]
	elif slot_index < save_slots.size() and save_slots[slot_index]["exists"]:
		load_button.disabled = false
		if delete_button:
			delete_button.disabled = false
	else:
		load_button.disabled = true
		if delete_button:
			delete_button.disabled = true

func _on_load_button_pressed() -> void:
	"""Loads or saves data for the selected slot."""
	if selected_slot < 0 or selected_slot >= save_slots.size():
		return
	var slot_data = save_slots[selected_slot]
	if not slot_data["exists"] and mode == "load":
		return

	var save_system = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			save_system = service_locator.get_save_system()
	if save_system and save_system.has_method("set_current_slot"):
		save_system.set_current_slot(slot_data["slot_number"])

	if mode == "save":
		if slot_data["exists"]:
			if _show_overwrite_modal(slot_data):
				return
		if Engine.has_singleton("Game"):
			Engine.get_singleton("Game").save_game()
		elif Game.get_singleton():
			Game.get_singleton().save_game()
		menu_closed.emit("save")
		return

	get_tree().set_meta("save_file_path", slot_data["file_path"])
	get_tree().set_meta("start_new_game", false)

	print("LoadGameMenu: Loading save from slot %d" % slot_data["slot_number"])
	menu_closed.emit("load")
	get_tree().change_scene_to_file("res://SampleProject/Game.tscn")

func _on_back_button_pressed() -> void:
	"""Возврат в главное меню"""
	if use_state_navigation:
		menu_closed.emit("back")
		return

	# Проверяем правильный путь к MainMenu
	var main_menu_path = "res://SampleProject/MainMenu.tscn"
	if not ResourceLoader.exists(main_menu_path):
		# Пробуем альтернативный путь
		main_menu_path = "res://MainMenu.tscn"
	menu_closed.emit("back")
	get_tree().change_scene_to_file(main_menu_path)

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

func _connect_ui_refresh() -> void:
	var ui_manager = _get_ui_manager()
	if ui_manager and ui_manager.has_signal("ui_refresh_requested"):
		if not ui_manager.ui_refresh_requested.is_connected(_on_ui_refresh_requested):
			ui_manager.ui_refresh_requested.connect(_on_ui_refresh_requested)

func _on_ui_refresh_requested() -> void:
	_update_mode_label()
	_update_slots_display()


func _get_ui_manager() -> Node:
	var ui_manager = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_ui_manager"):
			ui_manager = service_locator.get_ui_manager()
	return ui_manager

func _show_overwrite_modal(slot_data: Dictionary) -> bool:
	var ui_manager = _get_ui_manager()
	if not ui_manager:
		return false
	if not ui_manager.has_method("show_modal") or not ui_manager.has_method("get_modal_layer"):
		return false

	_pending_save_slot = int(slot_data.get("slot_number", -1))
	_pending_save_file_path = str(slot_data.get("file_path", ""))

	var modal_layer = ui_manager.get_modal_layer()
	if modal_layer and modal_layer.has_signal("modal_closed"):
		modal_layer.modal_closed.connect(_on_overwrite_modal_closed, CONNECT_ONE_SHOT)

	ui_manager.show_modal(MODAL_TEMPLATES.overwrite_save())
	return true

func _on_overwrite_modal_closed(result: String) -> void:
	if result != "confirm":
		return
	if Engine.has_singleton("Game"):
		Engine.get_singleton("Game").save_game()
	elif Game.get_singleton():
		Game.get_singleton().save_game()
	menu_closed.emit("save")

func _on_delete_button_pressed() -> void:
	if selected_slot < 0 or selected_slot >= save_slots.size():
		return
	var slot_data = save_slots[selected_slot]
	if not slot_data["exists"]:
		return
	_show_delete_modal(slot_data)

func _show_delete_modal(slot_data: Dictionary) -> void:
	var ui_manager = _get_ui_manager()
	if not ui_manager:
		return
	if not ui_manager.has_method("show_modal") or not ui_manager.has_method("get_modal_layer"):
		return

	_pending_delete_slot = int(slot_data.get("slot_number", -1))
	_pending_delete_file_path = str(slot_data.get("file_path", ""))

	var modal_layer = ui_manager.get_modal_layer()
	if modal_layer and modal_layer.has_signal("modal_closed"):
		modal_layer.modal_closed.connect(_on_delete_modal_closed, CONNECT_ONE_SHOT)

	ui_manager.show_modal(MODAL_TEMPLATES.delete_save())

func _on_delete_modal_closed(result: String) -> void:
	if result != "confirm":
		return
	_delete_slot_file(_pending_delete_slot, _pending_delete_file_path)
	_pending_delete_slot = -1
	_pending_delete_file_path = ""
	_load_save_slots_info()
	_update_slots_display()

func _delete_slot_file(slot_index: int, file_path: String) -> void:
	var target_path = file_path
	var save_system = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			save_system = service_locator.get_save_system()
	if save_system and save_system.has_method("get_slot_path"):
		target_path = save_system.get_slot_path(slot_index)

	if target_path != "" and FileAccess.file_exists(target_path):
		var result = DirAccess.remove_absolute(target_path)
		if result != OK:
			push_warning("LoadGameMenu: Failed to delete slot file: %s" % target_path)

	if save_system and save_system.has_method("set_slot_metadata"):
		save_system.set_slot_metadata(slot_index, {})
