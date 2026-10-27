extends SceneTree

## Кадри BACKLOG 22 у справжньому вікні: хранителі клятв у місті, меню клятви, екран Skills з деревами.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_skill_trees.gd -- <тека>
## Пише fb22_*.png у теку. Меню відкривається, як у гравця (B156): Esc, потім клік по вкладці в бічній панелі,
## а вікно Paladin — дорогою Sapega з плейтесту: Status → Skills, з колонкою партії, як у грі.

var game: Node
var sl: Node
var out_dir: String


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	await _finish_dialogue()
	var xp: Node = sl.get_xp_manager()
	var sm: Node = sl.get_skill_manager()
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	await create_timer(1.5).timeout
	var hero: Node2D = game.player
	var priest: Node = game.map.get_node("OathPriest")
	var witch: Node = game.map.get_node("OathWitch")

	for at in [[1420, "fb22_city_priest_witch"], [2000, "fb22_city_witch_dervish"]]:
		hero.global_position = Vector2(at[0], 360)
		for i in 40: await physics_frame
		await _shot(at[1])

	hero.global_position = Vector2(1830, 360)
	for i in 30: await physics_frame
	witch._on_interacted()
	for i in 10: await process_frame
	await _shot("fb22_witch_menu")
	witch._close_npc_menu()

	hero.global_position = Vector2(1470, 360)
	for i in 30: await physics_frame
	priest._on_interacted()  # D726: лише Talk — клятву дає перепис біля брами
	for i in 10: await process_frame
	await _shot("fb22_priest_menu")
	priest._close_npc_menu()

	# У місті сюжет уже відкрив вкладки меню (game_menu.tscn metadata/unlock_flag).
	for flag in ["village_oldman_gift", "village_left_complete", "village_abduction_complete", "village_oldman_healed"]:
		game.set_quest_flag(flag, true)
	sm.add_job_points(4)
	sm.unlock_skill("toughness")
	sm.unlock_skill("healing_palm")
	sm.unlock_skill("devotion")
	var ui_manager: Node = sl.get_ui_manager()
	var menu: Node = await _open_menu_like_player(["Skills"])
	menu.find_child("SkillsComponent", true, false)._rows["devotion"].grab_focus()
	for i in 4: await process_frame
	await _shot("fb22_skills_before_oath")
	ui_manager.close_game_menu()
	for i in 8: await process_frame

	sm.swear_oath("paladin")
	sm.unlock_skill("radiant_smite")
	menu = await _open_menu_like_player(["Status", "Skills"])
	var skills: Node = menu.find_child("SkillsComponent", true, false)
	skills._rows["radiant_smite"].grab_focus()
	for i in 4: await process_frame
	await _shot("fb22_skills_paladin")  # D728: інших дерев шляхів не видно
	quit(0)


## Esc (дія game_menu) відкриває меню; далі — клік мишею по кожній вкладці [param tabs] у бічній панелі.
func _open_menu_like_player(tabs: Array) -> Node:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	for tab: String in tabs:
		var button: Control = menu.get_node("%%%sButton" % tab)
		var pos := button.get_global_rect().get_center()
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = pos
			click.global_position = pos
			root.push_input(click)
			await process_frame
		for i in 10: await process_frame
	assert(menu.current_tab_name == tabs[-1], "capture_skill_trees: the menu is not on %s" % tabs[-1])
	return menu


func _finish_dialogue() -> void:
	var dm: Node = sl.get_dialogue_manager()
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)
