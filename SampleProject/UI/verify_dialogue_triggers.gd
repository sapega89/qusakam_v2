extends SceneTree

## Розмови й тригери (Sapega, 2026-10-26: «діалоги блокують тригери», «діалоговий текст довго викатується»,
## «автоматично показувати нову сторінку діалогу через 1-2 секунди»): D737 / B154, D738, D739.
##   1. Тригер, у який герой зайшов посеред розмови сюжету, спрацьовує після неї; два — по черзі.
##      Подія входу (зона бою) після розмови: герой ще в зоні — спрацьовує, вийшов — зона знову чекає входу.
##   2. Розмова сюжету (вікно й монолог облачком) тримає героя; репліка мимохідь (барк) — ні, і тригер посеред
##      неї спрацьовує одразу.
##   3. D738: набір 48 літер/с; клік, Enter і A посеред набору показують усю репліку, у вікні й в облачку розмови.
##   4. D739: набрана репліка йде далі сама після паузи; Auto-Advance Off — ні; вибір чекає гравця.
##   godot --headless --path . --script res://SampleProject/UI/verify_dialogue_triggers.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_story_busy():
				break
			if dm.is_dialogue_active():
				dm.current_dialogue_box.finish()  # тест не чекає набору репліки
				dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_story_busy():
			return


func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _wait(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		await process_frame


## Натискання й відпускання справжньої кнопки (подія йде через InputMap → dq_accept).
func _tap(event: InputEvent) -> void:
	event.set(&"pressed", true)
	Input.parse_input_event(event)
	for i in 3: await process_frame
	var up: InputEvent = event.duplicate()
	up.set(&"pressed", false)
	Input.parse_input_event(up)
	for i in 3: await process_frame


func _enter_key() -> InputEvent:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	return key


func _left_click() -> InputEvent:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(root.size) * 0.5
	click.global_position = click.position
	return click


func _pad_a() -> InputEvent:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	return pad


## Тригер сюжету (лише діалог) у кімнаті, як ті, що стоять у сценах.
func _trigger(game: Node, dialogue_id: String) -> StateChangeTrigger:
	var trigger := StateChangeTrigger.new()
	trigger.dialogue_id = dialogue_id
	trigger.action_mode = StateChangeTrigger.ActionMode.DIALOGUE_ONLY
	game.map.add_child(trigger)
	trigger.owner = game.map
	return trigger


## Зона з колізією навколо [param at], що бачить героя.
func _zone(game: Node, at: Vector2) -> Area2D:
	var area := Area2D.new()
	area.collision_mask = game.player.collision_layer
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 64)
	shape.shape = rect
	area.add_child(shape)
	game.map.add_child(area)
	area.global_position = at
	return area


func _moves(player: Node2D) -> float:
	var x := player.global_position.x
	Input.action_press(&"move_right")
	for i in 20: await process_frame
	Input.action_release(&"move_right")
	for i in 5: await process_frame
	return absf(player.global_position.x - x)


func _initialize() -> void:
	await process_frame
	var settings: Node = root.get_node("SaveSystem").settings_module
	settings.settings.tutorial_windows = false
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon
	for i in 30: await process_frame
	await _drain(dm)
	var player: Node2D = game.player
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[1] A trigger entered during a story dialogue fires after it, in order (D737, B154)")
	settings.settings.auto_advance = false  # розмову гортає тест
	var first := _trigger(game, "RoadToVillage")
	var second := _trigger(game, "LeavingVillage")
	dm.start_dialogue("res://dialogue_quest/ArrivalToVillage.dqd")
	for i in 3: await process_frame
	ck(dm.is_dialogue_active() and dm.is_story_busy(), "a story dialogue runs")
	first._on_body_entered(player)
	second._on_body_entered(player)
	first._on_body_entered(player)  # другий вхід у ту саму зону — не другий запуск
	for i in 5: await process_frame
	ck(not first.has_triggered and not second.has_triggered and started == ["ArrivalToVillage"],
			"nothing fires in the middle of the dialogue (%s)" % [started])
	await _drain(dm)
	await _until(func() -> bool: return started.size() >= 3 and not dm.is_story_busy(), 5.0)
	ck(first.has_triggered and second.has_triggered, "both triggers fired after the dialogue")
	ck(started == ["ArrivalToVillage", "RoadToVillage", "LeavingVillage"], "in the order they were entered, one after another (%s)" % [started])

	print("[1b] An enter event (combat zone) after the dialogue: still inside fires, left re-arms")
	var inside := _zone(game, player.global_position)
	var outside := _zone(game, player.global_position + Vector2(0, -2000))
	for i in 4: await physics_frame
	var events: Array[String] = []
	dm.start_dialogue("res://dialogue_quest/ArrivalToVillage.dqd")
	for i in 3: await process_frame
	dm.when_story_free_inside(inside, func() -> void: events.append("inside fired"), func() -> void: events.append("inside re-armed"))
	dm.when_story_free_inside(outside, func() -> void: events.append("outside fired"), func() -> void: events.append("outside re-armed"))
	ck(events.is_empty(), "both wait for the dialogue")
	await _drain(dm)
	for i in 5: await process_frame
	ck(events == ["inside fired", "outside re-armed"], "the hero still inside → fires; outside → re-armed (%s)" % [events])
	inside.queue_free()
	outside.queue_free()

	print("[2] A story dialogue holds the hero, a bark does not")
	started.clear()
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	for i in 3: await process_frame
	ck(player.event, "the dialogue window holds the hero")
	var moved: float = await _moves(player)
	ck(moved < 1.0, "move_right does nothing during the dialogue (dx %.1f)" % moved)
	await _drain(dm)
	dm.bubble_time_scale = 1.0  # монолог триває справжні секунди
	dm.start_dialogue("res://dialogue_quest/LeavingVillage.dqd")
	for i in 3: await process_frame
	ck(dm.is_bubble_playing() and player.event, "a story monologue (bubble) holds the hero too (was free, D178)")
	moved = await _moves(player)
	ck(moved < 1.0, "move_right does nothing during the monologue (dx %.1f)" % moved)
	dm.bubble_time_scale = 0.0
	await _until(func() -> bool: return not dm.is_bubble_playing(), 30.0)
	for i in 5: await process_frame
	ck(not player.event, "the hero is free after the monologue")
	var speaker := Node2D.new()
	game.map.add_child(speaker)
	speaker.global_position = player.global_position + Vector2(200, 0)
	dm.bubble_time_scale = 1.0
	ck(dm.say_in_passing(speaker, "res://dialogue_quest/Smith_Bark.dqd", Vector2(0, -60)), "a bark starts")
	ck(not dm.is_story_busy() and not player.event, "a bark is not a story dialogue and holds nobody")
	moved = await _moves(player)
	ck(dm.chatter_bubble(speaker) != null and moved > 1.0, "the hero walks while the bark is up (dx %.1f)" % moved)
	var during_bark := _trigger(game, "RoadToVillage")
	started.clear()
	during_bark._on_body_entered(player)
	for i in 3: await process_frame
	ck(during_bark.has_triggered and started == ["RoadToVillage"], "a trigger during a bark fires at once (%s)" % [started])
	dm.bubble_time_scale = 0.0
	await _until(func() -> bool: return not dm.is_story_busy(), 10.0)
	speaker.queue_free()

	print("[3] D738: faster typing; a click, Enter or pad A while a line types shows it whole")
	var box: Node = dm.current_dialogue_box
	ck(is_equal_approx(box.settings.letters_per_second, UITokens.DIALOGUE_LETTERS_PER_SECOND) and UITokens.DIALOGUE_LETTERS_PER_SECOND >= 48.0,
			"the box types %.0f letters/s (was 24)" % box.settings.letters_per_second)
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	for i in 3: await process_frame
	var line1: String = box.get_text()
	ck(not box.is_finished(), "line 1 is typing")
	await _tap(_left_click())
	ck(box.is_finished() and box.get_text() == line1, "a left click shows the whole line at once")
	await _tap(_enter_key())
	ck(box.get_text() != line1 and not box.is_finished(), "the next press goes to line 2, which types")
	var line2: String = box.get_text()
	await _tap(_enter_key())
	ck(box.is_finished() and box.get_text() == line2, "Enter shows the whole line at once")
	await _tap(_pad_a())
	ck(box.get_text() != line2, "pad A goes on to line 3")
	if not box.is_finished():
		await _tap(_pad_a())
		ck(box.is_finished(), "pad A shows the whole line at once")
	await _drain(dm)
	dm.bubble_time_scale = 1.0
	dm.start_dialogue("res://dialogue_quest/Canyon_AbductionCutscene.dqd", true)
	var found: Array[Node2D] = []  # лямбда не міняє локальних змінних — лише вміст масиву
	await _until(func() -> bool:
		for child in player.get_children():
			if child.has_method(&"finish_typing") and not found.has(child):
				found.append(child)
		return not found.is_empty() and found[0].is_typing(), 3.0)
	var cloud: Node2D = found[0] if not found.is_empty() else null
	ck(cloud != null and cloud.is_typing(), "a cloud talk line is typing")
	await _tap(_left_click())
	ck(cloud != null and cloud.is_typed(), "a left click shows the whole cloud line at once")
	dm.bubble_time_scale = 0.0
	for i in 30:
		if not dm.is_bubble_playing(): break
		await _tap(_enter_key())
	ck(not dm.is_bubble_playing(), "the cloud talk ends")
	await _drain(dm)

	print("[4] D739: a typed line goes on by itself; Off — it waits; a choice waits")
	settings.settings.auto_advance = true
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	for i in 3: await process_frame
	line1 = box.get_text()
	box.finish()
	var delay: float = box.auto_advance_delay(line1)
	ck(delay >= UITokens.DIALOGUE_AUTO_MIN and delay <= UITokens.DIALOGUE_AUTO_MAX, "the pause is %.2f s (%.1f..%.1f)" % [delay, UITokens.DIALOGUE_AUTO_MIN, UITokens.DIALOGUE_AUTO_MAX])
	await _wait(delay * 0.5)
	ck(box.get_text() == line1, "half the pause in: still line 1")
	await _wait(delay * 0.5 + 0.4)
	ck(box.get_text() != line1 and dm.is_dialogue_active(), "after the pause: line 2 by itself")
	settings.settings.auto_advance = false
	line2 = box.get_text()
	box.finish()
	await _wait(UITokens.DIALOGUE_AUTO_MAX + 0.5)
	ck(box.get_text() == line2, "Auto-Advance Off: the line waits for a press")
	settings.settings.auto_advance = true
	await _drain(dm)
	var sections: Array[DQDqdParser.DqdSection] = DQDqdParser.parse_from_text("say|KUSAKAM|Pick one.\nchoice|Yes|No\nexit|\n")
	dm._find_dialogue_system_in_scene()
	box.visible = true
	dm.current_dialogue_player.play_sections(sections, "res://dialogue_quest/verify_choice")
	for i in 3: await process_frame
	box.finish()
	var choice_menu: Control = dm.current_dialogue_player.choice_menu
	await _until(func() -> bool: return choice_menu.visible, UITokens.DIALOGUE_AUTO_MAX + 1.0)
	ck(choice_menu.visible, "the line before a choice goes on by itself to the choice")
	await _wait(UITokens.DIALOGUE_AUTO_MAX + 1.0)
	ck(choice_menu.visible and dm.is_dialogue_active(), "the choice waits for the player")
	choice_menu.choice_made.emit("Yes")
	for i in 10: await process_frame
	ck(not dm.is_dialogue_active(), "a picked choice ends the test dialogue")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
