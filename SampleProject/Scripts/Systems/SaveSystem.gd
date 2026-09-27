extends Node

## 💾 SaveSystem - Модульная система сохранения/загрузки данных игры
## Координирует работу специализированных модулей сохранения
##
## ЭТАП 2.5: Refactored from monolithic 692-line file to modular architecture
## Old version backed up to: SaveSystem_old.gd

# Сигналы
signal load_game(player_data: Dictionary)

# Константы путей
const SAVE_DIR = "user://saves/"
const PROFILE_FILE = "profile.json"
const SLOT_FILE_TEMPLATE = "slot_%02d.sav"
const SLOT_COUNT = 4
## Дані гравця (інвентар, прапорці) — окремий файл на кожен слот (Q4).
const PLAYER_SLOT_TEMPLATE = "player_%02d.json"

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

# Модули сохранения
var player_data_module: PlayerDataModule
var inventory_module: InventoryModule
var flags_module: FlagsModule
var settings_module: SettingsModule

# Структура данных игрока (для обратной совместимости)
var player_data = {}

# Profile data for save slots
var profile: Dictionary = {}
var current_slot: int = 1
var game_settings: Dictionary = {}
var _session_slot_index: int = 1
var _session_start_msec: int = 0
var _session_base_playtime_sec: float = 0.0

# Включено ли автосохранение при переходе между сценами
var enable_auto_save_on_scene_transition: bool = false

## Тека слотів. Змінюється лише тестами через set_save_dir(), щоб не чіпати справжні сейви.
var save_dir: String = SAVE_DIR

func _ready():
	# Создаем папку для сохранений если её нет
	_create_save_directories()
	_load_profile()

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

func _create_save_directories():
	"""Создает папку для сохранений если её не существует"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("savegames"):
		dir.make_dir("savegames")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

func _load_profile() -> void:
	"""Loads save slot profile data."""
	profile = {
		"last_slot": 1,
		"slots": {}
	}

	var file_path = save_dir + PROFILE_FILE
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var result = json.parse(json_string)
		if result == OK and json.data is Dictionary:
			profile.merge(json.data, true)

	current_slot = int(profile.get("last_slot", 1))
	current_slot = clamp(current_slot, 1, SLOT_COUNT)
	_start_play_session(current_slot)

func _save_profile() -> void:
	"""Saves save slot profile data."""
	var file_path = save_dir + PROFILE_FILE
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("SaveSystem: Failed to save profile to %s" % file_path)
		return
	file.store_string(JSON.stringify(profile, "	"))
	file.close()

func get_slot_path(slot_index: int) -> String:
	"""Returns the slot file path."""
	var index = clamp(slot_index, 1, SLOT_COUNT)
	return save_dir + (SLOT_FILE_TEMPLATE % index)

func get_player_data_path(slot_index: int) -> String:
	"""Інвентар / прапорці / стан гравця для конкретного слота."""
	var index = clamp(slot_index, 1, SLOT_COUNT)
	return save_dir + (PLAYER_SLOT_TEMPLATE % index)

## Лише для тестів: перенаправляє слоти в окрему теку і перечитує профіль.
func set_save_dir(dir: String) -> void:
	save_dir = dir if dir.ends_with("/") else dir + "/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	_load_profile()

func slot_has_save(slot_index: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_index))

## Спільні дані картки слота для Save і Load (D80). Лише реальні значення:
## чого немає в сейві — немає в словнику (жодних вигаданих рівнів чи імен).
func get_slot_summary(slot_index: int) -> Dictionary:
	var summary := {"slot": slot_index, "exists": slot_has_save(slot_index)}
	if not summary.exists:
		return summary
	summary["file_path"] = get_slot_path(slot_index)
	var meta := get_slot_metadata(slot_index)
	for key in ["timestamp", "location", "level", "character_name"]:
		if meta.has(key) and str(meta[key]) != "":
			summary[key] = meta[key]
	summary["playtime_sec"] = float(meta.get("playtime_sec", 0.0))
	if not summary.has("location"):
		var sm := SaveManager.new()
		sm.load_from_text(get_slot_path(slot_index))
		var room := str(sm.get_value("current_room", ""))
		if room != "":
			summary["location"] = room
	return summary

func delete_slot(slot_index: int) -> bool:
	"""Видаляє сейв слота, його дані гравця і метадані."""
	var ok := true
	for path in [get_slot_path(slot_index), get_player_data_path(slot_index)]:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			push_warning("SaveSystem: failed to delete %s" % path)
			ok = false
	var slots = profile.get("slots", {})
	slots.erase(str(slot_index))
	profile["slots"] = slots
	_save_profile()
	return ok

func get_profile_path() -> String:
	return save_dir + PROFILE_FILE

func get_slot_count() -> int:
	return SLOT_COUNT

func set_current_slot(slot_index: int) -> void:
	_persist_session_playtime()
	current_slot = clamp(slot_index, 1, SLOT_COUNT)
	profile["last_slot"] = current_slot
	_save_profile()
	_start_play_session(current_slot)
	load_game_settings()

func get_slot_metadata(slot_index: int) -> Dictionary:
	var slots = profile.get("slots", {})
	return (slots.get(str(slot_index), {}) as Dictionary).duplicate()

func set_slot_metadata(slot_index: int, data: Dictionary) -> void:
	var slots = profile.get("slots", {})
	data["playtime_sec"] = _get_updated_playtime_sec(slot_index, data.get("playtime_sec", null))
	slots[str(slot_index)] = data
	profile["slots"] = slots
	_save_profile()

func get_current_playtime_sec() -> float:
	if _session_start_msec <= 0:
		return _session_base_playtime_sec
	var elapsed_sec = float(Time.get_ticks_msec() - _session_start_msec) / 1000.0
	return max(0.0, _session_base_playtime_sec + elapsed_sec)

func _start_play_session(slot_index: int) -> void:
	_session_slot_index = clamp(slot_index, 1, SLOT_COUNT)
	_session_base_playtime_sec = _get_slot_playtime_sec(_session_slot_index)
	_session_start_msec = Time.get_ticks_msec()

func _get_slot_playtime_sec(slot_index: int) -> float:
	var meta = get_slot_metadata(slot_index)
	if meta.has("playtime_sec"):
		return float(meta.get("playtime_sec", 0.0))
	return 0.0

func _get_updated_playtime_sec(slot_index: int, provided: Variant = null) -> float:
	if slot_index == _session_slot_index and _session_start_msec > 0:
		return get_current_playtime_sec()
	if provided != null:
		return float(provided)
	return _get_slot_playtime_sec(slot_index)

func _persist_session_playtime() -> void:
	if _session_start_msec <= 0:
		return
	var slots = profile.get("slots", {})
	var slot_key = str(_session_slot_index)
	var meta = (slots.get(slot_key, {}) as Dictionary).duplicate()
	meta["playtime_sec"] = get_current_playtime_sec()
	slots[slot_key] = meta
	profile["slots"] = slots
	_save_profile()

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

	# Сохраняем в файл поточного слота (раніше — один спільний файл на всі слоти)
	var file_path = get_player_data_path(current_slot)
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(data, "	")
		file.store_string(json_string)
		file.close()
		print("💾 SaveSystem: Player data saved to %s" % file_path)
		return true
	else:
		push_error("❌ SaveSystem: Failed to save player data to %s" % file_path)
		return false

func load_player_data():
	"""Загружает все данные игрока через модули"""
	var file_path = get_player_data_path(current_slot)
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
	"""Saves game settings into the current slot."""
	var data = settings_module.save()
	game_settings = data.duplicate()

	var save_manager := SaveManager.new()
	save_manager.data = {}

	var slot_path = get_slot_path(current_slot)
	if FileAccess.file_exists(slot_path):
		save_manager.load_from_text(slot_path)

	save_manager.set_value("game_settings", data)
	save_manager.save_as_text(slot_path)
	print("SaveSystem: Settings saved to slot %d" % current_slot)
	return true

func load_game_settings():
	"""Loads game settings from the current slot."""
	var slot_path = get_slot_path(current_slot)
	if not FileAccess.file_exists(slot_path):
		print("SaveSystem: No slot settings found, using defaults")
		settings_module.apply_settings()
		game_settings = settings_module.save()
		return false

	var save_manager := SaveManager.new()
	save_manager.data = {}
	save_manager.load_from_text(slot_path)

	var data = save_manager.get_value("game_settings", {})
	if data is Dictionary and not data.is_empty():
		settings_module.load_data(data)
		game_settings = data.duplicate()
		print("SaveSystem: Settings loaded from slot %d" % current_slot)
		return true

	print("SaveSystem: Slot settings missing, using defaults")
	settings_module.apply_settings()
	game_settings = settings_module.save()
	return false

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

func get_language() -> String:
	if settings_module and settings_module.has("settings"):
		return settings_module.settings.get("language", "uk")
	return "uk"

func set_language(language: String) -> void:
	if settings_module and settings_module.has("settings"):
		settings_module.settings["language"] = language
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
	for i in range(1, SLOT_COUNT + 1):
		if slot_has_save(i):
			return true
	return false

# ============================================================================
# ОБРАБОТКА ЗАКРЫТИЯ ИГРЫ
# ============================================================================

func _on_window_close_requested():
	"""Сохраняет настройки при закрытии окна"""
	_persist_session_playtime()
	save_game_settings()
	print("💾 SaveSystem: Settings saved on window close")

func _notification(what):
	"""Обработка системных событий"""
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_persist_session_playtime()
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
