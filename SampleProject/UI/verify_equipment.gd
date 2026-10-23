extends SceneTree

## Самоперевірка екрана Equipment (Phase 5.3).
##   godot --headless --path . --script res://SampleProject/UI/verify_equipment.gd

var ArmourWeight: GDScript

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame; await process_frame
	# Меню існує лише в запущеній грі (Game, гравець, нижня панель) — тест відкриває його там само.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var boot_game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(boot_game)
	current_scene = boot_game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var intro_dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var im: Node = sl.get_inventory_manager()
	var db: Node = sl.get_item_database()
	var cm: Node = sl.get_character_manager()
	for id in ["iron_sword", "copper_sword", "iron_armor", "iron_helmet", "iron_shield", "leather_armor"]:
		im.add_item(id, 1)
	await process_frame

	print("[1] open")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Equipment")
	for i in 8: await process_frame
	var eq: Node = menu.find_child("EquipmentComponent", true, false)
	ck(eq != null, "EquipmentComponent present")
	if eq == null: _done(); return
	ck(eq.is_visible_in_tree(), "Equipment visible after tab switch")
	ck(eq.game_manager != null, "valid game_manager")

	print("[2] slots come from gameplay data")
	var slot_ids: Array = []
	for e in eq.SLOTS: slot_ids.append(e[0])
	var real: Array = gm.player_state.get("equipment", {}).keys()
	real.sort(); var shown: Array = slot_ids.duplicate(); shown.sort()
	ck(shown == real, "11 slot rows match player_state.equipment exactly")
	ck(eq._slot_list.get_child_count() == 12, "12 rows rendered (mace — D147)")

	print("[3] keyboard focus + row state")
	var row0: Button = eq._slot_rows["sword"]
	ck(row0.focus_mode == Control.FOCUS_ALL, "slot rows are keyboard focusable")
	row0.grab_focus(); for i in 2: await process_frame
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ck(bar != null and bar._hint_label.text.find("Sword") >= 0, "focus publishes slot hint (%s)" % bar._hint_label.text)
	ck(row0.get_node("Row/ItemName").text == eq.PLACEHOLDER, "empty slot shows (empty)")
	ck(not row0.get_node("Row/Dot").visible, "no accent dot when empty")

	print("[4] equipping affects real stats")
	var before: int = gm.calculate_physical_damage()
	eq._equip("sword", "iron_sword", db.get_item("iron_sword"))
	for i in 4: await process_frame
	var after: int = gm.calculate_physical_damage()
	ck(after > before, "Phys. Atk. rose on equip (%d -> %d)" % [before, after])
	ck(after == before + 15, "delta equals item attack stat (+15)")
	ck(row0.get_node("Row/ItemName").text == "Iron Sword", "row shows equipped item")
	ck(row0.get_node("Row/Dot").visible, "accent dot shown when equipped")

	print("[5] persistence path")
	ck(gm.player_state.get("equipment", {}).get("sword") != null, "player_state updated (save-visible)")
	var snapshot: Dictionary = gm.player_state.get("equipment", {}).duplicate(true)

	print("[6] replacing equipment")
	eq._equip("sword", "copper_sword", db.get_item("copper_sword"))
	for i in 4: await process_frame
	ck(gm.player_state.equipment.sword.id == "copper_sword", "slot replaced, not duplicated")
	ck(gm.calculate_physical_damage() == before + 10, "stats follow the replacement (+10)")

	print("[6b] Max. SP row (D24)")
	var sp_line: Node = eq._right_attrs.get_child(0).get_child(0)
	ck(sp_line.get_child(0).text == "Max. SP", "first right row is Max. SP")
	ck(sp_line.get_child(1).text == str(sl.get_skill_manager().get_max_sp()), "Max. SP shows the SP pool (%s)" % sp_line.get_child(1).text)
	ck(not sp_line.get_node(^"Delta").visible, "Max. SP has no delta")
	# D117: рядки — копії шаблонів %SlotRow / %AttrRow зі сцени, стиль з теми, а не StyleBoxFlat у коді.
	var rows: Array = eq._slot_rows.values() + eq._left_attrs.get_children() + eq._right_attrs.get_children()
	ck(rows.size() == eq.SLOTS.size() + eq.ATTR_ROWS.size(), "%d slot rows + %d attribute rows" % [eq.SLOTS.size(), eq.ATTR_ROWS.size()])
	ck(rows.all(func(r: Control) -> bool: return r.theme_type_variation != &"" and not r.has_theme_stylebox_override(&"panel")),
		"slot and attribute rows are template copies styled by the theme (D117)")

	print("[7] incompatible items rejected")
	eq._equip("head", "iron_sword", db.get_item("iron_sword"))
	for i in 3: await process_frame
	ck(gm.player_state.equipment.get("head") == null, "sword refused by head slot")
	ck(not InventorySlotRules.fits(db.get_item("iron_sword"), "head"), "rule says sword !fits head")
	ck(InventorySlotRules.fits(db.get_item("iron_helmet"), "head"), "rule says helmet fits head")

	print("[8] Status reflects equipment with no sync code")
	menu.switch_to_tab("Status")
	for i in 6: await process_frame
	var st: Node = menu.find_child("StatsComponent", true, false)
	var shown_atk: String = st._left_attrs.get_child(0).get_child(0).get_child(2).text
	ck(shown_atk == str(gm.calculate_physical_damage()), "Status Phys. Atk. matches live value (%s)" % shown_atk)
	menu.switch_to_tab("Equipment")
	for i in 5: await process_frame

	print("[9] unequip all")
	eq._on_unequip_all_pressed()
	for i in 6: await process_frame
	var any := false
	for s_id in gm.player_state.get("equipment", {}):
		if gm.player_state.equipment[s_id] != null: any = true
	ck(not any, "all slots cleared")
	ck(gm.calculate_physical_damage() == before, "stats back to unequipped baseline")

	print("[10] optimize")
	eq._on_optimize_pressed()
	for i in 8: await process_frame
	ck(gm.player_state.equipment.get("sword") != null, "optimize filled the sword slot")
	ck(gm.player_state.equipment.sword.id == "iron_sword", "optimize picked the stronger sword")

	print("[11] inventory counts untouched")
	ck(im.get_item_count("iron_sword") == 1, "equipping does not consume inventory count")

	print("[12] save / load round-trip")
	var saved: Dictionary = gm.player_state.get("equipment", {}).duplicate(true)
	var psm: Node = gm.get_node("PlayerStateManager")
	psm.player_state["equipment"] = {}
	for i in 2: await process_frame
	psm.player_state["equipment"] = saved.duplicate(true)
	cm._sync_character_from_player_state()
	for i in 3: await process_frame
	ck(gm.player_state.equipment.get("sword") != null, "equipment survives a state round-trip")
	ck(cm.get_active_character().equipment.get("sword") != null, "character rehydrated from player_state")

	ArmourWeight = load("res://SampleProject/Scripts/Systems/ArmourWeight.gd")
	print("[12b] armour weight (D592): light — longer roll, heavy — more defence and a shorter roll")
	var mover: Node = gm.get_current_player().mover
	var passive: float = sl.get_skill_manager().passive_value("roll_length")
	eq._on_unequip_all_pressed()
	for i in 4: await process_frame
	ck(ArmourWeight.worn_class() == "light", "no body armour is light (%s)" % ArmourWeight.worn_class())
	var bare_def: int = gm.calculate_physical_defense()
	eq._equip("body", "leather_armor", db.get_item("leather_armor"))
	for i in 4: await process_frame
	ck(ArmourWeight.worn_class() == "light", "leather armour is light")
	ck(is_equal_approx(mover.roll_factor(), 1.0 + passive + 0.15), "light: roll ×%.2f (+15%%)" % mover.roll_factor())
	ck(gm.calculate_physical_defense() == bare_def + 10, "light: defence is the item's +10 only (%d)" % gm.calculate_physical_defense())
	ck(eq._slot_rows["body"].get_node("Row/ItemName").text.find("Light armour") >= 0, "BODY row names the weight (%s)" % eq._slot_rows["body"].get_node("Row/ItemName").text)
	eq._equip("body", "iron_armor", db.get_item("iron_armor"))
	for i in 4: await process_frame
	ck(ArmourWeight.worn_class() == "heavy", "iron armour is heavy")
	ck(is_equal_approx(mover.roll_factor(), 1.0 + passive - 0.15), "heavy: roll ×%.2f (−15%%)" % mover.roll_factor())
	ck(gm.calculate_physical_defense() == bare_def + 20 + 5, "heavy: defence +20 item +5 weight (%d)" % gm.calculate_physical_defense())
	ck(eq._slot_rows["body"].get_node("Row/ItemName").text.find("Heavy armour") >= 0, "BODY row says heavy")
	mover.start_roll()
	ck(is_equal_approx(mover.roll_length, mover.roll_duration * mover.roll_factor()), "a real roll uses the weight (%.3f s)" % mover.roll_length)
	for i in 30: await physics_frame

	print("[13] back / close")
	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes")
	ck(not paused, "game unpauses")
	_done()

func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
