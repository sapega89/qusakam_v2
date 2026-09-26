extends SceneTree

## Перевірка канонічного pause-досвіду (Phase 5.11).
##   godot --headless --path . --script res://SampleProject/UI/verify_pause.gd
##
## Окремого екрана Pause у Figma немає: паузою є вкладкове ігрове меню.
## Тест фіксує саме цей контракт, щоб другу систему паузи не створили випадково.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var menu_manager: Node = sl.get_menu_manager()

	print("[1] the game menu IS the pause UI")
	ck(not paused, "game starts unpaused")
	ui.open_game_menu()
	for i in 12: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "game menu opens")
	ck(paused, "opening the game menu pauses the tree")
	ck(ui.current_state_name == "GameMenuState", "UIManager is in GameMenuState")

	print("[2] menu processes while paused")
	if menu:
		ck(menu.process_mode == Node.PROCESS_MODE_WHEN_PAUSED
				or menu.process_mode == Node.PROCESS_MODE_ALWAYS,
				"menu keeps processing while the tree is paused")

	print("[3] gameplay input is suppressed while paused")
	ck(not ui.is_gameplay_input_allowed(), "gameplay input blocked while the menu is open")

	print("[4] ui_cancel closes via InputMap, not a raw keycode")
	var menu_src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/game_menu.gd", FileAccess.READ).get_as_text()
	ck(menu_src.find("keycode == KEY_ESCAPE") == -1, "no hardcoded keycode compare in the pause handler")
	ck(menu_src.find("is_action_pressed(&\"ui_cancel\")") != -1, "pause close uses the ui_cancel action")
	if menu:
		var ev := InputEventAction.new()
		ev.action = &"ui_cancel"
		ev.pressed = true
		menu._input(ev)
		for i in 8: await process_frame
		ck(get_first_node_in_group("game_menu") == null, "ui_cancel closes the menu")
		ck(not paused, "ui_cancel unpauses the game")

	print("[5] explicit close returns to gameplay")
	ui.open_game_menu()
	for i in 12: await process_frame
	ui.close_game_menu()
	for i in 8: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes")
	ck(not paused, "closing unpauses the tree")
	ck(ui.is_gameplay_input_allowed(), "gameplay input restored")
	ck(ui.current_state_name != "GameMenuState", "UIManager left GameMenuState")

	print("[5b] toggle path is idempotent")
	menu_manager.toggle_game_menu()
	for i in 10: await process_frame
	ck(paused, "toggle opens and pauses")
	menu_manager.toggle_game_menu()
	for i in 8: await process_frame
	ck(not paused, "toggle closes and unpauses")

	print("[6] focus is restored on reopen")
	ui.open_game_menu()
	for i in 12: await process_frame
	var menu2: Node = get_first_node_in_group("game_menu")
	ck(menu2 != null, "menu reopens")
	if menu2:
		ck(menu2.current_tab_name == "Inventory", "reopens on the default tab (%s)" % menu2.current_tab_name)
		var router: Node = menu2.find_child("FocusRouter", true, false)
		ck(router != null, "focus router present for keyboard/gamepad return")
		var focused := menu2.get_viewport().gui_get_focus_owner()
		ck(focused != null, "something holds focus after reopen")

	print("[7] Settings is reachable without leaving gameplay")
	ck(menu_src.find("change_scene_to_file(OptionsMenuScene)") == -1,
			"Settings route no longer unloads the running game")
	var options: Node = menu2.find_child("OptionsComponent", true, false) if menu2 else null
	ck(options != null, "options component lives inside the pause menu")
	if menu2:
		menu2._on_misc_settings_selected()
		for i in 8: await process_frame
		ck(paused, "opening Settings keeps the game paused")
		ck(menu2.is_inside_tree(), "pause menu survives the Settings route")
		ck(options != null and options.is_visible_in_tree(), "Settings panel shown")
		menu2.switch_to_tab("Inventory")
		for i in 5: await process_frame
		ck(not options.is_visible_in_tree(), "leaving Settings hides it again")

	ui.close_game_menu()
	for i in 6: await process_frame
	ck(not paused, "returns to gameplay cleanly")

	print("[8] no second pause system")
	var src: String = FileAccess.open(
		"res://SampleProject/Scripts/UI/PauseMenu.gd", FileAccess.READ).get_as_text()
	ck(src.find("class_name PauseMenu") != -1, "legacy PauseMenu.gd still on disk")
	# Мертвий код: жодна сцена його не інстанціює і жоден скрипт не згадує.
	var referenced := false
	for path in ["res://SampleProject/Game.tscn",
			"res://SampleProject/Scenes/UI/ui_root.tscn",
			"res://SampleProject/Scenes/Menus/Game/game_menu.tscn"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f and f.get_as_text().find("PauseMenu") != -1:
			referenced = true
	ck(not referenced, "no scene instantiates PauseMenu")
	ck(get_first_node_in_group("pause_menu") == null, "no PauseMenu node exists at runtime")
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
