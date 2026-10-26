extends SceneTree

## Кадри «живого світу» (BACKLOG 7 + 19): передній план, декор, хмари у кожній відкритій кімнаті. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_living_world.gd -- <out_dir>
## Файли: <out_dir>/living_<shot>.png

## [кімната, мітка входу, x героя, y героя, кадр].
const SHOTS := [
	["Village", ^"Arrival", 400.0, 360.0, "village_a"],
	["Village", ^"Arrival", 1500.0, 360.0, "village_b"],
	["Village", ^"Arrival", 2300.0, 360.0, "village_c"],
	["Canyon", ^"Arrival", 600.0, 340.0, "canyon_a"],
	["Canyon", ^"Arrival", 2000.0, 340.0, "canyon_b"],
	["DesertRoad", ^"Arrival_Start", 1250.0, 340.0, "road_a"],
	["DesertRoad", ^"Arrival_Start", 2000.0, 300.0, "road_b"],
	["DesertRoad", ^"Arrival_Start", 4500.0, 340.0, "road_c"],
	["CityGates", ^"Arrival", 400.0, 340.0, "gates_a"],
	["CityGates", ^"Arrival", 1500.0, 340.0, "gates_b"],
	["City", ^"ForgeDoor", 600.0, 380.0, "city_a"],
	["City", ^"ForgeDoor", 1800.0, 380.0, "city_b"],
	["LabCells", ^"Arrival", 300.0, 340.0, "cells_a"],
	["LabCells", ^"Arrival", 1400.0, 340.0, "cells_b"],
	["Laboratory", ^"SavePoint_Entrance", 400.0, 340.0, "lab_a"],
	["Laboratory", ^"SavePoint_Entrance", 1300.0, 340.0, "lab_b"],
	["LabBoss", ^"Arrival", 300.0, 340.0, "boss_a"],
	["LabBoss", ^"Arrival", 1400.0, 340.0, "boss_b"],
	["LaboratoryOutside", ^"Arrival", 400.0, 340.0, "labout_a"],
	["LaboratoryOutside", ^"Arrival", 1300.0, 340.0, "labout_b"],
]

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
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
		if not game.map.scene_file_path.ends_with("/" + shot[0] + ".tscn"):
			await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
			for i in 30: await physics_frame
		game.player.global_position = Vector2(shot[2], shot[3])
		for i in 60: await physics_frame
		await _drain()
		await create_timer(0.5).timeout
		_hide_demo_end(root)
		await process_frame
		root.get_texture().get_image().save_png("%s/living_%s.png" % [out_dir, shot[4]])
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

## Екран кінця демо (LaboratoryOutside) закриває кадр — ховаємо його лише для знімка.
func _hide_demo_end(node: Node) -> void:
	for child: Node in node.get_children():
		if child.scene_file_path.ends_with("DemoEndScreen.tscn") and child is CanvasItem:
			(child as CanvasItem).visible = false
		else:
			_hide_demo_end(child)
