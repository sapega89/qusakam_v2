extends SceneTree

## Хто говорить (BACKLOG 36, Q31): ім'я мовця по центру вікна діалогу і його портрет праворуч; у репліки
## оповідача (без мовця) — ні імені, ні рамки портрета. Репліки гортаються справжнім вводом: Enter, пад A, ЛКМ.
##   godot --headless --path . --script res://SampleProject/UI/verify_dialogue_speaker.gd

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
	if speaker == "":
		ck(name_label.text == "", "narration: no name (%s)" % name_label.text)
		ck(not box.get_node("%NameMargin").visible, "narration: the name row is hidden, no blank line above the text")
		ck(not frame.visible, "narration: no portrait frame")
		return
	ck(name_label.text == speaker, "%s: the name is shown (%s)" % [speaker, name_label.text])
	var text_top: float = box.get_node("%DialogueText").get_global_rect().position.y
	ck(name_label.is_visible_in_tree() and name_label.get_global_rect().end.y <= text_top,
		"%s: the name sits above the text, not over it (B112: %.0f ≤ %.0f)" % [speaker, name_label.get_global_rect().end.y, text_top])
	ck(name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s: the name is centred" % speaker)
	var centre: float = name_label.get_global_rect().get_center().x
	ck(absf(centre - box.get_global_rect().get_center().x) < 2.0, "%s: the name's row is centred on the box (%.0f vs %.0f)" % [speaker, centre, box.get_global_rect().get_center().x])
	ck(frame.visible == with_portrait and (portrait.texture != null) == with_portrait,
			"%s: portrait %s" % [speaker, "shown" if with_portrait else "absent"])


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
	await _drain(dm)  # вступ стартової кімнати

	print("[1] The old man's talk: narration, then Kusakam, then the grandfather")
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 6: await process_frame
	var box: Control = dm.current_dialogue_box
	ck(box.visible, "the dialogue box is open")
	_check_line(box, "", false)
	await _advance(dm, 0)
	_check_line(box, "Kusakam", true)
	await _advance(dm, 1)
	_check_line(box, "Grandfather", true)
	var portrait: TextureRect = box.get_node("%Portrait")
	ck(portrait.texture.resource_path.ends_with("old_man/portrait.tres"), "the grandfather's own face (%s)" % portrait.texture.resource_path)
	await _advance(dm, 2)
	for i in 10: await process_frame
	ck(not dm.is_dialogue_active(), "the talk ends on a mouse click")

	print("[2] The Mayor Hall queue: each companion with her / his portrait (D243–D245)")
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

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
