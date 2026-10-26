extends SceneTree

## Геймпад, зріз 1 ([[gamepad_plan]], D156): у кожної ігрової дії є кнопка пада; справжні події пада
## (Input.parse_input_event) рухають героя, стрибають і бʼють; B у грі меню не відкриває, Start
## відкриває, B закриває; у модалці A підтверджує, B скасовує.
##   godot --headless --path . --script res://SampleProject/UI/verify_gamepad.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Кнопки пада дії (індекси) і чи є вісь стіка.
func _pad_buttons(action: StringName) -> Array:
	var out: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			out.append(ev.button_index)
	return out

func _has_axis(action: StringName, axis: int, sign_value: float) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axis and signf(ev.axis_value) == sign_value:
			return true
	return false

func _press(button: int, pressed: bool = true) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tap(button: int) -> void:
	_press(button)
	await process_frame
	await process_frame
	_press(button, false)
	await process_frame

func _stick_x(value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = value
	Input.parse_input_event(ev)

func _drain(dm: Node) -> void:
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
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	await process_frame

	print("[1] The D156 layout is in the input map")
	ck(_has_axis(&"move_left", JOY_AXIS_LEFT_X, -1) and _has_axis(&"move_right", JOY_AXIS_LEFT_X, 1), "left stick moves left / right")
	ck(JOY_BUTTON_DPAD_UP in _pad_buttons(&"move_up") and JOY_BUTTON_DPAD_DOWN in _pad_buttons(&"move_down"), "D-pad up / down on move_up / move_down")
	ck(_pad_buttons(&"jump") == [JOY_BUTTON_A], "A jumps")
	ck(_pad_buttons(&"attack") == [JOY_BUTTON_X], "X attacks")
	ck(_pad_buttons(&"interact") == [JOY_BUTTON_Y], "Y interacts (moved off A)")
	ck(JOY_BUTTON_A in _pad_buttons(&"ui_accept") and JOY_BUTTON_B in _pad_buttons(&"ui_cancel"), "A confirms, B goes back in menus")
	ck(_pad_buttons(&"game_menu") == [JOY_BUTTON_START], "Start opens the Game Menu")
	ck(JOY_BUTTON_START not in _pad_buttons(&"ui_cancel") and JOY_BUTTON_B not in _pad_buttons(&"game_menu"), "B is not the menu button")
	ck(JOY_BUTTON_A in _pad_buttons(&"dq_accept"), "A turns dialogue lines (dq_accept) — without it a pad player is stuck in every dialogue")
	for action in [&"dodge", &"assist"]:  # D475: перемикання зброї немає, D-pad ←→ вільні
		ck(not _pad_buttons(action).is_empty() or _has_axis(action, JOY_AXIS_TRIGGER_LEFT, 1), "%s has a pad input" % action)

	print("[2] Real pad events drive the hero")
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	var player: Node = game.player
	for i in 20: await physics_frame
	var x0: float = player.global_position.x
	_stick_x(1.0)
	for i in 20: await physics_frame
	_stick_x(0.0)
	ck(player.global_position.x > x0 + 20.0, "left stick right → the hero runs right (%.0f px)" % (player.global_position.x - x0))
	for i in 10: await physics_frame
	_press(JOY_BUTTON_A)
	var rose := false
	for i in 6:
		await physics_frame
		rose = rose or player.velocity.y < 0.0
	_press(JOY_BUTTON_A, false)
	ck(rose, "A → the hero jumps")
	for i in 180:  # приземлитися: у повітрі Player перебиває атаку анімацією Fall
		await physics_frame
		if player.is_on_floor() and player.velocity.y == 0.0:
			break
	for i in 5: await physics_frame
	_press(JOY_BUTTON_X)
	var attacked := false
	for i in 4:  # parse_input_event доходить на наступному кадрі
		await process_frame
		attacked = attacked or player.combat.is_attacking
	ck(attacked, "X → the hero attacks")
	_press(JOY_BUTTON_X, false)
	await create_timer(0.6).timeout

	print("[3] Menu: B does not open it in the game, Start does, B closes it")
	var mm: Node = sl.get_menu_manager()
	await _tap(JOY_BUTTON_B)
	ck(not mm.is_menu_open(), "B in the game does nothing")
	await _tap(JOY_BUTTON_START)
	for i in 10: await process_frame
	ck(mm.is_menu_open(), "Start opens the Game Menu")
	await _tap(JOY_BUTTON_B)
	for i in 10: await process_frame
	ck(not mm.is_menu_open(), "B closes it")

	print("[4] Modal: A confirms, B cancels")
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	var results: Array = []
	layer.modal_closed.connect(func(r: String) -> void: results.append(r))
	sl.get_ui_manager().show_modal({"title": "Pad test", "description": "", "confirm_text": "OK", "cancel_text": "Cancel"})
	for i in 6: await process_frame
	layer.active_modal.confirm_button.grab_focus()
	await process_frame
	await _tap(JOY_BUTTON_A)
	for i in 4: await process_frame
	ck(results == ["confirm"], "A presses the focused OK (%s)" % [results])
	sl.get_ui_manager().show_modal({"title": "Pad test", "description": "", "confirm_text": "OK", "cancel_text": "Cancel"})
	for i in 6: await process_frame
	await _tap(JOY_BUTTON_B)
	for i in 4: await process_frame
	ck(results == ["confirm", "cancel"] and layer.active_modal == null, "B cancels the modal (%s)" % [results])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
