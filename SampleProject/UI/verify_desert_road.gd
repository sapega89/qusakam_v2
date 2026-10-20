extends SceneTree

## Desert Road (Sapega, 2026-10-12): Canyon II закривається при спуску на дорогу,
## монолог чекає на тригер, вороги справді зʼявляються, а бій зараховується
## лише коли всі вороги мертві.
##   godot --headless --path . --script res://SampleProject/UI/verify_desert_road.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Кімната без RoomInstance (MetSys) — інакше її не завантажити поза Game.
func _load_road() -> Node:
	var road: Node = load("res://SampleProject/Maps/DesertRoad.tscn").instantiate()
	var room_instance: Node = road.get_node_or_null("RoomInstance")
	if room_instance:
		road.remove_child(room_instance)
		room_instance.free()
	root.add_child(road)
	return road

func _enemies(road: Node) -> Array[Node]:
	var found: Array[Node] = []
	for node in road.find_children("*", "CombatBody2D", true, false):
		if node.is_alive():
			found.append(node)
	return found

func _reset_flags(game: Node, extra: Dictionary) -> void:
	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in ["canyon_exit_complete", "desert_road_monologue_complete", "desert_road_fight_complete"]:
		flags.erase(f)
	flags.merge(extra, true)
	game.set_quest_flags(flags)
	# Бій теж памʼятає своїх убитих (D152) — новий прогін починаємо з чистої кімнати.
	game.set_room_states({})

## Проклацує справжній діалог до кінця (accept як Enter / клік у грі).
func _finish_dialogue(dm: Node) -> void:
	# Діалоги йдуть ланцюжком із паузою між ними (черга DialogueManager) — доки не стихне.
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

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var bus: Node = root.get_node("EventBus")
	# Як кнопка New Game: без цього Game.tscn вантажить справжній сейв гравця.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())  # вступ Canyon
	var started: Array[String] = []
	sl.get_dialogue_manager().dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[1] Landing on the road closes Canyon II and waits for the trigger")
	_reset_flags(game, {})
	var road: Node = _load_road()
	for i in 6: await process_frame
	ck(game.get_quest_flag("canyon_exit_complete"), "canyon_exit_complete set on arrival")
	ck(road.current_state == road.State.TRAVELING, "state TRAVELING")
	ck(not started.has("DesertRoad_Monologue"), "monologue not started by arrival (%s)" % [started])

	print("[2] Monologue → taunt first, enemies appear only after it")
	var dm: Node = sl.get_dialogue_manager()
	bus.dialogue_finished.emit("DesertRoad_Monologue")
	for i in 6: await process_frame
	ck(road.current_state == road.State.FIGHT_ENCOUNTER, "state FIGHT_ENCOUNTER")
	ck(started.has("DesertRoad_Fight"), "the taunt is playing (%s)" % [started])
	ck(_enemies(road).size() == 0, "no enemy yet while the player is locked in the dialogue (%d)" % _enemies(road).size())
	await _finish_dialogue(dm)
	await create_timer(2.5).timeout  # дві хвилі з паузою 1.5 с
	ck(_enemies(road).size() == 4, "4 enemies on the road after the taunt (%d)" % _enemies(road).size())
	ck(road.current_state == road.State.FIGHT_ENCOUNTER, "the taunt alone does not end the fight")
	ck(not game.get_quest_flag("desert_road_fight_complete"), "fight not counted yet")

	print("[3] Killing every enemy ends the fight")
	for enemy in _enemies(road):
		enemy.die()
	for i in 4: await process_frame
	ck(game.get_quest_flag("desert_road_fight_complete"), "desert_road_fight_complete set")
	ck(road.current_state == road.State.TRANSITION_TO_CITY, "state TRANSITION_TO_CITY")
	road.queue_free()
	for i in 4: await process_frame

	print("[4] Re-entering after the monologue: taunt, then enemies")
	_reset_flags(game, {"desert_road_monologue_complete": true})
	road = _load_road()
	for i in 6: await process_frame
	ck(road.current_state == road.State.FIGHT_ENCOUNTER, "state FIGHT_ENCOUNTER")
	ck(_enemies(road).size() == 0, "no enemy before the taunt ends")
	await _finish_dialogue(dm)
	await create_timer(2.5).timeout
	ck(_enemies(road).size() == 4, "4 enemies on the road (%d)" % _enemies(road).size())
	road.queue_free()

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
