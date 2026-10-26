extends SceneTree

## Самоперевірка вкладки World Map у два рівні (D458, D487, D565; design/world_map_spec.md).
##   godot --headless --path . --script res://SampleProject/UI/verify_world_map.gd
##
## Рівень 1: шпилька на кожну локацію locations.json у map_pos, стани тут / відвідано / закрито, картка.
## Рівень 2: клітинки MetSys локації — досліджена / бачений вхід / схована, назви, значки; навігація A / B, вліво / вправо.
## Сейвів не чіпає: дослідження клітинок міняється лише в памʼяті MetSys і повертається назад.

## metsys_map_component.gd Level: WORLD, LOCATION.
const WORLD := 0
const LOCATION := 1

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _action(name: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = true
	return ev


func _initialize() -> void:
	await process_frame
	await process_frame
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
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	# Автозавантаження не резолвиться як глобальний ідентифікатор у скрипті-MainLoop — тож load(), не preload.
	var met: Node = root.get_node("MetSys")
	var LocationDB: GDScript = load("res://SampleProject/Scripts/Systems/LocationDB.gd")
	var LocationMap: GDScript = load("res://SampleProject/Scripts/Systems/LocationMap.gd")
	var here_id: String = LocationDB.of_scene(met.get_current_room_instance().get_parent().scene_file_path)

	print("[1] the tab opens on level 1, without the MetSys grid")
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("World Map")
	for i in 8: await process_frame
	var map: Control = menu.find_child("MetSysMapComponent", true, false)
	ck(map.is_visible_in_tree() and map.is_map_active, "World Map visible and active after the tab switch")
	ck(map.level == WORLD, "opens on level 1 (the world)")
	ck(map.get("map_view") == null and map.find_children("*", "MapView", true, false).is_empty(), "no MetSys MapView grid")
	ck(map.get_node("%Level1").is_visible_in_tree() and not map.get_node("%Level2").is_visible_in_tree(), "level 1 shown, level 2 hidden")
	ck(not get_first_node_in_group("ui_party_column").visible, "party column hidden, as in the frames")

	print("[2] one pin per location at its map_pos, with its state")
	var pins: Array[Node] = map.get_node("%Pins").get_children()
	ck(pins.size() == LocationDB.all().size(), "pins = locations (%d)" % pins.size())
	for pin: Control in pins:
		ck(pin.global_position.is_equal_approx(LocationDB.map_pos(pin.name)), "%s pin at map_pos %s" % [pin.name, pin.global_position])
	var here_pin: Control = map.get_node("%Pins").get_node(here_id)
	ck(map.pin_state(here_id) == &"here", "hero's location %s is 'here'" % here_id)
	ck(here_pin.theme_type_variation == &"MapPinHere", "here pin has the red plate")
	ck(here_pin.get_node("Row/Text/State").text == "you are here", "here pin says 'you are here'")
	for id: String in map.location_ids:
		var data: RefCounted = map.maps[id]
		var expected: StringName = &"here" if id == here_id else (&"visited" if data.visited() else &"locked")
		ck(map.pin_state(id) == expected, "%s pin state %s" % [id, expected])
	var locked_ids: Array = map.location_ids.filter(func(id: String) -> bool: return map.pin_state(id) == &"locked")
	ck(not locked_ids.is_empty(), "a location the hero has not reached is locked (%s)" % [locked_ids])
	for id: String in locked_ids:
		var pin: Control = map.get_node("%Pins").get_node(id)
		ck(pin.theme_type_variation == &"MapPinLocked" and pin.get_node("Row/Text/Name").theme_type_variation == &"MapPinNameLocked",
				"%s pin is grey at 60%%" % id)
	ck(map.location_ids[map.selected] == here_id, "the hero's location is selected first")

	print("[3] the location card")
	var data_here: RefCounted = map.maps[here_id]
	ck(map.get_node("%CardName").text == LocationDB.title(here_id), "card shows the selected location")
	var stats: String = map.get_node("%CardStats").text
	ck(stats == "Explored %d%% · Chests %d/%d" % [data_here.explored_percent(), data_here.chests_opened, data_here.chests_total],
			"card counts come from the data (%s)" % stats)
	ck(data_here.explored_percent() > 0 and data_here.explored_percent() <= 100, "explored %% is real (%d)" % data_here.explored_percent())
	ck(data_here.chests_total > 0, "chests counted from the rooms (%d)" % data_here.chests_total)
	ck(stats.findn("secret") < 0, "no secrets line: nothing in the data marks a secret")

	print("[4] the explored / seen / hidden rule")
	var cells: Dictionary = data_here.cells
	var counts := {0: 0, 1: 0, 2: 0}
	for c: Vector3i in cells:
		var explored: bool = met.is_cell_discovered(c, false)
		var seen := false
		for d in 4:
			var from: Vector3i = c - LocationMap.DIRS[d]
			if cells.has(from) and met.is_cell_discovered(from, false) and met.map_data.get_cell_at(from).get_border(d) != 0:
				seen = true
		var expected: int = 2 if explored else (1 if seen else 0)
		counts[expected] += 1
		ck(data_here.state(c) == expected, "cell %s state %d" % [c, expected])
	ck(counts[2] > 0, "some cells explored (%d)" % counts[2])
	ck(counts[0] > 0, "some cells hidden (%d)" % counts[0])
	ck(data_here.state(met.get_current_coords()) == LocationMap.Cell.EXPLORED, "the hero's cell is explored")
	# Дослідити сховану клітинку в памʼяті: вона стає залитою, а сусіди за відкритою межею — пунктирними.
	var probe := Vector3i.MAX
	for c: Vector3i in cells:
		if data_here.state(c) == LocationMap.Cell.HIDDEN:
			probe = c
			break
	met.save_data.explore_cell(probe)
	ck(data_here.state(probe) == LocationMap.Cell.EXPLORED, "exploring a hidden cell makes it explored")
	for d in 4:
		var next: Vector3i = probe + LocationMap.DIRS[d]
		if cells.has(next) and not met.is_cell_discovered(next, false) and met.map_data.get_cell_at(probe).get_border(d) != 0:
			ck(data_here.state(next) == LocationMap.Cell.SEEN, "its neighbour through an open border is seen %s" % next)
		elif cells.has(next) and met.map_data.get_cell_at(probe).get_border(d) == 0 and not met.is_cell_discovered(next, false):
			var other := false
			for d2 in 4:
				var from: Vector3i = next - LocationMap.DIRS[d2]
				other = other or (cells.has(from) and met.is_cell_discovered(from, false) and met.map_data.get_cell_at(from).get_border(d2) != 0)
			ck(data_here.state(next) == (LocationMap.Cell.SEEN if other else LocationMap.Cell.HIDDEN), "a wall does not reveal %s" % next)
	met.save_data.discovered_cells.erase(probe)
	ck(data_here.state(probe) != LocationMap.Cell.EXPLORED, "probe cell restored")

	print("[5] pad / keys: left / right between pins, A opens only a reached location")
	map.grab_focus()
	var start: int = map.selected
	map._gui_input(_action(&"ui_right"))
	ck(map.selected == mini(start + 1, map.location_ids.size() - 1), "right moves to the next pin (%d -> %d)" % [start, map.selected])
	ck(map.get_node("%CardName").text == LocationDB.title(map.location_ids[map.selected]), "card follows the selection")
	map.select(map.location_ids.find(locked_ids[0]))
	map._gui_input(_action(&"ui_accept"))
	ck(map.level == WORLD, "A on a locked pin stays on level 1")
	map.select(map.location_ids.find(here_id))
	map._gui_input(_action(&"ui_left"))
	map._gui_input(_action(&"ui_right"))
	map.select(map.location_ids.find(here_id))
	map._gui_input(_action(&"ui_accept"))
	await process_frame
	ck(map.level == LOCATION and map.shown_id == here_id, "A opens level 2 of the selected location")

	print("[6] level 2 draws the location from MetSys")
	ck(map.get_node("%Level2").is_visible_in_tree() and not map.get_node("%Level1").is_visible_in_tree(), "level 2 shown, level 1 hidden")
	ck(map.get_node("%MapTitle").text == LocationDB.title(here_id).to_upper(), "title is the location in capitals")
	ck(map.get_node("%MapSubtitle").text == "Location map · B — back to the world map", "subtitle says how to go back")
	var grid: Control = map.get_node("%Grid")
	var names: Array[String] = []
	var icons: Array[StringName] = []
	for child in grid.get_children():
		if child is Label:
			names.append(child.text)
		else:
			icons.append(child.get_meta(&"marker"))
	for room: String in LocationDB.location(here_id).rooms:
		if data_here.room_explored(room):
			ck(LocationMap.room_title(room) in names, "explored room %s is named" % room)
		elif data_here.first_cell(room, LocationMap.Cell.SEEN) == Vector3i.MAX:
			ck(not LocationMap.room_title(room) in names, "hidden room %s is not named" % room)
	ck(&"hero" in icons, "hero icon drawn")
	for child in grid.get_children():
		if child is Label:
			continue
		var cell := Vector3i.MAX
		for c: Vector3i in cells:
			if map.cell_rect(c).has_point(child.position + child.size / 2.0):
				cell = c
		ck(cell != Vector3i.MAX and data_here.state(cell) != LocationMap.Cell.HIDDEN, "icon %s sits in a drawn cell" % child.get_meta(&"marker"))
	var drawn_box := Rect2(Vector2.ZERO, grid.size)
	for c: Vector3i in cells:
		if data_here.state(c) != LocationMap.Cell.HIDDEN:
			ck(drawn_box.encloses(map.cell_rect(c)), "drawn cell %s inside the grid" % c)
	var rooms: Control = map.get_node("%Rooms")
	ck(Rect2(Vector2.ZERO, rooms.size).encloses(Rect2(grid.position, grid.size * grid.scale)), "the grid fits the room area")
	ck(map.get_node("%Legend").is_visible_in_tree(), "legend shown")
	var src: String = FileAccess.get_file_as_string("res://SampleProject/Scripts/Menus/Game/metsys_map_component.gd") \
			+ FileAccess.get_file_as_string("res://SampleProject/Scripts/Systems/LocationMap.gd")
	for loc: Dictionary in LocationDB.all():
		for room: String in loc.rooms:
			ck(src.find('"%s"' % room) < 0, "nothing hard-coded for room %s" % room)

	print("[7] B goes back to level 1; other keys keep the focus on the map")
	map._gui_input(_action(&"ui_left"))
	ck(map.level == LOCATION, "left on level 2 does nothing")
	map._gui_input(_action(&"ui_cancel"))
	await process_frame
	ck(map.level == WORLD and map.get_node("%Level1").is_visible_in_tree(), "B returns to level 1")
	ck(menu.get_node("FocusRouter").focus_mode == "Content" or map.has_focus(), "focus stays on the map")
	ck(get_first_node_in_group("game_menu") != null, "B on level 2 does not close the menu")

	print("[8] uk text through the localisation tables")
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("uk")
	map._refresh_texts()
	ck(here_pin.get_node("Row/Text/State").text == "ви тут", "pin state in uk (%s)" % here_pin.get_node("Row/Text/State").text)
	ck(map.get_node("%CardStats").text.begins_with("Досліджено"), "card in uk (%s)" % map.get_node("%CardStats").text)
	TranslationServer.set_locale(locale)
	map._refresh_texts()

	print("[9] leaving the tab brings the party column back; reopening rebuilds cleanly")
	menu.switch_to_tab("Inventory")
	for i in 4: await process_frame
	ck(get_first_node_in_group("ui_party_column").visible, "party column back on Inventory")
	menu.switch_to_tab("Status")
	for i in 4: await process_frame
	menu.switch_to_tab("World Map")
	for i in 4: await process_frame
	ck(not get_first_node_in_group("ui_party_column").visible, "Status -> World Map keeps the party column hidden")
	ui.close_game_menu()
	for i in 6: await process_frame
	ck(not paused, "game unpauses")
	ui.open_game_menu()
	for i in 12: await process_frame
	var menu2: Node = get_first_node_in_group("game_menu")
	menu2.switch_to_tab("World Map")
	for i in 8: await process_frame
	var map2: Node = menu2.find_child("MetSysMapComponent", true, false)
	ck(map2.get_node("%Pins").get_child_count() == LocationDB.all().size() and map2.level == WORLD, "map rebuilds on reopen")
	ui.close_game_menu()
	for i in 5: await process_frame
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
