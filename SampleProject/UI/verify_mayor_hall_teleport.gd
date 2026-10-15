extends SceneTree

## Будинок мера → Лабораторія (Sapega, 2026-10-12): після розмови з мером гравця
## телепортує в Лабораторію, на окремий шар MetSys без дороги назад.
##   godot --headless --path . --script res://SampleProject/UI/verify_mayor_hall_teleport.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame
	await process_frame
	var bus: Node = root.get_node("EventBus")
	var metsys: Node = root.get_node("MetSys")
	# Як кнопка New Game: без цього Game.tscn вантажить справжній сейв гравця.
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame

	print("[1] Standing in the Mayor's Hall")
	var loads_before: int = game._load_room_call_count
	game.teleport_to_room("res://SampleProject/Maps/MayorHall.tscn", ^"Arrival")
	for i in 20: await physics_frame
	# B51: модуль переходів вантажив кімнату вдруге після кожного телепорту.
	ck(game._load_room_call_count - loads_before == 1, "one teleport loads the room once (%d)" % (game._load_room_call_count - loads_before))
	ck(game.map != null and game.map.scene_file_path.ends_with("MayorHall.tscn"), "in MayorHall (%s)" % (game.map.scene_file_path if game.map else "null"))

	print("[2] Another dialogue ending does nothing")
	bus.dialogue_finished.emit("CityGates_AfterFight")
	for i in 4: await process_frame
	ck(game.map.scene_file_path.ends_with("MayorHall.tscn"), "still in MayorHall")

	print("[3] The mayor's talk ends → Laboratory")
	loads_before = game._load_room_call_count
	bus.dialogue_finished.emit("res://dialogue_quest/City_MayorHall.dqd")
	for i in 20: await physics_frame
	ck(game._load_room_call_count - loads_before == 1, "the lab is loaded once (%d)" % (game._load_room_call_count - loads_before))
	ck(game.map != null and game.map.scene_file_path.ends_with("Laboratory.tscn"), "in Laboratory (%s)" % (game.map.scene_file_path if game.map else "null"))
	ck(metsys.current_layer == 2, "MetSys layer 2 (%d)" % metsys.current_layer)
	var entrance: Node2D = game.map.get_node("SavePoint_Entrance")
	# Гравець ставиться в точку входу і за кілька кадрів приземляється на підлогу.
	var offset: Vector2 = game.player.global_position - entrance.global_position
	ck(absf(offset.x) < 1.0 and absf(offset.y) < 32.0, "player at the lab entrance (offset %s)" % offset)
	ck(game.get_quest_flag("city_mayor_hall_complete"), "city_mayor_hall_complete set")
	ck(get_nodes_in_group("save_points").all(func(n: Node) -> bool: return not n.get_parent().scene_file_path.ends_with("MayorHall.tscn")), "MayorHall is gone")

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
