extends SceneTree

## Лабораторія (B53, D174): тригери ведуть розмови компаньйона → тест межі → бій; сейв посеред
## лабораторії стартує зі стану за прапорцями.
##   godot --headless --path . --script res://SampleProject/UI/verify_laboratory.gd

const LAB := "res://SampleProject/Maps/Laboratory.tscn"

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_player.accept()
			for f in 6: await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _alive(lab: Node) -> Array:
	return lab.find_children("*", "CharacterBody2D", true, false).filter(
			func(n): return n.is_in_group(&"enemies") and n.is_alive())

## Гравець проходить крізь тригер на x і дочитує розмову.
func _walk_to(game: Node, dm: Node, x: float) -> void:
	game.player.global_position = Vector2(x, 340)
	for i in 10: await physics_frame
	await _drain(dm)

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	await _drain(dm)

	print("[1] Fresh run: the lab waits in EXPLORE")
	game.teleport_to_room(LAB, ^"SavePoint_Entrance")
	for i in 20: await physics_frame
	var lab: Node = game.map
	ck(lab.get_current_state_name() == "EXPLORE", "EXPLORE (%s)" % lab.get_current_state_name())

	print("[2] Each trigger plays one companion talk, then the lab waits")
	var beats := [[430.0, "COMPANION_01", "lab_companion_01_complete"],
			[860.0, "COMPANION_02", "lab_companion_02_complete"],
			[1210.0, "COMPANION_03", "lab_companion_03_complete"]]
	for b in beats:
		await _walk_to(game, dm, b[0])
		ck(game.get_quest_flag(b[2]) and lab.get_current_state_name() == b[1],
				"x=%d → %s, %s set (%s)" % [b[0], b[1], b[2], lab.get_current_state_name()])
	ck(_alive(lab).is_empty(), "no enemies before the limit test")

	print("[3] Limit test → boss fight → after boss")
	await _walk_to(game, dm, 1600.0)
	for i in 30: await physics_frame
	await _drain(dm)
	for i in 240: await physics_frame
	ck(game.get_quest_flag("lab_limit_test_complete"), "lab_limit_test_complete set")
	ck(lab.get_current_state_name() == "BOSS_FIGHT" and not _alive(lab).is_empty(),
			"BOSS_FIGHT with enemies (%s, %d)" % [lab.get_current_state_name(), _alive(lab).size()])
	for round in 4:
		for e in _alive(lab):
			e.die()
		await create_timer(3.0).timeout
	await _drain(dm)
	ck(game.get_quest_flag("lab_boss_fight_complete"), "all dead → lab_boss_fight_complete")
	ck(game.get_quest_flag("lab_after_boss_complete") and lab.get_current_state_name() == "AFTER_BOSS",
			"AFTER_BOSS talk read (%s)" % lab.get_current_state_name())

	print("[4] A save made after the limit test restarts the fight (B53)")
	game.set_quest_flag("lab_boss_fight_complete", false)
	game.set_quest_flag("lab_after_boss_complete", false)
	var spawner: Node = lab.get_node("EnemySpawner")
	game.set_room_state(spawner._room, spawner.STATE_KEY, null)  # сейв до бою: убитих ще немає
	game.teleport_to_room(LAB, ^"SavePoint_PreBoss")
	for i in 20: await physics_frame
	await _drain(dm)
	for i in 240: await physics_frame
	lab = game.map
	ck(lab.get_current_state_name() == "BOSS_FIGHT" and not _alive(lab).is_empty(),
			"enters in BOSS_FIGHT with enemies (%s, %d)" % [lab.get_current_state_name(), _alive(lab).size()])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
