extends SceneTree

## Живе Місто (D740, Sapega 2026-10-26 «щоб NPC ходили по ньому, щоб можна було щось кудись тикнути»):
## жителі ходять своїми маршрутами й не стоять на дверях, NPC чи речах; герой іде крізь них; репліки мимохідь —
## біля героя й не в розмові; кожна річ працює від справжнього натискання interact; черга біля брами — лише після бою.
##   godot --headless --path . --script res://SampleProject/UI/verify_city_life.gd

const TOWNSFOLK := ["townsfolk_water_carrier", "townsfolk_porter", "townsfolk_old_man", "townsfolk_merchant_woman"]
## Житель не стоїть ближче за це до дверей, NPC, точки збереження (px по x).
const CLEAR_OF_NPC := 60.0
## …і до речі, яку можна тикнути.
const CLEAR_OF_PROP := 50.0
## Тут героя не бачить жоден житель (усі зупинки — до x 2240): біля палацу, ще в кімнаті.
const AWAY := Vector2(2400, 380)

var fails: Array[String] = []
var game: Node
var dm: Node
var sl: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame


func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventAction.new()
	up.action = &"interact"
	up.pressed = false
	Input.parse_input_event(up)
	for i in 3: await process_frame


func _modal_layer() -> Node:
	return sl.get_ui_manager().get_modal_layer()


func _close_modal() -> void:
	var layer := _modal_layer()
	for i in 60:
		if layer.active_modal:
			layer.active_modal.get_viewport().gui_get_focus_owner().pressed.emit()
			for f in 4: await process_frame
			return
		await process_frame


## Герой — біля речі (у її зоні), підказка видна.
func _walk_up_to(prop: Node2D) -> bool:
	game.player.global_position = Vector2(prop.global_position.x - 10.0, prop.global_position.y - 16.0)
	for i in 10: await physics_frame
	var interactable: InteractableComponent = prop.get_node(^"Interactable")
	return interactable.get_prompt().visible


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()

	print("[0] Townsfolk art (cell 64x96, rows idle + walk)")
	for kind: String in TOWNSFOLK:
		var sheet := "res://SampleProject/Assets/Characters/NPCs/%s/sheet.png" % kind
		print("  INFO %s: %s" % [kind, "committed" if ResourceLoader.exists(sheet) else "MISSING (stand-in sheet in its scene)"])

	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	await _drain()
	var city: Node = game.map
	var crowd: Node2D = city.get_node(^"Crowd")
	var walkers: Array[Node2D] = crowd.call(&"walkers")

	print("[1] The City has 6–10 townsfolk of the four kinds; no body, so the hero walks through them")
	ck(walkers.size() >= 6 and walkers.size() <= 10, "%d walkers in the City" % walkers.size())
	var kinds := {}
	for w: Node2D in walkers:
		kinds[w.scene_file_path.get_file().get_basename()] = true
		ck(w.find_children("*", "CollisionObject2D", true, false).is_empty(), "%s has no collision body" % w.name)
		ck((w.get_node(^"Sprite2D") as Sprite2D).texture != null, "%s has a sheet" % w.name)
	ck(kinds.size() == TOWNSFOLK.size(), "all four kinds walk (%s)" % ", ".join(kinds.keys()))

	print("[2] No stop on a door, an NPC, the save point or a prop")
	var blockers := {}
	for npc: Node in city.find_children("*", "NpcBase", true, false):
		blockers[npc.name] = (npc as Node2D).global_position.x
	# Вартові й двері палацу тепер на площі палацу (M7), кузня й каплиця — у ремісничому кварталі (D773); на ринку —
	# двері на дахи, на горище й люк у цистерну.
	for node_name: String in ["SavePoint", "RooftopsDoor", "TavernAtticDoor", "CisternDoor"]:
		blockers[node_name] = (city.get_node(node_name) as Node2D).global_position.x
	ck(blockers.size() >= 6, "%d doors / NPCs to keep clear of" % blockers.size())
	var props: Array[Node] = city.get_node(^"Props").get_children()
	for w: Node2D in walkers:
		var stops: PackedFloat32Array = w.get(&"stops")
		var bad: Array[String] = []
		for x: float in stops:
			for b: String in blockers:
				if absf(x - blockers[b]) < CLEAR_OF_NPC:
					bad.append("%d~%s" % [x, b])
			for prop: Node in props:
				if absf(x - (prop as Node2D).global_position.x) < CLEAR_OF_PROP:
					bad.append("%d~%s" % [x, prop.name])
		ck(bad.is_empty(), "%s stops %s clear %s" % [w.name, stops, bad])
	for prop: Node in props:
		var bad: Array[String] = []
		for b: String in blockers:
			if absf((prop as Node2D).global_position.x - blockers[b]) < CLEAR_OF_NPC + 40.0:
				bad.append(b)
		ck(bad.is_empty(), "%s does not cover a door or an NPC %s" % [prop.name, bad])

	print("[3] They walk: positions change, nobody is stuck")
	game.player.global_position = AWAY
	var start := {}
	var seen_x := {}
	for w: Node2D in walkers:
		start[w] = w.position.x
		seen_x[w] = [w.position.x, w.position.x]
	Engine.time_scale = 4.0
	var deadline := Time.get_ticks_msec() + 9000  # ≈36 с гри
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for w: Node2D in walkers:
			seen_x[w][0] = minf(seen_x[w][0], w.position.x)
			seen_x[w][1] = maxf(seen_x[w][1], w.position.x)
	Engine.time_scale = 1.0
	for w: Node2D in walkers:
		var span: float = seen_x[w][1] - seen_x[w][0]
		ck(span > 60.0, "%s walked %d px (stops %s)" % [w.name, span, w.get(&"stops")])
	var went_in := walkers.filter(func(w: Node2D) -> bool: return not (w.get(&"doorways") as PackedFloat32Array).is_empty())
	ck(went_in.size() >= 2, "%d walkers have a doorway on their route" % went_in.size())

	print("[4] The hero comes close: the walker steps aside (up the street), and back when he leaves")
	var w0: Node2D = walkers[2]
	var base_y: float = w0.get(&"_base_y")
	game.player.global_position = Vector2(w0.global_position.x, 380)
	await _until(func() -> bool: return w0.position.y < base_y - 5.0, 3.0)
	ck(w0.position.y < base_y - 5.0, "%s stepped aside (y %d → %d)" % [w0.name, base_y, w0.position.y])
	game.player.global_position = AWAY
	await _until(func() -> bool: return is_equal_approx(w0.position.y, base_y), 3.0)
	ck(is_equal_approx(w0.position.y, base_y), "%s back on the street line" % w0.name)

	print("[5] Barks: near the hero a walker says a line; not during a dialogue")
	dm.bubble_time_scale = 1.0
	var barks: Array = []
	crowd.barked.connect(func(walker: Node2D, line: String) -> void: barks.append([walker, line]))
	var near: Node2D = null
	for w: Node2D in walkers:
		if w.call(&"is_out"):
			near = w
			break
	game.player.global_position = Vector2(near.global_position.x + 70.0, 380)
	crowd.set(&"_gap", 0.0)
	await _until(func() -> bool: return not barks.is_empty(), 3.0)
	ck(barks.size() == 1, "one bark near the hero (%d)" % barks.size())
	if not barks.is_empty():
		var walker: Node2D = barks[0][0]
		ck(dm.chatter_bubble(walker) != null, "%s says «%s» in a cloud" % [walker.name, barks[0][1]])
		ck(walker.global_position.distance_to(game.player.global_position) < crowd.get(&"bark_radius"), "the speaker is near the hero")
		ck(tr(barks[0][1]) != "" and (crowd.get(&"lines") as PackedStringArray).has(barks[0][1]), "the line is one of the crowd's keys")
	ck(crowd.get(&"_gap") >= crowd.get(&"bark_gap_min"), "next bark waits ≥ %d s" % crowd.get(&"bark_gap_min"))
	dm._end_all_chatter()
	game.player.global_position = AWAY
	crowd.set(&"_gap", 0.0)
	await create_timer(0.5).timeout
	ck(barks.size() == 1, "no bark with nobody near the hero")
	dm.start_dialogue("res://dialogue_quest/CityGates_Guard_Chatter.dqd")
	await _until(func() -> bool: return dm.is_dialogue_active(), 2.0)
	ck(dm.is_dialogue_active(), "a dialogue is running")
	game.player.global_position = Vector2(near.global_position.x + 30.0, 380)
	crowd.set(&"_gap", 0.0)
	await create_timer(1.0).timeout
	ck(barks.size() == 1, "no bark during the dialogue")
	await _drain()
	game.player.global_position = AWAY
	for i in 5: await physics_frame

	print("[6] Things to poke: prompt, then the effect, by a real interact press")
	var inventory: Node = sl.get_inventory_manager()
	var by_name := {}
	for prop: Node in props:
		by_name[prop.name] = prop
	ck(props.size() >= 6, "%d props in the City" % props.size())

	var board: Node2D = by_name["NoticeBoard"]
	ck(await _walk_up_to(board), "Notice board: the prompt shows")
	await _press_interact()
	await _until(func() -> bool: return _modal_layer().active_modal != null, 2.0)
	ck(_modal_layer().active_modal != null, "Notice board: the notices open")
	await _close_modal()

	var well: Node2D = by_name["Well"]
	var hero: Node = game.player
	hero.current_health = hero.Max_Health - 60
	var hp_before: int = hero.current_health
	ck(await _walk_up_to(well), "Well: the prompt shows")
	await _press_interact()
	var heal := int(root.get_node("ItemDatabase").get_item("potion_lesser").effect.value)
	ck(hero.current_health == mini(hp_before + heal, hero.Max_Health), "Well: a drink heals %d (%d → %d)" % [heal, hp_before, hero.current_health])
	ck(not (well.get_node(^"Interactable") as InteractableComponent).get_prompt().visible, "Well: once per visit (the prompt is gone)")
	var hp_after: int = hero.current_health
	await _press_interact()
	ck(hero.current_health == hp_after, "Well: a second press does nothing")

	var stall: Node2D = by_name["FruitStall"]
	var price := int(root.get_node("ItemDatabase").get_item("potion_lesser").buy_price)
	inventory.spend_coins(inventory.get_coins())
	var had: int = inventory.get_item_count("potion_lesser")
	ck(await _walk_up_to(stall), "Fruit stall: the prompt shows")
	await _press_interact()
	ck(inventory.get_item_count("potion_lesser") == had, "Fruit stall: no coins, nothing sold")
	inventory.add_coins(price + 3)
	await _press_interact()
	ck(inventory.get_item_count("potion_lesser") == had + 1 and inventory.get_coins() == 3,
			"Fruit stall: bought one for %d coins (coins left %d)" % [price, inventory.get_coins()])

	var cat: Node2D = by_name["Cat"]
	ck(await _walk_up_to(cat), "Cat: the prompt shows")
	await _press_interact()
	var hearts := cat.get_children().filter(func(n: Node) -> bool: return n.get(&"kind") == &"love")
	ck(hearts.size() == 1, "Cat: a heart pops over it")
	ck(dm.chatter_bubble(cat) != null, "Cat: it purrs in a cloud")

	var crate: Node2D = by_name["Crate"]
	var coins_before: int = inventory.get_coins()
	ck(await _walk_up_to(crate), "Crate: the prompt shows")
	await _press_interact()
	ck(inventory.get_coins() == coins_before + int(crate.get(&"coins")), "Crate: +%d coins" % crate.get(&"coins"))
	await _close_modal()
	await _press_interact()
	ck(inventory.get_coins() == coins_before + int(crate.get(&"coins")), "Crate: searched once only")
	ck(game.get_room_state(root.get_node("MetSys").map_data.get_room_from_scene_path(city.scene_file_path, false), "searched_Crate", false),
			"Crate: the room remembers it (save)")

	var shrine: Node2D = by_name["Shrine"]
	ck(await _walk_up_to(shrine), "Shrine: the prompt shows")
	await _press_interact()
	ck(dm.chatter_bubble(shrine) != null, "Shrine: one line in a cloud")
	game.player.global_position = AWAY
	for i in 5: await physics_frame

	dm.bubble_time_scale = 0.0
	print("[7] City Gates: a queue of 2–3, only once the gate fight is over")
	game.set_quest_flag("city_gates_intro_complete", true)
	game.set_quest_flag("city_gates_fight_complete", false)
	await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 30: await physics_frame
	var queue: Node2D = game.map.get_node(^"Crowd")
	ck(not queue.visible and queue.process_mode == Node.PROCESS_MODE_DISABLED, "before the fight is won the queue is away")
	game.set_quest_flag("city_gates_fight_complete", true)
	await process_frame
	ck(queue.visible, "after the fight the queue stands at the gate")
	var queue_walkers: Array[Node2D] = queue.call(&"walkers")
	ck(queue_walkers.size() >= 2 and queue_walkers.size() <= 3, "%d in the queue" % queue_walkers.size())
	var door_x: float = (game.map.get_node(^"CellarDoor") as Node2D).global_position.x
	var scribe_x: float = (game.map.get_node(^"GateScribe") as Node2D).global_position.x
	for w: Node2D in queue_walkers:
		for x: float in w.get(&"stops") as PackedFloat32Array:
			ck(absf(x - door_x) >= CLEAR_OF_NPC and absf(x - scribe_x) >= CLEAR_OF_NPC, "%s stands clear of the cellar door and the scribe (%d)" % [w.name, x])
	_done()


func _done() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("  - " + f)
	quit()
