extends SceneTree
const Kit = preload("res://SampleProject/UI/input_kit.gd")

## Вікно навичок Dragon Nest (D674; до того BACKLOG 43, D330–D334) справжнім вводом: миша, клавіші, InputEventJoypadButton.
## Вміщається без прокрутки, клітинки за slot з лініями, розміри з UITokens, стани клітинок (бейдж рівня, ранг, «+»),
## панель деталей (ранг і ефект зараз → далі), Learn +1 / Reset і Accept, каскад зняття передумови, Esc скидає позначене,
## ранги до найвищого, слот хотбара, атрибути, Reset all лише на місці медитації.
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

func _rank(ui: Node, id: String) -> Label:
	return ui._rows[id].get_parent().get_node(^"Rank")

func _badge(ui: Node, id: String) -> Label:
	return ui._rows[id].get_node(^"LevelBadge/Label")

func _plus(ui: Node, id: String) -> bool:
	return ui._rows[id].get_node(^"Plus").visible

func _facts(ui: Node) -> Dictionary:
	var out := {}
	var cells: Array = ui._detail_grid.get_children().filter(func(c): return not c.is_queued_for_deletion() and c.visible)
	for i in range(0, cells.size() - 1, 2):
		out[cells[i].text] = cells[i + 1].text
	return out

func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)  # headless скидає вікно до 64×64, а миша клікає в координатах 1920×1080
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	Kit.pre_d815_hero(self)  # D815: this test buys skills and counts JP from a hero who has none
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var SkillManagerScript = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd")
	var R = SkillManagerScript.Result
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	sm.add_job_points(6)  # 4 за рівні 2–5 + 6 = 10
	ck(sm.swear_oath("paladin") == R.OK, "the census gave the Paladin path (D727: Skills shows the base and the chosen tree, D728)")

	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var ui: Node = menu.find_child("SkillsComponent", true, false)
	var S = ui.NodeState

	print("[1] Fits without scrolling; cells by slot; sizes from UITokens")
	ck(ui.find_children("*", "ScrollContainer", true, false).is_empty(), "no ScrollContainer on the screen")
	var window: Control = ui.get_node(^"Window")
	ck(window.get_combined_minimum_size().y <= window.size.y, "the window's content fits its height (%d of %d)" % [window.get_combined_minimum_size().y, window.size.y])
	ck(window.offset_bottom == -UITokens.BOTTOM_BAR_HEIGHT, "the window ends above the hint bar (%d)" % window.offset_bottom)
	for panel: Control in [ui._left_panel, ui._right_panel]:
		var stage: Control = panel.get_node(^"Tree/Stage")
		var grid: GridContainer = ui._grid(panel)
		ck(grid.get_combined_minimum_size().y + grid.offset_top <= stage.size.y, "%s: the grid fits (%d of %d)" % [panel.name, grid.get_combined_minimum_size().y, stage.size.y])
		ck(grid.columns == UITokens.SKILL_GRID_COLUMNS and grid.get_theme_constant(&"h_separation") == UITokens.SKILL_GRID_GAP_H
				and grid.get_theme_constant(&"v_separation") == UITokens.SKILL_GRID_GAP_V, "%s: columns and gaps from UITokens" % panel.name)
		ck(grid.get_child_count() == UITokens.SKILL_GRID_COLUMNS * UITokens.SKILL_GRID_ROWS, "%s: a 4 × 5 grid" % panel.name)
	ck(ui._cell.custom_minimum_size.x == UITokens.SKILL_SLOT_SIZE and ui._cell.get_node(^"Slot").custom_minimum_size == Vector2(UITokens.SKILL_SLOT_SIZE, UITokens.SKILL_SLOT_SIZE),
			"the cell is SKILL_SLOT_SIZE")
	ck(ui.get_node(^"Window/Center/Body/Columns/SidePanel").custom_minimum_size.x == UITokens.SKILL_DETAIL_WIDTH
			and ui._tree_tab.custom_minimum_size.x == UITokens.SKILL_TAB_WIDTH, "detail width and tab width from UITokens")
	var misplaced: Array = ui._rows.keys().filter(func(id: String) -> bool:
			var d: SkillDefinition = ui._skill_database.get_skill(id)
			return ui._rows[id].get_parent().get_index() != d.slot.y * UITokens.SKILL_GRID_COLUMNS + d.slot.x)
	ck(misplaced.is_empty(), "every skill sits in its slot's cell %s" % [misplaced])
	var keen: Rect2 = ui._rows["keen_edge"].get_global_rect()
	var training: Rect2 = ui._rows["weapon_training"].get_global_rect()
	ck(is_equal_approx(keen.position.x, training.position.x) and keen.position.y > training.end.y, "Keen Edge right under Weapon Training")
	var styled: Array = ui.find_children("*", "Control", true, false).filter(
			func(c: Control) -> bool: return c.has_theme_stylebox_override(&"panel") or c.has_theme_color_override(&"font_color"))
	ck(styled.is_empty(), "cells and panels carry no stylebox / colour overrides (D117): %s" % [styled.map(func(c): return String(c.name))])
	var links: Array = ui._links(ui._left_panel).links + ui._links(ui._right_panel).links
	ck(links.size() == 11, "11 lines in the Paladin view (4 in the trunk, 7 in Paladin): %d" % links.size())
	ck(links.all(func(l: Array) -> bool: return not bool(l[2])), "nothing learned: every line is grey")

	print("[2] Cell states: icon, level badge, rank, + (D674, D332)")
	ck(ui.node_state("toughness") == S.CAN_LEARN and _rank(ui, "toughness").text == "0 / 3" and _badge(ui, "toughness").text == "Lv 1"
			and _badge(ui, "toughness").theme_type_variation == &"SkillLevelBadgeLabel", "Toughness: can learn, 0 / 3, badge Lv 1")
	ck(ui._rows["toughness"].get_node(^"Art").modulate.a == 1.0 and not _plus(ui, "toughness"), "a learnable skill: full icon, no + yet")
	ck(_rank(ui, "fire_strike").text == "0 / 5", "an active ranks to 5")
	ck(ui.node_state("fortitude") == S.LOCKED and _badge(ui, "fortitude").text == "Lv 12" and _badge(ui, "fortitude").theme_type_variation == &"SkillLevelBadgeLow",
			"Fortitude: locked, red Lv 12 (hero is level 5)")
	ck(is_equal_approx(ui._rows["fortitude"].get_node(^"Art").modulate.a, UITokens.SKILL_LOCKED_ICON_ALPHA), "a locked icon is dimmed (D605)")
	ck(ui._rows["toughness"].get_node(^"Art").self_modulate == UITokens.SKILL_ICON_PASSIVE and ui._rows["fire_strike"].get_node(^"Art").self_modulate == UITokens.SKILL_ICON_ACTIVE,
			"icon tints by kind (D605)")
	ck(ui.node_state("radiant_smite") == S.LOCKED and _badge(ui, "radiant_smite").theme_type_variation == &"SkillLevelBadgeLabel", "Radiant Smite before 3 JP in the base tree: locked, Lv 5 not red")
	ck(ui.node_state("rising_slash") == S.LOCKED and ui._reason_text("rising_slash") == "Coming later: this skill is not built yet.", "a planned v2 active (D535): coming later")

	print("[3] Detail panel: rank, effect now → next, costs (D334, D674)")
	await _mouse(ui._rows["fire_strike"])
	var facts := _facts(ui)
	ck(ui._selected_id == "fire_strike" and ui._detail_name.text == "Fire Strike" and ui._detail_kind.text == "Active · Holy Warrior · Rank 0 / 5", "a click selects Fire Strike: %s" % ui._detail_kind.text)
	ck(String(facts.get("Damage", "")).begins_with("—  →  ") and facts.get("SP cost") == "6" and not facts.has("Cooldown")
			and facts.get("Required level") == "6" and facts.get("Rank cost") == "1 JP" and facts.has("Weapon") and facts.has("Burn per second"), "facts: %s" % [facts])
	ck(ui._detail_state.text.begins_with("Level too low: needs level 6"), "the full reason: %s" % ui._detail_state.text)
	ck(not ui._hotbar_box.visible and ui._learn_button.disabled and ui._reset_button.disabled, "not learned: no hotbar row, Learn +1 and Reset disabled")
	ck(ui._detail_icon.texture != null and ui._detail_icon.self_modulate == UITokens.SKILL_ICON_ACTIVE, "the big icon")
	await _mouse(ui._rows["toughness"])
	ck(_facts(ui).get("Effect") == "—  →  +10 max HP" and ui._next_text.text == "+10 max HP" and not ui._learn_button.disabled, "a passive's effect: %s" % _facts(ui).get("Effect"))

	print("[4] Mouse: a click only selects; Learn +1 / Reset / right click are pending (D330)")
	var jp: int = sm.get_job_points()
	await _mouse(ui._rows["toughness"], MOUSE_BUTTON_LEFT, true)
	ck(not sm.is_unlocked("toughness") and ui.plan.is_empty(), "a double click does not learn")
	await _mouse(ui._learn_button)
	ck(ui.node_state("toughness") == S.PICKED and not sm.is_unlocked("toughness") and sm.get_job_points() == jp, "Learn +1 marks it, nothing spent")
	ck(ui._jp_value.text == str(jp - 1) and _rank(ui, "toughness").text == "1 / 3" and _rank(ui, "toughness").theme_type_variation == &"SkillRankPlanned",
			"skill points left and the planned rank in gold (%s, %s)" % [ui._jp_value.text, _rank(ui, "toughness").text])
	ck(ui._rows["toughness"].theme_type_variation == &"SkillSlotLearned" and not ui._rows["toughness"].get_node(^"LevelBadge").visible and _plus(ui, "toughness"),
			"a picked cell: gold frame, no level badge, + for the next rank")
	ck(ui._pending_label.text == "To spend: 1 JP" and ui._accept_button.visible and ui._cancel_button.visible, "the bottom bar: %s" % ui._pending_label.text)
	await _mouse(ui._learn_button)
	ck(ui.plan.skill_picks("toughness") == 2 and _rank(ui, "toughness").text == "2 / 3", "Learn +1 again: rank 2 planned")
	await _mouse(ui._reset_button)
	ck(ui.plan.is_empty() and ui.node_state("toughness") == S.CAN_LEARN and not ui._accept_button.visible, "Reset takes back all of its picks")
	await _mouse(ui._learn_button)
	await _mouse(ui._rows["toughness"], MOUSE_BUTTON_RIGHT)
	ck(ui.plan.is_empty(), "a right click takes one back")

	print("[5] Keyboard and gamepad on the cells")
	ui._rows["devotion"].grab_focus()
	await process_frame
	ck(ui._selected_id == "devotion", "focus selects")
	await _key(KEY_ENTER)
	ck(ui.plan.skill_picks("devotion") == 1, "Enter: Learn +1")
	await _key(KEY_BACKSPACE)
	ck(ui.plan.skill_picks("devotion") == 0, "Backspace takes it back")
	await _pad(JOY_BUTTON_A)
	ck(ui.plan.skill_picks("devotion") == 1, "pad A: Learn +1")
	await _pad(JOY_BUTTON_X)
	ck(ui.plan.is_empty(), "pad X takes it back")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	ck(_focus() == ui._rows["shield_bash"], "D-pad right: the next cell of the row (%s)" % (_focus().get_parent().name if _focus() else "none"))
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	ck(_focus() == ui._rows["shield_of_faith"], "and on into the oath tree (%s)" % (_focus().get_parent().name if _focus() else "none"))
	await _pad(JOY_BUTTON_DPAD_DOWN)
	ck(_focus() == ui._rows["aura_of_resolve"], "D-pad down: the cell below (%s)" % (_focus().get_parent().name if _focus() else "none"))
	for i in 8:
		if _focus() in ui._tree_tabs.get_children():
			break
		await _pad(JOY_BUTTON_DPAD_UP)
	ck(_focus() in ui._tree_tabs.get_children(), "D-pad up reaches the tabs (%s)" % (_focus().name if _focus() else "none"))
	var visible_tabs: Array = ui._tree_tabs.get_children().filter(func(t: Control) -> bool: return t.visible)
	ck(visible_tabs.map(func(t: Button) -> String: return t.text) == ["Holy Warrior", "Paladin"], "only the base and the chosen path's tabs (D728)")
	for i in 4:
		if _focus() == visible_tabs[1]:
			break
		await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	for i in 2: await process_frame
	ck(_focus() == visible_tabs[1] or ui._rows.values().has(_focus()), "the D-pad stays on the visible tabs (%s)" % (_focus().name if _focus() else "none"))
	ck(ui._shown_oath == "paladin" and ui._rows.has("radiant_smite") and not ui._rows.has("bulwark"), "A on the Paladin tab keeps its tree")

	print("[6] A picked prerequisite opens its skill; undoing it drops the skill (cascade)")
	# D497: навичка клятви 5-го рівня — від 3 JP у стовбурі; два вже вкладено, третє дасть позначений Shield Block.
	ck(sm.unlock_skill("devotion") == R.OK and sm.unlock_skill("weapon_training") == R.OK, "2 JP already in the base tree")
	sl.get_game_manager().player_state.oath = ""  # інша гра: перепис дав шлях без бога
	ck(sm.swear_oath("warden") == R.OK, "the Warden path chosen instead")
	for i in 2: await process_frame
	var trained: Array = ui._links(ui._left_panel).links.filter(func(l): return l[0] == ui._rows["weapon_training"].get_parent())
	ck(trained.size() == 2 and trained.all(func(l): return bool(l[2])), "learned Weapon Training: its two lines are gold")
	ck(ui.node_state("bulwark") == S.LOCKED and ui._reason_text("bulwark") == "Needs Shield Block first.", "Bulwark needs Shield Block (in the other panel)")
	await _mouse(ui._rows["shield_block"])
	await _mouse(ui._learn_button)
	ck(ui.node_state("bulwark") == S.CAN_LEARN, "Shield Block picked → Bulwark can be picked")
	await _mouse(ui._rows["bulwark"])
	await _key(KEY_ENTER)
	ck(ui.plan.skill_picks("bulwark") == 1 and ui.plan.jp_cost() == 2, "Bulwark picked (2 JP pending)")
	ck(ui._budgets.text == "Holy Warrior 3 / 14  ·  Warden of Balance 1 / 12", "budgets with the plan: %s" % ui._budgets.text)
	await _mouse(ui._rows["shield_block"], MOUSE_BUTTON_RIGHT)
	ck(ui.plan.is_empty(), "undoing Shield Block drops Bulwark too")

	print("[7] Esc / B drop the picks and keep the screen; Accept spends; ranks stop at the top")
	await _mouse(ui._rows["toughness"])
	await _mouse(ui._learn_button)
	await _key(KEY_ESCAPE)
	for i in 2: await process_frame
	ck(ui.plan.is_empty() and get_first_node_in_group("game_menu") != null and ui.is_visible_in_tree(), "Esc drops the picks, the menu stays")
	await _mouse(ui._learn_button)
	await _pad(JOY_BUTTON_B)
	for i in 2: await process_frame
	ck(ui.plan.is_empty() and get_first_node_in_group("game_menu") != null, "pad B the same")
	jp = sm.get_job_points()
	await _mouse(ui._learn_button)  # Toughness
	await _mouse(ui._rows["shield_block"])
	await _mouse(ui._learn_button)
	await _mouse(ui._rows["bulwark"])
	await _mouse(ui._learn_button)
	await _mouse(ui._cancel_button)
	ck(ui.plan.is_empty() and not sm.is_unlocked("toughness"), "the Cancel button drops them")
	await _mouse(ui._rows["toughness"])
	await _mouse(ui._learn_button)
	await _mouse(ui._rows["shield_block"])
	await _mouse(ui._learn_button)
	await _mouse(ui._rows["bulwark"])
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_Y)
	for i in 2: await process_frame
	ck(sm.is_unlocked("toughness") and sm.is_unlocked("shield_block") and sm.is_unlocked("bulwark"), "pad Y accepts all three")
	ck(sm.get_job_points() == jp - 3 and ui.plan.is_empty() and ui._jp_value.text == str(sm.get_job_points()), "3 JP spent once (%d → %d)" % [jp, sm.get_job_points()])
	ck(ui.node_state("bulwark") == S.LEARNED and _rank(ui, "bulwark").text == "1 / 3" and ui._rows["bulwark"].theme_type_variation == &"SkillSlotLearned"
			and _plus(ui, "bulwark"), "learned: gold frame, 1 / 3, + for the next rank")
	await _key(KEY_ENTER)  # фокус на Bulwark: ранг
	ck(ui.plan.skill_picks("bulwark") == 1 and _rank(ui, "bulwark").text == "2 / 3", "Enter on a learned skill picks a rank (2 / 3)")
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(sm.get_rank("bulwark") == 2, "the Accept button ranks it up")
	await _mouse(ui._rows["toughness"])
	var now_hp: String = _facts(ui).get("Effect", "")
	ck(now_hp == "+10 max HP  →  +13 max HP", "a passive's effect now → next: %s" % now_hp)
	await _mouse(ui._learn_button)
	await _mouse(ui._learn_button)
	ck(ui.plan.skill_picks("toughness") == 2 and ui._learn_button.disabled and ui._reason_text("toughness") == "Rank 3 after Accept.", "a passive stops at rank 3")
	await _key(KEY_F)
	for i in 2: await process_frame
	ck(sm.get_rank("toughness") == 3 and not _plus(ui, "toughness") and ui._reason_text("toughness") == "Max rank." and not ui._next_caption.visible,
			"key F accepts; at 3 / 3: no +, Max rank, no next rank")

	print("[8] Put a learned active skill on the hotbar from this screen (D331)")
	await _mouse(ui._rows["healing_palm"])
	await _mouse(ui._learn_button)
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(sm.is_unlocked("healing_palm") and ui._hotbar_box.visible, "learned active: the hotbar row shows")
	var palm_slot: int = sm.get_slot_of_skill("healing_palm")
	ck(ui._slot_buttons[palm_slot].button_pressed and ui._slot_buttons[palm_slot].tooltip_text == "%d · Healing Palm" % (palm_slot + 1)
			and ui._slot_buttons[palm_slot].get_node(^"Art").texture != null and ui._slot_buttons[palm_slot].get_node(^"Key/Label").text == str(palm_slot + 1),
			"its slot is marked (%d): the icon, the key number, the name in the tooltip" % (palm_slot + 1))
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

	print("[9] Only skills here: attributes wait in Status (D741); Reset all only at a meditation spot (D628, D629)")
	var attrs: Node = sl.get_attribute_manager()
	ck(ui.find_child("AttrPanel", true, false) == null and ui.find_child("AttributesButton", true, false) == null
			and ui.find_child("AttributeRow", true, false) == null, "no attribute panel, button or rows on the Skills screen")
	ck(attrs.get_unspent() > 0 and ui._attr_points_hint.visible and ui._attr_points_hint.text == "Attribute points: %d · in Status" % attrs.get_unspent(),
			"the points bar says how many attribute points wait in Status (%s)" % ui._attr_points_hint.text)
	ck(ui._detail.visible, "the side panel shows the skill")
	attrs.spend({"strength": attrs.get_unspent()})
	await process_frame
	ck(not ui._attr_points_hint.visible, "none left: the hint goes")
	ck(sm.can_respec() == R.NOT_MEDITATING and ui._reset_all_button.disabled and ui._reset_all_button.tooltip_text == "Reset at a meditation spot",
			"Reset all is closed away from a meditation spot")

	print("[10] 19 a tab: every cell fits with its details and is reached by the D-pad (skills v2 slice 2)")
	for tree_id: String in ["", ui._shown_oath]:
		ck(ui._cells_of(tree_id).size() == 19, "the %s tab shows 19 skills (D535)" % ui._tree_name(tree_id))
	# Найдовший опис з рядом хотбара (вивчена активна) — вікно не росте за екран (заголовок і вкладки не обрізано).
	for locale: String in ["en", "uk"]:
		TranslationServer.set_locale(locale)
		var tallest := ""
		var tallest_y := 0.0
		for id: String in ui._rows.keys() + ["toughness"]:
			ui._on_row_selected(id)
			ui._hotbar_box.visible = true
			var need: float = window.get_combined_minimum_size().y
			if need > tallest_y:
				tallest_y = need
				tallest = id
		ck(locale == "en" or ui._detail_name.text != "Toughness", "%s: the screen is in this language (%s)" % [locale, ui._detail_name.text])
		ck(tallest_y <= window.size.y, "%s: with the hotbar row, the tallest detail (%s) fits: %d of %d" % [locale, tallest, tallest_y, window.size.y])
	TranslationServer.set_locale("en")
	ui._on_row_selected("toughness")
	ck(ui._hotbar_slots.columns == SkillManagerScript.SLOT_COUNT and ui._slot_template.custom_minimum_size == Vector2(UITokens.SKILL_HOTBAR_SLOT_SIZE, UITokens.SKILL_HOTBAR_SLOT_SIZE),
			"the hotbar slots are one row of SKILL_HOTBAR_SLOT_SIZE squares")
	var crossing: Array = (ui._links(ui._left_panel).links + ui._links(ui._right_panel).links).filter(func(l: Array) -> bool:
			return l[0].get_node(^"Rank").get_global_rect().end.y > l[0].get_global_rect().end.y)
	ck(crossing.is_empty(), "every line starts under the prerequisite's rank label, not through it")
	ck(window.get_global_rect().position.y >= ui.get_global_rect().position.y, "the window's top (title, tabs) is on screen")
	# Геймпад: з першої клітинки D-pad (сусіди фокуса Godot) доходить до всіх 38 клітинок двох дерев.
	var cells: Array = ui._rows.values()
	var seen: Array = [cells[0]]
	var queue: Array = [cells[0]]
	while not queue.is_empty():
		var at: Control = queue.pop_back()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var next: Control = at.find_valid_focus_neighbor(side)
			if next != null and next in cells and not next in seen:
				seen.append(next)
				queue.append(next)
	ck(seen.size() == 38 and cells.size() == 38, "the D-pad reaches every cell: %d of %d" % [seen.size(), cells.size()])

	print("[11] Leaving with picks spends nothing")
	jp = sm.get_job_points()
	await _mouse(ui._rows["bulwark"])
	await _mouse(ui._learn_button)
	menu.switch_to_tab("Inventory")
	for i in 4: await process_frame
	ck(ui.plan.is_empty() and sm.get_job_points() == jp and sm.get_rank("bulwark") == 2, "another tab drops the picks")
	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
