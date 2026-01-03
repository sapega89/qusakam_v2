extends Control

# Сцена выбора сохранения для загрузки игры

@onready var save_slots_container: VBoxContainer = $MainPanel/VBoxContainer/SaveSlotsContainer
@onready var load_button: Button = $MainPanel/VBoxContainer/ButtonsContainer/LoadButton
@onready var back_button: Button = $MainPanel/VBoxContainer/ButtonsContainer/BackButton

var selected_slot: int = -1
var save_slots: Array[Dictionary] = []

const METSYS_SAVE_PATH = "user://example_save_data.sav"
const SAVE_SLOTS_COUNT = 3

func _ready() -> void:
	# Подключаем кнопки
	back_button.pressed.connect(_on_back_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	
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
	"""Загружает информацию о всех слотах сохранений"""
	save_slots.clear()
	
	# Проверяем основной слот MetSys (слот 1)
	var slot1_data = _get_save_slot_info(1)
	save_slots.append(slot1_data)
	
	# Проверяем дополнительные слоты (если они есть)
	for i in range(2, SAVE_SLOTS_COUNT + 1):
		var slot_data = _get_save_slot_info(i)
		save_slots.append(slot_data)

func _get_save_slot_info(slot_number: int) -> Dictionary:
	"""Получает информацию о слоте сохранения"""
	var slot_data = {
		"slot_number": slot_number,
		"exists": false,
		"location": "",
		"time": "",
		"collectibles": 0,
		"file_path": ""
	}
	
	# Для слота 1 проверяем основной файл MetSys
	if slot_number == 1:
		var metsys_path = METSYS_SAVE_PATH
		if FileAccess.file_exists(metsys_path):
			slot_data.exists = true
			slot_data.file_path = metsys_path
			# Загружаем информацию из сохранения
			var save_manager = SaveManager.new()
			if save_manager.load_from_text(metsys_path) == OK:
				slot_data.collectibles = save_manager.get_value("collectible_count", 0)
				# Не используем current_room напрямую, лучше получить название из SaveSystem
			
			# Проверяем SaveSystem для дополнительной информации
			if Engine.has_singleton("ServiceLocator"):
				var service_locator = Engine.get_singleton("ServiceLocator")
				if service_locator and service_locator.has_method("get_save_system"):
					var save_system = service_locator.get_save_system()
					if save_system and save_system.has("player_data"):
						var player_data = save_system.player_data
						if player_data.has("save_location_name") and not player_data.save_location_name.is_empty():
							slot_data.location = player_data.save_location_name
						# Если название не найдено, пробуем определить по имени комнаты из MetSys
						elif slot_data.location.is_empty():
							var current_room = save_manager.get_value("current_room", "")
							if not current_room.is_empty():
								# Пробуем определить название по имени комнаты
								if current_room.begins_with("StartingPoint") or current_room.contains("Starting"):
									slot_data.location = "Лаборатория"
								else:
									slot_data.location = current_room
							else:
								# Только если совсем ничего не найдено
								slot_data.location = "Лаборатория"
						if player_data.has("last_save_time") and not player_data.last_save_time.is_empty():
							slot_data.time = player_data.last_save_time
			# Если SaveSystem недоступен, пробуем определить по имени комнаты
			elif slot_data.location.is_empty():
				var current_room = save_manager.get_value("current_room", "")
				if not current_room.is_empty():
					if current_room.begins_with("StartingPoint") or current_room.contains("Starting"):
						slot_data.location = "Лаборатория"
					else:
						slot_data.location = current_room
				else:
					slot_data.location = "Лаборатория"
	else:
		# Для других слотов проверяем отдельные файлы (если они есть)
		var slot_path = "user://save_slot_%d.sav" % slot_number
		if FileAccess.file_exists(slot_path):
			slot_data.exists = true
			slot_data.file_path = slot_path
			# Загружаем информацию из сохранения
			var save_manager = SaveManager.new()
			if save_manager.load_from_text(slot_path) == OK:
				slot_data.collectibles = save_manager.get_value("collectible_count", 0)
				var current_room = save_manager.get_value("current_room", "")
				if not current_room.is_empty():
					slot_data.location = current_room
	
	return slot_data

func _update_slots_display() -> void:
	"""Обновляет отображение слотов сохранений"""
	for i in range(save_slots_container.get_child_count()):
		var slot_button = save_slots_container.get_child(i) as Button
		if slot_button:
			var slot_data: Dictionary = {}
			if i < save_slots.size():
				slot_data = save_slots[i]
			if slot_data.has("exists") and slot_data.exists:
				# Формируем текст для слота с сохранением
				var slot_text = "Slot %d: " % (i + 1)
				# Используем сохраненное название локации
				var location_name = slot_data.location
				if location_name.is_empty():
					# Только если название не найдено, используем fallback
					location_name = "Unknown Location"
				slot_text += location_name
				
				# Добавляем информацию о предметах
				if slot_data.collectibles > 0:
					slot_text += " (%d/6 предметов)" % slot_data.collectibles
				
				# Добавляем время сохранения
				if not slot_data.time.is_empty():
					slot_text += "\n%s" % slot_data.time
				
				slot_button.text = slot_text
				slot_button.disabled = false
			else:
				# Пустой слот
				slot_button.text = "Slot %d: Empty" % (i + 1)
				slot_button.disabled = false
			
			# Подключаем сигнал нажатия
			if not slot_button.pressed.is_connected(_on_slot_button_pressed):
				slot_button.pressed.connect(_on_slot_button_pressed.bind(i))

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
	if slot_index < save_slots.size() and save_slots[slot_index].exists:
		load_button.disabled = false
	else:
		load_button.disabled = true

func _on_load_button_pressed() -> void:
	"""Загружает выбранное сохранение"""
	if selected_slot < 0 or selected_slot >= save_slots.size():
		return
	
	var slot_data = save_slots[selected_slot]
	if not slot_data.exists:
		return
	
	# Устанавливаем путь к сохранению для загрузки
	if selected_slot == 0:
		# Слот 1 использует основной путь
		get_tree().set_meta("save_file_path", METSYS_SAVE_PATH)
	else:
		# Другие слоты используют свои пути
		get_tree().set_meta("save_file_path", slot_data.file_path)
	
	# Устанавливаем флаг загрузки
	get_tree().set_meta("start_new_game", false)
	
	print("📂 LoadGameMenu: Loading save from slot %d" % (selected_slot + 1))
	
	# Переходим к игре
	get_tree().change_scene_to_file("res://SampleProject/Game.tscn")

func _on_back_button_pressed() -> void:
	"""Возврат в главное меню"""
	# Проверяем правильный путь к MainMenu
	var main_menu_path = "res://SampleProject/MainMenu.tscn"
	if not ResourceLoader.exists(main_menu_path):
		# Пробуем альтернативный путь
		main_menu_path = "res://MainMenu.tscn"
	get_tree().change_scene_to_file(main_menu_path)

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")
