extends SceneTree

## Секрети мапи (D765, Q98): невидима SecretArea рахується знайденою при першому вході героя, це живе в стані кімнати
## й переживає сейв; картка World Map показує «Secrets c/d» з вузлів кімнат локації; дзвін і тост «Secret found».
## Карта рівня 2 малює знайдений секрет його значком на місці вузла, незнайдений — ніяк; рядок легенди.
## Пише лише в user://verify_secrets/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_secrets.gd

const TEST_DIR := "user://verify_secrets/"
const TEST_SLOT := 1
const SECRET_SCRIPT := "res://SampleProject/Scripts/Gameplay/SecretArea.gd"
const MURAL_ROOM := "res://SampleProject/Maps/DragonMural.tscn"
const MURAL_SECRET := "SecretArea_DragonMural"
const WORLD_MAP_TAB := "World Map"

var fails: Array[String] = []
var found_events: Array[String] = []
var sounds: Array[StringName] = []


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


## Вузли SecretArea сцени кімнати [param room] (імʼя сцени), прочитані поза деревом.
func _secret_nodes(room: String) -> Array[Node]:
	var scene: Node = (load("res://SampleProject/Maps/%s.tscn" % room) as PackedScene).instantiate()
	var out: Array[Node] = []
	for node: Node in scene.find_children("*", "Area2D", true, false):
		if node.get_script() != null and (node.get_script() as Script).resource_path == SECRET_SCRIPT:
			out.append(node)
	for node: Node in out:
		node.get_parent().remove_child(node)
	scene.free()
	return out


func _walk_into(game: Node, area: Node2D) -> void:
	game.player.global_position = area.global_position
	for i in 10: await physics_frame


func _walk_out(game: Node, area: Node2D) -> void:
	game.player.global_position = area.global_position + Vector2(-600, 0)
	for i in 10: await physics_frame


func _card_stats(ui: Node) -> String:
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab(WORLD_MAP_TAB)
	for i in 8: await process_frame
	var text: String = menu.find_child("MetSysMapComponent", true, false).get_node("%CardStats").text
	ui.close_game_menu()
	for i in 8: await process_frame
	return text


## Значки рівня 2 локації [param id] ({marker, kind, dimmed, size}) і чи є в легенді рядок секрету: вкладка World Map,
## open_location.
func _level2_icons(ui: Node, id: String) -> Array[Dictionary]:
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab(WORLD_MAP_TAB)
	for i in 8: await process_frame
	var map: Control = menu.find_child("MetSysMapComponent", true, false)
	map.open_location(id)
	await process_frame
	var out: Array[Dictionary] = []
	for child: Node in map.get_node("%Grid").get_children():
		if child.has_meta(&"marker"):
			out.append({"marker": child.get_meta(&"marker"), "kind": child.get(&"kind"), "dimmed": child.get(&"dimmed"),
					"size": (child as Control).size})
	var legend: Control = map.get_node("%Legend")
	legend_secret_ok = (legend.get_node(^"Rows/Secret/Icon").get(&"kind") == &"secret"
			and (legend.get_node(^"Rows/Secret/Text") as Label).text == "secret (found)" and legend.is_visible_in_tree())
	ui.close_game_menu()
	for i in 8: await process_frame
	return out


var legend_secret_ok := false


func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	var met: Node = root.get_node("MetSys")
	var event_bus: Node = root.get_node("EventBus")
	var LocationDB: GDScript = load("res://SampleProject/Scripts/Systems/LocationDB.gd")
	var LocationMap: GDScript = load("res://SampleProject/Scripts/Systems/LocationMap.gd")
	var SecretArea: GDScript = load(SECRET_SCRIPT)
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	event_bus.secret_found.connect(func(room: String, secret: String) -> void: found_events.append(room + "/" + secret))
	root.get_node("AudioManager").sound_played.connect(
			func(event: StringName, _s: AudioStream, _b: StringName, _p: float) -> void: sounds.append(event))
	set_meta("start_new_game", true)
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = await _boot()
	await _drain(dm)

	print("[1] every placed SecretArea is invisible; the rubble one hides inside the rubble")
	var per_location: Dictionary[String, int] = {}
	for loc: Dictionary in LocationDB.all():
		var id: String = loc.id
		per_location[id] = 0
		for room: String in LocationDB.location(id).rooms:
			for node: Node in _secret_nodes(room):
				per_location[id] += 1
				var visuals: Array = node.get_children().filter(func(c: Node) -> bool: return c is CanvasItem and not c is CollisionShape2D)
				ck(visuals.is_empty() and (node as Area2D).collision_layer == 0, "%s/%s draws nothing and is not a body" % [room, node.name])
				node.free()
	var road: Node = (load("res://SampleProject/Maps/DesertRoad.tscn") as PackedScene).instantiate()
	var rubble: Node2D = road.get_node(^"Rubble_ShopRoof")
	var rubble_shape: CollisionShape2D = rubble.get_node(^"CollisionShape2D")
	var rubble_rect: Rect2 = rubble_shape.shape.get_rect()
	rubble_rect.position += rubble.position + rubble_shape.position
	var stash: Node2D = road.get_node(^"SecretArea_ShopRoofRubble")
	var stash_rect: Rect2 = (stash.get_node(^"CollisionShape2D") as CollisionShape2D).shape.get_rect()
	stash_rect.position += stash.position
	ck(rubble_rect.encloses(stash_rect), "the shop-roof secret %s lies inside the rubble %s" % [stash_rect, rubble_rect])
	road.free()
	# M7: + схованка контрабандистів; + голубник і схованка в цистерні; + схованка Маліка.
	ck(per_location["canyon_of_whispers"] == 7 and per_location["city"] == 3 and per_location["laboratory"] == 1,
			"secrets per location %s" % per_location)

	print("[2] the card's total comes from the nodes, none found in a new game")
	for id: String in per_location:
		var data: RefCounted = LocationMap.new(id)
		ck(data.secrets_total == per_location[id] and data.secrets_found == 0,
				"%s: %d/%d = nodes %d" % [id, data.secrets_found, data.secrets_total, per_location[id]])
		ck(not data.markers.any(func(m: Dictionary) -> bool: return m.kind == LocationMap.KIND_SECRET),
				"%s: no secret icon while none is found" % id)

	print("[3] entering counts once: chime and «Secret found» toast")
	await game.teleport_to_room(MURAL_ROOM, ^"Arrival")
	for i in 10: await physics_frame
	var room: String = met.get_current_room_name()
	var area: Node2D = game.map.find_child(MURAL_SECRET, true, false)
	ck(area != null and area.get_script() == SecretArea, "the mural room has its SecretArea")
	ck(found_events.is_empty() and not game.get_room_state(room, SecretArea.state_key(MURAL_SECRET), false),
			"arriving at the door does not find it")
	sounds.clear()
	await _walk_into(game, area)
	ck(found_events == [room + "/" + MURAL_SECRET], "found when the hero walks in (%s)" % [found_events])
	ck(game.get_room_state(room, SecretArea.state_key(MURAL_SECRET), false) == true, "room state found_%s" % MURAL_SECRET)
	ck(sounds.has(&"secret_found"), "the soft chime plays (%s)" % [sounds])
	var feed: Node = get_first_node_in_group(&"loot_feed")
	var texts: Array = feed.toasts().map(func(t: Node) -> String: return (t.get_node(^"Row/Text") as Label).text)
	ck(texts.has("Secret found"), "a «Secret found» toast in the loot feed (%s)" % [texts])
	var toast: Node = feed.toasts()[0]
	ck(not (toast.get_node(^"Row/Icon") as TextureRect).visible, "the secret toast has no item icon")
	await _walk_out(game, area)
	await _walk_into(game, area)
	ck(found_events.size() == 1, "walking in again does not count twice (%d)" % found_events.size())
	var stats: String = await _card_stats(root.get_node("ServiceLocator").get_ui_manager())
	ck(stats.ends_with("Secrets 1/%d" % per_location["canyon_of_whispers"]), "the card shows the found secret (%s)" % stats)
	var canyon: RefCounted = LocationMap.new("canyon_of_whispers")
	var secret_marks: Array = canyon.markers.filter(func(m: Dictionary) -> bool: return m.kind == LocationMap.KIND_SECRET)
	ck(secret_marks.size() == 1, "one secret marker, the found one (%d)" % secret_marks.size())
	var mural_room: String = MURAL_ROOM.get_file().get_basename()
	ck(not secret_marks.is_empty() and canyon.cells[secret_marks[0].cell] == mural_room, "the marker sits in %s" % mural_room)
	var cell_px: Vector2 = met.settings.in_game_cell_size
	var origin := Vector3i.MAX
	for c: Vector3i in canyon.cells:
		if canyon.cells[c] == mural_room:
			origin = Vector3i(mini(origin.x, c.x), mini(origin.y, c.y), c.z)
	if not secret_marks.is_empty():
		var at: Vector2 = (Vector2(secret_marks[0].cell.x - origin.x, secret_marks[0].cell.y - origin.y)
				+ (secret_marks[0].at as Vector2)) * cell_px
		ck(at.is_equal_approx(area.position), "at the SecretArea's position (%s = %s)" % [at, area.position])
	var icons: Array[Dictionary] = await _level2_icons(root.get_node("ServiceLocator").get_ui_manager(), "canyon_of_whispers")
	var drawn: Array = icons.filter(func(i: Dictionary) -> bool: return i.marker == &"secret")
	ck(drawn.size() == 1 and drawn[0].kind == &"secret" and not drawn[0].dimmed,
			"level 2 draws the found secret's icon (%d)" % drawn.size())
	ck(not drawn.is_empty() and drawn[0].size == Vector2.ONE * UITokens.MAP_ICON, "the same 26 px circle")
	ck(legend_secret_ok, "the legend has «secret (found)» with the icon")

	print("[4] saved and loaded like an opened chest")
	ck(game.save_game(), "save_game()")
	game.queue_free()
	for i in 4: await process_frame
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	await _drain(dm)
	ck(game.get_room_state(room, SecretArea.state_key(MURAL_SECRET), false) == true, "restored from the save")
	var loaded: RefCounted = LocationMap.new("canyon_of_whispers")
	ck(loaded.secrets_found == 1 and loaded.secrets_total == per_location["canyon_of_whispers"],
			"the card data after loading %d/%d" % [loaded.secrets_found, loaded.secrets_total])
	found_events.clear()
	await game.teleport_to_room(MURAL_ROOM, ^"Arrival")
	for i in 10: await physics_frame
	area = game.map.find_child(MURAL_SECRET, true, false)
	ck(not (area as Area2D).monitoring, "a found secret no longer watches the hero")
	await _walk_into(game, area)
	ck(found_events.is_empty(), "no second «found» after loading (%s)" % [found_events])
	game.queue_free()
	for i in 4: await process_frame

	print("[5] New Game starts with no secrets found")
	set_meta("start_new_game", true)
	game = await _boot()
	ck(game.get_room_state(room, SecretArea.state_key(MURAL_SECRET), false) == false, "no found secret in a new game")

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
