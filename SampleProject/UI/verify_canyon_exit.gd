extends SceneTree

## Спуск з каньйону (Sapega, 2026-10-13): посередині сходів — кат-сцена Canyon_ExitCutscene,
## після неї гравець уже на дорозі. До повернення з села сходи — звичайні сходи.
##   godot --headless --path . --script res://SampleProject/UI/verify_canyon_exit.gd

const STAIRS_MIDDLE := Vector2(550, 590)

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
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[1] Before the village the stairs are just stairs")
	await _enter_canyon(game, {"canyon_intro_complete": true, "canyon_exploration_complete": true})
	game.player.global_position = STAIRS_MIDDLE
	for i in 30: await process_frame
	ck(not started.has("Canyon_ExitCutscene"), "no exit cutscene before the village (%s)" % [started])
	ck(game.map.scene_file_path.ends_with("Canyon.tscn"), "still in the Canyon")
	await _drain(dm)  # кат-сцена викрадення з цього кроку

	print("[2] After the village the middle of the stairs plays the descent")
	await _enter_canyon(game, {"canyon_abduction_complete": true, "village_abduction_complete": true,
			"village_arrival_complete": true, "village_fight_complete": true, "village_left_complete": true})
	ck(game.map.get_current_state_name() == "RELIC_PICKUP", "Canyon waits in RELIC_PICKUP (%s)" % game.map.get_current_state_name())
	game.player.global_position = STAIRS_MIDDLE
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

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
