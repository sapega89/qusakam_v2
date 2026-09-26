extends SceneTree

## Самоперевірка екрана Settings (Phase 5.13).
##   godot --headless --path . --script res://SampleProject/UI/verify_settings.gd
##
## Показуємо лише підтримувані налаштування; відкладені рядки Figma
## (Resolution, Frame Rate Limit, Screen Brightness, Ambient, Text Speed,
## Screen Shake, Damage Numbers) не мають бути на екрані взагалі.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

const DEFERRED := ["Resolution", "Frame Rate", "Brightness", "Ambient",
	"Text Speed", "Screen Shake", "Damage Numbers"]


func _labels(node: Node, out: Array) -> Array:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_labels(child, out)
	return out


func _row(opts: Node, title: String) -> Node:
	for margin in opts._list.get_children():
		if margin.get_child_count() > 0 and margin.get_child(0).name == title:
			return margin.get_child(0)
	return null


func _segments(opts: Node, title: String) -> Array:
	var row: Node = _row(opts, title)
	if row == null:
		return []
	var frame: Node = row.get_node_or_null(^"Segments")
	return frame.get_child(0).get_children() if frame else []


func _active_segment(opts: Node, title: String) -> String:
	for cell in _segments(opts, title):
		if cell.theme_type_variation == &"SettingsSegmentOn":
			return cell.text
	return ""


func _press(opts: Node, title: String, cell_text: String) -> bool:
	for cell in _segments(opts, title):
		if cell.text.ends_with(cell_text):
			cell.pressed.emit()
			return true
	return false


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var save_system: Node = sl.get_save_system()
	var loc: Node = root.get_node_or_null("LocalizationManager")
	var tokens = load("res://SampleProject/UI/Tokens/UITokens.gd")

	print("[1] Settings opens inside the game menu, no scene change")
	var scene_before = current_scene
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Misc")
	for i in 10: await process_frame
	var opts: Node = get_first_node_in_group("settings_screen")
	ck(opts != null, "settings screen present")
	if opts == null:
		_done()
		return
	ck(opts.is_visible_in_tree(), "settings visible on the Misc tab")
	ck(current_scene == scene_before, "no scene change")
	ck(paused, "game stays paused behind the menu")
	ck(get_first_node_in_group("game_menu") == menu, "same menu instance — no second pause system")

	print("[2] only supported tabs exist")
	var ids: Array = []
	for t in opts.TABS: ids.append(t.id)
	ck(ids == ["display", "audio", "game", "controls"], "four tabs: %s" % str(ids))

	print("[3] deferred Figma rows are absent everywhere")
	var seen: Array = []
	for tab in ids:
		opts.switch_to_tab(tab)
		for i in 3: await process_frame
		_labels(opts, seen)
	var leaked: Array = []
	for term in DEFERRED:
		for text in seen:
			if String(text).findn(term) >= 0:
				leaked.append(term)
				break
	ck(leaked.is_empty(), "no deferred rows rendered (leaked: %s)" % str(leaked))

	print("[4] audio rows bind to the real settings module")
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	var module: Node = opts._settings_module
	ck(module != null, "settings module resolved")
	ck(module == save_system.settings_module, "same module the save system owns — no duplicate")
	for pair in [["Master Volume", "master_volume"], ["Music", "music_volume"],
			["Sound Effects", "sfx_volume"]]:
		var row: Node = _row(opts, pair[0])
		ck(row != null, "%s row present" % pair[0])
		if row:
			var slider: HSlider = row.get_node(^"Slider/Value")
			var expected := roundf(float(module.settings.get(pair[1], 0.0)) * 100.0)
			ck(slider.value == expected, "%s reads %d from settings" % [pair[0], int(slider.value)])

	print("[5] volume changes apply immediately and persist")
	var master_row: Node = _row(opts, "Master Volume")
	var master: HSlider = master_row.get_node(^"Slider/Value")
	master.value = 40.0
	for i in 4: await process_frame
	ck(absf(float(module.settings["master_volume"]) - 0.4) < 0.01,
			"module holds 0.40 (%.2f)" % module.settings["master_volume"])
	var bus := AudioServer.get_bus_index("Master")
	var applied := db_to_linear(AudioServer.get_bus_volume_db(bus))
	ck(absf(applied - 0.4) < 0.02, "AudioServer applied it live (%.2f)" % applied)
	ck(master_row.get_node(^"Slider/Readout").text == "40", "readout updated")

	print("[6] display mode and vsync are real DisplayServer state")
	opts.switch_to_tab("display")
	for i in 4: await process_frame
	ck(_row(opts, "Display Mode") != null, "Display Mode row present")
	ck(_row(opts, "VSync") != null, "VSync row present")
	ck(_segments(opts, "Display Mode").size() == 2, "two display modes only (no borderless)")
	var was_fs: bool = module.settings.get("fullscreen", false)
	ck(_press(opts, "Display Mode", "Fullscreen"), "Fullscreen cell pressed")
	for i in 4: await process_frame
	ck(module.settings["fullscreen"] == true, "fullscreen stored")
	ck(_active_segment(opts, "Display Mode").ends_with("Fullscreen"), "segment shows the new state")
	ck(_press(opts, "Display Mode", "Windowed"), "Windowed cell pressed")
	for i in 4: await process_frame
	ck(module.settings["fullscreen"] == false, "windowed stored")
	ck(_press(opts, "VSync", "Disable"), "VSync Disable pressed")
	for i in 4: await process_frame
	ck(module.settings["vsync"] == false, "vsync stored")
	# Headless-драйвер ігнорує запис у DisplayServer, тож реальний стан вікна
	# перевіряємо лише з живим драйвером.
	if DisplayServer.get_name() == "headless":
		print("  SKIP live DisplayServer checks (headless stub ignores writes)")
		var mod_src: String = FileAccess.open(
			"res://SampleProject/Scripts/Systems/Save/Modules/SettingsModule.gd",
			FileAccess.READ).get_as_text()
		ck(mod_src.find("window_set_mode") != -1 and mod_src.find("window_set_vsync_mode") != -1,
				"existing module is the one talking to DisplayServer")
	else:
		ck(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
				"DisplayServer follows the setting")
		ck(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
				"DisplayServer vsync follows")
	_press(opts, "VSync", "Enable")
	for i in 3: await process_frame

	print("[7] languages come from LocalizationManager, not a hardcoded list")
	opts.switch_to_tab("game")
	for i in 4: await process_frame
	var lang_cells := _segments(opts, "Language")
	ck(loc != null, "LocalizationManager autoload present")
	ck(lang_cells.size() == loc.available_languages.size(),
			"one cell per real locale (%d vs %d)" % [lang_cells.size(), loc.available_languages.size()])
	var src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/options_component.gd", FileAccess.READ).get_as_text()
	ck(src.find("available_languages") != -1, "list is read from the manager")
	var before_lang: String = loc.get_language()
	var other: String = "uk" if before_lang != "uk" else "en"
	ck(_press(opts, "Language", opts._language_name(other)), "switched language cell")
	for i in 4: await process_frame
	ck(loc.get_language() == other, "LocalizationManager switched to %s" % loc.get_language())
	ck(module.settings["language"] == other, "language stored in settings")

	print("[8] controls tab keeps the Maaacks rebinding widget")
	opts.switch_to_tab("controls")
	for i in 5: await process_frame
	var input_menu: Node = opts._input_menu
	ck(input_menu != null and input_menu.visible, "InputOptionsMenu shown")
	ck(not opts._list.visible, "our own row list is hidden on Controls")
	var rebinder: Node = input_menu.find_child("*Input*", true, false)
	ck(rebinder != null, "addon rebinding subtree present")
	ck(src.find("action_add_event") == -1 and src.find("action_erase_events") == -1,
			"no second rebinding implementation in our script")
	# Стилізація аддона — СКОУПОВАНА: він успадковує тему лише тому, що
	# вкладений у наш екран. Глобально GameUITheme аддонам не нав'язуємо.
	ck(input_menu.get_theme_font_size("font_size", "SettingsRowLabel") == tokens.SIZE_ROW_TITLE,
			"addon widget inherits the theme inside Settings (visual integration)")
	ck(str(ProjectSettings.get_setting("gui/theme/custom", "")) == "",
			"theme is still not project-global, so addon UI elsewhere is untouched")
	var addon_src: String = FileAccess.open(
		"res://addons/maaacks_menus_template/base/nodes/menus/options_menu/input/input_actions_list.gd",
		FileAccess.READ).get_as_text()
	ck(addon_src.find("action_add_event") != -1, "addon still owns rebinding behaviour")

	print("[9] persistence round trip")
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	_row(opts, "Music").get_node(^"Slider/Value").value = 25.0
	for i in 4: await process_frame
	save_system.save_game_settings()
	module.settings["music_volume"] = 0.99
	save_system.load_game_settings()
	await process_frame
	ck(absf(float(module.settings["music_volume"]) - 0.25) < 0.01,
			"reloaded value restored (%.2f)" % module.settings["music_volume"])
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	ck(_row(opts, "Music").get_node(^"Slider/Value").value == 25.0, "UI reflects the reloaded value")

	print("[10] defaults / legacy config load safely")
	module.load_data({})
	await process_frame
	ck(module.settings.has("master_volume"), "empty payload falls back to defaults")
	module.load_data({"master_volume": 0.5})
	await process_frame
	ck(module.settings.get("master_volume") == 0.5, "partial legacy payload accepted")
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	ck(_row(opts, "Music") != null, "missing keys still render with fallbacks")

	print("[11] restore defaults")
	opts._on_restore_pressed()
	for i in 4: await process_frame
	ck(module.settings["master_volume"] == module.default_settings["master_volume"],
			"restore resets to module defaults")

	print("[12] theme and shared tokens")
	ck(opts._heading.get_theme_font_size("font_size", "SettingsHeading") == tokens.SIZE_DISPLAY,
			"heading resolves SettingsHeading from the shared theme")
	ck(opts._eyebrow.get_theme_color("font_color", "SettingsEyebrow") == tokens.ACCENT,
			"eyebrow colour from tokens")
	var scene_text: String = FileAccess.open(
		"res://SampleProject/Scenes/Menus/Game/options_component.tscn", FileAccess.READ).get_as_text()
	ck(scene_text.find("theme_override_colors") == -1, "no one-off colour overrides in the scene")
	ck(scene_text.find("FontFile") == -1, "no embedded one-off fonts")

	print("[13] bottom bar hints are truthful")
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	opts.switch_to_tab("audio")
	for i in 3: await process_frame
	ck(bar != null and bar._hint_label.text == opts.TAB_HINTS["audio"],
			"hint follows the tab (%s)" % (bar._hint_label.text if bar else "-"))

	print("[14] back to gameplay")
	ck(opts.has_method("close_options_menu") and opts.mode == "game_menu", "dual mode preserved")
	menu.switch_to_tab("Inventory")
	for i in 5: await process_frame
	ck(not opts.is_visible_in_tree(), "settings hides when leaving the tab")
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	menu._input(ev)
	for i in 8: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "ui_cancel closed the menu")
	ck(not paused, "gameplay resumed")
	ck(ui.is_gameplay_input_allowed(), "gameplay input restored")
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
