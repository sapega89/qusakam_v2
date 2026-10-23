extends SceneTree

## Витоки пам'яті на переходах між кімнатами (B73): коло через сім кімнат кілька разів; після першого кола
## (прогрів кешів) сирітських вузлів не має з'являтися, а статична пам'ять — рости. До B73 кожен перехід лишав
## повну копію кімнати сиротою: +374 вузли й +3,3 МБ за коло.
##   godot --headless --path . --script res://SampleProject/UI/verify_memory.gd

const ROOMS := [["Canyon", "Arrival"], ["Village", "Arrival"], ["DesertRoad", "Arrival_Start"], ["CityGates", "Arrival"],
	["City", "SavePoint"], ["MayorHall", "Arrival"], ["Laboratory", "SavePoint_PreBoss"]]
const LAPS := 3
const STATIC_GROWTH_MB := 1.0

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 6:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 5: await process_frame
		if not dm.is_dialogue_active():
			return

func _initialize() -> void:
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
	for f in ["canyon_abduction_complete"]:
		game.set_quest_flag(f, true)
	var warm_static := 0.0
	var warm_orphans := 0
	for lap in LAPS:
		for r in ROOMS:
			game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % r[0], NodePath(r[1]))
			for i in 12: await process_frame
			await _drain(dm)
		for i in 30: await process_frame
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		print("  lap %d: orphans %d, static %.1f MB" % [lap + 1, orphans, static_mb])
		if lap == 0:
			warm_static = static_mb
			warm_orphans = orphans
	var end_static := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var end_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	ck(end_orphans <= warm_orphans, "no orphan nodes pile up after lap 1 (%d → %d)" % [warm_orphans, end_orphans])
	ck(end_static - warm_static < STATIC_GROWTH_MB, "static memory flat after lap 1 (%+.1f MB)" % (end_static - warm_static))
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
