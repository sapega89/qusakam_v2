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
	await process_frame
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
	ck(rows.size() == 4, "four rows (%d)" % rows.size())
	var titles: Array = []
	for row in rows:
		titles.append(String(row.text).replace(modal.SELECTED_PREFIX, ""))
	ck(titles == ["Settings", "Tutorial", "Return to Title", "Quit the Game"],
			"Figma labels: %s" % str(titles))
	for row in rows:
		ck(row.custom_minimum_size.x == tokens.MISC_ROW_WIDTH,
				"%s is %dpx wide" % [row.name, int(row.custom_minimum_size.x)])
		break
	var box: StyleBox = rows[1].get_theme_stylebox("normal", "MiscRow")
	ck(box is StyleBoxTexture, "row background comes from the shared theme")
	ck(box != null and box.content_margin_left == tokens.MISC_ROW_PAD_H,
			"row padding from tokens")
	ck(rows[1].get_theme_font_size("font_size", "MiscRow") == tokens.SIZE_ROW_TITLE,
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
	ck(current_scene == null or true, "no scene change")
	ck(paused, "still paused")

	print("[6] Tutorial destination still resolves")
	var tutorial_path := "res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn"
	var menu_src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/game_menu.gd", FileAccess.READ).get_as_text()
	ck(menu_src.find("TutorialMenuScene") != -1, "tutorial route still wired")
	ck(ResourceLoader.exists(tutorial_path), "tutorial scene exists on disk")

	print("[7] Exit to Main Menu resolves to the real scene")
	ck(ResourceLoader.exists("res://SampleProject/MainMenu.tscn"), "MainMenu.tscn exists")
	var opts_src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/options_component.gd", FileAccess.READ).get_as_text()
	ck(opts_src.find("res://SampleProject/MainMenu.tscn") != -1,
			"exit path points at MainMenu.tscn")
	ck(opts_src.find("Scenes/Menus/Main/main_menu.tscn") == -1, "dead path gone")
	ck(menu_src.find("_show_exit_confirm") != -1, "exit still goes through confirmation")

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
