extends SceneTree

## M7: нові кімнати графів регіонів на тимчасових фонах, під камерою гри — одна картинка-сітка 4×3 (кожен кадр — екран,
## зменшений учетверо). Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_world_rooms.gd -- design/shots/world_rooms.png

const MAPS := "res://SampleProject/Maps/%s.tscn"
## [кімната, де стоїть герой]
const SHOTS := [["MountainPath", Vector2(900, 300)], ["ScreeSlide", Vector2(430, 560)], ["StreamGorge", Vector2(1300, 300)],
		["RockLedges", Vector2(430, 560)], ["CaveUnderBridge", Vector2(300, 780)], ["CanyonFloor", Vector2(2800, 300)],
		["LizardCaves", Vector2(4700, 300)], ["Chasm", Vector2(80, 300)], ["Aqueduct", Vector2(3000, 300)],
		["PalaceSquare", Vector2(1300, 300)], ["Rooftops", Vector2(1300, 300)], ["AlchemistCorridor", Vector2(1200, 300)]]
const CELL := Vector2i(480, 270)

var game: Node
var dm: Node


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	var sheet := Image.create(CELL.x * 4, CELL.y * 3, false, Image.FORMAT_RGBA8)
	for i in SHOTS.size():
		await game.teleport_to_room(MAPS % SHOTS[i][0], ^"Arrival")
		game.place_player(SHOTS[i][1])
		game.player.velocity = Vector2.ZERO
		for f in 45: await physics_frame
		await _drain()
		var cam: Camera2D = game.player.get_node(^"Camera2D")
		cam.top_level = false
		cam.position = Vector2.ZERO
		cam.reset_smoothing()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % 4 * CELL.x, i / 4 * CELL.y))
		print("shot %s hero %s" % [SHOTS[i][0], game.player.global_position])
	sheet.save_png(out)
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
