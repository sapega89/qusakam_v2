extends SceneTree

## The longer Desert Road (BACKLOG 23, design/world_expansion_plan.md, D296, D298) in the real game:
##   1. Each section fight (dunes, mesa, caravan) waits for the hero: no enemy until he walks into its zone, then its
##      own enemies appear on the floor; the story fight at the start (EnemySpawner) is not touched.
##   2. A finished section fight stays finished when the hero comes back (its own room-state key, D152).
##   3. No gift lies on the road (D583): the pickups and the chest are up in branches (verify_road_secrets walks them);
##      the one chest on the road is guarded by an optional fight (the old vulture, D722).
##   4. The road ends at CityGates: walking off the east edge loads CityGates.
##   5. Every ledge can be climbed again with one jump at a time (BACKLOG 32, no double jump): no rise between
##      neighbouring tile columns is higher than a jump, and from the floor on both sides of each raised top the
##      hero gets onto it with real move/jump input — the east side too, where he lands after dropping off.
##   godot --headless --path . --script res://SampleProject/UI/verify_road_sections.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const FIGHTS := {"Fight_Dunes": 3, "Fight_Mesa": 4, "Fight_Caravan": 5}  # D617: a bandit from each went to the lone fights; D445: a vulture joins the caravan

## A jump lifts the hero ~103 px (PlayerMover.jump_velocity, default gravity); a rise is climbable up to 3 tiles.
const JUMP_RISE := 96
## The hero's origin stands this far above his feet (on the floor at y 384 he is at y 360).
const FEET := 24.0
## Raised tops of the road (D296): [name, x from, x to, top y, floor x west of the rise, floor x east of it] in room px.
const LEDGES := [
	["dune step", 1856.0, 1984.0, 320.0, 1650.0, 2380.0], ["dune rock", 1984.0, 2112.0, 256.0, 1650.0, 2380.0],
	["dune east step", 2112.0, 2176.0, 320.0, 1650.0, 2380.0],
	["mesa plateau", 2752.0, 3136.0, 320.0, 2550.0, 3530.0], ["mesa end rock", 3136.0, 3264.0, 256.0, 2550.0, 3530.0],
	["mesa east step", 3264.0, 3328.0, 320.0, 2550.0, 3530.0],
	["caravan step", 3968.0, 4096.0, 320.0, 3770.0, 4460.0], ["caravan rock", 4096.0, 4192.0, 256.0, 3770.0, 4460.0],
	["caravan east step", 4192.0, 4256.0, 320.0, 3770.0, 4460.0],
]

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _alive(spawner: Node) -> Array:
	return spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)


## The hero on the low floor to one side of a ledge's rise heads for its middle — walking, jumping whenever a wall stops
## him, letting go of the stick once he is above the top — until he stands on it. Returns [made it, where he was].
func _climb(player: CharacterBody2D, ledge: Array, side: int) -> Array:
	var from_x: float = ledge[4] if side < 0 else ledge[5]
	var mid: float = (ledge[1] + ledge[2]) / 2.0
	var half: float = (ledge[2] - ledge[1]) / 2.0 - 16.0
	player.global_position = Vector2(from_x, 360.0)
	player.velocity = Vector2.ZERO
	for i in 30: await physics_frame
	var jump_left := 0
	var made := false
	for i in 300:
		await physics_frame
		var p := player.global_position
		if player.is_on_floor() and absf(p.x - mid) < half and absf(p.y + FEET - ledge[3]) < 12.0:
			made = true
			break
		_steer(&"move_right", p.x < mid - half)
		_steer(&"move_left", p.x > mid + half)
		if jump_left > 0:
			jump_left -= 1
			if jump_left == 0:
				Input.action_release(&"jump")
		elif player.is_on_floor() and player.is_on_wall():
			Input.action_press(&"jump")
			jump_left = 18
	for action: StringName in [&"move_right", &"move_left", &"jump"]:
		Input.action_release(action)
	return [made, player.global_position]


func _steer(action: StringName, on: bool) -> void:
	if on: Input.action_press(action)
	else: Input.action_release(action)


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	set_meta("start_new_game", true)
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	# The story beats of the road are done — only the sections are under test.
	for flag in ["desert_road_fight_complete"]:
		game.set_quest_flag(flag, true)
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	var road: Node = game.map
	var player: CharacterBody2D = game.player

	print("[1] Section fights wait for the hero")
	ck(_alive(road.get_node("EnemySpawner")).is_empty(), "the story fight stays done (no enemy at the start)")
	for fight: String in FIGHTS:
		ck(_alive(road.get_node(fight)).is_empty(), "%s: no enemy before the hero comes" % fight)
	for fight: String in FIGHTS:
		var spawner: Node = road.get_node(fight)
		var zone: Area2D = spawner.trigger_area
		player.global_position = Vector2(zone.global_position.x, 200.0)
		player.velocity = Vector2.ZERO
		await create_timer(3.5).timeout  # waves of 2, 1.5 s apart
		var alive: Array = _alive(spawner)
		ck(alive.size() == FIGHTS[fight], "%s: %d enemies after the hero walked in (%d)" % [fight, FIGHTS[fight], alive.size()])
		for enemy in alive.filter(func(e: Node) -> bool: return not e.flying):  # D445: гриф у повітрі (verify_flying_enemies)
			# D504: вороги вже б'ються — ходять, задкують, відскакують від тіл (D443); на підлозі — хоч в один із кадрів
			for i in 20:
				if enemy.is_on_floor():
					break
				await physics_frame
			ck(enemy.is_on_floor(), "%s: %s stands on the floor (y %.0f)" % [fight, enemy.name, enemy.global_position.y])
		for enemy in alive:
			enemy.die()
		for i in 6: await physics_frame
		ck(_alive(spawner).is_empty(), "%s: won" % fight)

	print("[2] A won section stays won")
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	road = game.map
	for fight: String in FIGHTS:
		var spawner: Node = road.get_node(fight)
		player.global_position = Vector2(spawner.trigger_area.global_position.x, 200.0)
		await create_timer(2.0).timeout
		ck(_alive(spawner).is_empty(), "%s: nobody comes back" % fight)

	print("[3] No gift lies on the road (D583): every pickup and chest is up in a branch, or guarded by an optional fight (D722)")
	var gifts := road.get_children().filter(func(n: Node) -> bool: return n.scene_file_path in ["res://SampleProject/Objects/ItemPickup.tscn", "res://SampleProject/Objects/Chest.tscn"])
	var guarded := gifts.filter(func(n: Node) -> bool: return n.get(&"guard") != null and not (n.get(&"guard") as NodePath).is_empty())
	ck(guarded.map(func(n: Node) -> String: return n.name) == ["Chest_OldVulture"], "one chest on the road, guarded by the old vulture (%s)" % [guarded])
	gifts = gifts.filter(func(n: Node) -> bool: return not guarded.has(n))
	ck(gifts.size() == 3, "three gifts on the road, all in branches (%d)" % gifts.size())
	for gift: Node2D in gifts:
		ck(gift.global_position.y < 200.0, "%s is above the road (y %.0f), not on it" % [gift.name, gift.global_position.y])

	print("[5] Every ledge can be climbed back onto (BACKLOG 32)")
	var fg: TileMapLayer = game.map.get_node("TileMap/Foreground")
	var tops := {}  # column → top row of its ground
	for c: Vector2i in fg.get_used_cells():
		tops[c.x] = mini(tops.get(c.x, 999), c.y)
	var cols: Array = tops.keys()
	cols.sort()
	var worst := 0
	for i in range(1, cols.size()):
		worst = maxi(worst, absi(tops[cols[i]] - tops[cols[i - 1]]))
	ck(worst * 32 <= JUMP_RISE, "no rise between neighbouring columns is above one jump (worst %d px)" % (worst * 32))
	for ledge: Array in LEDGES:
		for side: int in [-1, 1]:
			var r: Array = await _climb(player, ledge, side)
			ck(r[0], "%s from the %s: on top (%.0f, %.0f)" % [ledge[0], "west" if side < 0 else "east", r[1].x, r[1].y])

	print("[4] The east edge leads to CityGates")
	player.global_position = Vector2(5100.0, 340.0)
	Input.action_press(&"move_right")
	for i in 240:
		await physics_frame
		if game.map.scene_file_path.ends_with("CityGates.tscn"):
			break
	Input.action_release(&"move_right")
	ck(game.map.scene_file_path.ends_with("CityGates.tscn"), "walking east loads CityGates (%s)" % game.map.scene_file_path)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
