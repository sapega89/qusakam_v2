extends SceneTree

## Кадри для D830 / D832: рівна підлога Пустельної дороги (де були сходинки дюн, мези й каравану) і поверхи
## лабораторії без містків. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_flat_road_lab.gd -- <out_dir>
## Файли: <out_dir>/<shot>.png

## [кімната, мітка входу, позиція героя, кадр]
const SHOTS := [
	["DesertRoad", ^"Arrival_Start", Vector2(2050, 360), "road_dunes"],
	["DesertRoad", ^"Arrival_Start", Vector2(3050, 360), "road_mesa"],
	["DesertRoad", ^"Arrival_Start", Vector2(4120, 360), "road_caravan"],
	["Laboratory", ^"SavePoint_Entrance", Vector2(760, 360), "lab_a"],
	["Laboratory", ^"SavePoint_Entrance", Vector2(1380, 360), "lab_a_east"],
	["Laboratory", ^"SavePoint_Entrance", Vector2(1100, 840), "lab_b"],
	["Laboratory", ^"SavePoint_Entrance", Vector2(1150, 1320), "lab_c"],
	["LabBoss", ^"Arrival", Vector2(450, 360), "boss_west"],
	["LabBoss", ^"Arrival", Vector2(1300, 360), "boss_east"],
]

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	game.player.min_health = 1
	for shot: Array in SHOTS:
		if not game.map.scene_file_path.ends_with(shot[0] + ".tscn"):
			await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
			for i in 30: await physics_frame
		game.player.global_position = shot[2]
		for i in 60: await physics_frame
		await _drain()
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot[3]])
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
