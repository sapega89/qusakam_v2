extends SceneTree

## Хто говорить (BACKLOG 36, Q31): ім'я мовця по центру вікна діалогу і його портрет праворуч; реплік
## оповідача (без мовця) немає зовсім (D437). Репліки гортаються справжнім вводом: Enter, пад A, ЛКМ.
##   godot --headless --path . --script res://SampleProject/UI/verify_dialogue_speaker.gd

const TextFit = preload("res://SampleProject/UI/text_fit.gd")

var fails: Array[String] = []

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


func _enter(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = pressed
	Input.parse_input_event(key)
	for i in 2: await process_frame


func _wait(cond: Callable, max_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return cond.call()


## D736: Enter під час набору — уся репліка, наступне — наступна; утримання гонить репліки до вибору й не далі;
## вибір — лише справжнім натисканням; після вибору утримання знову гонить до кінця. Тимчасовий .dqd з вибором.
func _click_through(dm: Node, box: Control) -> void:
	print("[5] D736: a press shows the typing line whole, the next press moves on; holding runs to the choice, never past it")
	const PATH := "user://verify_dialogue_skip.dqd"
	var lines: Array[String] = ["The road is long and the sand is deep, grandson.", "I know, grandfather. I will walk it anyway.",
		"Then take water, and take your time with it.", "Water I have. Time I do not.",
		"After the choice the talk goes on.", "And then it ends."]
	var dqd := "say|GRANDFATHER|%s\nsay|KUSAKAM|%s\nsay|GRANDFATHER|%s\nsay|KUSAKAM|%s\nchoice|Yes|No\nsay|GRANDFATHER|%s\nsay|KUSAKAM|%s\nexit|\n" % lines
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(dqd)
	file.close()
	var player: Node = dm.current_dialogue_player
	var choices: Control = box.choice_menu
	# парсер — load після старту: як class_name він компілювався б разом із тестом, раніше за автозавантаження DialogueQuest
	player.play_sections(load("res://addons/dialogue_quest/scripts/systems/dqd/dqd_parser.gd").parse_from_file(PATH), PATH)
	for i in 3: await process_frame
	ck(box.visible and not box.is_finished() and box.text == lines[0], "the first line is typing")
	await _enter(true)
	await _enter(false)
	ck(box.is_finished() and box.text == lines[0], "Enter while it types shows the whole line at once")
	await _enter(true)
	await _enter(false)
	ck(box.text == lines[1] and not box.is_finished(), "the next Enter goes to the next line (%s)" % box.text)
	await _enter(true)
	var reached := await _wait(func() -> bool: return choices.visible, 4.0)
	ck(reached and box.text == lines[3], "holding Enter runs the lines up to the choice (%s)" % box.text)
	for i in 30: await process_frame  # тримають і далі
	ck(choices.visible and box.text == lines[3], "the choice is never skipped while the button is held")
	ck(get_first_node_in_group(&"player").event, "the hero is held while the choice is open")
	await _enter(false)
	for i in 4: await process_frame
	ck(choices.visible, "releasing after the run does not pick or skip anything")
	var picked: Array[String] = []
	choices.choice_made.connect(func(c: String) -> void: picked.append(c))
	await _enter(true)
	await _enter(false)
	await _wait(func() -> bool: return not choices.visible, 1.0)
	ck(picked == ["Yes"] and box.text == lines[4], "a real press picks the answer, the talk goes on (%s, %s)" % [picked, box.text])
	await _enter(true)
	var ended := await _wait(func() -> bool: return not dm.is_dialogue_active(), 4.0)
	await _enter(false)
	ck(ended, "holding again runs to the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Справжній ввід «далі» (dq_accept): клавіатура, пад або миша — по черзі, як грає тестер.
func _advance(dm: Node, device: int) -> void:
	dm.current_dialogue_box.finish()  # D254: репліка мусить бути набрана, інакше «далі» нічого не робить
	await process_frame
	var press: InputEvent
	match device:
		0:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			press = key
		1:
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_A
			press = pad
		_:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = Vector2(root.size) * Vector2(0.5, 0.3)
			click.global_position = click.position
			press = click
	press.set(&"pressed", true)
	Input.parse_input_event(press)
	for i in 3: await process_frame
	var release: InputEvent = press.duplicate()
	release.set(&"pressed", false)
	Input.parse_input_event(release)
	for i in 4: await process_frame


func _check_line(box: Control, speaker: String, with_portrait: bool) -> void:
	var name_label: Label = box.get_node("%Name")
	var frame: Control = box.get_node("%PortraitBackground")
	var portrait: TextureRect = box.get_node("%Portrait")
	ck(name_label.text == speaker, "%s: the name is shown (%s)" % [speaker, name_label.text])
	var text_top: float = box.get_node("%DialogueText").get_global_rect().position.y
	ck(name_label.is_visible_in_tree() and name_label.get_global_rect().end.y <= text_top,
		"%s: the name sits above the text, not over it (B112: %.0f ≤ %.0f)" % [speaker, name_label.get_global_rect().end.y, text_top])
	ck(name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s: the name is centred" % speaker)
	var centre: float = name_label.get_global_rect().get_center().x
	ck(absf(centre - box.get_global_rect().get_center().x) < 2.0, "%s: the name's row is centred on the box (%.0f vs %.0f)" % [speaker, centre, box.get_global_rect().get_center().x])
	ck(frame.visible == with_portrait and (portrait.texture != null) == with_portrait,
			"%s: portrait %s" % [speaker, "shown" if with_portrait else "absent"])
	if with_portrait:
		ck(box.get_global_rect().encloses(frame.get_global_rect()),
			"%s: the box holds the portrait (B122: box %s, portrait %s)" % [speaker, box.get_global_rect(), frame.get_global_rect()])
	# D474: текст у грі ×1.5 (тіло ≥ 24 px), вікно росте під нього — нічого не обрізано.
	var text_px: int = box.get_node("%DialogueText").get_theme_font_size(&"normal_font_size")
	ck(text_px >= UITokens.INGAME_BODY_MIN and name_label.get_theme_font_size(&"font_size") >= UITokens.INGAME_BODY_MIN,
			"%s: D474 dialogue text %d px, name %d px" % [speaker, text_px, name_label.get_theme_font_size(&"font_size")])
	var clip: String = TextFit.clipped(box)
	ck(clip == "", "%s: D474 nothing clipped in the box (%s)" % [speaker, clip])


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
	await _drain(dm)  # вступ стартової кімнати

	print("[1] The old man's talk: Kusakam, then the grandfather (D437: no narration line first)")
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 6: await process_frame
	var box: Control = dm.current_dialogue_box
	ck(box.visible, "the dialogue box is open")
	_check_line(box, "Kusakam", true)
	await _advance(dm, 1)
	_check_line(box, "Grandfather", true)
	var portrait: TextureRect = box.get_node("%Portrait")
	ck(portrait.texture.resource_path.ends_with("old_man/portrait.tres"), "the grandfather's own face (%s)" % portrait.texture.resource_path)
	await _advance(dm, 2)
	for i in 10: await process_frame
	ck(not dm.is_dialogue_active(), "the talk ends on a mouse click")

	print("[1b] D437: no line without a speaker in any dialogue, uk or en (the box never narrates)")
	var narration: Array[String] = []
	for dir: String in ["res://dialogue_quest/", "res://dialogue_quest/en/"]:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".dqd"):
				continue
			var n := 0
			for raw: String in FileAccess.get_file_as_string(dir + file).split("\n"):
				n += 1
				var parts := raw.split("|")
				if parts.size() >= 3 and parts[0].strip_edges() == "say" and parts[1].strip_edges().is_empty():
					narration.append("%s%s:%d" % [dir.trim_prefix("res://dialogue_quest/"), file, n])
	ck(narration.is_empty(), "every say line has a speaker (%s)" % [narration])

	print("[2] The Mayor Hall queue: each companion with her / his portrait (D243–D245); a second start_dialogue after one has ended still grows the box (B122)")
	dm.start_dialogue("res://dialogue_quest/City_MayorHall.dqd")
	for i in 6: await process_frame
	_check_line(box, "Kusakam", true)
	for who: Array in [["Urizen", "urizen"], ["Astrit", "astrit"], ["Alisia", "alisia"]]:
		await _advance(dm, 0)
		_check_line(box, who[0], true)
		ck(portrait.texture.resource_path.ends_with("%s/portrait.tres" % who[1]), "%s: the companion portrait (%s)" % [who[0], portrait.texture.resource_path])
	await _drain(dm)

	print("[3] A speaker without art keeps the name and shows no empty frame")
	var villager: Resource = load("res://dialogue_quest/characters/VILLAGER_1.tres")
	ck(villager.get(&"portrait") == null, "VILLAGER_1 has no portrait")
	box.set_portrait_image(null)
	ck(not box.get_node("%PortraitBackground").visible, "no texture → no frame")

	print("[4] The name is the first row of the box, not an overlay (B112); the mouse passes through it")
	var name_row: Control = box.get_node("%NameMargin")
	ck(name_row.get_parent() == box.get_node("Margin/Rows") and name_row.get_index() == 0, "NameMargin is the first child of Margin/Rows")
	ck(name_row.mouse_filter == Control.MOUSE_FILTER_IGNORE and box.get_node("%Name").mouse_filter == Control.MOUSE_FILTER_IGNORE, "NameMargin and Name ignore the mouse")

	await _click_through(dm, box)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
