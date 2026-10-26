extends SceneTree

## Самоперевірка екрана Settings (Phase 5.13).
##   godot --headless --path . --script res://SampleProject/UI/verify_settings.gd
##
## Показуємо лише підтримувані налаштування; кожен рядок Figma тепер має свою систему (settings-2:
## Screen Brightness D428, Ambient D427, Text Speed D425, Screen Shake D426 — [3], [22]);
## Damage Numbers (D66) — verify_damage_numbers.gd. Resolution / Frame Rate Limit (BACKLOG 41) — verify_settings_graphics.gd.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Колись відкладені рядки Figma (settings_mapping.md) — тепер на своїх вкладках.
const ONCE_DEFERRED := {"Screen Brightness": "display", "Ambient": "audio",
	"Text Speed": "game", "Screen Shake": "game"}


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
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	await process_frame
	# Headless скидає вікно до 64×64 на першому кадрі, а тест клікає мишею в координатах 1920×1080.
	# Раніше розмір неявно ставив AppConfig аддона Maaacks із player_config.cfg (замінено InputConfig).
	root.size = Vector2i(1920, 1080)
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
	var save_system: Node = sl.get_save_system()
	# Файл налаштувань лежить у теці сейвів — тест не має права чіпати справжні.
	# Тека, що лишилась від обірваного прогону, має сейви — [9] перевіряє інсталяцію без жодного.
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
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

	print("[3] the once-deferred Figma rows are on their tabs (settings-2)")
	for title in ONCE_DEFERRED:
		opts.switch_to_tab(ONCE_DEFERRED[title])
		for i in 3: await process_frame
		ck(_row(opts, title) != null, "%s row on the %s tab" % [title, ONCE_DEFERRED[title]])

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
	# B22: −/+ — квадратні кнопки з рамкою (SettingsStepper), а не голі гліфи.
	for part in [^"Slider/Minus", ^"Slider/Plus"]:
		var stepper: Button = master_row.get_node(part)
		ck(stepper.theme_type_variation == &"SettingsStepper" and stepper.size.x >= UITokens.SETTINGS_STEPPER_BOX
				and stepper.size.y >= UITokens.SETTINGS_STEPPER_BOX, "B22: %s is a %dpx framed box (%s)" % [part, UITokens.SETTINGS_STEPPER_BOX, stepper.size])
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
	ck(_segments(opts, "Display Mode").size() == 3, "three display modes: Windowed / Fullscreen / Borderless")
	ck(_press(opts, "Display Mode", "Fullscreen"), "Fullscreen cell pressed")
	for i in 4: await process_frame
	ck(module.settings["display_mode"] == "fullscreen", "fullscreen stored")
	ck(_active_segment(opts, "Display Mode").ends_with("Fullscreen"), "segment shows the new state")
	ck(_press(opts, "Display Mode", "Windowed"), "Windowed cell pressed")
	for i in 4: await process_frame
	ck(module.settings["display_mode"] == "windowed", "windowed stored")
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
	# B96: кожна дія з біндингом має свою читабельну назву (ключ перекладу), а не capitalize() свого id.
	var list: Node = input_menu.get_node(^"%InputActionsList")
	var uk_po: Translation = load("res://SampleProject/Resources/Translations/uk.po")
	var unnamed: Array = []
	var untranslated: Array = []
	for action: StringName in list._get_all_action_names(false):
		if InputMap.action_get_events(action).is_empty():
			continue
		if not action in list.input_action_names:
			unnamed.append(action)
			continue
		if uk_po.get_message(list.action_name_map[action]) == "":
			untranslated.append(list.action_name_map[action])
	ck(unnamed.is_empty(), "B96: every bound action has a readable name in input_options_menu.tscn %s" % str(unnamed))
	ck(untranslated.is_empty(), "B96: every readable action name is in uk.po %s" % str(untranslated))
	var shown: Array = []
	for row in _action_rows(list).slice(1):
		shown.append(row.get_child(0).text)
	ck(shown.has("Next Dialogue Line") and not shown.has("Dq Accept") and not shown.has("Save Delete"),
			"B96: rows read Next Dialogue Line, not Dq Accept / Save Delete %s" % str(shown))

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

	print("[20] B12: header icon is TEXT_PRIMARY 64x64, no blue stock colours (#88)")
	var icon_tints: Array = []
	for tab in opts.TABS:
		opts.switch_to_tab(tab.id)
		for i in 2: await process_frame
		var tint: Color = opts._header_icon.modulate * opts._header_icon.self_modulate
		ck(opts._header_icon.modulate == UITokens.TEXT_PRIMARY and opts._header_icon.self_modulate == Color.WHITE
				and opts._header_icon.size == Vector2(UITokens.SETTINGS_HEADER_ICON, UITokens.SETTINGS_HEADER_ICON),
				"%s header icon is TEXT_PRIMARY, %s px (Figma 218:4264)" % [tab.id, opts._header_icon.size])
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
	await _device_tabs(input_menu)

	print("[9] B118: a change with no slot save at all survives a restart")
	for slot in range(1, save_system.get_slot_count() + 1):
		ck(not save_system.slot_has_save(slot), "slot %d has no save" % slot)
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	_row(opts, "Music").get_node(^"Slider/Value").value = 25.0
	for i in 4: await process_frame
	# Зміна сама записала файл налаштувань — без save_game_settings() з тесту.
	ck(FileAccess.file_exists(save_system.get_settings_path()), "the change wrote %s" % save_system.get_settings_path())
	ck(not save_system.slot_has_save(save_system.current_slot), "no slot file was created")
	module.settings["music_volume"] = 0.99
	save_system.load_game_settings()
	await process_frame
	ck(absf(float(module.settings["music_volume"]) - 0.25) < 0.01,
			"reloaded value restored (%.2f)" % module.settings["music_volume"])
	opts.switch_to_tab("audio")
	for i in 4: await process_frame
	ck(_row(opts, "Music").get_node(^"Slider/Value").value == 25.0, "UI reflects the reloaded value")

	await _every_row(opts, module, save_system, loc)

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
	# D117 (#50 order 6): рядки — копії шаблонів зі сцени, розміри шаблонів — з токенів.
	ck(src.find(".new()") == -1, "D117: no row node or stylebox is built in options_component.gd")
	for spec in [[^"%Tab", Vector2(UITokens.SETTINGS_SIDEBAR_WIDTH, UITokens.SETTINGS_TAB_HEIGHT)],
			[^"%Tab/Pointer", Vector2.ONE * UITokens.SETTINGS_POINTER],
			[^"%SegmentRow", Vector2(0, UITokens.SETTINGS_CHOICE_ROW_HEIGHT)],
			[^"%SegmentRow/Row/Segments/Cells/Cell0", Vector2(UITokens.SETTINGS_SEGMENT_MIN_WIDTH, 0)],
			[^"%StepperRow/Row/Stepper/Prev", Vector2.ONE * UITokens.SETTINGS_STEPPER_BOX],
			[^"%StepperRow/Row/Stepper/Value", Vector2(UITokens.SETTINGS_STEPPER_WIDTH, 0)],
			[^"%StepperRow/Row/Stepper/Next", Vector2.ONE * UITokens.SETTINGS_STEPPER_BOX],
			[^"%SliderRow", Vector2(0, UITokens.SETTINGS_SLIDER_ROW_HEIGHT)],
			[^"%SliderRow/Row/Slider/Minus", Vector2.ONE * UITokens.SETTINGS_STEPPER_BOX],
			[^"%SliderRow/Row/Slider/Value", Vector2(UITokens.SETTINGS_SLIDER_WIDTH, 0)],
			[^"%SliderRow/Row/Slider/Plus", Vector2.ONE * UITokens.SETTINGS_STEPPER_BOX],
			[^"%SliderRow/Row/Slider/Readout", Vector2(UITokens.SETTINGS_READOUT_WIDTH, 0)],
			[^"%BrightnessPreview/Dark/Swatch", UITokens.SETTINGS_PREVIEW_SIZE],
			[^"%BrightnessPreview/Bright/Swatch", UITokens.SETTINGS_PREVIEW_SIZE],
			[^"%BrightnessPreview/Dark/Swatch/Compass", Vector2.ONE * UITokens.SETTINGS_PREVIEW_ICON]]:
		var size: Vector2 = (opts.get_node(spec[0]) as Control).custom_minimum_size
		ck(size == spec[1], "D117: template %s is %s, tokens say %s" % [spec[0], size, spec[1]])
	var tab_box: Vector2 = (opts._tab_buttons["display"].button as Button).custom_minimum_size  # %Tab/Button, перейменована
	ck(tab_box == Vector2.ONE * UITokens.SETTINGS_TAB_BOX, "D117: tab button is %s, tokens say %d" % [tab_box, UITokens.SETTINGS_TAB_BOX])

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
		for i in 10: await process_frame
	# B64: кнопка раніше лише зберігала налаштування; тепер — як Misc: спершу підтвердження.
	var confirm: Node = ui.get_modal_layer().active_modal
	ck(confirm != null, "Exit to Main Menu asks for confirmation")
	if confirm:
		confirm.confirmed.emit()
		for i in 20: await process_frame
	var landed: String = current_scene.scene_file_path if current_scene else "<none>"
	ck(landed.ends_with("MainMenu.tscn"), "landed on MainMenu (%s)" % landed)
	ck(get_nodes_in_group("game_menu").is_empty() and get_nodes_in_group("settings_screen").is_empty(),
			"no Game Menu or in-game Settings left over the main menu")
	ck(not paused, "main menu is not frozen")

	print("[17] Main Menu → Options: Controls keeps Restore on screen, the scrollbar is visible (Sapega, 2026-10-16)")
	current_scene.options_button_up()
	await create_timer(1.0).timeout
	opts = get_first_node_in_group("settings_screen")
	opts.switch_to_tab("controls")
	for i in 12: await process_frame
	# MainMenu.tscn → OptionsPanel (WindowPanel): Restore лежить усередині її внутрішнього відступу.
	var options_panel: PanelContainer = opts.get_parent()
	var pad: float = options_panel.get_theme_stylebox("panel").content_margin_bottom
	var inner: Rect2 = root.get_visible_rect().grow(-pad)
	var restore: Control = opts.find_child("RestoreButton", true, false)
	ck(pad > 0.0 and inner.encloses(restore.get_global_rect()), "Restore Default Settings inside the panel padding %d (%s)" % [pad, restore.get_global_rect()])
	var list_bar: VScrollBar = opts.find_child("InputActionsList", true, false).get_v_scroll_bar()
	ck(list_bar.is_visible_in_tree(), "Controls list scrolls with a visible scrollbar")
	var grabber: StyleBoxFlat = list_bar.get_theme_stylebox("grabber")
	ck(grabber.bg_color == UITokens.ACCENT, "scrollbar grabber is color/accent (Figma 222:4768, #79)")
	_done()


## Комірки рядка дії на Controls: тексти кнопок прив'язок (без назви дії).
## Settings plan slice 1 (GitHub #100): кожен рядок — зміна видна одразу, переживає перезапуск,
## Restore Default Settings повертає типове значення. Controls мають власний Reset (D397) — [21].
## Клітинка за номером — підписи залежать від мови інтерфейсу.
func _press_at(opts: Node, title: String, index: int) -> bool:
	var cells: Array = _segments(opts, title)
	if index < 0 or index >= cells.size():
		return false
	cells[index].pressed.emit()
	return true


func _every_row(opts: Node, module: Node, save_system: Node, loc: Node) -> void:
	print("[22] every row: change → applied → restart round trip → Restore (settings plan slice 1)")
	var display: Node = root.get_node("DisplayManager")
	var audio: Node = root.get_node("AudioManager")
	var vsync_seen: Array[bool] = []
	display.vsync_changed.connect(func(on: bool) -> void: vsync_seen.append(on))
	var slot_path: String = save_system.get_slot_path(save_system.current_slot)

	opts.switch_to_tab("display")
	for i in 3: await process_frame
	ck(_press_at(opts, "Display Mode", 2), "Borderless cell pressed")
	for i in 3: await process_frame
	ck(module.settings["display_mode"] == "borderless" and display.display_mode == "borderless",
			"Borderless stored and applied (%s)" % display.display_mode)
	ck(_segments(opts, "Display Mode")[2].theme_type_variation == &"SettingsSegmentOn", "segment shows Borderless")
	ck((_row(opts, "Resolution").get_node(^"Stepper/Next") as Button).disabled, "Resolution locked in Borderless")
	if DisplayServer.get_name() != "headless":
		ck(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "window is borderless fullscreen")
	_press_at(opts, "Display Mode", 0)
	for i in 3: await process_frame
	_row(opts, "Resolution").get_node(^"Stepper/Next").pressed.emit()
	await process_frame
	ck(module.settings["resolution"] == "2560x1440" and display.resolution == Vector2i(2560, 1440),
			"Resolution 2560x1440 stored and applied (%s)" % display.resolution)
	_press_at(opts, "Display Mode", 1)
	for i in 3: await process_frame
	ck(display.display_mode == "fullscreen", "Fullscreen applied")
	_press_at(opts, "VSync", 1)
	for i in 3: await process_frame
	ck(module.settings["vsync"] == false and vsync_seen.back() == false, "VSync off stored and applied")
	_row(opts, "Frame Rate Limit").get_node(^"Stepper/Next").pressed.emit()
	await process_frame
	ck(module.settings["fps_limit"] == 120 and Engine.max_fps == 120, "Frame Rate Limit 120 applied (%d)" % Engine.max_fps)
	# D428: одна гамма поверх світу й UI — шар DisplayManager, не сцена.
	var overlay: ColorRect = display.get_node(^"%Brightness")
	ck(not overlay.visible, "Brightness 50: no overlay drawn")
	ck((overlay.get_parent() as CanvasLayer).layer > 100, "brightness layer above HUD, menus and transitions")
	_row(opts, "Screen Brightness").get_node(^"Slider/Value").value = 80.0
	await process_frame
	var gamma: float = (overlay.material as ShaderMaterial).get_shader_parameter(&"gamma")
	ck(module.settings["brightness"] == 80 and display.brightness == 80 and overlay.visible
			and absf(gamma - pow(2.0, 0.6)) < 0.001, "Brightness 80 stored and applied (gamma %.3f)" % gamma)
	var preview: Node = opts._list.find_child("BrightnessPreview", true, false)
	var captions: Array = []
	for column in ["Dark", "Bright"]:
		var caption: Label = preview.get_node_or_null(NodePath(column + "/Caption")) if preview else null
		var compass: TextureRect = preview.get_node_or_null(NodePath(column + "/Swatch/Compass")) if preview else null
		captions.append("%s:%s" % [caption.text if caption else "-", compass != null and compass.texture != null])
	ck(captions == ["DARK:true", "BRIGHT:true"], "DARK / BRIGHT preview swatches with the compass (%s)" % str(captions))

	opts.switch_to_tab("audio")
	for i in 3: await process_frame
	var volumes := {"Master Volume": 30.0, "Music": 20.0, "Sound Effects": 10.0, "Ambient": 40.0}
	for title in volumes:
		_row(opts, title).get_node(^"Slider/Value").value = volumes[title]
	for i in 3: await process_frame
	ck(absf(audio.get_master_volume() - 0.3) < 0.02 and absf(audio.get_music_volume() - 0.2) < 0.02
			and absf(audio.get_sfx_volume() - 0.1) < 0.02, "three volumes applied to their buses")
	var ambience: int = AudioServer.get_bus_index(&"Ambience")
	ck(absf(audio.get_ambient_volume() - 0.4) < 0.02 and absf(float(module.settings["ambient_volume"]) - 0.4) < 0.01
			and AudioServer.get_bus_volume_db(ambience) < -6.0 - 7.0, "Ambient 40 on the Ambience bus, under its −6 dB mix (D427)")

	opts.switch_to_tab("game")
	for i in 3: await process_frame
	var lang: String = "uk" if loc.get_language() != "uk" else "en"
	ck(_press_at(opts, "Language", Array(loc.get_available_languages()).find(lang)), "Language cell pressed")
	for i in 3: await process_frame
	ck(TranslationServer.get_locale().begins_with(lang), "locale %s applied" % TranslationServer.get_locale())
	# Підписи клітинок перекладені — натискаємо за індексом (0 — On, 1 — Off).
	# D746: Hints — у вкладці Game, де стояли Tutorial Windows; за замовчуванням On.
	ck(_row(opts, "Hints") != null and _row(opts, "Tutorial Windows") == null and module.default_settings["hints"] == true
			and not module.settings.has("tutorial_windows"), "Hints row in Game, On by default; no Tutorial Windows row (D746)")
	_press_at(opts, "Hints", 1)
	for i in 3: await process_frame
	_press_at(opts, "Damage Numbers", 1)
	for i in 3: await process_frame
	ck(module.settings["text_speed"] == "default" and module.settings["screen_shake"] == true,
			"Text Speed Default and Screen Shake On by default")
	var box_rate: Array[int] = [_typed_in_one_second()]
	_press_at(opts, "Text Speed", 1)
	for i in 3: await process_frame
	box_rate.append(_typed_in_one_second())
	ck(box_rate[0] == 48 and module.settings["text_speed"] == "quick" and box_rate == [48, 96],
			"D738: Default types 48 letters/s (was 24), Quick 96 (%s)" % str(box_rate))
	# D739: Auto-Advance — рядок одразу за Text Speed, On за замовчуванням, Off зберігається.
	ck(_row(opts, "Auto-Advance") != null and module.settings["auto_advance"] == true, "D739: Auto-Advance row present, On by default")
	_press_at(opts, "Auto-Advance", 1)
	for i in 3: await process_frame
	ck(module.settings["auto_advance"] == false and not module.auto_advance_enabled(), "D739: Auto-Advance Off stored")
	_press_at(opts, "Auto-Advance", 0)
	for i in 3: await process_frame
	ck(module.settings["auto_advance"] == true, "D739: Auto-Advance On again")
	ck(is_equal_approx(SPEECH_BUBBLE.seconds_for("x".repeat(40)) / module.text_speed_factor(), 2.0),
			"Text Speed Quick: a 40-letter cloud line holds 2 s, not 4 s (D178 / D425)")
	ck(await _camera_kicks(), "Screen Shake On: a hit kicks the camera")
	_press_at(opts, "Screen Shake", 1)
	for i in 3: await process_frame
	ck(module.settings["screen_shake"] == false and not await _camera_kicks(), "Screen Shake Off: no camera kick (D426)")
	ck(_row(opts, "Auto-Save") != null, "Auto-Save row present (D413)")
	ck(module.settings["auto_save"] == false, "Auto-Save is Off by default")
	_press_at(opts, "Auto-Save", 0)
	for i in 3: await process_frame
	ck(module.settings["hints"] == false and module.settings["damage_numbers"] == false
			and module.settings["auto_save"] == true, "Hints off, Damage Numbers off, Auto-Save on stored")
	# Auto-Save діє одразу: наступний перехід між кімнатами пише сейв поверх заглушки.
	FileAccess.open(slot_path, FileAccess.WRITE).store_string(var_to_str({"current_room": ":test"}))
	save_system._on_room_entered("probe")
	var saved: Dictionary = str_to_var(FileAccess.get_file_as_string(slot_path))
	ck(saved["current_room"] != ":test", "Auto-Save On: a room change saved the game (%s)" % saved["current_room"])
	ck(not saved.has("game_settings"), "B118: the slot file carries no settings")

	print("[22b] restart round trip")
	var changed: Dictionary = module.settings.duplicate()
	# Кожна зміна вже записала файл налаштувань; save_game_settings() тест не кличе.
	ck(str_to_var(FileAccess.get_file_as_string(save_system.get_settings_path())) == changed,
			"the settings file holds every change")
	# «Перезапуск»: модуль і живий стан — знову типові, далі SaveSystem читає файл налаштувань, як під час старту.
	module.settings = module.default_settings.duplicate()
	module.apply_settings()
	ck(display.display_mode == "windowed" and Engine.max_fps == 60, "live state reset before the reload")
	save_system.load_game_settings()
	await process_frame
	ck(module.settings == changed, "every key comes back from the settings file")
	ck(display.display_mode == "fullscreen" and display.resolution == Vector2i(2560, 1440) and Engine.max_fps == 120
			and vsync_seen.back() == false, "display rows re-applied after the reload")
	ck(absf(audio.get_music_volume() - 0.2) < 0.02 and absf(audio.get_ambient_volume() - 0.4) < 0.02,
			"volumes re-applied after the reload")
	ck(display.brightness == 80 and display.get_node(^"%Brightness").visible, "brightness re-applied after the reload")
	ck(_typed_in_one_second() == 48 and not await _camera_kicks(), "Text Speed Quick and Screen Shake Off act after the reload")
	ck(TranslationServer.get_locale().begins_with(lang), "language re-applied after the reload")
	opts.switch_to_tab("game")
	for i in 3: await process_frame
	ck(_segments(opts, "Auto-Save")[0].theme_type_variation == &"SettingsSegmentOn", "Auto-Save row shows On after the reload")
	ck(module.settings["hints"] == false and _segments(opts, "Hints")[1].theme_type_variation == &"SettingsSegmentOn",
			"Hints Off survives the reload (D746)")

	print("[22c] Restore Default Settings puts every row back")
	opts._on_restore_pressed()
	for i in 3: await process_frame
	ck(module.settings == module.default_settings, "every key back to default")
	ck(display.display_mode == "windowed" and display.resolution == Vector2i(1920, 1080) and Engine.max_fps == 60
			and vsync_seen.back() == true, "display defaults applied")
	ck(absf(audio.get_master_volume() - float(module.default_settings["master_volume"])) < 0.02
			and absf(audio.get_music_volume() - float(module.default_settings["music_volume"])) < 0.02
			and absf(audio.get_sfx_volume() - float(module.default_settings["sfx_volume"])) < 0.02, "volume defaults applied")
	ck(TranslationServer.get_locale().begins_with(String(module.default_settings["language"])), "default language applied")
	ck(absf(audio.get_ambient_volume() - 1.0) < 0.01 and display.brightness == 50
			and not display.get_node(^"%Brightness").visible, "Ambient 100 and Brightness 50 restored")
	ck(_typed_in_one_second() == 24 and await _camera_kicks(), "Text Speed Default and Screen Shake On restored")
	var on_disk: Dictionary = str_to_var(FileAccess.get_file_as_string(save_system.get_settings_path()))
	ck(on_disk == module.default_settings, "defaults written to the settings file")
	FileAccess.open(slot_path, FileAccess.WRITE).store_string(var_to_str({"current_room": ":test"}))
	save_system._on_room_entered("probe")
	ck(str_to_var(FileAccess.get_file_as_string(slot_path))["current_room"] == ":test", "Auto-Save Off: a room change saves nothing")
	module.settings["hints"] = false  # D746: no «?» tips in the rest of the test


const SPEECH_BUBBLE := preload("res://SampleProject/UI/Components/speech_bubble.gd")
## load(), не preload: GameDialogueBox.gd читає автолоад SaveSystem, а скрипт тесту компілюється ще до автолоадів.
const DIALOGUE_BOX := "res://SampleProject/Scenes/UI/dialogue_box.tscn"


## Скільки літер вікно діалогу гри набирає за 1 с (D254 / D425) — окремий екземпляр, годинник крутить тест.
func _typed_in_one_second() -> int:
	var box: Node = (load(DIALOGUE_BOX) as PackedScene).instantiate()
	root.add_child(box)
	box.set_process(false)
	box.settings.letters_per_second = UITokens.DIALOGUE_LETTERS_PER_SECOND  # D738 (аддон міг лишити тег [speed])
	box.text = "x".repeat(200)
	box.start_progressing(0)
	box._process(1.01)  # трохи понад 1 с: сума кроків 1/48 с з плаваючою комою недобирає останню літеру
	var typed: int = box._text.visible_characters
	box.free()
	return typed


## D426: чи зсуває VFXHooks._kick_camera камеру гри (кік триває KICK_TIME).
func _camera_kicks() -> bool:
	var camera: Camera2D = root.get_viewport().get_camera_2d()
	var pause_mode: Node.ProcessMode = camera.process_mode
	camera.process_mode = Node.PROCESS_MODE_ALWAYS  # меню паузи відкрите — твін камери інакше стоїть
	camera.offset = Vector2.ZERO
	root.get_node("GameManager/VFXHooks")._kick_camera(Vector2.RIGHT, 8.0)
	var moved := false
	for i in 4:
		await process_frame
		moved = moved or camera.offset != Vector2.ZERO
	for i in 20: await process_frame  # кік догасає (KICK_TIME)
	camera.process_mode = pause_mode
	camera.offset = Vector2.ZERO
	return moved


func _binding_cells(list: Node, title: String) -> Array:
	for row in list.get_node(^"%ParentBoxContainer").get_children():
		if row.visible and not row.is_queued_for_deletion() and row.get_child(0).text == title:
			return row.get_children().slice(1).map(func(b: Button) -> String: return b.text.strip_edges())
	return []


## D193, B19: дві вкладки пристроїв; призначення й Reset — лише свого пристрою. player_config.cfg гравця
## тест переписує під час переназначення — зберігаємо його байти й повертаємо наприкінці.
func _device_tabs(input_menu: Node) -> void:
	print("[21] B19 / D193: Controls has Keyboard & Mouse and Gamepad tabs, each with its own device only")
	const CONFIG := "user://player_config.cfg"
	var saved_config: PackedByteArray = FileAccess.get_file_as_bytes(CONFIG) if FileAccess.file_exists(CONFIG) else PackedByteArray()
	var saved_map: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		saved_map[action] = InputMap.action_get_events(action)
	var list: Node = input_menu.get_node(^"%InputActionsList")
	var window: Node = input_menu.get_node(^"KeyAssignmentWindow")
	# Назви кнопок миші перекладає рушій (у uk «ЛКМ») — порівнюємо з тим, що дає InputEventHelper.
	var lmb_event := InputEventMouseButton.new()
	lmb_event.button_index = MOUSE_BUTTON_LEFT
	var lmb: String = InputEventHelper.get_text(lmb_event)
	ck(input_menu.get_node(^"%KeyboardTab").is_visible_in_tree() and input_menu.get_node(^"%GamepadTab").is_visible_in_tree(),
			"Keyboard & Mouse and Gamepad tabs are shown")
	ck(not input_menu.is_pad() and input_menu.get_node(^"%KeyboardTab").theme_type_variation == &"SettingsSegmentOn",
			"Keyboard & Mouse is the open tab")
	var pad_shown: Array = []
	for action: StringName in list.input_action_names:
		for event in list.device_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				pad_shown.append(action)
	ck(pad_shown.is_empty(), "the keyboard tab lists no pad binding %s" % str(pad_shown))
	ck(_binding_cells(list, "Attack") == [lmb, "", ""],
			"B19: Attack on the keyboard tab = the left mouse button only %s" % str(_binding_cells(list, "Attack")))
	var key_r := InputEventKey.new()
	key_r.physical_keycode = KEY_J  # вільна клавіша: K — open_skills_tab (D742)
	key_r.pressed = true
	var pad_touch := InputEventJoypadButton.new()
	pad_touch.button_index = JOY_BUTTON_TOUCHPAD
	pad_touch.pressed = true
	var mouse_x := InputEventMouseButton.new()
	mouse_x.button_index = MOUSE_BUTTON_XBUTTON1
	mouse_x.pressed = true
	ck(window._is_recordable_input(key_r) and window._is_recordable_input(mouse_x) and not window._is_recordable_input(pad_touch),
			"the keyboard tab's Assign window takes keys and mouse buttons, not the pad")
	# Клавіатура: друга комірка Attack ← J; геймпад Attack не чіпається.
	# Як після кліку на комірку (_on_button_pressed), але без вікна Assign: подію даємо самі.
	list.editing_action_name = "attack"
	list.editing_action_group = 1
	list.add_action_event("J", key_r)
	for i in 2: await process_frame
	ck(_binding_cells(list, "Attack") == [lmb, "J", ""], "a keyboard rebind fills the keyboard slot %s" % str(_binding_cells(list, "Attack")))

	input_menu.get_node(^"%GamepadTab").pressed.emit()
	for i in 3: await process_frame
	ck(input_menu.is_pad() and window.pad, "Gamepad tab opens; the Assign window listens to the pad")
	ck(_binding_cells(list, "Attack") == ["Button X", "", ""],
			"B19: Attack on the gamepad tab = Button X only %s" % str(_binding_cells(list, "Attack")))
	ck(_binding_cells(list, "Move Up") == ["Left Stick Up", "Dpad Up", ""], "Move Up on the gamepad tab %s" % str(_binding_cells(list, "Move Up")))
	var xs: Dictionary = {}
	for row in list.get_node(^"%ParentBoxContainer").get_children():
		if row.visible and not row.is_queued_for_deletion():
			xs[roundi(row.get_child(1).global_position.x)] = true
	ck(xs.size() == 1, "every row's first cell starts at one x, long names included %s" % str(xs.keys()))
	ck(window._is_recordable_input(pad_touch) and not window._is_recordable_input(key_r) and not window._is_recordable_input(mouse_x),
			"the gamepad tab's Assign window takes the pad only")
	list.editing_action_name = "attack"
	list.editing_action_group = 0
	list.add_action_event("Touchpad", pad_touch)
	for i in 2: await process_frame
	var attack: Array = InputMap.action_get_events(&"attack").map(func(e: InputEvent) -> String: return e.as_text())
	ck(attack.size() == 3 and attack[2] == pad_touch.as_text() and not attack.has(saved_map[&"attack"][1].as_text()),
			"a pad rebind replaces the pad button, the keyboard and mouse stay first %s" % str(attack))
	list.reset()
	for i in 2: await process_frame
	ck(_binding_cells(list, "Attack") == ["Button X", "", ""], "gamepad Reset restores Button X")
	ck(InputMap.action_get_events(&"attack").any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_J),
			"gamepad Reset leaves the keyboard rebind")
	input_menu.get_node(^"%KeyboardTab").pressed.emit()
	for i in 3: await process_frame
	list.reset()
	for i in 2: await process_frame
	ck(_binding_cells(list, "Attack") == [lmb, "", ""], "keyboard Reset restores the keyboard tab")
	# Повертаємо все, як було до тесту: InputMap і player_config.cfg гравця.
	for action: StringName in saved_map:
		InputMap.action_erase_events(action)
		for event: InputEvent in saved_map[action]:
			InputMap.action_add_event(action, event)
	if saved_config.is_empty():
		DirAccess.remove_absolute(CONFIG)
	else:
		FileAccess.open(CONFIG, FileAccess.WRITE).store_buffer(saved_config)
	PlayerConfig.config_file = null
	list._build_assigned_input_events()
	list.set_pad(false)
	for i in 3: await process_frame


func _done() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
