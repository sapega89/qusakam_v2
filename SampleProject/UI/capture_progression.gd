extends SceneTree

## D447, D488 (cloud/progression): двері зали мера без клятви — двоє вартових і облачко; герой медитує на точці
## збереження. Два кадри + лист 1×2 у теку з аргументу (за замовчуванням design/shots):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_progression.gd -- <dir>

var out: String
var shots: Array[Image] = []


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join("progression_%s.png" % name))
	shots.append(img)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0  # монолог початку гри — геть, щоб не займав облачко
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	game.set_quest_flag("city_gates_fight_complete", true)

	# 1. Двері зали мера: герой підходить без клятви, правий вартовий каже своє.
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	while dm.is_bubble_playing():
		await process_frame
	dm.bubble_time_scale = 1.0
	game.player.global_position = Vector2(2300, 360)
	Input.action_press(&"move_right")
	for i in 90: await physics_frame
	Input.action_release(&"move_right")
	for i in 20: await process_frame
	await _shot("mayor_gate")

	# 2. Медитація на точці збереження — перед екраном збереження.
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	var save_point: Node = game.map.get_node(^"SavePoint")
	save_point.interactable.interacted.emit()
	for i in 6: await process_frame
	await _shot("meditate")
	sl.get_ui_manager().close_state()

	var sheet := Image.create(1920, 540, false, shots[0].get_format())
	for i in shots.size():
		var half := shots[i].duplicate() as Image
		half.resize(960, 540)
		sheet.blit_rect(half, Rect2i(0, 0, 960, 540), Vector2i(960 * i, 0))
	sheet.save_png(out.path_join("progression_sheet.png"))
	quit()
