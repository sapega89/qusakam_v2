# This is the main script of the game. It manages the current map and some other stuff.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"
class_name Game

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")
const DEFAULT_SAVE_PATH = "user://saves/slot_01.sav"

# The game starts in this map. Note that it's scene name only, just like MetSys refers to rooms.
@export var starting_map: String = "Canyon.tscn"

# Number of collected collectibles. Setting it also updates the counter.
var collectibles: int:
	set(count):
		collectibles = count
		%CollectibleCount.text = "%d/6" % count

# The coordinates of generated rooms. MetSys does not keep this list, so it needs to be done manually.
var generated_rooms: Array[Vector3i]
# The typical array of game events. It's supplementary to the storable objects.
var events: Array[String]
# For Custom Runner integration.
var custom_run: bool

# Флаги квестов, диалогов, катсцен, боссов и локаций
# Используются для сохранения прогресса игры через SaveSystem
var quest_flags: Dictionary = {}
var cutscene_flags: Dictionary = {}
var boss_flags: Dictionary = {}
var location_flags: Dictionary = {}
var _bootstrapped: = false
var game_instance_id: String = ""  # Унікальний ID екземпляру Game
static var _last_game_id: int = 0  # Статичний лічильник для генерації унікальних ID

var _ready_call_count: int = 0

func _ready() -> void:
	_ready_call_count += 1
	
	# Генеруємо унікальний ID для цього екземпляру Game
	if game_instance_id.is_empty():
		_last_game_id += 1
		game_instance_id = "Game_%d_%d" % [Time.get_ticks_msec(), _last_game_id]
		print("🆔 [Game] Створено новий екземпляр з ID: %s" % game_instance_id)
	else:
		print("🆔 [Game] Використовується існуючий екземпляр з ID: %s" % game_instance_id)
	
	# ТИМЧАСОВО: діагностика квестових прапорців. Прибрати після розбору.
	DebugLogger.current_level = DebugLogger.LogLevel.INFO

	print("=")
	print("🎮 [Game] ========== _ready() ВИКЛИКАНО (виклик #%d) ==========" % _ready_call_count)
	print("🆔 [Game] ID екземпляру: %s" % game_instance_id)
	print("🎮 [Game] Поточна сцена: %s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene else "null"))
	print("🎮 [Game] Поточний час: %s" % Time.get_datetime_string_from_system())
	
	# ВАЖЛИВО: Встановлюємо мета-значення singleton ПЕРЕД викликом get_singleton()
	# Це потрібно для того, щоб get_singleton() міг знайти екземпляр
	get_script().set_meta(&"singleton", self)
	
	# Перевірка, чи це той самий екземпляр
	var singleton = Game.get_singleton()
	if singleton and singleton != self:
		print("⚠️ [Game] УВАГА: Знайдено ІНШИЙ екземпляр Game!")
		print("⚠️ [Game] Поточний ID: %s" % game_instance_id)
		print("⚠️ [Game] Singleton ID: %s" % (singleton.game_instance_id if singleton.has("game_instance_id") else "N/A"))
		print("⚠️ [Game] ЦЕ МОЖЕ БУТИ ПРИЧИНОЮ ПОДВІЙНОЇ ТЕЛЕПОРТАЦІЇ - створено новий екземпляр!")
	
	# singleton meta можно оставить, но это тоже выполнится много раз — ок
	get_script().set_meta(&"singleton", self)

	# ВАЖНО: bootstrap только один раз
	if _bootstrapped:
		print("⚠️ [Game] _ready() вже викликано (_bootstrapped=true), пропускаємо ініціалізацію")
		print("⚠️ [Game] ID екземпляру: %s" % game_instance_id)
		print("⚠️ [Game] ЦЕ МОЖЕ БУТИ ПРИЧИНОЮ ПОДВІЙНОЇ ТЕЛЕПОРТАЦІЇ - гра перестворюється!")
		print("⚠️ [Game] Stack trace:")
		print_stack()
		DebugLogger.warning("Game: ⚠️ _ready() вже викликано (_bootstrapped=true), пропускаємо ініціалізацію", "Game")
		DebugLogger.warning("Game: ⚠️ ЦЕ МОЖЕ БУТИ ПРИЧИНОЮ ПОДВІЙНОЇ ТЕЛЕПОРТАЦІЇ - гра перестворюється!", "Game")
		print("=")
		return
	_bootstrapped = true
	print("✅ [Game] _ready() викликано вперше, ініціалізуємо гру")
	print("🆔 [Game] Екземпляр Game з ID: %s" % game_instance_id)
	DebugLogger.info("Game: ✅ _ready() викликано вперше, ініціалізуємо гру", "Game")

	# Make sure MetSys is in initial state (ТОЛЬКО НА НОВЫЙ ЗАПУСК ИЗ МЕНЮ)
	print("🔄 [Game] Скидаємо стан MetSys...")
	MetSys.reset_state()
	print("✅ [Game] MetSys стан скинуто")

	var player_node = $Player
	if player_node:
		print("✅ [Game] Player node знайдено: %s" % player_node.name)
		set_player(player_node)
		player_node.process_mode = Node.PROCESS_MODE_INHERIT
		player_node.visible = true
		print("✅ [Game] Player налаштовано: process_mode=%d, visible=%s" % [player_node.process_mode, player_node.visible])
	else:
		push_error("🎮 Game: Player node NOT FOUND!")
		print("❌ [Game] Player node НЕ ЗНАЙДЕНО!")

	print("📞 [Game] Викликаємо _initialize_save_and_room() через call_deferred...")
	call_deferred("_initialize_save_and_room")
	print("✅ [Game] _ready() завершено, _initialize_save_and_room() заплановано")
	print("=")


func _unhandled_input(event: InputEvent) -> void:
	# Обробка Escape для відкриття/закриття game menu через MenuManager
	# ВАЖНО: Перевіряємо, чи це Escape (KEY_ESCAPE), а не інша клавіша
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		# Перевіряємо, чи меню вже відкрите - якщо так, не обробляємо тут (це зробить game_menu.gd)
		if ServiceLocator:
			var menu_manager = ServiceLocator.get_menu_manager()
			if menu_manager and menu_manager.is_menu_open():
				# Меню вже відкрите, воно само обробить Escape для закриття
				return

		print("🎮 Game: Escape натиснуто!")
		# ServiceLocator - це autoload, доступний напряму через ім'я
		if ServiceLocator:
			var menu_manager = ServiceLocator.get_menu_manager()
			if menu_manager:
				print("🎮 Game: Відкриваємо меню...")
				menu_manager.toggle_game_menu()
				get_viewport().set_input_as_handled()
				return  # ВАЖНО: повертаємося, щоб не обробляти далі
		else:
			print("⚠️ Game: ServiceLocator не знайдено!")

	# Також обробляємо ui_cancel action (якщо він налаштований на Escape)
	if event.is_action_pressed("ui_cancel"):
		print("🎮 Game: ui_cancel action натиснуто!")
		# Перевіряємо, чи це не оброблено вже вище
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			# Вже оброблено вище
			return

		# ServiceLocator - це autoload, доступний напряму через ім'я
		if ServiceLocator:
			var menu_manager = ServiceLocator.get_menu_manager()
			if menu_manager:
				menu_manager.toggle_game_menu()
				get_viewport().set_input_as_handled()
				return

func _normalize_room_ref_to_scene_path(room_ref: String) -> String:
	var ref := room_ref.strip_edges()
	if ref.is_empty():
		return ""

	# Already full scene path
	if ref.begins_with("res://") and ref.ends_with(".tscn"):
		return ref

	# File name only, like "Canyon.tscn"
	if ref.ends_with(".tscn") and not ref.begins_with("res://"):
		var candidate := "res://SampleProject/Maps/" + ref
		if ResourceLoader.exists(candidate):
			return candidate
		return ""  # unknown file name

	# Looks like MetSys room id (often starts with ":" in your logs)
	if ref.begins_with(":"):
		# TODO: resolve id -> scene path using MetSys/MapData API.
		# If you don't have API, you can fallback to default map (for now).
		return ""

	return ""  # unsupported format

func _normalize_room_ref_to_scene_ref(room_ref: String) -> String:
	var ref := room_ref.strip_edges()
	if ref.is_empty():
		return ""

	# Full scene path
	if ref.begins_with("res://") and ref.ends_with(".tscn"):
		return ref

	# File name only
	if ref.ends_with(".tscn") and not ref.begins_with("res://"):
		var candidate := "res://SampleProject/Maps/" + ref
		if ResourceLoader.exists(candidate):
			return candidate
		return ""

	# Looks like Godot UID tail stored as ":xxxx"
	if ref.begins_with(":"):
		var uid_ref := "uid://" + ref.substr(1)
		if ResourceLoader.exists(uid_ref):
			return uid_ref
		return ""

	return ""

var _save_room_initialized:=false
var loaded_from_save = false

func _get_current_save_path() -> String:
	var save_system = ServiceLocator.get_save_system() if ServiceLocator else null
	if save_system and save_system.has_method("get_slot_path"):
		var slot_index = 1
		var slot_value = save_system.get("current_slot")
		if typeof(slot_value) == TYPE_INT:
			slot_index = slot_value
		return save_system.get_slot_path(slot_index)
	return DEFAULT_SAVE_PATH

func _initialize_save_and_room() -> void:
	if _save_room_initialized:
		print("⚠️ [Game] _initialize_save_and_room() вже викликано, пропускаємо")
		DebugLogger.warning("Game: ⚠️ _initialize_save_and_room() вже викликано, пропускаємо", "Game")
		return
	_save_room_initialized = true
	print("✅ [Game] _initialize_save_and_room() викликано вперше")
	DebugLogger.info("Game: ✅ _initialize_save_and_room() викликано вперше", "Game")
	# Check if this is a new game (don't load save) or loading from save
	var start_new_game = get_tree().get_meta("start_new_game", false)
	# Clear the meta after reading it
	if get_tree().has_meta("start_new_game"):
		get_tree().remove_meta("start_new_game")

	# Проверяем, есть ли указанный путь к сохранению (из меню загрузки)
	var save_file_path = _get_current_save_path()
	if get_tree().has_meta("save_file_path"):
		save_file_path = get_tree().get_meta("save_file_path")
		get_tree().remove_meta("save_file_path")

	if not start_new_game and FileAccess.file_exists(save_file_path):
		var save_manager := SaveManager.new()
		save_manager.load_from_text(save_file_path)

		# Metadata mapping
		collectibles = save_manager.get_value("collectible_count", 0)
		_assign_array(generated_rooms, save_manager.get_value("generated_rooms", []))
		_assign_array(events, save_manager.get_value("events", []))
		_assign_array(player.abilities, save_manager.get_value("abilities", []))

		# Restore MetSys state (map, items, position)
		save_manager.retrieve_game(self)
		loaded_from_save = true
		
		# КРИТИЧНО: Загружаем quest flags ДО вызова load_room()
		# Это гарантирует что quest flags будут доступны когда сцена загрузится
		_load_full_game_data_from_save_system()		

		var loaded_scene_path := String(save_manager.get_value("current_room_scene_path", ""))
		if not loaded_scene_path.is_empty():
			starting_map = loaded_scene_path
		else:
			# fallback на room_name (старые сейвы)
			var room_name := String(save_manager.get_value("current_room", ""))
			if not room_name.is_empty():
				starting_map = room_name
	else:
		# If no data exists, set empty one and initialize default values for new game.
		MetSys.set_save_data()
		# Initialize collectibles counter to 0 for new game
		collectibles = 0
		generated_rooms.clear()
		events.clear()
		quest_flags.clear()
		cutscene_flags.clear()
		boss_flags.clear()
		location_flags.clear()

	# Initialize room when it changes.
	if not room_loaded.is_connected(init_room):
		room_loaded.connect(init_room, CONNECT_DEFERRED)
	
	var scene_path := _normalize_room_ref_to_scene_ref(starting_map)
	if scene_path.is_empty():
		push_error("Cannot resolve starting_map to scene ref: %s" % starting_map)
		scene_path = "res://SampleProject/Maps/Canyon.tscn"

	print("🚪 [Game] Викликаємо load_room() для: %s" % scene_path)
	load_room(scene_path)  # навмисно без await: нижче є своє очікування кадру
	print("🚪 [Game] load_room() викликано для: %s" % scene_path)


	# ВАЖНО: Для новой игры позиционируем игрока на SavePoint в стартовой комнате
	# (при загрузке сохранения позиция уже восстановлена через save_manager.retrieve_game выше)
	if start_new_game:
		await get_tree().process_frame  # Ждём загрузки комнаты
		_position_player_at_save_point()

	# MetSys автоматически устанавливает позицию игрока:
	# - Из сохранения при загрузке игры (через save_manager.retrieve_game)
	# - На SavePoint при новой игре (если он есть в комнате)
	# Не нужно вручную искать SavePoint - MetSys сам это делает!

	# Add module for room transitions.
	# УВАГА: тільки ScrollingRoomTransitions. Він обнуляє game.map перед
	# завантаженням, через що базовий load_room() не чекає map.tree_exited і
	# відпрацьовує синхронно. RoomTransitions так не робить і вимагає await у
	# нашому override — а це ламає переходи (див. коментар у load_room()).
	var transitions := add_module("ScrollingRoomTransitions.gd")
	transitions.SCROLL_TIME = 0.4      # тривалість доїзду камери, с
	transitions.SCROLL_DISTANCE = 0.5  # дистанція в частках екрана (1.0 = повний екран)
	print("📦 [Game] Модуль ScrollingRoomTransitions.gd додано")

	# Reset position tracking (feature specific to this project).
	await get_tree().physics_frame
	reset_map_starting_coords.call_deferred()

	# Make sure minimap is at correct position (required for themes to work correctly).
	%Minimap.set_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)

# Returns this node from anywhere.
static func get_singleton() -> Game:
	var script = Game as Script
	if script.has_meta(&"singleton"):
		return script.get_meta(&"singleton") as Game
	# Fallback: try to find Game in the scene tree
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		var root = tree.root
		if root:
			# Try to find Game node in the scene tree
			var game_node = root.find_child("Game", true, false)
			if game_node and game_node is Game:
				# Cache it for future calls
				script.set_meta(&"singleton", game_node)
				return game_node as Game
	return null

# Unified Save/Load Coordinator
func save_game() -> bool:
	"""Main entry point for saving the game state across all systems.
	Повертає true лише коли і сейв MetSys, і дані гравця записано (D76/D79:
	модалка успіху показується тільки на true)."""
	DebugLogger.info("💾 Game: Starting unified save sequence...", "Game")
	
	# 1. MetSys Save (Map, Rooms, Basic Player Props)
	var save_manager := SaveManager.new()
	save_manager.set_value("collectible_count", collectibles)
	save_manager.set_value("generated_rooms", generated_rooms)
	save_manager.set_value("events", events)
	var room_name := MetSys.get_current_room_name()
	save_manager.set_value("current_room", room_name)

# Сохраняем полный путь сцены (ГЛАВНОЕ)
	var room_scene_path := MetSys.get_full_room_path(room_name)
	save_manager.set_value("current_room_scene_path", room_scene_path)
	save_manager.set_value("abilities", player.abilities)
	
	save_manager.store_game(self)
	# SaveManager.save_as_text() нічого не повертає — пишемо самі, щоб знати результат.
	var save_path := _get_current_save_path()
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	if save_file == null:
		push_error("Game: failed to write save %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	save_file.store_string(var_to_str(save_manager.data))
	save_file.close()

	var save_system = ServiceLocator.get_save_system() if ServiceLocator else null
	if save_system and save_system.has_method("set_slot_metadata"):
		var meta = {
			"timestamp": Time.get_datetime_string_from_system(),
			"location": room_name
		}
		var slot_value = save_system.get("current_slot")
		var slot_index = slot_value if typeof(slot_value) == TYPE_INT else 1
		meta["slot"] = slot_index
		# Картка слота (Figma 150:1278): рівень і ім'я лідера — реальні дані (Q3).
		var xp = ServiceLocatorHelper.get_manager("get_xp_manager")
		if xp and xp.has_method("get_level"):
			meta["level"] = xp.get_level()
		var chars = ServiceLocatorHelper.get_manager("get_character_manager")
		if chars and chars.has_method("get_active_character"):
			var lead = chars.get_active_character()
			if lead and lead.name != "":
				meta["character_name"] = lead.name
		save_system.set_slot_metadata(slot_index, meta)

	# 2. SaveSystem Sync (Inventory, Flags, Quest Progress)
	# Update player state before full data save
	_sync_player_state_to_save_system()
	if not _save_full_game_data_to_save_system():
		push_error("Game: player data was not saved")
		return false

	DebugLogger.info("✅ Game: Unified save completed successfully.", "Game")
	return true

func _assign_array(target: Array, source: Variant):
	if source is Array:
		target.assign(source)
	else:
		target.clear()

func _sync_player_state_to_save_system():
	var service_locator = ServiceLocator if Engine.has_singleton("ServiceLocator") else null
	if not service_locator: return
	
	var player_state_manager = service_locator.get_player_state_manager()
	if player_state_manager:
		player_state_manager.set_player_position(player.global_position)
	
	var save_system = service_locator.get_save_system()
	if save_system and save_system.has("player_data"):
		save_system.player_data.current_scene = MetSys.get_current_room_name()

var _load_room_call_count: int = 0
var _last_load_room_path: String = ""

func load_room(room_ref: String) -> void:
	"""Перевизначений load_room() з логуванням для діагностики"""
	_load_room_call_count += 1
	var normalized_path = _normalize_room_ref_to_scene_ref(room_ref)
	
	print("🚪 [Game] load_room() викликано #%d: room_ref='%s', path='%s'" % [_load_room_call_count, room_ref, normalized_path])
	print("🆔 [Game] ID екземпляру: %s" % game_instance_id)
	
	# Перевірка на повторний виклик для тієї ж кімнати
	# Перевіряємо як по шляху, так і по поточній кімнаті MetSys
	var current_room_name = MetSys.get_current_room_name()
	var current_room_path = MetSys.get_full_room_path(current_room_name) if current_room_name != "" else ""
	
	# ВАЖЛИВО: Блокуємо тільки якщо намагаємося завантажити ТУ Ж кімнату, в якій вже знаходимося
	# Але дозволяємо перехід до НОВОЇ кімнати (наприклад, Canyon → DesertRoad)
	if current_room_path == normalized_path:
		# Намагаємося завантажити кімнату, в якій вже знаходимося
		print("⚠️ [Game] load_room() викликано для вже завантаженої кімнати (поточна кімната MetSys): %s" % current_room_name)
		print("🆔 [Game] ID екземпляру: %s" % game_instance_id)
		print("⚠️ [Game] БЛОКУЄМО ПОДВІЙНИЙ ВИКЛИК, щоб запобігти подвійній телепортації!")
		DebugLogger.warning("Game: load_room() викликано для вже завантаженої кімнати: %s" % normalized_path, "Game")
		return  # Блокуємо подвійний виклик
	
	# Якщо це перехід до НОВОЇ кімнати, оновлюємо _last_load_room_path
	_last_load_room_path = normalized_path
	
	# Викликаємо базовий метод.
	# УВАГА: свідомо БЕЗ await — перевірено, що з ним переходи зациклюються
	# (Canyon <-> Village сотнями разів). Зі ScrollingRoomTransitions await і не
	# потрібен: модуль обнуляє game.map, тому базовий load_room() не доходить до
	# `await map.tree_exited` і відпрацьовує синхронно в одному кадрі.
	super.load_room(room_ref)

func reset_map_starting_coords():
	$UI/MapWindow.reset_starting_coords()

## Позиционирует игрока на SavePoint в текущей комнате
func _position_player_at_save_point() -> void:
	# Ищем SavePoint в текущей комнате
	var save_points = get_tree().get_nodes_in_group("save_points")
	if save_points.size() > 0:
		var save_point = save_points[0]
		# spawn_offset завжди існує в SavePoint (має значення за замовчуванням Vector2(0, 0))
		var target_position = save_point.global_position + save_point.spawn_offset
		print("📍 [Game] Позиціонуємо гравця на SavePoint: %s (offset: %s)" % [target_position, save_point.spawn_offset])
		player.global_position = target_position
		MetSys.set_player_position(player.position)
		print("✅ [Game] Гравець позиціоновано на SavePoint: %s" % player.global_position)
		DebugLogger.info("Game: Positioned player at SavePoint for new game: %s" % player.global_position, "Game")
		# НЕ оновлюємо камеру вручну - MetSys обробляє це автоматично через adjust_camera_limits()
	else:
		print("⚠️ [Game] SavePoint не знайдено в кімнаті!")
		DebugLogger.warning("Game: No SavePoint found in starting room", "Game")

var _init_room_called_for_room: String = ""
var _init_room_call_count: int = 0

func init_room():
	_init_room_call_count += 1
	var current_room = MetSys.get_current_room_name()

	print("🆔 [Game] init_room() викликано для екземпляру з ID: %s" % game_instance_id)
	_dump_quest_flags("init_room -> %s" % current_room)
	
	# Захист від повторного виклику для тієї ж кімнати
	# MetSys може емітувати room_loaded кілька разів для тієї ж кімнати - це нормальна поведінка
	if _init_room_called_for_room == current_room:
		# Не виводимо попередження, оскільки це очікувана поведінка MetSys
		# MetSys може емітувати room_loaded кілька разів під час завантаження кімнати
		return
	
	_init_room_called_for_room = current_room
	
	# Скидаємо _last_load_room_path після успішного завантаження нової кімнати
	# Це дозволяє завантажувати ту ж кімнату знову, якщо потрібно (наприклад, при поверненні)
	var current_room_path = MetSys.get_full_room_path(current_room) if current_room != "" else ""
	if current_room_path != "" and _last_load_room_path == current_room_path:
		# Кімната успішно завантажена, скидаємо захист для майбутніх переходів
		_last_load_room_path = ""
		print("🔄 [Game] Скинуто _last_load_room_path після успішного завантаження кімнати: %s" % current_room)
	
	print("✅ [Game] init_room() викликано для кімнати %s (виклик #%d)" % [current_room, _init_room_call_count])
	print("🆔 [Game] ID екземпляру: %s" % game_instance_id)
	print("📍 [Game] Поточна позиція гравця ДО init_room: %s" % player.global_position)
	print("📍 [Game] MetSys.last_player_position: %s" % MetSys.last_player_position)
	DebugLogger.info("Game: ✅ init_room() викликано для кімнати %s (виклик #%d)" % [current_room, _init_room_call_count], "Game")
	DebugLogger.info("Game: Поточна позиція гравця ДО init_room: %s" % player.global_position, "Game")
	DebugLogger.info("Game: MetSys.last_player_position: %s" % MetSys.last_player_position, "Game")
	
	var room_instance = MetSys.get_current_room_instance()
	if is_instance_valid(room_instance):
		room_instance.adjust_camera_limits($Player/Camera2D)
		print("✅ [Game] RoomInstance знайдено: %s" % room_instance.name)
		DebugLogger.info("Game: RoomInstance знайдено: %s" % room_instance.name, "Game")
	else:
		push_warning("Game: No RoomInstance found in current room!")
	
	# ВАЖЛИВО: Чекаємо, поки MetSys модуль переходів завершить позиціонування
	# MetSys використовує RoomTransitions.gd для обробки переходів між кімнатами
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("📍 [Game] Позиція гравця ПІСЛЯ очікування MetSys: %s" % player.global_position)
	DebugLogger.info("Game: Позиція гравця ПІСЛЯ очікування MetSys: %s" % player.global_position, "Game")
	
	# ВАЖЛИВО: НЕ позиціонуємо камеру вручну.
	# room_instance.adjust_camera_limits() задає межі, а сама камера — дочірній
	# вузол гравця, тому слідкує за ним автоматично.
	
	# Перевірка дивної позиції - перевіряємо тільки екстремальні значення
	# Різні сцени мають різні координати, тому не використовуємо жорсткі межі
	var position_is_extreme = player.global_position.y < -5000 or player.global_position.y > 10000 or \
							  player.global_position.x < -5000 or player.global_position.x > 10000
	
	# Перевіряємо відстань до найближчого SavePoint в ПОТОЧНІЙ кімнаті
	# ВАЖЛИВО: get_nodes_in_group() може повернути SavePoint з попередньої сцени, якщо вона ще не вивантажена
	# Тому перевіряємо, чи SavePoint належить до поточної кімнати через MetSys RoomInstance
	var save_points = get_tree().get_nodes_in_group("save_points")
	var current_room_instance = MetSys.get_current_room_instance()
	var valid_save_point = null
	
	# Шукаємо SavePoint, який належить до поточної кімнати
	# ВАЖЛИВО: Використовуємо RoomInstance для перевірки, чи SavePoint належить до поточної кімнати
	var current_scene = get_tree().current_scene if get_tree() else null
	
	for sp in save_points:
		if not is_instance_valid(sp):
			continue
		
		# Перевіряємо, чи SavePoint знаходиться в поточній сцені
		if not sp.is_inside_tree():
			continue
		
		# Перевіряємо, чи SavePoint є частиною поточної сцени
		var sp_scene = sp.get_tree().current_scene if sp.get_tree() else null
		if sp_scene != current_scene:
			continue
		
		# ДОДАТКОВА ПЕРЕВІРКА: Перевіряємо, чи SavePoint належить до поточної кімнати через RoomInstance
		# RoomInstance містить всі об'єкти поточної кімнати
		if is_instance_valid(current_room_instance):
			# Перевіряємо, чи SavePoint є дочірнім вузлом RoomInstance або його нащадком
			var room_node = current_room_instance.get_parent() if current_room_instance.get_parent() else current_room_instance
			if sp.is_ancestor_of(room_node) or room_node.is_ancestor_of(sp) or sp.get_parent() == room_node:
				valid_save_point = sp
				break
			# Альтернативна перевірка: чи SavePoint знаходиться в межах поточної кімнати
			# Якщо RoomInstance має метод для перевірки, використовуємо його
			# Але поки що використовуємо простішу перевірку через current_scene
		
		# Якщо RoomInstance не знайдено, використовуємо перевірку через current_scene
		if not is_instance_valid(current_room_instance):
			if sp_scene == current_scene:
				valid_save_point = sp
				break
	
	# Якщо не знайшли валідний SavePoint через RoomInstance, використовуємо fallback
	# але тільки якщо він знаходиться в поточній сцені І близько до гравця
	if not valid_save_point and save_points.size() > 0:
		var closest_save_point = null
		var closest_distance = INF
		
		for sp in save_points:
			if not is_instance_valid(sp) or not sp.is_inside_tree():
				continue
			var sp_scene = sp.get_tree().current_scene if sp.get_tree() else null
			if sp_scene != current_scene:
				continue
			
			# ДОДАТКОВА ПЕРЕВІРКА: перевіряємо, чи SavePoint не з попередньої кімнати
			# Якщо позиція SavePoint дуже далеко від поточної позиції гравця, це може бути SavePoint з попередньої кімнати
			var distance = player.global_position.distance_to(sp.global_position)
			# ВАЖЛИВО: Якщо SavePoint ближче 3000 пікселів, він може бути валідним для поточної кімнати
			# Зберігаємо найближчий SavePoint
			if distance < 3000 and distance < closest_distance:
				closest_save_point = sp
				closest_distance = distance
		
		if closest_save_point:
			valid_save_point = closest_save_point
			print("✅ [Game] Знайдено найближчий SavePoint в поточній кімнаті на відстані: %.2f пікселів" % closest_distance)
	
	if valid_save_point:
		var distance_to_save_point = player.global_position.distance_to(valid_save_point.global_position)
		
		# Якщо позиція екстремальна АБО гравець дуже далеко від SavePoint (більше 2000 пікселів)
		# то позиціонуємо на SavePoint
		if position_is_extreme or distance_to_save_point > 2000:
			if position_is_extreme:
				print("⚠️ [Game] УВАГА: Екстремальна позиція гравця: %s" % player.global_position)
				DebugLogger.warning("Game: Екстремальна позиція гравця: %s" % player.global_position, "Game")
			else:
				print("⚠️ [Game] УВАГА: Гравець дуже далеко від SavePoint: %.2f пікселів" % distance_to_save_point)
				DebugLogger.warning("Game: Гравець дуже далеко від SavePoint: %.2f пікселів" % distance_to_save_point, "Game")
			
			# Позиціонуємо на SavePoint
			var target_position = valid_save_point.global_position + valid_save_point.spawn_offset
			print("✅ [Game] Виправляємо позицію на SavePoint поточної кімнати: %s (offset: %s)" % [target_position, valid_save_point.spawn_offset])
			player.global_position = target_position
			MetSys.set_player_position(player.position)
			print("✅ [Game] Позиція виправлена: %s" % player.global_position)
			DebugLogger.info("Game: Позиція виправлена на SavePoint: %s" % player.global_position, "Game")
	else:
		if position_is_extreme:
			print("⚠️ [Game] УВАГА: Екстремальна позиція гравця, але SavePoint не знайдено!")
			DebugLogger.warning("Game: Екстремальна позиція гравця, але SavePoint не знайдено: %s" % player.global_position, "Game")
	
	player.on_enter()
	
	# ВАЖЛИВО: При поверненні до Canyon позиціонуємо гравця на SavePoint
	# Але тільки якщо це не автоматичний перехід через MetSys room connections
	if "Canyon" in current_room:
		# Перевіряємо, чи гравець повернувся з Village
		var game = Game.get_singleton()
		if game and game.get_quest_flag("village_left_complete", false):
			# Перевіряємо, чи MetSys вже позиціонував гравця
			# Якщо позиція далеко від SavePoint, позиціонуємо на SavePoint
			var canyon_save_points = get_tree().get_nodes_in_group("save_points")
			if canyon_save_points.size() > 0:
				var save_point = canyon_save_points[0]
				var distance_to_save_point = player.global_position.distance_to(save_point.global_position)
				print("📍 [Game] Відстань до SavePoint: %.2f пікселів" % distance_to_save_point)
				DebugLogger.info("Game: Відстань до SavePoint: %.2f пікселів" % distance_to_save_point, "Game")
				# Якщо гравець далеко від SavePoint (більше 500 пікселів), позиціонуємо на SavePoint
				if distance_to_save_point > 500:
					print("✅ [Game] Гравець далеко від SavePoint, позиціонуємо на SavePoint")
					DebugLogger.info("Game: Гравець далеко від SavePoint, позиціонуємо на SavePoint", "Game")
					_position_player_at_save_point()
					# Оновлюємо MetSys позицію
					MetSys.set_player_position(player.position)
					print("📍 [Game] Позиція гравця ПІСЛЯ позиціонування на SavePoint: %s" % player.global_position)
			else:
				print("⚠️ [Game] SavePoint не знайдено в кімнаті %s" % current_room)
				DebugLogger.warning("Game: SavePoint не знайдено в кімнаті %s" % current_room, "Game")
	
	# Initializes MetSys.get_current_coords(), so you can use it from the beginning.
	if MetSys.last_player_position.x == Vector2i.MAX.x:
		MetSys.set_player_position(player.position)
		print("📍 [Game] Встановлено MetSys.last_player_position: %s" % player.position)
		DebugLogger.info("Game: Встановлено MetSys.last_player_position: %s" % player.position, "Game")
	
	print("📍 [Game] Позиція гравця ПІСЛЯ init_room: %s" % player.global_position)
	DebugLogger.info("Game: Позиція гравця ПІСЛЯ init_room: %s" % player.global_position, "Game")
	
	# ВАЖЛИВО: НЕ позиціонуємо камеру вручну — вона є дочірнім вузлом гравця
	# і слідкує за ним автоматично.

# ============================================================================
# Флаги квестов, диалогов, катсцен, боссов и локаций
# ============================================================================

signal quest_flag_changed(quest_id: String, value: Variant)
signal quest_completed(quest_id: String)
signal objective_updated(text: String)

var current_objective: String = ""

## Встановлює поточну ціль (відображається в UI)
func set_objective(text: String) -> void:
	current_objective = text
	objective_updated.emit(text)
	DebugLogger.info("Game: Нова ціль: %s" % text, "Game")

## Отримує поточну ціль
func get_objective() -> String:
	return current_objective

## Получает флаги квестов
func get_quest_flags() -> Dictionary:
	return quest_flags.duplicate(true)

## Устанавливает флаги квестов
func set_quest_flags(flags: Dictionary) -> void:
	quest_flags = flags.duplicate(true)
	# Эмитим событие для каждого измененного флага
	for quest_id in flags:
		quest_flag_changed.emit(quest_id, flags[quest_id])
		if flags[quest_id] == true:
			quest_completed.emit(quest_id)

## Устанавливает флаг квеста
func set_quest_flag(quest_id: String, value: Variant) -> void:
	var old_value = quest_flags.get(quest_id, false)
	quest_flags[quest_id] = value
	print("🚩 [FLAGS] SET %s = %s | Game=%s | всього=%d" % [quest_id, value, game_instance_id, quest_flags.size()])
	quest_flag_changed.emit(quest_id, value)
	# Если квест завершен (value == true), эмитим событие завершения
	if value == true and old_value != true:
		quest_completed.emit(quest_id)

## Получает флаг квеста
func get_quest_flag(quest_id: String, default: Variant = false) -> Variant:
	return quest_flags.get(quest_id, default)

## ТИМЧАСОВО: діагностика. Друкує всі виставлені квестові прапорці.
## Разом з game_instance_id видно, чи не читає сцена інший екземпляр Game.
func _dump_quest_flags(where: String) -> void:
	var active: Array[String] = []
	for k in quest_flags:
		if quest_flags[k] == true:
			active.append(String(k))
	active.sort()
	print("🚩 [FLAGS] %s | Game=%s | всього=%d | виставлено: %s" % [
		where, game_instance_id, quest_flags.size(),
		", ".join(active) if active.size() > 0 else "(жодного)"
	])

## Получает флаги катсцен
func get_cutscene_flags() -> Dictionary:
	return cutscene_flags.duplicate(true)

## Устанавливает флаги катсцен
func set_cutscene_flags(flags: Dictionary) -> void:
	cutscene_flags = flags.duplicate(true)

## Устанавливает флаг катсцены
func set_cutscene_flag(cutscene_id: String, value: Variant) -> void:
	cutscene_flags[cutscene_id] = value

## Получает флаг катсцены
func get_cutscene_flag(cutscene_id: String, default: Variant = false) -> Variant:
	return cutscene_flags.get(cutscene_id, default)

## Получает флаги боссов
func get_boss_flags() -> Dictionary:
	return boss_flags.duplicate(true)

## Устанавливает флаги боссов
func set_boss_flags(flags: Dictionary) -> void:
	boss_flags = flags.duplicate(true)

## Устанавливает флаг босса
func set_boss_flag(boss_id: String, value: Variant) -> void:
	boss_flags[boss_id] = value

## Получает флаг босса
func get_boss_flag(boss_id: String, default: Variant = false) -> Variant:
	return boss_flags.get(boss_id, default)

## Получает флаги локаций
func get_location_flags() -> Dictionary:
	return location_flags.duplicate(true)

## Устанавливает флаги локаций
func set_location_flags(flags: Dictionary) -> void:
	location_flags = flags.duplicate(true)

## Устанавливает флаг локации
func set_location_flag(location_id: String, value: Variant) -> void:
	location_flags[location_id] = value

## Получает флаг локации
func get_location_flag(location_id: String, default: Variant = false) -> Variant:
	return location_flags.get(location_id, default)

## Сохраняет флаги в SaveSystem
func _save_game_flags_to_save_system() -> void:
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			var save_system = service_locator.get_save_system()
			if save_system and save_system.has_method("save_player_data"):
				# SaveSystem автоматически получит флаги через методы get_*_flags()
				save_system.save_player_data()

## Сохраняет полные данные игры в SaveSystem
func _save_full_game_data_to_save_system() -> bool:
	# Раніше тут стояв Engine.has_singleton("ServiceLocator") — для autoload це
	# завжди false, тож інвентар і прапорці НІКОЛИ не зберігались разом зі слотом.
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator == null or not service_locator.has_method("get_save_system"):
		return false
	var save_system = service_locator.get_save_system()
	if save_system == null or not save_system.has_method("save_player_data"):
		return false

	# SaveSystem.save_player_data() читает позицию из game_manager.player_state.player_position,
	# поэтому нужно обновить её перед сохранением
	if player and is_instance_valid(player):
		var player_state_manager = service_locator.get_player_state_manager()
		if player_state_manager and player_state_manager.has_method("set_player_position"):
			# ВАЖНО: Используем global_position, а не position (локальная позиция)!
			player_state_manager.set_player_position(player.global_position)
			DebugLogger.info("Game: Saved player global position: %s" % player.global_position, "Game")

		# Обновляем текущую сцену/комнату
		if "player_data" in save_system:
			var current_room = MetSys.get_current_room_name()
			if not current_room.is_empty():
				save_system.player_data["current_scene"] = current_room

	# Сохраняем все данные (инвентарь, позиция, флаги и т.д.) у файл поточного слота
	return bool(save_system.save_player_data())

## Загружает полные данные игры из SaveSystem (инвентарь, позиция, флаги и т.д.)
func _load_full_game_data_from_save_system() -> void:
	# FIX: В Godot 4.5 autoload доступен напрямую, а не через Engine.get_singleton()
	var save_system = ServiceLocator.get_save_system() if ServiceLocator else null

	if save_system and save_system.has_method("load_player_data"):
		# SaveSystem автоматически загрузит все данные:
		# - Инвентарь через GameManager
		# - Позицію игрока через GameManager
		# - Флаги через методы set_*_flags()
		save_system.load_player_data()

		# После загрузки данных из SaveSystem, загружаем позицию игрока
		# если она была сохранена
		if "player_data" in save_system:
			var _player_data = save_system.player_data  # Префикс _ - переменная не используется

			# Позиция игрока уже восстановлена через MetSys save_manager.retrieve_game()
			# SaveSystem используется только для инвентаря и флагов
			# (позиция хранится в MetSys, не в SaveSystem)
