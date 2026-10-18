extends SceneTree

## Спуск з каньйону (Sapega, 2026-10-13): посередині сходів — кат-сцена Canyon_ExitCutscene,
## після неї гравець уже на дорозі. До повернення з села сходи — звичайні сходи.
##   godot --headless --path . --script res://SampleProject/UI/verify_canyon_exit.gd


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
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _enter_canyon(game: Node, flags: Dictionary) -> void:
	var all: Dictionary = game.get_quest_flags().duplicate()
	all.merge(flags, true)
	game.set_quest_flags(all)
	game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 20: await process_frame

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[0] Canyon I: the trigger plays Canyon_Exploration, the raid over black, then the ridge (Sapega, 2026-10-16)")
	await _enter_canyon(game, {"canyon_intro_complete": true})
	ck(game.map.get_current_state_name() == "EXPLORATION", "waits in EXPLORATION (%s)" % game.map.get_current_state_name())
	ck(started.is_empty(), "nothing plays before the trigger (%s)" % [started])
	var trigger: Area2D = game.map.get_node("StateChangeTrigger2")
	game.player.global_position = trigger.get_node("CollisionShape2D").global_position
	for i in 30: await process_frame
	ck(not started.is_empty() and started[0] == "Canyon_Exploration", "Canyon_Exploration first (%s)" % [started])
	await _drain(dm)
	# Напад на село — у Canyon, поверх чорного (Sapega, 2026-10-16).
	await _until(func() -> bool: return started.has("VillageAbduction"), 5.0)
	var fade: CanvasLayer = root.get_node_or_null(^"ScreenFade")
	ck(fade != null and fade.get_child(0).color.a > 0.9, "the raid plays over a black screen")
	ck(dm.current_dialogue_box.is_visible_in_tree() and dm.current_dialogue_box.get_parent().layer > fade.layer,
			"the dialogue box is shown above the black")
	await _drain(dm)
	await _until(func() -> bool: return started.has("Canyon_AbductionCutscene"), 5.0)
	ck(not root.has_node(^"ScreenFade"), "light again before Kusakam looks from the ridge")
	await _drain(dm)
	ck(started == ["Canyon_Exploration", "VillageAbduction", "Canyon_AbductionCutscene"], "raid, then the ridge (%s)" % [started])
	ck(game.get_quest_flag("canyon_exploration_complete") and game.get_quest_flag("canyon_abduction_complete"),
			"both flags set (journal: Explore the Canyon, Find a way forward)")
	started.clear()

	print("[1] Before the village the stairs are just stairs")
	await _enter_canyon(game, {"canyon_intro_complete": true, "canyon_exploration_complete": true})
	game.player.global_position = game.map.get_node(^"CanyonExitTrigger/CollisionShape2D").global_position
	for i in 30: await process_frame
	ck(not started.has("Canyon_ExitCutscene"), "no exit cutscene before the village (%s)" % [started])
	ck(game.map.scene_file_path.ends_with("Canyon.tscn"), "still in the Canyon")
	await _drain(dm)  # RoadToVillage: після викрадення, до села

	print("[2] After the village the middle of the stairs plays the descent")
	await _enter_canyon(game, {"canyon_abduction_complete": true, "village_abduction_complete": true,
			"village_arrival_complete": true, "village_fight_complete": true, "village_left_complete": true})
	ck(game.map.get_current_state_name() == "RELIC_PICKUP", "Canyon waits in RELIC_PICKUP (%s)" % game.map.get_current_state_name())
	game.player.global_position = game.map.get_node(^"CanyonExitTrigger/CollisionShape2D").global_position
	for i in 30: await process_frame
	ck(started.has("Canyon_ExitCutscene"), "Canyon_ExitCutscene plays (%s)" % [started])

	print("[3] The cutscene ends on the road")
	await _drain(dm)
	for i in 30: await process_frame
	ck(game.map.scene_file_path.ends_with("DesertRoad.tscn"), "player is on the Desert Road (%s)" % game.map.scene_file_path)
	var arrival: Node2D = game.map.get_node("ArrivalFromCanyon")
	ck(absf(game.player.global_position.x - arrival.global_position.x) < 48.0,
			"player stands at ArrivalFromCanyon (x=%.0f)" % game.player.global_position.x)
	ck(game.get_quest_flag("canyon_exit_complete"), "canyon_exit_complete set")
	ck(not game.player.event, "the player can move")

	print("[4] Enter shows the next bubble line at once (Sapega, 2026-10-16)")
	await _drain(dm)
	await _until(func() -> bool: return not dm.is_bubble_playing(), 5.0)
	dm.bubble_time_scale = 1.0  # справжні 2–6 с на репліку
	dm.start_dialogue("res://dialogue_quest/Canyon_Exploration.dqd")  # 4 репліки Кусакама
	for i in 3: await process_frame
	ck(dm.is_bubble_playing(), "the monologue plays as a bubble")
	var t0 := Time.get_ticks_msec()
	for line in 4:
		var press := InputEventAction.new()
		press.action = &"dq_accept"
		press.pressed = true
		Input.parse_input_event(press)
		for i in 3: await process_frame
	ck(not dm.is_bubble_playing(), "4 presses → monologue over in %d ms, not ~10 s" % (Time.get_ticks_msec() - t0))
	dm.bubble_time_scale = 0.0

	print("[5] The scene goes away mid-monologue (menu / new game / load)")
	dm.bubble_time_scale = 1.0
	dm.start_dialogue("res://dialogue_quest/Canyon_Exploration.dqd")
	for i in 3: await process_frame
	ck(dm.is_bubble_playing(), "a monologue is playing")
	var player: Node = game.player
	game.remove_child(player)  # облачко — дитина гравця, йде з ним, як при закритті Game
	for i in 3: await process_frame
	ck(not dm.is_bubble_playing(), "the monologue ended with its bubble, no show_line() on a freed node")
	game.add_child(player)
	dm.bubble_time_scale = 0.0
	started.clear()
	dm.start_dialogue("res://dialogue_quest/VillageAbduction.dqd")
	for i in 3: await process_frame
	ck(started == ["VillageAbduction"], "the next dialogue still plays, not stuck in the queue (%s)" % [started])
	await _drain(dm)

	print("RESULT:" + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
