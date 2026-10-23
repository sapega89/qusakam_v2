extends SceneTree

## Desert Road (Sapega, 2026-10-12; D439): Canyon II закривається при спуску на дорогу, розмови перед боєм
## немає — вороги вже стоять на дорозі, а бій зараховується лише коли всі вороги мертві.
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
	for f in ["canyon_exit_complete", "desert_road_fight_complete"]:
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

	print("[1] Landing on the road closes Canyon II; no talk, the enemies already stand on the road (D439)")
	_reset_flags(game, {})
	var road: Node = _load_road()
	for i in 6: await process_frame
	ck(game.get_quest_flag("canyon_exit_complete"), "canyon_exit_complete set on arrival")
	ck(road.current_state == road.State.FIGHT_ENCOUNTER, "state FIGHT_ENCOUNTER from the start")
	ck(started.is_empty(), "no monologue, no 'Enemies on the road!' (%s)" % [started])
	ck(not FileAccess.file_exists("res://dialogue_quest/DesertRoad_Monologue.dqd") and not FileAccess.file_exists("res://dialogue_quest/en/DesertRoad_Fight.dqd"),
			"the road's talks are cut (en and uk)")
	ck(road.get_node_or_null("StateChangeTrigger_DesertMonologue") == null, "no monologue trigger on the road")
	ck(_enemies(road).size() == 4, "all 4 enemies stand on the road at once (%d)" % _enemies(road).size())
	var hero_x: float = road.get_node("ArrivalFromCanyon").global_position.x
	for enemy in _enemies(road):
		ck(enemy.global_position.x - hero_x > enemy.detection_range,
				"%s waits out of reach of the arriving hero (%.0f px > %.0f)" % [enemy.name, enemy.global_position.x - hero_x, enemy.detection_range])
	ck(not game.get_quest_flag("desert_road_fight_complete"), "fight not counted yet")

	print("[2] Killing every enemy ends the fight")
	for enemy in _enemies(road):
		enemy.die()
	for i in 4: await process_frame
	ck(game.get_quest_flag("desert_road_fight_complete"), "desert_road_fight_complete set")
	ck(road.current_state == road.State.TRANSITION_TO_CITY, "state TRANSITION_TO_CITY")
	road.queue_free()
	for i in 4: await process_frame

	print("[3] Re-entering after the fight: no enemies, on to the city")
	road = _load_road()
	for i in 6: await process_frame
	ck(road.current_state == road.State.TRANSITION_TO_CITY, "state TRANSITION_TO_CITY")
	ck(_enemies(road).size() == 0, "the road stays clear (%d)" % _enemies(road).size())
	ck(started.is_empty(), "still no talk (%s)" % [started])
	road.queue_free()

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
