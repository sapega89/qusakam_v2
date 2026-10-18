extends SceneTree

## Асисти компаньйонів ([[companion_assist_plan]], D209) у справжній грі на DesertRoad: хто відкритий —
## з прапорців лабораторії; одна кнопка кличе наступного готового; кожен справді б'є (кішка Алісії,
## удар Астрита, монети Уризена, охоронець біля воріт) і прибирає себе; кулдаун у кожного свій.
##   godot --headless --path . --script res://SampleProject/UI/verify_companions.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

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

## Слот асисту на хотбарі (зріз 4): видно? чий портрет? залишок кулдауну?
func _hud() -> Array:
	var bind: Control = get_first_node_in_group(&"skill_hotbar").get_node(^"%SlotsRow/AssistBind")
	var portrait: Texture2D = bind.get_node(^"Slot/Portrait").texture
	var overlay: Label = bind.get_node(^"Slot/Cooldown")
	var who := "" if portrait == null else portrait.resource_path.get_base_dir().get_file()
	return [bind.is_visible_in_tree(), who, overlay.text if overlay.visible else ""]

func _actors() -> Array:
	return get_nodes_in_group(&"companions")

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	var enemies: Array = game.map.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies"))
	var hero: Node2D = game.player
	hero.mover.last_direction = 1
	for i in enemies.size():  # стоять у ряд перед героєм, не рухаються й не б'ють
		enemies[i].set_physics_process(false)
		enemies[i].global_position = Vector2(hero.global_position.x + 60 + i * 50, enemies[i].global_position.y)
	var near = enemies[0]
	var cm: Node = sl.get_companion_manager()
	var called: Array = []
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: called.append(id))

	print("[1] Nobody unlocked → the button does nothing")
	ck(cm.get_unlocked().is_empty() and cm.call_next() == "" and _actors().is_empty(), "no companions, no assist")
	for i in 2: await process_frame  # хотбар оновлюється у своєму _process
	ck(not _hud()[0], "no assist slot on the hotbar")

	print("[2] The Laboratory flags unlock them, in roster order")
	for f in ["lab_companion_01_complete", "lab_companion_02_complete"]:  # як Laboratory._complete_quest_for_dialogue
		game.set_quest_flag(f, true)
		cm.join_on_unlock(f)
	ck(cm.get_unlocked() == ["alisia", "astrit"], "Алісия and Астрит unlocked (%s)" % [cm.get_unlocked()])
	ck(cm.get_party() == ["alisia", "astrit"], "each joins the party as unlocked (%s)" % [cm.get_party()])
	for i in 2: await process_frame  # хотбар оновлюється у своєму _process
	ck(_hud() == [true, "alisia", ""], "the hotbar shows Алісия ready (%s)" % [_hud()])

	print("[3] Алісия: her cat claws the nearest enemy 3 times")
	var hp: int = near.current_health
	ck(cm.call_next() == "alisia" and _actors().size() == 1, "Алісия runs in")
	await create_timer(2.5).timeout
	ck(near.current_health == hp - 3 * 8, "the cat clawed 3 × 8 (%d → %d)" % [hp, near.current_health])
	ck(_actors().is_empty(), "Алісия left and freed herself")

	print("[4] Астрит: pounces on the nearest enemy, a heavy blow")
	hp = near.current_health
	ck(cm.call_next() == "astrit", "Астрит is next in the queue")
	await create_timer(2.0).timeout
	ck(near.current_health == hp - 40, "Астрит hit for 40 (%d → %d)" % [hp, near.current_health])
	ck(cm.call_next() == "", "both on cooldown → nobody")
	for i in 2: await process_frame
	var hud := _hud()
	ck(hud[0] and hud[1] == "alisia" and hud[2].ends_with("s"), "the hotbar shows Алісия, soonest back, with seconds left (%s)" % [hud])

	print("[5] Уризен: a coin smite on every enemy in front, with a stun")
	game.set_quest_flag("lab_companion_03_complete", true)
	cm.join_on_unlock("lab_companion_03_complete")
	var before: Array = enemies.map(func(e: Node) -> int: return e.current_health)
	ck(cm.call_next() == "urizen", "Уризен answers")
	await create_timer(2.4).timeout
	# Вороги заморожені (фізика вимкнена), тож оглушення не спадає — видно і після удару.
	var stunned := enemies.filter(func(e: Node) -> bool: return e.enemy_logic.stun_left > 0.0)
	var hurt := 0
	for i in enemies.size():
		if enemies[i].current_health == before[i] - 30:
			hurt += 1
	ck(hurt == enemies.size(), "every enemy in front took 30 (%d of %d)" % [hurt, enemies.size()])
	ck(stunned.size() == enemies.size(), "and was stunned (%d)" % stunned.size())

	print("[6] Cooldowns: 15 s each, then the queue goes on")
	cm._process(cm.COOLDOWN + 0.1)
	ck(cm.is_ready("alisia") and cm.is_ready("astrit") and cm.is_ready("urizen"), "all ready after %.0f s" % cm.COOLDOWN)
	ck(cm.call_next() == "alisia", "the queue goes on after the last called (Уризен): Алісия")
	await create_timer(2.5).timeout

	print("[7] The City Gates guard: offered for the fight, his thrust ends it")
	cm.offer_guard(true)
	for i in 2: await process_frame  # хотбар оновлюється у своєму _process
	ck(_hud()[1] == "guard", "the hotbar shows the guard while he is offered (%s)" % [_hud()])
	ck(cm.call_next() == "guard" and not cm.is_guard_offered(), "the button calls the guard once")
	await create_timer(2.0).timeout
	ck(enemies.all(func(e: Node) -> bool: return not e.is_alive()), "every enemy in front is down")
	ck(called == ["alisia", "astrit", "urizen", "alisia", "guard"], "assist_called for each (%s)" % [called])
	await create_timer(1.0).timeout
	ck(_actors().is_empty(), "no companion left behind")
	# Охоронець б'є кількох одразу → кілька hitstop за кадр; гра мусить повернутись до нормальної швидкості.
	ck(is_equal_approx(Engine.time_scale, 1.0), "time runs normally after the guard's multi-hit (%.2f)" % Engine.time_scale)

	print("[8] The party (D220): chosen in Status, its order is the assist queue, at most 3")
	ck(cm.get_party() == ["alisia", "astrit", "urizen"], "all three in the party (%s)" % [cm.get_party()])
	cm._process(cm.COOLDOWN + 0.1)
	ck(not cm.toggle_party("alisia") and cm.get_party() == ["astrit", "urizen"], "Алісия stays in camp (%s)" % [cm.get_party()])
	cm._last_called = ""
	ck(cm.peek_next() == "astrit", "the queue starts at the first in the party (%s)" % cm.peek_next())
	ck(cm.toggle_party("alisia") and cm.get_party() == ["astrit", "urizen", "alisia"], "taken back, she goes last (%s)" % [cm.get_party()])
	var saved: Dictionary = root.get_node("SaveSystem").player_data_module.save()
	ck(saved.companion_party == cm.get_party(), "the party is saved with the player (%s)" % [saved.companion_party])
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Status")
	for i in 10: await process_frame
	var cards: Array = get_first_node_in_group("game_menu").find_child("CompanionCards", true, false).get_children().filter(func(c: Control) -> bool: return c.visible)
	var labels: Array = cards.map(func(c: Control) -> String: return "%s %s" % [c.get_node(^"Row/Info/Name").text, c.get_node(^"Row/Info/Order").text])
	ck(labels == ["Алісия IN PARTY · 3", "Астрит IN PARTY · 1", "Уризен IN PARTY · 2"], "Status shows each with its place in the queue (%s)" % [labels])
	cards[0].get_node(^"Select").pressed.emit()
	await process_frame
	ck(cards[0].get_node(^"Row/Info/Order").text == "IN CAMP" and not cm.is_in_party("alisia"), "pressing her card sends her to camp")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
