extends SceneTree

## Зала вогняного джина (queue row 9.7, D302, D307): справжній ввід. Герой заходить (move_right) — розмова про плащ,
## зала замикається (на захід не вийти, брама на сході опущена); пропуск утриманням Tab — той самий стан бою.
## Джин б'ється (ходи, смужка боса), асист компаньйона кличеться кнопкою. Сейв посеред бою → бій одразу, без розмови.
## Програш → джин забирає плащ, звичайний Game Over. Перемога (останній удар — справжня attack) → репліка, брама
## піднімається, колізії немає; на місток — одним справжнім стрибком (B83); герой іде на схід у LaboratoryOutside.
##   godot --headless --path . --script res://SampleProject/UI/verify_lab_boss.gd

const HALL := "res://SampleProject/Maps/LabBoss.tscn"
const TEST_DIR := "user://verify_lab_boss/"
const TEST_SLOT := 1
## Асисти відкриває 9.5 (LabCells); тут — лише для тесту.
const ASSIST_FLAGS: Array[String] = ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete"]
## Містки для ухилів (build_laboratory.gd, рядок 9): верх — y 288, x 352–544 і 1216–1408.
const BRIDGES: Array[Vector2] = [Vector2(448, 288), Vector2(1312, 288)]

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

func _djinn() -> Node2D:
	return _hall().get_node_or_null(^"FireDjinn") if _hall() else null

func _hud_visible() -> bool:
	return (game.get_node(^"UI") as CanvasLayer).visible and (game.get_node(^"UICanvas") as CanvasLayer).visible

## Герой невразливий, поки тест сам не захоче програти.
func _tough() -> void:
	game.player.Max_Health = 99999
	game.player.current_health = 99999

## Справжній ввід: герой іде праворуч, доки не почнеться розмова.
func _walk_in() -> void:
	_press(&"move_right")
	await _until(func() -> bool: return _state() != "WAIT", 6.0)
	_press(&"move_right", false)

func _talk_played_to_fight() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while _state() != "FIGHT" and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame

## Утримання Tab секунду — пропуск; далі сцена домотується сама до бою.
func _skip_to_fight() -> void:
	await _until(func() -> bool: return root.get_node_or_null(^"CutsceneSkipPrompt") != null, 5.0)
	_tab(true)
	await create_timer(1.2, true, false, true).timeout
	_tab(false)
	await _until(func() -> bool: return _state() == "FIGHT", 20.0)

func _snap() -> Dictionary:
	var hall := _hall()
	var djinn := _djinn()
	return {"state": _state(), "flags": game.get_quest_flags().duplicate(true), "objective": game.get_objective(),
			"hero": game.player.global_position, "djinn": djinn.global_position,
			"locked": hall.is_arena_locked(), "gates_open": hall.are_gates_open(),
			"awake": djinn.process_mode == Node.PROCESS_MODE_INHERIT, "bar": djinn.bar.visible,
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

func _room_music_back(label: String) -> void:
	await _until(func() -> bool: return _music() == _hall_track(), 8.0)
	ck(_music() == _hall_track(), "%s: the hall's own Music is back (%s)" % [label, _music().resource_path if _music() else "none"])

func _fight_state_ok(s: Dictionary, label: String) -> void:
	ck(s.state == "FIGHT", "%s: fight state (%s)" % [label, s.state])
	ck(s.locked and not s.gates_open, "%s: the arena is locked, the gates down (%s)" % [label, s])
	ck(s.awake and s.bar, "%s: the djinn is awake, the boss bar shows" % label)
	ck(s.hud and s.control and is_equal_approx(s.speed, 1.0), "%s: HUD and control back, normal speed" % label)
	ck(s.handler, "%s: the hall owns the hero's defeat (the cloak)" % label)
	ck(s.objective == "Defeat the fire djinn", "%s: objective (%s)" % [label, s.objective])
	ck(s.flags.get("lab_boss_talk_complete", false) and not s.flags.get("lab_boss_fight_complete", false), "%s: talk flag set, fight not won" % label)
	ck(_music() == root.get_node("AudioManager").music["boss"], "%s: the boss track plays (D414)" % label)

## Справжній стрибок з підлоги під містком: герой стає на нього (односторонній — знизу проходить наскрізь).
## Ступні — низ колізії героя; на підлозі (y 384) вони на feet px нижче за його позицію.
func _jump_onto(bridge: Vector2, label: String) -> void:
	var p: CharacterBody2D = game.player
	p.global_position = Vector2(bridge.x, 340.0)
	p.velocity = Vector2.ZERO
	for i in 30: await physics_frame
	var feet: float = 384.0 - p.global_position.y
	ck(p.is_on_floor() and feet > 0.0 and feet < 64.0, "%s: on the floor under the bridge (%s)" % [label, p.global_position])
	var top := p.global_position.y
	_press(&"jump")  # утримання — повний стрибок (коротке натискання — короткий)
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		top = minf(top, p.global_position.y)
		await physics_frame
	_press(&"jump", false)
	ck(p.is_on_floor() and absf(p.global_position.y + feet - bridge.y) < 4.0, "%s: one real jump lands on it (feet y %.0f, top %.0f; apex feet %.0f)" % [label, p.global_position.y + feet, bridge.y, top + feet])

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
	for flag in ASSIST_FLAGS:
		game.set_quest_flag(flag, true)
		sl.get_companion_manager().join_on_unlock(flag)  # як у 9.5: відкритий — у загін

	print("[1] Arriving: the djinn waits asleep, the gates are down, nothing plays")
	game.teleport_to_room(HALL, ^"Arrival")
	for i in 30: await physics_frame
	started.clear()
	for i in 30: await physics_frame
	var hall := _hall()
	ck(hall != null, "in the boss hall")
	ck(_state() == "WAIT" and started.is_empty(), "WAIT, no dialogue (%s, %s)" % [_state(), started])
	ck(not hall.is_arena_locked() and not hall.are_gates_open(), "way west open, the gates down")
	ck(_djinn().process_mode == Node.PROCESS_MODE_DISABLED and not _djinn().bar.visible, "the djinn sleeps, no boss bar")
	ck(game.get_objective() == "Defeat the fire djinn", "objective (%s)" % game.get_objective())

	print("[2] Walking in (real move_right): the cloak talk, the hall seals")
	await _walk_in()
	ck(_state() == "TALK" and game.player.event, "TALK, input taken (%s)" % _state())
	for i in 3: await physics_frame
	ck(hall.is_arena_locked(), "the arena locks as the talk starts")
	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	ck(started == ["Lab_Boss_Talk"], "the cloak talk (%s)" % [started])
	ck(not _hud_visible() and root.get_node_or_null(^"CutsceneSkipPrompt") != null, "HUD hidden, skip prompt shown")
	await _talk_played_to_fight()
	var played := _snap()
	_fight_state_ok(played, "played")
	_tough()

	print("[3] Locked in: no way back west, the gates stop him in the east")
	_press(&"move_left")
	await create_timer(2.5).timeout
	_press(&"move_left", false)
	ck(_hall() != null and game.player.global_position.x > 0.0, "move_left stops at the arena wall (x %.0f)" % game.player.global_position.x)
	game.player.global_position = Vector2(1460, 380)
	for i in 10: await physics_frame
	_press(&"move_right")
	await create_timer(1.5).timeout
	_press(&"move_right", false)
	ck(_hall() != null and game.player.global_position.x < 1560.0, "move_right stops at the gates (x %.0f)" % game.player.global_position.x)
	ck(started.count("Lab_Boss_Talk") == 1, "the talk played once (%s)" % [started])

	print("[4] Same beat, skipped with a real Tab hold, from the same start")
	game.set_quest_flag("lab_boss_talk_complete", false)
	game.teleport_to_room(HALL, ^"Arrival")
	for i in 30: await physics_frame
	started.clear()
	ck(_state() == "WAIT", "a fresh hall waits (%s)" % _state())
	await _walk_in()
	await _skip_to_fight()
	var skipped := _snap()
	_fight_state_ok(skipped, "skipped")
	ck(root.get_node_or_null(^"CutsceneSkipPrompt") == null, "skip prompt gone")
	ck(started == ["Lab_Boss_Talk"], "the same talk ran under the skip (%s)" % [started])
	for key in ["flags", "objective"]:
		ck(played[key] == skipped[key], "skipped %s == played" % key)
	for key in ["hero", "djinn"]:
		ck((played[key] as Vector2).distance_to(skipped[key]) < 16.0, "skipped %s ends where played (%s vs %s)" % [key, skipped[key], played[key]])
	_tough()

	print("[5] The djinn fights: its moves come, they hurt; the boss bar follows HP; an assist answers the button")
	var djinn := _djinn()
	var kinds: Array[String] = []
	djinn.enemy_logic.attack_started.connect(func() -> void: kinds.append(String(djinn.enemy_logic.last_move.kind)))
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline and not (kinds.has("combo") and kinds.has("fireball") and kinds.has("pillar")):
		# Хід — за відстанню (fire_djinn.tscn: пазурі до 120 px, кулі 150–700, стовп усюди; D302). B117: перемикання
		# близько/далеко кожні 0.5 с з перервою джина 1.0 с (D411) щоразу потрапляло в те саме — тепер відстань під хід,
		# якого ще не було; на 135 px підходить лише стовп.
		if not djinn.enemy_logic.is_attacking:
			var gap := 400.0 if not kinds.has("fireball") else (60.0 if not kinds.has("combo") else 135.0)
			var x := clampf(djinn.global_position.x + (-gap if djinn.global_position.x > 700.0 else gap), 80.0, 1480.0)
			game.player.global_position = Vector2(x, 380)
		game.player.current_health = 99999
		await create_timer(0.5).timeout
	ck(kinds.has("combo") and kinds.has("fireball") and kinds.has("pillar"), "claws, fireball and pillar all come (%s)" % [kinds])
	var hits: Array[int] = []
	game.player.health_changed.connect(func(h: int, _m: int, _a: bool) -> void: hits.append(h))
	game.player.global_position = Vector2(djinn.global_position.x - 60.0, 380)
	await _until(func() -> bool: return hits.any(func(h: int) -> bool: return h < 99999), 15.0)
	ck(hits.any(func(h: int) -> bool: return h < 99999), "its blows hurt the hero (%s)" % [hits.slice(0, 4)])
	_tough()
	var bar: Control = djinn.bar
	ck(bar.visible and bar.is_inside_tree(), "the boss bar shows")
	djinn.take_damage(100)
	for i in 5: await process_frame
	var fill: ProgressBar = bar.get_node(^"%BossHp")
	ck(is_equal_approx(fill.value / fill.max_value, float(djinn.current_health) / djinn.Max_Health), "the bar follows the djinn's HP (%d/%d)" % [djinn.current_health, djinn.Max_Health])
	var assists: Array[String] = []
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: assists.append(id))
	_press(&"assist")
	await physics_frame
	await physics_frame
	_press(&"assist", false)
	for i in 10: await physics_frame
	ck(assists.size() == 1, "a real assist press calls a companion (%s)" % [assists])

	print("[6] Save mid-fight, load: the fight is on at once, no talk replay")
	ck(game.save_game(), "saved in the hall")
	DirAccess.copy_absolute(slot_path, TEST_DIR + "hall.bak")
	game.queue_free()
	for i in 4: await process_frame
	await _boot(slot_path)
	ck(_hall() != null, "loaded into the boss hall")
	var loaded := _snap()
	_fight_state_ok(loaded, "after load")
	ck(started.is_empty(), "no talk on load (%s)" % [started])
	ck(_djinn().current_health == _djinn().Max_Health, "the djinn starts the fight anew (%d)" % _djinn().current_health)
	var arena: Vector2 = _hall().get_node(^"RoomInstance").get_size()
	ck(game.player.global_position.x > 0.0 and game.player.global_position.x < 1560.0 and game.player.global_position.y < arena.y, "the hero is inside the locked arena (%s)" % game.player.global_position)

	print("[7] Lose: the djinn beats him → it takes the cloak → the normal Game Over")
	game.player.current_health = 1
	game.player.global_position = Vector2(_djinn().global_position.x - 60.0, 380)
	await _until(func() -> bool: return started.has("Lab_Boss_TakesCloak"), 20.0)
	ck(started.has("Lab_Boss_TakesCloak"), "the djinn takes the cloak (%s)" % [started])
	ck(_state() == "CLOAK", "CLOAK state (%s)" % _state())
	ck(absf(_djinn().global_position.x - game.player.global_position.x) < 70.0, "the djinn hovers at the hero (%.0f vs %.0f)" % [_djinn().global_position.x, game.player.global_position.x])
	ck(get_first_node_in_group(&"game_over_screen") == null, "no Game Over before the line ends")
	await _drain()
	await _until(func() -> bool: return get_first_node_in_group(&"game_over_screen") != null, 5.0)
	ck(get_first_node_in_group(&"game_over_screen") != null and paused, "the Game Over screen, game paused")
	ck(not game.player.defeat_handler.is_valid() and not game.get_quest_flag("lab_boss_fight_complete"), "handler cleared, no win flag")
	await _room_music_back("lose")
	paused = false
	for layer in game.find_children("GameOverLayer", "CanvasLayer", false, false):
		layer.free()

	print("[8] Win: the last blow is a real attack → the line, the gates go up, the way east")
	game.queue_free()
	for i in 4: await process_frame
	DirAccess.copy_absolute(TEST_DIR + "hall.bak", slot_path)
	await _boot(slot_path)
	_fight_state_ok(_snap(), "win run")
	_tough()
	var xp: Node = sl.get_xp_manager()
	var gained: Array = []
	xp.xp_gained.connect(func(amount: int, _t: int) -> void: gained.append(amount))
	djinn = _djinn()
	djinn.current_health = 1
	for i in 30:
		if djinn.is_dead:
			break
		game.player.global_position = Vector2(djinn.global_position.x - 50.0, 380)
		game.player.mover.last_direction = 1
		_press(&"attack")
		await physics_frame
		await physics_frame
		_press(&"attack", false)
		await create_timer(0.3).timeout
	ck(djinn.is_dead, "the djinn falls to a real attack")
	ck(gained.has(500), "+500 XP from the djinn (%s)" % [gained])
	await _until(func() -> bool: return started.has("Laboratory_AfterBoss"), 6.0)
	ck(started.has("Laboratory_AfterBoss"), "Kusakam's cloak line (%s)" % [started])
	ck(_state() == "OPEN" and not _hall().is_arena_locked(), "OPEN, the arena unlocked")
	await _room_music_back("win")
	await _drain()
	await _until(func() -> bool: return game.get_quest_flag("lab_after_boss_complete") and root.get_node_or_null(^"CutsceneSkipPrompt") == null, 10.0)
	ck(game.get_quest_flag("lab_boss_fight_complete") and game.get_quest_flag("lab_after_boss_complete"), "fight and after-boss flags")
	ck(_hall().are_gates_open(), "the gates are up, their collision off")
	var gate: Sprite2D = _hall().get_node(^"Gates/Sprite")
	ck(gate.position.y < 384.0 - 150.0, "the portcullis is raised (y %.0f)" % gate.position.y)
	ck(game.get_objective() == "Leave the laboratory", "objective (%s)" % game.get_objective())
	ck(not game.player.event and _hud_visible(), "control and HUD back")

	print("[9] B83: each dodge bridge is one real jump up")
	for i in BRIDGES.size():
		await _jump_onto(BRIDGES[i], "bridge %d" % (i + 1))

	print("[10] The hero walks east out of the Laboratory")
	game.player.global_position = Vector2(1300, 380)
	for i in 10: await physics_frame
	_press(&"move_right")
	await _until(func() -> bool: return game.map != null and game.map.scene_file_path.ends_with("LaboratoryOutside.tscn"), 10.0)
	_press(&"move_right", false)
	ck(game.map != null and game.map.scene_file_path.ends_with("LaboratoryOutside.tscn"), "through the gates into LaboratoryOutside (%s)" % (game.map.scene_file_path if game.map else "null"))
	await _drain()

	game.queue_free()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
