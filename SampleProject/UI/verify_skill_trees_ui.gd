extends SceneTree

## Екран Skills з деревами (D283, D333) справжнім вводом: вкладки клятв мишею і геймпадом, фокус з вузлів на вкладки,
## вивчення — позначка + Accept (D330, замість подвійного кліку B77), стан дерева до і після клятви, назва класу в шапці.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_trees_ui.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

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

func _mouse(node: Control, double: bool = false) -> void:
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.double_click = double and pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame

## Геймпад: D-pad і A — ті самі ui_* дії, якими ходить фокус.
func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame

func _focus() -> Control:
	return root.gui_get_focus_owner()

## Вузли смуги клятви: смуга (Nodes + Pad) — третя дитина ряду рівня (підпис, стовбур, клятва).
func _secondary_ids(ui: Node) -> Array:
	var out: Array = []
	for id in ui._rows:
		var cell: Node = ui._rows[id].get_parent().get_parent()
		if cell.get_index() == 2:
			out.append(id)
	return out

func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)  # headless скидає вікно до 64×64, а миша клікає в координатах 1920×1080
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	sm.add_job_points(10)

	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var ui: Node = menu.find_child("SkillsComponent", true, false)

	print("[1] Two columns: trunk and an oath tree under three tabs")
	var tabs: Array = ui._tree_tabs.get_children()
	ck(tabs.map(func(t): return t.text) == ["Paladin", "Dark Knight", "Warden of Balance"], "three oath tabs %s" % [tabs.map(func(t): return t.text)])
	ck(ui._char_class.text == "Holy Warrior", "header class: Holy Warrior (%s)" % ui._char_class.text)
	ck(ui._rows.has("healing_palm") and ui._rows.has("devotion") and not ui._rows.has("searing_hex"), "trunk left, Paladin tree right by default")
	ck(tabs[0].button_pressed and _secondary_ids(ui).has("radiant_smite"), "Paladin tab pressed, its tree shown")
	var status: Label = ui._tree_status
	ck(status.text.find("Swear an oath in the City") >= 0, "before the oath the tree says where to swear (%s)" % status.text)

	print("[2] Mouse: a click on a tab switches the tree")
	await _mouse(tabs[2])
	for i in 2: await process_frame
	ck(ui._shown_oath == "warden" and _secondary_ids(ui).has("balanced_strike") and not _secondary_ids(ui).has("radiant_smite"), "Warden tab shows the Warden tree")

	print("[3] Gamepad: from a trunk node into the oath tree, up to the tabs, switch with A")
	ui._rows["weapon_training"].grab_focus()  # Lv 4 стовбура; праворуч нижче — Lv 5 клятви
	await process_frame
	for i in 3:
		if _focus() != null and _secondary_ids(ui).has(String(_focus().name)):
			break
		await _pad(JOY_BUTTON_DPAD_DOWN if i == 0 else JOY_BUTTON_DPAD_RIGHT)
	ck(_focus() != null and _secondary_ids(ui).has(String(_focus().name)), "the D-pad reaches the oath tree (%s)" % (_focus().name if _focus() else "none"))
	for i in 12:
		if _focus() in tabs:
			break
		await _pad(JOY_BUTTON_DPAD_UP)
	ck(_focus() in tabs, "D-pad up reaches the tabs (%s)" % (_focus().name if _focus() else "none"))
	for i in 3:
		if _focus() == tabs[1]:
			break
		await _pad(JOY_BUTTON_DPAD_RIGHT if _focus() == tabs[0] else JOY_BUTTON_DPAD_LEFT)
	ck(_focus() == tabs[1], "the D-pad walks the tabs (%s)" % (_focus().name if _focus() else "none"))
	await _pad(JOY_BUTTON_A)
	for i in 2: await process_frame
	ck(ui._shown_oath == "dark_knight" and _secondary_ids(ui).has("searing_hex"), "A on the Dark Knight tab shows its tree")
	ui._on_row_selected("searing_hex")
	ck(get_first_node_in_group("ui_bottom_bar")._hint_label.text.find("Swear an oath in the City") >= 0, "an oath skill before the oath explains why")

	print("[4] Mouse: a click selects, Pick + Accept learn (D330 replaces the B77 double click)")
	var jp: int = sm.get_job_points()
	await _mouse(ui._rows["devotion"])
	ck(not sm.is_unlocked("devotion") and ui._selected_id == "devotion", "a single click only selects")
	await _mouse(ui._rows["devotion"], true)
	ck(not sm.is_unlocked("devotion"), "a double click does not learn any more")
	await _mouse(ui._pick_button)
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(sm.is_unlocked("devotion") and sm.get_job_points() == jp - 1, "Pick, then Accept learn it (JP %d → %d)" % [jp, sm.get_job_points()])

	print("[5] After the oath")
	ck(sm.swear_oath("paladin") == 0, "swore the Paladin oath")
	for i in 2: await process_frame
	ck(ui._char_class.text == "Paladin", "header class: Paladin")
	ck(ui._shown_oath == "paladin" and tabs[0].button_pressed, "the sworn tree is shown")
	ck(status.text.ends_with("Your oath"), "status: Your oath (%s)" % status.text)
	await _mouse(tabs[1])
	for i in 2: await process_frame
	ck(status.text.ends_with("Sworn to another oath"), "another tree: Sworn to another oath (%s)" % status.text)
	await _mouse(tabs[0])
	for i in 2: await process_frame
	ui._rows["radiant_smite"].grab_focus()
	await process_frame
	await _pad(JOY_BUTTON_A)
	ck(not sm.is_unlocked("radiant_smite") and ui.plan.skill_picks("radiant_smite") == 1, "A on an oath node picks it")
	await _pad(JOY_BUTTON_Y)
	for i in 2: await process_frame
	ck(sm.is_unlocked("radiant_smite"), "Y accepts: learned")
	ck(_focus() == ui._rows.get("radiant_smite"), "focus stays on the row after learning (%s)" % (_focus().name if _focus() else "none"))

	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
