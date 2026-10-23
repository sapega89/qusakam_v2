extends SceneTree

## D674: вікно навичок Dragon Nest у справжньому вікні — для порівняння з design/shots/figma_skills_dragon_nest.png.
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_skills_dn.gd -- <тека>
## Герой 15 рівня з клятвою Paladin і кількома рангами, як у кадрі Figma; пише skills_dn_*.png у теку.

var game: Node
var sl: Node
var out_dir: String


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	# У місті сюжет уже відкрив вкладки меню (game_menu.tscn metadata/unlock_flag).
	for flag in ["village_oldman_gift", "village_left_complete", "village_abduction_complete", "village_oldman_healed"]:
		game.set_quest_flag(flag, true)
	var xp: Node = sl.get_xp_manager()
	var sm: Node = sl.get_skill_manager()
	while xp.get_level() < 15:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	await _finish_dialogue()
	sm.add_job_points(20)
	sm.swear_oath("paladin")
	for id: String in ["shield_block", "healing_palm", "devotion", "weapon_training", "fire_strike", "radiant_smite",
			"mending_hands", "skyfall_blessing"]:
		sm.unlock_skill(id)
	for id: String in ["radiant_smite", "radiant_smite", "shield_block", "devotion", "skyfall_blessing"]:
		sm.upgrade_skill(id)

	var ui_manager: Node = sl.get_ui_manager()
	ui_manager.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 10: await process_frame
	var skills: Node = menu.find_child("SkillsComponent", true, false)
	skills._rows["radiant_smite"].grab_focus()
	skills.pick_selected()
	for i in 6: await process_frame
	await _shot("skills_dn_paladin")
	skills.cancel_plan()
	skills._rows["toughness"].grab_focus()
	for i in 4: await process_frame
	await _shot("skills_dn_passive")
	quit(0)


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
