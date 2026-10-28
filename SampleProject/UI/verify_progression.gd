extends SceneTree

## Progression calls of 2026-10-23 (D447, D488, D492), played in the real game:
##   1. The cap: a flood of XP stops at level 20; the HUD XP row, the XP bar and the Status screen show MAX.
##   2. The Mayor Hall gate: without an oath the City's east door is shut, two gate guards stand there, the right one
##      says so in a bubble and the objective points to the oath keepers; after the oath the hero walks through.
##   3. The meditation: using a save point the hero sits (Meditate), then the save screen opens; leaving it stands
##      him up and gives him his feet back.
##   4. The respawn rule: an ordinary fight (Laboratory corridors) stays cleared inside its region, comes back when
##      the hero re-enters the region or meditates; a story fight (the Desert Road ambush) never comes back.
##   godot --headless --path . --script res://SampleProject/UI/verify_progression.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const CITY := "res://SampleProject/Maps/City.tscn"
## Двері палацу між вартовими — на площі палацу, кінці вулиці за ринком (M7, D773).
const SQUARE := "res://SampleProject/Maps/PalaceSquare.tscn"
const LAB := "res://SampleProject/Maps/Laboratory.tscn"
const CELLS := "res://SampleProject/Maps/LabCells.tscn"
const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const TEST_DIR := "user://test_saves_progression/"
## Камери пройдено — LabCells не грає своїх сцен (як verify_laboratory).
const LAB_FLAGS := ["lab_cells_cutscene_complete", "lab_acquaintance_complete"]

var fails: Array[String] = []
var sl: Node
var game: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _alive(spawner: Node) -> Array:
	return spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())


func _room_of(scene_path: String) -> String:
	return root.get_node("MetSys").map_data.get_room_from_scene_path(scene_path, false)


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").set_save_dir(TEST_DIR)  # тести не чіпають справжніх сейвів
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	sl = root.get_node("ServiceLocator")
	game = await Kit.boot(self)
	var xp: Node = sl.get_xp_manager()

	print("[1] The cap is 20 and the bars show MAX (D488)")
	ck(xp.MAX_LEVEL == 20, "XPManager.MAX_LEVEL %d" % xp.MAX_LEVEL)
	xp.add_xp(100000000)
	await Kit.frames(self, 6)
	ck(xp.get_level() == 20 and xp.current_xp == 0 and xp.is_max_level(), "a flood of XP stops at 20 (level %d, %d XP)" % [xp.get_level(), xp.current_xp])
	# D552: XP на HUD — смуга на всю ширину без чисел; на капі повна.
	var hud_xp: ProgressBar = game.get_node("UICanvas/CombatHUD/XpBar")
	hud_xp.refresh()
	ck(hud_xp.ratio == 1.0, "HUD XP bar full at the cap (%.2f)" % hud_xp.ratio)
	var bar: Node = game.get_node("UICanvas/PlayerXPBar")
	bar._update_display()
	ck(bar.xp_label.text == tr("MAX") and bar.progress_bar.value == 100.0, "XP bar: '%s', %d%%" % [bar.xp_label.text, bar.progress_bar.value])

	print("[2] The Mayor Hall door is open without an oath (D725: the D488 gate is gone)")
	ck(sl.get_skill_manager().get_oath() == "", "no oath yet")
	await game.teleport_to_room(SQUARE, ^"Arrival")
	await Kit.frames(self, 20)
	var city: Node = game.map
	var hall_door: Area2D = city.get_node("MayorHallDoor")
	var east: Object = root.get_node("MetSys").map_data.get_cell_at(Vector3i(28, 5, 0))
	ck(hall_door.interactable.enabled and east.get_border(0) == 0, "the palace door opens without an oath (the east edge stays a wall)")
	ck(city.get_node("GuardLeft").scene_file_path.ends_with("gate_guard.tscn") and city.get_node("GuardRight").scene_file_path.ends_with("gate_guard.tscn"),
			"two gate guards at the door")
	ck(not city.has_node("GateTalk") and not city.has_node("ObjectiveTargets/oath_keepers")
			and not FileAccess.file_exists("res://dialogue_quest/City_MayorHall_Guard.dqd"), "no guard line and no oath objective at the door")
	ck(game.get_objective() != "Swear an oath with the oath keepers", "the objective is not «swear an oath» (%s)" % game.get_objective())
	game.player.global_position = hall_door.global_position + Vector2(-20, 40)
	await Kit.frames(self, 10)
	hall_door.interactable.interacted.emit()
	for i in 120:
		await physics_frame
		if game.map != city:
			break
	ck(game.map != city and String(game.map.scene_file_path).ends_with("MayorHall.tscn"), "the hero walks into the Mayor Hall with no oath")
	await Kit.drain(self)

	print("[3] A save point: meditate, then the save screen; leaving it stands him up (D447)")
	await game.teleport_to_room(CITY, ^"SavePoint")
	await Kit.frames(self, 20)
	var save_point: Node = game.map.get_node("SavePoint")
	var anim: AnimationPlayer = game.player.get_node("AnimationPlayer")
	var ui: Node = sl.get_ui_manager()
	save_point.interactable.interacted.emit()
	await Kit.frames(self, 3)
	ck(save_point.meditating and game.player.event, "the hero sits and cannot move")
	ck(String(anim.current_animation).ends_with("Jump"), "D764: first he hops onto the meditation spot (%s)" % anim.current_animation)
	await create_timer(save_point.HOP_TIME + 0.1).timeout
	ck(String(anim.current_animation).ends_with("Meditate"), "pose: %s" % anim.current_animation)
	ck(ui.current_state_name != "SaveGameState", "the save screen waits until he sits")
	await create_timer(save_point.MEDITATE_SIT_TIME).timeout
	ck(ui.current_state_name == "SaveGameState", "then the save screen opens (%s)" % ui.current_state_name)
	ck(String(anim.current_animation).ends_with("Meditate"), "he meditates while it is open (%s)" % anim.current_animation)
	ui.close_state()
	await create_timer(save_point.HOP_TIME + 0.1).timeout  # D764: і зістрибує назад
	ck(not save_point.meditating and not game.player.event, "leaving the screen gives him his feet back")
	ck(String(anim.current_animation).ends_with("Idle"), "he stands up (%s)" % anim.current_animation)
	ck(game.player.is_on_floor(), "on the floor all along, not hanging at the circle's height")

	print("[4] Ordinary enemies come back; story fights do not (D492)")
	var road_room := _room_of(ROAD)
	game.set_room_state(road_room, "enemies", {})  # засідка на дорозі добита — сюжетний бій
	for f in LAB_FLAGS:
		game.set_quest_flag(f, true)
	await game.teleport_to_room(LAB, ^"SavePoint_Entrance")
	await Kit.frames(self, 20)
	var upper: Node = game.map.get_node("Fight_Upper")
	ck(upper.respawns and not game.map.get_node("Fight_Fly").fight_in_progress(), "Fight_Upper is an ordinary fight")
	upper.spawn_all_enemies()
	await create_timer(4.0).timeout
	for enemy in _alive(upper):
		enemy.die()
	await Kit.frames(self, 10)
	ck(upper.fight_cleared(), "Fight_Upper cleared")
	await game.teleport_to_room(CELLS, ^"Arrival")
	await game.teleport_to_room(LAB, ^"SavePoint_Entrance")
	await Kit.frames(self, 10)
	upper = game.map.get_node("Fight_Upper")
	ck(upper.fight_cleared(), "same region (cells → corridors): still cleared")
	await game.teleport_to_room(CITY, ^"SavePoint")
	ck(game.get_room_state(_room_of(LAB), "enemies_upper") == {}, "in the City the Laboratory fight is still won (forgotten on the way back)")
	await game.teleport_to_room(LAB, ^"SavePoint_Entrance")
	await Kit.frames(self, 10)
	upper = game.map.get_node("Fight_Upper")
	ck(game.get_room_state(_room_of(LAB), "enemies_upper") == null and not upper.fight_in_progress(),
			"back in the Laboratory region: Fight_Upper is forgotten and starts afresh")
	ck(upper.fight_won(), "but it still counts as won (lab_corridors_complete does not wait for it again)")
	upper.spawn_all_enemies()
	await create_timer(4.0).timeout
	ck(_alive(upper).size() == upper.spawn_points.size(), "all %d come back (%d)" % [upper.spawn_points.size(), _alive(upper).size()])
	for enemy in _alive(upper):
		enemy.die()
	await Kit.frames(self, 10)
	ck(upper.fight_cleared(), "cleared again")
	game.meditate()
	ck(game.get_room_state(_room_of(LAB), "enemies_upper") == null, "meditating forgets it too")
	await game.teleport_to_room(CELLS, ^"Arrival")
	await game.teleport_to_room(LAB, ^"SavePoint_Entrance")
	await Kit.frames(self, 10)
	ck(not game.map.get_node("Fight_Upper").fight_in_progress(), "after meditating, the next visit starts it afresh")
	ck(game.get_room_state(road_room, "enemies") == {}, "the road ambush (a story fight) stays won")

	game.queue_free()
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
