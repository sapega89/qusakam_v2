extends SceneTree

## BACKLOG 14 (D291–D294): NPC під героєм у кожній мапі; торговець і коваль виходять зі своїх будинків назустріч
## Кусакаму — кат-сцена один раз, керування забрано, голосового привітання немає, завдання в журналі, NPC на місці.
##   godot --headless --path . --script res://SampleProject/UI/verify_npc_arrival.gd

const NPC_DIR := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/"

var fails: Array[String] = []
var played: Array[StringName] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

## Сумарний z від кореня сцени (z_as_relative додає z батьків).
func _z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z

func _is_npc(node: Node) -> bool:
	return node is NpcBase or node.scene_file_path.begins_with(NPC_DIR)

func _z_order() -> void:
	print("[1] Every NPC in every map draws behind the hero")
	var hero: Node = load("res://SampleProject/Player.tscn").instantiate()
	var hero_z := _z(hero.get_node(^"Sprite2D"))
	hero.free()
	var checked := 0
	for file: String in DirAccess.get_files_at("res://SampleProject/Maps/"):
		if not file.ends_with(".tscn"):
			continue
		var map: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for npc: Node in map.find_children("*", "", true, false).filter(_is_npc):
			var art: Array = npc.find_children("*", "Sprite2D", true, false) + npc.find_children("*", "AnimatedSprite2D", true, false)
			for sprite: CanvasItem in art:
				checked += 1
				ck(_z(sprite) < hero_z, "%s/%s/%s z %d < hero %d" % [file.get_basename(), npc.name, sprite.name, _z(sprite), hero_z])
		map.free()
	ck(checked >= 6, "NPC sprites found in the maps (%d)" % checked)

func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame

## Герой підходить до NPC і тисне interact; у меню — справжні ui_down × n і ui_accept.
func _choose(npc: NpcBase, label: String) -> void:
	await _tap(&"interact")
	for i in 4: await process_frame
	var labels: Array = npc.npc_menu.get_children().map(func(b: Button) -> String: return b.text)
	for i in labels.find(label):
		await _tap(&"ui_down")
	await _tap(&"ui_accept")
	for i in 4: await process_frame

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

## Герой іде праворуч справжнім move_right, поки не почнеться зустріч (керування забрано).
func _walk_in(player: CharacterBody2D) -> void:
	Input.action_press(&"move_right")
	await _until(func() -> bool: return player.event, 8.0)
	Input.action_release(&"move_right")

func _arrival(game: Node, sl: Node, room: String, start: NodePath, npc_name: String, door_name: String, task: String,
		flag: String, first_line: String, start_x: float = 0.0) -> void:
	var dm: Node = sl.get_dialogue_manager()
	game.teleport_to_room(room, start)
	for i in 30: await physics_frame
	if start_x > 0.0:  # past the room's own dialogue triggers (Road monologue; City_Merchant zone before D311)
		game.player.global_position = Vector2(start_x, 360)
		for i in 20: await physics_frame
	var npc: NpcBase = game.map.get_node(npc_name)
	var station: float = npc.global_position.x
	var door: float = (game.map.get_node(door_name) as Node2D).global_position.x
	ck(not npc.visible and npc.process_mode == Node.PROCESS_MODE_DISABLED, "%s hidden before the meeting" % npc_name)
	var started: Array[String] = []
	var on_start := func(id: String) -> void: started.append(id.get_file().get_basename())
	dm.dialogue_started.connect(on_start)
	played.clear()
	var player: CharacterBody2D = game.player
	await _walk_in(player)
	ck(player.event and not dm.is_dialogue_active(), "walking in starts the meeting: control taken by the cutscene, not a dialogue")
	for i in 6: await physics_frame
	var anim: AnimationPlayer = npc.get_node(^"AnimationPlayer")
	ck(npc.visible and anim.current_animation == "walk", "%s walks (%s)" % [npc_name, anim.current_animation])
	ck(absf(npc.global_position.x - door) < absf(station - door), "%s comes out of the door (x %.0f, door %.0f)" % [npc_name, npc.global_position.x, door])
	ck(not npc.interactable.enabled, "no talk prompt during the cutscene")
	await _until(func() -> bool: return dm.is_dialogue_active(), 8.0)
	ck(absf(npc.global_position.x - station) < 1.0, "%s at the station when the talk starts" % npc_name)
	ck(started == [first_line], "first-meeting talk %s (%s)" % [first_line, started])
	await _drain(dm)
	for i in 10: await process_frame
	ck(not played.any(func(e: StringName) -> bool: return String(e).begins_with("greet_")), "no voiced greeting in the cutscene (%s)" % [played])
	ck(game.get_quest_flag("task_%s_taken" % task), "task %s started" % task)
	ck(game.get_quest_flag(flag), "%s set" % flag)
	ck(not player.event, "control back")
	ck(anim.current_animation == "work" and npc.interactable.enabled, "%s goes to work at the station, with a prompt (D295)" % npc_name)
	dm.dialogue_started.disconnect(on_start)

	# Повернувшись у кімнату — NPC уже стоїть, сцена не повторюється.
	game.teleport_to_room(room, start)
	for i in 30: await physics_frame
	if start_x > 0.0:
		game.player.global_position = Vector2(start_x, 360)
	npc = game.map.get_node(npc_name)
	ck(npc.visible and absf(npc.global_position.x - station) < 1.0, "%s stays at the station on return" % npc_name)
	player = game.player
	Input.action_press(&"move_right")
	for i in 90: await physics_frame
	Input.action_release(&"move_right")
	ck(not player.event and not dm.is_dialogue_active(), "the meeting plays once")

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	_z_order()
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	root.get_node("AudioManager").sound_played.connect(
			func(event: StringName, _s: AudioStream, _b: StringName, _p: float) -> void: played.append(event))
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())

	print("[2] Desert Road: after the fight the merchant comes out of his shop")
	for f: String in ["canyon_exit_complete", "desert_road_monologue_complete", "desert_road_fight_complete"]:
		game.set_quest_flag(f, true)
	await _arrival(game, sl, "res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start", "Merchant", "ShopDoor",
			"merchant_caravan", "desert_road_merchant_met", "Merchant_Arrival", 700.0)

	print("[3] City: the blacksmith comes out of his forge")
	await _arrival(game, sl, "res://SampleProject/Maps/City.tscn", ^"SavePoint", "Blacksmith", "ForgeDoor",
			"smith_helmet", "city_blacksmith_met", "Smith_Arrival", 840.0)

	print("[4] Both tasks show in the Journal")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	for i in 10: await process_frame
	var journal: Node = get_first_node_in_group("journal_screen")
	var titles: Array = journal.entries.map(func(e: Dictionary) -> String: return e.title)
	ck(titles.has("The Stolen Caravan") and titles.has("The Helmet"), "journal lists the tasks (%s)" % [titles])
	var helmet: Array = journal.entries.filter(func(e: Dictionary) -> bool: return e.title == "The Helmet")
	ck(not helmet.is_empty() and "god of deals" in helmet[0].description and "Goal: Buy 2 Iron Ingots and 1 Leather" in helmet[0].description
			and "anvil" in helmet[0].description, "The Helmet: lore + a clear goal in the Journal (D311) (%s)" % [helmet])
	sl.get_ui_manager().close_game_menu()
	for i in 10: await process_frame

	print("[5] The caravan task turns in once the City Gates are cleared")
	var TASKS: GDScript = load("res://SampleProject/Scripts/Tasks/task_service.gd")
	var caravan: Dictionary = TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == "merchant_caravan")[0]
	ck(not TASKS.can_turn_in(caravan), "not before the gates fight")
	game.set_quest_flag("city_gates_fight_complete", true)
	ck(TASKS.can_turn_in(caravan), "after the gates fight")

	print("[6] The caravan merchant has moved on to the City (D311): gone from the road, at work past the City gates")
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 30: await physics_frame
	ck(game.map.get_node_or_null(^"Merchant") == null, "no merchant on the Desert Road after the gates fight")
	game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	var merchant: NpcBase = game.map.get_node(^"Merchant")
	var hero: CharacterBody2D = game.player
	ck(merchant.visible and absf(merchant.global_position.x - 800.0) < 1.0, "the merchant stands at the old City_Merchant spot")
	ck(_z(merchant.get_node(^"Sprite2D")) < _z(hero.get_node(^"Sprite2D")), "behind the hero (D291)")
	await _until(func() -> bool: return merchant.get_node(^"AnimationPlayer").current_animation == "work", 8.0)
	ck(merchant.get_node(^"AnimationPlayer").current_animation == "work", "he counts coins (D295)")
	hero.global_position = merchant.global_position + Vector2(-40, -10)
	hero.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	var dm: Node = sl.get_dialogue_manager()
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	played.clear()
	await _tap(&"interact")
	for i in 4: await process_frame
	var labels: Array = merchant.npc_menu.get_children().map(func(b: Button) -> String: return b.text)
	ck(labels == ["Talk", "Quest", "Buy"], "his menu: Talk / Quest / Buy (%s)" % [labels])
	ck(played.has(&"greet_merchant"), "a voiced greeting when the hero starts the talk (D277) (%s)" % [played])
	merchant.npc_menu.cancelled.emit()
	for i in 4: await process_frame
	await _choose(merchant, "Quest")
	ck(started.has("Merchant_Caravan_Done"), "Quest hands in the caravan in the City (%s)" % [started])
	await _drain(dm)
	ck(game.get_quest_flag("task_merchant_caravan_done"), "caravan task done")
	await _choose(merchant, "Buy")
	ck(merchant.is_shop_open, "Buy opens his shop")
	var stock: Array = merchant.shop_menu_instance.shop_items
	ck(stock.has("iron_ingot") and stock.has("leather") and stock.has("hi_potion"), "City stock: the helmet's ingots and leather, potions (%s)" % [stock])
	merchant.close_shop()

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
