extends SceneTree

## The longer Desert Road (BACKLOG 23, design/world_expansion_plan.md, D296, D298) in the real game:
##   1. Each section fight (dunes, mesa, caravan) waits for the hero: no enemy until he walks into its zone, then its
##      own enemies appear on the floor; the story fight at the start (EnemySpawner) is not touched.
##   2. A finished section fight stays finished when the hero comes back (its own room-state key, D152).
##   3. A ledge pickup: the hero jumps from the step onto the ledge (real physics, real keys), presses interact,
##      the item lands in the inventory, and after a reload of the room it is gone (D298).
##   4. The road ends at CityGates: walking off the east edge loads CityGates.
##   godot --headless --path . --script res://SampleProject/UI/verify_road_sections.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const FIGHTS := {"Fight_Dunes": 4, "Fight_Mesa": 4, "Fight_Caravan": 5}

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _alive(spawner: Node) -> Array:
	return spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	set_meta("start_new_game", true)
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	# The story beats of the road are done — only the sections are under test.
	for flag in ["desert_road_monologue_complete", "desert_road_fight_complete", "desert_road_merchant_met"]:
		game.set_quest_flag(flag, true)
	game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	var road: Node = game.map
	var player: CharacterBody2D = game.player

	print("[1] Section fights wait for the hero")
	ck(_alive(road.get_node("EnemySpawner")).is_empty(), "the story fight stays done (no enemy at the start)")
	for fight: String in FIGHTS:
		ck(_alive(road.get_node(fight)).is_empty(), "%s: no enemy before the hero comes" % fight)
	for fight: String in FIGHTS:
		var spawner: Node = road.get_node(fight)
		var zone: Area2D = spawner.trigger_area
		player.global_position = Vector2(zone.global_position.x, 330.0 if fight != "Fight_Mesa" else 270.0)
		player.velocity = Vector2.ZERO
		await create_timer(3.5).timeout  # waves of 2, 1.5 s apart
		var alive: Array = _alive(spawner)
		ck(alive.size() == FIGHTS[fight], "%s: %d enemies after the hero walked in (%d)" % [fight, FIGHTS[fight], alive.size()])
		for enemy in alive:
			ck(enemy.is_on_floor(), "%s: %s stands on the floor (y %.0f)" % [fight, enemy.name, enemy.global_position.y])
		for enemy in alive:
			enemy.die()
		for i in 6: await physics_frame
		ck(_alive(spawner).is_empty(), "%s: won" % fight)

	print("[2] A won section stays won")
	game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	road = game.map
	for fight: String in FIGHTS:
		var spawner: Node = road.get_node(fight)
		player.global_position = Vector2(spawner.trigger_area.global_position.x, 330.0 if fight != "Fight_Mesa" else 270.0)
		await create_timer(2.0).timeout
		ck(_alive(spawner).is_empty(), "%s: nobody comes back" % fight)

	print("[3] The dune ledge: jump up, pick up, gone after a reload")
	var inventory: Node = sl.get_inventory_manager()
	var before: int = inventory.get_item_count("potion")
	# On the floor west of the step (tiles 58–61, top y 320), facing east.
	player.global_position = Vector2(1800.0, 360.0)
	player.velocity = Vector2.ZERO
	await create_timer(0.5).timeout
	Input.action_press(&"move_right")
	await create_timer(0.15).timeout
	await _hold(&"jump", 0.25)  # onto the step
	await create_timer(0.45).timeout
	await _hold(&"jump", 0.25)  # onto the rock (tiles 62–65, top y 256)
	await create_timer(0.3).timeout
	Input.action_release(&"move_right")
	await create_timer(0.6).timeout
	if player.global_position.x > 2060.0:  # overshot the potion: a step back west
		await _hold(&"move_left", 0.12)
		await create_timer(0.3).timeout
	ck(player.is_on_floor() and player.global_position.y < 260.0 and absf(player.global_position.x - 2048.0) < 30.0,
			"the hero stands on the ledge (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
	var pickup: Node = road.get_node("Pickup_DuneLedge")
	ck(pickup.get_node("Interactable").enabled, "the potion offers \"Pick up\"")
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"interact"
	Input.parse_input_event(release)
	for i in 6: await process_frame
	ck(inventory.get_item_count("potion") == before + 1, "a potion in the bag (%d → %d)" % [before, inventory.get_item_count("potion")])
	var layer = sl.get_ui_manager().get_modal_layer()
	if layer.active_modal:
		layer.active_modal.get_viewport().gui_get_focus_owner().pressed.emit()
		for i in 4: await process_frame
	game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	ck(game.map.get_node_or_null("Pickup_DuneLedge") == null, "the picked potion does not come back")
	ck(game.map.get_node_or_null("Pickup_MesaLedge") != null, "the other ledges keep theirs")

	print("[4] The east edge leads to CityGates")
	player.global_position = Vector2(5100.0, 340.0)
	Input.action_press(&"move_right")
	for i in 240:
		await physics_frame
		if game.map.scene_file_path.ends_with("CityGates.tscn"):
			break
	Input.action_release(&"move_right")
	ck(game.map.scene_file_path.ends_with("CityGates.tscn"), "walking east loads CityGates (%s)" % game.map.scene_file_path)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
