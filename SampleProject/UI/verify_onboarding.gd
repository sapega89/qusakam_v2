extends SceneTree

## Навчання бою й сторінка Controls (BACKLOG 28, design/onboarding_plan.md, D-28a…D-28f), справжнім вводом:
## шість уроків у вуличному бою села — кожен чекає, доки рух зроблено, хибний рух його не зараховує;
## усі шість проходять клавіатурою з мишею, а потім геймпадом. Вікна туторіалу крутять кадри з гри;
## Misc → Controls відкривається кліками й називає кожну дію для обох пристроїв.
##   godot --headless --path . --script res://SampleProject/UI/verify_onboarding.gd

## Скрипти гри — load() уже в _initialize(): preload компілював би їх до автозавантажень (EventBus, ServiceLocator).
var CombatTraining: GDScript
const COMBAT_TRAINING := "res://SampleProject/Scripts/Gameplay/CombatTraining.gd"
var TutorialTopics: GDScript
const TUTORIAL_TOPICS := "res://SampleProject/Scripts/UI/tutorial_topics.gd"
var TopicWindow: PackedScene
const TOPIC_WINDOW := "res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn"
var TutorialMenu: GDScript
const TUTORIAL_MENU := "res://SampleProject/Scripts/Menus/Game/tutorial_menu.gd"
const Kit = preload("res://SampleProject/UI/input_kit.gd")

## Кнопки уроків: клавіатура / миша (D270, project.godot) і геймпад.
const KEYBOARD := {"attack": [&"mouse", MOUSE_BUTTON_LEFT], "heavy_attack": [&"key", KEY_R],
		"block": [&"key", KEY_CTRL], "dodge": [&"key", KEY_SHIFT]}
const PAD := {"attack": [&"pad", JOY_BUTTON_X], "heavy_attack": [&"pad", JOY_BUTTON_B],
		"block": [&"pad", JOY_BUTTON_LEFT_SHOULDER], "dodge": [&"pad", JOY_BUTTON_RIGHT_SHOULDER]}

## Дії InputMap, яких немає на сторінці Controls, і чому.
const NOT_GAMEPLAY := {
	&"save_delete": "Load Game menu only (delete a save)",
	&"menu_next_tab": "shares the Previous / next menu tab row with menu_prev_tab",
	&"toggle_mouse": "keyboard & mouse only (D417): a pad never moves the cursor; rebindable in Settings → Controls",
}

## Ранні кроки сюжету (D-28h): кімната → її скрипт. Кожна ціль там або веде на мітку ObjectiveTargets/<id> цієї
## кімнати, або в NO_WALK — крок, де йти нікуди (бій перед очима, розмова, кат-сцена).
const EARLY_ROOMS := {
	"Canyon": "res://SampleProject/Scripts/Gameplay/Scenes/Canyon.gd",
	"Village": "res://SampleProject/Scripts/Gameplay/Scenes/Village.gd",
	"DesertRoad": "res://SampleProject/Scripts/Gameplay/Scenes/DesertRoad.gd",
	"CityGates": "res://SampleProject/Scripts/Gameplay/Scenes/CityGates.gd",
}
const NO_WALK := ["Find a way forward", "Descend to the road", "Learn to fight: follow the lesson",
		"Defeat the bandit in the street", "Make a decision", "Defeat the enemies on the road", "Defeat the bandits"]
## Уже за ранніми кроками: ціль у місті (City), мітки — разом із планом міста.
const BEYOND_EARLY := ["Find the laboratory"]
## Цілі, що лишаються в наступній кімнаті: мітка з тим самим id мусить бути і там.
const CARRIED := {"canyon_bridge": ["Village", "Canyon"], "city_gates": ["DesertRoad", "CityGates"]}

var fails: Array[String] = []
var game: Node
var hero: Node
var bandit: Node
var training: Node
var buttons: Dictionary = KEYBOARD
var _lowest_hero := 99999
var _lowest_bandit := 99999


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	CombatTraining = load(COMBAT_TRAINING)
	TutorialTopics = load(TUTORIAL_TOPICS)
	TopicWindow = load(TOPIC_WINDOW)
	TutorialMenu = load(TUTORIAL_MENU)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # уроки плашками, без паузи
	await process_frame
	root.size = Vector2i(1920, 1080)  # кліки влучають туди, де намальовано (input_kit)
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete"]:
		flags[f] = true
	game.set_quest_flags(flags)

	print("[0] The street fight starts with the lessons (D-28a)")
	await game.teleport_to_room("res://SampleProject/Maps/Village.tscn", ^"Arrival")
	await create_timer(1.0).timeout
	var village: Node = game.map
	hero = game.player
	hero.global_position = Vector2(150, 344)
	hero.velocity = Vector2.ZERO
	for i in 30: await process_frame
	await _drain(dm)
	for i in 30: await process_frame
	training = village.training
	ck(training != null and training.current_id() == "lesson_attack", "lesson 1 Attack is up (%s)" % (training.current_id() if training else "no training"))
	var hint: Node = get_first_node_in_group("tutorial_hint_display")
	ck(hint.current_hint == "lesson_attack" and hint.is_showing, "its banner shows (%s)" % hint.current_hint)
	ck(hint.hint_label.text.contains("Left Mouse"), "the banner names the keyboard button (%s)" % hint.hint_label.text)
	ck(game.current_objective == "Learn to fight: follow the lesson", "objective (%s)" % game.current_objective)
	ck(TutorialTopics.is_seen("attack") and TutorialTopics.is_seen("block") and TutorialTopics.is_seen("heavy_attack"),
			"the general combat hints do not pop up during the lessons")
	bandit = village.enemy_spawner.spawned_enemies[0]
	hero.health_changed.connect(func(h: int, _m: int, _a: bool) -> void: _lowest_hero = mini(_lowest_hero, h))
	bandit.health_changed.connect(func(h: int, _m: int, _a: bool) -> void: _lowest_bandit = mini(_lowest_bandit, h))

	print("[1] Keyboard and mouse: each lesson waits for its move")
	await _run_lessons("keyboard")
	ck(game.current_objective == "Defeat the bandit in the street", "after the lessons: finish him (%s)" % game.current_objective)
	ck(not hint.is_showing or not hint.current_hint.begins_with("lesson_"), "no lesson banner left")

	print("[2] Gamepad: the same six lessons with pad buttons")
	buttons = PAD
	var pad_training: Node = CombatTraining.new()
	village.add_child(pad_training)
	training = pad_training
	training.start(village.enemy_spawner.spawned_enemies)
	for i in 4: await process_frame
	await _run_lessons("pad")

	print("[3] Nobody fell while learning (D-28c); after them the bandit can be killed")
	ck(hero.is_alive() and _lowest_hero > 0, "the hero never dropped to 0 (lowest %d)" % _lowest_hero)
	ck(bandit.is_alive() and _lowest_bandit > 0, "the bandit never dropped to 0 (lowest %d)" % _lowest_bandit)
	pad_training.queue_free()
	bandit.die()
	for i in 20: await process_frame
	ck(game.get_quest_flag("village_fight_complete"), "village_fight_complete after the kill")
	ck(village.training == null, "the training is gone with the fight")
	await _drain(dm)

	print("[4] Tutorial windows play frames recorded from the game (D-28e)")
	await _check_frames()

	print("[5] Misc → Controls by real clicks (D-28f)")
	await _check_controls(sl)

	print("[7] Where to go next: the plaque arrow points at the objective's marker (D-28h)")
	_check_objective_markers()
	await _check_arrow(village)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0)


## Шість уроків по черзі: перед кожним — хибний рух, що урок не зараховує; потім правильний, доки не зараховано.
func _run_lessons(device: String) -> void:
	var done: Array[String] = []
	training.lesson_done.connect(func(id: String) -> void: done.append(id))
	await _wait_lesson("lesson_attack")
	await _until(_attack_once, "lesson_attack", device)

	await _wait_lesson("lesson_combo")
	var hint: Node = get_first_node_in_group("tutorial_hint_display")
	var glyph: String = "X" if device == "pad" else "Left Mouse"
	ck(hint.current_hint == "lesson_combo" and hint.hint_label.text.contains("Press %s three times" % glyph),
			"%s: the banner names the %s button (%s)" % [device, device, hint.hint_label.text])
	await _tap("heavy_attack")
	await create_timer(1.6).timeout
	ck(training.current_id() == "lesson_combo", "%s: a heavy hit does not pass Combo" % device)
	await _until(_combo, "lesson_combo", device)

	await _wait_lesson("lesson_dodge")
	await _face()
	await _tap("attack")
	await create_timer(0.8).timeout
	ck(training.current_id() == "lesson_dodge", "%s: attacking does not pass Dodge" % device)
	await _until(_dodge_on_glint, "lesson_dodge", device)

	await _wait_lesson("lesson_block")
	await _until(_hold_block, "lesson_block", device)

	await _wait_lesson("lesson_parry")
	await _face()
	await _hold_block()  # тримати з початку замаху — це блок, не парирування
	ck(training.current_id() == "lesson_parry", "%s: a held block does not pass Parry" % device)
	await _until(_parry_on_glint, "lesson_parry", device)

	await _wait_lesson("lesson_heavy")
	await _face()
	await _tap("attack")
	await create_timer(0.8).timeout
	ck(training.current_id() == "lesson_heavy", "%s: a light hit does not pass Heavy" % device)
	await _until(_heavy, "lesson_heavy", device)
	ck(done == CombatTraining.get_script_constant_map()["LESSONS"], "%s: all six in order (%s)" % [device, done])


func _attack_once() -> void:
	await _tap("attack")
	await create_timer(0.3).timeout


func _combo() -> void:
	for i in 3:
		await _tap("attack")
		await create_timer(0.18).timeout
	await create_timer(0.4).timeout


func _dodge_on_glint() -> void:
	await _bandit_signal(&"attack_telegraphed")
	await _tap("dodge")
	await create_timer(0.4).timeout


## Блок, піднятий ще до замаху: герой уже в BLOCK, коли ворог починає замах, тож удар приходить після PARRY_WINDOW.
## Не посеред серії: блок, піднятий наприкінці чужого замаху, — чесне парирування; так само блок, що встав лише
## після збою від попереднього удару. Такий замах пропускаємо й пробуємо на наступному.
func _hold_block() -> void:
	for i in 12:
		for f in 400:
			if not bandit.enemy_logic.is_attacking:
				break
			await physics_frame
		_hold("block", true)
		await _bandit_signal(&"attack_started")
		if hero.combat.is_blocking():
			break
		_hold("block", false)
	await create_timer(0.9).timeout
	_hold("block", false)


func _parry_on_glint() -> void:
	await _bandit_signal(&"attack_telegraphed")
	_hold("block", true)
	await create_timer(0.3).timeout
	_hold("block", false)


func _heavy() -> void:
	await _tap("heavy_attack")
	await create_timer(0.8).timeout


## Повторює [param attempt], доки урок [param id] не зараховано (бандит може збити героя посеред руху).
func _until(attempt: Callable, id: String, device: String) -> void:
	for i in 12:
		if training.current_id() != id:
			break
		await _face()
		await attempt.call()
		for f in 10: await physics_frame
	ck(training.current_id() != id, "%s: %s passes with the real button" % [device, id])


func _wait_lesson(id: String) -> void:
	for i in 120:
		if training.current_id() == id:
			return
		await process_frame
	ck(false, "lesson %s came up (now %s)" % [id, training.current_id()])


## Герой упритул до бандита й обличчям до нього.
func _face() -> void:
	await create_timer(0.3).timeout  # вийти зі збою
	var side: float = -1.0 if hero.global_position.x < bandit.global_position.x else 1.0
	hero.global_position = Vector2(bandit.global_position.x + side * 30.0, bandit.global_position.y - 4.0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = int(-side)
	for i in 3: await physics_frame


func _bandit_signal(sig: StringName) -> void:
	var fired := [false]
	var logic: Object = bandit.enemy_logic
	var on_fire := func() -> void: fired[0] = true
	logic.connect(sig, on_fire, CONNECT_ONE_SHOT)
	for i in 400:
		if fired[0]:
			return
		await physics_frame
	logic.disconnect(sig, on_fire)


func _event(action: String, pressed: bool) -> InputEvent:
	var spec: Array = buttons[action]
	match spec[0]:
		&"key":
			var key := InputEventKey.new()
			key.physical_keycode = spec[1]
			key.keycode = spec[1]
			key.pressed = pressed
			return key
		&"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = spec[1]
			mouse.pressed = pressed
			mouse.position = Vector2(root.size) / 2.0
			mouse.global_position = mouse.position
			return mouse
	var pad := InputEventJoypadButton.new()
	pad.button_index = spec[1]
	pad.pressed = pressed
	return pad


func _hold(action: String, pressed: bool) -> void:
	Input.parse_input_event(_event(action, pressed))


func _tap(action: String) -> void:
	_hold(action, true)
	await physics_frame
	await physics_frame
	_hold(action, false)
	await physics_frame


func _check_frames() -> void:
	for topic in TutorialTopics.all():
		TutorialTopics.mark_seen(topic.id)
	var layer: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer()
	var with_frames: Array = TutorialTopics.all().filter(func(t: Dictionary) -> bool: return t.has("frames"))
	var sets: Array = []
	for topic in with_frames:
		if not topic.frames in sets:
			sets.append(topic.frames)
	ck(sets.size() >= 8, "eight frame sets: move, combo, dodge, block, parry, heavy, heal, assist (%s)" % [sets])
	for id in ["movement", "lesson_attack", "lesson_combo", "lesson_dodge", "lesson_block", "lesson_parry",
			"lesson_heavy", "healing_palm", "call_guard"]:
		ck(with_frames.any(func(t: Dictionary) -> bool: return t.id == id), "%s has a picture" % id)
	for topic in with_frames:
		var frames: Array[Texture2D] = TutorialMenu.load_frames(topic.frames)
		ck(frames.size() >= 6, "%s: %d frames of '%s'" % [topic.id, frames.size(), topic.frames])
	for id: String in with_frames.map(func(t: Dictionary) -> String: return t.id):
		layer.show_custom_modal(TopicWindow)
		var window: Node = layer.active_modal
		window.open_id(id)
		var shot: TextureRect = window.get_node(^"%Shot")
		var first: Texture2D = shot.texture
		ck(first != null and first == window.frames[0] and window.get_node(^"%ShotFrame").visible, "%s window shows frame 0" % id)
		await create_timer(0.35).timeout
		ck(shot.texture != first and shot.texture in window.frames, "%s window plays the frames" % id)
		ck(window.get_node(^"%Key").text != "", "%s window names the button (%s)" % [id, window.get_node(^"%Key").text])
		window.cancelled.emit()
		for i in 4: await process_frame


func _check_controls(sl: Node) -> void:
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "game menu open")
	await Kit.mouse(self, menu.misc_button)
	var modal: Node = get_first_node_in_group("misc_menu_modal")
	ck(modal != null, "Misc opened by a click")
	await Kit.mouse(self, modal.controls_button)
	var page: Node = menu.find_child("ControlsComponent", true, false)
	ck(page.is_visible_in_tree(), "Controls opened by a click")
	ck(not menu.find_child("TutorialComponent", true, false).is_visible_in_tree(), "only the Controls panel shows")
	var missing: Array = []
	for i in page.ACTIONS.size():
		var texts: Array[String] = page.row_texts(i)
		if texts[1] == "—" or texts[2] == "—":
			missing.append(texts)
	ck(missing.is_empty(), "every action has a keyboard and a pad button (%s)" % [missing])
	var listed: Array = page.ACTIONS.map(func(a: Array) -> StringName: return a[1])
	var unlisted: Array = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not action in NOT_GAMEPLAY and not action in listed:
			unlisted.append(action)
	ck(unlisted.is_empty(), "every gameplay action in the InputMap is listed (missing %s)" % [unlisted])
	var weapon_prev: Array[String] = page.row_texts(listed.find(&"weapon_prev"))
	ck(weapon_prev[1] == "Z" and weapon_prev[2] == "D-pad left", "previous weapon: Z / D-pad left (D-28i) (%s)" % [weapon_prev])
	var block_row: Array[String] = page.row_texts(8)
	ck(block_row[1].contains("Ctrl") and block_row[2] == "LB", "block: Ctrl / LB (%s)" % [block_row])
	ck(root.gui_get_focus_owner() == page.get_node(^"%ActionList").get_child(0), "focus on the first row (pad / arrows scroll)")
	ui.close_game_menu()
	for i in 16: await process_frame

	print("[6] The same page by gamepad: Start → Misc → Controls")
	await Kit.pad(self, JOY_BUTTON_START)
	await Kit.frames(self, 16)
	menu = get_first_node_in_group("game_menu")
	ck(menu != null, "Start opens the game menu")
	for i in 8:
		if root.gui_get_focus_owner() == menu.misc_button:
			break
		await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == menu.misc_button, "D-pad reaches Misc")
	await Kit.pad(self, JOY_BUTTON_A)
	await Kit.frames(self, 6)
	modal = get_first_node_in_group("misc_menu_modal")
	ck(modal != null, "A opens Misc")
	for i in 6:
		if root.gui_get_focus_owner() == modal.controls_button:
			break
		await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == modal.controls_button, "D-pad reaches Controls")
	await Kit.pad(self, JOY_BUTTON_A)
	await Kit.frames(self, 6)
	page = menu.find_child("ControlsComponent", true, false)
	ck(page.is_visible_in_tree(), "A opens Controls")
	var rows: Node = page.get_node(^"%ActionList")
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == rows.get_child(1), "D-pad down scrolls the list")
	ui.close_game_menu()


func _check_objective_markers() -> void:
	var calls := RegEx.create_from_string('set_objective\\("([^"]+)"(?:, &"(\\w+)")?\\)')
	for room: String in EARLY_ROOMS:
		var markers := _markers("res://SampleProject/Maps/%s.tscn" % room)
		var source := FileAccess.get_file_as_string(EARLY_ROOMS[room])
		var seen := {}
		for m in calls.search_all(source):
			var text := m.get_string(1)
			var id := m.get_string(2)
			if seen.has(text + id):
				continue
			seen[text + id] = true
			if text in BEYOND_EARLY:
				continue
			if id == "":
				ck(text in NO_WALK, "%s: «%s» has no marker and is a fight / talk / cutscene" % [room, text])
			else:
				ck(id in markers, "%s: «%s» → ObjectiveTargets/%s (%s)" % [room, text, id, markers])
	for id: String in CARRIED:
		for room: String in CARRIED[id]:
			ck(id in _markers("res://SampleProject/Maps/%s.tscn" % room), "%s is marked in %s too (the route crosses rooms)" % [id, room])


## Імена міток ObjectiveTargets/* у сцені кімнати — зі стану сцени, без запуску кімнати.
func _markers(path: String) -> Array[String]:
	var state: SceneState = (load(path) as PackedScene).get_state()
	var out: Array[String] = []
	for i in state.get_node_count():
		if String(state.get_node_path(i, true)) == "./ObjectiveTargets":
			out.append(String(state.get_node_name(i)))
	return out


func _check_arrow(village: Node) -> void:
	var hud: Node = get_first_node_in_group("combat_hud_top")
	var arrow: Label = hud.get_node(^"%Direction")
	game.set_objective("Check on the house", &"house")
	var house: Vector2 = village.get_node(^"ObjectiveTargets/house").global_position
	for case: Array in [[-600.0, "→"], [600.0, "←"], [0.0, ""]]:
		hero.global_position = Vector2(house.x + case[0], house.y - 20.0)
		hero.velocity = Vector2.ZERO
		for i in 3: await process_frame
		var shown: String = arrow.text if arrow.visible else ""
		ck(shown == case[1], "hero %+d px from the house: arrow «%s» (%s)" % [case[0], case[1], shown])
	game.set_objective("Make a decision")
	for i in 3: await process_frame
	ck(not arrow.visible, "a talk step has no arrow")


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			for f in 6: await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return
