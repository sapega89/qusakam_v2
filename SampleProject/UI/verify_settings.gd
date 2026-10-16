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


const TEST_DIR := "user://verify_settings/"


## Рядки віджета maaacks: заголовок колонок + по рядку на дію (шаблон ActionBoxContainer прихований).
func _action_rows(actions: Node) -> Array:
	var out: Array = []
	for row in actions.get_node(^"%ParentBoxContainer").get_children():
		if row.visible:
			out.append(row)
	return out


## Назва першого НАМАЛЬОВАНОГО рядка, що перетинає край вʼюпорта; "" — таких немає.
func _half_cut_row(actions: Control) -> String:
	var view: Rect2 = actions.get_global_rect()
	for row in _action_rows(actions):
		var r: Rect2 = row.get_global_rect()
		if row.modulate.a > 0.0 and not view.encloses(r):
			return row.get_child(0).text if row.get_child(0) is Label else str(row.name)
	return ""


func _wheel(target: Control, button: MouseButton) -> void:
	var pos: Vector2 = target.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.factor = 1.0
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)


func _initialize() -> void:
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
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var save_system: Node = sl.get_save_system()
	# Налаштування пишуться у файл слота — тест не має права чіпати справжні сейви гравця.
	save_system.set_save_dir(TEST_DIR)
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
			"res://SampleProject/Scripts/Systems/DisplayManager.gd",
			FileAccess.READ).get_as_text()
		# SettingsModule віддає налаштування DisplayManager — без власного запасного шляху (D131).
		ck(mod_src.find("window_set_mode") != -1 and mod_src.find("window_set_vsync_mode") != -1,
				"DisplayManager is the one talking to DisplayServer")
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
	ck(input_menu.get_theme_font_size("font_size", "SettingsRowLabel") == tokens.font_px(tokens.SIZE_ROW_TITLE),
			"addon widget inherits the theme inside Settings (visual integration)")
	ck(str(ProjectSettings.get_setting("gui/theme/custom", "")) == "",
			"theme is still not project-global, so addon UI elsewhere is untouched")
	var addon_src: String = FileAccess.open(
		"res://addons/maaacks_menus_template/base/nodes/menus/options_menu/input/input_actions_list.gd",
		FileAccess.READ).get_as_text()
	ck(addon_src.find("action_add_event") != -1, "addon still owns rebinding behaviour")

	print("[17] B20: the active tab's pointer does not move its button (#81)")
	for tab in ids:
		opts.switch_to_tab(tab)
		for i in 3: await process_frame
		var xs: Array = []
		var left_of_zero: Array = []
		for id in opts._tab_buttons:
			var entry: Dictionary = opts._tab_buttons[id]
			xs.append(entry.button.global_position.x)
			for part in [entry.row, entry.pointer, entry.button]:
				if part.global_position.x < 0.0:
					left_of_zero.append(id)
		ck(xs.all(func(x: float) -> bool: return x == xs[0]),
				"%s active: all tab buttons share one x %s" % [tab, str(xs)])
		ck(left_of_zero.is_empty(), "%s active: nothing left of x=0 %s" % [tab, str(left_of_zero)])
		var ptr: Control = opts._tab_buttons[tab].pointer
		ck(ptr.is_visible_in_tree() and ptr.modulate.a == 1.0, "%s active: pointer drawn" % tab)
		var others_hidden: bool = true
		for id in opts._tab_buttons:
			if id != tab and opts._tab_buttons[id].pointer.modulate.a != 0.0:
				others_hidden = false
		ck(others_hidden, "%s active: inactive pointers not drawn" % tab)

	print("[19] B23: tab titles are the agreed strings (#84, D182)")
	var titles := {"display": "Display Settings", "audio": "Audio Settings",
			"game": "Game Settings", "controls": "Controls"}
	for tab in opts.TABS:
		opts.switch_to_tab(tab.id)
		for i in 2: await process_frame
		ck(tab.heading == titles[tab.id] and opts._heading.text == titles[tab.id]
				and opts._heading.is_visible_in_tree(),
				"%s heading reads «%s»" % [tab.id, opts._heading.text])

	print("[20] B12: header icon has no blue stock colours (#88)")
	var icon_tints: Array = []
	for tab in opts.TABS:
		opts.switch_to_tab(tab.id)
		for i in 2: await process_frame
		var tint: Color = opts._header_icon.modulate * opts._header_icon.self_modulate
		icon_tints.append(tint)
		var img: Image = opts._header_icon.texture.get_image()
		var blue: int = 0
		for y in img.get_height():
			for x in img.get_width():
				var px: Color = img.get_pixel(x, y) * tint
				if px.a > 0.0 and px.b > px.r and px.b > px.g:
					blue += 1
		ck(blue == 0, "%s header icon: %d blue-dominant drawn pixels" % [tab.id, blue])
	ck(icon_tints.all(func(c: Color) -> bool: return c == icon_tints[0]),
			"header icon colour identical on all four tabs %s" % str(icon_tints[0]))

	print("[18] B21: one content column on Audio, Game and Controls (#82)")
	var columns: Dictionary = {}
	for tab in ["audio", "game", "controls"]:
		opts.switch_to_tab(tab)
		for i in 4: await process_frame
		if tab == "controls":
			var list_rect: Rect2 = input_menu.get_node(^"%InputActionsList").get_global_rect()
			var top: float = input_menu.get_node(^"VBoxContainer").global_position.y
			columns[tab] = [list_rect.position.x, list_rect.end.x, top]
		else:
			var first: Control = opts._list.get_child(0)
			var content: Rect2 = (first.get_child(0) as Control).get_global_rect()
			columns[tab] = [content.position.x, content.end.x, first.global_position.y]
	for tab in ["game", "controls"]:
		for k in 3:
			ck(absf(columns[tab][k] - columns["audio"][k]) <= 1.0,
					"%s %s matches audio (%.0f vs %.0f)" % [tab, ["left edge", "right edge", "first-row y"][k],
					columns[tab][k], columns["audio"][k]])

	print("[18b] B21: Figma row heights — slider 50 (17:409), choice 68 (17:632), 2px between, label centred (#82)")
	for spec in [["audio", UITokens.SETTINGS_SLIDER_ROW_HEIGHT], ["game", UITokens.SETTINGS_CHOICE_ROW_HEIGHT],
			["display", UITokens.SETTINGS_CHOICE_ROW_HEIGHT]]:
		opts.switch_to_tab(spec[0])
		for i in 4: await process_frame
		var rows: Array = []
		for child in opts._list.get_children():
			if child is MarginContainer:
				rows.append(child)
		for row: Control in rows:
			var label: Control = row.get_child(0).get_child(0)
			var row_mid: float = row.get_global_rect().get_center().y
			ck(is_equal_approx(row.size.y, spec[1]) and absf(label.get_global_rect().get_center().y - row_mid) <= 1.0,
					"%s row '%s' %.0fpx (want %d), label centre %.0f vs row %.0f" % [spec[0], row.get_child(0).name,
					row.size.y, spec[1], label.get_global_rect().get_center().y, row_mid])
		for i in range(1, rows.size()):
			var pitch: float = rows[i].global_position.y - rows[i - 1].global_position.y
			ck(is_equal_approx(pitch, spec[1] + UITokens.SETTINGS_ROW_GAP),
					"%s row pitch %.0f == %d + %d" % [spec[0], pitch, spec[1], UITokens.SETTINGS_ROW_GAP])

	opts.switch_to_tab("controls")
	for i in 3: await process_frame
	print("[16] B18: controls viewport fills the panel, rows are never half-cut (#79)")
	var body: Control = opts.get_node(^"%Body")
	var actions: ScrollContainer = input_menu.get_node(^"%InputActionsList")
	var mapping: VBoxContainer = actions.get_parent()
	var used: float = 0.0
	for child in mapping.get_children():
		if child != actions and child.visible:
			used += child.size.y + mapping.get_theme_constant("separation")
	ck(actions.size.y >= body.size.y - used - 1.0,
			"viewport %.0fpx fills the panel %.0fpx minus title and Reset %.0fpx" % [actions.size.y, body.size.y, used])
	var vbar: VScrollBar = actions.get_v_scroll_bar()
	ck(vbar.max_value > vbar.page, "list is taller than the viewport (%.0f > %.0f)" % [vbar.max_value, vbar.page])
	ck(vbar.is_visible_in_tree() and vbar.size.x == tokens.SCROLLBAR_WIDTH,
			"scrollbar visible, %.0fpx wide" % vbar.size.x)
	var cut: Array = []
	var offset := 0.0
	while offset <= vbar.max_value:
		vbar.value = offset
		await process_frame
		await process_frame
		var bad: String = _half_cut_row(actions)
		if bad != "":
			cut.append("%s@%d" % [bad, int(vbar.value)])
		offset += 7.0
	ck(cut.is_empty(), "no drawn row crosses the viewport edge at any offset (%s)" % str(cut))
	var rows: Array = _action_rows(actions)
	var last_row: Control = rows[-1]
	vbar.value = 0.0
	for i in 3: await process_frame
	ck(last_row.modulate.a == 0.0, "last row starts hidden below the viewport")
	for i in 40:
		_wheel(actions, MOUSE_BUTTON_WHEEL_DOWN)
		await process_frame
	for i in 3: await process_frame
	ck(last_row.modulate.a == 1.0 and actions.get_global_rect().encloses(last_row.get_global_rect()),
			"mouse wheel reaches the last row (%s)" % last_row.get_child(0).text)
	vbar.value = 0.0
	for i in 3: await process_frame
	(rows[1].get_child(1) as Control).grab_focus()
	await process_frame
	for i in rows.size() - 2:  # з першої дії до останньої
		_key(KEY_DOWN)
		await process_frame
		await process_frame
	for i in 3: await process_frame
	var focused: Control = root.gui_get_focus_owner()
	ck(focused != null and focused.get_parent() == last_row,
			"keyboard Down reaches the last row (%s)" % (focused.get_parent().get_child(0).text if focused else "-"))
	ck(last_row.modulate.a == 1.0 and actions.get_global_rect().encloses(last_row.get_global_rect()),
			"focused last row is drawn whole")
	ck(_half_cut_row(actions) == "", "no half-cut row after keyboard scrolling")
	vbar.value = 0.0

	print("[9] persistence round trip")
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	_row(opts, "Music").get_node(^"Slider/Value").value = 25.0
	for i in 4: await process_frame
	# Налаштування живуть у слоті з сейвом гри — слот без сейву не створюється.
	FileAccess.open(save_system.get_slot_path(save_system.current_slot), FileAccess.WRITE).store_string(var_to_str({"current_room": ":test"}))
	save_system.save_game_settings()
	module.settings["music_volume"] = 0.99
	save_system.load_game_settings()
	await process_frame
	ck(absf(float(module.settings["music_volume"]) - 0.25) < 0.01,
			"reloaded value restored (%.2f)" % module.settings["music_volume"])
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	ck(_row(opts, "Music").get_node(^"Slider/Value").value == 25.0, "UI reflects the reloaded value")

	# [10] «порожній / неповний payload → значення за замовчуванням» прибрано разом із цим
	# запасним шляхом (D131): відсутній ключ у налаштуваннях — помилка.

	print("[11] restore defaults")
	opts._on_restore_pressed()
	for i in 4: await process_frame
	ck(module.settings["master_volume"] == module.default_settings["master_volume"],
			"restore resets to module defaults")

	print("[12] theme and shared tokens")
	ck(opts._heading.get_theme_font_size("font_size", "SettingsHeading") == tokens.font_px(tokens.SIZE_DISPLAY),
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
	menu._unhandled_input(ev)
	for i in 8: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "ui_cancel closed the menu")
	ck(not paused, "gameplay resumed")
	ck(ui.is_gameplay_input_allowed(), "gameplay input restored")

	print("[15] Settings → Exit to Main Menu lands on a live main menu")
	ui.open_game_menu()
	for i in 14: await process_frame
	menu = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Misc")
	for i in 6: await process_frame
	opts = get_first_node_in_group("settings_screen")
	ck(opts != null and opts.exit_to_main_menu_button != null, "exit button present")
	if opts:
		opts.exit_to_main_menu_button.pressed.emit()
		for i in 20: await process_frame
	var landed: String = current_scene.scene_file_path if current_scene else "<none>"
	ck(landed.ends_with("MainMenu.tscn"), "landed on MainMenu (%s)" % landed)
	ck(not paused, "main menu is not frozen")
	_done()


func _done() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
