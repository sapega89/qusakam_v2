extends SceneTree

## Прохід брами (черга 8c, 8d): герой підходить до брами, іде повз вежу й крізь прохід (уся брама позаду
## нього, D314), на тому боці — та сама брама зсередини біля західного входу в Місто; далі коваль виходить
## із кузні до ковадла, яке стоїть на місці (B81). Пише <prefix>_*.png і <prefix>_sheet.png:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_city_gates_passage.gd -- <dir> [prefix]

var out: String
var prefix: String
var game: Node
var shots: Array[Image] = []


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join("%s_%s.png" % [prefix, name]))
	shots.append(img)


## Справжнє move_right, доки умова не стане істинною.
func _walk_until(cond: Callable) -> void:
	Input.action_press(&"move_right")
	for i in 600:
		if cond.call():
			break
		await physics_frame
	Input.action_release(&"move_right")
	for i in 20: await physics_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	prefix = args[1] if args.size() > 1 else "fb8c"
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	for i in 300:
		if not dm.is_dialogue_active(): break
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame
	# Бій біля брами вже позаду — TO_CITY, у Місті без зустрічей.
	for flag in ["city_gates_intro_complete", "city_gates_fight_complete", "city_gates_after_fight_complete"]:
		game.set_quest_flag(flag, true)
	await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 30: await physics_frame
	game.player.global_position = Vector2(1000, 360)
	for i in 60: await physics_frame

	await _walk_until(func() -> bool: return game.player.global_position.x > 1180.0)
	await _shot("1_approach")
	await _walk_until(func() -> bool: return game.player.global_position.x > 1430.0)
	await _shot("2_tower")
	await _walk_until(func() -> bool: return game.player.global_position.x > 1640.0)
	await _shot("3_inside")
	await _walk_until(func() -> bool: return game.map.scene_file_path.ends_with("/City.tscn") and game.player.global_position.x > 40.0)
	for i in 30: await physics_frame
	await _shot("4_city_side")

	# B81: коваль виходить, ковадло стоїть біля кузні.
	var smith: Node2D = game.map.get_node(^"Blacksmith")
	var anim: AnimationPlayer = smith.get_node(^"AnimationPlayer")
	await _walk_until(func() -> bool: return smith.visible and anim.current_animation == "walk")
	for i in 50: await physics_frame
	await _shot("5_smith_walks")
	for i in 600:
		if dm.is_dialogue_active(): break
		await physics_frame
	await _shot("6_smith_at_anvil")

	var half := Vector2i(640, 360)
	var sheet := Image.create(half.x * 3, half.y * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(half.x, half.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, half), Vector2i(i % 3 * half.x, i / 3 * half.y))
	sheet.save_png(out.path_join("%s_sheet.png" % prefix))
	print("CAPTURED %d shots -> %s" % [shots.size(), out])
	quit()
