extends SceneTree

## BACKLOG 14 (D291, D293), D442, D452, D454: NPC під героєм у кожній мапі; катсцен першої зустрічі немає — торговець
## і коваль стоять на місці з синім «!», гукають героя, меню відкривається саме, Quest видає завдання, знак зникає;
## завдання в журналі; караванник переходить у місто (D311).
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

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame
	for i in 2: await process_frame


func _focused_label(npc: NpcBase) -> String:
	var focused := npc.get_viewport().gui_get_focus_owner()
	return (focused as Button).text if focused is Button and focused.get_parent() == npc.npc_menu else ""


## D735: W/S, стрілки й хрестовина гортають меню; перша ж клавіша бере його — герой не йде, не стрибає й не бʼє,
## доки меню не закрито (Esc відпускає).
func _menu_takes_the_hero(npc: NpcBase, player: CharacterBody2D) -> void:
	var labels: Array = npc.npc_menu.get_children().map(func(b: Button) -> String: return b.text)
	ck(not player.event, "D735: before a menu key the hero is free")
	await _key(KEY_S)
	ck(npc.npc_menu.is_engaged and player.event, "D735: S takes the menu and holds the hero")
	ck(labels.size() < 2 or _focused_label(npc) == labels[1], "D735: S moves to the next row (%s)" % _focused_label(npc))
	await _key(KEY_W)
	ck(_focused_label(npc) == labels[0], "D735: W moves back (%s)" % _focused_label(npc))
	await _key(KEY_DOWN)
	ck(labels.size() < 2 or _focused_label(npc) == labels[1], "D735: Down arrow moves too (%s)" % _focused_label(npc))
	await _tap(&"ui_up")
	ck(_focused_label(npc) == labels[0], "D735: Up / D-pad up moves back (%s)" % _focused_label(npc))
	var at: Vector2 = player.global_position
	Input.action_press(&"move_right")
	for i in 10: await physics_frame
	Input.action_release(&"move_right")
	await _tap(&"jump")
	await _tap(&"attack")
	for i in 4: await physics_frame
	ck(player.global_position.distance_to(at) < 1.0 and player.velocity == Vector2.ZERO, "D735: walk and jump do nothing behind the menu (moved %.1f)" % player.global_position.distance_to(at))
	ck(player.combat.state == load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State.READY, "D735: attack does nothing behind the menu (%s)" % player.combat.state)
	ck(npc.npc_menu.visible, "D735: the menu stays open")
	await _tap(&"ui_cancel")
	ck(not npc.npc_menu.visible and not player.event, "D735: Esc / B closes it and lets the hero go")


## Меню NPC відкрите саме (D454) — або, якщо гравець його закрив, E відкриває знову; у меню — справжні
## ui_down × n і interact (D454: вибирає interact).
func _choose(npc: NpcBase, label: String) -> void:
	if not npc.npc_menu.visible:
		await _tap(&"interact")
		for i in 4: await process_frame
	var labels: Array = npc.npc_menu.get_children().map(func(b: Button) -> String: return b.text)
	for i in labels.find(label):
		await _tap(&"ui_down")
	await _tap(&"interact")
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

## D442: NPC стоїть на місці від початку, над головою синій «!»; герой підбігає справжнім move_right — жодної
## катсцени: меню відкривається саме (D454), NPC гукає (D452); Quest видає завдання, і знак зникає.
func _meet(game: Node, sl: Node, room: String, start: NodePath, npc_name: String, task: String, give: String,
		bark: String, start_x: float) -> void:
	var dm: Node = sl.get_dialogue_manager()
	await game.teleport_to_room(room, start)
	for i in 30: await physics_frame
	game.player.global_position = Vector2(start_x, 360)  # past the room's own dialogue triggers (Road monologue)
	for i in 20: await physics_frame
	var npc: NpcBase = game.map.get_node(npc_name)
	var station: float = (load(room) as PackedScene).instantiate().get_node(npc_name).position.x
	ck(npc.visible and npc.process_mode != Node.PROCESS_MODE_DISABLED and absf(npc.global_position.x - station) < 1.0,
			"%s stands at his station from the start (D442)" % npc_name)
	ck(npc.marker.visible and npc.marker.kind == &"side", "a blue \"!\" over his head: a side quest to give (%s)" % npc.marker.kind)
	var started: Array[String] = []
	var on_start := func(id: String) -> void: started.append(id.get_file().get_basename())
	dm.dialogue_started.connect(on_start)
	played.clear()
	dm.bubble_time_scale = 1.0  # облачко мимохідь живе seconds_for() — тест має його побачити
	var player: CharacterBody2D = game.player
	Input.action_press(&"move_right")
	await _until(func() -> bool: return npc.npc_menu.visible or player.event, 8.0)
	var x0: float = player.global_position.x
	for i in 6: await physics_frame
	var still_running: bool = player.global_position.x > x0
	Input.action_release(&"move_right")
	ck(not player.event and not dm.is_dialogue_active(), "walking up starts no cutscene and no dialogue")
	ck(npc.npc_menu.visible, "his menu opens by itself (D454)")
	ck(still_running, "the menu is not modal: the hero keeps running")
	await _menu_takes_the_hero(npc, player)
	var bubble: Node2D = dm.chatter_bubble(npc)
	ck(bubble != null and npc.quest_bark_dialogue.ends_with(bark + ".dqd"), "he calls out in a cloud (D452: %s)" % bark)
	var greet: StringName = root.get_node("AudioManager").hooks.greet_event(npc.character_id)
	ck(played.has(greet), "a voiced greeting as the menu opens (%s in %s)" % [greet, played])
	dm.bubble_time_scale = 0.0
	player.global_position.x = npc.global_position.x - 30.0
	for i in 10: await physics_frame
	await _choose(npc, "Quest")
	ck(started == [give], "Quest: the give talk %s (%s)" % [give, started])
	await _drain(dm)
	for i in 10: await process_frame
	ck(game.get_quest_flag("task_%s_taken" % task), "task %s taken" % task)
	ck(not npc.marker.visible and npc.marker.kind == &"", "the \"!\" is gone once the quest is taken")
	dm.dialogue_started.disconnect(on_start)

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
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

	print("[2] No first-meeting cutscenes (D442): no NpcArrival anywhere")
	ck(not FileAccess.file_exists("res://SampleProject/Scripts/Gameplay/NPCs/NpcArrival.gd"), "NpcArrival.gd is gone")
	for map: String in ["DesertRoad", "City"]:
		var text := FileAccess.get_file_as_string("res://SampleProject/Maps/%s.tscn" % map)
		ck(text.find("NpcArrival") == -1 and text.find("_Arrival.dqd") == -1, "%s has no arrival zone or arrival talk" % map)

	print("[3] Desert Road: after the fight the merchant stands at his shop with a blue \"!\"")
	for f: String in ["canyon_exit_complete", "desert_road_fight_complete"]:
		game.set_quest_flag(f, true)
	await _meet(game, sl, "res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start", "Merchant", "merchant_caravan",
			"Merchant_Caravan_Give", "Merchant_Bark", 700.0)

	print("[3b] City: the blacksmith stands at his forge with a blue \"!\"")
	await _meet(game, sl, "res://SampleProject/Maps/CraftQuarter.tscn", ^"Arrival", "Blacksmith", "smith_helmet",
			"Smith_Helmet_Give", "Smith_Bark", 719.0)

	print("[4] Both tasks show in the Journal")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	for i in 10: await process_frame
	var journal: Node = get_first_node_in_group("journal_screen")
	journal.select_section("side")  # завдання NPC — побічні історії (D791)
	var titles: Array = journal.entries.map(func(e: Dictionary) -> String: return e.title)
	ck(titles.has("The Stolen Caravan") and titles.has("The Helmet"), "journal lists the tasks (%s)" % [titles])
	var helmet: Array = journal.entries.filter(func(e: Dictionary) -> bool: return e.title == "The Helmet")
	ck(not helmet.is_empty() and "god of deals" in helmet[0].description and helmet[0].objectives.size() == 1
			and String(helmet[0].objectives[0]).begins_with("Buy 2 Iron Ingots and 1 Leather") and "anvil" in helmet[0].objectives[0], "The Helmet: lore + a clear goal in the Journal (D311) (%s)" % [helmet])
	sl.get_ui_manager().close_game_menu()
	for i in 10: await process_frame

	print("[5] The caravan task turns in once the City Gates are cleared")
	var TASKS: GDScript = load("res://SampleProject/Scripts/Tasks/task_service.gd")
	var caravan: Dictionary = TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == "merchant_caravan")[0]
	ck(not TASKS.can_turn_in(caravan), "not before the gates fight")
	game.set_quest_flag("city_gates_fight_complete", true)
	ck(TASKS.can_turn_in(caravan), "after the gates fight")

	print("[6] The caravan merchant has moved on to the City (D311): gone from the road, at work past the City gates")
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 30: await physics_frame
	ck(game.map.get_node_or_null(^"Merchant") == null, "no merchant on the Desert Road after the gates fight")
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	var merchant: NpcBase = game.map.get_node(^"Merchant")
	var hero: CharacterBody2D = game.player
	ck(merchant.visible and absf(merchant.global_position.x - 800.0) < 1.0, "the merchant stands at the old City_Merchant spot")
	ck(_z(merchant.get_node(^"Sprite2D")) < _z(hero.get_node(^"Sprite2D")), "behind the hero (D291)")
	await _until(func() -> bool: return merchant.get_node(^"AnimationPlayer").current_animation == "work", 8.0)
	ck(merchant.get_node(^"AnimationPlayer").current_animation == "work", "he counts coins (D295)")
	var dm: Node = sl.get_dialogue_manager()
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	played.clear()
	hero.global_position = merchant.global_position + Vector2(-40, -10)
	hero.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	var labels: Array = merchant.npc_menu.get_children().map(func(b: Button) -> String: return b.text)
	ck(merchant.npc_menu.visible and labels == ["Talk", "Quest", "Buy"], "his menu opens by itself: Talk / Quest / Buy (%s)" % [labels])
	ck(played.has(&"greet_merchant"), "a voiced greeting as the menu opens (D277, D454) (%s)" % [played])
	ck(not merchant.marker.visible, "no \"!\": the caravan task is already taken")
	merchant.npc_menu.cancelled.emit()
	for i in 10: await process_frame
	ck(not merchant.npc_menu.visible, "ui_cancel closes it, and it stays closed while the hero stands there")
	await _choose(merchant, "Quest")
	ck(started.has("Merchant_Caravan_Done"), "Quest hands in the caravan in the City (%s)" % [started])
	await _drain(dm)
	ck(game.get_quest_flag("task_merchant_caravan_done"), "caravan task done")
	# BACKLOG 33: нагорода — модалкою «You obtained:» після розмови; поки вона відкрита, interact не діє.
	for i in 6: await process_frame
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	ck(layer.active_modal != null and layer.active_modal.description_label.text == "Coin × 60", "the reward popup: Coin × 60")
	ck(not merchant.npc_menu.visible, "the menu waits while the popup is open")
	await _tap(&"ui_accept")
	for i in 4: await process_frame
	ck(layer.active_modal == null, "ui_accept closes the reward popup")
	ck(merchant.npc_menu.visible, "then the menu comes back by itself")
	await _choose(merchant, "Buy")
	ck(merchant.is_shop_open, "Buy opens his shop")
	var stock: Array = merchant.shop_menu_instance.shop_items
	ck(stock.has("iron_ingot") and stock.has("leather") and not stock.has("hi_potion") and not stock.has("potion"), "City stock: the helmet's ingots and leather, no potions (4b) (%s)" % [stock])
	merchant.close_shop()

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
