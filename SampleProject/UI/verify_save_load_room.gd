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
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
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
	explored = explored_more
	ck(game.save_game(), "save_game() wrote slot %d" % TEST_SLOT)
	var text := FileAccess.get_file_as_string(slot_path)
	ck(text.contains("discovered_cells"), "slot file holds the MetSys map")
	game.queue_free()
	for i in 4: await process_frame

	print("[2] Load it back")
	set_meta("save_file_path", slot_path)
	game = await _boot()
	ck(metsys.get_current_room_name() == road_room, "back on the Desert Road (%s, saved %s)" % [metsys.get_current_room_name(), road_room])
	ck(is_equal_approx(metsys.get_explored_ratio(), explored), "explored map restored (%.3f vs %.3f)" % [metsys.get_explored_ratio(), explored])

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
