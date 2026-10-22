extends SceneTree

## Екран Skills після переробки (BACKLOG 43, D330–D334) справжнім вводом: миша, клавіші, InputEventJoypadButton.
## Вміщається без прокрутки, дерево рівнів із лініями, стани вузлів, панель деталей, позначки й Accept,
## каскад зняття передумови, Esc скидає позначене, слот хотбара з цього екрана.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_screen.gd

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

func _mouse(node: Control, button: MouseButton = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.double_click = double and pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame

func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame

func _focus() -> Control:
	return root.gui_get_focus_owner()

func _note(ui: Node, id: String) -> String:
	return ui._rows[id].get_node(^"Row/State").text

func _marker(ui: Node, id: String) -> Texture2D:
	return ui._rows[id].get_node(^"Row/Marker").texture

func _facts(ui: Node) -> Dictionary:
	var out := {}
	var cells: Array = ui._detail_grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	for i in range(0, cells.size() - 1, 2):
		out[cells[i].text] = cells[i + 1].text
	return out

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
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	sm.add_job_points(6)  # 4 за рівні 2–5 + 6 = 10

	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var ui: Node = menu.find_child("SkillsComponent", true, false)
	var S = ui.NodeState

	print("[1] Fits without scrolling; a tree by level tiers; tabs in the oath header")
	ck(ui.find_children("*", "ScrollContainer", true, false).is_empty(), "no ScrollContainer on the screen")
	var body: Control = ui.get_node(^"Center/Body")
	ck(body.get_combined_minimum_size().y <= ui.size.y - 64, "the screen's content fits its height (%d of %d)" % [body.get_combined_minimum_size().y, ui.size.y - 64])
	ck(ui._tiers.get_combined_minimum_size().y <= ui._tree_stage.size.y, "the tree fits its panel (%d of %d)" % [ui._tiers.get_combined_minimum_size().y, ui._tree_stage.size.y])
	var side: Control = ui.get_node(^"Center/Body/Columns/SidePanel")
	ck(side.get_combined_minimum_size().y <= side.size.y + 1, "the detail / attributes column fits (%d of %d)" % [side.get_combined_minimum_size().y, side.size.y])
	var tiers: Array = ui._tiers.get_children().map(func(t): return String(t.name))
	ck(tiers == ["Tier1", "Tier2", "Tier3", "Tier4", "Tier5", "Tier6", "Tier8", "Tier10", "Tier12", "Tier15", "Tier18", "Tier20"], "12 level tiers, trunk + Paladin (%s)" % [tiers])
	ck(ui._rows["radiant_smite"].get_parent().get_parent().get_parent().name == "Tier5" and ui._rows["fortitude"].get_parent().get_parent().get_parent().name == "Tier12", "each skill sits in its level's tier")
	ck(ui._tree_tabs.get_parent().name == "OathHeader", "the oath tabs share the oath header, not their own row")
	# D117: рядки — копії шаблонів зі сцени, стилі з теми; лише аватар несе копію AvatarChip з кольором героя.
	var styled: Array = ui.find_children("*", "Control", true, false).filter(
			func(c: Control) -> bool: return c.has_theme_stylebox_override(&"panel") or c.has_theme_color_override(&"font_color"))
	ck(styled == [ui._avatar], "rows carry no stylebox / colour overrides, only the avatar's colour (D117): %s" % [styled.map(func(c): return String(c.name))])
	ck(ui._links.links.size() == 3, "3 links in the Paladin view (Radiant Smite → Skyfall → Judgement, Resolve → Vow): %d" % ui._links.links.size())
	for id in ui._rows:
		var r: Rect2 = ui._rows[id].get_global_rect()
		if not ui._tree_stage.get_global_rect().grow(1).encloses(r):
			ck(false, "%s inside the tree panel" % id)

	print("[2] States: learned / can learn now / locked with the reason (D332)")
	ck(ui.node_state("toughness") == S.CAN_LEARN and _marker(ui, "toughness") == null and _note(ui, "toughness") == "1 JP", "Toughness: can learn now, no lock, cost 1 JP")
	ck(ui.node_state("healing_palm") == S.CAN_LEARN and _note(ui, "healing_palm") == "Free", "Healing Palm: free")
	ck(ui.node_state("fortitude") == S.LOCKED and _marker(ui, "fortitude") == ui.ICON_LOCK and _note(ui, "fortitude") == "Lv 12", "Fortitude: locked, lock icon, Lv 12")
	ck(ui.node_state("radiant_smite") == S.LOCKED and _note(ui, "radiant_smite") == "Oath", "Radiant Smite before the oath: locked, Oath")
	ck(ui.node_state("skyfall_blessing") == S.LOCKED and _note(ui, "skyfall_blessing") == "Oath", "Skyfall Blessing before the oath: Oath")

	print("[3] Detail panel: what it does and costs (D334)")
	await _mouse(ui._rows["fire_strike"])
	var facts := _facts(ui)
	ck(ui._selected_id == "fire_strike" and ui._detail_name.text == "Fire Strike", "a click selects Fire Strike and shows it")
	ck(facts.get("Cost") == "1 JP" and facts.get("Level") == "Lv 6" and facts.get("SP", "").ends_with("SP") and facts.get("Cooldown", "").ends_with(" s"), "cost, level, SP, cooldown: %s" % [facts])
	ck(String(facts.get("Effect", "")).find("dmg") >= 0 and String(facts.get("Weapon", "")) != "", "effect and weapon shown")
	ck(ui._detail_state.text.begins_with("Level too low: needs level 6"), "the full reason: %s" % ui._detail_state.text)
	ck(not ui._hotbar_box.visible and ui._pick_button.disabled, "not learned: no hotbar row, Pick disabled")
	await _mouse(ui._rows["toughness"])
	ck(_facts(ui).get("Effect") == "+10 max HP" and ui._detail_state.text.begins_with("Can learn now"), "a passive's effect: %s" % _facts(ui).get("Effect"))

	print("[4] Mouse: a click only selects; Pick / Undo / right click are pending")
	var jp: int = sm.get_job_points()
	await _mouse(ui._rows["toughness"], MOUSE_BUTTON_LEFT, true)
	ck(not sm.is_unlocked("toughness") and ui.plan.is_empty(), "a double click no longer learns (B77 / D283 replaced)")
	await _mouse(ui._pick_button)
	ck(ui.node_state("toughness") == S.PICKED and not sm.is_unlocked("toughness") and sm.get_job_points() == jp, "Pick marks it, nothing spent")
	ck(ui._jp_value.text == "%d JP" % (jp - 1) and _note(ui, "toughness") == "Picked" and _marker(ui, "toughness") == ui.ICON_PICKED, "the header shows what is left (%s)" % ui._jp_value.text)
	ck(ui._pending_label.text == "To spend: 1 JP" and not ui._accept_button.disabled, "the action bar: %s" % ui._pending_label.text)
	await _mouse(ui._undo_button)
	ck(ui.plan.is_empty() and ui.node_state("toughness") == S.CAN_LEARN, "Undo takes it back")
	await _mouse(ui._pick_button)
	await _mouse(ui._rows["toughness"], MOUSE_BUTTON_RIGHT)
	ck(ui.plan.is_empty(), "a right click takes it back too")

	print("[5] Keyboard and gamepad on the nodes")
	ui._rows["devotion"].grab_focus()
	await process_frame
	ck(ui._selected_id == "devotion", "focus selects")
	await _key(KEY_ENTER)
	ck(ui.plan.skill_picks("devotion") == 1, "Enter picks")
	await _key(KEY_BACKSPACE)
	ck(ui.plan.skill_picks("devotion") == 0, "Backspace takes it back")
	await _pad(JOY_BUTTON_A)
	ck(ui.plan.skill_picks("devotion") == 1, "pad A picks")
	await _pad(JOY_BUTTON_X)
	ck(ui.plan.is_empty(), "pad X takes it back")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	ck(_focus() != null and ui._rows.values().has(_focus()), "D-pad moves between nodes (%s)" % (_focus().name if _focus() else "none"))
	for i in 14:
		if _focus() in ui._tree_tabs.get_children():
			break
		await _pad(JOY_BUTTON_DPAD_UP)
	ck(_focus() in ui._tree_tabs.get_children(), "D-pad up reaches the oath tabs (%s)" % (_focus().name if _focus() else "none"))
	for i in 3:
		if _focus() == ui._tree_tabs.get_child(2):
			break
		await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	for i in 2: await process_frame
	ck(ui._shown_oath == "warden" and ui._rows.has("bulwark") and not ui._rows.has("radiant_smite"), "A on the Warden tab shows its tree")

	print("[6] A picked prerequisite opens its skill; undoing it drops the skill (cascade)")
	ck(sm.swear_oath("warden") == R.OK, "swore the Warden oath")
	for i in 2: await process_frame
	ck(ui.node_state("bulwark") == S.LOCKED and _note(ui, "bulwark") == "Locked", "Bulwark needs Shield Block: locked")
	await _mouse(ui._rows["shield_block"])
	await _mouse(ui._pick_button)
	ck(ui.node_state("bulwark") == S.CAN_LEARN, "Shield Block picked → Bulwark can be picked")
	var link: Array = ui._links.links.filter(func(l): return l[1] == ui._rows["bulwark"])[0]
	ck(link[0] == ui._rows["shield_block"] and bool(link[2]), "the Shield Block → Bulwark line lights up")
	await _mouse(ui._rows["bulwark"])
	await _key(KEY_ENTER)
	ck(ui.plan.skill_picks("bulwark") == 1 and ui.plan.jp_cost() == 2, "Bulwark picked (2 JP pending)")
	await _mouse(ui._rows["shield_block"], MOUSE_BUTTON_RIGHT)
	ck(ui.plan.is_empty(), "undoing Shield Block drops Bulwark too")

	print("[7] Esc / B drop the picks and keep the screen; Accept spends")
	await _mouse(ui._rows["toughness"])
	await _mouse(ui._pick_button)
	await _key(KEY_ESCAPE)
	for i in 2: await process_frame
	ck(ui.plan.is_empty() and get_first_node_in_group("game_menu") != null and ui.is_visible_in_tree(), "Esc drops the picks, the menu stays")
	await _mouse(ui._pick_button)
	await _pad(JOY_BUTTON_B)
	for i in 2: await process_frame
	ck(ui.plan.is_empty() and get_first_node_in_group("game_menu") != null, "pad B the same")
	jp = sm.get_job_points()
	await _mouse(ui._pick_button)  # Toughness
	await _mouse(ui._rows["shield_block"])
	await _mouse(ui._pick_button)
	await _mouse(ui._rows["bulwark"])
	await _mouse(ui._pick_button)
	await _mouse(ui._cancel_button)
	ck(ui.plan.is_empty() and not sm.is_unlocked("toughness"), "the Cancel button drops them")
	await _mouse(ui._rows["toughness"])
	await _mouse(ui._pick_button)
	await _mouse(ui._rows["shield_block"])
	await _mouse(ui._pick_button)
	await _mouse(ui._rows["bulwark"])
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_Y)
	for i in 2: await process_frame
	ck(sm.is_unlocked("toughness") and sm.is_unlocked("shield_block") and sm.is_unlocked("bulwark"), "pad Y accepts all three")
	ck(sm.get_job_points() == jp - 3 and ui.plan.is_empty() and ui._jp_value.text == "%d JP" % sm.get_job_points(), "3 JP spent once (%d → %d)" % [jp, sm.get_job_points()])
	ck(ui.node_state("bulwark") == S.LEARNED and _note(ui, "bulwark") == "R1" and _marker(ui, "bulwark") == ui.ICON_CHECK, "learned: check icon and rank")
	await _key(KEY_ENTER)  # фокус на Bulwark: ранг
	ck(ui.plan.skill_picks("bulwark") == 1 and _note(ui, "bulwark") == "R1 +1", "Enter on a learned skill picks a rank (R1 +1)")
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(sm.get_rank("bulwark") == 2, "the Accept button ranks it up")
	await _mouse(ui._rows["toughness"])
	await _mouse(ui._pick_button)
	await _key(KEY_F)
	for i in 2: await process_frame
	ck(sm.get_rank("toughness") == 2, "key F accepts")

	print("[8] Put a learned active skill on the hotbar from this screen (D331)")
	await _mouse(ui._rows["healing_palm"])
	await _mouse(ui._pick_button)
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(sm.is_unlocked("healing_palm") and ui._hotbar_box.visible, "learned active: the hotbar row shows")
	var palm_slot: int = sm.get_slot_of_skill("healing_palm")
	ck(ui._slot_buttons[palm_slot].button_pressed and ui._slot_buttons[palm_slot].text == "%d · Healing Palm" % (palm_slot + 1), "its slot is marked (%d)" % (palm_slot + 1))
	await _mouse(ui._slot_buttons[2])
	ck(sm.get_equipped_skill(2) == "healing_palm" and ui._slot_buttons[2].button_pressed, "a click on slot 3 puts it there")
	await _key(KEY_2)
	ck(sm.get_equipped_skill(1) == "healing_palm", "key 2 (the hotbar key) puts it in slot 2")
	await _pad(JOY_BUTTON_BACK)
	ck(sm.get_equipped_skill(3) == "healing_palm", "pad Back (hotbar slot 4) puts it in slot 4")
	ui._slot_buttons[0].grab_focus()
	await process_frame
	await _pad(JOY_BUTTON_A)
	ck(sm.get_equipped_skill(0) == "healing_palm", "pad A on the focused slot 1 button")
	await _mouse(ui._rows["toughness"])
	ck(not ui._hotbar_box.visible, "a passive has no hotbar row")
	await _key(KEY_3)
	ck(sm.get_equipped_skill(2) != "toughness", "the hotbar key does nothing for a passive")

	print("[9] Leaving with picks spends nothing")
	jp = sm.get_job_points()
	await _mouse(ui._rows["toughness"])
	await _mouse(ui._pick_button)
	menu.switch_to_tab("Inventory")
	for i in 4: await process_frame
	ck(ui.plan.is_empty() and sm.get_job_points() == jp and sm.get_rank("toughness") == 2, "another tab drops the picks")
	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
