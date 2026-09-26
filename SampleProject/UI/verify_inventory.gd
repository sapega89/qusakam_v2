extends SceneTree

## Самоперевірка екрана інвентарю (Phase 5).
##
## Запуск:
##   godot --headless --path . --script res://SampleProject/UI/verify_inventory.gd
var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame; await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var inv_mgr: Node = sl.get_inventory_manager()
	# дати трохи предметів різних типів
	inv_mgr.add_item("iron_ore", 3)
	inv_mgr.add_item("potion", 2)
	await process_frame

	print("[1] open")
	ui.open_game_menu()
	for i in 12: await process_frame
	var gm: Node = get_first_node_in_group("game_menu")
	ck(gm != null, "game menu opens")
	var inv: Node = gm.find_child("InventoryComponent", true, false)
	ck(inv != null, "InventoryComponent present")
	if inv == null: _done(); return
	ck(inv.visible, "Inventory visible by default")

	print("[2] categories")
	var tabs: Node = inv.find_child("Tabs", true, false)
	ck(tabs != null and tabs.get_child_count() == 5, "5 category tabs")
	var names: Array = []
	for b in tabs.get_children(): names.append(b.text)
	ck(names == ["ALL","CONSUMABLES","MATERIALS","EQUIPMENT","KEY ITEMS"], "tab labels match Figma: %s" % str(names))
	var key_tab: Button = tabs.get_node_or_null("key_items")
	ck(key_tab != null and key_tab.disabled, "KEY ITEMS visible but disabled")
	ck(key_tab != null and key_tab.visible, "KEY ITEMS still visible")

	print("[3] switching + counts")
	var counts: Dictionary = {}
	for id in ["all","consumables","materials","equipment"]:
		inv._select_category(StringName(id))
		await process_frame
		counts[id] = inv.items.size()
		print("      %s -> %d rows" % [id, inv.items.size()])
	ck(counts["all"] >= counts["consumables"], "ALL >= CONSUMABLES")
	ck(counts["materials"] > 0, "MATERIALS non-empty (iron_ore added)")
	ck(counts["consumables"] > 0, "CONSUMABLES non-empty (potion added)")

	print("[4] equipment = weapon + armor")
	inv._select_category(&"equipment")
	await process_frame
	var bad := 0
	for it in inv.items:
		var t: String = String(it["item_data"].get("type",""))
		if t != "weapon" and t != "armor": bad += 1
	ck(bad == 0, "EQUIPMENT contains only weapon/armor")

	print("[5] empty category behaviour")
	inv._select_category(&"key_items")
	await process_frame
	ck(inv._current_category != &"key_items", "disabled tab refuses selection")

	print("[6] rows + selection + details")
	inv._select_category(&"all")
	for i in 3: await process_frame
	var list: Node = inv.find_child("ItemList", true, false)
	ck(list.get_child_count() == inv.items.size(), "row count == item count")
	if list.get_child_count() > 0:
		var r0 = list.get_child(0)
		ck(r0.button_pressed, "first row selected by default")
		ck(r0.tooltip_text != "", "row exposes item details via tooltip")
		var r1 = list.get_child(mini(1, list.get_child_count()-1))
		r1.emit_signal("row_selected", r1.index)
		await process_frame
		ck(inv._selected_index == r1.index, "row selection updates index")

	print("[7] equipment-selection flow")
	ck(inv.has_method("set_equipment_selection_mode"), "set_equipment_selection_mode preserved")
	inv.set_equipment_selection_mode(true, "sword", null)
	for i in 3: await process_frame
	ck(inv.equipment_selection_mode, "equipment selection mode on")
	var only_swords := true
	for it in inv.items:
		if String(it["item_data"].get("category","")) != "sword": only_swords = false
	ck(only_swords, "slot filter keeps only matching items")
	inv.set_equipment_selection_mode(false)
	await process_frame

	print("[8] save/load")
	var before: Dictionary = inv_mgr.save_to_dict()
	inv_mgr.load_from_dict(before)
	await process_frame
	ck(inv_mgr.save_to_dict() == before, "InventoryManager save/load round-trips")
	ck(inv_mgr.get_item_count("iron_ore") == 3, "item counts survive reload")

	print("[9] data contract")
	var gm2: Node = sl.get_game_manager()
	ck(inv.game_manager != null, "BaseMenuComponent receives a valid game_manager")
	ck(inv.item_database != null, "BaseMenuComponent receives a valid item_database")
	for m in ["calculate_max_health","calculate_physical_damage","calculate_magic_damage",
			"calculate_physical_defense","calculate_magic_defense","calculate_attack_speed",
			"calculate_dodge_chance","calculate_accuracy","calculate_critical_chance",
			"get_class_data","switch_character","get_current_player","get_active_character",
			"get_all_characters"]:
		ck(gm2.has_method(m), "GameManager exposes %s()" % m)
	ck(gm2.calculate_max_health() > 0, "calculate_max_health() returns a real value (%d)" % gm2.calculate_max_health())
	var ch = gm2.get_active_character()
	var direct: int = StatCalculator.calculate_max_health(ch.attributes, ch.get_equipment_stats())
	ck(gm2.calculate_max_health() == direct, "delegate matches StatCalculator (no duplicated formula)")
	ck(typeof(gm2.get_class_data(ch.class_id, ch.subclass_id)) == TYPE_DICTIONARY, "get_class_data() delegates")
	ck(gm2.player_state is Dictionary, "player_state delegate typed")
	ck(gm2.characters is Dictionary, "characters delegate typed")

	print("[10] description not mouse-only")
	inv._select_category(&"all")
	for i in 3: await process_frame
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ck(bar != null, "bottom bar reachable via group")
	var list2: Node = inv.find_child("ItemList", true, false)
	if bar and list2.get_child_count() > 1:
		var r = list2.get_child(1)
		ck(r.tooltip_text != "", "row still has mouse tooltip")
		r.grab_focus()
		for i in 3: await process_frame
		ck(bar._hint_label.text.find(String(inv.items[1]["name"])) >= 0,
			"keyboard focus publishes description to bottom bar")
		inv.visible = false
		for i in 2: await process_frame
		ck(bar._hint_label.text == bar.DEFAULT_HINT, "hint restored when inventory hides")
		inv.visible = true
		for i in 2: await process_frame

	print("[11] close / back")
	ui.close_game_menu()
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes")
	ck(not paused, "game unpauses on close")
	_done()

func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
