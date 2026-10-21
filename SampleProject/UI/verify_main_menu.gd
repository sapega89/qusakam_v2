extends SceneTree

## Самоперевірка slice 1c: Main Menu Continue + Splash.
##   godot --headless --path . --script res://SampleProject/UI/verify_main_menu.gd
##
## Figma: main-menu 9:26, UI/Splash Screen 258:5140, UI/Menu Item 248:62.
## Рішення: D72 (лише Continue), D75/D77 (Continue → Save Slot Selection, LOAD).

const MENU_SCENE := "res://SampleProject/MainMenu.tscn"
const TEST_DIR := "user://verify_mainmenu_saves/"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var ss: Node


func _wipe() -> void:
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)


func _open(title_mode: bool) -> Control:
	set_meta("show_title_screen", title_mode)
	var m: Control = load(MENU_SCENE).instantiate()
	root.add_child(m)
	return m


func _initialize() -> void:
	await process_frame
	await process_frame
	ss = root.get_node("ServiceLocator").get_save_system()
	var theme: Theme = load("res://SampleProject/UI/Themes/GameUITheme.tres")
	ss.set_save_dir(TEST_DIR)
	_wipe()
	ss.set_save_dir(TEST_DIR)

	print("[1] Scene follows Figma 9:26 with shared styles")
	var txt := FileAccess.open(MENU_SCENE, FileAccess.READ).get_as_text()
	ck(txt.find("theme_override") == -1 and txt.find("StyleBox") == -1, "no local styles in MainMenu.tscn")
	ck(txt.find("load_game") == -1, "no Load Game button (D72)")
	var menu := _open(true)
	await process_frame
	var items: Array = menu.menu.get_children().map(func(b): return b.text)
	ck(items == ["New Game", "Continue", "Settings", "Quit Game"], "Figma order and labels: %s" % str(items))
	# D119: пункти по центру під назвою, вказівник поруч із текстом (B17).
	var listed := _open(false)  # меню розкладається лише у видимому режимі
	for i in 4: await process_frame
	var axis: float = listed.get_node("Center/GameTitle").get_global_rect().get_center().x
	for b in listed.menu.get_children():
		var r: Rect2 = (b as Control).get_global_rect()
		ck(absf(r.get_center().x - axis) <= 1.0, "%s centred under the title (%.0f vs %.0f)" % [b.text, r.get_center().x, axis])
		ck(r.size.x < 200.0, "%s hugs its content (%.0f px)" % [b.text, r.size.x])
	listed.queue_free()
	ck(theme.get_font_size("font_size", "TitleKhalahas") == UITokens.SIZE_TITLE_KHALAHAS, "KHALAHAS 100px")
	ck(theme.get_font_size("font_size", "TitleHeroes") == UITokens.SIZE_TITLE_HEROES, "HEROES 90px")
	ck((theme.get_font("font", "TitleKhalahas") as FontVariation).spacing_glyph == UITokens.TITLE_SPACING_KHALAHAS,
			"title letter-spacing from Figma")

	print("[2] Splash (258:5140)")
	ck(menu.get_node("%SplashBackground").color == UITokens.SPLASH_BG, "black #050508 background")
	ck(not menu.background.visible and not menu.get_node("%MenuOverlay").visible, "no menu art on the splash")
	ck(menu.press_any_button_container.visible, "\"PRESS ANY BUTTON\" shown")
	ck(menu.press_any_button_label.uppercase and menu.press_any_button_label.text == "Press Any Button", "prompt copy, uppercased")
	ck(not menu.menu.visible and not menu.get_node("%MenuDivider").visible, "menu hidden on the splash")
	ck(menu.get_node("%GameTitle").visible, "title visible")
	ck(menu.get_node("%CopyrightLabel").text == "© 2024-2026 Khalahas Studio. All Rights Reserved.", "Figma copyright")

	print("[3] Any button → main menu")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	menu._input(ev)
	for i in 30: await process_frame
	ck(menu.menu.visible and not menu.press_any_button_container.visible, "menu replaces the prompt")
	ck(menu.background.visible and menu.get_node("%MenuOverlay").color == UITokens.MAIN_MENU_OVERLAY,
			"forest art under a black 56% overlay")
	var new_game: Button = menu.menu.get_node("new_game")
	var cont: Button = menu.menu.get_node("continue")
	var settings: Button = menu.menu.get_node("options")
	ck(menu.get_viewport().gui_get_focus_owner() == new_game, "New Game focused")
	ck(new_game.theme_type_variation == &"MainMenuItemOn", "focused item uses the active style")
	ck(settings.theme_type_variation == &"MainMenuItem", "other items use the inactive style")
	ck(is_equal_approx(theme.get_color("font_color", "MainMenuItem").a, UITokens.MENU_INACTIVE_ALPHA), "inactive text at 70%")
	ck(theme.get_color("icon_normal_color", "MainMenuItem").a == 0.0, "inactive item hides the pointer")
	ck(theme.get_color("icon_focus_color", "MainMenuItemOn").a == 1.0, "active item shows the pointer")

	print("[4] Continue only when a save exists (D72)")
	ck(cont.disabled and cont.focus_mode == Control.FOCUS_NONE, "no saves → Continue disabled")
	ck(new_game.find_valid_focus_neighbor(SIDE_BOTTOM) == settings, "focus skips the disabled Continue")
	menu.queue_free()
	await process_frame
	var f := FileAccess.open(ss.get_slot_path(2), FileAccess.WRITE)
	f.store_string(var_to_str({"current_room": "Canyon"}))
	f.close()
	menu = _open(false)
	for i in 4: await process_frame
	cont = menu.menu.get_node("continue")
	ck(not cont.disabled and cont.focus_mode == Control.FOCUS_ALL, "a save exists → Continue enabled")
	ck(menu.menu.visible and menu.background.visible, "returning to the menu skips the splash")

	print("[4b] Esc in Settings closes Settings, not the game (Sapega, 2026-10-16)")
	menu.options_button_up()
	await create_timer(1.0).timeout
	ck(get_first_node_in_group("settings_screen") != null and not menu.menu.visible, "Settings open over the menu")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await create_timer(1.0).timeout  # якби Esc викликав quit(), процес закінчився б тут без RESULT
	ck(menu.menu.visible and get_first_node_in_group("settings_screen") == null, "Esc returned to the menu")

	print("[4c] Esc and Exit on the menu ask \"Exit Game?\" first (Sapega, 2026-10-16)")
	var layer: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer()
	for way in ["Esc", "Exit button"]:
		if way == "Esc":
			Input.parse_input_event(esc)
		else:
			menu.menu.get_node("exit").pressed.emit()
		for i in 6: await process_frame
		var modal: Node = layer.active_modal
		ck(modal != null and modal.title_label.text == "Exit Game?", "%s → Exit Game? modal" % way)
		if modal == null:
			continue
		var panel_bg: Color = modal.get_node("Panel").get_theme_stylebox("panel").bg_color
		ck(panel_bg.a == 1.0, "%s → the modal panel is opaque (D195, alpha %.2f)" % [way, panel_bg.a])
		for b in modal.buttons_container.get_children():
			if b is Button and b.text == "Cancel":
				b.pressed.emit()
		for i in 6: await process_frame
		ck(layer.active_modal == null and menu.menu.visible, "%s → Cancel keeps the game running" % way)

	print("[5] Continue → Save Slot Selection in LOAD mode (D75)")
	cont.pressed.emit()
	for i in 6: await process_frame
	var scene := current_scene
	ck(scene != null and scene.scene_file_path == "res://SampleProject/Scenes/Menus/LoadGameMenu.tscn",
			"Continue opens the slot selection (%s)" % (scene.scene_file_path if scene else "null"))
	ck(scene != null and scene.get("mode") == "load", "in LOAD mode")
	if scene:
		var cards: Array = scene._cards
		ck(cards[1].is_selectable() and not cards[0].is_selectable(), "only the saved slot is selectable")

	_wipe()
	DirAccess.remove_absolute(TEST_DIR)
	_done()


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("    : " + f)
	quit(0 if fails.is_empty() else 1)
