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

## Чекає, доки cond не стане true, але не довше max_s — далі ck() скаже, чого не дочекались.
func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await physics_frame

func _fighting(lab: Node) -> bool:
	return lab.get_current_state_name() == "BOSS_FIGHT" and not _alive(lab).is_empty()

## Гравець проходить крізь тригер (лабораторія на три поверхи, D225) і дочитує розмову.
func _walk_to(game: Node, dm: Node, trigger: Node2D) -> void:
	game.player.global_position = trigger.global_position
	for i in 10: await physics_frame
	await _drain(dm)

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
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
	var beats := [["StateChangeTrigger_Companion01", "COMPANION_01", "lab_companion_01_complete"],
			["StateChangeTrigger_Companion02", "COMPANION_02", "lab_companion_02_complete"],
			["StateChangeTrigger_Companion03", "COMPANION_03", "lab_companion_03_complete"]]
	for b in beats:
		await _walk_to(game, dm, lab.get_node(b[0]))
		ck(game.get_quest_flag(b[2]) and lab.get_current_state_name() == b[1],
				"%s → %s, %s set (%s)" % [b[0], b[1], b[2], lab.get_current_state_name()])
	ck(_alive(lab).is_empty(), "no enemies before the limit test")

	print("[3] Limit test → boss fight → after boss")
	await _walk_to(game, dm, lab.get_node(^"StateChangeTrigger_LimitTest"))
	for i in 30: await physics_frame
	await _drain(dm)
	await _until(func(): return _fighting(lab), 8.0)
	ck(game.get_quest_flag("lab_limit_test_complete"), "lab_limit_test_complete set")
	ck(lab.get_current_state_name() == "BOSS_FIGHT" and not _alive(lab).is_empty(),
			"BOSS_FIGHT with enemies (%s, %d)" % [lab.get_current_state_name(), _alive(lab).size()])
	# Хвилі доспавнюються після смертей — добиваємо, доки бій не завершиться.
	await _until(func():
		for e in _alive(lab):
			e.die()
		return game.get_quest_flag("lab_boss_fight_complete"), 15.0)
	await _until(func(): return dm.is_dialogue_active(), 5.0)
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
	lab = game.map
	await _until(func(): return _fighting(lab), 8.0)
	ck(lab.get_current_state_name() == "BOSS_FIGHT" and not _alive(lab).is_empty(),
			"enters in BOSS_FIGHT with enemies (%s, %d)" % [lab.get_current_state_name(), _alive(lab).size()])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
