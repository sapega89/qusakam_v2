extends SceneTree

## Тінь героя (hero-shadow): стоїть і на вершині стрибка, у кімнаті з дорогою (DesertRoad, смуга D559) і в
## приміщенні (LabBoss). Один кадр 2×2, кожна клітинка — 600×560 px екрана навколо тіні. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_hero_shadow.gd -- <out.png>

## [кімната, мітка входу, x героя (NAN — де поставила мітка)].
const SHOTS := [
	["DesertRoad", ^"Arrival_Start", NAN],
	["LabBoss", ^"Arrival", NAN],
]
const CROP := Vector2i(600, 560)
## Центр кадру — на стільки екранних px вище тіні, щоб влізли й вона, і герой на вершині стрибка.
const LIFT := 200

var game: Node
var dm: Node

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
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
	var sheet := Image.create(CROP.x * 2, CROP.y * SHOTS.size(), false, Image.FORMAT_RGBA8)
	for row in SHOTS.size():
		var shot: Array = SHOTS[row]
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
		for i in 30: await physics_frame
		if not is_nan(shot[2]):
			game.player.global_position.x = shot[2]
		for i in 60: await physics_frame
		await _drain()
		await create_timer(0.5).timeout
		await _shot(sheet, Vector2i(0, row), "%s standing" % shot[0])
		Input.action_press(&"jump")
		for i in 60:
			await physics_frame
			if game.player.velocity.y >= 0.0 and not game.player.is_on_floor():
				break
		await _shot(sheet, Vector2i(1, row), "%s top of the jump" % shot[0])
		Input.action_release(&"jump")
		for i in 60: await physics_frame
	sheet.save_png(out)
	print("saved ", out)
	quit()

## Кадр навколо тіні (камера йде за героєм, тож центр — від тіні в цьому кадрі, у px екрана).
func _shot(sheet: Image, cell: Vector2i, label: String) -> void:
	await RenderingServer.frame_post_draw
	var shadow: Node2D = game.player.get_node(^"Shadow")
	var centre: Vector2 = root.get_final_transform() * shadow.get_global_transform_with_canvas().origin - Vector2(0, LIFT)
	var image := root.get_texture().get_image()
	var corner := (Vector2i(centre) - CROP / 2).clamp(Vector2i.ZERO, image.get_size() - CROP)
	var crop := image.get_region(Rect2i(corner, CROP))
	crop.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), cell * CROP)
	print("%s: hero %s, shadow %s visible %s scale %.2f alpha %.2f" % [label, game.player.global_position, shadow.global_position, shadow.visible, shadow.scale.x, shadow.modulate.a])

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
