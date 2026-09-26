extends SceneTree

## Самоперевірка екрана Status (Phase 5.2).
##
## Запуск:
##   godot --headless --path . --script res://SampleProject/UI/verify_status.gd

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame; await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var gm: Node = sl.get_game_manager()
	sl.get_xp_manager().add_xp(250)

	print("[1] open Status")
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Status")
	for i in 8: await process_frame
	var st: Node = menu.find_child("StatsComponent", true, false)
	ck(st != null, "StatsComponent present")
	if st == null: _done(); return
	ck(st.visible, "Status visible after tab switch")
	ck(st.game_manager != null, "Status has a valid game_manager")

	print("[2] real data, no fabrication")
	var ch = gm.get_active_character()
	ck(st._name_label.text == String(ch.name), "name from CharacterManager (%s)" % st._name_label.text)
	ck(st._level_label.text == "Lv.%d" % sl.get_xp_manager().get_level(), "level from XPManager (%s)" % st._level_label.text)
	ck(st._next_level_value.text.ends_with("EXP"), "EXP to next level shown (%s)" % st._next_level_value.text)
	ck(st._jp_value.text == st.PLACEHOLDER, "JP shown as placeholder (no JP system)")
	ck(st._sp_meter.get_node("Head/Value").text == st.PLACEHOLDER, "Max SP placeholder (no SP model)")

	print("[3] attributes come from StatCalculator")
	ck(st._left_attrs.get_child_count() == 4, "4 left attribute rows")
	ck(st._right_attrs.get_child_count() == 4, "4 right attribute rows")
	var hp_txt: String = st._hp_meter.get_node("Head/Value").text
	ck(hp_txt != st.PLACEHOLDER, "Max HP has a real value (%s)" % hp_txt)
	var expected: int = StatCalculator.calculate_physical_damage(ch.attributes, ch.get_equipment_stats())
	var shown: String = st._left_attrs.get_child(0).get_child(0).get_child(2).text
	ck(shown == str(expected), "Phys. Atk. matches StatCalculator (%s == %d)" % [shown, expected])

	print("[4] live refresh")
	var before: String = st._level_label.text
	sl.get_xp_manager().add_xp(100000)
	for i in 4: await process_frame
	ck(st._level_label.text != before, "level_up refreshes the screen (%s -> %s)" % [before, st._level_label.text])

	print("[5] party panel swap")
	var party: Node = get_first_node_in_group("ui_party_column")
	ck(party != null, "party column reachable")
	ck(party != null and not party.visible, "party column hidden while Status is open")
	menu.switch_to_tab("Inventory")
	for i in 6: await process_frame
	ck(party != null and party.visible, "party column restored when leaving Status")

	print("[6] back / close")
	ui.close_game_menu()
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes from Status flow")
	ck(not paused, "game unpauses")
	_done()

func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
