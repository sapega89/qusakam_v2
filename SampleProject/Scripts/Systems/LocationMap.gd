extends RefCounted

## Дані однієї локації для карти World Map (design/world_map_spec.md, D458, D565): клітинки MetSys її кімнат, стан кожної
## (досліджена / бачений вхід / схована), об'єкти кімнат (герой, медитація, скрині, замкнені брами, завдання, виходи)
## і переходи між клітинками (драбина, спуск). Усе — з MapData MetSys, стану гри й сцен кімнат: кімнати перебудовують
## (world_structure_plan Region v2/v3), тож тут нічого не задано під окрему кімнату.
##   const LocationMap = preload("res://SampleProject/Scripts/Systems/LocationMap.gd")
##   var data = LocationMap.new("canyon_of_whispers")
## Сцени кімнат створюються поза деревом (без _ready) лише щоб прочитати вузли, і одразу звільняються.

const LocationDB := preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
const LockedDoor := preload("res://SampleProject/Scripts/Gameplay/LockedDoor.gd")

enum Cell { HIDDEN, SEEN, EXPLORED }

const KIND_HERO := &"hero"
const KIND_SAVE := &"save"
const KIND_CHEST := &"chest"
const KIND_CHEST_OPEN := &"chest_open"
const KIND_LOCKED := &"locked"
const KIND_QUEST := &"quest"
const KIND_EXIT := &"exit"
const PASSAGE_LADDER := &"ladder"
const PASSAGE_DROP := &"drop"

const SAVE_POINT_SCRIPT := "res://SampleProject/Scripts/SavePoint.gd"
const LADDER_SCRIPT := "res://SampleProject/Scripts/Gameplay/Ladder.gd"
const LOCKED_DOOR_SCRIPT := "res://SampleProject/Scripts/Gameplay/LockedDoor.gd"

## Межі клітинки в MapData MetSys ідуть R, D, L, U; -1 — відкрито всередині кімнати, 0 — стіна, > 0 — прохід.
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0), Vector3i(0, -1, 0)]
const BORDER_WALL := 0
const DOWN := 1
## Куди в клітинці стає значок виходу через межу R, D, L, U (частки клітинки).
const EXIT_AT: Array[Vector2] = [Vector2(0.86, 0.5), Vector2(0.5, 0.8), Vector2(0.14, 0.5), Vector2(0.5, 0.2)]

var id: String
## Клітинка MetSys → кімната (імʼя сцени без .tscn).
var cells: Dictionary[Vector3i, String] = {}
## {kind: StringName, cell: Vector3i, at: Vector2 — місце в клітинці, частки 0..1}.
var markers: Array[Dictionary] = []
## {kind: StringName, upper: Vector3i} — перехід між клітинкою upper і тією, що під нею.
var passages: Array[Dictionary] = []
var chests_total := 0
var chests_opened := 0

var _met: Node
## Межі між клітинкою й тією, що під нею, які перетинає драбина.
var _ladder_cells: Dictionary[Vector3i, bool] = {}


func _init(location_id: String) -> void:
	id = location_id
	_met = (Engine.get_main_loop() as SceneTree).root.get_node(^"MetSys")
	var rooms: Array = LocationDB.location(id).rooms
	for room: String in rooms:
		for coords: Vector3i in _met.map_data.get_cells_assigned_to(_room_path(room)):
			cells[coords] = room
	for room: String in rooms:
		_scan_room(room)
	_find_exits()
	_find_passages()
	_add_hero()


## Стан клітинки (world_map_spec): досліджена; бачений вхід — сусідня досліджена клітинка має до неї не стіну; решта схована.
func state(coords: Vector3i) -> Cell:
	if _met.is_cell_discovered(coords, false):
		return Cell.EXPLORED
	for d in DIRS.size():
		var from: Vector3i = coords - DIRS[d]
		if cells.has(from) and _met.is_cell_discovered(from, false) and _border(from, d) != BORDER_WALL:
			return Cell.SEEN
	return Cell.HIDDEN


## Частка досліджених клітинок локації, 0..100.
func explored_percent() -> int:
	var explored := 0
	for coords: Vector3i in cells:
		explored += int(_met.is_cell_discovered(coords, false))
	return roundi(100.0 * explored / cells.size())


## Герой уже бував тут: є хоч одна досліджена клітинка.
func visited() -> bool:
	return cells.keys().any(func(c: Vector3i) -> bool: return _met.is_cell_discovered(c, false))


## Герой зараз у цій локації.
func is_here() -> bool:
	return cells.has(_met.get_current_coords())


## Кімната досліджена, якщо досліджено хоч одну її клітинку.
func room_explored(room: String) -> bool:
	return cells.keys().any(func(c: Vector3i) -> bool: return cells[c] == room and _met.is_cell_discovered(c, false))


## Перша клітинка кімнати (верхня, потім ліва) серед тих, що мають стан [param wanted] або кращий.
func first_cell(room: String, wanted: Cell) -> Vector3i:
	var best := Vector3i.MAX
	for c: Vector3i in cells:
		if cells[c] != room or state(c) < wanted:
			continue
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	return best


## Назва кімнати мовою гри: ключ — імʼя сцени словами («LizardCave» → «Lizard Cave»), як location_title до D618.
static func room_title(room: String) -> String:
	return TranslationServer.translate(room.capitalize())


func _room_path(room: String) -> String:
	return (_met.settings.map_root_folder as String).path_join(room + ".tscn")


func _border(coords: Vector3i, dir: int) -> int:
	return _met.map_data.get_cell_at(coords).get_border(dir)


func _scan_room(room: String) -> void:
	var path := _room_path(room)
	var room_key: String = _met.map_data.get_room_from_scene_path(path, false)
	# Початок координат кімнати — її найменша клітинка, як RoomInstance.min_cell.
	var origin := Vector3i(Vector3i.MAX.x, Vector3i.MAX.y, 0)
	for c: Vector3i in cells:
		if cells[c] == room:
			origin = Vector3i(mini(origin.x, c.x), mini(origin.y, c.y), c.z)
	assert(origin.x != Vector3i.MAX.x, "LocationMap: room %s has no MetSys cells (MapData.txt)" % room)
	var scene: Node = (load(path) as PackedScene).instantiate()
	for child in scene.get_children():
		_walk(child, Transform2D.IDENTITY, room, room_key, origin)
	scene.free()


func _walk(node: Node, parent: Transform2D, room: String, room_key: String, origin: Vector3i) -> void:
	if node is CanvasLayer:
		return  # тла й передні плани — об'єктів кімнати там немає
	var xf := parent
	if node is Node2D:
		xf = parent * (node as Node2D).transform
	_classify(node, xf.origin, room, room_key, origin)
	for child in node.get_children():
		_walk(child, xf, room, room_key, origin)


func _classify(node: Node, pos: Vector2, room: String, room_key: String, origin: Vector3i) -> void:
	if node is Chest:
		chests_total += 1
		var opened: bool = Game.get_singleton().get_room_state(room_key, "opened_%s" % node.name, false)
		chests_opened += int(opened)
		_mark(KIND_CHEST_OPEN if opened else KIND_CHEST, pos, room, origin)
	elif node is RoomDoor:
		var door: RoomDoor = node
		if door.gate_id != "" and RoomDoor.locked(door.gate_id, room_key, node.name, door.target_room):
			_mark(KIND_LOCKED, pos, room, origin)
		elif LocationDB.of_scene(door.target_room) != id:
			_mark(KIND_EXIT, pos, room, origin)
	elif node is NpcBase:
		var npc: NpcBase = node
		if npc._here() and npc.quest_marker() != &"":
			_mark(KIND_QUEST, pos, room, origin)
	elif _has_script(node, SAVE_POINT_SCRIPT):
		_mark(KIND_SAVE, pos, room, origin)
	elif _has_script(node, LOCKED_DOOR_SCRIPT):
		if LockedDoor.is_locked(node.get(&"gate_id"), room_key, node.name):
			_mark(KIND_LOCKED, pos, room, origin)
	elif _has_script(node, LADDER_SCRIPT):
		var top := _cell_of(pos, origin)
		var bottom := _cell_of(pos + Vector2(0, node.get(&"height")), origin)
		for y in range(top.y, bottom.y):
			_ladder_cells[Vector3i(top.x, y, origin.z)] = true


## Сам скрипт вузла або його предок — [param path].
func _has_script(node: Node, path: String) -> bool:
	var script: Script = node.get_script()
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false


## Клітинка MetSys для точки [param pos] у координатах кімнати.
func _cell_of(pos: Vector2, origin: Vector3i) -> Vector3i:
	var p: Vector2 = pos / (_met.settings.in_game_cell_size as Vector2)
	return Vector3i(origin.x + floori(p.x), origin.y + floori(p.y), origin.z)


func _mark(kind: StringName, pos: Vector2, room: String, origin: Vector3i) -> void:
	var cell := _cell_of(pos, origin)
	if cells.get(cell, "") != room:
		push_warning("LocationMap: %s in %s at %s is outside the room's MetSys cells" % [kind, room, pos])
		return
	var p: Vector2 = pos / (_met.settings.in_game_cell_size as Vector2)
	markers.append({"kind": kind, "cell": cell, "at": p - p.floor()})


## Вихід в іншу локацію: межа-не-стіна до клітинки, що належить іншій локації.
func _find_exits() -> void:
	for c: Vector3i in cells:
		for d in DIRS.size():
			var next: Vector3i = c + DIRS[d]
			if not cells.has(next) and _met.map_data.cells.has(next) and _border(c, d) != BORDER_WALL:
				markers.append({"kind": KIND_EXIT, "cell": c, "at": EXIT_AT[d]})


## Межа між клітинкою й тією, що під нею, без стіни: драбина, якщо її перетинає Ladder, інакше спуск.
func _find_passages() -> void:
	for c: Vector3i in cells:
		var below: Vector3i = c + DIRS[DOWN]
		if cells.has(below) and _border(c, DOWN) != BORDER_WALL:
			passages.append({"kind": PASSAGE_LADDER if _ladder_cells.has(c) else PASSAGE_DROP, "upper": c})


func _add_hero() -> void:
	var room: Node = _met.get_current_room_instance()
	if room == null or not is_here():
		return
	var p: Vector2 = _met.exact_player_position / (_met.settings.in_game_cell_size as Vector2)
	markers.append({"kind": KIND_HERO, "cell": _met.get_current_coords(), "at": p - p.floor()})
