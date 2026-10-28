extends SceneTree

## prop-sizes (D814, A11 + A12): пальми 4 H, двері 112 art, замкнені ворота 128 art, кузня одноповерхова — кожен кадр
## окремо в <тека> і одна сітка 4 × N (кожен кадр — екран, зменшений учетверо). Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_prop_sizes.gd -- design/shots/prop_sizes design/shots/prop_sizes_after.png
## Третій аргумент wire_props — кадри A13 (реквізит табору, льоху й дому старійшини окремими спрайтами), fg_scrub
## 2:1 (B191) і спори CollapsedDrain поза гратами.

const MAPS := "res://SampleProject/Maps/%s.tscn"
## [кімната, де стоїть герой, назва кадру]
const SHOTS := [
	["DesertRoad", Vector2(1100, 330), "road_palms"], ["DesertRoad", Vector2(2100, 330), "road_palisade_gate"],
	["DesertRoad", Vector2(2850, 330), "road_mesa_cleft"], ["DesertRoad", Vector2(3330, 330), "road_cave_mouth"],
	["Village", Vector2(1100, 330), "village_palms"], ["CraftQuarter", Vector2(1030, 330), "city_forge"],
	["City", Vector2(2540, 330), "city_door_elder"], ["CityGates", Vector2(700, 330), "gates_occluder_palm"],
	["BanditCamp", Vector2(1150, 360), "camp_locked_gate"], ["LizardCave", Vector2(1100, 360), "cave_locked_gate"],
	["Laboratory", Vector2(2990, 330), "lab_door"], ["MayorHall", Vector2(200, 330), "palace_door"],
]
const WIRE_PROPS := [
	["BanditCamp", Vector2(450, 360), "camp_west"], ["BanditCamp", Vector2(1100, 360), "camp_east"],
	["GatehouseCellar", Vector2(500, 370), "cellar_west"], ["GatehouseCellar", Vector2(1150, 370), "cellar_east"],
	["ElderHouse", Vector2(450, 800), "elder_house"], ["DragonMural", Vector2(450, 360), "mural_scrub"],
	["LizardCave", Vector2(800, 370), "cave_scrub"], ["MesaClimb", Vector2(500, 800), "mesa_scrub"],
	["CollapsedDrain", Vector2(3150, 340), "drain_grate"],
]
## Кімнати без вузла Arrival — куди телепортувати.
const ARRIVE := {"DesertRoad": ^"Arrival_Start", "City": ^"SavePoint", "Laboratory": ^"DrainDoor"}
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
	var args := OS.get_cmdline_user_args()
	var shots: Array = WIRE_PROPS if args.size() > 2 and args[2] == "wire_props" else SHOTS
	var rows := (shots.size() + 3) / 4
	var sheet := Image.create(CELL.x * 4, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		if not game.map.scene_file_path.ends_with(shots[i][0] + ".tscn"):
			await game.teleport_to_room(MAPS % shots[i][0], ARRIVE.get(shots[i][0], ^"Arrival"))
		game.place_player(shots[i][1])
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
		half.save_png("res://%s/%s.png" % [out_dir, shots[i][2]])
		image.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % 4 * CELL.x, i / 4 * CELL.y))
		print("shot %s hero %s" % [shots[i][2], game.player.global_position])
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
