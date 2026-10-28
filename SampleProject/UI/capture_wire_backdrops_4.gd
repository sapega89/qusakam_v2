extends SceneTree

## wire-backdrops-4: бічні кімнати Лабораторії (M6d-1) з підключеними намальованими планами під камерою гри —
## кожен кадр окремо в <тека> і одна сітка 4 × N (кожен кадр — екран, зменшений учетверо). Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_wire_backdrops_4.gd -- design/shots/wire_backdrops_4 design/shots/wire_backdrops_4.png

const MAPS := "res://SampleProject/Maps/%s.tscn"
## [кімната, де стоїть герой, назва кадру]
const SHOTS := [
	["AlchemistCorridor", Vector2(300, 340), "corridor_store_door"], ["AlchemistCorridor", Vector2(1300, 340), "corridor_table"],
	["AlchemistCorridor", Vector2(2300, 340), "corridor_stairs"], ["AlchemistStore", Vector2(500, 340), "store_barrels"],
	["AlchemistStore", Vector2(1450, 340), "store_door"], ["MalikStash", Vector2(300, 340), "stash_hoard"],
	["MalikStash", Vector2(1350, 340), "stash_shaft"], ["CollapsedDrain", Vector2(250, 340), "drain_hatch"],
	["CollapsedDrain", Vector2(2130, 340), "drain_collapse"], ["CollapsedDrain", Vector2(2950, 340), "drain_grate"],
	["CollapsedDrain", Vector2(3840, 340), "drain_pipe"], ["CollapsedDrain", Vector2(5400, 340), "drain_chest"],
]
const CELL := Vector2i(480, 270)

var game: Node
var dm: Node


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var out_sheet: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
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
	game.player.set_invulnerable(true)
	var rows := (SHOTS.size() + 3) / 4
	var sheet := Image.create(CELL.x * 4, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in SHOTS.size():
		if not game.map.scene_file_path.ends_with(SHOTS[i][0] + ".tscn"):
			await game.teleport_to_room(MAPS % SHOTS[i][0], ^"Arrival")
		game.place_player(SHOTS[i][1])
		game.player.velocity = Vector2.ZERO
		for f in 45: await physics_frame
		await _drain()
		var cam: Camera2D = game.player.get_node(^"Camera2D")
		cam.reset_smoothing()
		for f in 5: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var half := image.duplicate() as Image
		half.resize(960, 540, Image.INTERPOLATE_NEAREST)
		half.save_png("res://%s/%s.png" % [out_dir, SHOTS[i][2]])
		image.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % 4 * CELL.x, i / 4 * CELL.y))
		print("shot %s hero %s" % [SHOTS[i][2], game.player.global_position])
	sheet.save_png("res://" + out_sheet)
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
