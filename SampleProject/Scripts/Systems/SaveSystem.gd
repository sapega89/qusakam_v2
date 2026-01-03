extends Node

## 💾 SaveSystem - Модульная система сохранения/загрузки данных игры
## Координирует работу специализированных модулей сохранения
##
## ЭТАП 2.5: Refactored from monolithic 692-line file to modular architecture
## Old version backed up to: SaveSystem_old.gd

# Сигналы
signal load_game(player_data: Dictionary)

# Константы путей
const SAVE_FILE_PATH = "user://savegames/"
const PLAYER_DATA_FILE = "player_data.json"
const GAME_SETTINGS_FILE = "game_settings.json"

# Модули сохранения
var player_data_module: PlayerDataModule
var inventory_module: InventoryModule
var flags_module: FlagsModule
var settings_module: SettingsModule

# Структура данных игрока (для обратной совместимости)
var player_data = {}

# Включено ли автосохранение при переходе между сценами
var enable_auto_save_on_scene_transition: bool = false

func _ready():
	# Создаем папку для сохранений если её нет
	_create_save_directory()

	# Инициализируем модули
	_initialize_modules()

	# Загружаем настройки при запуске (через call_deferred для доступа к менеджерам)
	call_deferred("load_game_settings")

	# Подключаем обработку выхода из игры
	if get_tree().root.has_signal("close_requested"):
		get_tree().root.close_requested.connect(_on_window_close_requested)

	# Подключаемся к событиям переходов сцен для автосохранения
	call_deferred("_connect_scene_events")

func _initialize_modules():
	"""Инициализирует модули сохранения"""
	# Создаём модули
	player_data_module = PlayerDataModule.new()
	inventory_module = InventoryModule.new()
	flags_module = FlagsModule.new()
	settings_module = SettingsModule.new()

	# Добавляем как дочерние узлы
	add_child(player_data_module)
	add_child(inventory_module)
	add_child(flags_module)
	add_child(settings_module)

	print("💾 SaveSystem: Initialized modular architecture (4 modules)")

func _connect_scene_events():
	"""Подписывается на события переходов сцен для автосохранения"""
	if Engine.has_singleton("EventBus"):
		EventBus.scene_transition_completed.connect(_on_scene_transition_completed)
		EventBus.dialogue_finished.connect(_on_dialogue_finished)
		print("💾 SaveSystem: Connected to scene and dialogue events")

func _create_save_directory():
	"""Создает папку для сохранений если её не существует"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("savegames"):
		dir.make_dir("savegames")

# ============================================================================
# СОХРАНЕНИЕ ДАННЫХ ИГРОКА
# ============================================================================

func save_player_data():
	"""Сохраняет все данные игрока через модули"""
	var data = {}

	# Собираем данные из всех модулей
	data["player"] = player_data_module.save()
	data["inventory"] = inventory_module.save()
	data["flags"] = flags_module.save()

	# Добавляем метаданные
	data["save_location_name"] = _get_current_location_name()
	data["last_save_time"] = Time.get_datetime_string_from_system()

	# Обновляем player_data для обратной совместимости
	player_data = _flatten_data(data)

	# Сохраняем в файл
	var file_path = SAVE_FILE_PATH + PLAYER_DATA_FILE
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
		print("💾 SaveSystem: Player data saved to %s" % file_path)
		return true
	else:
		push_error("❌ SaveSystem: Failed to save player data to %s" % file_path)
		return false

func load_player_data():
	"""Загружает все данные игрока через модули"""
	var file_path = SAVE_FILE_PATH + PLAYER_DATA_FILE
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		print("💾 SaveSystem: No save file found at %s" % file_path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("❌ SaveSystem: Failed to parse save file: %s" % json.get_error_message())
		return false

	var data = json.data

	# Загружаем данные в модули
	if "player" in data:
		player_data_module.load_data(data.player)
	if "inventory" in data:
		inventory_module.load_data(data.inventory)
	if "flags" in data:
		flags_module.load_data(data.flags)

	# Обновляем player_data для обратной совместимости
	player_data = _flatten_data(data)

	# Отправляем сигнал
	load_game.emit(player_data)

	print("💾 SaveSystem: Player data loaded from %s" % file_path)
	return true

# ============================================================================
# СОХРАНЕНИЕ НАСТРОЕК
# ============================================================================

func save_game_settings():
	"""Сохраняет настройки игры через SettingsModule"""
	var data = settings_module.save()

	var file_path = SAVE_FILE_PATH + GAME_SETTINGS_FILE
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
		print("💾 SaveSystem: Settings saved")
		return true
	else:
		push_error("❌ SaveSystem: Failed to save settings to %s" % file_path)
		return false

func load_game_settings():
	"""Загружает настройки игры через SettingsModule"""
	var file_path = SAVE_FILE_PATH + GAME_SETTINGS_FILE
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		print("💾 SaveSystem: No settings file found, using defaults")
		settings_module.apply_settings()  # Применяем настройки по умолчанию
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("❌ SaveSystem: Failed to parse settings: %s" % json.get_error_message())
		return false

	settings_module.load_data(json.data)
	print("💾 SaveSystem: Settings loaded")
	return true

# ============================================================================
# МЕТОДЫ ДЛЯ ОБНОВЛЕНИЯ ДАННЫХ (для обратной совместимости)
# ============================================================================

func update_player_health(current_health: int, max_health: int):
	"""Обновляет здоровье игрока (сохраняется при следующем save_player_data)"""
	if not player_data.has("player"):
		player_data["player"] = {}
	player_data["player"]["current_health"] = current_health
	player_data["player"]["max_health"] = max_health

func update_player_position(position: Vector2):
	"""Обновляет позицию игрока (сохраняется при следующем save_player_data)"""
	if not player_data.has("player"):
		player_data["player"] = {}
	player_data["player"]["player_position"] = {"x": position.x, "y": position.y}

func add_unlocked_skill(skill_name: String):
	"""Добавляет разблокированную способность"""
	if not player_data.has("player"):
		player_data["player"] = {}
	if not player_data["player"].has("unlocked_skills"):
		player_data["player"]["unlocked_skills"] = []
	if not player_data["player"]["unlocked_skills"].has(skill_name):
		player_data["player"]["unlocked_skills"].append(skill_name)

# ============================================================================
# НАСТРОЙКИ (делегируем в SettingsModule)
# ============================================================================

func update_master_volume(volume: float):
	settings_module.update_master_volume(volume)
	save_game_settings()

func update_music_volume(volume: float):
	settings_module.update_music_volume(volume)
	save_game_settings()

func update_sfx_volume(volume: float):
	settings_module.update_sfx_volume(volume)
	save_game_settings()

func toggle_fullscreen():
	settings_module.toggle_fullscreen()
	save_game_settings()

func toggle_vsync():
	settings_module.toggle_vsync()
	save_game_settings()

# ============================================================================
# АВТОСОХРАНЕНИЕ И СОБЫТИЯ
# ============================================================================

func auto_save():
	"""Автоматическое сохранение данных игрока"""
	save_player_data()

func _on_scene_transition_completed(scene_path: String):
	"""Автосохранение при переходе в важные сцены (если включено)"""
	if not enable_auto_save_on_scene_transition:
		return

	var auto_save_scenes = ["village1", "village", "town", "hub"]
	var should_save = false

	for save_scene in auto_save_scenes:
		if save_scene in scene_path.to_lower():
			should_save = true
			break

	if should_save:
		print("💾 SaveSystem: Auto-saving after transition to: %s" % scene_path)
		call_deferred("save_player_data")

func _on_dialogue_finished(dialogue_id: String = ""):
	"""Отслеживает завершенные диалоги"""
	if dialogue_id == "":
		return

	if not player_data.has("completed_dialogues"):
		player_data["completed_dialogues"] = {}

	player_data["completed_dialogues"][dialogue_id] = true
	print("💬 SaveSystem: Dialogue marked as completed: %s" % dialogue_id)

# ============================================================================
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ============================================================================

func _get_current_location_name() -> String:
	"""Получает название текущей локации"""
	# Пробуем получить из MetSys
	if Engine.has_singleton("MetSys"):
		var metsys = Engine.get_singleton("MetSys")
		if metsys and metsys.has_method("get_current_room_name"):
			var room_name = metsys.get_current_room_name()
			if not room_name.is_empty():
				return room_name

	# Fallback: используем имя сцены
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.name

	return "Unknown Location"

func _flatten_data(data: Dictionary) -> Dictionary:
	"""Преобразует модульные данные в плоский формат (для обратной совместимости)"""
	var flat = {}

	# Копируем данные игрока
	if "player" in data:
		for key in data.player:
			flat[key] = data.player[key]

	# Копируем инвентарь
	if "inventory" in data:
		flat["inventory"] = data.inventory

	# Копируем флаги
	if "flags" in data:
		for key in data.flags:
			flat[key] = data.flags[key]

	# Копируем метаданные
	if "save_location_name" in data:
		flat["save_location_name"] = data.save_location_name
	if "last_save_time" in data:
		flat["last_save_time"] = data.last_save_time

	return flat

# ============================================================================
# УПРАВЛЕНИЕ ФАЙЛАМИ
# ============================================================================

func has_save_file() -> bool:
	"""Проверяет существование файла сохранения"""
	return FileAccess.file_exists(SAVE_FILE_PATH + PLAYER_DATA_FILE)

func delete_save_file():
	"""Удаляет файл сохранения"""
	var file_path = SAVE_FILE_PATH + PLAYER_DATA_FILE
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false

# ============================================================================
# ОБРАБОТКА ЗАКРЫТИЯ ИГРЫ
# ============================================================================

func _on_window_close_requested():
	"""Сохраняет настройки при закрытии окна"""
	save_game_settings()
	print("💾 SaveSystem: Settings saved on window close")

func _notification(what):
	"""Обработка системных событий"""
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_game_settings()
			print("💾 SaveSystem: Settings saved on exit")
			get_tree().quit()

func _exit_tree() -> void:
	"""Отписывается от всех сигналов при удалении"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Отписывается от всех сигналов EventBus"""
	if not Engine.has_singleton("EventBus"):
		return

	if EventBus.scene_transition_completed.is_connected(_on_scene_transition_completed):
		EventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	if EventBus.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.dialogue_finished.disconnect(_on_dialogue_finished)

	if get_tree().root.has_signal("close_requested") and get_tree().root.close_requested.is_connected(_on_window_close_requested):
		get_tree().root.close_requested.disconnect(_on_window_close_requested)

	print("💾 SaveSystem: Disconnected from all signals")
