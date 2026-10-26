extends SceneTree

## Паритет геймпада (BACKLOG 24): кожна дія InputMap, яку бере гра, має кнопку геймпада; кожен екран
## проходиться лише фокусом і кнопками геймпада (InputEventJoypadButton через root.push_input); підказки й бейджі
## нижньої панелі називають кнопки пристрою, яким грали останнім.
##   godot --headless --path . --script res://SampleProject/UI/verify_gamepad_parity.gd
## Екрани, які вже ганяють геймпадом інші verify (не дублюються тут): інвентар — verify_use_item, екіпірування —
## verify_equip_picker, навички й Accept (Y) — verify_skill_screen / verify_skill_trees_ui / verify_attributes,
## журнал — verify_journal_sections, крамниця (interact) — verify_shop, хранителі клятв — verify_oath, скрині й
## «You obtained» — verify_chests / verify_gift_popup, вікна туторіалу — verify_tutorial_hints, сторінка Controls —
## verify_onboarding, пропуск кат-сцени (утримання Y) — verify_cutscene, діалог (A) — verify_gamepad.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const TEST_DIR := "user://verify_gamepad_parity_saves/"
## ui_*, які гра бере (решта вбудованих ui_* — текстові поля, графи, діалоги файлів — у грі не вживаються).
const UI_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]
## Дії лише для клавіатури й миші: курсор геймпад не рухає, показувати його з пада нема чого (D417).
const MOUSE_ONLY: Array[StringName] = [&"toggle_mouse"]
const CODE_DIRS := ["res://SampleProject/Scripts", "res://SampleProject/UI/Components", "res://addons/dialogue_quest/scripts"]

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	var ss: Node = root.get_node("ServiceLocator").get_save_system()
	ss.set_save_dir(TEST_DIR)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: підказки банером, без вікон
	_actions()
	await _main_menu()
	var game: Node = await Kit.boot(self)
	await _game_menu(game)
	await _forge()
	await _choice_menu()
	await _game_over()
	await _demo_end()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _has_pad(action: StringName) -> bool:
	return InputMap.action_get_events(action).any(func(e: InputEvent) -> bool:
		return e is InputEventJoypadButton or e is InputEventJoypadMotion)


## Тиснути [param button], доки [param done] не скаже «так» (не більше [param tries] разів).
func _pad_until(button: JoyButton, done: Callable, tries: int = 12) -> bool:
	for i in tries:
		if done.call():
			return true
		await Kit.pad(self, button)
	return done.call()


## [0] Кожна дія з InputMap і кожна дія, яку називає код гри, має подію геймпада.
func _actions() -> void:
	print("[0] Every gameplay / menu action has a joypad event")
	var missing: Array = []
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_") and action not in UI_ACTIONS:
			continue
		if not _has_pad(action) and action not in MOUSE_ONLY:
			missing.append(action)
	ck(missing.is_empty(), "every InputMap action the game owns has a pad event (missing: %s)" % [missing])
	var used := {}
	var pattern := RegEx.create_from_string("is_action(?:_pressed|_just_pressed|_released|_just_released)?\\(\\s*&?\"([a-z0-9_]+)\"")
	for dir in CODE_DIRS:
		for path in _scripts(dir):
			for m in pattern.search_all(FileAccess.get_file_as_string(path)):
				used[m.get_string(1)] = path
	var no_pad: Array = []
	for action in used:
		if InputMap.has_action(action) and not _has_pad(action) and StringName(action) not in MOUSE_ONLY:
			no_pad.append("%s (%s)" % [action, used[action].get_file()])
	ck(used.size() > 20, "actions named in code scanned (%d)" % used.size())
	ck(no_pad.is_empty(), "every action the code reacts to has a pad event (missing: %s)" % [no_pad])


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out


## [1] Головне меню й налаштування (дисплей, мова) лише геймпадом.
func _main_menu() -> void:
	print("[1] Main menu and Settings with the pad only")
	set_meta("show_title_screen", true)
	var menu: Control = load("res://SampleProject/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await Kit.frames(self, 4)
	await Kit.pad(self, JOY_BUTTON_A)
	await create_timer(1.0).timeout
	ck(menu.menu.visible and _focus() != null and _focus().get_parent() == menu.menu, "A leaves the splash, a menu item has focus (%s)" % _focus())
	ck(InputGlyphs.using_gamepad, "the pad is the last device")
	var on_settings := func() -> bool: return _focus() != null and _focus().text == "Settings"
	ck(await _pad_until(JOY_BUTTON_DPAD_DOWN, on_settings), "D-pad reaches Settings")
	await Kit.pad(self, JOY_BUTTON_A)
	await create_timer(0.8).timeout
	var opts: Control = menu.options_component
	ck(opts != null and _focus() != null and opts.is_ancestor_of(_focus()), "Settings open with focus inside (%s)" % _focus())

	# Дисплей: від вкладки до комірки VSync; перемикач перебудовує рядок — фокус лишається на ньому
	opts.switch_to_tab("display")
	opts.focus_current_tab()
	await Kit.frames(self, 2)
	var in_vsync := func() -> bool: return _focus() != null and str(_focus().get_path()).contains("VSyncRow")
	await Kit.pad(self, JOY_BUTTON_DPAD_RIGHT)
	ck(_focus() != null and str(_focus().get_path()).contains("Display ModeRow"), "D-pad right from the tab enters the first row (%s)" % _focus())
	ck(await _pad_until(JOY_BUTTON_DPAD_DOWN, in_vsync), "D-pad reaches the VSync row (%s)" % _focus())
	var vsync: bool = opts._cfg_get("vsync")
	await Kit.pad(self, JOY_BUTTON_A)
	ck(opts._cfg_get("vsync") != vsync or _focus().name == ("Cell0" if vsync else "Cell1"), "A on a VSync cell applies it")
	ck(in_vsync.call(), "focus stays on the VSync row after it rebuilds (%s)" % _focus())
	# назад, як було
	var back_cell := "Cell0" if vsync else "Cell1"
	await _pad_until(JOY_BUTTON_DPAD_LEFT if back_cell == "Cell0" else JOY_BUTTON_DPAD_RIGHT,
			func() -> bool: return _focus().name == back_cell, 2)
	await Kit.pad(self, JOY_BUTTON_A)
	ck(opts._cfg_get("vsync") == vsync, "VSync restored")

	# Мова: вкладка Game, рядок Language, A на вибраній мові — рядок перебудовується, фокус лишається
	opts.switch_to_tab("game")
	opts.focus_current_tab()
	await Kit.frames(self, 2)
	var in_language := func() -> bool: return _focus() != null and str(_focus().get_path()).contains("LanguageRow")
	await Kit.pad(self, JOY_BUTTON_DPAD_RIGHT)
	ck(in_language.call(), "D-pad right from the Game tab enters the Language row (%s)" % _focus())
	var language: String = opts._cfg_get("language")
	var cell: String = _focus().name
	await Kit.pad(self, JOY_BUTTON_A)
	await Kit.frames(self, 2)
	ck(in_language.call() and _focus().name == cell, "focus stays on the Language cell after the row rebuilds (%s)" % _focus())
	if opts._cfg_get("language") != language:
		opts._on_language_changed(language)

	await Kit.pad(self, JOY_BUTTON_B)
	await create_timer(0.8).timeout
	ck(menu.menu.visible and _focus() != null and _focus().get_parent() == menu.menu, "B closes Settings, focus back on the menu (%s)" % _focus())
	await Kit.pad(self, JOY_BUTTON_B)
	await Kit.frames(self, 4)
	var modal: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	ck(modal != null and _focus() != null and modal.is_ancestor_of(_focus()), "B on the main menu asks to quit, focus in the dialog")
	await Kit.pad(self, JOY_BUTTON_B)
	await Kit.frames(self, 6)
	ck(root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal == null and _focus() != null
			and _focus().get_parent() == menu.menu, "B cancels the quit dialog, focus back on the menu")
	menu.queue_free()
	await Kit.frames(self, 2)


## [2] Ігрове меню: Start, кожна вкладка D-pad + A, вміст і назад кнопкою B; бейджі нижньої панелі й хотбара.
func _game_menu(game: Node) -> void:
	print("[2] Game Menu tabs, content and back with the pad; bottom-bar and hotbar badges follow the device")
	var hotbar: Node = get_first_node_in_group(&"skill_hotbar")
	await Kit.key(self, KEY_SHIFT)
	ck(not InputGlyphs.using_gamepad and hotbar.get_node("%Slots/Bind1/Badge/Key").text == "1", "keyboard: hotbar slot 1 reads 1")
	await Kit.pad(self, JOY_BUTTON_X)
	await create_timer(0.6).timeout
	ck(InputGlyphs.using_gamepad and hotbar.get_node("%Slots/Bind1/Badge/Key").text == "RT"
			and hotbar.get_node("%Slots/Bind5/Badge/Key").text == "LT+RT"
			and get_first_node_in_group(&"player_vitals_panel").get_node("%AssistChip/Badge/Key").text == "LT",
			"pad: hotbar slot 1 reads RT, slot 5 LT+RT (D549), the F chip LT")

	# Вкладки, які сюжет ще не відкрив, відкриваємо прапорцями до відкриття меню
	var probe: Node = load("res://SampleProject/Scenes/Menus/Game/game_menu.tscn").instantiate()
	for node in probe.find_children("*", "Button", true, false):
		if node.has_meta("unlock_flag"):
			game.set_quest_flag(node.get_meta("unlock_flag"), true)
	probe.free()
	await Kit.pad(self, JOY_BUTTON_START)
	var menu: Node = null
	for i in 60:
		menu = get_first_node_in_group(&"game_menu")
		if menu != null and menu.is_visible_in_tree() and _focus() != null:
			break
		await process_frame
	ck(menu != null, "Start opens the Game Menu with focus, every tab unlocked (%s)" % _focus())
	if menu == null:
		return
	# Своя нижня панель є і в панелі туторіалу — беремо видиму панель меню
	var bar: Node = menu.find_children("*", "UIBottomBar", true, false).filter(func(b: Node) -> bool: return b.is_visible_in_tree())[0]
	var badges := func() -> Array:
		return bar.get_node("%Actions").get_children().map(func(row: Node) -> String: return row.get_child(0).get_child(0).text)
	ck(badges.call() == ["LS", "A", "B"], "pad: bottom bar reads LS / A / B (%s)" % [badges.call()])

	var buttons: Array = menu._tabs.get_buttons().filter(func(b: BaseButton) -> bool: return not b.disabled and b != menu.misc_button)
	ck(buttons.size() >= 4, "content tabs open (%s)" % [buttons.map(func(b): return b.get_meta("tab"))])
	for button in buttons:
		var tab: String = button.get_meta("tab")
		var down := await _pad_until(JOY_BUTTON_DPAD_DOWN, func() -> bool: return _focus() == button, 8)
		var reached := down or await _pad_until(JOY_BUTTON_DPAD_UP, func() -> bool: return _focus() == button, 8)
		await Kit.pad(self, JOY_BUTTON_A)
		await Kit.frames(self, 2)
		ck(reached and menu.current_tab_name == tab, "%s: D-pad + A opens it" % tab)
		await Kit.pad(self, JOY_BUTTON_DPAD_RIGHT)
		await Kit.frames(self, 2)
		var panel: Node = button.get_node(button.get_meta("panel"))
		var inside: bool = _focus() != null and (_focus() == panel or panel.is_ancestor_of(_focus()))
		if menu.focus_router._find_first_focusable(panel) == null:
			ck(_focus() == button, "%s: view only — focus stays on the tab (%s)" % [tab, _focus()])
			continue
		ck(inside, "%s: D-pad right moves focus into the content (%s)" % [tab, _focus()])
		if inside:
			await Kit.pad(self, JOY_BUTTON_B)
			await Kit.frames(self, 2)
			ck(get_first_node_in_group(&"game_menu") == menu and menu.is_visible_in_tree() and _focus() is BaseButton and _focus() in menu._tabs.get_buttons(),
					"%s: B goes back to the tabs, the menu stays open (%s)" % [tab, _focus()])

	# Misc: модалка з фокусом; B закриває її, фокус — на Misc
	var on_misc := func() -> bool: return _focus() == menu.misc_button
	ck(await _pad_until(JOY_BUTTON_DPAD_DOWN, on_misc, 8) or await _pad_until(JOY_BUTTON_DPAD_UP, on_misc, 8), "D-pad reaches Misc")
	await Kit.pad(self, JOY_BUTTON_A)
	await Kit.frames(self, 3)
	var modal: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	ck(modal != null and _focus() != null and modal.is_ancestor_of(_focus()), "Misc: the list opens with focus (%s)" % _focus())
	await Kit.pad(self, JOY_BUTTON_B)
	await Kit.frames(self, 4)
	ck(_focus() == menu.misc_button, "B closes Misc, focus back on the Misc tab (%s)" % _focus())

	await Kit.key(self, KEY_DOWN)
	ck(badges.call() == ["Arrows", "Enter", "Escape"], "keyboard: the same bar reads Arrows / Enter / Escape (%s)" % [badges.call()])
	ck(hotbar.get_node("%Slots/Bind1/Badge/Key").text == "1", "keyboard: hotbar back to 1")
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(badges.call() == ["LS", "A", "B"], "pad again: LS / A / B")
	await Kit.pad(self, JOY_BUTTON_START)
	await create_timer(0.4).timeout
	ck(get_first_node_in_group(&"game_menu") == null or not get_first_node_in_group(&"game_menu").is_visible_in_tree(), "Start closes the Game Menu")


## [3] Кузня: категорії доступні D-pad ліворуч від рядків і вибираються A; перемикач станцій — LB/RB.
func _forge() -> void:
	print("[3] Forge: categories by D-pad + A, stations by LB / RB, badges name the pad")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var menu: Control = load("res://SampleProject/Scenes/Crafting/crafting_menu.tscn").instantiate()
	layer.add_child(menu)
	paused = true  # як Blacksmith.gd: кузня відкривається на паузі
	await Kit.frames(self, 6)
	var station: int = menu.station_index
	await Kit.pad(self, JOY_BUTTON_RIGHT_SHOULDER)
	ck(menu.station_index != station, "RB switches the station")
	if menu.get_rows().size() > 0:
		menu.get_rows()[0].grab_focus()
	var on_category := func() -> bool: return _focus() in menu._category_buttons
	ck(await _pad_until(JOY_BUTTON_DPAD_LEFT, on_category, 3), "D-pad left reaches the categories (%s)" % _focus())
	if on_category.call():
		var category: int = menu._category_buttons.find(_focus())
		await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
		var next: int = menu._category_buttons.find(_focus())
		await Kit.pad(self, JOY_BUTTON_A)
		ck(next != category and menu.category_index == next, "A picks the focused category (%d: %d -> %d)" % [menu.category_index, category, next])
	var bar: Node = menu.base_menu.get_node("BottomBar")
	var first: String = bar.get_node("%Actions").get_child(0).get_child(0).get_child(0).text
	ck(first == "LB/RB", "station badge reads LB/RB on the pad (%s)" % first)
	await Kit.pad(self, JOY_BUTTON_B)
	await Kit.frames(self, 3)
	layer.queue_free()
	paused = false
	await Kit.frames(self, 2)


## [4] Вибір відповіді в діалозі: фокус на першій, A вибирає.
func _choice_menu() -> void:
	print("[4] Dialogue choice menu: focus on the first answer, A picks it")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var choices: Control = load("res://addons/dialogue_quest/prefabs/ui/dialogue/components/choice_menu/choice_menu.tscn").instantiate()
	layer.add_child(choices)
	await Kit.frames(self, 2)
	var picked: Array = []
	choices.choice_made.connect(func(c: String) -> void: picked.append(c))
	choices.choices = PackedStringArray(["Yes", "No"])
	choices.show()
	await Kit.frames(self, 3)
	ck(_focus() != null and choices.is_ancestor_of(_focus()) and _focus().text == "Yes", "the first answer has focus (%s)" % _focus())
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	await Kit.pad(self, JOY_BUTTON_A)
	ck(picked == ["No"], "D-pad + A picks an answer (%s)" % [picked])
	# D721: W/S і стрілки гортають відповіді з клавіатури, Enter вибирає.
	choices.hide()
	choices.choices = PackedStringArray(["Yes", "Maybe", "No"])
	choices.show()
	await Kit.frames(self, 3)
	await Kit.key(self, KEY_S)
	ck(_focus() != null and _focus().text == "Maybe", "D721: S moves to the next answer (%s)" % (_focus().text if _focus() is Button else "-"))
	await Kit.key(self, KEY_S)
	await Kit.key(self, KEY_S)
	ck(_focus().text == "No", "D721: S stops at the last answer (%s)" % _focus().text)
	await Kit.key(self, KEY_W)
	ck(_focus().text == "Maybe", "D721: W moves back (%s)" % _focus().text)
	await Kit.key(self, KEY_UP)
	ck(_focus().text == "Yes", "D721: the Up arrow moves too (%s)" % _focus().text)
	await Kit.key(self, KEY_DOWN)
	await Kit.key(self, KEY_ENTER)
	ck(picked == ["No", "Maybe"], "D721: Enter picks the answer W/S/arrows reached (%s)" % [picked])
	layer.queue_free()
	await Kit.frames(self, 2)


## [5] Game Over: фокус на Resume, клавіша підтвердження в підвалі — за пристроєм.
func _game_over() -> void:
	print("[5] Game Over: focus on Resume, the footer key follows the device")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var screen: Control = load("res://SampleProject/Scenes/UI/game_over_screen.tscn").instantiate()
	screen.change_scenes = false
	layer.add_child(screen)
	await Kit.frames(self, 3)
	var key: Label = screen.get_node("%Footer/Keycap/KeyLabel")
	ck(_focus() != null and screen.is_ancestor_of(_focus()), "a button has focus (%s)" % _focus())
	ck(key.text == "A", "pad: footer key A (%s)" % key.text)
	await Kit.key(self, KEY_SHIFT)
	ck(key.text == "ENTER", "keyboard: footer key ENTER (%s)" % key.text)
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	layer.queue_free()
	await Kit.frames(self, 2)


## [6] Кінець демо: кнопка повернення у фокусі (A / Enter).
func _demo_end() -> void:
	print("[6] Demo end screen: the return button has focus")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var screen: Control = load("res://SampleProject/Scenes/UI/DemoEndScreen.tscn").instantiate()
	layer.add_child(screen)
	await Kit.frames(self, 3)
	ck(_focus() == screen.return_button, "ReturnButton focused (%s)" % _focus())
	layer.queue_free()
	await Kit.frames(self, 2)
