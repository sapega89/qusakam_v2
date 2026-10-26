extends SceneTree

## Лабораторія на кімнати (D303, черга 9.4): LabCells → коридори (Laboratory, верхній поверх) → назад і знову →
## з нижнього поверху в LabBoss (джин уже переможений) — дверима (справжнє E, room_art_audit: прохід крізь намальовану
## стіну став парою залізних дверей); з LabBoss герой сам іде («праворуч») крізь ґрати в LaboratoryOutside.
## На кожному переході: нова кімната, герой на її підлозі біля дверей, якими вийде назад, або біля краю.
##   godot --headless --path . --script res://SampleProject/UI/verify_lab_rooms.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const CELLS := "res://SampleProject/Maps/LabCells.tscn"

var fails: Array[String] = []
var game: Node

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

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await physics_frame

func _room() -> String:
	return game.map.scene_file_path.get_file().get_basename() if game.map else ""

## Тримає [param action], доки герой не опиниться в кімнаті [param room]; тоді відпускає й дає встати.
## Висоту ступнів у межах клітинки до і після порівнює: прохід — на одному рівні підлоги.
func _walk_into(action: StringName, room: String, label: String) -> void:
	var before := _room()
	var feet_before: float = fposmod(game.player.global_position.y, 480.0)
	Input.action_press(action)
	await _until(func() -> bool: return _room() == room, 20.0)
	for i in 20: await physics_frame
	Input.action_release(action)
	for i in 30: await physics_frame
	var p: Node2D = game.player
	ck(_room() == room, "%s: %s → %s (%s)" % [label, before, room, _room()])
	ck(p.is_on_floor(), "%s: the hero stands on the floor (%s)" % [label, p.global_position])
	var feet_after: float = fposmod(p.global_position.y, 480.0)
	ck(absf(feet_after - feet_before) < 8.0, "%s: same floor height across the door (%.0f → %.0f)" % [label, feet_before, feet_after])
	var edge: float = 0.0 if action == &"move_right" else game.map.get_node(^"RoomInstance").get_size().x
	ck(absf(p.position.x - edge) < 260.0, "%s: just inside the edge (x %.0f, edge %.0f)" % [label, p.position.x, edge])

## Герой біля дверей [param door], E; чекає кімнату [param room]: герой на підлозі біля дверей, що ведуть назад.
func _door_into(door: String, room: String, label: String) -> void:
	var before := _room()
	var node: RoomDoor = game.map.get_node(door)
	game.place_player(node.global_position)
	for i in 30: await physics_frame
	ck(node.interactable.player_nearby and node.interactable.enabled, "%s: %s offers Enter" % [label, door])
	await Kit.key(self, KEY_E)
	await _until(func() -> bool: return _room() == room, 20.0)
	for i in 40: await physics_frame
	var p: Node2D = game.player
	ck(_room() == room, "%s: %s → %s (%s)" % [label, before, room, _room()])
	ck(p.is_on_floor(), "%s: the hero stands on the floor (%s)" % [label, p.global_position])
	var back: Node2D = game.map.get_node(node.arrival)
	ck(absf(p.global_position.x - back.global_position.x) < 48.0, "%s: in front of %s, the door back (x %.0f)" % [label, back.name, p.global_position.x])

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)

	print("[1] The cells: the hero lands in his cell, on the floor")
	# Тут — лише двері й підлоги: сюжет камер (кат-сцена, знайомство, D304/D305) пройдено — verify_lab_cells.gd.
	for f in ["lab_cells_cutscene_complete", "lab_acquaintance_complete", "lab_companion_01_complete",
			"lab_companion_02_complete", "lab_companion_03_complete"]:
		game.set_quest_flag(f, true)
	await game.teleport_to_room(CELLS, ^"Arrival")
	for i in 30: await physics_frame
	ck(_room() == "LabCells" and game.player.is_on_floor(), "in LabCells on the floor (%s, %s)" % [_room(), game.player.global_position])
	for n in ["Cells", "Bars", "Table", "Malik", "Scientist", "Prisoner"]:
		ck(game.map.has_node(n), "LabCells has %s" % n)

	print("[2] East out of the cells into the corridors' top storey, and back")
	await _door_into("CorridorDoor", "Laboratory", "cells → corridors")
	await _door_into("CellsDoor", "LabCells", "corridors → cells")
	await _door_into("CorridorDoor", "Laboratory", "cells → corridors again")
	await _drain(dm)

	print("[3] From the corridors' bottom storey east into the boss hall (the mercenary already beaten — the gates are up)")
	# Бій і замкнена зала — verify_lab_boss.gd (9.7); тут лише двері.
	for flag in ["lab_boss_talk_complete", "lab_boss_fight_complete", "lab_after_boss_complete"]:
		game.set_quest_flag(flag, true)
	await _drain(dm)
	await _door_into("BossDoor", "LabBoss", "corridors → boss hall")
	ck(game.map.has_node("Gates"), "the boss hall has its gates")

	print("[4] Through the boss hall out into the open")
	await _walk_into(&"move_right", "LaboratoryOutside", "boss hall → outside")
	await _drain(dm)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
