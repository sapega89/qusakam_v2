extends SceneTree

## Нові очки, як у Diablo II (D723), і колонка партії над вікном навичок (B151).
## Sapega, плейтест 2026-10-26: «панель скілів закрила панель атрибутів … там наче її закриває паті-панель з Кусакамом»,
## «треба підсвічувати, щоб воно якось горіло», «може кнопку як в Діабло 2?».
##   godot --headless --path . --script res://SampleProject/UI/verify_new_points.gd
##
## [1] B151: Status → Skills (і інші шляхи) — колонка партії схована, панель навички в кадрі, 1920×1080 і 1280×720.
## [2] HUD: поки вкладку не відкрито сюжетом — кнопок немає; відкрито — дві світні кнопки з «+N», підписом і клавішею,
##     не на панелі героя, хотбарі, квест-панелі й стрічці здобичі.
## [3] Клік і клавіша (K, C, хрестовина ліворуч) відкривають меню одразу на Skills / Status.
## [4] У меню вкладки Skills і Status світяться з лічильником; витратив — гаснуть, і HUD-кнопки зникають.
## [5] Під час діалогу кнопок немає.

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

var fails: Array[String] = []


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok:
		fails.append(label)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


func _mouse(node: Control) -> void:
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	node.get_viewport().push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		node.get_viewport().push_input(ev)
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame


func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size
	for i in 4: await process_frame


## Меню відкрите на вкладці [param tab]? Повертає саме меню.
func _menu_on(tab: String) -> Node:
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	return menu if menu != null and menu.current_tab_name == tab else null


func _close(ui: Node) -> void:
	ui.close_game_menu()
	for i in 8: await process_frame


func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)  # headless скидає вікно до 64×64, а миша клікає в координатах 1920×1080
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	var ui: Node = sl.get_ui_manager()
	var sm: Node = sl.get_skill_manager()
	var attrs: Node = sl.get_attribute_manager()
	var xp: Node = sl.get_xp_manager()
	var hud: Node = game.find_child("HudNewPoints", true, false)
	ck(hud != null, "HudNewPoints is on the CombatHUD")
	var skills_btn: Button = hud.get_node(^"%SkillPoints")
	var attrs_btn: Button = hud.get_node(^"%AttributePoints")
	for flag in ["village_oldman_healed", "village_oldman_gift"]:
		game.set_quest_flag(flag, false)

	print("[2] HUD buttons: only for an open tab, with + count, caption and key")
	xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	for i in 2: await process_frame
	ck(sm.get_job_points() > 0 and attrs.get_unspent() == 5, "level 2: skill points %d, attribute points %d" % [sm.get_job_points(), attrs.get_unspent()])
	ck(not skills_btn.visible and not attrs_btn.visible, "Skills and Status not yet opened by the story: no buttons")
	game.set_quest_flag("village_oldman_healed", true)
	game.set_quest_flag("village_oldman_gift", true)
	for i in 2: await process_frame
	ck(skills_btn.visible and skills_btn.is_glowing() and skills_btn.get_node(^"%Count").text == "+%d" % sm.get_job_points(),
			"«New skills» glows with +%d" % sm.get_job_points())
	ck(attrs_btn.visible and attrs_btn.is_glowing() and attrs_btn.get_node(^"%Count").text == "+5", "«New attributes» glows with +5")
	ck(skills_btn.get_node(^"%Caption").text == "New skills" and attrs_btn.get_node(^"%Caption").text == "New attributes", "captions from the tables")
	ck(skills_btn.key_text() == "K" and attrs_btn.key_text() == "C", "keyboard: K and C on the buttons (%s, %s)" % [skills_btn.key_text(), attrs_btn.key_text()])
	ck(skills_btn.get_node(^"Glow").get_node(^"%Halo").theme_type_variation == &"PointsGlow"
			and not skills_btn.has_theme_stylebox_override(&"normal"), "the glow and the plate come from the theme (no overrides)")
	var hud_root: Control = game.get_node(^"UICanvas/CombatHUD")
	var keep_clear: Array[Control] = [hud_root.get_node(^"PlayerVitalsPanel"), hud_root.get_node(^"SkillHotbar"),
			hud_root.get_node(^"CombatHudTop/QuestPanel"), hud_root.get_node(^"LootFeed")]
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		await _set_window(size)
		var canvas := root.get_visible_rect()
		var bad: Array[String] = []
		for button: Control in [skills_btn, attrs_btn]:
			var r := button.get_global_rect()
			if not canvas.encloses(r):
				bad.append("%s off screen" % button.name)
			for other in keep_clear:
				if other.get_global_rect().intersects(r):
					bad.append("%s on %s" % [button.name, other.name])
		ck(bad.is_empty(), "%dx%d: both buttons on screen, clear of the hero panel, quick slots, quest panel and loot feed %s" % [size.x, size.y, bad])
	await _set_window(Vector2i(1920, 1080))

	print("[3] Click or key opens the menu right on the tab")
	# У грі курсор схований (D417): клікнути кнопку можна, показавши його Alt, як і все в HUD.
	await _key(KEY_ALT)
	ck(game.get_node(^"MouseCursor").cursor_visible, "Alt shows the cursor")
	await _mouse(skills_btn)
	var menu: Node = await _menu_on("Skills")
	ck(menu != null, "click «New skills» → Game Menu on Skills")
	await _close(ui)
	await _mouse(attrs_btn)
	ck(await _menu_on("Status") != null, "click «New attributes» → Game Menu on Status")
	await _close(ui)
	await _key(KEY_K)
	ck(await _menu_on("Skills") != null, "key K → Skills")
	await _close(ui)
	await _key(KEY_C)
	ck(await _menu_on("Status") != null, "key C → Status")
	await _close(ui)
	await _pad(JOY_BUTTON_DPAD_LEFT)
	ck(await _menu_on("Skills") != null, "pad D-pad left → the first tab that waits (Skills)")
	await _close(ui)
	InputGlyphs.using_gamepad = true
	hud.refresh()
	ck(skills_btn.key_text() == "D-pad left" and attrs_btn.key_text() == "", "pad: the D-pad glyph only on the button it opens (%s / %s)" % [skills_btn.key_text(), attrs_btn.key_text()])
	InputGlyphs.using_gamepad = false
	hud.refresh()

	print("[1] B151: the party column never covers the skill side panel")
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		await _set_window(size)
		for path in [["Skills"], ["Status", "Skills"], ["World Map", "Skills"], ["Status", "World Map", "Skills"], ["Skills", "Status"], ["Skills", "Inventory"]]:
			ui.open_game_menu()
			for i in 14: await process_frame
			menu = get_first_node_in_group("game_menu")
			for tab in path:
				menu.switch_to_tab(tab)
				for i in 4: await process_frame
			var party: Control = menu.get_node(^"BaseMenu/HBoxContainer/RightPanel")
			var shown: Control = menu.find_child("SkillsComponent", true, false).get_node(^"Window/Center/Body/Columns/SidePanel") \
					if path[-1] == "Skills" else null
			if path[-1] == "Inventory":
				ck(party.visible, "%dx%d %s: the party column is back" % [size.x, size.y, " → ".join(path)])
			elif path[-1] == "Status":
				ck(not party.visible, "%dx%d %s: the party column hidden" % [size.x, size.y, " → ".join(path)])
			else:
				ck(not party.visible and root.get_visible_rect().encloses(shown.get_global_rect()),
						"%dx%d %s: the party column hidden, the side panel on screen" % [size.x, size.y, " → ".join(path)])
			await _close(ui)
	await _set_window(Vector2i(1920, 1080))

	print("[4] The sidebar tabs glow with a count until the points are spent")
	ui.open_game_menu()
	for i in 14: await process_frame
	menu = get_first_node_in_group("game_menu")
	var skills_glow: Control = menu.get_node(^"%SkillsButton/PointsGlow")
	var status_glow: Control = menu.get_node(^"%StatusButton/PointsGlow")
	ck(skills_glow.is_glowing() and skills_glow.count_text() == str(sm.get_job_points()), "Skills tab glows, badge %s" % skills_glow.count_text())
	ck(status_glow.is_glowing() and status_glow.count_text() == "5", "Status tab glows, badge %s" % status_glow.count_text())
	ck(not menu.get_node(^"%InventoryButton").has_node(^"PointsGlow"), "only Skills and Status carry the glow")
	menu.switch_to_tab("Status")
	for i in 6: await process_frame
	var st: Node = menu.find_child("StatsComponent", true, false)
	for i in 5:
		await _mouse(st._attr_rows_box.get_node(^"strength/Plus"))
	ck(status_glow.is_glowing(), "picked but not accepted: still glowing")
	await _mouse(st._accept_button)
	for i in 2: await process_frame
	ck(attrs.get_unspent() == 0 and not status_glow.is_glowing() and not status_glow.visible, "Accept spends them: the Status tab stops glowing")
	menu.switch_to_tab("Skills")
	for i in 6: await process_frame
	var sk: Node = menu.find_child("SkillsComponent", true, false)
	var ok_result: int = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result.OK  # load: скрипт тягне autoload
	while sm.get_job_points() > 0:
		var before: int = sm.get_job_points()
		for id: String in sk._rows:
			if sk.plan.can_pick(id) == ok_result:
				sk.plan.pick(id)
				break
		sk.accept_plan()
		for i in 2: await process_frame
		if sm.get_job_points() == before:
			break
	ck(sm.get_job_points() == 0 and not skills_glow.visible, "JP spent: the Skills tab stops glowing")
	await _close(ui)
	ck(not skills_btn.visible and not attrs_btn.visible, "back in the game: both HUD buttons are gone")

	print("[5] No buttons during dialogue")
	xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	for i in 2: await process_frame
	ck(skills_btn.visible and attrs_btn.visible, "a new level: both back")
	var dm: Node = sl.get_dialogue_manager()
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")  # розмова у вікні; монолог-облачко HUD не ховає, як і підказки
	for i in 4: await process_frame
	ck(dm.is_dialogue_active() and not skills_btn.visible and not attrs_btn.visible, "dialogue: hidden (active %s, buttons %s / %s)" % [dm.is_dialogue_active(), skills_btn.visible, attrs_btn.visible])
	await _key(KEY_K)
	ck(get_first_node_in_group("game_menu") == null, "K during dialogue opens nothing")
	await _drain(dm)
	for i in 2: await process_frame
	ck(skills_btn.visible and attrs_btn.visible, "dialogue over: back")
	await _key(KEY_ALT)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
