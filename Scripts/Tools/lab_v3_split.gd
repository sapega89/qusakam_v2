extends SceneTree

## Одноразовий перехід лабораторії на граф v3 (D863, D865): трьохповерхова Laboratory.tscn розрізається на окремі
## кімнати — Laboratory лишається нижнім поверхом (з камер), бої, медитація, двері й декор інших поверхів переходять у
## нові сцени LabMiddleFloor / LabTopFloor / LabGuardPocket; сходи LabStairsEast / LabStairsWest — порожні каркаси.
## Драбини Ladder1/2 і бічні стіни WestWall/EastWall зникають; двері, що міняють місце (DrainDoor, StairsDoor), — теж:
## їх ставить build_world_rooms.py (EXISTING_DOORS). Далі: build_laboratory.gd (схеми, атмосфера, позиції), тоді
## build_world_rooms.py (двері, MapData.txt). Повторно не запускати: другий раз нового нічого не розріже.
##   godot --headless --path . --script res://Scripts/Tools/lab_v3_split.gd

const MAPS := "res://SampleProject/Maps/%s.tscn"
const SCRIPT := "res://SampleProject/Scripts/Gameplay/Scenes/Laboratory.gd"
const TILESET := "res://SampleProject/Resources/Tileset.tres"
const ROOM_INSTANCE := "res://addons/MetroidvaniaSystem/Nodes/RoomInstance.tscn"
const MUSIC := "res://SampleProject/Resources/Audio/Music/dunes_of_silence.ogg"
const FRONT_DARK := "res://SampleProject/Scenes/Backgrounds/foreground_dark.tscn"
const STOREY_H := 480.0
## Поверх старої кімнати → нова сцена (0 — сама Laboratory).
const STOREY_ROOM := ["Laboratory", "LabMiddleFloor", "LabTopFloor"]
## Поверх у 2,5 раза ширший (2 клітинки → 5): декор розходиться по ньому.
const WIDEN := 2.5


func _initialize() -> void:
	var lab: Node = load(MAPS % "Laboratory").instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var rooms := {
		"LabMiddleFloor": _skeleton("LabMiddleFloor", true),
		"LabTopFloor": _skeleton("LabTopFloor", true),
		"LabGuardPocket": _skeleton("LabGuardPocket", false),
		"LabStairsEast": _skeleton("LabStairsEast", false),
		"LabStairsWest": _skeleton("LabStairsWest", false),
	}
	for node_name in ["Fight_Cursed", "Fight_Middle"]:
		_move(lab, node_name, rooms.LabMiddleFloor)
	for node_name in ["Fight_Lower", "SavePoint_PreBoss", "BossDoorEntrance", "BossDoor"]:
		_move(lab, node_name, rooms.LabTopFloor)
	for node_name in ["Fight_TowerGuard", "Chest_TowerGuard"]:
		_move(lab, node_name, rooms.LabGuardPocket)
	for node_name in ["Ladder1", "Ladder2", "WestWall", "EastWall", "StairsDoorEntrance", "StairsDoor",
			"DrainDoorEntrance", "DrainDoor"]:
		var node := lab.get_node(NodePath(node_name))
		lab.remove_child(node)
		node.free()
	# Декор, атмосфера, колони переднього плану — у кімнату свого поверху, на поверх нижче на висоту поверху.
	for group in ["Decor", "Ambience", "FrontDark"]:
		var source: Node = lab.get_node(NodePath(group))
		for child: Node2D in source.get_children():
			var storey := clampi(int((child.position.y - 1.0) / STOREY_H), 0, 2)
			child.position = Vector2(child.position.x * WIDEN, child.position.y - storey * STOREY_H)
			if storey == 0:
				continue
			var target: Node = rooms[STOREY_ROOM[storey]]
			var parent := target.get_node_or_null(NodePath(group))
			if parent == null:
				parent = source.duplicate(0)
				for old in parent.get_children():
					parent.remove_child(old)
					old.free()
				target.add_child(parent)
				parent.owner = target
			var owned := _owned(child, lab)
			source.remove_child(child)
			parent.add_child(child)
			for node in owned:
				node.owner = target
	_save(lab, MAPS % "Laboratory", ResourceLoader.get_resource_uid(MAPS % "Laboratory"))
	for room_name: String in rooms:
		_save(rooms[room_name], MAPS % room_name, ResourceUID.create_id())
	quit()


## Каркас кімнати: схований шар тайлів (його заповнить build_laboratory.gd), RoomInstance, музика лабораторії;
## поверх — зі скриптом Laboratory.gd і темним переднім планом.
func _skeleton(room_name: String, storey: bool) -> Node2D:
	var room := Node2D.new()
	room.name = room_name
	if storey:
		room.set_script(load(SCRIPT))
	var tile_map := Node2D.new()
	tile_map.name = "TileMap"
	room.add_child(tile_map)
	tile_map.owner = room
	var fg := TileMapLayer.new()
	fg.name = "Foreground"
	fg.tile_set = load(TILESET)
	fg.use_parent_material = true
	tile_map.add_child(fg)
	fg.owner = room
	var instance: Node = load(ROOM_INSTANCE).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	instance.name = "RoomInstance"
	room.add_child(instance)
	instance.owner = room
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	music.stream = load(MUSIC)
	music.autoplay = true
	music.bus = &"Music"
	room.add_child(music)
	music.owner = room
	if storey:
		var front: Node = load(FRONT_DARK).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		front.name = "FrontDark"
		room.add_child(front)
		front.owner = room
	return room


## Вузли піддерева [param node], що належать сцені [param root] (вкладені сцени лишають своїх власників).
func _owned(node: Node, root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node.owner == root:
		out.append(node)
	for child in node.get_children(true):
		out.append_array(_owned(child, root))
	return out


func _move(from: Node, node_name: String, to: Node) -> void:
	var node := from.get_node(NodePath(node_name))
	var owned := _owned(node, from)
	from.remove_child(node)
	to.add_child(node)
	for n in owned:
		n.owner = to


func _save(room: Node, path: String, uid: int) -> void:
	var packed := PackedScene.new()
	print("%s pack %d" % [path.get_file(), packed.pack(room)])
	print("%s save %d uid %d" % [path.get_file(), ResourceSaver.save(packed, path), ResourceSaver.set_uid(path, uid)])
	room.free()
