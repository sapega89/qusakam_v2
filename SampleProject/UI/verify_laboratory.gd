extends SceneTree

## Коридори лабораторії (B53, D174, D303): тригер на нижньому поверсі веде в бій; сейв посеред
## лабораторії стартує зі стану за прапорцями. Компаньйони — у LabCells (D305, verify_lab_cells.gd).
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
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
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
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
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

	print("[1b] Hidden tiles still hold the hero on every floor; the far plane moves slower than the room (D246)")
	ck(not lab.get_node("TileMap/Foreground").visible, "the collision tiles are hidden — the drawn surfaces show")
	for floor_y in [384.0, 864.0, 1344.0]:
		game.player.global_position = Vector2(900, floor_y - 40)
		for i in 30: await physics_frame
		ck(game.player.is_on_floor() and absf(game.player.global_position.y - floor_y + 24) < 4,
				"the hero stands on the floor at y %d (%s)" % [floor_y, game.player.global_position])
	var far: Node2D = lab.get_node("Atmosphere/Far1/Sprite")
	game.player.global_position = Vector2(300, 344)
	for i in 60: await physics_frame
	var camera: Camera2D = root.get_camera_2d()
	var far_x := far.global_position.x
	var cam_x := camera.get_screen_center_position().x
	game.player.global_position = Vector2(1100, 344)
	for i in 60: await physics_frame
	var cam_moved := camera.get_screen_center_position().x - cam_x
	# шар зсувається на (1 − 0.4) руху камери; повтор кожні 864 px перескакує — тому за модулем
	var off := fposmod(far.global_position.x - far_x - 0.6 * cam_moved, 864.0)
	ck(cam_moved > 300.0 and minf(off, 864.0 - off) < 4.0,
			"the far plane follows the camera at 0.6 of its move (camera %.0f, off %.1f)" % [cam_moved, off])
	game.player.global_position = lab.get_node("SavePoint_Entrance").global_position
	for i in 10: await physics_frame

	print("[2] The companions met in the cells (D305): no companion talks or limit test in the corridors")
	for node_name in ["CompanionNPC_alisia", "CompanionNPC_astrit", "CompanionNPC_urizen", "StateChangeTrigger_Companion01",
			"StateChangeTrigger_Companion02", "StateChangeTrigger_Companion03", "StateChangeTrigger_LimitTest"]:
		ck(not lab.has_node(node_name), "no %s" % node_name)
	ck(_alive(lab).is_empty(), "no enemies before the fight trigger")

	print("[3] Fight trigger → fight → after boss")
	await _walk_to(game, dm, lab.get_node(^"StateChangeTrigger_Fight"))
	for i in 30: await physics_frame
	await _drain(dm)
	await _until(func(): return _fighting(lab), 8.0)
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

	print("[4] A save made before the fight: the corridors wait, the trigger restarts the fight (B53)")
	game.set_quest_flag("lab_boss_fight_complete", false)
	game.set_quest_flag("lab_after_boss_complete", false)
	var spawner: Node = lab.get_node("EnemySpawner")
	game.set_room_state(spawner._room, spawner.state_key, null)  # сейв до бою: убитих ще немає
	game.teleport_to_room(LAB, ^"SavePoint_PreBoss")
	for i in 20: await physics_frame
	await _drain(dm)
	lab = game.map
	ck(lab.get_current_state_name() == "EXPLORE", "enters in EXPLORE (%s)" % lab.get_current_state_name())
	await _walk_to(game, dm, lab.get_node(^"StateChangeTrigger_Fight"))
	await _until(func(): return _fighting(lab), 8.0)
	ck(lab.get_current_state_name() == "BOSS_FIGHT" and not _alive(lab).is_empty(),
			"enters in BOSS_FIGHT with enemies (%s, %d)" % [lab.get_current_state_name(), _alive(lab).size()])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
