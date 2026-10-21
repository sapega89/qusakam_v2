extends Node

## 💾 SaveSystem - Модульная система сохранения/загрузки данных игры
## Координирует работу специализированных модулей сохранения
##
## ЭТАП 2.5: Refactored from monolithic 692-line file to modular architecture

# Сигналы

# Константы путей
const SAVE_DIR = "user://saves/"
const PROFILE_FILE = "profile.json"
const SLOT_FILE_TEMPLATE = "slot_%02d.sav"
const SLOT_COUNT = 4
## Дані гравця (інвентар, прапорці) — окремий файл на кожен слот (Q4).
const PLAYER_SLOT_TEMPLATE = "player_%02d.json"


# Модули сохранения
var player_data_module: PlayerDataModule
var inventory_module: InventoryModule
var flags_module: FlagsModule
var settings_module: SettingsModule


# Profile data for save slots
var profile: Dictionary = {}
var current_slot: int = 1
var game_settings: Dictionary = {}
var _session_slot_index: int = 1
var _session_start_msec: int = 0
var _session_base_playtime_sec: float = 0.0

# Включено ли автосохранение при переходе между сценами

## Запуск з --script (verify_*, capture_*, playthrough) — не гра: він не читає й не пише справжні
## сейви та налаштування гравця, а працює у власній теці, яку кожен такий запуск починає порожньою.
## Раніше тести, що міняли налаштування, переписували slot_01.sav гравця (save_game_settings()).
const SCRIPT_RUN_SAVE_DIR = "user://script_run_saves/"

## Тека слотів. Тест може взяти ще окрему через set_save_dir().
var save_dir: String = SAVE_DIR

func _ready():
	if get_tree().get_script() != null:
		_start_script_run_dir()
	# Создаем папку для сохранений если её нет
	_create_save_directories()
	_load_profile()

	# Инициализируем модули
	_initialize_modules()

	# Загружаем настройки при запуске (через call_deferred для доступа к менеджерам)
	call_deferred("load_game_settings")

	# Подключаем обработку выхода из игры
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

func _start_script_run_dir() -> void:
	save_dir = SCRIPT_RUN_SAVE_DIR
	DirAccess.make_dir_recursive_absolute(save_dir)
	for file in DirAccess.get_files_at(save_dir):
		if DirAccess.remove_absolute(save_dir + file) != OK:
			push_error("SaveSystem: cannot clear %s%s left by the previous script run" % [save_dir, file])
	print("💾 SaveSystem: script run — saves and settings in %s, not %s" % [save_dir, SAVE_DIR])

## Лише для тестів: перенаправляє слоти в окрему теку і перечитує профіль.
func set_save_dir(dir: String) -> void:
	dir = dir if dir.ends_with("/") else dir + "/"
	if dir == SAVE_DIR and get_tree().get_script() != null:
		push_error("SaveSystem: a script run may not point at the player's saves %s" % SAVE_DIR)
		return
	save_dir = dir
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
	data["last_save_time"] = Time.get_datetime_string_from_system()

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

	print("💾 SaveSystem: Player data loaded from %s" % file_path)
	return true

# ============================================================================
# СОХРАНЕНИЕ НАСТРОЕК
# ============================================================================

func save_game_settings():
	"""Saves game settings into the current slot."""
	var data = settings_module.save()
	game_settings = data.duplicate()

	var slot_path = get_slot_path(current_slot)
	if not FileAccess.file_exists(slot_path):
		# Слот без сейву гри не створюємо: Game.gd вважав би його сейвом без кімнати.
		# Налаштування потраплять у слот з першим збереженням гри (Game.gd → "game_settings").
		return true
	var slot_data := _read_slot(slot_path)
	slot_data["game_settings"] = data
	var file := FileAccess.open(slot_path, FileAccess.WRITE)
	file.store_string(var_to_str(slot_data))
	file.close()
	print("SaveSystem: Settings saved to slot %d" % current_slot)
	return true


## Вміст файла слота як є — БЕЗ SaveManager.load_from_text(): той заодно підміняє поточний стан
## MetSys (MetSys.set_save_data) даними з файла. Через це кожна зміна налаштувань посеред гри
## відкочувала відкриту карту до стану з диска, і наступний сейв записував уже порожню карту.
func _read_slot(slot_path: String) -> Dictionary:
	if not FileAccess.file_exists(slot_path):
		return {}
	return str_to_var(FileAccess.get_file_as_string(slot_path))

func load_game_settings():
	"""Loads game settings from the current slot."""
	var slot_path = get_slot_path(current_slot)
	if not FileAccess.file_exists(slot_path):
		print("SaveSystem: No slot settings found, using defaults")
		settings_module.apply_settings()
		game_settings = settings_module.save()
		return false

	var data: Dictionary = _read_slot(slot_path)["game_settings"]
	settings_module.load_data(data)
	game_settings = data.duplicate()
	print("SaveSystem: Settings loaded from slot %d" % current_slot)
	return true

# ============================================================================
# НАСТРОЙКИ (делегируем в SettingsModule)
# ============================================================================

func get_language() -> String:
	return settings_module.settings["language"]

func set_language(language: String) -> void:
	settings_module.settings["language"] = language
	save_game_settings()

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


	if get_tree().root.close_requested.is_connected(_on_window_close_requested):
		get_tree().root.close_requested.disconnect(_on_window_close_requested)

	print("💾 SaveSystem: Disconnected from all signals")
