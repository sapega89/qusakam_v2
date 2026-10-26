extends SceneTree

## Плашка цілі (BACKLOG 37, Q39; D717): ціль на HUD з'являється, коли ціль змінилась і коли герой зайшов в іншу
## локацію, гасне через кілька секунд і не повертається ні після меню (Esc, пад Start), ні після діалогу, ні на
## кімнаті в тій самій локації; під час діалогу її немає. Та сама ціль — ще й підпунктом у списку журналу.
##   godot --headless --path . --script res://SampleProject/UI/verify_objective_plaque.gd

const OBJECTIVE := "Return to the village"
const MAPS := "res://SampleProject/Maps/%s.tscn"

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


## Перехід у кімнату [param room]; діалоги, що почались на вході, догортаємо.
func _go(game: Node, dm: Node, room: String) -> void:
	await game.teleport_to_room(MAPS % room, ^"Arrival")
	for i in 10: await process_frame
	await _drain(dm)
	for i in 3: await process_frame


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
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
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

	print("[2] D717: leaving the Game Menu (Esc, then pad Start) does not bring it back")
	await _tap(_esc())
	ck(paused and sl.get_ui_manager().current_state_name == "GameMenuState", "Esc opens the Game Menu (paused)")
	for i in 30: await process_frame
	ck(not hud.is_plaque_shown(), "no plaque while the menu is open")
	await _tap(_esc())
	for i in 10: await process_frame
	ck(not paused, "Esc closes the menu")
	ck(not hud.is_plaque_shown(), "no plaque after the menu (alpha %.2f)" % panel.modulate.a)
	await _tap(_start())
	ck(paused, "pad Start opens the Game Menu")
	await _tap(_start())
	for i in 10: await process_frame
	ck(not paused and not hud.is_plaque_shown(), "pad Start closes it, still no plaque")

	print("[3] D717: never during a dialogue; an objective set in one shows after it, a plain talk brings nothing back")
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 6: await process_frame
	ck(dm.is_dialogue_active(), "a dialogue is running")
	game.set_objective("Find the old man's gift")
	for i in 3: await process_frame
	ck(not hud.is_plaque_shown() and hud.is_plaque_pending(), "objective changed mid-dialogue: no plaque, it waits")
	for line in 10:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()  # D254
		await process_frame
		ck(not hud.is_plaque_shown(), "no plaque on dialogue line %d" % line)
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		await _tap(enter)
	for i in 6: await process_frame
	ck(not dm.is_dialogue_active(), "the talk ended on Enter")
	ck(hud.is_plaque_shown(), "the waiting plaque shows after the dialogue (alpha %.2f)" % panel.modulate.a)
	for i in 30: await process_frame
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 6: await process_frame
	ck(dm.is_dialogue_active() and not hud.is_plaque_shown(), "a dialogue starting while it shows hides it at once")
	await _drain(dm)
	await _wait_faded(hud)
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 6: await process_frame
	await _drain(dm)
	for i in 10: await process_frame
	ck(not hud.is_plaque_shown(), "a talk with no objective change brings nothing back")
	game.set_objective(OBJECTIVE)
	for i in 3: await process_frame
	await _wait_faded(hud)

	print("[3b] D717: a room in the same location keeps it hidden; another location shows it, then it fades")
	var location_db: GDScript = load("res://SampleProject/Scripts/Systems/LocationDB.gd")
	ck(location_db.of_scene(game.map.scene_file_path) == "canyon_of_whispers", "start in the Canyon of Whispers (%s)" % game.map.scene_file_path.get_file())
	await _go(game, dm, "DragonMural")
	ck(game.map.scene_file_path.ends_with("DragonMural.tscn"), "in DragonMural, same location")
	ck(not hud.is_plaque_shown() and not hud.is_plaque_pending(), "no plaque on a room change inside one location")
	await _go(game, dm, "GatehouseCellar")
	ck(game.map.scene_file_path.ends_with("GatehouseCellar.tscn"), "in GatehouseCellar (city), another location")
	for i in 120:
		if hud.is_plaque_shown():
			break
		await process_frame
	ck(hud.is_plaque_shown() and hud.get_node("%QuestTitle").text == OBJECTIVE, "the plaque shows on entering another location")
	shown_at = Time.get_ticks_msec()
	await _wait_faded(hud)
	seconds = (Time.get_ticks_msec() - shown_at) / 1000.0
	ck(not hud.is_plaque_shown() and seconds >= tokens.OBJECTIVE_PLAQUE_HOLD, "and fades after its time (%.1f s)" % seconds)
	await _go(game, dm, "BanditCamp")
	ck(hud.is_plaque_shown(), "back into the Canyon of Whispers: shown again")
	await _wait_faded(hud)
	await _go(game, dm, "DragonMural")
	ck(not hud.is_plaque_shown(), "then a room inside it: hidden (objective %s)" % hud.get_node("%QuestTitle").text)

	print("[3c] D717: no location name anywhere on the HUD")
	var names: Array[String] = []
	for loc: Dictionary in location_db.all():
		names.append(tr(loc.name))
	var found: Array[String] = []
	for label: Node in game.get_node(^"UICanvas").find_children("*", "Label", true, false):
		for n in names:
			if (label as Label).text.contains(n):
				found.append("%s: %s" % [label.name, n])
	ck(found.is_empty(), "no HUD (UICanvas) label holds a location name %s" % str(found))

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
