extends SceneTree

## Черга 8b (D311, D312): торговець каравану в місті за роботою, його крамниця, нове завдання коваля
## «The Helmet» у Журналі й у розмові. Чотири кадри + лист 2×2 у теку з аргументу (за замовчуванням design/shots):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_city_merchant.gd -- <dir>

var out: String
var shots: Array[Image] = []


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join("fb8b_%s.png" % name))
	shots.append(img)


func _drain(dm: Node) -> void:
	for i in 300:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(dm)
	for flag in ["desert_road_fight_complete", "task_merchant_caravan_taken",
			"city_gates_fight_complete", "task_smith_helmet_taken"]:
		game.set_quest_flag(flag, true)

	# 1. Торговець за роботою біля брами, герой ліворуч.
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 60: await physics_frame
	await _drain(dm)
	var merchant: NpcBase = game.map.get_node(^"Merchant")
	game.player.global_position.x = merchant.global_position.x - 200
	var anim: AnimationPlayer = merchant.get_node(^"AnimationPlayer")
	for i in 600:
		if anim.current_animation == "work": break
		await process_frame
	for i in 20: await process_frame
	await _shot("merchant_work")

	# 2. Його крамниця.
	merchant.open_shop()
	for i in 20: await process_frame
	await _shot("shop")
	merchant.close_shop()
	for i in 10: await process_frame

	# 3. Коваль видає «The Helmet»: третій рядок (де взяти злитки); герой біля кузні.
	game.player.global_position.x = (game.map.get_node(^"Blacksmith") as Node2D).global_position.x - 120
	for i in 30: await physics_frame
	dm.start_dialogue("res://dialogue_quest/Smith_Helmet_Give.dqd")
	for line in 2:
		for i in 6: await process_frame
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
	for i in 6: await process_frame
	dm.current_dialogue_box.finish()
	for i in 6: await process_frame
	await _shot("smith_dialogue")
	await _drain(dm)

	# 4. Журнал: завдання з передісторією й ціллю.
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	for i in 10: await process_frame
	var journal: Node = get_first_node_in_group("journal_screen")
	journal.selected_id = "task/smith_helmet"
	journal.update_display()
	for i in 10: await process_frame
	await _shot("journal")

	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(960, 540)
		sheet.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i(960 * (i % 2), 540 * floori(i / 2.0)))
	sheet.save_png(out.path_join("fb8b_sheet.png"))
	print("sheet saved: ", out.path_join("fb8b_sheet.png"))
	quit(0)
