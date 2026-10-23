extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## Кімнати, куди можна піти з поточної, вантажаться у фоні (performance_plan, slice 2 і 3): сусіди за картою MetSys,
## цілі дверей кімнати і те, що попросила кат-сцена (preload). Готова сцена тримається тут, тож load() у
## MetSysGame.load_room() бере її з кешу, а не компілює скрипти й читає текстури посеред кадру.
## Тримаємо поточну кімнату й ті, куди з неї можна піти; решта відпускається при кожній зміні кімнати.

## Шлях res:// → готова PackedScene.
var held: Dictionary = {}
## Шляхи, чиє фонове завантаження ще йде.
var _pending: Dictionary = {}
## Шляхи, які тримаються до кінця гри, а не до зміни кімнати (SceneWarmer.gd, slice 5).
var pinned: Dictionary = {}


func _initialize() -> void:
	game.room_loaded.connect(_on_room_loaded)
	game.get_tree().process_frame.connect(_collect)


## Будь-яке посилання на кімнату ("Village.tscn", ":uid", uid://, res://) → шлях res://, яким кешує ResourceLoader.
static func scene_path(room_ref: String) -> String:
	if room_ref.begins_with(":"):
		room_ref = "uid://" + room_ref.substr(1)
	if room_ref.begins_with("uid://"):
		return ResourceUID.get_id_path(ResourceUID.text_to_id(room_ref))
	if room_ref.begins_with("res://"):
		return room_ref
	return MetSys.get_full_room_path(room_ref)


## Почати фонове завантаження кімнати, якщо вона ще не тримається й не вантажиться.
func request(path: String) -> void:
	if held.has(path) or _pending.has(path):
		return
	if ResourceLoader.has_cached(path):
		held[path] = load(path)
		return
	var err := ResourceLoader.load_threaded_request(path)
	assert(err == OK, "RoomPreloader: load_threaded_request %s → %s" % [path, error_string(err)])
	_pending[path] = true


## Дочекатися кімнати, попрошеної через request(): кадри йдуть далі, гра не стоїть.
func wait(path: String) -> PackedScene:
	while _pending.has(path):
		await game.get_tree().process_frame
		_collect()
	return held[path]


## Завантажити у фоні й тримати до кінця гри — не лише кімнату, будь-який ресурс (slice 5).
func pin(path: String) -> void:
	pinned[path] = true
	request(path)


## Чи йде ще якесь фонове завантаження (тести чекають, поки стихне, перш ніж вийти).
func busy() -> bool:
	return not _pending.is_empty()


func is_held(path: String) -> bool:
	return held.has(path)


## Готові фонові завантаження переходять у held.
func _collect() -> void:
	for path: String in _pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_pending.erase(path)
		assert(status == ResourceLoader.THREAD_LOAD_LOADED, "RoomPreloader: failed to load %s (%d)" % [path, status])
		held[path] = ResourceLoader.load_threaded_get(path)


func _on_room_loaded() -> void:
	var room := MetSys.get_current_room_instance()
	var wanted: Array[String] = [game.map.scene_file_path]
	for room_name: String in room.get_neighbor_rooms():
		wanted.append(scene_path(room_name))
	for node: Node in game.map.find_children("*", "Area2D"):
		if node is RoomDoor:
			wanted.append(scene_path((node as RoomDoor).target_room))
	for path: String in held.keys():
		if not path in wanted and not pinned.has(path):
			held.erase(path)
	for path: String in wanted:
		request(path)
