extends SceneTree

## Ноги героя на підлозі (hero-feet): герой стоїть у кімнаті з дорогою (смуга D559) і в LabBoss (верх Surfaces = колізія);
## кадр навколо героя, ×2. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_hero_feet.gd -- <out_dir> <suffix>
## Файли: <out_dir>/hero_feet_<кімната>_<suffix>.png

## [кімната, мітка входу, x героя (NAN — де поставила мітка)].
const SHOTS := [
	["DesertRoad", ^"Arrival_Start", NAN],
	["LabBoss", ^"Arrival", 400.0],
]
const CROP := Vector2i(360, 240)

var game: Node
var dm: Node
var out_dir := ""
var suffix := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	suffix = OS.get_cmdline_user_args()[1]
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
	for shot: Array in SHOTS:
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
		for i in 30: await physics_frame
		if not is_nan(shot[2]):
			game.player.global_position.x = shot[2]
		for i in 60: await physics_frame
		await _drain()
		await create_timer(0.5).timeout
		var at: Vector2 = game.player.get_global_transform_with_canvas().origin
		var image := root.get_texture().get_image()
		var corner := Vector2i(at) - CROP / 2
		corner = corner.clamp(Vector2i.ZERO, image.get_size() - CROP)
		var crop := image.get_region(Rect2i(corner, CROP))
		crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/hero_feet_%s_%s.png" % [out_dir, shot[0], suffix])
		print("shot %s: hero %s on the floor %s" % [shot[0], game.player.global_position, game.player.is_on_floor()])
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
