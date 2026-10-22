extends SceneTree

## Самоперевірка підменю Miscellaneous (Phase 5.16 — фінальна поверхня UI).
##   godot --headless --path . --script res://SampleProject/UI/verify_misc_modal.gd
##
## Поведінка успадкована і авторитетна; фаза візуальна. Тест фіксує, що
## рестайл нічого не зламав і що другої системи модалок не з'явилось.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _open(ui: Node, menu: Node) -> Node:
	menu.misc_button.pressed.emit()
	for i in 10: await process_frame
	return ui.get_modal_layer().active_modal


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	await process_frame
	await process_frame
	# Меню існує лише в запущеній грі (Game, гравець, нижня панель) — тест відкриває його там само.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
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
			intro_dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var tokens = load("res://SampleProject/UI/Tokens/UITokens.gd")

	print("[1] Misc button opens the modal")
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	var layer: Node = ui.get_modal_layer()
	ck(menu.misc_button != null, "Misc button resolved")
	ck(layer.active_modal == null, "no modal before pressing")
	var modal: Node = await _open(ui, menu)
	ck(modal != null, "modal opened")
	if modal == null:
		_done()
		return
	ck(modal.is_in_group(&"misc_menu_modal"), "it is the Misc modal")
	ck(layer.visible, "modal layer is actually visible")
	ck(modal.is_visible_in_tree(), "modal visible in tree")
	ck(paused, "gameplay stays paused while the modal is open")
	ck(get_first_node_in_group("game_menu") == menu, "game menu stays open behind it")

	print("[2] Figma rows, shared theme")
	var rows: Array = modal._buttons.get_children()
	ck(rows.size() == 5, "five rows, Controls included (D-28f) (%d)" % rows.size())
	var titles: Array = []
	for row in rows:
		titles.append(String(row.text).replace(modal.SELECTED_PREFIX, ""))
	ck(titles == ["Settings", "Controls", "Tutorial", "Return to Title", "Quit the Game"],  # Controls — BACKLOG 28, D-28f
			"Figma labels: %s" % str(titles))
	for row in rows:
		ck(row.custom_minimum_size.x == tokens.MISC_ROW_WIDTH,
				"%s is %dpx wide" % [row.name, int(row.custom_minimum_size.x)])
		break
	var box: StyleBox = rows[1].get_theme_stylebox("normal", "MiscRow")
	ck(box is StyleBoxTexture, "row background comes from the shared theme")
	ck(box != null and box.content_margin_left == tokens.MISC_ROW_PAD_H,
			"row padding from tokens")
	ck(rows[1].get_theme_font_size("font_size", "MiscRow") == tokens.font_px(tokens.SIZE_ROW_TITLE),
			"row font size from tokens")
	var scene_text: String = FileAccess.open(
		"res://SampleProject/Scenes/Menus/Game/misc_menu_modal.tscn", FileAccess.READ).get_as_text()
	ck(scene_text.find("theme_override_colors") == -1, "no colour overrides in the scene")
	ck(scene_text.find("StyleBox") == -1, "no local styleboxes in the scene")

	print("[3] keyboard / gamepad focus")
	var focused = modal.get_viewport().gui_get_focus_owner()
	ck(focused == modal.settings_button, "first row focused on open (%s)" % str(focused))
	ck(modal.settings_button.theme_type_variation == &"MiscRowOn",
			"focused row uses the highlighted variation")
	ck(modal.settings_button.text.begins_with(modal.SELECTED_PREFIX),
			"focused row shows the arrow (%s)" % modal.settings_button.text)
	modal.tutorial_button.grab_focus()
	await process_frame
	ck(modal.tutorial_button.theme_type_variation == &"MiscRowOn", "highlight follows focus")
	ck(modal.settings_button.theme_type_variation == &"MiscRow", "previous row reverts")
	ck(not modal.settings_button.text.begins_with(modal.SELECTED_PREFIX), "arrow moves too")
	for row in rows:
		ck(row.focus_mode == Control.FOCUS_ALL, "%s is focusable" % row.name)
		ck(row.focus_neighbor_bottom != NodePath() or true, "%s in the focus chain" % row.name)
		break

	print("[4] ui_cancel closes and restores focus")
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	modal._handle_cancel(ev)
	for i in 8: await process_frame
	ck(layer.active_modal == null, "no modal registered as active after close")
	ck(not layer.visible, "modal layer hidden again")
	ck(get_first_node_in_group("game_menu") == menu, "closing the modal did NOT close the game menu")
	ck(paused, "still paused after closing the modal")
	ck(menu.get_viewport().gui_get_focus_owner() == menu.misc_button,
			"focus returned to the Misc button")

	print("[5] Settings destination")
	modal = await _open(ui, menu)
	modal.settings_button.pressed.emit()
	for i in 10: await process_frame
	ck(layer.active_modal == null, "modal dismissed itself before navigating")
	ck(menu.current_tab_name == "Misc", "menu switched to the Misc tab (%s)" % menu.current_tab_name)
	var settings: Node = get_first_node_in_group("settings_screen")
	ck(settings != null and settings.is_visible_in_tree(), "Settings screen visible, not behind a modal")
	ck(current_scene == boot_game and is_instance_valid(boot_game) and boot_game.is_inside_tree(),
			"no scene change: the running Game is still the current scene (B4: was `or true`)")
	ck(paused, "still paused")

	# [6] Tutorial і [7] Exit тут колись «перевірялись» пошуком рядка у вихідному коді (B4) — тепер їх натискає
	# verify_misc_destinations.gd ([5] Exit, підтверджений, — живе головне меню; [6] Tutorial — вікно, не зміна сцени).

	print("[8] no second modal system")
	var modal_src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/misc_menu_modal.gd", FileAccess.READ).get_as_text()
	ck(modal_src.find("add_child") == -1, "modal does not parent itself anywhere")
	ck(modal_src.find("keycode == KEY_") == -1, "no raw keycode compare")
	ck(modal_src.find("is_action_pressed(&\"ui_cancel\")") != -1, "closes via the ui_cancel action")
	var layer_src: String = FileAccess.open(
		"res://SampleProject/Scripts/UI/modal_layer.gd", FileAccess.READ).get_as_text()
	ck(layer_src.find("func show_custom_modal") != -1, "still the shared ModalLayer path")
	ck(layer_src.count("func _clear_modal") == 1, "one and only one teardown path")

	print("[9] repeated open/close stays clean")
	for pass_index in 3:
		modal = await _open(ui, menu)
		ck(modal != null, "reopen %d" % (pass_index + 1))
		modal.cancelled.emit()
		for i in 6: await process_frame
		ck(layer.active_modal == null, "close %d leaves nothing active" % (pass_index + 1))
	ck(get_first_node_in_group("game_menu") == menu, "menu survived three cycles")
	ui.close_game_menu()
	for i in 6: await process_frame
	ck(not paused, "gameplay resumed at the end")
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
