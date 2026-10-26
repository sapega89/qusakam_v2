extends SceneTree

## Курсор у грі (D157 → D417, gamepad_plan slice 1b, GitHub #36).
##   godot --headless --path . --script res://SampleProject/UI/verify_mouse_cursor.gd
##
## У грі курсор схований; Alt (toggle_mouse) показує / ховає; Game Menu і модалка завжди з курсором,
## після закриття — знову стан Alt; схований курсор не натискає й не наводить GUI, а ЛКМ і далі б'є.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var _probe_pressed: int = 0
var _probe_hovered: int = 0
var _attacks: int = 0


func _alt() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ALT
		ev.physical_keycode = KEY_ALT
		ev.pressed = pressed
		root.push_input(ev)


func _move_to(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(1, 1)
	root.push_input(ev)


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	root.size = Vector2i(1920, 1080)
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var ui: Node = sl.get_ui_manager()
	var cursor: Node = game.get_node(^"MouseCursor")
	root.get_node("EventBus").player_attacked.connect(func(_p: Node, _d: int) -> void: _attacks += 1)

	print("[1] toggle_mouse is Alt (D417), not Ctrl (block, D270)")
	var keys: Array[int] = []
	for ev in InputMap.action_get_events(&"toggle_mouse"):
		if ev is InputEventKey:
			keys.append((ev as InputEventKey).physical_keycode)
	ck(keys == [KEY_ALT], "toggle_mouse = Alt (%s)" % str(keys))

	print("[2] in play the cursor is hidden; Alt shows and hides it")
	ck(not paused and not ui.is_ui_active(), "in play, nothing paused")
	ck(not cursor.cursor_visible, "cursor hidden at start")
	_alt()
	await process_frame
	ck(cursor.cursor_visible and cursor.shown_by_player, "Alt shows it")
	_alt()
	await process_frame
	ck(not cursor.cursor_visible and not cursor.shown_by_player, "Alt again hides it")

	print("[3] a hidden cursor never presses or hovers the GUI; LMB still attacks")
	var layer := CanvasLayer.new()
	layer.layer = 100  # HUD шари нижче 128 — щит над ними
	root.add_child(layer)
	var probe := Button.new()
	probe.text = "probe"
	probe.position = Vector2(860, 500)
	probe.size = Vector2(200, 80)
	probe.focus_mode = Control.FOCUS_ALL
	layer.add_child(probe)
	probe.pressed.connect(func() -> void: _probe_pressed += 1)
	# Те саме, що роблять game_menu.gd, misc_menu_modal.gd, MainMenu.gd… — фокус на наведення.
	probe.mouse_entered.connect(func() -> void:
		_probe_hovered += 1
		probe.grab_focus())
	await process_frame
	var centre: Vector2 = probe.get_global_rect().get_center()
	var attacks_before: int = _attacks
	_move_to(centre)
	await process_frame
	_click(centre)
	for i in 30: await physics_frame
	ck(_probe_hovered == 0, "no mouse_entered under a hidden cursor (%d)" % _probe_hovered)
	ck(not probe.has_focus(), "no hover focus")
	ck(_probe_pressed == 0, "the button under the hidden cursor is not pressed (%d)" % _probe_pressed)
	ck(_attacks > attacks_before, "LMB still attacks (player_attacked %d → %d)" % [attacks_before, _attacks])

	print("[4] Alt on: the same click reaches the GUI (the probe is real)")
	_alt()
	await process_frame
	_move_to(centre + Vector2(2, 2))
	await process_frame
	_click(centre + Vector2(2, 2))
	await process_frame
	ck(_probe_hovered >= 1 and probe.has_focus(), "hover focus works with the cursor shown")
	ck(_probe_pressed == 1, "button pressed with the cursor shown (%d)" % _probe_pressed)
	_alt()
	await process_frame
	layer.queue_free()
	for i in 30: await physics_frame  # удар закінчився — меню відкривається

	print("[5] the Game Menu always has the cursor; closing it restores the Alt state")
	ck(not cursor.cursor_visible, "hidden before the menu")
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group(&"game_menu")
	ck(menu != null and paused, "game menu open, game paused")
	ck(cursor.cursor_visible, "cursor shown in the Game Menu without Alt")
	_alt()
	await process_frame
	ck(cursor.cursor_visible and not cursor.shown_by_player, "Alt inside the menu does not change the play state")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	menu._unhandled_input(esc)
	for i in 8: await process_frame
	ck(get_first_node_in_group(&"game_menu") == null and not paused, "menu closed")
	ck(not cursor.cursor_visible, "hidden again after the menu (Alt state: off)")
	_alt()
	await process_frame
	ui.open_game_menu()
	for i in 14: await process_frame
	menu = get_first_node_in_group(&"game_menu")
	menu._unhandled_input(esc)
	for i in 8: await process_frame
	ck(cursor.cursor_visible, "still shown after the menu (Alt state: on)")
	_alt()
	await process_frame

	print("[6] a modal always has the cursor")
	var layer_modal: Node = ui.get_modal_layer()
	ui.show_modal({"title": "Probe", "description": "", "confirm_text": "OK", "cancel_text": "Cancel"})
	for i in 4: await process_frame
	ck(layer_modal.active_modal != null, "modal open")
	ck(cursor.cursor_visible, "cursor shown over the modal")
	layer_modal._close_with_result("confirm")
	for i in 4: await process_frame
	ck(layer_modal.active_modal == null and not cursor.cursor_visible, "hidden again after the modal")

	print("[7] leaving the game gives the cursor back")
	game.queue_free()
	for i in 3: await process_frame
	ck(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or DisplayServer.get_name() == "headless",
			"Input.mouse_mode visible outside the game")
	ck(FileAccess.get_file_as_string("res://SampleProject/Scripts/UI/mouse_cursor.gd").find("MOUSE_MODE_VISIBLE") != -1,
			"_exit_tree restores MOUSE_MODE_VISIBLE")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
