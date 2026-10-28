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
	ck(stats == "Explored %d%% · Chests %d/%d · Secrets %d/%d" % [data_here.explored_percent(), data_here.chests_opened,
			data_here.chests_total, data_here.secrets_found, data_here.secrets_total], "card counts come from the data (%s)" % stats)
	ck(data_here.explored_percent() > 0 and data_here.explored_percent() <= 100, "explored %% is real (%d)" % data_here.explored_percent())
	ck(data_here.chests_total > 0, "chests counted from the rooms (%d)" % data_here.chests_total)
	ck(data_here.secrets_total > 0, "secrets counted from the SecretArea nodes of the rooms (D765, %d)" % data_here.secrets_total)

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

	print("[6b] every icon kind of the spec comes from the real rooms; an opened chest dims")
	var kinds_seen: Dictionary[StringName, bool] = {}
	for loc: Dictionary in LocationDB.all():
		var loc_data: RefCounted = LocationMap.new(loc.id)
		var chest_marks := 0
		for m: Dictionary in loc_data.markers:
			kinds_seen[m.kind] = true
			chest_marks += int(m.kind == LocationMap.KIND_CHEST or m.kind == LocationMap.KIND_CHEST_OPEN)
		ck(chest_marks == loc_data.chests_total, "%s: an icon for every chest (%d/%d)" % [loc.id, chest_marks, loc_data.chests_total])
	for kind: StringName in [&"hero", &"save", &"chest", &"locked", &"quest", &"exit"]:
		ck(kinds_seen.has(kind), "the real rooms give a %s icon" % kind)
	var chest_cell := Vector3i.MAX
	var chest_id := ""
	for loc: Dictionary in LocationDB.all():
		var loc_data: RefCounted = LocationMap.new(loc.id)
		for m: Dictionary in loc_data.markers:
			if chest_cell == Vector3i.MAX and m.kind == LocationMap.KIND_CHEST:
				chest_cell = m.cell
				chest_id = loc.id
	var chest_room: String = LocationMap.new(chest_id).cells[chest_cell]
	var chest_key: String = met.map_data.get_room_from_scene_path(
			(met.settings.map_root_folder as String).path_join(chest_room + ".tscn"), false)
	var chest_scene: Node = (load((met.settings.map_root_folder as String).path_join(chest_room + ".tscn")) as PackedScene).instantiate()
	var chest_names: Array = chest_scene.find_children("*", "Chest", true, false).map(func(n: Node) -> String: return n.name)
	chest_scene.free()
	var was_explored: bool = met.is_cell_discovered(chest_cell, false)
	met.save_data.explore_cell(chest_cell)
	map.set_map_active(true)  # як при відкритті вкладки: LocationMap збирається з поточного стану гри
	map.open_location(chest_id)
	await process_frame
	var chest_icon := func() -> Control:
		for child in grid.get_children():
			if child.has_meta(&"marker") and map.cell_rect(chest_cell).has_point(child.position + child.size / 2.0) \
					and child.get(&"kind") == &"chest":
				return child
		return null
	var closed_icon: Control = chest_icon.call()
	ck(closed_icon != null and not closed_icon.get(&"dimmed") and closed_icon.modulate.a == 1.0,
			"a closed chest in %s is bright" % chest_room)
	for chest_name: String in chest_names:
		boot_game.set_room_state(chest_key, "opened_%s" % chest_name, true)
	map.set_map_active(true)
	map.open_location(chest_id)
	await process_frame
	var open_icon: Control = chest_icon.call()
	ck(open_icon != null and open_icon.get_meta(&"marker") == LocationMap.KIND_CHEST_OPEN and open_icon.get(&"dimmed")
			and is_equal_approx(open_icon.modulate.a, UITokens.MAP_ICON_OPENED_ALPHA), "after opening %s it dims" % [chest_names])
	for chest_name: String in chest_names:
		boot_game.set_room_state(chest_key, "opened_%s" % chest_name, false)
	if not was_explored:
		met.save_data.discovered_cells.erase(chest_cell)
	map.set_map_active(true)
	here_pin = map.get_node("%Pins").get_node(here_id)  # шпильки зібрано наново
	map.open_location(here_id)
	await process_frame

	print("[7] B goes back to level 1; other keys keep the focus on the map")
	map._gui_input(_action(&"ui_left"))
	ck(map.level == LOCATION, "left on level 2 does nothing")
	map._gui_input(_action(&"ui_cancel"))
	await process_frame
	ck(map.level == WORLD and map.get_node("%Level1").is_visible_in_tree(), "B returns to level 1")
	ck(menu.get_node("FocusRouter").focus_mode == "Content" or map.has_focus(), "focus stays on the map")
	ck(get_first_node_in_group("game_menu") != null, "B on level 2 does not close the menu")

	await _canvas_checks(map, here_id)
	here_pin = map.get_node("%Pins").get_node(here_id)  # шпильки зібрано наново

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

	print("[19] the M map (Game UI/MapWindow) has no MetSys sample debug UI (B205)")
	var map_window: Control = current_scene.get_node(^"UI/MapWindow")
	ck(map_window.find_children("*", "Label", true, false).is_empty(), "no label: neither «Press D to toggle delta vector» nor the «0%» counter")
	ck(map_window.get_node_or_null(^"TopDraw") == null and map_window.get_node_or_null(^"Percent") == null, "no TopDraw / Percent nodes")
	ck(not ("show_delta" in map_window) and not map_window.has_method(&"reset_starting_coords"), "no delta-vector state or reset hook")
	_key(KEY_M, true)
	_key(KEY_M, false)
	for i in 3: await process_frame
	ck(map_window.visible and map_window.map_view != null, "M still opens the map with its MetSys grid")
	_key(KEY_D, true)
	_key(KEY_D, false)
	for i in 3: await process_frame
	ck(map_window.visible and map_window.find_children("*", "Label", true, false).is_empty(), "D does nothing on the open map")
	_key(KEY_M, true)
	_key(KEY_M, false)
	for i in 3: await process_frame
	ck(not map_window.visible and current_scene.get_node(^"%Player").process_mode == Node.PROCESS_MODE_INHERIT, "M closes it and frees the hero")
	_done()


func _mouse_button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	ev.global_position = at
	ev.position = at
	return ev


func _mouse_motion(at: Vector2, relative: Vector2, velocity := Vector2.ZERO, held := true) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.global_position = at
	ev.position = at
	ev.relative = relative
	ev.velocity = velocity
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	return ev


## Тягнути мишею від [param from] на [param delta] кількома кроками й відпустити.
func _drag(map: Control, from: Vector2, delta: Vector2, steps := 4, velocity := Vector2.ZERO) -> void:
	map._gui_input(_mouse_button(MOUSE_BUTTON_LEFT, true, from))
	for i in steps:
		map._gui_input(_mouse_motion(from + delta * (i + 1) / steps, delta / steps, velocity))
	map._gui_input(_mouse_button(MOUSE_BUTTON_LEFT, false, from + delta))


func _wheel(map: Control, at: Vector2, up: bool, times := 1) -> void:
	for i in times:
		map._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true, at))


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _joy_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


## Карта-полотно (map-pan, як в Octopath Traveler): тягнути, ковзати, масштабувати, край, клац проти тягнення, клавіші й стік.
func _canvas_checks(map: Control, here_id: String) -> void:
	var cam: RefCounted = map.world_camera
	var bg: Control = map._background
	var view: Rect2 = cam.view
	var covers := func() -> bool:
		return Rect2(bg.position, bg.size * bg.scale).encloses(view)

	print("[10] level 1: opens in the Figma frame's scale on the hero; the parchment always covers the view")
	map.set_map_active(true)
	await process_frame
	ck(map.level == WORLD and is_equal_approx(cam.zoom, 1.0), "level 1 opens at zoom 1 (%.3f)" % cam.zoom)
	var here_i: int = map.location_ids.find(here_id)
	var want: Vector2 = view.get_center() - map.pin_center(here_i)
	var expect_off := Vector2(clampf(want.x, view.end.x - 1920.0, view.position.x), clampf(want.y, view.end.y - 1080.0, view.position.y))
	ck(cam.offset.is_equal_approx(expect_off), "centred on the hero as far as the edges allow (%s, want %s)" % [cam.offset, expect_off])
	ck(covers.call(), "parchment covers the view at the start")
	ck(is_equal_approx(bg.scale.x, cam.zoom) and bg.position.is_equal_approx(cam.offset), "menu background follows the camera")

	print("[11] level 1: the wheel zooms around the cursor and clamps")
	var at := Vector2(1100, 500)
	var under: Vector2 = cam.to_content(at)
	_wheel(map, at, true)
	ck(is_equal_approx(cam.zoom, UITokens.MAP_ZOOM_STEP), "one notch zooms in by MAP_ZOOM_STEP (%.3f)" % cam.zoom)
	ck(cam.to_content(at).distance_to(under) < 0.5, "the point under the cursor stays put (%s -> %s)" % [under, cam.to_content(at)])
	var pin0: Control = map.get_node("%Pins").get_child(0)
	var c0: Vector2 = pin0.global_position + pin0.get_combined_minimum_size() / 2.0
	ck(c0.distance_to(cam.to_view(map.pin_center(0))) < 1.0, "pins ride with the map, not scaled (%s)" % c0)
	ck(is_equal_approx(pin0.scale.x, 1.0), "pin keeps its size")
	_wheel(map, at, true, 30)
	ck(is_equal_approx(cam.zoom, UITokens.MAP_ZOOM_MAX), "zoom in stops at MAP_ZOOM_MAX (%.3f)" % cam.zoom)
	ck(covers.call(), "parchment covers the view at the maximum")
	_wheel(map, at, false, 60)
	ck(is_equal_approx(cam.zoom, cam.zoom_min) and cam.zoom_min < 1.0, "zoom out stops at the fitted minimum (%.3f)" % cam.zoom)
	ck(covers.call(), "parchment still covers the view at the minimum (never leaves it)")

	print("[12] level 1: a drag pans by the mouse delta 1:1 and stops at the edge")
	_wheel(map, view.get_center(), true, 8)
	cam.center_on(Vector2(960, 540))
	map._apply_camera()
	var before: Vector2 = cam.offset
	_drag(map, Vector2(1000, 500), Vector2(-80, -40))
	ck(cam.offset.is_equal_approx(before + Vector2(-80, -40)), "drag moves the map by the delta (%s -> %s)" % [before, cam.offset])
	ck(map.level == WORLD, "a drag does not open anything")
	_drag(map, Vector2(1000, 500), Vector2(6000, 6000))
	ck(cam.offset.is_equal_approx(view.position), "a long drag stops at the top-left edge (%s)" % cam.offset)
	ck(covers.call(), "after the drag the parchment still covers the view")
	_drag(map, Vector2(1000, 500), Vector2(-9000, -9000))
	ck(cam.offset.is_equal_approx(view.end - Vector2(1920, 1080) * cam.zoom), "and at the bottom-right edge (%s)" % cam.offset)

	print("[13] level 1: release with speed glides, then the glide stops at the edge")
	cam.center_on(Vector2(960, 540))
	map._apply_camera()
	before = cam.offset
	_drag(map, Vector2(1000, 500), Vector2(40, 0), 2, Vector2(1500, 0))
	var after_drag: Vector2 = cam.offset
	for i in 10: await process_frame
	ck(cam.offset.x > after_drag.x + 1.0, "the map keeps sliding after release (%.1f -> %.1f)" % [after_drag.x, cam.offset.x])
	for i in 120: await process_frame
	ck(cam.velocity == Vector2.ZERO, "the glide dies out")
	ck(covers.call(), "the glide never shows past the parchment")

	print("[14] level 1: hover selects a pin; a short click opens it, a drag over it does not")
	map.set_map_active(true)
	await process_frame
	var here_pin: Control = map.get_node("%Pins").get_child(here_i)
	var pin_at: Vector2 = here_pin.get_global_rect().get_center()
	var other: int = 0 if here_i != 0 else 1
	map.select(other)
	map._gui_input(_mouse_motion(pin_at, Vector2(2, 0), Vector2.ZERO, false))
	ck(map.selected == here_i, "hovering a pin selects it")
	ck(map.get_node("%CardName").text == map.LocationDB.title(here_id), "and shows its card")
	_drag(map, pin_at, Vector2(UITokens.MAP_DRAG_SLOP + 6.0, 0), 3)
	ck(map.level == WORLD, "a drag of more than MAP_DRAG_SLOP px over a pin does not open it")
	map._gui_input(_mouse_motion(map.get_node("%Pins").get_child(here_i).get_global_rect().get_center(), Vector2.ZERO, Vector2.ZERO, false))
	pin_at = map.get_node("%Pins").get_child(here_i).get_global_rect().get_center()
	_drag(map, pin_at, Vector2(3, 0), 1)
	await process_frame
	ck(map.level == LOCATION and map.shown_id == here_id, "a short click (3 px) opens the location")

	print("[15] level 2: opens at the cell's own size on the hero, hero's room highlighted with its card")
	var rcam: RefCounted = map.room_camera
	var grid: Control = map.get_node("%Grid")
	var rooms: Control = map.get_node("%Rooms")
	ck(is_equal_approx(rcam.zoom, maxf(1.0, rcam.zoom_min)), "level 2 opens at zoom 1 (%.3f)" % rcam.zoom)
	ck(grid.position.is_equal_approx(rcam.offset) and is_equal_approx(grid.scale.x, rcam.zoom), "the grid follows its camera")
	var data: RefCounted = map.maps[here_id]
	var hero_room: String = data.cells[root.get_node("MetSys").get_current_coords()]
	# Уся локація досліджена (лише в памʼяті MetSys) — тоді вона більша за рамку й є куди тягнути.
	var met: Node = root.get_node("MetSys")
	var probed: Array[Vector3i] = []
	for c: Vector3i in data.cells:
		if not met.is_cell_discovered(c, false):
			met.save_data.explore_cell(c)
			probed.append(c)
	map.open_location(here_id)
	await process_frame
	ck(map.hovered_room == hero_room and map.get_node("%RoomCard").visible, "hero's room %s highlighted, card shown" % hero_room)
	ck(map.get_node("%RoomName").text == map.LocationMap.room_title(hero_room), "room card names it (%s)" % map.get_node("%RoomName").text)
	ck(map.get_node("%RoomStats").text.begins_with("Chests "), "room card counts its chests (%s)" % map.get_node("%RoomStats").text)

	print("[16] level 2: wheel zooms around the cursor and clamps; drag pans and stops at the edge")
	var r_at: Vector2 = rooms.global_position + rooms.size / 2.0 + Vector2(30, 20)
	_wheel(map, r_at, true, 30)
	ck(is_equal_approx(rcam.zoom, UITokens.MAP_ZOOM_MAX), "level 2 zoom in stops at MAP_ZOOM_MAX")
	rcam.center_on(rcam.content / 2.0)
	var r_under: Vector2 = rcam.to_content(r_at - rooms.global_position)
	_wheel(map, r_at, false)
	var r_now: Vector2 = rcam.to_content(r_at - rooms.global_position)
	for axis in 2:  # вісь, де локація менша за рамку, стоїть по центру — там точка їде законно
		if rcam.content[axis] * rcam.zoom > rcam.view.size[axis]:
			ck(absf(r_now[axis] - r_under[axis]) < 0.5, "the room point under the cursor stays put on axis %d (%.1f -> %.1f)"
					% [axis, r_under[axis], r_now[axis]])
	_wheel(map, r_at, false, 60)
	ck(is_equal_approx(rcam.zoom, rcam.zoom_min), "level 2 zoom out stops at the fit (%.3f)" % rcam.zoom)
	ck(Rect2(Vector2.ZERO, rooms.size).encloses(Rect2(grid.position, grid.size * grid.scale).grow(-0.5)), "at the fit the whole location is in the frame")
	_wheel(map, r_at, true, 30)
	before = rcam.offset
	_drag(map, r_at, Vector2(-30, 25))
	ck(rcam.offset.is_equal_approx(before + Vector2(-30, 25)), "drag moves the rooms by the delta (%s -> %s)" % [before, rcam.offset])
	_drag(map, r_at, Vector2(-9000, -9000))
	ck(rcam.offset.is_equal_approx(rcam.view.end - grid.size * rcam.zoom), "a long drag stops at the far edge (%s)" % rcam.offset)
	ck(map.level == LOCATION, "dragging on level 2 keeps level 2")

	print("[17] level 2: hover highlights a room and shows its card; empty space hides it")
	rcam.zoom = rcam.zoom_min
	rcam.setup(rcam.view, rcam.content, rcam.zoom_min, rcam.zoom_max)
	map._apply_camera()
	var hover_room := ""
	var hover_at := Vector2.ZERO
	for c: Vector3i in data.cells:
		if data.state(c) == map.LocationMap.Cell.EXPLORED and data.cells[c] != hero_room:
			hover_room = data.cells[c]
			hover_at = rooms.global_position + rcam.to_view(map.cell_rect(c).get_center())
			break
	map._gui_input(_mouse_motion(hover_at, Vector2(1, 0), Vector2.ZERO, false))
	ck(hover_room != "" and map.hovered_room == hover_room, "hovering %s highlights it" % hover_room)
	ck(map.get_node("%RoomName").text == map.LocationMap.room_title(hover_room), "its card shows")
	map._gui_input(_mouse_motion(rooms.global_position + Vector2(2, 2), Vector2(1, 0), Vector2.ZERO, false))
	ck(map.hovered_room == "" and not map.get_node("%RoomCard").visible, "empty parchment: no highlight, no card")

	print("[18] keys and pad: WASD / arrows / right stick pan, Q-E / triggers zoom")
	map.grab_focus()
	await process_frame
	_wheel(map, r_at, true, 30)
	rcam.center_on(rcam.content / 2.0)
	map._apply_camera()
	before = rcam.offset
	_key(KEY_D, true)
	for i in 6: await process_frame
	_key(KEY_D, false)
	ck(rcam.offset.x < before.x - 1.0, "D moves the view right on level 2 (%.1f -> %.1f)" % [before.x, rcam.offset.x])
	before = rcam.offset
	Input.action_press(&"ui_left")
	for i in 6: await process_frame
	Input.action_release(&"ui_left")
	ck(rcam.offset.x > before.x + 1.0, "the left arrow moves the view left on level 2")
	before = rcam.offset
	_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)
	for i in 6: await process_frame
	_joy_axis(JOY_AXIS_RIGHT_Y, 0.0)
	ck(rcam.offset.y < before.y - 1.0, "the right stick moves the view down (%.1f -> %.1f)" % [before.y, rcam.offset.y])
	var z: float = rcam.zoom
	Input.action_press(&"menu_prev_tab")
	for i in 6: await process_frame
	Input.action_release(&"menu_prev_tab")
	ck(rcam.zoom < z, "Q zooms out (%.3f -> %.3f)" % [z, rcam.zoom])
	z = rcam.zoom
	_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	for i in 6: await process_frame
	_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	ck(rcam.zoom > z, "the right trigger zooms in (%.3f -> %.3f)" % [z, rcam.zoom])
	map._gui_input(_action(&"ui_cancel"))
	await process_frame
	ck(map.level == WORLD, "B still goes back to level 1")
	for c: Vector3i in probed:
		met.save_data.discovered_cells.erase(c)
	map.grab_focus()
	_wheel(map, view.get_center(), true, 4)
	cam.center_on(Vector2(960, 540))
	map._apply_camera()
	before = cam.offset
	var sel: int = map.selected
	_key(KEY_W, true)
	for i in 6: await process_frame
	_key(KEY_W, false)
	ck(cam.offset.y > before.y + 1.0 and map.selected == sel, "W pans level 1 up and keeps the selected pin")
	before = cam.offset
	_joy_axis(JOY_AXIS_RIGHT_X, -1.0)
	for i in 6: await process_frame
	_joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	ck(cam.offset.x > before.x + 1.0, "the right stick pans level 1")
	z = cam.zoom
	Input.action_press(&"menu_next_tab")
	for i in 6: await process_frame
	Input.action_release(&"menu_next_tab")
	ck(cam.zoom > z, "E zooms level 1 in (%.3f -> %.3f)" % [z, cam.zoom])
	map.select(here_i)
	map._gui_input(_action(&"ui_right"))
	ck(map.selected != here_i or map.location_ids.size() == 1, "left / right still choose pins on level 1")
	for i in 60: await process_frame
	var sel_center: Vector2 = cam.to_view(map.pin_center(map.selected))
	ck(view.has_point(sel_center), "the view follows the pin chosen by keys (%s)" % sel_center)
	map.set_map_active(true)
	await process_frame


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
