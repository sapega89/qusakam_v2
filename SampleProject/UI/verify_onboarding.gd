extends SceneTree

## Навчання бою й сторінка Controls (BACKLOG 28, design/onboarding_plan.md, D-28a…D-28f), справжнім вводом:
## чотири уроки у вуличному бою села (D503) — кожен чекає одну вдалу дію, хибний рух його не зараховує;
## усі чотири проходять клавіатурою з мишею, а потім геймпадом — без вікон на паузі, менш ніж за хвилину;
## кнопка пропуску кат-сцени пропускає решту. Вікна туторіалу крутять кадри з гри;
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
		"block": [&"key", KEY_CTRL], "dodge": [&"key", KEY_SHIFT], "cutscene_skip": [&"key", KEY_TAB]}
const PAD := {"attack": [&"pad", JOY_BUTTON_X], "heavy_attack": [&"pad", JOY_BUTTON_B],
		"block": [&"pad", JOY_BUTTON_LEFT_SHOULDER], "dodge": [&"pad", JOY_BUTTON_RIGHT_SHOULDER],
		"cutscene_skip": [&"pad", JOY_BUTTON_Y]}
## D503: увесь ланцюг уроків — менш ніж за хвилину для гравця, що робить кожен рух раз.
const CHAIN_LIMIT_MS := 60000

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
	"ElderHouse": "res://SampleProject/Scripts/Gameplay/Scenes/ElderHouse.gd",  # розмова з дідом (D438)
	"DesertRoad": "res://SampleProject/Scripts/Gameplay/Scenes/DesertRoad.gd",
	"CityGates": "res://SampleProject/Scripts/Gameplay/Scenes/CityGates.gd",
}
const NO_WALK := ["Find a way forward", "Descend to the road", "Learn to fight: follow the lesson",
		"Defeat the bandit in the street", "Make a decision", "Defeat the enemies on the road", "Defeat the bandits"]
## Уже за ранніми кроками: ціль у місті (City), мітки — разом із планом міста.
const BEYOND_EARLY := ["Find the laboratory"]
## Цілі, що лишаються в наступній кімнаті: мітка з тим самим id мусить бути і там.
const CARRIED := {"canyon_bridge": ["ElderHouse", "Village", "Canyon"], "city_gates": ["DesertRoad", "CityGates"]}

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

	print("[1b] D733: one line per lesson; passed lessons are flagged and never come back")
	ck(CombatTraining.LESSONS.all(func(id: String) -> bool: return CombatTraining.is_done(id)), "all four lessons are flagged done")
	var again: Node = CombatTraining.new()
	village.add_child(again)
	var again_done := [false]
	again.finished.connect(func() -> void: again_done[0] = true)
	again.start(village.enemy_spawner.spawned_enemies)
	for i in 4: await process_frame
	ck(again_done[0] and again.current_id() == "" and not (hint.is_showing and hint.current_hint.begins_with("lesson_")),
			"a training with every lesson done ends at once, no banner (%s)" % again.current_id())
	again.queue_free()
	_reset_lessons()

	print("[2] Gamepad: the same four lessons with pad buttons, each move once, under a minute (D503)")
	buttons = PAD
	var pad_training: Node = CombatTraining.new()
	village.add_child(pad_training)
	training = pad_training
	var started := Time.get_ticks_msec()
	training.start(village.enemy_spawner.spawned_enemies)
	for i in 4: await process_frame
	ck(not paused and hint.is_showing and hint.current_hint == "lesson_attack", "a banner, no window pausing the game")
	await _run_lessons("pad", false)
	var took := Time.get_ticks_msec() - started
	ck(took < CHAIN_LIMIT_MS, "the whole chain took %.1f s (< %d s)" % [took / 1000.0, CHAIN_LIMIT_MS / 1000])

	print("[2a] D733: leave mid-training and come back — it goes on from the next lesson, the passed one is not repeated")
	_reset_lessons()
	buttons = KEYBOARD
	var first_go: Node = CombatTraining.new()
	village.add_child(first_go)
	training = first_go
	first_go.start(village.enemy_spawner.spawned_enemies)
	await _wait_lesson("lesson_attack")
	var loc: Node = root.get_node("LocalizationManager")
	for lang in ["en", "uk"]:
		loc.apply_language(lang)
		for i in 3: await process_frame
		ck(hint.hint_label.get_line_count() == 1, "%s: the lesson is one line (%s)" % [lang, hint.hint_label.text])
	loc.apply_language("en")
	await _until(_combo, "lesson_attack", "keyboard")
	await _wait_lesson("lesson_defend")
	first_go.queue_free()  # пішов із села посеред уроку захисту
	for i in 4: await process_frame
	ck(not hint.is_showing or not hint.current_hint.begins_with("lesson_"), "leaving takes the lesson banner away")
	var second_go: Node = CombatTraining.new()
	village.add_child(second_go)
	training = second_go
	var seen_lessons: Array[String] = []
	second_go.lesson_done.connect(func(id: String) -> void: seen_lessons.append(id))
	second_go.start(village.enemy_spawner.spawned_enemies)
	for i in 4: await process_frame
	ck(second_go.current_id() == "lesson_defend", "back again: the training goes on at Dodge or Block (%s)" % second_go.current_id())
	ck(hint.current_hint == "lesson_defend" and hint.hint_label.get_line_count() == 1, "its one line shows (%s)" % hint.hint_label.text)
	ck(not paused and root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal == null, "no popup, no pause")
	second_go.queue_free()
	for i in 4: await process_frame
	_reset_lessons()

	print("[2b] The skip button skips the rest of the training (D503)")
	var skip_training: Node = CombatTraining.new()
	village.add_child(skip_training)
	var skipped := [false]
	skip_training.finished.connect(func() -> void: skipped[0] = true)
	skip_training.start(village.enemy_spawner.spawned_enemies)
	for i in 4: await process_frame
	ck(skip_training.current_id() == "lesson_attack", "a fresh training is on lesson 1 (%s)" % skip_training.current_id())
	await _tap("cutscene_skip")
	for i in 4: await process_frame
	ck(skipped[0] and skip_training.current_id() == "", "skipped: finished, no lesson left (%s)" % skip_training.current_id())
	ck(not hint.is_showing or not hint.current_hint.begins_with("lesson_"), "no lesson banner left after the skip")
	skip_training.queue_free()

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


## Чотири уроки по черзі (D503). [param wrong_moves]: перед кожним — хибний рух, що урок не зараховує; потім правильний,
## доки не зараховано. Урок захисту клавіатурою проходить ривком, геймпадом — блоком.
func _run_lessons(device: String, wrong_moves: bool = true) -> void:
	var done: Array[String] = []
	training.lesson_done.connect(func(id: String) -> void: done.append(id))
	await _wait_lesson("lesson_attack")
	if device == "pad":
		await _tap("block")  # плашка бере назви кнопок з останнього пристрою — спершу кнопка геймпада
	var hint: Node = get_first_node_in_group("tutorial_hint_display")
	var glyph: String = "X" if device == "pad" else "Left Mouse"
	ck(hint.current_hint == "lesson_attack" and hint.hint_label.text.contains("%s three times" % glyph),
			"%s: the banner names the %s button (%s)" % [device, device, hint.hint_label.text])
	if wrong_moves:
		await _face()
		await _tap("heavy_attack")
		await create_timer(1.6).timeout
		ck(training.current_id() == "lesson_attack", "%s: a heavy hit does not pass Attack" % device)
	await _until(_combo, "lesson_attack", device)

	await _wait_lesson("lesson_defend")
	if wrong_moves:
		await _face()
		await _tap("attack")
		await create_timer(0.8).timeout
		ck(training.current_id() == "lesson_defend", "%s: attacking does not pass Dodge or Block" % device)
	await _until(_hold_block if device == "pad" else _dodge_on_glint, "lesson_defend", device)

	await _wait_lesson("lesson_parry")
	if wrong_moves:
		await _face()
		await _hold_block()  # тримати з початку замаху — це блок, не парирування
		ck(training.current_id() == "lesson_parry", "%s: a held block does not pass Parry" % device)
	await _until(_parry_on_glint, "lesson_parry", device)

	await _wait_lesson("lesson_heavy")
	if wrong_moves:
		# Після парирування відкрите вікно рипосту (D575): легкий удар у ньому — рипост важким кадром, тож чекаємо
		await create_timer(hero.combat.RIPOSTE_WINDOW).timeout
		await _face()
		await _tap("attack")
		await create_timer(0.8).timeout
		ck(training.current_id() == "lesson_heavy", "%s: a light hit does not pass Heavy" % device)
	await _until(_heavy, "lesson_heavy", device)
	ck(done == CombatTraining.get_script_constant_map()["LESSONS"], "%s: all four in order (%s)" % [device, done])


func _combo() -> void:
	for i in 3:
		await _tap("attack")
		await create_timer(0.18).timeout
	await create_timer(0.4).timeout


## D504: підказка — за TELL_LEAD до удару; ривок — коли удар падає (хітбокс живий посеред ривка).
func _dodge_on_glint() -> void:
	await _bandit_signal(&"attack_telegraphed")
	await create_timer(bandit.enemy_logic.TELL_LEAD - 0.12).timeout
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


## D504: блок — в останні PARRY_WINDOW с перед ударом, тобто трохи після підказки; удар — жовтий (не фінішер).
func _parry_on_glint() -> void:
	await _bandit_signal(&"attack_telegraphed")
	if bandit.enemy_logic.tell_kind != &"parry":
		await create_timer(0.6).timeout
		return
	await create_timer(bandit.enemy_logic.TELL_LEAD - hero.combat.PARRY_WINDOW + 0.08).timeout
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
	for id in ["movement", "lesson_attack", "lesson_defend", "lesson_parry",
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
	ck(not &"weapon_next" in listed and not &"weapon_prev" in listed, "D475: no weapon-switch rows")
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


## Новий забіг уроків у тому самому тесті: прапорці пройдених уроків (D733) знято.
func _reset_lessons() -> void:
	for id: String in CombatTraining.LESSONS:
		game.set_quest_flag(CombatTraining.DONE_FLAG % id, false)
