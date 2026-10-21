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

## Підсумковий z з урахуванням батьків (z_as_relative).
func _z(item: CanvasItem) -> int:
	var z := 0
	var n: Node = item
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z

## Чи непрозорий піксель спрайта там, де стоїть герой: на висоті грудей (chest) або на висоті мосту брами (рядок 70 текстури).
func _covers(sprite: Sprite2D, player: Node2D, chest: bool) -> bool:
	var p: Vector2 = sprite.to_local(player.global_position + Vector2(0, -30))
	var img: Image = sprite.texture.get_image()
	var px := Vector2i(int(p.x), int(p.y) if chest else 70)
	if px.x < 0 or px.x >= img.get_width() or px.y < 0 or px.y >= img.get_height():
		return false
	return img.get_pixelv(px).a > 0.5

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

	print("[7] B80: a teleport from where the new room has a trigger moves the body at once; the trigger stays quiet")
	player.global_position = Vector2(690, 360)  # у смузі RaidTrigger; у FIGHT_LOOP він не спрацьовує
	for i in 30: await physics_frame
	var flags: Dictionary = game.get_quest_flags().duplicate(true)
	flags.erase("city_gates_intro_complete")  # знову APPROACH — RaidTrigger чатує
	game.set_quest_flags(flags)
	started.clear()
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	var body: Transform2D = PhysicsServer2D.body_get_state(player.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
	ck(body.origin.is_equal_approx(player.global_position), "physics body at the arrival right away (%s vs %s)" % [body.origin, player.global_position])
	var y0: float = player.global_position.y
	for i in 30: await physics_frame
	ck(game.map.get_current_state_name() == "APPROACH", "the raid does not re-fire 200 px away (%s)" % game.map.get_current_state_name())
	ck(started.is_empty() and not player.event, "no raid lines, control kept (%s)" % [started])
	ck(player.global_position.y > y0, "the hero falls after the teleport (y %.1f -> %.1f)" % [y0, player.global_position.y])

	print("[8] 8c/8d: the gatehouse is a passage the hero walks through, every gate layer behind him (D314); walking east loads the City inside it")
	for flag in ["city_gates_intro_complete", "city_gates_fight_complete", "city_gates_after_fight_complete"]:
		game.set_quest_flag(flag, true)
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 30: await physics_frame
	room = game.map
	ck(room.get_current_state_name() == "TO_CITY", "TO_CITY (%s)" % room.get_current_state_name())
	var front: Sprite2D = room.get_node(^"GatePassage/Front")
	var hero_z: int = _z(player.get_node(^"Sprite2D"))
	for layer: CanvasItem in room.get_node(^"GatePassage").get_children():
		ck(_z(layer) < hero_z, "gate layer %s z %d below the hero %d (8d: the gate never covers him)" % [layer.name, _z(layer), hero_z])
	ck(_z(room.get_node(^"GatePassage/Back")) < _z(front), "the dark wall stays behind the towers")
	player.global_position = Vector2(1100, 360)
	for i in 30: await physics_frame
	var past_tower := false
	var under_bridge := false
	Input.action_press(&"move_right")
	for i in 600:
		if game.map != room:
			break
		var x: float = player.global_position.x
		if x > 1380.0 and x < 1480.0:
			past_tower = past_tower or (_covers(front, player, true) and player.is_visible_in_tree())
		if x > 1600.0:
			under_bridge = under_bridge or (not _covers(front, player, true) and _covers(front, player, false))
		await physics_frame
	for i in 10: await physics_frame
	Input.action_release(&"move_right")
	ck(past_tower, "the hero walks past the tower, drawn in front of it")
	ck(under_bridge, "deeper in, the hero stands inside the arch, under the bridge")
	ck(game.map.scene_file_path.ends_with("/City.tscn"), "real move_right east loads the City (%s)" % game.map.scene_file_path)
	var city_front: Sprite2D = game.map.get_node(^"GatePassage/Front")
	ck(not _covers(city_front, player, true) and _covers(city_front, player, false),
			"the City side: the hero arrives inside the same passage (x %.0f)" % player.global_position.x)
	ck(_z(city_front) < _z(game.player.get_node(^"Sprite2D")), "the City side: the towers are behind the hero too")

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
