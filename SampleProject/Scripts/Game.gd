# This is the main script of the game. It manages the current map and some other stuff.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"
class_name Game

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")
const SAVE_PATH = "user://example_save_data.sav"

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

func _ready() -> void:
	push_warning("GAME_READY id=%s stack:\n%s" % [get_instance_id(), str(get_stack())])

	print("🎮 Game: _ready() started")

	# singleton meta можно оставить, но это тоже выполнится много раз — ок
	get_script().set_meta(&"singleton", self)

	# ВАЖНО: bootstrap только один раз
	if _bootstrapped:
		print("🎮 Game: already bootstrapped, skipping init")
		return
	_bootstrapped = true

	# Make sure MetSys is in initial state (ТОЛЬКО НА НОВЫЙ ЗАПУСК ИЗ МЕНЮ)
	MetSys.reset_state()

	var player_node = $Player
	if player_node:
		set_player(player_node)
		player_node.process_mode = Node.PROCESS_MODE_INHERIT
		player_node.visible = true
	else:
		push_error("🎮 Game: Player node NOT FOUND!")

	call_deferred("_initialize_save_and_room")
	print("🎮 Game: _ready() finished")


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

func _initialize_save_and_room() -> void:
	if _save_room_initialized:
		return
	_save_room_initialized = true
	# Check if this is a new game (don't load save) or loading from save
	var start_new_game = get_tree().get_meta("start_new_game", false)
	# Clear the meta after reading it
	if get_tree().has_meta("start_new_game"):
		get_tree().remove_meta("start_new_game")

	# Проверяем, есть ли указанный путь к сохранению (из меню загрузки)
	var save_file_path = SAVE_PATH
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

	await load_room(scene_path)


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
	add_module("RoomTransitions.gd")
	# You can enable alternate transition effect by using this module instead.
	#add_module("ScrollingRoomTransitions.gd")

	# Reset position tracking (feature specific to this project).
	await get_tree().physics_frame
	reset_map_starting_coords.call_deferred()

	# Make sure minimap is at correct position (required for themes to work correctly).
	%Minimap.set_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)

# Returns this node from anywhere.
static func get_singleton() -> Game:
	return (Game as Script).get_meta(&"singleton") as Game

# Unified Save/Load Coordinator
func save_game():
	"""Main entry point for saving the game state across all systems."""
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
	save_manager.save_as_text(SAVE_PATH)
	
	# 2. SaveSystem Sync (Inventory, Flags, Quest Progress)
	# Update player state before full data save
	_sync_player_state_to_save_system()
	_save_full_game_data_to_save_system()
	
	DebugLogger.info("✅ Game: Unified save completed successfully.", "Game")

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

func reset_map_starting_coords():
	$UI/MapWindow.reset_starting_coords()

## Позиционирует игрока на SavePoint в текущей комнате
func _position_player_at_save_point() -> void:
	# Ищем SavePoint в текущей комнате
	var save_points = get_tree().get_nodes_in_group("save_points")
	if save_points.size() > 0:
		var save_point = save_points[0]
		player.global_position = save_point.position
		MetSys.set_player_position(player.position)
		DebugLogger.info("Game: Positioned player at SavePoint for new game: %s" % player.global_position, "Game")
	else:
		DebugLogger.warning("Game: No SavePoint found in starting room", "Game")

func init_room():
	var room_instance = MetSys.get_current_room_instance()
	if is_instance_valid(room_instance):
		room_instance.adjust_camera_limits($Player/Camera2D)
	else:
		push_warning("Game: No RoomInstance found in current room!")
		
	player.on_enter()

	# Initializes MetSys.get_current_coords(), so you can use it from the beginning.
	if MetSys.last_player_position.x == Vector2i.MAX.x:
		MetSys.set_player_position(player.position)

# ============================================================================
# Флаги квестов, диалогов, катсцен, боссов и локаций
# ============================================================================

## Получает флаги квестов
func get_quest_flags() -> Dictionary:
	return quest_flags.duplicate(true)

## Устанавливает флаги квестов
func set_quest_flags(flags: Dictionary) -> void:
	quest_flags = flags.duplicate(true)

## Устанавливает флаг квеста
func set_quest_flag(quest_id: String, value: Variant) -> void:
	quest_flags[quest_id] = value

## Получает флаг квеста
func get_quest_flag(quest_id: String, default: Variant = false) -> Variant:
	return quest_flags.get(quest_id, default)

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
func _save_full_game_data_to_save_system() -> void:
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			var save_system = service_locator.get_save_system()
			if save_system and save_system.has_method("save_player_data"):
				# FIX: Сохраняем текущую позицию игрока через PlayerStateManager
				# SaveSystem.save_player_data() читает позицию из game_manager.player_state.player_position,
				# поэтому нужно обновить её перед сохранением
				if player and is_instance_valid(player):
					# Получаем PlayerStateManager
					var player_state_manager = service_locator.get_player_state_manager()
					if player_state_manager and player_state_manager.has_method("set_player_position"):
						# ВАЖНО: Используем global_position, а не position (локальная позиция)!
						player_state_manager.set_player_position(player.global_position)
						DebugLogger.info("Game: Saved player global position: %s" % player.global_position, "Game")

					# Обновляем текущую сцену/комнату
					if save_system.has("player_data"):
						var current_room = MetSys.get_current_room_name()
						if not current_room.is_empty():
							save_system.player_data.current_scene = current_room

				# Сохраняем все данные (инвентарь, позиция, флаги и т.д.)
				# SaveSystem автоматически определит название локации при сохранении
				save_system.save_player_data()

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
