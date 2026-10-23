extends SceneTree

## XP curve (BACKLOG 23, design/world_expansion_plan.md, D297): the intended route to the City, played kill by kill
## through the real XPManager. The kills are read from the room scenes (every EnemySpawnPoint) and the rewards from
## their EnemyStats — change a fight or a reward and this re-checks where level 5 lands.
##   1. The curve comes from Resources/Data/xp_curve.json.
##   2. Level 2 on the Desert Road (Healing Palm there, D252); level < 5 until the City Gates fight is done.
##   3. Level 5 on the last City Gates kill — the hero enters the City able to swear the oath (D280).
##   4. Straight on through the Mayor Hall and the Laboratory (D492): level 16–17 when the Laboratory ends.
##   5. A little farming — the Laboratory corridors again, at most FARM_ROUNDS times — reaches the cap (20, D488).
##   6. At the cap XP no longer counts.
##   7. A New Game in the same session starts again at level 1, with an empty bag and a fresh hero (B79).
##   godot --headless --path . --script res://SampleProject/UI/verify_xp_curve.gd

## Rooms before the City in story order (story.json: Canyon I → Village → Canyon II → Desert Road → City Gates).
const ROUTE := ["Canyon", "Village", "DesertRoad", "CityGates"]
const OATH_LEVEL := 5
## After the City, story order: Mayor Hall (the Brass Collector) → Laboratory cells → corridors → the djinn → outside.
const LAB_ROUTE := ["City", "MayorHall", "LabCells", "Laboratory", "LabBoss", "LaboratoryOutside"]
const LAB_END_LEVELS := [16, 17]
## "A little farming" (D492): rounds of the respawning Laboratory corridors after the djinn.
const FARM_ROUNDS := 2
const Kit = preload("res://SampleProject/UI/input_kit.gd")

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	var xp = root.get_node("ServiceLocator").get_xp_manager()
	var spawn_point_script: Script = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")

	print("[1] the curve is data")
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/xp_curve.json"))
	xp.reset()
	var needs: Array[int] = []
	for level in range(1, xp.MAX_LEVEL):
		needs.append(xp.xp_for_next_level)
		xp.add_xp(xp.xp_for_next_level)
	var expected: Array[int] = []
	for step in curve.to_next:
		expected.append(int(step))
	ck(needs == expected, "XP to the next level follows xp_curve.json (%s, expected %s)" % [needs, expected])
	ck(needs.slice(0, OATH_LEVEL - 1) == [100, 150, 200, 250], "levels 1-4 keep D297's 100, 150, 200, 250 (%s)" % [needs.slice(0, OATH_LEVEL - 1)])

	print("[2] the route, kill by kill")
	xp.reset()
	var total := 0
	for room_name: String in ROUTE:
		var room: Node = (load("res://SampleProject/Maps/%s.tscn" % room_name) as PackedScene).instantiate()
		var kills: Array[String] = []
		var level_before: int = xp.current_level
		for point: Node in room.find_children("*", "Node2D", true, false):
			if point.get_script() != spawn_point_script:
				continue
			var stats = point.enemy_stats()
			ck(stats.xp_reward > 0, "%s %s (%s) gives XP" % [room_name, point.name, point.enemy_type])
			if room_name == "CityGates":
				ck(xp.current_level < OATH_LEVEL, "level %d before the City Gates kill %s" % [xp.current_level, point.name])
			xp.add_xp(stats.xp_reward)
			total += stats.xp_reward
			kills.append(point.enemy_type)
		room.free()
		print("    %-10s %2d kills %s → %d XP, level %d → %d" % [room_name, kills.size(), kills, total, level_before, xp.current_level])
		if room_name == "DesertRoad":
			ck(xp.current_level >= 2 and xp.current_level < OATH_LEVEL,
					"after the Desert Road: level %d (≥ 2 for Healing Palm, < %d before the City Gates)" % [xp.current_level, OATH_LEVEL])

	print("[3] at the City")
	ck(xp.current_level == OATH_LEVEL, "the hero enters the City at level %d (%d XP, expected %d)" % [xp.current_level, total, OATH_LEVEL])

	print("[4] straight on through the Laboratory (D492)")
	for room_name: String in LAB_ROUTE:
		var level_before: int = xp.current_level
		var room_xp := _room_xp(room_name, spawn_point_script)
		xp.add_xp(room_xp)
		total += room_xp
		print("    %-17s +%3d XP → %4d XP, level %d → %d" % [room_name, room_xp, total, level_before, xp.current_level])
	ck(xp.current_level in LAB_END_LEVELS, "the Laboratory ends at level %d (%d XP, expected %s)" % [xp.current_level, total, LAB_END_LEVELS])

	print("[5] a little farming reaches the cap (D488, D492)")
	var corridors := _room_xp("Laboratory", spawn_point_script)
	var rounds := 0
	while xp.current_level < xp.MAX_LEVEL and rounds < FARM_ROUNDS:
		xp.add_xp(corridors)
		rounds += 1
		print("    corridors again #%d +%d XP → level %d" % [rounds, corridors, xp.current_level])
	ck(xp.current_level == xp.MAX_LEVEL, "level %d after %d rounds of the corridors (cap %d within %d)" % [xp.current_level, rounds, xp.MAX_LEVEL, FARM_ROUNDS])
	ck(rounds == FARM_ROUNDS, "not sooner than %d rounds (took %d): farming is still needed" % [FARM_ROUNDS, rounds])

	print("[6] at the cap XP no longer counts")
	var gained := [0]
	var on_gain := func(_amount: int, _total: int) -> void: gained[0] += 1
	xp.xp_gained.connect(on_gain)
	xp.add_xp(5000)
	xp.xp_gained.disconnect(on_gain)
	ck(xp.current_level == xp.MAX_LEVEL and xp.current_xp == 0 and gained[0] == 0, "level %d, %d XP, %d xp_gained signals" % [xp.current_level, xp.current_xp, gained[0]])
	ck(xp.is_max_level() and xp.get_xp_percentage() == 1.0, "is_max_level, the bar full")
	xp.restore(99, 4000)
	ck(xp.current_level == xp.MAX_LEVEL and xp.current_xp == 0, "a save at the old cap 99 loads at %d (level %d, %d XP)" % [xp.MAX_LEVEL, xp.current_level, xp.current_xp])

	print("[7] a New Game in the same session starts at level 1 (B79)")
	var sl: Node = root.get_node("ServiceLocator")
	xp.add_xp(500)
	sl.get_inventory_manager().add_item("potion", 3)
	sl.get_game_manager().player_state.oath = "paladin"
	ck(xp.current_level > 1, "XP of the last game kept in the autoload (level %d)" % xp.current_level)
	var game: Node = await Kit.boot(self)
	ck(xp.current_level == 1 and xp.current_xp == 0, "New Game → level %d, %d XP (expected 1, 0)" % [xp.current_level, xp.current_xp])
	ck(sl.get_inventory_manager().get_item_count("potion") == 0, "New Game → the last game's potions are gone")
	ck(sl.get_game_manager().player_state.oath == "", "New Game → no oath (player state reset)")
	game.queue_free()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


## XP of every enemy in the room: its spawn points and its bosses (EnemyStats on the node, MayorHall, LabBoss).
func _room_xp(room_name: String, spawn_point_script: Script) -> int:
	var room: Node = (load("res://SampleProject/Maps/%s.tscn" % room_name) as PackedScene).instantiate()
	var sum := 0
	for node: Node in room.find_children("*", "", true, false):
		if node.get_script() == spawn_point_script:
			sum += node.enemy_stats().xp_reward
		elif "enemy_stats" in node and node.enemy_stats is EnemyStats:
			sum += node.enemy_stats.xp_reward
	room.free()
	return sum
