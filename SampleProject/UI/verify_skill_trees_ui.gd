extends SceneTree

## Вікно навичок Dragon Nest (D674) справжнім вводом: вкладки чотирьох дерев мишею і геймпадом, дві панелі (базове дерево
## і клятва), фокус з клітинок на вкладки, вивчення — Learn +1 + Accept (D330), стан до і після клятви.
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

## Навички правої панелі (дерево клятви).
func _secondary_ids(ui: Node) -> Array:
	return ui._rows.keys().filter(func(id: String) -> bool: return ui._rows[id].get_parent().get_parent() == ui._grid(ui._right_panel))

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
	# Вікно скілів вантажиться на головному потоці; поки RoomPreloader у фоні вантажить сусідів Canyon (з round 13 —
	# бічні кімнати й нові вороги), такий load() часом стає в deadlock із воркером (B149). Чекаємо, поки стихне.
	while game.room_preloader.busy():
		await process_frame
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

	print("[1] Four tabs; the base tree left, an oath tree right")
	var tabs: Array = ui._tree_tabs.get_children()
	ck(tabs.map(func(t): return t.text) == ["Holy Warrior", "Paladin", "Dark Knight", "Warden of Balance"], "four tree tabs %s" % [tabs.map(func(t): return t.text)])
	ck(ui._hero_line.text.begins_with("Lv 5 · "), "the hero line: %s" % ui._hero_line.text)
	ck(ui._rows.has("healing_palm") and ui._rows.has("devotion") and not ui._rows.has("searing_hex"), "trunk left, Paladin tree right by default")
	ck(tabs[0].button_pressed and tabs[1].button_pressed and not tabs[2].button_pressed, "Holy Warrior and Paladin tabs pressed")
	ck(_secondary_ids(ui).has("radiant_smite"), "the Paladin tree is in the right panel")
	var status: Label = ui._right_panel.get_node(^"Tree/Status")
	ck(status.visible and status.text.find("Swear an oath in the City") >= 0, "before the oath the tree says where to swear (%s)" % status.text)
	ck(ui._right_panel.get_node(^"Tree/Heading").text == "Paladin · Light", "right heading: %s" % ui._right_panel.get_node(^"Tree/Heading").text)

	print("[2] Mouse: a click on an oath tab switches the right tree")
	await _mouse(tabs[3])
	for i in 2: await process_frame
	ck(ui._shown_oath == "warden" and _secondary_ids(ui).has("balanced_strike") and not _secondary_ids(ui).has("radiant_smite"), "Warden tab shows the Warden tree")
	ck(_focus() == ui._rows["bulwark"], "and focuses its first cell (%s)" % (_focus().name if _focus() else "none"))

	print("[3] Gamepad: from a trunk cell into the oath tree, up to the tabs, switch with A")
	ui._rows["healing_palm"].grab_focus()  # правий стовпець базового дерева; праворуч — дерево клятви
	await process_frame
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	ck(_focus() != null and _secondary_ids(ui).has(String(_focus().get_parent().name)), "D-pad right crosses into the oath tree (%s)" % (_focus().get_parent().name if _focus() else "none"))
	for i in 8:
		if _focus() in tabs:
			break
		await _pad(JOY_BUTTON_DPAD_UP)
	ck(_focus() in tabs, "D-pad up reaches the tabs (%s)" % (_focus().name if _focus() else "none"))
	for i in 4:
		if _focus() == tabs[2]:
			break
		await _pad(JOY_BUTTON_DPAD_RIGHT if tabs.find(_focus()) < 2 else JOY_BUTTON_DPAD_LEFT)
	ck(_focus() == tabs[2], "the D-pad walks the tabs (%s)" % (_focus().name if _focus() else "none"))
	await _pad(JOY_BUTTON_A)
	for i in 2: await process_frame
	ck(ui._shown_oath == "dark_knight" and _secondary_ids(ui).has("searing_hex"), "A on the Dark Knight tab shows its tree")
	ui._on_row_selected("searing_hex")
	ck(get_first_node_in_group("ui_bottom_bar")._hint_label.text.find("Swear an oath in the City") >= 0, "an oath skill before the oath explains why")
	await _mouse(tabs[0])
	ck(_focus() == ui._rows["toughness"], "the Holy Warrior tab focuses the base tree (%s)" % (_focus().get_parent().name if _focus() else "none"))

	print("[4] Mouse: a click selects, Learn +1 + Accept learn (D330)")
	var jp: int = sm.get_job_points()
	await _mouse(ui._rows["devotion"])
	ck(not sm.is_unlocked("devotion") and ui._selected_id == "devotion", "a single click only selects")
	await _mouse(ui._rows["devotion"], true)
	ck(not sm.is_unlocked("devotion"), "a double click does not learn")
	await _mouse(ui._learn_button)
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(sm.is_unlocked("devotion") and sm.get_job_points() == jp - 1, "Learn +1, then Accept learn it (JP %d → %d)" % [jp, sm.get_job_points()])

	print("[5] After the oath")
	# D497: навичка клятви 5-го рівня — від 3 JP у стовбурі (Devotion уже є).
	ck(sm.unlock_skill("toughness") == 0 and sm.unlock_skill("shield_block") == 0, "3 JP in the base tree")
	ck(sm.swear_oath("paladin") == 0, "swore the Paladin oath")
	for i in 2: await process_frame
	ck(ui._shown_oath == "paladin" and tabs[1].button_pressed and not status.visible, "the sworn tree is shown, no oath hint")
	ck(tabs[2].disabled and tabs[3].disabled and not tabs[0].disabled and not tabs[1].disabled, "other oaths' tabs are closed (D489)")
	ck(ui._budgets.text == "Holy Warrior 3 / 14  ·  Paladin 0 / 12", "budgets at the bottom: %s" % ui._budgets.text)
	ui._rows["radiant_smite"].grab_focus()
	await process_frame
	await _pad(JOY_BUTTON_A)
	ck(not sm.is_unlocked("radiant_smite") and ui.plan.skill_picks("radiant_smite") == 1, "A on an oath cell picks it")
	await _pad(JOY_BUTTON_Y)
	for i in 2: await process_frame
	ck(sm.is_unlocked("radiant_smite"), "Y accepts: learned")
	ck(_focus() == ui._rows.get("radiant_smite"), "focus stays on the cell after learning (%s)" % (_focus().get_parent().name if _focus() else "none"))

	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
