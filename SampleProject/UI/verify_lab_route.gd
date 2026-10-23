extends SceneTree

## Увесь шлях лабораторії до кінця демо (queue row 9.8, D310, [[lab_story_plan]] зрізи 9–10), справжнім вводом —
## клавіатура й геймпад упереміш, як грав би гравець:
##   1. Зала мера: перемога (справжня attack) → камери; той самий сейв, програш → камери. Обидва — той самий біт.
##   2. Камери: кат-сцена пропущена утриманням геймпада Y (підказка показує Y); сейв → завантаження — AWAKE, без
##      повтору кат-сцени; вихід із камери лівим стіком, знайомство гортається кнопкою A → FREE; стіком на схід.
##   3. Коридори: підказка точки збереження показує кнопку геймпада; три бої; сейв на SavePoint_PreBoss кнопкою Y,
##      слот — кнопкою A; завантаження → той самий поверх, добиті бої не повертаються.
##   4. Зала джина: розмова пропущена геймпадом Y; програш → плащ → Game Over; «Resume» кнопкою A → останній сейв
##      (коридори перед залою, бос не почався).
##   5. Знову в залу: розмова (Tab) → бій → перемога справжньою attack → брама → на схід у LaboratoryOutside;
##      розмови кнопкою A → екран кінця демо, один; назад у залу й знову надвір — екран знову, розмови не повторюються
##      (B66); «Return» кнопкою A → головне меню.
## Пише лише в user://verify_lab_route/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_lab_route.gd

const MAYOR := "res://SampleProject/Maps/MayorHall.tscn"
const CELLS := "res://SampleProject/Maps/LabCells.tscn"
const LAB := "res://SampleProject/Maps/Laboratory.tscn"
const BOSS := "res://SampleProject/Maps/LabBoss.tscn"
const OUTSIDE := "res://SampleProject/Maps/LaboratoryOutside.tscn"
const TEST_DIR := "user://verify_lab_route/"
const TEST_SLOT := 1
const CELLS_TALKS: Array[String] = ["Lab_Cells_Arrival", "Lab_Cells_Injection", "Lab_Cells_Prisoner",
		"Lab_Cells_Djinn", "Lab_Cells_Faint", "Lab_Cells_Awake"]
## Бій коридорів → підлога його поверху (y).
const FIGHTS := {"Fight_Upper": 384.0, "Fight_Middle": 864.0, "Fight_Lower": 1344.0}
const FEET := 24.0

var fails: Array[String] = []
var game: Node
var dm: Node
var sl: Node
var save_system: Node
var slot_path: String
var started: Array[String] = []
var stick := 0.0

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

# ── Ввід ─────────────────────────────────────────────────────────────────────

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tab(pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.keycode = KEY_TAB
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _pad(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _pad_tap(button: JoyButton) -> void:
	_pad(button, true)
	await physics_frame
	await physics_frame
	_pad(button, false)
	for i in 4: await process_frame

## Лівий стік по горизонталі: −1 ліворуч, 1 праворуч, 0 відпущено.
func _stick(x: float) -> void:
	if is_equal_approx(x, stick):
		return
	stick = x
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = x
	Input.parse_input_event(ev)

## Кожну репліку гортає кнопка A геймпада (dq_accept): перше натискання дописує рядок, друге — далі.
func _pad_talk(max_s: float = 60.0) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	var quiet := 0
	while quiet < 20 and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active() and not dm.is_bubble_playing():
			quiet = 0
			await _pad_tap(JOY_BUTTON_A)
		else:
			quiet = 0 if dm.is_dialogue_active() else quiet + 1
			await process_frame

## Утримання пропуску секунду справжнього часу; далі сцена домотується сама до [param done].
func _hold_skip(pad: bool, done: Callable) -> void:
	await _until(func() -> bool: return _prompt() != null, 8.0)
	ck(_prompt() != null and not _hud_visible(), "skip prompt shown, HUD hidden (%s, %s, dialogue %s)" % [_room().get_file(), _state(), dm.is_dialogue_active()])
	if _prompt() == null:
		return
	if pad:
		_pad(JOY_BUTTON_Y, true)
		for i in 5: await process_frame
		var text: String = _prompt().get_node(^"%SkipLabel").text
		ck(text == "Hold Y to skip", "the skip prompt names the pad button (%s)" % text)
	else:
		_tab(true)
		for i in 5: await process_frame
		var text: String = _prompt().get_node(^"%SkipLabel").text
		ck(text == "Hold Tab to skip", "the skip prompt names the key (%s)" % text)
	await create_timer(1.2, true, false, true).timeout
	if pad:
		_pad(JOY_BUTTON_Y, false)
	else:
		_tab(false)
	await _until(done, 30.0)
	for i in 20: await physics_frame

## «You obtained:» трофеї зали мера: закривається кнопкою A.
func _close_modals() -> void:
	var ui: Node = sl.get_ui_manager()
	for i in 10:
		if ui.modal_layer == null or ui.modal_layer.active_modal == null:
			return
		await _pad_tap(JOY_BUTTON_A)
		for f in 10: await process_frame

# ── Стан гри ─────────────────────────────────────────────────────────────────

func _boot(save_path: String) -> void:
	started.clear()
	if save_path.is_empty():
		set_meta("start_new_game", true)
	else:
		set_meta("save_file_path", save_path)
		set_meta("start_new_game", false)
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame

func _load(save_path: String) -> void:
	game.queue_free()
	for i in 4: await process_frame
	await _boot(save_path)

func _room() -> String:
	return game.map.scene_file_path if is_instance_valid(game) and game.map != null else ""

func _state() -> String:
	return game.map.get_current_state_name() if _room() in [MAYOR, CELLS, BOSS] else "-"

func _prompt() -> Node:
	return root.get_node_or_null(^"CutsceneSkipPrompt")

func _hud_visible() -> bool:
	return (game.get_node(^"UI") as CanvasLayer).visible and (game.get_node(^"UICanvas") as CanvasLayer).visible

func _tough() -> void:
	game.player.Max_Health = 99999
	game.player.current_health = 99999

func _end_screens() -> Array:
	return game.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and n.get_script().resource_path.ends_with("DemoEndScreen.gd"))

## Справжній ввід: тримати [param action], доки [param cond] (або [param max_s] секунд).
func _hold_until(action: StringName, cond: Callable, max_s: float) -> void:
	_press(action)
	await _until(cond, max_s)
	_press(action, false)
	for i in 10: await physics_frame

## Лівий стік, доки [param cond].
func _stick_until(x: float, cond: Callable, max_s: float) -> void:
	_stick(x)
	await _until(cond, max_s)
	_stick(0.0)
	for i in 10: await physics_frame

## Останній удар — справжня attack.
func _strike_down(boss: Node2D) -> void:
	_tough()
	boss.current_health = 1
	for i in 30:
		if boss.is_dead:
			break
		game.player.global_position = Vector2(boss.global_position.x - 50.0, game.player.global_position.y)
		game.player.mover.last_direction = 1
		_press(&"attack")
		await physics_frame
		await physics_frame
		_press(&"attack", false)
		await create_timer(0.3).timeout

# ── Коридори (як verify_laboratory.gd) ───────────────────────────────────────

func _alive(spawner: Node) -> Array:
	return spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())

## Ворог, що став на підлогу, добивається (бої коридорів перевіряє verify_laboratory).
func _fight_frame() -> void:
	if _room() != LAB:
		return
	for fight: String in FIGHTS:
		for enemy: Node in _alive(game.map.get_node(fight)):
			if enemy.is_on_floor():
				enemy.die()

func _release_all() -> void:
	_stick(0.0)
	for action: StringName in [&"move_down", &"jump"]:
		Input.action_release(action)

## Герой іде лівим стіком до x [param target]; стіна — стрибок (A). Бої по дорозі добиваються.
func _go(target: float, max_frames := 1200) -> bool:
	var jump_left := 0
	for i in max_frames:
		await physics_frame
		_fight_frame()
		var p: Node2D = game.player
		if absf(p.global_position.x - target) < 12.0:
			_release_all()
			return true
		_stick(1.0 if p.global_position.x < target else -1.0)
		if jump_left > 0:
			jump_left -= 1
			if jump_left == 0:
				_pad(JOY_BUTTON_A, false)
		elif p.is_on_floor() and p.is_on_wall():
			_pad(JOY_BUTTON_A, true)
			jump_left = 18
	_release_all()
	return false

## Хрестовина вниз над драбиною — до підлоги поверху під нею.
func _climb_down(label: String) -> void:
	var y0: float = game.player.global_position.y
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	var grabbed := false
	for i in 400:
		await physics_frame
		_fight_frame()
		grabbed = grabbed or game.player.mover.is_climbing()
		if grabbed and not game.player.mover.is_climbing():
			break
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	for i in 20: await physics_frame
	ck(grabbed and game.player.global_position.y > y0 + 350.0, "%s: down the ladder (y %.0f → %.0f)" % [label, y0, game.player.global_position.y])

## Точка збереження: підказка з кнопкою геймпада; Y — меню збереження; A — слот (і підтвердження, якщо питає).
## Старий файл слота прибрано заздалегідь (лише тестова тека): тоді видно, що записав саме цей вибір.
func _save_at(point: String) -> void:
	var sp: Node2D = game.map.get_node(point)
	var prompt: Control = sp.interactable.get_prompt()
	await _until(func() -> bool: return prompt.visible, 3.0)
	ck(prompt.visible and prompt.is_using_gamepad(), "%s: the Save prompt shows the pad button" % point)
	var ui: Node = sl.get_ui_manager()
	DirAccess.remove_absolute(slot_path)
	await _pad_tap(JOY_BUTTON_Y)
	await _until(func() -> bool: return ui.current_state_name == "SaveGameState", 3.0)  # D447: спершу медитація
	ck(ui.current_state_name == "SaveGameState", "%s: pad Y opens the save screen (%s)" % [point, ui.current_state_name])
	for i in 6:
		if FileAccess.file_exists(slot_path) and (ui.modal_layer == null or ui.modal_layer.active_modal == null):
			break
		await _pad_tap(JOY_BUTTON_A)
		for f in 30: await process_frame
	ck(FileAccess.file_exists(slot_path), "%s: pad A saved into the slot" % point)
	if ui.is_ui_active():
		await _pad_tap(JOY_BUTTON_B)
		for f in 20: await process_frame
	ck(not ui.is_ui_active() and ui.is_gameplay_input_allowed(), "%s: back to the game (%s)" % [point, ui.current_state_name])

# ── Маршрут ──────────────────────────────────────────────────────────────────

func _initialize() -> void:
	await process_frame
	save_system = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false  # D289
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	slot_path = save_system.get_slot_path(TEST_SLOT)
	await process_frame
	sl = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	await _boot("")
	await _pad_talk()  # вступ Canyon

	print("[1] Mayor Hall, both outcomes lead to the Lab cells")
	await game.teleport_to_room(MAYOR, ^"Arrival")
	for i in 30: await physics_frame
	ck(game.save_game(), "saved at the hall door (test-only: the hall has no save point)")
	DirAccess.copy_absolute(slot_path, TEST_DIR + "mayor.bak")
	started.clear()
	await _hold_until(&"move_right", func() -> bool: return _state() != "QUEUE", 6.0)
	await _hold_skip(true, func() -> bool: return _state() == "FIGHT" and not game.player.event)
	ck(started.has("City_MayorHall") and started.has("MayorHall_WallBurst"), "the queue and the wall burst ran (%s)" % [started])
	await _strike_down(game.map.get_node(^"ScorpicoreWarrior"))
	await _until(func() -> bool: return started.has("MayorHall_Victory"), 6.0)
	ck(started.has("MayorHall_Victory") and game.get_quest_flag("mayor_boss_defeated"), "win: the victory talk")
	await _pad_talk()
	await _until(func() -> bool: return _room() == CELLS and started.has("Lab_Cells_Arrival"), 15.0)
	ck(_room() == CELLS and _state() == "CUTSCENE", "win → the Lab cells, the cutscene starts (%s, %s)" % [_room(), _state()])
	var win_flags: Dictionary = game.get_quest_flags().duplicate()
	# Кат-сцену камер у цьому забігу теж пропускає геймпад — гра не виходить посеред сцени.
	await _hold_skip(true, func() -> bool: return _state() == "AWAKE" and not game.player.event and not dm.is_dialogue_active())
	await _close_modals()
	ck(_state() == "AWAKE", "win run: awake in the cells (%s)" % _state())

	DirAccess.copy_absolute(TEST_DIR + "mayor.bak", slot_path)
	await _load(slot_path)
	ck(_room() == MAYOR and _state() == "QUEUE", "the save loads at the hall door, the queue waits (%s)" % _state())
	await _hold_until(&"move_right", func() -> bool: return _state() != "QUEUE", 6.0)
	await _hold_skip(false, func() -> bool: return _state() == "FIGHT" and not game.player.event)
	var warrior: Node2D = game.map.get_node(^"ScorpicoreWarrior")
	game.player.current_health = 1
	game.player.global_position = Vector2(warrior.global_position.x - 90.0, game.player.global_position.y)
	await _until(func() -> bool: return started.has("MayorHall_Defeat"), 15.0)
	ck(started.has("MayorHall_Defeat") and get_first_node_in_group(&"game_over_screen") == null, "lose: the defeat talk, no Game Over")
	await _pad_talk()
	await _until(func() -> bool: return _room() == CELLS and started.has("Lab_Cells_Arrival"), 15.0)
	ck(_room() == CELLS and _state() == "CUTSCENE", "lose → the Lab cells, the same cutscene (%s, %s)" % [_room(), _state()])
	var lose_flags: Dictionary = game.get_quest_flags().duplicate()
	ck(lose_flags.get("city_mayor_hall_complete", false) and win_flags.get("city_mayor_hall_complete", false), "both outcomes close the hall")
	ck(win_flags.get("mayor_boss_defeated", false) and not lose_flags.get("mayor_boss_defeated", false), "only the win marks the axe-warrior beaten")
	ck(not game.player.is_dead and game.player.current_health == game.player.Max_Health, "the lost run's hero is on his feet")

	print("[2] The cells: pad Y skips the cutscene; save, load → the wake beat; stick + A through the acquaintance")
	await _hold_skip(true, func() -> bool: return _state() == "AWAKE" and not game.player.event and not dm.is_dialogue_active())
	ck(CELLS_TALKS.all(func(t: String) -> bool: return started.has(t)), "every cells talk ran under the skip (%s)" % [started])
	ck(game.get_quest_flag("lab_cells_cutscene_complete") and _hud_visible(), "cutscene flag, HUD back")
	await _close_modals()
	ck(game.save_game(), "saved awake in the cell (test-only: the cells have no save point)")
	await _load(slot_path)
	await _until(func() -> bool: return _state() != "-", 3.0)
	for i in 30: await physics_frame
	ck(_room() == CELLS and _state() == "AWAKE", "the load resumes awake in the cells (%s, %s)" % [_room(), _state()])
	ck(not started.any(func(t: String) -> bool: return t in CELLS_TALKS and t != "Lab_Cells_Awake"), "no cutscene replay (%s)" % [started])
	var cell: Node2D = game.map.get_node(^"Arrival")
	ck(absf(game.player.global_position.x - cell.global_position.x) < 48.0, "the hero is in his cell (%s)" % game.player.global_position)
	await _pad_talk()
	started.clear()
	await _stick_until(1.0, func() -> bool: return _state() != "AWAKE", 8.0)
	ck(_state() == "ACQUAINTANCE", "stick right out of the cell → the acquaintance (%s)" % _state())
	var deadline := Time.get_ticks_msec() + 60000
	while not (_state() == "FREE" and not game.player.event and _prompt() == null) and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active() and not dm.is_bubble_playing():
			await _pad_tap(JOY_BUTTON_A)
		else:
			await process_frame
	for i in 30: await physics_frame
	ck(_state() == "FREE" and started.has("Lab_Acquaintance") and not started.has("Lab_Malik_Quest"), "pad A read the one acquaintance talk with Malik (D462) → FREE (%s, %s)" % [_state(), started])
	ck(sl.get_companion_manager().get_unlocked().size() == 3 and sl.get_companion_manager().get_party().is_empty() and game.get_quest_flag("task_malik_escort_taken"), "three assists available, none picked yet (D464), Malik's task taken")
	for id in ["alisia", "astrit", "urizen"]:  # як гравець у Status
		sl.get_companion_manager().toggle_party(id)
	await _stick_until(1.0, func() -> bool: return _room() == LAB, 12.0)
	ck(_room() == LAB, "stick east into the corridors (%s)" % _room())

	print("[3] The corridors: the save prompt speaks pad; three fights; save at PreBoss with the pad; load")
	_tough()
	ck(await _go(200.0), "to SavePoint_Entrance (%s)" % game.player.global_position)
	var entrance: Node2D = game.map.get_node(^"SavePoint_Entrance")
	var entrance_prompt: Control = entrance.interactable.get_prompt()
	await _until(func() -> bool: return entrance_prompt.visible, 3.0)
	ck(entrance_prompt.visible and entrance_prompt.is_using_gamepad(), "SavePoint_Entrance: the Save prompt shows the pad button")
	ck(await _go(1504.0), "top storey east (%s)" % game.player.global_position)
	await _climb_down("top → middle")
	ck(await _go(224.0), "middle storey west (%s)" % game.player.global_position)
	await _climb_down("middle → bottom")
	ck(game.map.is_fight_cleared(^"Fight_Upper") and game.map.is_fight_cleared(^"Fight_Middle"), "two storeys fought")
	ck(await _go(400.0), "to SavePoint_PreBoss (%s)" % game.player.global_position)
	await _save_at("SavePoint_PreBoss")
	var saved_at: Vector2 = game.player.global_position
	await _load(slot_path)
	ck(_room() == LAB and game.player.global_position.distance_to(saved_at) < 16.0, "the load resumes at PreBoss (%s, %s)" % [_room(), game.player.global_position])
	ck(game.map.is_fight_cleared(^"Fight_Upper") and game.map.is_fight_cleared(^"Fight_Middle") and not game.map.is_fight_cleared(^"Fight_Lower"),
			"the two won fights count as won, the lower one waits")
	ck(not game.map.get_node(^"Fight_Upper").fight_in_progress() and not game.map.get_node(^"Fight_Middle").fight_in_progress(),
			"the meditation at PreBoss brought their enemies back (D492)")
	_tough()
	ck(await _go(1600.0), "bottom storey east through the last fight (%s)" % game.player.global_position)
	ck(game.get_quest_flag("lab_corridors_complete"), "lab_corridors_complete")
	ck(await _go(400.0), "back to SavePoint_PreBoss")
	await _save_at("SavePoint_PreBoss")
	await _stick_until(1.0, func() -> bool: return _room() == BOSS, 15.0)
	ck(_room() == BOSS, "stick east into the boss hall (%s)" % _room())

	print("[4] The mercenary: pad Y skips the talk; losing → the cloak → Game Over; pad A Resume → the last save")
	started.clear()
	await _stick_until(1.0, func() -> bool: return _state() != "WAIT", 8.0)
	await _hold_skip(true, func() -> bool: return _state() == "FIGHT" and not game.player.event)
	ck(_state() == "FIGHT" and started.has("Lab_Boss_Talk"), "the talk, then the fight (%s)" % [started])
	var boss: Node2D = game.map.get_node(^"Mercenary")
	game.player.current_health = 1
	game.player.global_position = Vector2(boss.global_position.x - 50.0, 380)
	await _until(func() -> bool: return started.has("Lab_Boss_TakesCloak"), 20.0)
	ck(_state() == "CLOAK", "the mercenary wins: CLOAK (%s)" % _state())
	await _pad_talk()
	await _until(func() -> bool: return get_first_node_in_group(&"game_over_screen") != null, 6.0)
	var over: Control = get_first_node_in_group(&"game_over_screen")
	ck(over != null and paused, "the normal Game Over screen, paused")
	for i in 5: await process_frame
	ck(over.get_viewport().gui_get_focus_owner() == over.get_node(^"%ResumeButton"), "Resume has the focus")
	await _pad_tap(JOY_BUTTON_A)
	for i in 4: await process_frame
	await _until(func() -> bool: return current_scene != null and current_scene != game and current_scene.scene_file_path.ends_with("Game.tscn"), 5.0)
	game = current_scene
	started.clear()
	for i in 60: await physics_frame
	ck(not paused and _room() == LAB, "pad A Resume → the last save, in the corridors (%s)" % _room())
	ck(game.get_quest_flag("lab_corridors_complete") and not game.get_quest_flag("lab_boss_talk_complete") and not game.get_quest_flag("lab_boss_fight_complete"),
			"the save is before the hall: corridors done, the mercenary not met")

	print("[5] Again: the talk (Tab), the win, the gates, out to the demo end")
	# D492: сейв на PreBoss — медитація, тож нижній бій повернувся; герой знову пробивається крізь нього.
	ck(not game.map.get_node(^"Fight_Lower").fight_in_progress(), "the lower fight is back after the meditation (D492)")
	_tough()
	ck(await _go(1600.0), "through the lower fight again (%s)" % game.player.global_position)
	await _stick_until(1.0, func() -> bool: return _room() == BOSS, 15.0)
	await _stick_until(1.0, func() -> bool: return _state() != "WAIT", 8.0)
	ck(_state() == "TALK", "the talk again — it was not in the save (%s)" % _state())
	await _hold_skip(false, func() -> bool: return _state() == "FIGHT" and not game.player.event)
	boss = game.map.get_node(^"Mercenary")
	await _strike_down(boss)
	ck(boss.is_dead, "the mercenary falls to a real attack")
	await _until(func() -> bool: return started.has("Laboratory_AfterBoss"), 6.0)
	await _pad_talk()
	await _until(func() -> bool: return game.get_quest_flag("lab_after_boss_complete") and _prompt() == null, 10.0)
	ck(_state() == "OPEN" and game.map.are_gates_open(), "OPEN, the gates up")
	ck(game.get_objective() == "Leave the laboratory", "objective (%s)" % game.get_objective())
	started.clear()
	game.player.global_position = Vector2(1300, 380)
	for i in 10: await physics_frame
	await _stick_until(1.0, func() -> bool: return _room() == OUTSIDE, 10.0)
	ck(_room() == OUTSIDE, "stick east through the gates, out of the Laboratory (%s)" % _room())
	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	await _pad_talk()
	await _until(func() -> bool: return not _end_screens().is_empty(), 6.0)
	for i in 30: await process_frame
	ck(started == ["Demo_End"], "the closing talk once, no narrator line before it (D437) (%s)" % [started])
	ck(game.get_quest_flag("lab_outside_complete") and game.get_quest_flag("demo_end_complete"), "lab_outside_complete, demo_end_complete")
	ck(_end_screens().size() == 1, "one demo end screen (%d)" % _end_screens().size())
	# B141: герой стоїть на намальованій траві (підлога 384 — верх Terrain), а не висить у повітрі над міткою Arrival
	var arrival_y: float = game.map.get_node(^"Arrival").global_position.y
	ck(game.player.is_on_floor() and game.player.global_position.y > arrival_y + 8.0,
			"the hero stands on the grass outside (y %.0f, below the Arrival mark %.0f, on floor %s) — B141" % [game.player.global_position.y, arrival_y, game.player.is_on_floor()])
	var screen: Control = _end_screens()[0]
	await _finale(screen)
	ck(screen.get_viewport().gui_get_focus_owner() == screen.return_button, "Return has the focus")

	print("[6] B66: back into the hall and out again — the screen again, the talks not again")
	screen.queue_free()
	game.player.set_movement_enabled(true)  # test-only: the screen holds the hero, here he walks back in
	await process_frame
	started.clear()
	await _stick_until(-1.0, func() -> bool: return _room() == BOSS, 10.0)
	ck(_room() == BOSS and _state() == "OPEN", "stick west back into the open hall (%s, %s)" % [_room(), _state()])
	ck(started.is_empty() and not game.map.is_arena_locked(), "no talk, no lock (%s)" % [started])
	await _stick_until(1.0, func() -> bool: return _room() == OUTSIDE, 10.0)
	await _until(func() -> bool: return not _end_screens().is_empty(), 6.0)
	for i in 30: await process_frame
	ck(_end_screens().size() == 1, "the demo end screen again, one (%d)" % _end_screens().size())
	ck(started.is_empty(), "the closing talks do not replay (%s)" % [started])
	screen = _end_screens()[0]
	await _finale(screen)
	ck(screen.get_viewport().gui_get_focus_owner() == screen.return_button, "Return has the focus again")
	await _pad_tap(JOY_BUTTON_A)
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path.ends_with("MainMenu.tscn"), 5.0)
	ck(current_scene != null and current_scene.scene_file_path.ends_with("MainMenu.tscn"), "pad A Return → the main menu (%s)" % (current_scene.scene_file_path if current_scene else "null"))

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)


## D473: кнопка з'являється, коли фінал дограв (HUD гасне, камера в небо, титул); вікно туторіалу ставить гру на паузу — закриваємо.
func _finale(screen: Control) -> void:
	var shown := [false]
	screen.finale_shown.connect(func() -> void: shown[0] = true)
	var modals: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer()
	var deadline := Time.get_ticks_msec() + 15000
	while not shown[0] and Time.get_ticks_msec() < deadline:
		if modals.active_modal != null:
			modals._close_with_result("", modals.active_modal)
		await process_frame
	ck(shown[0], "the finale played to the end (D473)")
