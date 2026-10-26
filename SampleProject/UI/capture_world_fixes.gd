extends SceneTree

## Кімнати надворі під камерою гри (D446, D448, D451, D483): у кожній кімнаті герой стає по черзі в середину
## кожного стовпця клітинок MetSys, кадр — увесь екран, зменшений удвічі. До/після складає
## Scripts/Tools/world_fixes_sheet.py. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_world_fixes.gd -- <out_dir>
##   … -- <out_dir> [кімната ...]
## Файли: <out_dir>/<кімната>_<стовпець>.png, <out_dir>/sparkle_<кадр>.png (блиск предмета, D446, у повну величину)

const ROOMS := [
	["Village", ^"Arrival"],
	["Canyon", ^"Descent/Edge"],
	["DesertRoad", ^"Arrival_Start"],
	["CityGates", ^"Arrival"],
	["City", ^"ForgeDoor"],
	["LaboratoryOutside", ^"Arrival"],
]

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
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
	var only := OS.get_cmdline_user_args().slice(1)  # після <out_dir> можна назвати кімнати (і sparkle) — тоді лише їх
	if only.is_empty() or only.has("sparkle"):
		await _sparkle()
	var cell: Vector2 = root.get_node("MetSys").settings.in_game_cell_size
	for spot: Array in ROOMS:
		if not only.is_empty() and not only.has(spot[0]):
			continue
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % spot[0], spot[1])
		for i in 30: await physics_frame
		await _drain()
		for screen in root.find_children("*", "Control", true, false):
			# Без типу DemoEndScreen: скрипт знімка компілюється до autoload, клас тягне за собою Game.gd і MetSys
			if screen.get_script() != null and screen.get_script().resource_path.ends_with("DemoEndScreen.gd"):
				screen.get_parent().queue_free()  # LaboratoryOutside одразу показує кінець демо — кадр про кімнату
				game.player.set_movement_enabled(true)  # B141: екран тримав героя — без цього він висів, де його поставили
		var mark: Node2D = game.map.get_node(spot[1])
		var size: Vector2 = game.map.get_node(^"RoomInstance").get_size()
		var columns := roundi(size.x / cell.x)
		for c in columns:
			game.place_player(Vector2(cell.x * (c + 0.5), mark.global_position.y - 40.0))
			for i in 45: await physics_frame
			await _drain()
			await _shot("%s_%d" % [spot[0], c])
	quit()

## Блиск предмета на землі (D446): кадри анімації у повну величину.
func _sparkle() -> void:
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	var pickup: Node2D = game.map.get_node(^"Pickup_ShopRoof")
	game.place_player(pickup.global_position + Vector2(-120, 0))
	for i in 45: await physics_frame
	await _drain()
	for f in 4:
		pickup.get_node(^"AnimationPlayer").seek([0.0, 0.15, 0.3, 0.65][f], true)
		await _crop(pickup, "sparkle_%d" % f)

## Виріз 320×180 px екрана навколо [param node] у повну величину.
func _crop(node: Node2D, name: String) -> void:
	var cam: Camera2D = game.player.get_node(^"Camera2D")
	cam.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	var at := (node.global_position - cam.get_screen_center_position()) * cam.zoom + Vector2(root.size) / 2.0
	var image := root.get_texture().get_image()
	image.get_region(Rect2i(Vector2i(at) - Vector2i(160, 90), Vector2i(320, 180))).save_png("%s/%s.png" % [out_dir, name])

func _shot(name: String) -> void:
	var cam: Camera2D = game.player.get_node(^"Camera2D")
	cam.top_level = false  # пролог нової гри лишає камеру top_level
	cam.position = Vector2.ZERO
	cam.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	image.save_png("%s/%s.png" % [out_dir, name])
	print("shot %s hero %s camera %s limits %d..%d" % [name, game.player.global_position, cam.get_screen_center_position(), cam.limit_top, cam.limit_bottom])

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
