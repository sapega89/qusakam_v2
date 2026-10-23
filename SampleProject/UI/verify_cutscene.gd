extends SceneTree

## Спільні кат-сцени (D308, design/cutscene_plan.md): поки йде сцена, HUD сховано, у куті «Hold … to skip»;
## справжнє утримання Tab або геймпад Y секунду пропускає сцену — і вона закінчується в тому самому стані, що й
## дограна: прапорці (і завдання), стан кімнати, ціль, кімната, позиції героя й акторів. Кожну сцену грають двічі
## з одного й того самого стану: раз до кінця (репліки гортає тест), раз з пропуском (тест реплік не чіпає).
##   godot --headless --path . --script res://SampleProject/UI/verify_cutscene.gd

var fails: Array[String] = []
var game: Node
var dm: Node

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
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _hud_visible() -> bool:
	return (game.get_node(^"UI") as CanvasLayer).visible and (game.get_node(^"UICanvas") as CanvasLayer).visible

func _prompt() -> Node:
	return root.get_node_or_null(^"CutsceneSkipPrompt")

func _snap(actors: Array[NodePath]) -> Dictionary:
	var positions := {"hero": game.player.global_position}
	for path in actors:
		positions[str(path)] = (game.map.get_node(path) as Node2D).global_position
	return {"flags": game.get_quest_flags().duplicate(true), "rooms": game.get_room_states().duplicate(true),
			"objective": game.get_objective(), "room": game.map.scene_file_path, "positions": positions}

func _restore(state: Dictionary) -> void:
	game.set_quest_flags(state.flags)
	game.set_room_states(state.rooms)
	game.set_objective(state.objective)

func _same(played: Dictionary, skipped: Dictionary, beat: String) -> void:
	for key in ["flags", "rooms", "objective", "room"]:
		ck(played[key] == skipped[key], "%s: skipped %s == played (%s vs %s)" % [beat, key, skipped[key], played[key]])
	for actor in played.positions:
		var gap: float = (played.positions[actor] as Vector2).distance_to(skipped.positions[actor])
		ck(gap < 2.0, "%s: %s ends where it does when played (gap %.1f: %s vs %s)" % [beat, actor, gap, skipped.positions[actor], played.positions[actor]])

func _key(pressed: bool) -> InputEvent:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.keycode = KEY_TAB
	ev.pressed = pressed
	return ev

func _pad_y(pressed: bool) -> InputEvent:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_Y
	ev.pressed = pressed
	return ev

## Справжнє утримання кнопки пропуску: HUD сховано, підказка показує цю кнопку й заповнюється; після секунди — пропуск.
func _hold_skip(press: InputEvent, release: InputEvent, glyph: String, beat: String) -> void:
	await _until(func() -> bool: return _prompt() != null, 8.0)
	ck(_prompt() != null, "%s: the skip prompt shows during the cutscene" % beat)
	ck(not _hud_visible(), "%s: HUD hidden during the cutscene" % beat)
	Input.parse_input_event(press)
	await process_frame
	var label: Label = _prompt().get_node(^"%SkipLabel")
	var fill: ProgressBar = _prompt().get_node(^"%SkipFill")
	ck(label.text.contains(glyph), "%s: prompt names %s (%s)" % [beat, glyph, label.text])
	await create_timer(0.5, true, false, true).timeout
	ck(fill.value > 0.2 and fill.value < 0.9, "%s: half a second fills the bar halfway (%.2f)" % [beat, fill.value])
	ck(not _prompt().skipping, "%s: no skip before the hold time" % beat)
	await create_timer(0.7, true, false, true).timeout
	ck(_prompt() == null or _prompt().skipping, "%s: a full second's hold skips" % beat)
	Input.parse_input_event(release)

## Сцена двічі з одного стану: [param start] запускає її, [param done] — її кінець; [param actors] — чиї позиції звірити.
func _play_and_skip(beat: String, start: Callable, done: Callable, actors: Array[NodePath],
		press: InputEvent, release: InputEvent, glyph: String) -> void:
	var before := _snap([])
	await start.call()
	ck(game.player.event, "%s: the cutscene takes the input" % beat)
	await _until(func() -> bool: return _prompt() != null, 8.0)
	ck(not _hud_visible(), "%s: HUD hidden while it plays" % beat)
	var deadline := Time.get_ticks_msec() + 30000
	while not done.call() and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active() and not dm.is_bubble_playing():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
	ck(done.call(), "%s: played to the end" % beat)
	for i in 30: await physics_frame  # герой після телепорту долітає до землі
	var played := _snap(actors)
	ck(_hud_visible() and _prompt() == null, "%s: HUD back, prompt gone after the played cutscene" % beat)
	await _drain()

	_restore(before)
	await start.call()
	var t0 := Time.get_ticks_msec()
	await _hold_skip(press, release, glyph, beat)
	await _until(done, 15.0)
	ck(done.call(), "%s: skipped to the end (%.1f s)" % [beat, (Time.get_ticks_msec() - t0) / 1000.0])
	for i in 30: await physics_frame
	var skipped := _snap(actors)
	ck(_hud_visible() and _prompt() == null, "%s: HUD back, prompt gone after the skip" % beat)
	ck(is_equal_approx(Engine.time_scale, 1.0), "%s: normal speed after the skip (%.1f)" % [beat, Engine.time_scale])
	_same(played, skipped, beat)
	await _drain()
	ck(not game.player.event, "%s: control back" % beat)

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0  # облачка (D178) без очікування
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()  # вступ Canyon
	ck(InputMap.has_action(&"cutscene_skip"), "cutscene_skip action registered (Tab / pad Y)")

	print("[0] A cutscene that starts mid-air lands the hero before its first line (B123)")
	game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 30: await physics_frame
	game.player.global_position = Vector2(560, 360)
	for i in 30: await physics_frame
	ck(game.player.is_on_floor(), "the hero stands at the gates before the jump")
	var ground_y: float = game.player.global_position.y
	game.player.global_position.y -= 160.0
	for i in 3: await physics_frame
	ck(not game.player.is_on_floor(), "the hero is in the air when the cutscene starts")
	var on_floor_at_line: Array[bool] = []
	var at_line := func(_id: String) -> void: on_floor_at_line.append(game.player.is_on_floor())
	dm.dialogue_started.connect(at_line)
	var cs: RefCounted = load("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd").new()  # не preload: скрипт кличе автозавантаження
	ck(cs.landing, "the cutscene lets him land first")
	dm.start_dialogue("res://dialogue_quest/CityGates_Raid.dqd")  # як Canyon_ExitCutscene: розмова не через cs.say
	ck(not dm.is_dialogue_active(), "the line waits while he falls")
	await _until(func() -> bool: return not on_floor_at_line.is_empty(), 4.0)
	dm.dialogue_started.disconnect(at_line)
	ck(on_floor_at_line == [true], "he is on the floor when the first line shows (%s)" % [on_floor_at_line])
	ck(absf(game.player.global_position.y - ground_y) < 2.0, "he landed on the ground, not hanging (%.0f vs %.0f)" % [game.player.global_position.y, ground_y])
	ck(game.player.event, "input stays off: the cutscene holds him")
	await _drain()
	cs.end()
	for i in 10: await physics_frame
	ck(not game.player.event and _prompt() == null, "the cutscene ends and control comes back")

	print("[1] City Gates raid: hold Tab")
	var raid_start := func() -> void:
		await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
		for i in 30: await physics_frame
		game.player.global_position = Vector2(560, 360)
		for i in 30: await physics_frame
		Input.action_press(&"move_right")
		await _until(func() -> bool: return game.player.event, 4.0)
		Input.action_release(&"move_right")
	var bandits: Array[NodePath] = []
	await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	for i in 10: await physics_frame
	for bandit in game.map.get_node(^"Raid/Bandits").get_children():
		bandits.append(NodePath("Raid/Bandits/" + bandit.name))
	await _play_and_skip("raid", raid_start,
			func() -> bool: return game.map.get_current_state_name() == "FIGHT_LOOP", bandits, _key(true), _key(false), "Tab")

	print("[2] Merchant arrival on the Desert Road (NpcArrival): hold pad Y")
	for f: String in ["canyon_exit_complete", "desert_road_fight_complete"]:
		game.set_quest_flag(f, true)
	var merchant_start := func() -> void:
		await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
		for i in 30: await physics_frame
		game.player.global_position = Vector2(700, 360)
		for i in 20: await physics_frame
		Input.action_press(&"move_right")
		await _until(func() -> bool: return game.player.event, 8.0)
		Input.action_release(&"move_right")
	await _play_and_skip("merchant", merchant_start,
			func() -> bool: return game.get_quest_flag("desert_road_merchant_met") and not game.player.event,
			[^"Merchant"], _pad_y(true), _pad_y(false), "Y")

	print("[3] Canyon descent (ends after a teleport): hold Tab")
	var all: Dictionary = game.get_quest_flags().duplicate()
	all.merge({"canyon_abduction_complete": true, "village_abduction_complete": true, "village_arrival_complete": true,
			"village_fight_complete": true, "village_left_complete": true}, true)
	game.set_quest_flags(all)
	var descent_start := func() -> void:
		await game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
		for i in 20: await process_frame
		game.player.global_position = Vector2(1000, 370)
		for i in 30: await process_frame
		Input.action_press(&"move_left")
		await _until(func() -> bool: return game.player.event, 5.0)
		Input.action_release(&"move_left")
	var before_descent := _snap([])
	await _play_and_skip("descent", descent_start,
			func() -> bool: return game.map.scene_file_path.ends_with("DesertRoad.tscn") and not game.player.event,
			[], _key(true), _key(false), "Tab")

	print("[4] Quit to the main menu mid-cutscene, then a new game (B92)")
	_restore(before_descent)
	await descent_start.call()
	await _until(func() -> bool: return _prompt() != null, 8.0)
	ck(_prompt() != null and not _hud_visible(), "descent is playing")
	root.get_node("ServiceLocator").get_ui_manager().close_state()
	set_meta("show_title_screen", true)
	change_scene_to_file("res://SampleProject/MainMenu.tscn")
	for i in 30: await process_frame
	ck(_prompt() == null, "the skip prompt left with its game")
	ck(is_equal_approx(Engine.time_scale, 1.0), "normal speed in the main menu (%.1f)" % Engine.time_scale)
	var started: Array[String] = []
	var count_started := func(id: String) -> void: started.append(id)
	dm.dialogue_started.connect(count_started)  # саме dialogue_started кликав hold() на звільненому герої
	set_meta("start_new_game", true)
	change_scene_to_file("res://SampleProject/Game.tscn")
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path.ends_with("Game.tscn") \
			and current_scene.player != null, 10.0)
	game = current_scene
	await _until(func() -> bool: return not started.is_empty(), 10.0)
	dm.dialogue_started.disconnect(count_started)
	ck(not started.is_empty(), "the new game's first dialogue runs (%s)" % [started])
	await _drain()
	for i in 30: await process_frame
	ck(_hud_visible() and _prompt() == null, "the new game's intro ends with the HUD back")
	ck(not game.player.event, "the new game's intro gives control back")

	print("[5] The next cutscene in the new game hides and shows the HUD again (B92)")
	await _play_and_skip("raid after a new game", raid_start,
			func() -> bool: return game.map.get_current_state_name() == "FIGHT_LOOP", bandits, _key(true), _key(false), "Tab")

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
