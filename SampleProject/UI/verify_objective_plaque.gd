extends SceneTree

## Плашка цілі (BACKLOG 37, Q39): ціль на HUD з'являється, гасне через кілька секунд, знову з'являється після
## виходу з меню (Game Menu — Esc і пад Start, діалог — Enter); та сама ціль — ще й підпунктом у списку журналу.
##   godot --headless --path . --script res://SampleProject/UI/verify_objective_plaque.gd

const OBJECTIVE := "Return to the village"

var fails: Array[String] = []
var tokens: GDScript = load("res://SampleProject/UI/Tokens/UITokens.gd")

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


func _tap(event: InputEvent) -> void:
	event.set(&"pressed", true)
	Input.parse_input_event(event)
	for i in 3: await process_frame
	var release: InputEvent = event.duplicate()
	release.set(&"pressed", false)
	Input.parse_input_event(release)
	for i in 6: await process_frame


func _esc() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	return key


func _start() -> InputEventJoypadButton:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	return pad


## Чекає, доки плашка згасне (утримання + дві анімації і запас).
func _wait_faded(hud: Node) -> void:
	var limit: float = tokens.OBJECTIVE_PLAQUE_HOLD + tokens.OBJECTIVE_PLAQUE_FADE * 2.0 + 1.0
	var deadline: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while hud.is_plaque_shown() and Time.get_ticks_msec() < deadline:
		await process_frame


func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	var hud: Node = get_first_node_in_group(&"combat_hud_top")
	var panel: Control = hud.get_node("%QuestPanel")

	print("[1] A new objective shows the plaque, then it fades after a few seconds")
	game.set_objective(OBJECTIVE)
	for i in 3: await process_frame
	ck(hud.is_plaque_shown() and hud.get_node("%QuestTitle").text == OBJECTIVE, "the plaque shows the objective")
	var shown_at: int = Time.get_ticks_msec()
	await _wait_faded(hud)
	var seconds: float = (Time.get_ticks_msec() - shown_at) / 1000.0
	ck(not hud.is_plaque_shown() and panel.visible, "faded out (alpha %.2f), the objective stays set" % panel.modulate.a)
	ck(seconds >= tokens.OBJECTIVE_PLAQUE_HOLD, "it stayed for the hold time first (%.1f s)" % seconds)

	print("[2] Leaving the Game Menu (Esc, then pad Start) brings it back")
	await _tap(_esc())
	ck(paused and sl.get_ui_manager().current_state_name == "GameMenuState", "Esc opens the Game Menu (paused)")
	for i in 30: await process_frame
	ck(not hud.is_plaque_shown(), "no plaque while the menu is open")
	await _tap(_esc())
	for i in 10: await process_frame
	ck(not paused, "Esc closes the menu")
	ck(hud.is_plaque_shown(), "the plaque is back after the menu (alpha %.2f)" % panel.modulate.a)
	await _wait_faded(hud)
	ck(not hud.is_plaque_shown(), "and fades again")
	await _tap(_start())
	ck(paused, "pad Start opens the Game Menu")
	await _tap(_start())
	for i in 10: await process_frame
	ck(not paused and hud.is_plaque_shown(), "pad Start closes it and the plaque is back")
	await _wait_faded(hud)

	print("[3] Leaving a dialogue (Enter) brings it back")
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 6: await process_frame
	for line in 10:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()  # D254
		await process_frame
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		await _tap(enter)
	for i in 6: await process_frame
	ck(not dm.is_dialogue_active(), "the talk ended on Enter")
	ck(hud.is_plaque_shown(), "the plaque is back after the dialogue (alpha %.2f)" % panel.modulate.a)

	print("[4] The objective is in the Journal list too, under the current item")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group(&"game_menu")
	menu.switch_to_tab("Journal")
	for i in 10: await process_frame
	var journal: Node = get_first_node_in_group(&"journal_screen")
	var rows: Array = journal.entries.filter(func(e: Dictionary) -> bool: return e.title == OBJECTIVE)
	ck(rows.size() == 1, "one Journal row '%s' (%d)" % [OBJECTIVE, rows.size()])
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		ck(row.state == "current" and row.parent == journal.entries.filter(
				func(e: Dictionary) -> bool: return e.state == "current" and e.parent == "")[0].id,
				"a current sub-row of the current item (parent %s)" % row.parent)
		var button: Button = null
		for child: Node in journal._entry_list.get_children():
			if child is Button and child.visible and child.get_meta(&"entry_id", "") == row.id:
				button = child
		ck(button != null and button.is_visible_in_tree() and button.text.ends_with(OBJECTIVE), "the row is drawn in the list")
	game.set_objective("Explore the Canyon")  # такий текст уже є серед цілей story.json → без дубля
	for i in 3: await process_frame
	ck(journal.entries.filter(func(e: Dictionary) -> bool: return e.title == "Explore the Canyon").size() == 1,
			"an objective already listed from story.json is not doubled")
	ck(journal.entries.filter(func(e: Dictionary) -> bool: return e.title == OBJECTIVE).is_empty(), "the old objective's row is gone")
	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
