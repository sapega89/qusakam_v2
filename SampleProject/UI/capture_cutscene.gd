extends SceneTree

## Кат-сцени (D308): HUD сховано, у куті «Hold … to skip» і смужка, що заповнюється, поки тримають кнопку.
## Напад на браму (Tab) і вихід торговця (геймпад Y). Пише fb9_1_*.png і fb9_1_sheet.png у теку з аргументу:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_cutscene.gd -- <dir>

var out: String
var game: Node
var dm: Node
var shots: Array[Image] = []


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join("fb9_1_%s.png" % name))
	shots.append(img)


func _drain() -> void:
	for i in 300:
		if not dm.is_dialogue_active(): return
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame


func _walk(action: StringName) -> void:
	Input.action_press(action)
	while not game.player.event:
		await physics_frame
	Input.action_release(action)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()

	# 1 — до сцени: HUD на місці.
	await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 30: await physics_frame
	game.player.global_position = Vector2(560, 360)
	for i in 60: await physics_frame
	await _shot("1_before_hud")

	# 2 — сцена почалась: HUD сховано, підказка порожня; камера пливе до брами.
	await _walk(&"move_right")
	await create_timer(1.0).timeout
	await _shot("2_cutscene_no_hud")

	# 3 — репліка варти, Tab тримають пів секунди: смужка наполовину.
	while not dm.is_dialogue_active():
		await process_frame
	await create_timer(1.0).timeout
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await create_timer(0.55).timeout
	await _shot("3_hold_tab_half")
	var up: InputEventKey = tab.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _drain()
	while game.map.get_current_state_name() != "FIGHT_LOOP":
		if dm.is_dialogue_active():
			await _drain()
		await process_frame
	await _drain()

	# 4 — торговець виходить, геймпад Y: підказка називає Y.
	for flag in ["canyon_exit_complete", "desert_road_fight_complete"]:
		game.set_quest_flag(flag, true)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 30: await physics_frame
	game.player.global_position = Vector2(700, 360)
	for i in 30: await physics_frame
	await _walk(&"move_right")
	await create_timer(0.8).timeout
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	Input.parse_input_event(y)
	await create_timer(0.7).timeout
	await _shot("4_merchant_hold_y")
	var y_up: InputEventJoypadButton = y.duplicate()
	y_up.pressed = false
	Input.parse_input_event(y_up)

	var half := Vector2i(960, 540)
	var sheet := Image.create(half.x * 2, half.y * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(half.x, half.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, half), Vector2i(i % 2 * half.x, i / 2 * half.y))
	sheet.save_png(out.path_join("fb9_1_sheet.png"))
	print("CAPTURED %d shots → %s" % [shots.size(), out])
	quit()
