extends SceneTree

## Сейв → завантаження (Sapega, 2026-10-12): гравець зʼявляється в тій кімнаті,
## де зберігся (а не в Canyon), і відкрита частина карти MetSys зберігається.
## Пише лише в user://verify_save_load_room/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_save_load_room.gd

const TEST_DIR := "user://verify_save_load_room/"
const TEST_SLOT := 1

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game

func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	var metsys: Node = root.get_node("MetSys")
	save_system.set_save_dir(TEST_DIR)
	var slot_path: String = save_system.get_slot_path(TEST_SLOT)
	ck(slot_path.begins_with(TEST_DIR), "tests write only to %s" % TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)

	print("[1] Save on the Desert Road with part of the map explored")
	set_meta("start_new_game", true)
	var game: Node = await _boot()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 20: await physics_frame
	var road_room: String = metsys.get_current_room_name()
	var explored: float = metsys.get_explored_ratio()
	ck(explored > 0.0, "some of the map is explored (%.3f)" % explored)
	# Зміна налаштування посеред гри (гучність, мова) перечитувала слот через SaveManager і
	# відкочувала карту MetSys до стану з диска — сейв після цього писав порожню карту.
	ck(game.save_game(), "an earlier save exists on disk")
	game.player.global_position = Vector2(1500, 344)  # далі по дорозі — нові клітинки
	for i in 10: await physics_frame
	var explored_more: float = metsys.get_explored_ratio()
	ck(explored_more > explored, "walking on explores more (%.3f → %.3f)" % [explored, explored_more])
	save_system.save_game_settings()
	ck(is_equal_approx(metsys.get_explored_ratio(), explored_more), "changing a setting mid-game keeps the explored map (%.3f)" % metsys.get_explored_ratio())
	# B82: справжня взаємодія з точкою збереження — вона ставить героя на себе й відкриває екран сейву;
	# герой стає на землю, і екран зберігає через Game.save_game() (LoadGameMenu._save_via_game).
	var save_point: Node2D = game.map.get_node(^"SavePoint_BeforeCity")
	save_point.call(&"_on_interacted")
	var ui = root.get_node("ServiceLocator").get_ui_manager()
	ck(ui.current_state_name == "SaveGameState", "the save point opens the save screen (%s)" % ui.current_state_name)
	ui.close_state()
	for i in 30: await physics_frame
	var saved_pos: Vector2 = game.player.global_position
	ck(saved_pos.distance_to(save_point.global_position) < 40.0, "hero stands at the save point (%s)" % saved_pos)
	explored = metsys.get_explored_ratio()
	var xp = root.get_node("ServiceLocator").get_xp_manager()
	xp.reset()
	xp.add_xp(xp.xp_for_next_level + xp.xp_for_next_level / 2 + 30)  # B79: level 2 and 80 XP towards 3
	var saved_level: int = xp.current_level
	var saved_xp: int = xp.current_xp
	ck(game.save_game(), "save_game() wrote slot %d" % TEST_SLOT)
	var text := FileAccess.get_file_as_string(slot_path)
	ck(text.contains("discovered_cells"), "slot file holds the MetSys map")
	# Після сейву йдемо геть — в іншу кімнату: завантаження має повернути на точку збереження.
	await game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 20: await physics_frame
	ck(metsys.get_current_room_name() != road_room, "walked off to another room before loading (%s)" % metsys.get_current_room_name())
	game.queue_free()
	for i in 4: await process_frame
	xp.reset()

	print("[2] Load it back (as LoadGameMenu._load_slot() does)")
	set_meta("save_file_path", slot_path)
	set_meta("start_new_game", false)
	game = await _boot()
	ck(metsys.get_current_room_name() == road_room, "back on the Desert Road (%s, saved %s)" % [metsys.get_current_room_name(), road_room])
	ck(is_equal_approx(metsys.get_explored_ratio(), explored), "explored map restored (%.3f vs %.3f)" % [metsys.get_explored_ratio(), explored])
	ck(game.player.global_position.distance_to(saved_pos) < 4.0,
			"hero is back at the save point (%s, saved %s) — B82" % [game.player.global_position, saved_pos])
	ck(game.player.global_position.distance_to(game.map.get_node(^"Arrival_Start").global_position) > 1000.0,
			"not at the room's arrival marker — B82")
	ck(xp.current_level == saved_level and xp.current_xp == saved_xp and saved_level > 1,
			"level and XP restored (level %d, %d XP; saved %d, %d) — B79" % [xp.current_level, xp.current_xp, saved_level, saved_xp])

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
