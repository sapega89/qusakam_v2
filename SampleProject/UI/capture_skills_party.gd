extends SceneTree

## Кадри skills-party (B156, D741, D742) так, як їх бачить гравець: HUD з обома світними кнопками нових очок,
## Game Menu, відкрите кліком по «Нові атрибути» (Status з рядками атрибутів і позначеним очком, світні вкладки),
## далі клік по вкладці Skills (дорога Sapega з плейтесту: Status → Skills, колонка партії як у грі).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_skills_party.gd -- <тека>
## Те саме з --resolution 1280x720 — найменше вікно гри (DisplayManager.RESOLUTIONS). Пише skills_party_*_<WxH>.png.

var sl: Node
var out_dir: String
var suffix: String


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	suffix = "%dx%d" % [root.size.x, root.size.y]
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D289
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	for flag in ["village_oldman_gift", "village_left_complete", "village_abduction_complete", "village_oldman_healed"]:
		game.set_quest_flag(flag, true)
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 3:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	await create_timer(4.0).timeout  # сповіщення про рівень (D623) згасає
	await _shot("hud")

	var hud: Node = game.find_child("HudNewPoints", true, false)
	# У грі курсор схований (D417) — Alt показує його, і кнопку можна клікнути.
	for pressed in [true, false]:
		var alt := InputEventKey.new()
		alt.keycode = KEY_ALT
		alt.physical_keycode = KEY_ALT
		alt.pressed = pressed
		root.push_input(alt)
		await process_frame
	await _click(hud.get_node(^"%AttributePoints"))
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	var st: Node = menu.find_child("StatsComponent", true, false)
	await _click(st._attr_rows_box.get_node(^"vitality/Plus"))
	st._attr_rows_box.get_node(^"vitality/Plus").grab_focus()
	await create_timer(0.8).timeout  # пульс сяйва вкладок — ближче до піку
	await _shot("status")
	await _click(menu.get_node(^"%SkillsButton"))
	for i in 10: await process_frame
	menu.find_child("SkillsComponent", true, false)._rows["toughness"].grab_focus()
	await create_timer(0.8).timeout
	await _shot("skills_after_status")
	quit(0)


## Клік у координатах вікна: полотно 1920×1080 розтягнуто на вікно (canvas_items), а подія йде від вікна.
func _click(node: Control) -> void:
	var pos := root.get_final_transform() * node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pos
		click.global_position = pos
		root.push_input(click)
		await process_frame


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
	root.get_texture().get_image().save_png(out_dir.path_join("skills_party_%s_%s.png" % [name, suffix]))
	print("shot ", name)
