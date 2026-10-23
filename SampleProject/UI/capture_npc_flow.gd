extends SceneTree

## D442, D452, D454: знаки над NPC у грі — синій «!» коваля й герб жриці в місті, меню коваля, що відкрилось саме,
## з його реплікою мимохідь, жовтий «!» діда в селі. Три кадри в один лист (половинний розмір) у теку з аргументу:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_npc_flow.gd -- <dir>

var out: String
var shots: Array[Image] = []


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join("npc_flow_%s.png" % name))
	shots.append(img)


func _drain(dm: Node) -> void:
	for i in 300:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(dm)

	# 1. Місто: синій «!» над ковалем, герб над жрицею.
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 60: await physics_frame
	await _drain(dm)
	var smith: NpcBase = game.map.get_node(^"Blacksmith")
	game.player.global_position.x = smith.global_position.x + 250
	for i in 60: await physics_frame
	await _shot("markers")

	# 2. Герой підійшов до коваля: меню відкрилось саме, коваль гукає.
	dm.bubble_time_scale = 1.0
	game.player.global_position.x = smith.global_position.x - 40
	for i in 30: await physics_frame
	await _shot("auto_menu")
	dm.bubble_time_scale = 0.0

	# 3. Село: жовтий «!» над дідом, поки сюжетне завдання не видано.
	for flag in ["village_abduction_complete", "village_arrival_complete", "village_fight_complete", "village_afterfight_complete"]:
		game.set_quest_flag(flag, true)
	await game.teleport_to_room("res://SampleProject/Maps/Village.tscn", ^"ElderDoor")
	for i in 60: await physics_frame
	await _drain(dm)
	var old_man: NpcBase = game.map.get_node(^"OldManQuest")
	game.player.global_position.x = old_man.global_position.x - 260
	for i in 60: await physics_frame
	await _drain(dm)
	await _shot("story")

	var sheet := Image.create(960 * shots.size(), 540, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var half: Image = shots[i].duplicate()
		half.convert(Image.FORMAT_RGBA8)
		half.resize(960, 540, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(half, Rect2i(0, 0, 960, 540), Vector2i(960 * i, 0))
	sheet.save_png(out.path_join("npc_flow_sheet.png"))
	print("sheet saved: ", out.path_join("npc_flow_sheet.png"))
	quit()
