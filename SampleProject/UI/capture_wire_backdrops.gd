extends SceneTree

## wire-backdrops: кімнати з підключеними намальованими планами під камерою гри — кожен кадр окремо в <тека> і одна
## сітка 4 × N (кожен кадр — екран, зменшений учетверо). Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_wire_backdrops.gd -- design/shots/wire_backdrops design/shots/wire_backdrops.png
## Третій аргумент «2» — кімнати wire-backdrops-2 (SHOTS_2):
##   ... -- design/shots/wire_backdrops_2 design/shots/wire_backdrops_2.png 2
## «3» — місто wire-backdrops-3 (SHOTS_3).

const MAPS := "res://SampleProject/Maps/%s.tscn"
## [кімната, де стоїть герой, назва кадру]
const SHOTS := [
	["MountainPath", Vector2(300, 340), "path_1"], ["MountainPath", Vector2(1300, 340), "path_2"],
	["MountainPath", Vector2(2450, 340), "path_3"], ["ScreeSlide", Vector2(60, 340), "scree_top"],
	["ScreeSlide", Vector2(800, 820), "scree_bottom"], ["StreamGorge", Vector2(200, 340), "gorge_1"],
	["StreamGorge", Vector2(1300, 340), "gorge_2"], ["StreamGorge", Vector2(2450, 340), "gorge_3"],
	["RockLedges", Vector2(60, 820), "ledges_bottom"], ["RockLedges", Vector2(800, 340), "ledges_top"],
	["Village", Vector2(300, 340), "village_1"], ["Village", Vector2(1300, 340), "village_2"],
	["Village", Vector2(2300, 340), "village_3"], ["ElderHouse", Vector2(300, 400), "attic"],
	["CaveUnderBridge", Vector2(200, 340), "cave_top"], ["CaveUnderBridge", Vector2(600, 820), "cave_middle"],
	["CaveUnderBridge", Vector2(500, 1300), "cave_floor"], ["MesaTop", Vector2(300, 340), "mesa_1"],
	["MesaTop", Vector2(1500, 340), "mesa_2"], ["ZahraRest", Vector2(200, 340), "zahra_1"],
	["ZahraRest", Vector2(900, 340), "zahra_well"], ["ZahraRest", Vector2(1650, 340), "zahra_3"],
]
## wire-backdrops-2: решта каньйону. Міст провалля й ґрата льоху — у обох станах (прапорець ставить сам кадр).
const SHOTS_2 := [
	["Dunes", Vector2(200, 340), "dunes_1"], ["Dunes", Vector2(1100, 340), "dunes_2"],
	["Dunes", Vector2(2700, 340), "dunes_trail"], ["Chasm", Vector2(80, 340), "chasm_raised"],
	["Chasm", Vector2(780, 340), "chasm_lowered", "chasm_bridge_down"], ["DryRiverbed", Vector2(300, 340), "riverbed"],
	["Aqueduct", Vector2(600, 340), "aqueduct_breach"], ["Aqueduct", Vector2(1900, 340), "aqueduct_2"],
	["Aqueduct", Vector2(3100, 340), "aqueduct_doors"], ["Aqueduct", Vector2(3100, 340), "aqueduct_open", "aqueduct_cellar_open"],
	["OldRuins", Vector2(200, 340), "ruins_well"], ["OldRuins", Vector2(1900, 340), "ruins_2"],
	["OldRuins", Vector2(4100, 340), "ruins_arch"], ["GateApproach", Vector2(150, 340), "approach_lever"],
	["GateApproach", Vector2(1300, 340), "approach_well"], ["CanyonFloor", Vector2(400, 340), "floor_crack"],
	["CanyonFloor", Vector2(1500, 340), "floor_2"], ["CanyonFloor", Vector2(2780, 340), "floor_hole"],
	["CaveExit", Vector2(400, 340), "cave_exit"], ["SmugglersStash", Vector2(300, 340), "stash"],
]
## wire-backdrops-3: місто — нові кімнати, кінці драбин і мотузки на ринку й біля брами; ґрата цистерни в обох станах.
const SHOTS_3 := [
	["City", Vector2(800, 340), "city_pigeons"], ["City", Vector2(880, 340), "city_ladder"],
	["City", Vector2(1250, 340), "city_tent"], ["City", Vector2(2420, 340), "city_stall"],
	["CityGates", Vector2(640, 340), "gates_rope"], ["CraftQuarter", Vector2(300, 340), "craft_1"],
	["CraftQuarter", Vector2(1100, 340), "craft_forge"], ["CraftQuarter", Vector2(2300, 340), "craft_chapel"],
	["PalaceSquare", Vector2(400, 340), "palace_fountain"], ["PalaceSquare", Vector2(1500, 340), "palace_door"],
	["Rooftops", Vector2(150, 340), "roofs_rope"], ["Rooftops", Vector2(1300, 340), "roofs_loft"],
	["Rooftops", Vector2(2400, 340), "roofs_ladder"], ["PigeonLoft", Vector2(432, 340), "loft"],
	["TavernAttic", Vector2(200, 340), "attic_hatch"], ["TavernAttic", Vector2(1300, 340), "attic_2"],
	["MayorArchive", Vector2(300, 340), "archive"], ["Cistern", Vector2(160, 340), "cistern_grate"],
	["Cistern", Vector2(160, 340), "cistern_open", "cistern_cellar_open"], ["Cistern", Vector2(900, 340), "cistern_dragon"],
	["Cistern", Vector2(1700, 340), "cistern_well"], ["Cistern", Vector2(2300, 340), "cistern_breach"],
	["CisternStash", Vector2(200, 340), "stash_breach"], ["CisternStash", Vector2(1100, 340), "stash_2"],
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
	var set_name: String = OS.get_cmdline_user_args()[2] if OS.get_cmdline_user_args().size() > 2 else "1"
	var shots: Array = {"1": SHOTS, "2": SHOTS_2, "3": SHOTS_3}[set_name]
	var rows := (shots.size() + 3) / 4
	var sheet := Image.create(CELL.x * 4, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		# На ринку немає Arrival: герой стає біля драбини на дахи, далеко від голубів (вони злітають за 160 px).
		var mark: NodePath = ^"RooftopsDoor" if shots[i][0] == "City" else ^"Arrival"
		if shots[i].size() > 3:
			game.set_quest_flag(shots[i][3], true)
			await game.teleport_to_room(MAPS % shots[i][0], mark)
		elif not game.map.scene_file_path.ends_with(shots[i][0] + ".tscn"):
			await game.teleport_to_room(MAPS % shots[i][0], mark)
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
