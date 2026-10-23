extends SceneTree

## Кадри вікна туторіалу «Choosing Companions» (D463) — набір companion_picker: Status → Companions, гравець
## бере в загін Астрит, Уризена й Алісию (картки стають «IN PARTY · n»), потім кнопка асисту кличе вибрану —
## постріл Алісії (D464). Кадр асисту пишеться й у набір assist (теми call_guard і companions), бо старий показував кішку.
## Вирізки 500×240, як у capture_tutorial_frames.gd. Потрібне вікно (не --headless):
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_companion_picker_frames.gd
## Після запуску — `godot --headless --path . --import`.

const OUT := "res://SampleProject/Assets/UI/Tutorial"
const SIZE := Vector2i(500, 240)
## Скільки кадрів (по 0,1 с у вікні) тримається кожен стан карток.
const HOLD := 6
## Порядок вибору — він же черга асисту, як «IN PARTY · n» у кадрі.
const PICKS := ["astrit", "urizen", "alisia"]

var game: Node
var sl: Node
var _picker: Array[Image] = []


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue()
	await create_timer(2.5).timeout
	await _finish_dialogue()
	get_first_node_in_group("tutorial_hint_display").modulate.a = 0.0
	var cm: Node = sl.get_companion_manager()
	for f in cm.UNLOCK_FLAGS.values():
		game.set_quest_flag(f, true)

	# Status → Companions: усі в таборі, далі по одному в загін
	var ui: Node = sl.get_ui_manager()
	ui.open_companion_picker()
	for i in 30: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	var section: Control = menu.find_child("CompanionsSection", true, false)
	var cards: Array = menu.find_child("CompanionCards", true, false).get_children().filter(func(c: Control) -> bool: return c.visible)
	await _hold_section(section)
	for id in PICKS:
		var card: Control = cards.filter(func(c: Control) -> bool: return c.get_meta(&"companion_id") == id)[0]
		card.get_node(^"Select").grab_focus()
		await _hold_section(section, HOLD / 2)
		card.get_node(^"Select").pressed.emit()
		await _hold_section(section)
	ui.close_game_menu()
	for i in 20: await process_frame

	# Кнопка асисту кличе першу в черзі — Астрит; щоб показати постріл, першою ставимо Алісию
	sl.get_game_manager().player_state.companion_party = ["alisia", "astrit", "urizen"]
	var hero: Node2D = game.player
	var enemies: Array = game.map.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies"))
	var target: Node2D = enemies[0]
	for e in enemies:
		e.Max_Health = 9999
		e.current_health = 9999
		e.set_physics_process(false)
		e.detection_area.monitoring = false
		e.enemy_logic.current_state = 0
		e.global_position.x += 3000
	target.global_position = Vector2(hero.global_position.x + 130, target.global_position.y)
	hero.mover.last_direction = 1
	for i in 12: await physics_frame
	var assist: Array[Image] = []
	var center: Vector2 = hero.global_position + Vector2(30.0, 0.0)  # Алісия стає за 70 px позаду героя
	_press(&"assist")
	for i in 14:
		await RenderingServer.frame_post_draw
		assist.append(_crop(root.get_viewport().get_canvas_transform() * center))
		await create_timer(0.1).timeout
	_save("companion_picker", _picker + assist)
	_save("assist", assist)
	print("picker frames done")
	quit(0)


## [param count] кадрів секції Companions (вирізка 1000×480 навколо неї, зменшена вдвічі — як ShotFrame).
func _hold_section(section: Control, count: int = HOLD) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var at := Vector2i(section.get_global_rect().get_center()) - SIZE
	var shot := img.get_region(Rect2i(at.clamp(Vector2i.ZERO, img.get_size() - SIZE * 2), SIZE * 2))
	shot.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	for i in count:
		_picker.append(shot)


func _crop(at: Vector2) -> Image:
	var img: Image = root.get_texture().get_image()
	var corner := (Vector2i(at) - Vector2i(SIZE.x / 2, 150)).clamp(Vector2i.ZERO, img.get_size() - SIZE)
	return img.get_region(Rect2i(corner, SIZE))


func _save(set_name: String, images: Array[Image]) -> void:
	var dir := ProjectSettings.globalize_path(OUT).path_join(set_name)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for i in images.size():
		images[i].save_png(dir.path_join("%d.png" % i))
	print("frames ", set_name, " ", images.size())


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _finish_dialogue() -> void:
	var dm: Node = sl.get_dialogue_manager()
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return
