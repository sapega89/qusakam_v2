# This is the main script of the game. It manages the current map and some other stuff.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"
class_name Game

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")
const MouseCursorScene = preload("res://SampleProject/Scenes/UI/mouse_cursor.tscn")
const RoomPreloader := preload("res://SampleProject/Scripts/Gameplay/RoomPreloader.gd")
const FADE_ROOM_TRANSITIONS := "res://SampleProject/Scripts/Gameplay/FadeRoomTransitions.gd"

## Екран чорний, кімната завантажена — стара зараз зміниться на нову (D434).
signal room_swapping
## Зміна кімнати закінчилась: екран знову світлий (D434). Гравця вже поставлено.
signal room_change_finished

## Фонове завантаження кімнат (RoomPreloader.gd).
var room_preloader: RoomPreloader
## Від початку затемнення до кінця появи (D434). Нова зміна кімнати чекає, поки скінчиться ця.
var room_changing: bool = false

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
## Що сталося в кімнатах: {імʼя кімнати MetSys: {ключ: значення}} (room_state_plan, D152).
## Кімнату передають явно: стан пишуть і під час вивантаження, коли MetSys уже в новій.
var room_state: Dictionary = {}
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

	# ВАЖЛИВО: Встановлюємо мета-значення singleton ПЕРЕД викликом get_singleton()
	# Це потрібно для того, щоб get_singleton() міг знайти екземпляр
	get_script().set_meta(&"singleton", self)
	
	# Перевірка, чи це той самий екземпляр
	var singleton = Game.get_singleton()
	if singleton and singleton != self:
		push_warning("Game: another Game instance is the singleton (%s, this one %s)" % [singleton.game_instance_id, game_instance_id])

	# singleton meta можно оставить, но это тоже выполнится много раз — ок
	get_script().set_meta(&"singleton", self)

	# ВАЖНО: bootstrap только один раз
	if _bootstrapped:
		DebugLogger.warning("Game: ⚠️ _ready() вже викликано (_bootstrapped=true), пропускаємо ініціалізацію", "Game")
		DebugLogger.warning("Game: ⚠️ ЦЕ МОЖЕ БУТИ ПРИЧИНОЮ ПОДВІЙНОЇ ТЕЛЕПОРТАЦІЇ - гра перестворюється!", "Game")
		return
	_bootstrapped = true
	DebugLogger.info("Game: ✅ _ready() викликано вперше, ініціалізуємо гру", "Game")

	# D417: курсор схований у грі, Alt показує його; меню й модалки — завжди з курсором.
	add_child(MouseCursorScene.instantiate())

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


## Game Menu відкривається дією game_menu — Esc або Start (D156). Не ui_cancel: на ньому кнопка B,
## а B у грі — «назад», не меню.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"game_menu"):
		# Esc — це й ui_cancel модалки: поки модалка відкрита, вона сама його обробить.
		if ServiceLocator.get_ui_manager().get_modal_layer().active_modal != null:
			return
		var menu_manager: MenuManager = ServiceLocator.get_menu_manager()
		# Меню вже відкрите — закриття обробить game_menu.gd.
		if menu_manager.is_menu_open():
			return
		menu_manager.toggle_game_menu()
		get_viewport().set_input_as_handled()

func _normalize_room_ref_to_scene_ref(room_ref: String) -> String:
	var ref := room_ref.strip_edges()
	if ref.is_empty():
		return ""

	# Full scene path
	if ref.begins_with("res://") and ref.ends_with(".tscn"):
		return ref

	# Already a UID ref — this function returns these itself for ":xxxx" names,
	# and load_room() normalizes its argument a second time.
	if ref.begins_with("uid://"):
		return ref if ResourceLoader.exists(ref) else ""

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
	return SaveSystem.get_slot_path(SaveSystem.current_slot)

func _initialize_save_and_room() -> void:
	if _save_room_initialized:
		DebugLogger.warning("Game: ⚠️ _initialize_save_and_room() вже викликано, пропускаємо", "Game")
		return
	_save_room_initialized = true
	DebugLogger.info("Game: ✅ _initialize_save_and_room() викликано вперше", "Game")
	# Check if this is a new game (don't load save) or loading from save
	var start_new_game = get_tree().get_meta("start_new_game", false)
	# Clear the meta after reading it
	if get_tree().has_meta("start_new_game"):
		get_tree().remove_meta("start_new_game")
	# Миттєвий стан минулої гри живе в автолоадах — нова сесія (нова гра чи завантаження) починає з чистого.
	ServiceLocator.get_companion_manager().reset()
	ServiceLocator.get_skill_manager().clear_cooldowns()
	# B79: рівень, досвід, стан героя й речі — теж з чистого; сейв нижче відновить свої (PlayerDataModule, InventoryModule).
	ServiceLocator.get_xp_manager().reset()
	ServiceLocator.get_game_manager().get_node(^"PlayerStateManager").reset_player_state()
	ServiceLocator.get_character_manager().initialize_characters()  # ростер бере чистий стан і синхронізує клас (B55)
	ServiceLocator.get_inventory_manager().clear()

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

		# Restore MetSys state (map, items); позицію гравця ставимо після load_room() нижче (B82)
		save_manager.retrieve_game(self)
		loaded_from_save = true
		
		# КРИТИЧНО: Загружаем quest flags ДО вызова load_room()
		# Это гарантирует что quest flags будут доступны когда сцена загрузится
		_load_full_game_data_from_save_system()		

		# Імʼя кімнати MetSys (":uid") — єдине джерело. Окремий
		# current_room_scene_path склеював папку з цим імʼям у неіснуючий шлях,
		# і завантаження мовчки починалось з Canyon.
		starting_map = String(save_manager.get_value("current_room"))
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
		room_state.clear()

	# Initialize room when it changes.
	if not room_loaded.is_connected(init_room):
		room_loaded.connect(init_room, CONNECT_DEFERRED)
	
	var scene_path := _normalize_room_ref_to_scene_ref(starting_map)
	if scene_path.is_empty():
		push_error("Cannot resolve starting_map to scene ref: %s" % starting_map)
		return

	# Сусідів і цілі дверей вантажить у фоні з першої ж кімнати (performance_plan, slice 2–3).
	room_preloader = RoomPreloader.new(self)
	modules.append(room_preloader)
	# Без старої мапи load_room() синхронний (перша кімната; з меню — під чорним екраном, D434).
	load_room(scene_path)


	# Нова гра — гравець на мітці Arrival стартової кімнати. Завантаження — там, де він зберігся (B82):
	# позицію пише _save_full_game_data_to_save_system(), читає PlayerDataModule. Кімната вже додана
	# (load_room() без старої мапи синхронний), тож ставимо одразу, до першого кроку фізики —
	# тригери кімнати бачать гравця на збереженому місці, а не в дефолтній точці Game.tscn (B80).
	if loaded_from_save:
		place_player(ServiceLocator.get_player_state_manager().get_player_position())
	elif start_new_game:
		await get_tree().process_frame  # Ждём загрузки комнаты
		_position_player_at_start()

	# Перехід пішки крізь край кімнати — через затемнення (D434), як двері й телепорти: усі йдуть через load_room().
	add_module(FADE_ROOM_TRANSITIONS)

	# Reset position tracking (feature specific to this project).
	await get_tree().physics_frame
	reset_map_starting_coords.call_deferred()

	# Make sure minimap is at correct position (required for themes to work correctly).
	%Minimap.set_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)

func _exit_tree() -> void:
	if (Game as Script).get_meta(&"singleton", null) == self:
		(Game as Script).remove_meta(&"singleton")

# Returns this node from anywhere.
static func get_singleton() -> Game:
	# null поза грою (головне меню). Мета знімається в _exit_tree(), тож
	# видаленого Game тут не буває.
	return (Game as Script).get_meta(&"singleton", null) as Game

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
	var room_name: String = MetSys.get_current_room_name()
	save_manager.set_value("current_room", room_name)
	save_manager.set_value("abilities", player.abilities)
	
	save_manager.store_game(self)
	# Відкриті клітинки карти, маркери тощо. SaveManager.save_as_text() додає їх
	# сам, але ми пишемо файл власноруч — без цього карта після завантаження
	# була знову порожня (0% explored).
	save_manager.data.merge(MetSys.get_save_data())
	# SaveManager.save_as_text() нічого не повертає — пишемо самі, щоб знати результат.
	var save_path := _get_current_save_path()
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	if save_file == null:
		push_error("Game: failed to write save %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	save_file.store_string(var_to_str(save_manager.data))
	save_file.close()

	# Картка слота (Figma 150:1278): лише реальні дані (Q3); локація — зона журналу (D133).
	var meta := {
		"timestamp": Time.get_datetime_string_from_system(),
		"location": ServiceLocator.get_game_flow().location_title(map.scene_file_path),
		"slot": SaveSystem.current_slot,
		"level": ServiceLocator.get_xp_manager().get_level(),
	}
	var lead: GameCharacter = ServiceLocator.get_character_manager().get_active_character()
	if lead.name != "":
		meta["character_name"] = lead.name
	SaveSystem.set_slot_metadata(SaveSystem.current_slot, meta)

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
	var service_locator = ServiceLocator
	if not service_locator: return
	
	var player_state_manager = service_locator.get_player_state_manager()
	if player_state_manager:
		player_state_manager.set_player_position(player.global_position)
	

var _load_room_call_count: int = 0
var _last_load_room_path: String = ""

## Єдиний шлях зміни кімнати: прохід крізь край (FadeRoomTransitions), двері й телепорти (teleport_to_room).
## D434: екран гасне, кімната довантажується (зазвичай уже готова у фоні, RoomPreloader), стара міняється на нову
## під чорним, і екран світлішає. Гра на цей час на паузі, але кадри йдуть — нічого не зависає.
## Повертається одразу після заміни, коли екран ще чорний: викликач ставить гравця, і лише тоді його видно.
## Кінець появи — сигнал room_change_finished.
func load_room(room_ref: String) -> void:
	_load_room_call_count += 1
	var normalized_path = _normalize_room_ref_to_scene_ref(room_ref)

	# Перевірка на повторний виклик для тієї ж кімнати
	# Перевіряємо як по шляху, так і по поточній кімнаті MetSys
	var current_room_name = MetSys.get_current_room_name()
	var current_room_path = MetSys.get_full_room_path(current_room_name) if current_room_name != "" else ""

	# ВАЖЛИВО: Блокуємо тільки якщо намагаємося завантажити ТУ Ж кімнату, в якій вже знаходимося
	# Але дозволяємо перехід до НОВОЇ кімнати (наприклад, Canyon → DesertRoad)
	if current_room_path == normalized_path:
		DebugLogger.warning("Game: load_room() викликано для вже завантаженої кімнати: %s" % normalized_path, "Game")
		return  # Блокуємо подвійний виклик

	# Якщо це перехід до НОВОЇ кімнати, оновлюємо _last_load_room_path
	_last_load_room_path = normalized_path

	var path: String = RoomPreloader.scene_path(normalized_path)
	if map == null:
		# Перша кімната гри. Без старої мапи базовий load_room() синхронний.
		super.load_room(path)
		if ScreenFade.is_on(self):
			room_changing = true
			_lift_fade()
		return

	while room_changing:
		await room_change_finished
	room_changing = true
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	room_preloader.request(path)
	# Кат-сцена могла вже затемнити екран сама (Canyon, MayorHall) — тоді гасити нічого.
	if not ScreenFade.is_black(self):
		await ScreenFade.to_black(self, UITokens.ROOM_FADE_TIME)
	# Чорне тримається лише доки кімната ще вантажиться.
	await room_preloader.wait(path)

	room_swapping.emit()
	# Стару кімнату відʼєднуємо до заміни: тоді базовий load_room() не чекає її tree_exited і відпрацьовує
	# синхронно, а MetSys.current_room одразу стає новою.
	var old_map := map
	var old_room: Node = MetSys.get_current_room_instance()
	old_room.get_parent().remove_child(old_room)
	old_room.queue_free()
	map = null
	super.load_room(path)
	old_map.queue_free()
	tree.paused = was_paused
	_lift_fade()


## Поява після заміни кімнати. Без await у load_room(): викликач ставить гравця в тому ж кадрі, до першого світлого.
func _lift_fade() -> void:
	await ScreenFade.from_black(self, UITokens.ROOM_FADE_TIME)
	room_changing = false
	room_change_finished.emit()


## Кат-сцена, що закінчиться телепортом, просить цільову кімнату заздалегідь (performance_plan, slice 3).
func preload_room(room_path: String) -> void:
	room_preloader.request(RoomPreloader.scene_path(room_path))

func reset_map_starting_coords():
	$UI/MapWindow.reset_starting_coords()

## Телепорт у кімнату, не повʼязану з поточною (двері, кат-сцена, а не прохід по мапі): затемнення, заміна кімнати,
## герой на вузлі [param arrival], поява (D434). Повертається, коли екран знову світлий.
## Кат-сцена, що сама затемнила екран, не чекає: її кімнату звільняє цей самий виклик, а світло повертає load_room().
func teleport_to_room(room_path: String, arrival: NodePath) -> void:
	await load_room(room_path)
	var target: Node2D = map.get_node(arrival)
	place_player(target.global_position)
	if room_changing:
		await room_change_finished

## Нова гра: гравець на мітці Arrival стартової кімнати. Точки збереження бувають
## не в кожній кімнаті (до DesertRoad їх немає), тож старт від них не залежить.
func _position_player_at_start() -> void:
	var arrival: Node2D = map.get_node(^"Arrival")
	place_player(arrival.global_position)
	DebugLogger.info("Game: Positioned player at Arrival for new game: %s" % player.global_position, "Game")

var _init_room_called_for_room: String = ""
var _init_room_call_count: int = 0

func init_room():
	_init_room_call_count += 1
	var current_room = MetSys.get_current_room_name()

	
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
	
	DebugLogger.info("Game: ✅ init_room() викликано для кімнати %s (виклик #%d)" % [current_room, _init_room_call_count], "Game")
	DebugLogger.info("Game: Поточна позиція гравця ДО init_room: %s" % player.global_position, "Game")
	DebugLogger.info("Game: MetSys.last_player_position: %s" % MetSys.last_player_position, "Game")
	
	var room_instance = MetSys.get_current_room_instance()
	if is_instance_valid(room_instance):
		room_instance.adjust_camera_limits($Player/Camera2D)
		_raise_camera_bottom($Player/Camera2D)
		DebugLogger.info("Game: RoomInstance знайдено: %s" % room_instance.name, "Game")
	else:
		push_warning("Game: No RoomInstance found in current room!")
	
	# ВАЖЛИВО: Чекаємо, поки MetSys модуль переходів завершить позиціонування
	# MetSys використовує RoomTransitions.gd для обробки переходів між кімнатами
	await get_tree().process_frame
	await get_tree().process_frame
	
	DebugLogger.info("Game: Позиція гравця ПІСЛЯ очікування MetSys: %s" % player.global_position, "Game")
	
	# ВАЖЛИВО: НЕ позиціонуємо камеру вручну.
	# room_instance.adjust_camera_limits() задає межі, а сама камера — дочірній
	# вузол гравця, тому слідкує за ним автоматично.
	
	# Позицію задають MetSys (переходи), _initialize_save_and_room() (завантаження, B82) і
	# _position_player_at_start() (нова гра). Евристики «гравець задалеко
	# від SavePoint — переставити» прибрано: вони ховали помилки позиціонування (D131).
	player.on_enter()

	# Initializes MetSys.get_current_coords(), so you can use it from the beginning.
	if MetSys.last_player_position.x == Vector2i.MAX.x:
		MetSys.set_player_position(player.position)
		DebugLogger.info("Game: Встановлено MetSys.last_player_position: %s" % player.position, "Game")
	
	DebugLogger.info("Game: Позиція гравця ПІСЛЯ init_room: %s" % player.global_position, "Game")
	
	# ВАЖЛИВО: НЕ позиціонуємо камеру вручну — вона є дочірнім вузлом гравця
	# і слідкує за ним автоматично.
	EventBus.room_entered.emit(map.scene_file_path.get_file().get_basename())

## D483: надворі підлога стоїть на ~85 % висоти кадру — нижня межа камери піднімається до підлоги + 15 % кадру,
## верх кадру тоді виходить за верхній край кімнати, де його закривають шари задника. Підлогу кімнати задає
## metadata/camera_floor_y у її .tscn; кімнати без неї (усередині) тримають межі клітинок MetSys.
const CAMERA_GROUND_SHARE := 0.15

func _raise_camera_bottom(camera: Camera2D) -> void:
	if not map.has_meta(&"camera_floor_y"):
		return
	var view_height: float = get_viewport().get_visible_rect().size.y / camera.zoom.y
	camera.limit_bottom = roundi(float(map.get_meta(&"camera_floor_y")) + view_height * CAMERA_GROUND_SHARE)
	camera.limit_top = mini(camera.limit_top, camera.limit_bottom - ceili(view_height))

# ============================================================================
# Флаги квестов, диалогов, катсцен, боссов и локаций
# ============================================================================

signal quest_flag_changed(quest_id: String, value: Variant)
signal quest_completed(quest_id: String)
signal objective_updated(text: String)

var current_objective: String = ""
## Куди йти (BACKLOG 28, D-28h): імʼя мітки ObjectiveTargets/<id> у кімнаті. Та сама назва стоїть у кожній кімнаті
## шляху (у селі «canyon_bridge» — західний край, у каньйоні — сам міст), тож стрілка на плашці веде й крізь кімнати.
## Порожньо — стрілки немає (бій, розмова, кат-сцена).
var objective_target: StringName = &""

## Встановлює поточну ціль (відображається в UI); [param target] — мітка, на яку вказує стрілка плашки.
func set_objective(text: String, target: StringName = &"") -> void:
	current_objective = text
	objective_target = target
	objective_updated.emit(text)
	DebugLogger.info("Game: Нова ціль: %s" % text, "Game")

## Отримує поточну ціль
func get_objective() -> String:
	return current_objective

## Мітка цілі в поточній кімнаті; null — у цієї цілі немає мітки тут.
func objective_marker() -> Node2D:
	if objective_target == &"" or map == null:
		return null
	return map.get_node_or_null(NodePath("ObjectiveTargets/%s" % objective_target)) as Node2D

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
	DebugLogger.verbose("Game: quest flag %s = %s" % [quest_id, value], "Game")
	quest_flag_changed.emit(quest_id, value)
	# Если квест завершен (value == true), эмитим событие завершения
	if value == true and old_value != true:
		quest_completed.emit(quest_id)

## Получает флаг квеста
func get_quest_flag(quest_id: String, default: Variant = false) -> Variant:
	return quest_flags.get(quest_id, default)

func get_room_state(room: String, key: String, default: Variant = null) -> Variant:
	return room_state.get(room, {}).get(key, default)

func set_room_state(room: String, key: String, value: Variant) -> void:
	room_state.get_or_add(room, {})[key] = value

func get_room_states() -> Dictionary:
	return room_state.duplicate(true)

func set_room_states(states: Dictionary) -> void:
	room_state = states.duplicate(true)

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

## Інвентар, прапорці й позиція гравця — у файл поточного слота (SaveSystem).
func _save_full_game_data_to_save_system() -> bool:
	ServiceLocator.get_player_state_manager().set_player_position(player.global_position)
	return bool(SaveSystem.save_player_data())


## Завантажує інвентар, прапорці й позицію гравця зі слота (позицію застосовує _initialize_save_and_room(), B82).
func _load_full_game_data_from_save_system() -> void:
	SaveSystem.load_player_data()
