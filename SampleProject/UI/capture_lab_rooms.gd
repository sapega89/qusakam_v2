extends SceneTree

## Кадри лабораторії на кімнати (queue row 9.4, D303): камери (герой у камері, стіл з алхіміком і в'язнем, Малік),
## вхід у коридори, зала джина з брамою, вихід назовні. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_lab_rooms.gd -- <out_dir>
## Файли: <out_dir>/fb9_4_<shot>.png

## [кімната, мітка входу, x героя, кадр]; y — підлога поверху (360 — верхній/єдиний).
const SHOTS := [
	["LabCells", ^"Arrival", 150.0, "cells_arrival"],
	["LabCells", ^"Arrival", 925.0, "cells_table"],
	["LabCells", ^"Arrival", 1400.0, "cells_malik"],
	["Laboratory", ^"SavePoint_Entrance", 120.0, "corridors_entry"],
	["LabBoss", ^"Arrival", 400.0, "boss_hall"],
	["LabBoss", ^"Arrival", 1400.0, "boss_gates"],
]

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	for shot: Array in SHOTS:
		if not game.map.scene_file_path.ends_with(shot[0] + ".tscn"):
			await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
			for i in 30: await physics_frame
		game.player.global_position = Vector2(shot[2], 360.0)
		for i in 60: await physics_frame
		await _drain()
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("%s/fb9_4_%s.png" % [out_dir, shot[3]])
	quit()

func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
