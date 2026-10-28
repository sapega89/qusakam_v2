extends SceneTree

## The longer Desert Road (BACKLOG 23, design/world_expansion_plan.md, D296, D298) in the real game:
##   1. Each section fight (dunes, mesa, caravan) waits for the hero: no enemy until he walks into its zone, then its
##      own enemies appear on the floor; the story fight at the start (EnemySpawner) is not touched.
##   2. A finished section fight stays finished when the hero comes back (its own room-state key, D152).
##   3. No gift lies on the road (D583): the pickups and the chest are up in branches (verify_road_secrets walks them);
##      the one chest on the road is guarded by an optional fight (the old vulture, D722).
##   4. The road goes on east: walking off the east edge loads Zahra's Rest (M7; the City Gates are further on).
##   1b. D817: every group fight on the road is a bandit and a jackal or two bandits and a jackal (lone fights stay
##      lone), and winning a group pays its win_xp on top of its enemies' XP.
##   5. D830 «на дорозі не має бути сходинок»: the floor is flat — no tile above the floor row, and a ray down at every
##      32 px of the road meets the floor at y 384 (the dune, mesa and caravan steps of D296 are gone).
##   godot --headless --path . --script res://SampleProject/UI/verify_road_sections.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const FIGHTS := {"Fight_Dunes": 2, "Fight_Mesa": 3, "Fight_Caravan": 3}  # D817: a bandit and a jackal, or two bandits and a jackal
## D817: in a road group the "bandits" are the bandit gang (bandit, shield-bearer, archer), the "jackal" its one beast
## (jackal, scorpion, vulture; their big kinds stand on the same base).
const GANG := ["melee", "shield", "archer"]
const BEASTS := ["fast", "tank", "vulture"]

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

	# Секції тут — лише хто й коли зʼявляється; бої тепер важкі (D754), і герой першого рівня серед груп не мусить вижити
	player.min_health = 1
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
		var gained: Array[int] = [0]
		var count_xp := func(amount: int, _total: int) -> void: gained[0] += amount
		root.get_node("ServiceLocator").get_xp_manager().xp_gained.connect(count_xp)
		var due: int = spawner.win_xp
		for enemy in alive:
			due += enemy.xp_reward
			enemy.die()
		for i in 6: await physics_frame
		ck(_alive(spawner).is_empty(), "%s: won" % fight)
		root.get_node("ServiceLocator").get_xp_manager().xp_gained.disconnect(count_xp)
		ck(spawner.win_xp > 0 and gained[0] == due,
				"%s: the win pays its enemies' XP and win_xp %d (+%d, expected +%d)" % [fight, spawner.win_xp, gained[0], due])

	print("[1b] D817: a road group is a bandit and a jackal, or two bandits and a jackal; lone fights stay lone")
	for spawner: Node in road.get_children().filter(func(n: Node) -> bool: return n.get_script() == road.get_node("EnemySpawner").get_script()):
		var types: Array = spawner.spawn_points.map(func(p: Node) -> String: return p.enemy_type)
		if types.size() == 1:
			ck(spawner.win_xp == 0, "%s: lone (%s), no win_xp" % [spawner.name, types])
			continue
		var gang: int = types.filter(func(t: String) -> bool: return t in GANG).size()
		var beasts: int = types.filter(func(t: String) -> bool: return t in BEASTS).size()
		ck(beasts == 1 and gang in [1, 2] and gang + beasts == types.size(),
				"%s: %d bandit(s) and one beast (%s)" % [spawner.name, gang, types])

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

	print("[5] D830: the road is flat — no step or ledge where the hero walks")
	var fg: TileMapLayer = game.map.get_node("TileMap/Foreground")
	var raised: Array[int] = []  # колонки, де щось стоїть над підлогою (рядок 12, y 384)
	for c: Vector2i in fg.get_used_cells():
		if c.y < 12 and not raised.has(c.x):
			raised.append(c.x)
	ck(raised.is_empty(), "every tile column tops out at the floor y 384 (raised columns %s)" % [raised])
	# Справжнім променем згори вниз, як падає герой: під кожними 32 px дороги — підлога y 384 (дахи крамниці й
	# башти — уступи над дорогою, вище за y 200, їх промінь не бачить).
	var space := player.get_world_2d().direct_space_state
	var bumps: Array[String] = []
	for x in range(16, 5184, 32):
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, 200.0), Vector2(x, 600.0), fg.tile_set.get_physics_layer_collision_layer(0))
		var hit: Dictionary = space.intersect_ray(q)
		while not hit.is_empty() and not hit.collider is TileMapLayer:  # тіла на дорозі (вороги, скриня) — не підлога
			q.exclude = q.exclude + [hit.rid]
			hit = space.intersect_ray(q)
		if hit.is_empty() or absf((hit.position as Vector2).y - 384.0) > 0.5:
			bumps.append("x %d → %s" % [x, "nothing" if hit.is_empty() else str((hit.position as Vector2).y)])
	ck(bumps.is_empty(), "the floor under the whole road is at y 384 (%s)" % [bumps])

	print("[4] The east edge leads to Zahra's Rest")
	player.global_position = Vector2(5100.0, 340.0)
	Input.action_press(&"move_right")
	for i in 240:
		await physics_frame
		if game.map.scene_file_path.ends_with("ZahraRest.tscn"):
			break
	Input.action_release(&"move_right")
	ck(game.map.scene_file_path.ends_with("ZahraRest.tscn"), "walking east loads ZahraRest (%s)" % game.map.scene_file_path)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
