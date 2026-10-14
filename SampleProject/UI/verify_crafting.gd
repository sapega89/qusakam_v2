extends SceneTree

## Крафт у коваля (slice 4, design/crafting_mapping.md): матеріали + золото (D85),
## тимчасові ціни (D97), чотири станції (D108), панель рецепта → "Craft X?" / "Cannot Craft".
##   godot --headless --path . --script res://SampleProject/UI/verify_crafting.gd

var fails: Array[String] = []
var inv: Node
var ui: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _set_count(id: String, n: int) -> void:
	var have: int = inv.get_item_count(id)
	if have > n:
		inv.remove_item(id, have - n)
	elif have < n:
		inv.add_item(id, n - have)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _modal() -> Control:
	return ui.get_modal_layer().active_modal

func _press_modal(result: String) -> void:
	var modal := _modal()
	if result == "confirm":
		modal.confirmed.emit()
	else:
		modal.cancelled.emit()
	for i in 4: await process_frame

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	inv = sl.get_inventory_manager()
	ui = sl.get_ui_manager()
	var service = load("res://SampleProject/Scripts/Crafting/crafting_service.gd").new()
	var R = service.Result

	print("[1] Every recipe has a station tab and a (mock) gold cost")
	var per_station := {}
	for st in service.STATIONS:
		per_station[st.id] = service.recipes(st.id, &"all").size()
	ck(per_station == {"furnace": 4, "workbench": 2, "anvil": 6, "alchemy_table": 6}, "recipes per station %s" % per_station)
	var costs_ok := true
	for recipe_id in sl.get_item_database().get_all_recipes():
		costs_ok = costs_ok and int(sl.get_item_database().get_recipe(recipe_id).get("gold_cost", 0)) > 0
	ck(costs_ok, "all 18 recipes carry gold_cost > 0")
	ck(service.row("craft_iron_sword").detail == "Requires: 3 Iron Ingot, 1 Wood Plank", "materials line (%s)" % service.row("craft_iron_sword").detail)

	print("[2] Missing materials: refused, nothing taken")
	for id in ["iron_ingot", "wood_plank", "iron_sword"]:
		_set_count(id, 0)
	_set_count("iron_ingot", 1)
	_set_count("coin", 100)
	ck(service.craft("craft_iron_sword") == R.NOT_ENOUGH_MATERIALS, "NOT_ENOUGH_MATERIALS")
	ck(service.missing("craft_iron_sword") == [{"name": "Iron Ingot", "missing": 2}, {"name": "Wood Plank", "missing": 1}],
			"missing list %s" % [service.missing("craft_iron_sword")])
	ck(inv.get_item_count("iron_ingot") == 1 and inv.get_item_count("coin") == 100, "inventory untouched")

	print("[3] Missing gold: refused, nothing taken")
	_set_count("iron_ingot", 3)
	_set_count("wood_plank", 1)
	_set_count("coin", 5)
	ck(service.craft("craft_iron_sword") == R.NOT_ENOUGH_GOLD, "NOT_ENOUGH_GOLD")
	ck(inv.get_item_count("iron_ingot") == 3 and inv.get_item_count("coin") == 5, "inventory untouched")

	print("[4] Enough of both: exact consumption")
	_set_count("coin", 100)
	ck(service.craft("craft_iron_sword") == R.OK, "OK")
	ck(inv.get_item_count("iron_ingot") == 0, "3 Iron Ingot spent")
	ck(inv.get_item_count("wood_plank") == 0, "1 Wood Plank spent")
	ck(inv.get_item_count("coin") == 80, "20 gold spent (%d left)" % inv.get_item_count("coin"))
	ck(inv.get_item_count("iron_sword") == 1, "1 Iron Sword made")
	_set_count("wood_log", 1)
	_set_count("coin", 100)
	service.craft("craft_wood_plank")
	ck(inv.get_item_count("wood_plank") == 4, "a recipe that yields 4 gives 4")

	print("[5] The screen: CRAFT, four stations, two-line rows")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var menu: Control = load("res://SampleProject/Scenes/Crafting/crafting_menu.tscn").instantiate()
	layer.add_child(menu)
	paused = true
	for i in 6: await process_frame
	ck(menu._station_tabs.map(func(t): return t.text) == ["Furnace", "Workbench", "Anvil", "Alchemy"], "station tabs (D108)")
	menu._set_station(2)  # Anvil
	for i in 4: await process_frame
	var rows: Array = menu.get_rows()
	ck(rows.size() == 6, "6 anvil recipes (%d)" % rows.size())
	var sword_row = rows.filter(func(r): return r.data.id == "craft_iron_sword")[0]
	ck(sword_row.get_node("%DetailLabel").visible, "row shows the materials line")
	ck(sword_row.size.y >= UITokens.CRAFT_ROW_HEIGHT, "two-line row is taller (%d)" % sword_row.size.y)

	print("[6] Row → recipe panel → confirm → crafted")
	_set_count("iron_ingot", 3)
	_set_count("wood_plank", 1)
	_set_count("iron_sword", 0)
	_set_count("coin", 100)
	sword_row.row_activated.emit(sword_row.data)
	for i in 4: await process_frame
	ck(_modal() is RecipePanel, "the recipe panel opens")
	ck(_modal().get_node("%Title").text == "Iron Sword Recipe", "panel title (%s)" % _modal().get_node("%Title").text)
	ck(_modal().get_node("%Materials").get_child_count() == 2, "two material lines")
	ck(_modal().get_node("%StatsBox").visible, "expected stats shown (attack +15)")
	await _press_modal("confirm")
	ck(_modal() != null and _modal().title_label.text == "Craft Iron Sword?", "then \"Craft Iron Sword?\"")
	await _press_modal("confirm")
	ck(inv.get_item_count("iron_sword") == 1 and inv.get_item_count("coin") == 80, "crafted through the UI")
	ck(_modal() == null, "no modal left open")

	print("[7] Not enough materials → Cannot Craft, naming what is missing")
	rows = menu.get_rows()
	sword_row = rows.filter(func(r): return r.data.id == "craft_iron_sword")[0]
	sword_row.row_activated.emit(sword_row.data)
	for i in 4: await process_frame
	await _press_modal("confirm")
	ck(_modal() != null and _modal().title_label.text == "Cannot Craft", "\"Cannot Craft\"")
	ck(_modal() != null and _modal().description_label.text.contains("You are missing: Iron Ingot ×3, Wood Plank ×1"),
			"names the missing materials (%s)" % (_modal().description_label.text if _modal() else ""))
	await _press_modal("confirm")
	ck(inv.get_item_count("iron_sword") == 1, "nothing crafted")

	print("[8] Esc closes the screen")
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	var esc_key := InputEventKey.new()
	esc_key.keycode = KEY_ESCAPE
	esc_key.physical_keycode = KEY_ESCAPE
	esc_key.pressed = true
	root.push_input(esc_key)  # справжній шлях клавіші: каркас BaseMenu отримує її першим
	for i in 3: await process_frame
	ck(closed[0], "a real Esc key reaches the screen and closes it")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
