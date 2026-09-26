extends SceneTree

## Самоперевірка Journal (Phase 5.14).
##   godot --headless --path . --script res://SampleProject/UI/verify_journal.gd
##
## ⚠️ ФІКСТУРИ ТІЛЬКИ ДЛЯ ТЕСТІВ. Продакшн-даних завдань у проєкті немає,
## і цей тест підтверджує, що екран їх не вигадує.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Синтетичні записи — лише для перевірки розкладки.
const FIXTURES := [
	{"id": "t_a", "title": "Test Entry Alpha", "state": "Active",
	 "objectives": ["Test objective one", "Test objective two"],
	 "description": "Synthetic test description used only for layout QA."},
	{"id": "t_b", "title": "Test Entry Beta", "state": "Completed",
	 "objectives": ["Test objective three"], "description": ""},
	{"id": "t_c", "title": "Test Entry Gamma", "state": "", "objectives": [],
	 "description": "Entry with no objectives and no state."},
]

## Імена-заглушки з Figma, які продукт відхилив (D52/D53).
const FORBIDDEN := ["Khalahas Heroes", "Lyra", "Ashveil", "Valen", "Selene",
	"Backstory", "Path Action", "Talent", "All Chapters", "Main Story"]


func _texts(node: Node, out: Array) -> Array:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_texts(child, out)
	return out


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var tokens = load("res://SampleProject/UI/Tokens/UITokens.gd")

	print("[1] Journal opens from its existing tab")
	# Вантажимо реальну сцену, щоб прив'язка до Game.current_objective
	# перевірялась по-справжньому, а не падала у null-гілку.
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30: await process_frame
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Journal")
	for i in 10: await process_frame
	var journal: Node = get_first_node_in_group("journal_screen")
	ck(journal != null, "journal screen present")
	if journal == null:
		_done()
		return
	ck(journal.is_visible_in_tree(), "visible on the Journal tab")
	ck(menu.current_tab_name == "Journal", "menu reports the Journal tab")

	print("[2] production state invents nothing")
	ck(journal.entries.is_empty(), "no entries in production (%d)" % journal.entries.size())
	ck(journal._empty_state.visible, "honest empty state shown")
	ck(journal._empty_state.text == "No journal entries yet.",
			"empty text: %s" % journal._empty_state.text)
	ck(not journal._columns.visible, "list/detail hidden while empty")
	var seen: Array = _texts(journal, [])
	var leaked: Array = []
	for term in FORBIDDEN:
		for text in seen:
			if String(text).findn(term) >= 0:
				leaked.append(term)
				break
	ck(leaked.is_empty(), "no rejected Figma codex content (leaked: %s)" % str(leaked))
	var scene_text: String = FileAccess.open(
		"res://SampleProject/Scenes/Menus/Game/journal_component.tscn", FileAccess.READ).get_as_text()
	for term in FORBIDDEN:
		if scene_text.findn(term) >= 0:
			ck(false, "scene hardcodes '%s'" % term)
	ck(scene_text.findn("Entry_") == -1, "no quest rows baked into the .tscn")
	var src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/journal_component.gd", FileAccess.READ).get_as_text()
	ck(src.find("FIXTURES") == -1, "no fixtures live in production code")

	print("[3] empty state does not crash on interaction")
	journal.update_display()
	journal.clear_entries()
	journal._set_hint()
	journal._show_detail("nope")
	for i in 3: await process_frame
	ck(journal._empty_state.visible, "still empty and alive after poking it")

	print("[4] current objective is shown only when real")
	var game_node: Node = journal._game
	ck(game_node != null, "journal resolved the live Game node")
	if game_node == null:
		ck(false, "objective binding could not be exercised")
	else:
		game_node.set_objective("")
		journal._refresh_objective()
		await process_frame
		ck(not journal._objective_panel.visible, "empty objective hides the panel")
		game_node.set_objective("Find a way forward")
		for i in 3: await process_frame
		ck(journal._objective_panel.visible, "real objective shows the panel")
		ck(journal._objective_text.text == "Find a way forward",
				"objective text bound live (%s)" % journal._objective_text.text)
		ck(journal.entries.is_empty(),
				"objective is NOT promoted into a fake journal entry")

	print("[5] test fixtures render with no .tscn edits")
	journal.set_entries(FIXTURES)
	for i in 5: await process_frame
	ck(journal._entry_list.get_child_count() == FIXTURES.size(),
			"%d rows built dynamically" % journal._entry_list.get_child_count())
	ck(journal._columns.visible and not journal._empty_state.visible,
			"switches out of the empty state")
	var first: Button = journal._entry_list.get_child(0)
	ck(first.text == "Test Entry Alpha", "row title from data (%s)" % first.text)
	ck(first.theme_type_variation == &"ListRow", "rows use the shared ListRow variation")
	ck(journal._detail_title.text == "Test Entry Alpha", "detail shows the selected entry")
	ck(journal._detail_state.text == "ACTIVE", "state rendered (%s)" % journal._detail_state.text)
	ck(journal._objective_list.get_child_count() == 2,
			"two objectives listed (%d)" % journal._objective_list.get_child_count())

	print("[6] selection updates the detail pane")
	journal._entry_list.get_child(1).pressed.emit()
	for i in 4: await process_frame
	ck(journal.selected_id == "t_b", "selection tracked (%s)" % journal.selected_id)
	ck(journal._detail_title.text == "Test Entry Beta", "detail followed the selection")
	ck(journal._detail_state.text == "COMPLETED", "second state rendered")
	ck(not journal._detail_description.visible, "empty description hidden, not '—'")
	journal._entry_list.get_child(2).pressed.emit()
	for i in 4: await process_frame
	ck(not journal._objectives_caption.visible, "objectives caption hidden when there are none")
	ck(journal._objective_list.get_child_count() == 0, "no objective rows for an empty list")

	print("[7] keyboard / gamepad navigation")
	for row in journal._entry_list.get_children():
		ck(row.focus_mode == Control.FOCUS_ALL, "%s is focusable" % row.name)
		break
	var row0: Button = journal._entry_list.get_child(0)
	row0.grab_focus()
	await process_frame
	ck(journal.get_viewport().gui_get_focus_owner() == row0, "row can take focus")
	ck(row0.button_group != null, "rows share a ButtonGroup for single selection")
	row0.pressed.emit()
	for i in 3: await process_frame
	ck(journal.selected_id == "t_a", "activation from the focused row works")

	print("[8] shared theme, no one-off styles")
	ck(journal._heading.get_theme_font_size("font_size", "SettingsHeading") == tokens.SIZE_DISPLAY,
			"heading resolves the shared variation")
	ck(journal._eyebrow.get_theme_color("font_color", "SettingsEyebrow") == tokens.ACCENT,
			"eyebrow colour from tokens")
	ck(scene_text.find("theme_override_colors") == -1, "no colour overrides in the scene")
	ck(scene_text.find("FontFile") == -1, "no embedded fonts in the scene")

	print("[9] navigation in and out")
	menu.switch_to_tab("Inventory")
	for i in 5: await process_frame
	ck(not journal.is_visible_in_tree(), "hides when leaving the tab")
	menu.switch_to_tab("Journal")
	for i in 6: await process_frame
	ck(journal.is_visible_in_tree(), "returns on re-entry")
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	menu._input(ev)
	for i in 8: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "ui_cancel closed the menu")
	ck(not paused, "gameplay resumed")

	print("[10] fixtures never reach production state")
	ui.open_game_menu()
	for i in 12: await process_frame
	var menu2: Node = get_first_node_in_group("game_menu")
	menu2.switch_to_tab("Journal")
	for i in 8: await process_frame
	var journal2: Node = get_first_node_in_group("journal_screen")
	ck(journal2.entries.is_empty(), "a fresh Journal is empty again (%d)" % journal2.entries.size())
	ui.close_game_menu()
	for i in 5: await process_frame
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
