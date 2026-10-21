extends SceneTree

## Стан кімнат (room_state_plan, слайс 1): що записано про кімнату, переживає вихід з неї,
## сейв і завантаження, а нова гра його стирає.
## Пише лише в user://verify_room_state/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_room_state.gd

const TEST_DIR := "user://verify_room_state/"
const TEST_SLOT := 1

var fails: Array[String] = []
var started: Array[String] = []  # які діалоги стартували
const WAVES_TIME := 4.0

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game

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

func _enemies(game: Node) -> Array:
	return game.map.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())

func _by_name(nodes: Array, node_name: String) -> Node:
	for n in nodes:
		if String(n.name) == node_name:
			return n
	return null

func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	var metsys: Node = root.get_node("MetSys")
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)

	print("[1] A room's state survives leaving it")
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = await _boot()
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 10: await physics_frame
	var road: String = metsys.get_current_room_name()
	game.set_room_state(road, "test_key", 42)
	game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 10: await physics_frame
	ck(metsys.get_current_room_name() != road, "left the road (%s)" % metsys.get_current_room_name())
	ck(game.get_room_state(road, "test_key") == 42, "the road's state is still there")
	ck(game.get_room_state(metsys.get_current_room_name(), "test_key") == null, "other rooms do not see it")

	print("[2] Save and load keep it")
	ck(game.save_game(), "save_game()")
	game.queue_free()
	for i in 4: await process_frame
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	ck(game.get_room_state(road, "test_key") == 42, "restored from the save (%s)" % game.get_room_state(road, "test_key"))
	game.queue_free()
	for i in 4: await process_frame

	print("[3] New Game starts clean")
	set_meta("start_new_game", true)
	game = await _boot()
	ck(game.get_room_state(road, "test_key") == null, "no room state in a new game")

	print("[4] Leaving mid-fight: the dead stay dead, the living keep HP, no fight line again (D152)")
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	await _drain(dm)
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"ArrivalFromCanyon")
	for k in 3:
		await create_timer(1.0).timeout
		await _drain(dm)
	var enemies := _enemies(game)
	ck(enemies.size() == 4, "4 enemies on the road (%d)" % enemies.size())
	var hurt: Node = enemies[0]
	var hurt_name := String(hurt.name)
	hurt.take_damage(30)
	enemies[1].take_damage(1000)
	for i in 10: await physics_frame
	var hurt_hp: int = hurt.current_health
	ck(hurt_hp < hurt.Max_Health, "one enemy hurt (%d / %d)" % [hurt_hp, hurt.Max_Health])
	game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 20: await physics_frame
	started.clear()
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"ArrivalFromCanyon")
	await create_timer(WAVES_TIME).timeout  # DesertRoad спавнить хвилями: 2 + 2 через 1.5 с
	ck(not started.has("DesertRoad_Fight"), "the fight line is not played again (%s)" % [started])
	enemies = _enemies(game)
	ck(enemies.size() == 3, "3 enemies back — the killed one stays dead (%d)" % enemies.size())
	var back: Node = _by_name(enemies, hurt_name)
	ck(back != null and back.current_health == hurt_hp, "the hurt one keeps its HP (%s, was %d)" % [back.current_health if back else "gone", hurt_hp])

	print("[5] …and the same after save and load")
	ck(game.save_game(), "save_game() mid-fight")
	game.queue_free()
	for i in 4: await process_frame
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	started.clear()
	game = await _boot()
	await create_timer(WAVES_TIME).timeout
	ck(not started.has("DesertRoad_Fight"), "no fight line after loading (%s)" % [started])
	enemies = _enemies(game)
	ck(enemies.size() == 3, "3 enemies after loading (%d)" % enemies.size())
	back = _by_name(enemies, hurt_name)
	ck(back != null and back.current_health == hurt_hp, "HP survives the save (%s, was %d)" % [back.current_health if back else "gone", hurt_hp])
	for e in enemies:
		e.take_damage(1000)
	for i in 10: await physics_frame
	ck(game.get_quest_flag("desert_road_fight_complete"), "killing the rest still wins the fight")

	print("[6] City Gates: the guards are still there after leaving and coming back")
	game.set_quest_flag("city_gates_intro_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for k in 3:
		await create_timer(1.0).timeout
		await _drain(dm)
	await create_timer(WAVES_TIME).timeout
	var guards := _enemies(game)
	ck(guards.size() == 3, "3 guards at the gates (%d)" % guards.size())
	guards[0].take_damage(30)
	for i in 10: await physics_frame
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"SavePoint_BeforeCity")
	for i in 20: await physics_frame
	started.clear()
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	await create_timer(WAVES_TIME).timeout
	ck(not started.has("CityGates_Fight"), "no fight line on return (%s)" % [started])
	ck(_enemies(game).size() == 3, "all 3 guards back (%d)" % _enemies(game).size())

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
