extends SceneTree

## Куди НАСПРАВДІ ведуть 4 пункти Misc. Доповнює verify_misc_modal.gd, який
## перевіряє Tutorial і Exit пошуком рядка у вихідному коді (B4), а не натисканням.
##   godot --headless --path . --script res://SampleProject/UI/verify_misc_destinations.gd

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _open(ui: Node, menu: Node) -> Node:
	menu.misc_button.pressed.emit()
	for i in 10: await process_frame
	return ui.get_modal_layer().active_modal


## Справжній клік мишею через viewport — на відміну від pressed.emit() проходить
## mouse_filter, порядок дерева й перекриття. Саме тут живуть баги «не реагує».
func _click(node: Control) -> void:
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	for i in 8: await process_frame


func _initialize() -> void:
	await process_frame
	await process_frame
	# Меню існує лише в запущеній грі (Game, гравець, нижня панель) — тест відкриває його там само.
	set_meta("start_new_game", true)
	var boot_game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(boot_game)
	current_scene = boot_game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var intro_dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	var layer: Node = ui.get_modal_layer()
	var scene_before: String = current_scene.scene_file_path if current_scene else "<none>"
	print("scene before: %s" % scene_before)

	print("[1] Settings")
	var modal: Node = await _open(ui, menu)
	modal.settings_button.pressed.emit()
	for i in 10: await process_frame
	print("    tab=%s  scene=%s" % [menu.current_tab_name,
			current_scene.scene_file_path if current_scene else "<none>"])
	ck(menu.current_tab_name == "Misc", "Settings lands on the Misc tab")

	print("[2] Exit to Main Menu — expect a confirmation modal, not an instant exit")
	modal = await _open(ui, menu)
	modal.exit_main_menu_button.pressed.emit()
	for i in 10: await process_frame
	var confirm: Node = layer.active_modal
	print("    active_modal=%s  scene=%s" % [confirm,
			current_scene.scene_file_path if current_scene else "<none>"])
	ck(confirm != null, "Exit to Main Menu opens a confirmation modal")
	ck(current_scene == null or current_scene.scene_file_path == scene_before,
			"Exit to Main Menu did not change scene before confirming")
	if confirm and confirm.has_signal("cancelled"):
		confirm.cancelled.emit()
	for i in 10: await process_frame

	print("[3] MOUSE path — same buttons, real click events, not pressed.emit()")
	modal = await _open(ui, menu)
	ck(modal != null, "modal open before the mouse test")
	if modal:
		var before_tab: String = menu.current_tab_name
		menu.switch_to_tab("Inventory")
		for i in 6: await process_frame
		print("    tab parked at: %s" % menu.current_tab_name)
		var btn: Control = modal.settings_button
		var vp: Viewport = btn.get_viewport()
		print("    viewport size: %s" % vp.get_visible_rect().size)
		print("    button global rect: %s  visible_in_tree=%s  disabled=%s"
				% [btn.get_global_rect(), btn.is_visible_in_tree(), btn.disabled])
		print("    button mouse_filter=%d  modal mouse_filter=%d"
				% [btn.mouse_filter, modal.mouse_filter])
		var probe := InputEventMouseMotion.new()
		probe.position = btn.get_global_rect().get_center()
		probe.global_position = probe.position
		vp.push_input(probe)
		await process_frame
		var hovered: Control = vp.gui_get_hovered_control()
		print("    hovered control under that point: %s" % hovered)
		print("    tree paused=%s" % paused)
		var n: Node = btn
		while n:
			print("    can_process=%s process_mode=%d  %s"
					% [n.can_process(), n.process_mode, n.get_path()])
			n = n.get_parent()
		if hovered and hovered != btn:
			print("    ^ BLOCKER: %s at %s, mouse_filter=%d"
					% [hovered.get_path(), hovered.get_global_rect(), hovered.mouse_filter])
		await _click(btn)
		print("    after mouse click: active_modal=%s  tab=%s"
				% [layer.active_modal, menu.current_tab_name])
		ck(layer.active_modal == null, "mouse click closed the modal")
		ck(menu.current_tab_name == "Misc", "mouse click reached Settings (tab=%s)"
				% menu.current_tab_name)
		if before_tab:
			pass

	print("[4] PROOF — same click after UIRoot stops being pausable")
	var ui_root: Node = root.get_node_or_null(
			"GameManager/UIManager/UIRoot")
	if ui_root:
		ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 6: await process_frame
		modal = layer.active_modal
		if modal == null:
			modal = await _open(ui, menu)
		menu.switch_to_tab("Inventory")
		for i in 6: await process_frame
		print("    can_process now: %s" % modal.settings_button.can_process())
		await _click(modal.settings_button)
		print("    after mouse click: active_modal=%s  tab=%s"
				% [layer.active_modal, menu.current_tab_name])
		ck(layer.active_modal == null, "FIX: mouse click closes the modal")
		ck(menu.current_tab_name == "Misc", "FIX: mouse click reaches Settings")

	print("[4b] Escape closes the Misc sub-menu, not the whole Game Menu")
	modal = await _open(ui, menu)
	ck(modal != null, "Misc sub-menu open")
	for down in [true, false]:
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = down
		root.push_input(esc)
		await process_frame
	for i in 8: await process_frame
	ck(layer.active_modal == null, "Escape closed the Misc sub-menu")
	ck(get_first_node_in_group("game_menu") != null, "the Game Menu stays open behind it")

	print("[5] Exit to Main Menu, confirmed — lands on a LIVE main menu")
	modal = await _open(ui, menu)
	modal.exit_main_menu_button.pressed.emit()
	for i in 10: await process_frame
	confirm = layer.active_modal
	ck(confirm != null and confirm.has_signal("chosen"), "confirmation modal open")
	if confirm:
		confirm.chosen.emit("confirm")
	for i in 30: await process_frame
	var landed: String = current_scene.scene_file_path if current_scene else "<none>"
	print("    scene=%s  paused=%s" % [landed, paused])
	ck(landed.ends_with("MainMenu.tscn"), "landed on MainMenu (%s)" % landed)
	ck(not paused, "main menu is not frozen by the game's pause")
	var left_menu: Node = get_first_node_in_group("game_menu")
	ck(left_menu == null or not left_menu.is_visible_in_tree(), "the Game Menu is not left open over the title screen")
	ck(current_scene.is_title_screen_mode and current_scene.press_any_button_container.visible, "the title screen shows straight away")
	# Ігровий UI (UIManager) переживає зміну сцени — його повноекранний StateRoot
	# не має забирати мишу в головного меню.
	var new_game_button: Control = current_scene.menu.get_node("new_game")
	current_scene.menu.visible = true
	await process_frame
	var hover := InputEventMouseMotion.new()
	hover.position = new_game_button.get_global_rect().get_center()
	root.push_input(hover)
	await process_frame
	ck(root.gui_get_hovered_control() == new_game_button, "the mouse reaches New Game (%s)" % root.gui_get_hovered_control())

	print("[6] Tutorial — a full-screen window over the menu, never a scene swap (B2, D126)")
	# З головного меню гравець заходить у нову гру — меню відкривається вже там.
	set_meta("start_new_game", true)
	var game6: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game6)
	current_scene = game6
	for i in 40: await process_frame
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	ui.open_game_menu()
	for i in 16: await process_frame
	menu = get_first_node_in_group("game_menu")
	layer = ui.get_modal_layer()
	var before6: String = current_scene.scene_file_path if current_scene else "<none>"
	ck(menu != null, "game menu reopened for the tutorial check")
	if menu:
		modal = await _open(ui, menu)
		modal.tutorial_button.pressed.emit()
		for i in 10: await process_frame
	var after6: String = current_scene.scene_file_path if current_scene else "<none>"
	ck(after6 == before6, "the running scene stays loaded (B2)")
	var topics_panel: Node = menu.get_node("%TutorialComponent") if menu else null
	ck(topics_panel != null and topics_panel.is_visible_in_tree(), "topic list shown in the centre of the Game Menu")
	ck(menu != null and menu.current_tab_name == "Misc", "Misc stays the selected tab")
	var rows: Array = topics_panel.get_node("%TopicList").get_children().filter(func(r): return r.visible) if topics_panel else []
	ck(rows.map(func(r): return r.text) == ["Basic Controls", "The Map", "Saving Your Progress", "The Journal"],
			"only topics about real systems (%s)" % str(rows.map(func(r): return r.text)))
	if rows.size() > 1:
		rows[1].pressed.emit()
		for i in 8: await process_frame
	var tutorial: Node = layer.active_modal
	ck(tutorial != null and tutorial.has_method("show_topic"), "a topic opens full-screen")
	if tutorial:
		ck(tutorial.get_node("%Title").text == "The Map", "the chosen topic is shown (%s)" % tutorial.get_node("%Title").text)
		ck(tutorial.get_node("%ShotFrame").visible, "topic has its in-game screenshot")
		for down in [true, false]:
			var next := InputEventAction.new()
			next.action = &"ui_down"
			next.pressed = down
			root.push_input(next)
			await process_frame
		ck(tutorial.get_node("%Title").text == "Saving Your Progress", "down arrow moves to the next topic")
		for down in [true, false]:
			var esc := InputEventAction.new()
			esc.action = &"ui_cancel"
			esc.pressed = down
			root.push_input(esc)
			await process_frame
		for i in 6: await process_frame
		ck(layer.active_modal == null, "Escape closes the full-screen topic")
		ck(topics_panel.is_visible_in_tree(), "back on the topic list")
	menu.switch_to_tab("Inventory")
	await process_frame
	ck(not topics_panel.is_visible_in_tree(), "switching tabs hides the topic list")

	print("RESULT: " + ("ALL PASS" if fails.is_empty()
			else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0)
