extends SceneTree

## Самоперевірка екрана World Map (Phase 5.10).
##   godot --headless --path . --script res://SampleProject/UI/verify_world_map.gd
##
## MetSys — джерело правди поведінки; перевіряємо, що рестайл нічого не зламав.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	# Автозавантаження не резолвиться як глобальний ідентифікатор у скрипті-MainLoop.
	var met: Node = root.get_node_or_null("MetSys")

	print("[1] opens via tab")
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Inventory")
	for i in 5: await process_frame
	var inv: Node = menu.find_child("InventoryComponent", true, false)
	menu.switch_to_tab("World Map")
	for i in 8: await process_frame
	var map: Node = menu.find_child("MetSysMapComponent", true, false)
	ck(map != null, "MetSysMapComponent present")
	if map == null:
		_done()
		return
	ck(map.is_visible_in_tree(), "World Map visible after tab switch")
	ck(inv == null or not inv.is_visible_in_tree(), "previous screen hidden")
	ck(map.is_map_active, "map activated by the tab switch")

	print("[2] MetSys behaviour preserved")
	ck(map.map_view != null, "MetSys MapView created")
	ck(map.player_location != null, "player marker node created")
	ck(map.has_method("update_offset"), "centring API intact")
	ck(map.has_method("update_percent"), "explored percentage API intact")
	var ratio: float = met.get_explored_ratio()
	ck(ratio >= 0.0 and ratio <= 1.0, "explored ratio is valid (%.3f)" % ratio)

	print("[3] explored percentage reflects MetSys")
	map.update_percent()
	await process_frame
	var pct: Label = map.get_node_or_null("%PercentLabel")
	ck(pct != null, "percent label present")
	if pct:
		var expected := "%03d%%" % int(ratio * 100)
		ck(pct.text == expected, "percent matches MetSys (%s)" % pct.text)

	print("[4] player marker uses real position")
	var coords: Vector2i = met.get_current_flat_coords()
	map.update_offset()
	await process_frame
	ck(map.offset == coords - map.SIZE / 2, "offset centres on the real player cell")
	var src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/metsys_map_component.gd", FileAccess.READ).get_as_text()
	ck(src.find("get_current_flat_coords") != -1, "marker driven by MetSys coords, not faked")

	print("[5] input uses InputMap, not raw keycodes")
	ck(src.find("KEY_LEFT") == -1 and src.find("KEY_RIGHT") == -1, "no hardcoded KEY_* constants")
	ck(src.find("ui_left") != -1 and src.find("ui_down") != -1, "uses ui_* actions")
	var before: Vector2i = map.offset
	var ev := InputEventAction.new()
	ev.action = &"ui_right"
	ev.pressed = true
	map._input(ev)
	await process_frame
	ck(map.offset == before + Vector2i.RIGHT, "map pans on ui_right (%s -> %s)" % [str(before), str(map.offset)])

	print("[6] bottom-bar hints are truthful")
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ck(bar != null, "bottom bar present")
	if bar:
		var hint: String = bar._hint_label.text
		ck(hint.find("pan") >= 0, "hint mentions panning (%s)" % hint)
		ck(hint.findn("fast travel") < 0, "no hint for unimplemented actions")

	print("[7] chrome from Figma")
	ck(map.get_node_or_null("%MapTitle") != null, "map title block present")
	ck(map.get_node_or_null("%MapSubtitle") != null, "map subtitle present")
	ck(map.get_node_or_null("%ExploredPanel") != null, "explored panel present")
	var scene_text: String = FileAccess.open(
		"res://SampleProject/Scenes/Menus/Game/metsys_map_component.tscn", FileAccess.READ).get_as_text()
	ck(scene_text.find("StyleBoxFlat_bg") == -1, "local duplicate style removed")
	ck(scene_text.find("theme_type_variation") != -1, "uses shared theme variations")

	print("[8] no map state lost across menu close/open")
	var kept_offset: Vector2i = map.offset
	ui.close_game_menu()
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes (ui_cancel path)")
	ck(not paused, "game unpauses")
	ui.open_game_menu()
	for i in 12: await process_frame
	var menu2: Node = get_first_node_in_group("game_menu")
	menu2.switch_to_tab("World Map")
	for i in 8: await process_frame
	var map2: Node = menu2.find_child("MetSysMapComponent", true, false)
	ck(map2 != null and map2.map_view != null, "map rebuilds cleanly on reopen")
	ck(met.get_explored_ratio() == ratio, "MetSys exploration data unchanged (%.3f)" % met.get_explored_ratio())

	print("[9] other screens unaffected")
	for tab in ["Inventory", "Equipment", "Status", "Skills"]:
		menu2.switch_to_tab(tab)
		for i in 4: await process_frame
	menu2.switch_to_tab("World Map")
	for i in 5: await process_frame
	ck(map2.is_visible_in_tree(), "map still works after cycling every tab")
	ui.close_game_menu()
	for i in 5: await process_frame
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
