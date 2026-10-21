extends SceneTree

## Ворота міста (BACKLOG feedback 18): над головою небо (стелі з тайлів немає, вгору з кімнати не вийти),
## біля брами — варта; Кусакам підходить дорогою — кат-сцена нападу бандитів (керування забрано, камера до брами,
## CityGates, бандити біжать на точки спавну, CityGates_Raid, камера назад), далі бій з асистом охоронця (D209).
##   godot --headless --path . --script res://SampleProject/UI/verify_city_gates_raid.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

## Лише поточний діалог: _drain іде й за наступним, що стартує одразу після.
func _drain_one(dm: Node, started: Array[String]) -> void:
	var n := started.size()
	for i in 200:
		if not dm.is_dialogue_active() or started.size() != n:
			return
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _enemies(room: Node) -> Array:
	return room.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon
	var metsys: Node = root.get_node("MetSys")
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[1] Arriving: nothing plays until the road reaches the trigger")
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 30: await physics_frame
	var room: Node = game.map
	ck(room.get_current_state_name() == "APPROACH", "waits in APPROACH (%s)" % room.get_current_state_name())
	ck(started.is_empty(), "no dialogue on arrival (%s)" % [started])
	ck(not room.get_node(^"Raid").visible, "no bandits yet")

	print("[2] Open sky: the ceiling band is gone, but a jump cannot leave through the top")
	var player: CharacterBody2D = game.player
	var room_name: String = metsys.get_current_room_name()
	player.global_position = Vector2(1000, 60)
	for i in 30:
		player.velocity.y = -1500.0
		await physics_frame
	ck(player.global_position.y > 0.0, "stopped under the room's top (y %.0f)" % player.global_position.y)
	ck(metsys.get_current_room_name() == room_name, "still in CityGates (%s)" % metsys.get_current_room_name())
	var terrain: TileMapLayer = room.get_node(^"TileMap/Foreground")
	var overhead := terrain.get_used_cells().filter(func(c: Vector2i) -> bool: return c.y <= 3 and c.x >= 3 and c.x <= 52)
	ck(overhead.is_empty(), "no solid tiles over the road (%d)" % overhead.size())
	for i in 60: await physics_frame

	print("[3] Walking right into the trigger starts the raid: input taken, camera to the gate")
	player.global_position = Vector2(560, 360)
	for i in 30: await physics_frame
	Input.action_press(&"move_right")
	await _until(func() -> bool: return room.get_current_state_name() == "RAID_CUTSCENE", 4.0)
	Input.action_release(&"move_right")
	ck(room.get_current_state_name() == "RAID_CUTSCENE", "real move_right reaches the trigger (%s)" % room.get_current_state_name())
	var camera: Camera2D = player.get_node(^"Camera2D")
	ck(player.event, "movement taken")
	ck(camera.top_level, "camera detached from the hero")
	await _until(func() -> bool: return dm.is_dialogue_active(), 4.0)
	ck(started == ["CityGates"], "CityGates first (%s)" % [started])
	var look: Node2D = room.get_node(^"Raid/Look")
	ck(camera.global_position.distance_to(look.global_position) < 2.0, "camera at the gate (%s)" % camera.global_position)
	await _drain_one(dm, started)

	print("[4] The guard shouts, then the bandits run at the gate and stop on the fight's spawn points")
	await _until(func() -> bool: return dm.is_dialogue_active(), 4.0)
	ck(started == ["CityGates", "CityGates_Raid"], "then CityGates_Raid (%s)" % [started])
	await _drain_one(dm, started)
	var bandits: Array[Node] = room.get_node(^"Raid/Bandits").get_children()
	var start_x: float = (bandits[0] as Node2D).global_position.x
	for i in 10: await process_frame
	ck(room.get_node(^"Raid").visible, "bandits shown")
	ck((bandits[0] as Node2D).global_position.x > start_x, "bandits running right")
	ck(player.event, "movement still taken after the lines")
	var points: Array[Node] = room.get_node(^"EnemySpawner").get_children()
	await _until(func() -> bool: return absf((bandits[0] as Node2D).global_position.x - (points[0] as Node2D).global_position.x) < 1.0, 4.0)
	for i in bandits.size():
		var gap: float = absf((bandits[i] as Node2D).global_position.x - (points[i] as Node2D).global_position.x)
		ck(gap < 1.0, "%s on its spawn point (gap %.1f)" % [bandits[i].name, gap])

	print("[5] Camera back, then the guard-assist fight as before (D209)")
	await _until(func() -> bool: return room.get_current_state_name() == "FIGHT_LOOP", 4.0)
	ck(room.get_current_state_name() == "FIGHT_LOOP", "FIGHT_LOOP after the raid (%s)" % room.get_current_state_name())
	ck(not camera.top_level, "camera follows the hero again")
	ck(game.get_quest_flag("city_gates_intro_complete"), "city_gates_intro_complete set")
	await _until(func() -> bool: return dm.is_dialogue_active(), 4.0)
	ck(started == ["CityGates", "CityGates_Raid", "CityGates_Fight"], "then CityGates_Fight (%s)" % [started])
	await _drain(dm)
	await _until(func() -> bool: return _enemies(room).size() == 3, 4.0)
	var enemies: Array = _enemies(room)
	ck(enemies.size() == 3, "3 bandits to fight (%d)" % enemies.size())
	ck(not room.get_node(^"Raid").visible, "cutscene bandits replaced by the real ones")
	ck(not player.event, "control back")
	ck(sl.get_companion_manager()._guard_offered, "the guard is offered")
	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")
	ck(hint.current_hint == "call_guard", "call_guard hint (%s)" % hint.current_hint)

	print("[6] Coming back mid-fight does not replay the raid")
	started.clear()
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"SavePoint_BeforeCity")
	for i in 20: await physics_frame
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 60: await physics_frame
	ck(game.map.get_current_state_name() == "FIGHT_LOOP", "back in FIGHT_LOOP (%s)" % game.map.get_current_state_name())
	ck(not started.has("CityGates") and not started.has("CityGates_Raid"), "no raid lines (%s)" % [started])
	ck(not game.map.get_node(^"Raid").visible, "no cutscene bandits")

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
