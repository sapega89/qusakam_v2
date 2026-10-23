extends SceneTree

## Зала мера (queue row 9.3, D255, D300, D301): справжній ввід. Герой заходить (move_right) — кат-сцена черги
## й пролому одна, грає раз; пропуск (утримання Tab) закінчується в тому самому стані бою; шлях назад перекрито.
## Сейв посеред бою → завантаження починає залу з черги. Перемога (останній удар — справжня кнопка attack) →
## лабораторія, +XP боса і речі із зали; програш (б'є сам бос) → лабораторія без Game Over, герой на ногах.
## Також B51: телепорт у залу вантажить кімнату один раз (був verify_mayor_hall_teleport.gd).
##   godot --headless --path . --script res://SampleProject/UI/verify_mayor_hall.gd

const HALL := "res://SampleProject/Maps/MayorHall.tscn"
const TEST_DIR := "user://verify_mayor_hall/"
const TEST_SLOT := 1

var fails: Array[String] = []
var game: Node
var dm: Node
var sl: Node
var started: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _drain() -> void:
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

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tab(pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.keycode = KEY_TAB
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _boot(save_path: String) -> void:
	if save_path.is_empty():
		set_meta("start_new_game", true)
	else:
		set_meta("save_file_path", save_path)
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	started.clear()

func _hall() -> Node:
	return game.map if game.map != null and game.map.scene_file_path == HALL else null

func _state() -> String:
	return _hall().get_current_state_name() if _hall() else "-"

func _hud_visible() -> bool:
	return (game.get_node(^"UI") as CanvasLayer).visible and (game.get_node(^"UICanvas") as CanvasLayer).visible

## Справжній ввід: герой іде праворуч, доки не почнеться кат-сцена.
func _walk_in() -> void:
	_press(&"move_right")
	await _until(func() -> bool: return _state() != "QUEUE", 5.0)
	_press(&"move_right", false)

## Утримання Tab секунду — пропуск; далі сцена домотується сама до бою.
func _skip_to_fight() -> void:
	await _until(func() -> bool: return root.get_node_or_null(^"CutsceneSkipPrompt") != null, 5.0)
	_tab(true)
	await create_timer(1.2, true, false, true).timeout
	_tab(false)
	await _until(func() -> bool: return _state() == "FIGHT", 20.0)
	for i in 30: await physics_frame

func _snap() -> Dictionary:
	var hall := _hall()
	return {"state": _state(), "flags": game.get_quest_flags().duplicate(true), "objective": game.get_objective(),
			"hero": game.player.global_position, "boss": (hall.get_node(^"ScorpicoreWarrior") as Node2D).global_position,
			"boss_visible": hall.get_node(^"ScorpicoreWarrior").visible, "hole": hall.get_node(^"WallHole").visible,
			"barrier": not hall.get_node(^"BarrierWest/Collision").disabled, "queue": hall.get_node(^"Queue").visible,
			"hud": _hud_visible(), "control": not game.player.event, "speed": Engine.time_scale,
			"handler": game.player.defeat_handler.is_valid()}

## Музика бою (D414): що зараз грає ProjectMusicController і трек вузла Music самої зали.
func _music() -> AudioStream:
	var player: AudioStreamPlayer = root.get_node("ProjectMusicController").music_stream_player
	return player.stream if is_instance_valid(player) else null

func _hall_track() -> AudioStream:
	var state := (load(HALL) as PackedScene).get_state()
	for n in state.get_node_count():
		if state.get_node_name(n) == &"Music":
			for i in state.get_node_property_count(n):
				if state.get_node_property_name(n, i) == &"stream":
					return state.get_node_property_value(n, i)
	return null

## Бос упав / переміг: його трек замовкає, кат-сцена — не бій (B116): одразу трек зали, зброя за спиною.
func _room_music_back(label: String) -> void:
	await _until(func() -> bool: return _music() == _hall_track(), 1.0)
	ck(_music() == _hall_track(), "%s: boss track off → the hall's own Music (%s)" % [label, _music().resource_path if _music() else "none"])
	ck(not game.player.combat.in_combat() and game.player.weapon_view.sheathed, "%s: the fight is over in the cutscene, the weapon sheathed (B116)" % label)

func _fight_state_ok(s: Dictionary, label: String) -> void:
	ck(s.state == "FIGHT", "%s: fight state (%s)" % [label, s.state])
	ck(s.boss_visible and s.hole and s.barrier and not s.queue, "%s: boss out, hole shown, west barred, queue gone (%s)" % [label, s])
	ck(s.hud and s.control and is_equal_approx(s.speed, 1.0), "%s: HUD and control back, normal speed" % label)
	ck(s.handler, "%s: the hall owns the hero's defeat (no Game Over)" % label)
	ck(s.objective == "Survive the Scorpicore Axe-Warrior", "%s: objective (%s)" % [label, s.objective])
	ck(_music() == root.get_node("AudioManager").music["boss"], "%s: the boss track plays (D414)" % label)

func _in_lab(label: String) -> void:
	await _until(func() -> bool: return game.map != null and game.map.scene_file_path.ends_with("LabCells.tscn"), 10.0)
	ck(game.map != null and game.map.scene_file_path.ends_with("LabCells.tscn"), "%s: transported to the Lab cells (%s)" % [label, game.map.scene_file_path if game.map else "null"])
	for i in 30: await physics_frame
	var entrance: Node2D = game.map.get_node("Arrival")
	var offset: Vector2 = game.player.global_position - entrance.global_position
	ck(absf(offset.x) < 1.0 and absf(offset.y) < 32.0, "%s: in his cell (offset %s)" % [label, offset])
	ck(game.get_quest_flag("city_mayor_hall_complete"), "%s: city_mayor_hall_complete" % label)
	ck(get_first_node_in_group(&"game_over_screen") == null, "%s: no Game Over screen" % label)
	ck(not game.player.is_dead and game.player.current_health == game.player.Max_Health, "%s: hero on his feet (%d/%d)" % [label, game.player.current_health, game.player.Max_Health])
	ck(game.player.defeat_handler.is_valid() == false, "%s: defeat handler cleared" % label)
	# Далі — кат-сцена камер (D304, verify_lab_cells.gd): справжнє утримання Tab пропускає її до пробудження.
	await _until(func() -> bool: return started.has("Lab_Cells_Arrival"), 6.0)
	ck(started.has("Lab_Cells_Arrival") and game.map.get_current_state_name() == "CUTSCENE", "%s: the cells cutscene starts (%s)" % [label, started])
	await _until(func() -> bool: return root.get_node_or_null(^"CutsceneSkipPrompt") != null, 5.0)
	_tab(true)
	await create_timer(1.2, true, false, true).timeout
	_tab(false)
	await _until(func() -> bool: return game.map.get_current_state_name() == "AWAKE" and not game.player.event, 20.0)
	await create_timer(0.5).timeout
	ck(not game.player.event and _hud_visible(), "%s: control and HUD back in the lab" % label)
	ck(root.get_node_or_null(^"ScreenFade") == null, "%s: the black is lifted" % label)

func _initialize() -> void:
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false  # D289
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	var slot_path: String = save_system.get_slot_path(TEST_SLOT)
	await process_frame
	sl = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	await _boot("")
	await _drain()  # вступ Canyon

	print("[1] Arriving: the queue waits, nothing plays")
	var loads_before: int = game._load_room_call_count
	await game.teleport_to_room(HALL, ^"Arrival")
	for i in 30: await physics_frame
	ck(game._load_room_call_count - loads_before == 1, "one teleport loads the room once (B51, %d)" % (game._load_room_call_count - loads_before))
	ck(_hall() != null, "in the Mayor Hall")
	started.clear()
	for i in 30: await physics_frame
	var hall := _hall()
	ck(_state() == "QUEUE" and started.is_empty(), "QUEUE, no dialogue (%s, %s)" % [_state(), started])
	ck(not hall.get_node(^"ScorpicoreWarrior").visible and hall.get_node(^"ScorpicoreWarrior").process_mode == Node.PROCESS_MODE_DISABLED, "the boss is not there yet")
	ck(not hall.get_node(^"WallHole").visible and hall.get_node(^"BarrierWest/Collision").disabled, "wall whole, way west open")
	for id in ["astrit", "urizen", "alisia"]:
		ck(hall.get_node("Queue/CompanionNPC_" + id).visible, "%s stands in the queue" % id)

	print("[2] Walking in (real move_right): the queue cutscene, then the wall bursts")
	await _walk_in()
	ck(game.player.event, "input taken")
	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	ck(started == ["City_MayorHall"], "the queue talk (%s)" % [started])
	var spot: Node2D = hall.get_node(^"Queue/Kusakam")
	ck(absf(game.player.global_position.x - spot.global_position.x) < 2.0, "the hero stands at the end of the queue (%.0f vs %.0f)" % [game.player.global_position.x, spot.global_position.x])
	ck(not (game.player.get_node(^"Sprite2D") as Sprite2D).flip_h, "facing the mayor's door")
	ck(not _hud_visible() and root.get_node_or_null(^"CutsceneSkipPrompt") != null, "HUD hidden, skip prompt shown")
	var deadline := Time.get_ticks_msec() + 30000
	while _state() != "FIGHT" and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
	for i in 30: await physics_frame
	ck(started == ["City_MayorHall", "MayorHall_WallBurst"], "then the wall-burst talk (%s)" % [started])
	var played := _snap()
	_fight_state_ok(played, "played")

	print("[3] The way back is barred; the queue never replays")
	_press(&"move_left")
	await create_timer(2.5).timeout
	_press(&"move_left", false)
	ck(game.player.global_position.x > 0.0 and _hall() != null, "move_left stops at the west barrier (x %.0f)" % game.player.global_position.x)
	_press(&"move_right")
	await create_timer(1.0).timeout
	_press(&"move_right", false)
	ck(started.count("City_MayorHall") == 1, "the queue played once (%s)" % [started])

	print("[4] Same beat, skipped with a real Tab hold, from the same start")
	await game.teleport_to_room(HALL, ^"Arrival")
	for i in 30: await physics_frame
	started.clear()
	ck(_state() == "QUEUE", "a fresh hall starts at the queue (%s)" % _state())
	await _walk_in()
	await _skip_to_fight()
	var skipped := _snap()
	_fight_state_ok(skipped, "skipped")
	ck(root.get_node_or_null(^"CutsceneSkipPrompt") == null, "skip prompt gone")
	for key in ["flags", "objective"]:
		ck(played[key] == skipped[key], "skipped %s == played" % key)
	for key in ["hero", "boss"]:
		ck((played[key] as Vector2).distance_to(skipped[key]) < 4.0, "skipped %s ends where played (%s vs %s)" % [key, skipped[key], played[key]])

	print("[5] Save mid-fight, load: the hall starts again from the queue")
	ck(game.save_game(), "saved in the hall")
	DirAccess.copy_absolute(slot_path, TEST_DIR + "hall.bak")  # переходи далі автозберігаються в цей слот
	game.queue_free()
	for i in 4: await process_frame
	await _boot(slot_path)
	ck(_hall() != null, "loaded into the Mayor Hall")
	await _until(func() -> bool: return _state() != "QUEUE", 3.0)
	ck(_state() == "BURST" and not game.get_quest_flag("city_mayor_hall_complete"), "the queue cutscene starts where he stands (%s)" % _state())
	await _skip_to_fight()
	_fight_state_ok(_snap(), "after load")

	print("[6] Win: the last blow is a real attack → Lab, boss XP and the hall's loot")
	var xp: Node = sl.get_xp_manager()
	var inv: Node = sl.get_inventory_manager()
	var gained: Array = []
	xp.xp_gained.connect(func(amount: int, _t: int) -> void: gained.append(amount))
	var before := {"silver_ingot": inv.get_item_count("silver_ingot"), "silver_sword": inv.get_item_count("silver_sword")}
	# Монети з убитого боса падають ще й випадково (LootSystem, 70 % по 5–20) — тож рахуємо саме додавання +60 із зали.
	var coin_adds: Array = []
	root.get_node("EventBus").item_added.connect(func(id: String, amount: int) -> void:
		if id == "coin": coin_adds.append(amount))
	var boss: Node2D = _hall().get_node(^"ScorpicoreWarrior")
	game.player.Max_Health = 99999
	game.player.current_health = 99999
	boss.current_health = 1
	for i in 20:
		if boss.is_dead:
			break
		game.player.global_position = Vector2(boss.global_position.x - 50.0, game.player.global_position.y)
		game.player.mover.last_direction = 1
		_press(&"attack")
		await physics_frame
		await physics_frame
		_press(&"attack", false)
		await create_timer(0.3).timeout
	ck(boss.is_dead, "the axe-warrior falls to a real attack")
	await _until(func() -> bool: return started.has("MayorHall_Victory"), 6.0)
	ck(started.has("MayorHall_Victory"), "the victory talk (%s)" % [started])
	await _room_music_back("win")
	ck(gained.has(400), "+400 XP from the boss (%s)" % [gained])
	for item: String in before:
		var want: int = {"silver_ingot": 2, "silver_sword": 1}[item]
		ck(inv.get_item_count(item) == before[item] + want, "%s +%d (%d → %d)" % [item, want, before[item], inv.get_item_count(item)])
	ck(coin_adds.count(60) == 1, "the hall's 60 coins, once (coin adds %s)" % [coin_adds])
	ck(inv.get_item_count("hi_potion") == 0 and inv.get_item_count("potion") == 0, "no potions in the loot (4b)")
	ck(game.get_quest_flag("mayor_boss_defeated"), "mayor_boss_defeated set")
	await _drain()
	await _in_lab("win")

	print("[7] Lose: the boss beats him → Lab, no Game Over, no loot")
	game.queue_free()
	for i in 4: await process_frame
	DirAccess.copy_absolute(TEST_DIR + "hall.bak", slot_path)
	await _boot(slot_path)
	await _until(func() -> bool: return _state() == "BURST", 3.0)
	await _skip_to_fight()
	_fight_state_ok(_snap(), "lose run")
	gained.clear()
	var coins: int = inv.get_item_count("coin")
	boss = _hall().get_node(^"ScorpicoreWarrior")
	game.player.current_health = 1
	game.player.global_position = Vector2(boss.global_position.x - 90.0, game.player.global_position.y)
	await _until(func() -> bool: return started.has("MayorHall_Defeat"), 15.0)
	ck(started.has("MayorHall_Defeat"), "the defeat talk (%s)" % [started])
	await _room_music_back("lose")
	ck(get_first_node_in_group(&"game_over_screen") == null, "no Game Over screen on defeat")
	ck(not game.get_quest_flag("mayor_boss_defeated") and gained.is_empty() and inv.get_item_count("coin") == coins, "no win flag, XP or loot")
	await _drain()
	await _in_lab("lose")

	game.queue_free()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
