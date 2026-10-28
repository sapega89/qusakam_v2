extends SceneTree

## B201: кожне місце, де драбина чи люк проходить крізь підлогу, під камерою гри. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_ladder_holes.gd -- <out_dir>
## Файли в <out_dir>: elder_attic(_below), lab_ladder1(_below), lab_ladder2(_below), road_shop, road_tower, city_rooftops, city_tavern_attic,
## tavern_attic, rooftops, drain_hatch — 960×540 довкола героя (нижня половина екрана, щоб видно підлогу) у масштабі гри.

const MAPS := "res://SampleProject/Maps/%s.tscn"
## Кімната, двері прибуття, де стати, назва кадру.
const SPOTS := [
	["ElderHouse", ^"Arrival", Vector2(330, 420), "elder_attic"],
	["ElderHouse", ^"Arrival", Vector2(330, 840), "elder_attic_below"],
	["Laboratory", ^"DrainDoor", Vector2(1440, 360), "lab_ladder1"],
	["Laboratory", ^"DrainDoor", Vector2(1440, 600), "lab_ladder1_below"],
	["Laboratory", ^"DrainDoor", Vector2(290, 840), "lab_ladder2"],
	["Laboratory", ^"DrainDoor", Vector2(290, 1080), "lab_ladder2_below"],
	["DesertRoad", ^"MesaClimbDoor", Vector2(1400, 130), "road_shop"],
	["DesertRoad", ^"MesaClimbDoor", Vector2(2380, 130), "road_tower"],
	["City", ^"RooftopsDoor", Vector2(960, 360), "city_rooftops"],
	["City", ^"TavernAtticDoor", Vector2(2380, 360), "city_tavern_attic"],
	["TavernAttic", ^"LadderDoor", Vector2(280, 360), "tavern_attic"],
	["Rooftops", ^"LadderDoor", Vector2(2320, 360), "rooftops"],
	["CollapsedDrain", ^"HatchDoor", Vector2(980, 360), "drain_hatch"],
]

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
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
	for spot: Array in SPOTS:
		await game.teleport_to_room(MAPS % spot[0], spot[1])
		for i in 10: await physics_frame
		for spawner in game.map.get_children().filter(func(n: Node) -> bool: return n.has_signal(&"all_enemies_defeated") and n.trigger_area != null):
			spawner.trigger_area.monitoring = false
		game.place_player(spot[2])
		game.player.velocity = Vector2.ZERO
		for i in 45: await physics_frame
		await _drain()
		await _shot(spot[3])
	quit()

func _shot(name: String) -> void:
	var cam: Camera2D = game.player.get_node(^"Camera2D")
	cam.top_level = false  # пролог нової гри лишає камеру top_level
	cam.position = Vector2.ZERO
	cam.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image = image.get_region(Rect2i(480, 480, 960, 540))
	image.save_png("%s/%s.png" % [out_dir, name])
	print("shot %s hero %s" % [name, game.player.global_position])

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
