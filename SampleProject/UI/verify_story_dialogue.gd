extends SceneTree

## Сюжетна подача розмови (D110–D112, Figma conversation-dialog-choices 36:65; MASTER_PLAN S5).
##   1. Дані: кожна сюжетна розмова є (uk і en), не монолог, і кожен її мовець має кадр на весь зріст.
##   2. Сюжетна розмова відкриває подачу: темна сцена, назва локації (D565), картки — герой ліворуч, співрозмовник
##      праворуч, світиться той, хто говорить; кадри — ціле збільшення, без згладжування; вікно — під картками.
##   3. Поведінка та сама, що у звичайному вікні: клік — уся репліка (D736/D738), герой стоїть (D737); кінець — подачу
##      сховано, герой вільний.
##   4. Барк і звичайна розмова подачу не відкривають.
##   godot --headless --path . --script res://SampleProject/UI/verify_story_dialogue.gd

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"

var fails: Array[String] = []


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_story_busy():
				break
			if dm.is_dialogue_active():
				dm.current_dialogue_box.finish()  # тест не чекає набору репліки
				dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_story_busy():
			return


## Натискання й відпускання справжньої кнопки (подія йде через InputMap → dq_accept).
func _tap(event: InputEvent) -> void:
	event.set(&"pressed", true)
	Input.parse_input_event(event)
	for i in 3: await process_frame
	var up: InputEvent = event.duplicate()
	up.set(&"pressed", false)
	Input.parse_input_event(up)
	for i in 3: await process_frame


func _left_click() -> InputEvent:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(root.size) * 0.5
	click.global_position = click.position
	return click


func _moves(player: Node2D) -> float:
	var x := player.global_position.x
	Input.action_press(&"move_right")
	for i in 20: await process_frame
	Input.action_release(&"move_right")
	for i in 5: await process_frame
	return absf(player.global_position.x - x)


func _check_data(story: GDScript) -> void:
	print("[1] Every story dialogue exists in uk and en, is a talk (not a monologue) and its speakers have a full-body frame")
	var reader: GDScript = load("res://SampleProject/Scripts/Systems/dqd_reader.gd")
	for id: String in story.STORY:
		for dir: String in ["res://dialogue_quest/", "res://dialogue_quest/en/"]:
			ck(FileAccess.file_exists(dir + id + ".dqd"), "%s%s.dqd exists" % [dir.trim_prefix("res://"), id])
		var speakers: Array[String] = []
		for line: Dictionary in reader.lines("res://dialogue_quest/%s.dqd" % id):
			if not speakers.has(line.speaker):
				speakers.append(line.speaker)
		ck(speakers.any(func(s: String) -> bool: return s != story.HERO), "%s: someone besides the hero speaks %s" % [id, speakers])
		var missing: Array[String] = []
		for s: String in speakers:
			if not story.CAST.has(s):
				missing.append(s)
		ck(missing.is_empty(), "%s: every speaker has a card frame (missing %s)" % [id, missing])
	for speaker: String in story.CAST:
		var texture: Texture2D = load(story.CAST[speaker][0])
		var cell: Rect2i = story.CAST[speaker][1]
		ck(Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(cell), "%s: the frame %s lies inside its sheet %s" % [speaker, cell, texture.get_size()])
	ck(not story.is_story("res://dialogue_quest/Smith_Bark.dqd") and not story.is_story("res://dialogue_quest/CityGates_Scribe_Talk.dqd"),
			"barks and repeat talks are not story dialogues")


func _check_card(view: Control, card: Control, frame: TextureRect, speaker: String, story: GDScript) -> void:
	var texture: AtlasTexture = frame.texture
	ck(texture != null and texture.atlas.resource_path == story.CAST[speaker][0] and Rect2i(texture.region) == story.CAST[speaker][1],
			"%s: the card shows the character's own frame" % speaker)
	var k: float = frame.size.y / texture.region.size.y
	ck(k >= 2.0 and is_equal_approx(k, roundf(k)) and is_equal_approx(frame.size.x / texture.region.size.x, k),
			"%s: an integer scale ×%.2f (crisp pixels, D112)" % [speaker, k])
	ck(frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s: nearest filter" % speaker)
	ck(card.get_global_rect().encloses(frame.get_global_rect()), "%s: the frame fits its card" % speaker)
	ck(view.get_global_rect().encloses(card.get_global_rect()), "%s: the card is on screen" % speaker)


func _initialize() -> void:
	await process_frame
	var settings: Node = root.get_node("SaveSystem").settings_module
	settings.settings.hints = false
	settings.settings.auto_advance = false  # розмову гортає тест
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var story: GDScript = load("res://SampleProject/Scripts/Systems/story_dialogues.gd")
	_check_data(story)

	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon
	for i in 30: await process_frame
	await _drain(dm)
	var player: Node2D = game.player
	var view: Control = game.get_node(^"DialogueSystem/StoryDialogue")
	var plain_box: Control = game.get_node(^"DialogueSystem/DialogueBox")
	ck(view.theme == load(THEME_PATH), "the presentation uses the common theme (GameUITheme)")
	ck(not view.visible, "the presentation is shut outside a story talk")

	print("[2] The grandfather's talk opens the story presentation (D111)")
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	for i in 3: await process_frame
	var box: Control = dm.current_dialogue_box
	ck(dm.is_story_presentation() and view.visible and box == view.box and box.visible, "the story presentation is open")
	ck(not plain_box.visible, "the plain dialogue window stays shut")
	ck(dm.current_dialogue_player.dialogue_box == box, "DialogueQuest plays into the story box")
	var title: Label = view.get_node(^"%ChapterTitle")
	var location: String = sl.get_game_flow().location_title(game.map.scene_file_path)
	ck(title.text == location and title.text != "", "the chapter title is the location (D565): '%s'" % title.text)
	var screen: Vector2 = view.get_viewport_rect().size  # полотно 1920×1080 (вікно root у headless — 64×64)
	ck(title.get_global_rect().position.x < screen.x * 0.1 and title.get_global_rect().position.y < screen.y * 0.1, "the title sits top-left")
	var rule: Control = view.get_node(^"%ChapterRule")
	ck(rule.get_global_rect().position.y > title.get_global_rect().position.y and rule.size.y <= 2.0, "a thin rule under the title")
	var hero_card: Control = view.get_node(^"%HeroCard")
	var speaker_card: Control = view.get_node(^"%SpeakerCard")
	_check_card(view, hero_card, view.get_node(^"%HeroFrame"), story.HERO, story)
	_check_card(view, speaker_card, view.get_node(^"%SpeakerFrame"), "GRANDFATHER", story)
	ck(hero_card.get_global_rect().get_center().x < screen.x * 0.5 and speaker_card.get_global_rect().get_center().x > screen.x * 0.5,
			"the hero is on the left, the speaker on the right")
	var box_rect: Rect2 = box.get_global_rect()
	ck(hero_card.get_global_rect().end.y < box_rect.position.y and speaker_card.get_global_rect().end.y < box_rect.position.y,
			"the cards stand above the dialogue box")
	ck(view.get_global_rect().encloses(box_rect) and box_rect.position.y > screen.y * 0.5, "the box lies across the lower middle")
	ck(not box.get_node(^"%PortraitBackground").visible, "no portrait in the story box: the cards show who speaks")
	ck(box.get_node(^"%Name").text == "Kusakam", "line 1: Kusakam's name over the line")
	ck(hero_card.modulate == Color.WHITE and speaker_card.modulate != Color.WHITE, "the hero speaks: his card is lit, the other dimmed")

	print("[3] The same dialogue behaviour: a click shows the whole line, the next goes on (D736, D738)")
	ck(not box.is_finished(), "line 1 is typing")
	await _tap(_left_click())
	ck(box.is_finished(), "a left click shows the whole line at once")
	ck(box.get_node(^"%BobbingMarker").icon_visible, "the advance marker shows once the line is typed")
	await _tap(_left_click())
	ck(box.get_node(^"%Name").text == "Grandfather", "line 2: the grandfather")
	ck(speaker_card.modulate == Color.WHITE and hero_card.modulate != Color.WHITE, "the grandfather speaks: his card is lit")
	ck(player.event, "the story talk holds the hero (D737)")
	var moved: float = await _moves(player)
	ck(moved < 1.0, "move_right does nothing during the story talk (dx %.1f)" % moved)
	await _drain(dm)
	ck(not view.visible and not dm.is_story_presentation(), "the presentation closes with the talk")
	ck(not player.event, "the hero is free after the talk")

	print("[4] A talk with several speakers swaps the right card (Mayor Hall: the companions)")
	dm.start_dialogue("res://dialogue_quest/City_MayorHall.dqd")
	for i in 6: await process_frame
	ck(dm.is_story_presentation(), "the Mayor Hall talk is a story talk")
	var seen: Array[String] = []
	for i in 12:
		if not dm.is_dialogue_active():
			break
		if view.speaker_on_card != "" and not seen.has(view.speaker_on_card):
			seen.append(view.speaker_on_card)
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		for j in 3: await process_frame
	ck(seen.has("URIZEN") and seen.has("ASTRIT") and seen.has("ALISIA"), "each companion takes the right card (%s)" % [seen])
	await _drain(dm)

	print("[5] A bark and a plain talk do not open the presentation")
	var speaker := Node2D.new()
	game.map.add_child(speaker)
	speaker.global_position = player.global_position + Vector2(200, 0)
	ck(dm.say_in_passing(speaker, "res://dialogue_quest/Smith_Bark.dqd", Vector2(0, -60)), "a bark starts")
	for i in 3: await process_frame
	ck(not view.visible and not dm.is_story_presentation(), "the bark leaves the presentation shut")
	dm.end_chatter(speaker)
	speaker.queue_free()
	dm.start_dialogue("res://dialogue_quest/CityGates_Scribe_Talk.dqd")
	for i in 6: await process_frame
	ck(dm.is_dialogue_active() and dm.current_dialogue_box == plain_box and plain_box.visible, "a plain talk opens the plain window")
	ck(not view.visible, "the presentation stays shut")
	await _drain(dm)
	dm.start_dialogue("res://dialogue_quest/Lab_Cells_Arrival.dqd")
	for i in 6: await process_frame
	ck(dm.is_story_presentation(), "the next story talk opens the presentation again")
	await _drain(dm)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
