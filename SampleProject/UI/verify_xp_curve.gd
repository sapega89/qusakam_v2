extends SceneTree

## XP curve (BACKLOG 23, design/world_expansion_plan.md, D297): the intended route to the City, played kill by kill
## through the real XPManager. The kills are read from the room scenes (every EnemySpawnPoint) and the rewards from
## their EnemyStats — change a fight or a reward and this re-checks where level 5 lands.
##   1. The curve comes from Resources/Data/xp_curve.json.
##   2. Level 2 on the Desert Road (Healing Palm there, D252); level < 5 until the City Gates fight is done.
##   3. Level 5 on the last City Gates kill — the hero enters the City able to swear the oath (D280).
##   godot --headless --path . --script res://SampleProject/UI/verify_xp_curve.gd

## Rooms before the City in story order (story.json: Canyon I → Village → Canyon II → Desert Road → City Gates).
const ROUTE := ["Canyon", "Village", "DesertRoad", "CityGates"]
const OATH_LEVEL := 5

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
	for level in range(1, OATH_LEVEL):
		needs.append(xp.xp_for_next_level)
		xp.add_xp(xp.xp_for_next_level)
	var expected: Array[int] = []
	for level in range(1, OATH_LEVEL):
		expected.append(int(curve.first_level) + int(curve.step) * (level - 1))
	ck(needs == expected, "XP to the next level follows xp_curve.json (%s, expected %s)" % [needs, expected])

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

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
