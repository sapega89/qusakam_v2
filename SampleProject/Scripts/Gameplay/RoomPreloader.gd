extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## Кімнати, куди можна піти з поточної, вантажаться у фоні (performance_plan, slice 2 і 3): сусіди за картою MetSys,
## цілі дверей кімнати і те, що попросила кат-сцена (preload). Готова сцена тримається тут, тож load() у
## MetSysGame.load_room() бере її з кешу, а не компілює скрипти й читає текстури посеред кадру.
## Тримаємо поточну кімнату й ті, куди з неї можна піти; решта відпускається при кожній зміні кімнати.

## Шлях res:// → готова PackedScene.
var held: Dictionary = {}
## Шляхи, чиє фонове завантаження ще йде або чекає черги.
var _pending: Dictionary = {}
## Черга кімнат: вантажиться одна за раз (_loading). M7: дві нові кімнати, що вперше разом компілювали ті самі сцени
## (двері лабораторії → коридор алхіміка й дренаж), роняли гру (signal 11 у verify_memory) — як закріплені нижче.
var _queue: Array[String] = []
var _loading: String = ""
## Шляхи, які тримаються до кінця гри, а не до зміни кімнати (SceneWarmer.gd, slice 5).
var pinned: Dictionary = {}
## Закріплені шляхи, що ще чекають своєї черги. Вони йдуть по одному й лише коли кімнати не вантажаться:
## два потоки, що разом компілюють ті самі скрипти (DefaultEnemy.gd у ворогах і кімнатах, HealingPalm.tscn у
## Village.gd), давали «Could not resolve class» і «Could not preload».
var _pin_queue: Array[String] = []


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
	_pending[path] = true
	_queue.append(path)
	_start_next()


func _start_next() -> void:
	if _loading != "" or _queue.is_empty():
		return
	_loading = _queue.pop_front()
	var err := ResourceLoader.load_threaded_request(_loading)
	assert(err == OK, "RoomPreloader: load_threaded_request %s → %s" % [_loading, error_string(err)])


## Дочекатися кімнати, попрошеної через request(): кадри йдуть далі, гра не стоїть. Її черга — перша.
func wait(path: String) -> PackedScene:
	if _queue.has(path):
		_queue.erase(path)
		_queue.push_front(path)
	while _pending.has(path):
		await game.get_tree().process_frame
		_collect()
	return held[path]


## Завантажити у фоні й тримати до кінця гри — не лише кімнату, будь-який ресурс (slice 5). Без поспіху: у черзі.
func pin(path: String) -> void:
	if pinned.has(path):
		return
	pinned[path] = true
	_pin_queue.append(path)


## Чи йде ще якесь фонове завантаження (тести чекають, поки стихне, перш ніж вийти).
func busy() -> bool:
	return not _pending.is_empty() or not _pin_queue.is_empty()


func is_held(path: String) -> bool:
	return held.has(path)


## Готові фонові завантаження переходять у held.
func _collect() -> void:
	if _loading != "":
		var status := ResourceLoader.load_threaded_get_status(_loading)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		assert(status == ResourceLoader.THREAD_LOAD_LOADED, "RoomPreloader: failed to load %s (%d)" % [_loading, status])
		held[_loading] = ResourceLoader.load_threaded_get(_loading)
		_pending.erase(_loading)
		_loading = ""
		_start_next()
	if _pending.is_empty() and not _pin_queue.is_empty():
		request(_pin_queue.pop_front())


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
