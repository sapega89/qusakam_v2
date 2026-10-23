extends SceneTree

## BACKLOG 5 (D295): кожен NPC у своїй кімнаті посеред дії — кілька моментів циклу «work» і поза «talk»
## поруч у листі. Пише в теку з аргументу (за замовчуванням design/shots):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_npc_activity.gd -- <dir>

const SPOTS := [
	["res://SampleProject/Maps/City.tscn", ^"Blacksmith", "blacksmith"],
	["res://SampleProject/Maps/DesertRoad.tscn", ^"Merchant", "merchant"],
	["res://SampleProject/Maps/Village.tscn", ^"OldManQuest", "grandfather"],
	["res://SampleProject/Maps/City.tscn", ^"OathPriest", "priest"],
	["res://SampleProject/Maps/City.tscn", ^"OathWitch", "witch"],
	["res://SampleProject/Maps/City.tscn", ^"OathDervish", "dervish"],
	["res://SampleProject/Maps/CityGates.tscn", ^"GuardLeft", "guard"],
]
const MOMENTS := 4
const CROP := Vector2i(300, 440)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _crop(npc: Node2D) -> Image:
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	var at: Vector2 = npc.get_global_transform_with_canvas().origin
	var rect := Rect2i(Vector2i(at) - Vector2i(CROP.x / 2, CROP.y - 60), CROP)
	return shot.get_region(rect)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	for flag in ["city_blacksmith_met", "desert_road_merchant_met", "desert_road_fight_complete"]:
		game.set_quest_flag(flag, true)
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	var sheet := Image.create(CROP.x * (MOMENTS + 1), CROP.y * SPOTS.size(), false, Image.FORMAT_RGBA8)
	for row in SPOTS.size():
		var spot: Array = SPOTS[row]
		await game.teleport_to_room(spot[0], spot[1])
		for i in 90: await physics_frame
		for i in 300:
			if not dm.is_dialogue_active(): break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		var npc: Node2D = game.map.get_node(spot[1])
		var player: Node2D = game.player
		player.global_position.x = npc.global_position.x - 220
		for i in 30: await physics_frame
		var activity: Node = npc.get_node(^"Activity")
		var anim: AnimationPlayer = npc.get_node(^"AnimationPlayer")
		activity.resume()
		var step: float = anim.get_animation(&"work").length / MOMENTS
		for m in MOMENTS:
			anim.seek(step * m + 0.05, true)
			anim.pause()
			var img: Image = await _crop(npc)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * m, CROP.y * row))
			if m == 2:
				img.save_png(out.path_join("fb5_%s.png" % spot[2]))
		anim.play()
		if npc.has_node(^"Sparks"):  # іскри з ковадла на ударі (метод-трек грає лише на ходу)
			anim.seek(0.45, true)
			for i in 5: await process_frame
			(await _crop(npc)).save_png(out.path_join("fb5_%s_sparks.png" % spot[2]))
		if npc is NpcBase:  # поза розмови: E поруч
			player.global_position.x = npc.global_position.x - 50
			for i in 30: await physics_frame
			npc.interactable.interacted.emit()  # шлях клавіші E перевіряє verify_npc_activity.gd
			for i in 10: await process_frame
			var talk: Image = await _crop(npc)
			sheet.blit_rect(talk, Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * MOMENTS, CROP.y * row))
			print("%s: talk=%s menu=%s" % [spot[2], anim.current_animation, (npc as NpcBase).npc_menu.visible])
			_press(&"ui_cancel")
			for i in 10: await process_frame
	sheet.save_png(out.path_join("fb5_sheet.png"))
	print("sheet saved: ", out.path_join("fb5_sheet.png"))
	quit(0)
