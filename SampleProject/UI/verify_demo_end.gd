extends SceneTree

## Кінець демо за лабораторією (B66): перший вихід у LaboratoryOutside — розмови й екран кінця демо;
## повернутися в лабораторію й вийти знову — екран кінця демо теж (раніше машина станів застрягала).
##   godot --headless --path . --script res://SampleProject/UI/verify_demo_end.gd

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

func _end_screens(game: Node) -> Array:
	return game.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("DemoEndScreen.gd"))

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	for f in ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete", "lab_cells_cutscene_complete", "lab_acquaintance_complete", "lab_boss_fight_complete", "lab_after_boss_complete"]:
		game.set_quest_flag(f, true)

	print("[1] First time out of the laboratory: the talks, then the demo end screen")
	game.teleport_to_room("res://SampleProject/Maps/LaboratoryOutside.tscn", ^"Arrival")
	for i in 20: await process_frame
	await _drain(dm)
	for i in 30: await process_frame
	ck(game.get_quest_flag("lab_outside_complete") and game.get_quest_flag("demo_end_complete"), "both closing talks read")
	ck(_end_screens(game).size() == 1, "the demo end screen shows (%d)" % _end_screens(game).size())
	for s in _end_screens(game):
		s.queue_free()
	await process_frame

	print("[2] Back into the laboratory and out again: the demo still ends (B66)")
	game.teleport_to_room("res://SampleProject/Maps/Laboratory.tscn", ^"SavePoint_PreBoss")
	for i in 20: await process_frame
	await _drain(dm)
	game.teleport_to_room("res://SampleProject/Maps/LaboratoryOutside.tscn", ^"Arrival")
	for i in 30: await process_frame
	await _drain(dm)
	ck(_end_screens(game).size() == 1, "the demo end screen shows again (%d)" % _end_screens(game).size())

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
