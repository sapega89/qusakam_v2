extends SceneTree

## TIMEOUT: 600

## M7: усі кімнати трьох графів регіонів (design/refs/room_graph_M1_canyon.png, _M3_city.png, _M4_lab.png) на карті
## й граються (Scripts/Tools/build_world_rooms.py):
##   godot --headless --path . --script res://SampleProject/UI/verify_world_rooms.gd
##   1. Граф: від старту (Canyon) досяжна КОЖНА кімната — проходами крізь край (сусідні клітинки MetSys), падінням у
##      провал, дверима й сюжетними телепортами (спуск з каньйону, зала мера → лабораторія). Брами вважаються
##      відчиненими: їхній ключ чи важіль є в грі (п. 2).
##   2. Кожні двері — в обидва боки (ціль веде назад до цих дверей); кожна брама дверей — у gates.json; ключ брами
##      лежить у якійсь кімнаті (ItemPickup) або дає бій (RoomEnemySpawner.reward); прапорець брами ставить важіль,
##      двері (sets_flag) або розмова.
##   3. Кожна нова кімната: Arrival, RoomInstance, Music, локація, звук кімнати, назва кімнати перекладена (uk).
##   4. Справжнім вводом: у кожній новій кімнаті герой стоїть на підлозі біля Arrival.
##   5. Провалля: без мосту герой падає в сухе русло; важіль на підході до брами опускає міст, і дорога суцільна
##      (move_right з провалля → підхід до брами).
##   6. Короткий шлях з льоху: ґрати в акведук зачинені з обох боків, важіль у льоху відчиняє обидва.
## Пише лише в user://verify_world_rooms/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const LocationDB = preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
const MAPS := "res://SampleProject/Maps/%s.tscn"
const ROOM_DOOR := "res://SampleProject/Scripts/Gameplay/RoomDoor.gd"
const LEVER := "res://SampleProject/Scripts/Gameplay/Lever.gd"
const TALK_SPOT := "res://SampleProject/Scripts/Gameplay/TalkSpot.gd"
const PICKUP := "res://SampleProject/Scripts/Gameplay/ItemPickup.gd"
const SPAWNER := "res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd"
const GATES := "res://SampleProject/Resources/Data/gates.json"
const SOUNDS := "res://SampleProject/Resources/Data/sound_events.json"
const TEST_DIR := "user://verify_world_rooms/"
const START := "Canyon"
## Сюжетні телепорти (кат-сцени): Canyon.gd → печера під мостом, MayorHall.gd → камери лабораторії.
const STORY_EDGES := [["Canyon", "CaveUnderBridge"], ["MayorHall", "LabCells"]]
## Прапорці, що ставить сюжет (не важіль чи двері): розмова з Маліком.
const STORY_FLAGS := ["lab_acquaintance_complete"]
const NEW_ROOMS := ["MountainPath", "ScreeSlide", "StreamGorge", "RockLedges", "CaveUnderBridge", "CaveExit", "CanyonFloor",
		"SmugglersStash", "LizardCaves", "MesaTop", "ZahraRest", "Dunes", "Chasm", "DryRiverbed", "Aqueduct", "OldRuins",
		"GateApproach", "CraftQuarter", "PalaceSquare", "Rooftops", "PigeonLoft", "TavernAttic", "MayorArchive", "Cistern",
		"CisternStash", "AlchemistCorridor", "AlchemistStore", "MalikStash", "CollapsedDrain"]
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0), Vector3i(0, -1, 0)]

var fails: Array[String] = []
var game: Node
var metsys: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	metsys = root.get_node("MetSys")
	var rooms := _rooms()
	var scenes := {}
	for room: String in rooms:
		scenes[room] = (load(MAPS % room) as PackedScene).instantiate()

	print("[1] Every room is reachable from %s" % START)
	var edges := _edges(rooms, scenes)
	var seen := {START: true}
	var queue: Array[String] = [START]
	while not queue.is_empty():
		var room: String = queue.pop_front()
		for next: String in edges.get(room, []):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	for room: String in rooms:
		ck(seen.has(room), "%s is reachable from %s" % [room, START])

	print("[2] Every door both ways; every gate opens somewhere in the game")
	var gates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATES)).gates
	var keys := {}
	var flags := {}
	for f: String in STORY_FLAGS:
		flags[f] = "the story"
	for room: String in rooms:
		for n: Node in scenes[room].find_children("*", "", true, false):
			var path := _script(n)
			if path == PICKUP:
				keys[n.item_id] = "%s/%s" % [room, n.name]
			elif path == SPAWNER:
				for item: String in n.reward:
					keys[item] = "%s/%s" % [room, n.name]
			elif path == LEVER or path == TALK_SPOT or (path == ROOM_DOOR and n.sets_flag != ""):
				flags[n.sets_flag] = "%s/%s" % [room, n.name]
	for room: String in rooms:
		for door: Node in _doors(scenes[room]):
			var key := "%s/%s" % [room, door.name]
			var target: String = (door.target_room as String).get_file().get_basename()
			var back: Node = scenes[target].get_node_or_null(door.arrival) if scenes.has(target) else null
			ck(back != null and _script(back) == ROOM_DOOR and back.target_room == MAPS % room and String(back.arrival) == String(door.name),
					"%s → %s:%s and back" % [key, target, door.arrival])
			if door.gate_id == "":
				continue
			ck(gates.has(door.gate_id), "%s: gate %s is in gates.json" % [key, door.gate_id])
			var gate: Dictionary = gates.get(door.gate_id, {})
			if gate.has("key"):
				ck(keys.has(gate.key), "%s: the key %s is found at %s" % [key, gate.key, keys.get(gate.key, "nowhere")])
			elif gate.has("flag"):
				ck(flags.has(gate.flag), "%s: the flag %s is set by %s" % [key, gate.flag, flags.get(gate.flag, "nothing")])

	print("[3] Every new room: Arrival, RoomInstance, Music, location, room sound, translated title")
	var sounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOUNDS)).rooms
	TranslationServer.set_locale("uk")
	for room: String in NEW_ROOMS:
		var s: Node = scenes.get(room)
		ck(s != null, "%s is on the map" % room)
		if s == null:
			continue
		ck(s.has_node(^"Arrival") and s.has_node(^"RoomInstance") and s.has_node(^"Music"), "%s: Arrival, RoomInstance, Music" % room)
		ck(LocationDB.of_scene(MAPS % room) != "", "%s: in a location (%s)" % [room, LocationDB.of_scene(MAPS % room)])
		ck(sounds.has(room), "%s: room sound in sound_events.json" % room)
		var title := room.capitalize()
		ck(TranslationServer.translate(title) != title, "%s: «%s» in uk" % [room, TranslationServer.translate(title)])
	TranslationServer.set_locale("en")
	for room: String in scenes:
		scenes[room].free()

	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(1)
	game = await Kit.boot(self)
	game.player.set_invulnerable(true)

	print("[4] In every new room the hero stands on the floor at Arrival")
	for room: String in NEW_ROOMS:
		await game.teleport_to_room(MAPS % room, ^"Arrival")
		await _settle()
		var arrival: Node2D = game.map.get_node(^"Arrival")
		var body: CharacterBody2D = game.player
		ck(game.map.scene_file_path == MAPS % room and body.is_on_floor() and body.global_position.distance_to(arrival.global_position) < 64.0,
				"%s: on the floor at Arrival (hero %s, arrival %s)" % [room, body.global_position, arrival.global_position])

	print("[5] The chasm: down into the dry riverbed; the lever drops the bridge, the road runs on")
	await game.teleport_to_room(MAPS % "Chasm", ^"Arrival")
	await _settle()
	ck(not game.map.get_node(^"Bridge").is_lowered(), "the bridge stands up on the far side")
	game.place_player(Vector2(430.0, 300.0))
	await _until_room("DryRiverbed", 6.0)
	ck(_room() == "DryRiverbed", "no bridge: the hero falls into the dry riverbed (%s)" % _room())
	await game.teleport_to_room(MAPS % "GateApproach", ^"Arrival")
	await _settle()
	await _press_e_at(game.map.get_node(^"BridgeLever"))
	ck(game.get_quest_flag("chasm_bridge_down") and game.map.get_node(^"BridgeLever").is_pulled(), "E on the lever pulls it (chasm_bridge_down)")
	await game.teleport_to_room(MAPS % "Chasm", ^"Arrival")
	await _settle()
	ck(game.map.get_node(^"Bridge").is_lowered(), "the bridge is down")
	Input.action_press(&"move_right")
	await _until_room("GateApproach", 10.0)
	Input.action_release(&"move_right")
	ck(_room() == "GateApproach", "move_right runs over the bridge to the gate approach (%s)" % _room())

	print("[6] The cellar lever opens the grate into the aqueduct from both sides")
	await game.teleport_to_room(MAPS % "Aqueduct", ^"CellarDoor")
	await _settle()
	ck(not game.map.get_node(^"CellarDoor").is_open(), "from the aqueduct the grate is shut")
	await game.teleport_to_room(MAPS % "GatehouseCellar", ^"Arrival")
	await _settle()
	ck(not game.map.get_node(^"AqueductDoor").is_open(), "in the cellar too, until the lever")
	await _press_e_at(game.map.get_node(^"AqueductLever"))
	ck(game.map.get_node(^"AqueductDoor").is_open(), "the lever opens it")
	await game.teleport_to_room(MAPS % "Aqueduct", ^"CellarDoor")
	await _settle()
	ck(game.map.get_node(^"CellarDoor").is_open(), "and from the aqueduct side it is open now")

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


## Кімнати на карті MetSys (імена сцен).
func _rooms() -> Array[String]:
	var out: Array[String] = []
	for coords: Vector3i in metsys.map_data.cells:
		var room: String = metsys.map_data.get_assigned_scene_at(coords)
		if room != "" and not out.has(room.get_basename()):
			out.append(room.get_basename())
	out.sort()
	return out


## Куди можна піти з кімнати: край у сусідню кімнату (крізь стіну MetSys не веде, але в її клітинку героя пускає
## лише прохід — межа ≥ 1 з будь-якого боку), падіння (межа D ≥ 1), двері, сюжетні телепорти.
func _edges(rooms: Array[String], scenes: Dictionary) -> Dictionary:
	var out := {}
	var data = metsys.map_data
	for coords: Vector3i in data.cells:
		var here: String = data.get_assigned_scene_at(coords).get_basename()
		if here == "":
			continue
		for i in 4:
			var next: Vector3i = coords + DIRS[i]
			if data.get_cell_at(next) == null:
				continue
			var there: String = data.get_assigned_scene_at(next).get_basename()
			if there == "" or there == here:
				continue
			var mine: int = data.get_cell_at(coords).get_border(i)
			var theirs: int = data.get_cell_at(next).get_border((i + 2) % 4)
			if mine >= 1 or (i % 2 == 0 and theirs >= 1):
				_add(out, here, there)
	for room: String in rooms:
		for door: Node in _doors(scenes[room]):
			_add(out, room, (door.target_room as String).get_file().get_basename())
	for e: Array in STORY_EDGES:
		_add(out, e[0], e[1])
	return out


func _add(edges: Dictionary, from: String, to: String) -> void:
	if not edges.has(from):
		edges[from] = []
	if not (edges[from] as Array).has(to):
		edges[from].append(to)


func _doors(scene: Node) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in scene.get_children():
		if _script(n) == ROOM_DOOR:
			out.append(n)
	return out


func _script(n: Node) -> String:
	return (n.get_script() as Script).resource_path if n.get_script() != null else ""


func _room() -> String:
	return "" if game.map == null else game.map.scene_file_path.get_file().get_basename()


func _settle() -> void:
	while game.room_changing:
		await process_frame
	for i in 30: await physics_frame
	await Kit.drain(self)


func _until_room(room: String, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000.0)
	while _room() != room and Time.get_ticks_msec() < deadline:
		await process_frame
	await _settle()


## Герой підходить до речі (зона Area2D бачить лише тіло, що в неї зайшло) і тисне E.
func _press_e_at(thing: Node2D) -> void:
	game.place_player(thing.global_position + Vector2(-60.0, -40.0))
	for i in 10: await physics_frame
	Input.action_press(&"move_right")
	var interactable: Node = thing.get_node(^"Interactable")
	for i in 120:
		if interactable.player_nearby:
			break
		await physics_frame
	Input.action_release(&"move_right")
	await Kit.frames(self, 5)
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 20)
