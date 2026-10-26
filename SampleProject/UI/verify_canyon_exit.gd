extends SceneTree

## Медитація на вершині скелі (feedback 8): викрадення — лише після підйому й медитації.
## Спуск з каньйону (D256): після села край плато біля містка запускає кат-сцену — місток падає, Canyon_ExitCutscene,
## Кусакам злазить за камінь переднього плану, камера пливе до синього неба, і він уже на дорозі. До села — просто край.
##   godot --headless --path . --script res://SampleProject/UI/verify_canyon_exit.gd


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

func _press_accept_key() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	for i in 3: await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	for i in 3: await process_frame

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _enter_canyon(game: Node, flags: Dictionary) -> void:
	var all: Dictionary = game.get_quest_flags().duplicate()
	all.merge(flags, true)
	game.set_quest_flags(all)
	await game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 20: await process_frame

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[0] The abduction waits for the climb: on the summit Kusakam sits to meditate, the camera drifts left, the raid (Sapega, 2026-10-20)")
	await _enter_canyon(game, {"canyon_intro_complete": true})
	ck(game.map.get_current_state_name() == "EXPLORATION", "waits in EXPLORATION (%s)" % game.map.get_current_state_name())
	var player0: Node2D = game.player
	player0.global_position = Vector2(1040, 360)  # біля західного підніжжя скелі, де раніше стояв тригер
	for i in 30: await process_frame
	ck(started.is_empty() and game.map.get_current_state_name() == "EXPLORATION", "nothing plays at the foot of the rock (%s)" % [started])
	# Справжній шлях: від східного підніжжя вгору терасами — ліворуч і стрибки.
	player0.global_position = Vector2(2050, 360)
	for i in 20: await process_frame
	var anim0: AnimationPlayer = player0.get_node(^"AnimationPlayer")
	var camera0: Camera2D = player0.get_node(^"Camera2D")
	var on_top_before := false
	Input.action_press(&"move_left")
	var climb_start := Time.get_ticks_msec()
	while game.map.get_current_state_name() == "EXPLORATION" and Time.get_ticks_msec() - climb_start < 12000:
		if player0.global_position.x < 1550 and player0.global_position.y < 200:
			on_top_before = on_top_before or started.is_empty()
		Input.action_press(&"jump")
		for i in 14: await process_frame
		Input.action_release(&"jump")
		for i in 14: await process_frame
	Input.action_release(&"move_left")
	ck(on_top_before, "on the summit before anything plays: the climb comes first")
	ck(game.map.get_current_state_name() == "CUTSCENE_ABDUCTION", "the meditation spot on the summit starts the cutscene (%s)" % game.map.get_current_state_name())
	ck(player0.global_position.y < 216.0, "it fires up on the rock (y=%.0f)" % player0.global_position.y)
	ck(player0.event, "the cutscene takes the input")
	var seat: Vector2 = game.map.get_node(^"Meditation/Seat").global_position
	await _until(func() -> bool: return anim0.current_animation == "Meditate", 10.0)
	ck(started.size() > 0 and started[0] == "Canyon_Exploration", "Canyon_Exploration first (%s)" % [started])
	ck(anim0.current_animation == "Meditate" and player0.global_position.distance_to(seat) < 2.0,
			"Kusakam sits down at the stone (%s at %s)" % [anim0.current_animation, player0.global_position])
	var x_sit: float = camera0.get_screen_center_position().x
	var x_seat := player0.global_position.x
	Input.action_press(&"move_right")
	for i in 20: await process_frame
	Input.action_release(&"move_right")
	ck(absf(player0.global_position.x - x_seat) < 1.0 and anim0.current_animation == "Meditate", "move_right does nothing, he keeps sitting")
	ck(not started.has("VillageAbduction"), "the raid waits until the camera has drifted")
	await _until(func() -> bool: return started.has("VillageAbduction"), 10.0)
	var drift: float = x_sit - camera0.get_screen_center_position().x
	ck(drift > 200.0, "the camera drifted left before the raid (%.0f px)" % drift)
	var fade: CanvasLayer = root.get_node_or_null(^"ScreenFade")
	ck(fade != null and fade.get_child(0).color.a > 0.9, "the raid plays over a black screen")
	ck(dm.current_dialogue_box.is_visible_in_tree() and dm.current_dialogue_box.get_parent().layer > fade.layer,
			"the dialogue box is shown above the black")
	await _drain(dm)
	print("[0b] The talk after the meditation: Kusakam already stands, a white cloud over him, no input until it ends (item 25, D263)")
	dm.bubble_time_scale = 1.0  # перша репліка набирається по-справжньому
	await _until(func() -> bool: return started.has("Canyon_AbductionCutscene"), 8.0)
	ck(not root.has_node(^"ScreenFade"), "light again before the talk")
	ck(not camera0.top_level and camera0.position == Vector2.ZERO, "the camera is back on Kusakam when the talk starts")
	ck(anim0.current_animation != "Meditate", "he has risen from the disc when the talk starts (%s)" % anim0.current_animation)
	var cloud: Node2D = null
	for child in player0.get_children():
		if child.has_method(&"type_out"):
			cloud = child
	ck(cloud != null, "the talk is in a speech cloud over Kusakam")
	ck(not dm.current_dialogue_box.is_visible_in_tree(), "the dialogue box is not shown")
	ck(dm.is_dialogue_active() and player0.event, "the talk counts as a dialogue and holds the input")
	await _until(func() -> bool: return cloud.visible, 2.0)
	var cloud_label: Label = cloud.get_child(0).get_child(0)
	ck(cloud_label.text.begins_with("What is that?"), "the cloud opens on Kusakam's first line, no narration (D437: '%s')" % cloud_label.text.left(30))
	# Набір — як у вікні (D738: Enter посеред набору показує всю репліку одразу, наступний Enter — наступна).
	var first_line := cloud_label.text
	ck(not cloud.is_typed(), "the first line is still typing")
	await _press_accept_key()
	ck(cloud_label.text == first_line and cloud.is_typed(), "D738: Enter while the line types shows the whole line at once (%.2f typed)" % cloud_label.visible_ratio)
	var x_talk := player0.global_position.x
	Input.action_press(&"move_right")
	Input.action_press(&"attack")
	for i in 20: await process_frame
	Input.action_release(&"move_right")
	Input.action_release(&"attack")
	ck(absf(player0.global_position.x - x_talk) < 1.0 and anim0.current_animation == "Idle",
			"move_right / attack do nothing, he stays in Idle (%s, dx %.1f)" % [anim0.current_animation, player0.global_position.x - x_talk])
	await _until(func() -> bool: return cloud.is_typed(), 6.0)
	ck(cloud.is_typed(), "the line finishes typing")
	dm.bubble_time_scale = 0.0  # решта реплік — без очікування набору
	await _press_accept_key()
	ck(cloud_label.text != first_line, "Enter after the line is typed shows the next one")
	# Та сама дія з геймпада (A) і миші (ЛКМ) — пункт 24.
	var line2 := cloud_label.text
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Input.parse_input_event(pad)
	for i in 3: await process_frame
	pad = pad.duplicate()
	pad.pressed = false
	Input.parse_input_event(pad)
	for i in 3: await process_frame
	ck(cloud_label.text != line2, "gamepad A shows the next line")
	var line3 := cloud_label.text
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(root.size) * 0.5
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	for i in 3: await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	for i in 3: await process_frame
	ck(cloud_label.text != line3, "a mouse click shows the next line")
	for i in 20:
		if not dm.is_bubble_playing(): break
		await _press_accept_key()
	ck(not dm.is_bubble_playing() and not is_instance_valid(cloud), "the talk ends, the cloud is gone")
	for i in 10: await process_frame
	ck(started == ["Canyon_Exploration", "VillageAbduction", "Canyon_AbductionCutscene"], "climb, meditation, raid, ridge (%s)" % [started])
	ck(game.get_quest_flag("canyon_exploration_complete") and game.get_quest_flag("canyon_abduction_complete"),
			"both flags set (journal: Explore the Canyon, Find a way forward)")
	ck(not player0.event and not dm.is_dialogue_active(), "the input is back after the talk")
	started.clear()

	print("[1] Before the village the edge by the bridge is just an edge")
	await _enter_canyon(game, {"canyon_intro_complete": true, "canyon_exploration_complete": true})
	game.player.global_position = game.map.get_node(^"CanyonExitTrigger/CollisionShape2D").global_position
	for i in 30: await process_frame
	ck(not started.has("Canyon_ExitCutscene"), "no exit cutscene before the village (%s)" % [started])
	var bridge: Node = game.map.get_node("Bridge")
	ck(bridge.get_node("Pieces").visible and not game.map.get_node("Gorge").visible, "before the village the bridge stands over a hidden gorge (D231)")
	ck(game.map.get_node("TileMap/Gate2").enabled, "and its deck is solid")
	ck(game.map.scene_file_path.ends_with("Canyon.tscn"), "still in the Canyon")
	await _drain(dm)  # RoadToVillage: після викрадення, до села

	print("[2] After the village, walking to the edge starts the descent cutscene (D256)")
	await _enter_canyon(game, {"canyon_abduction_complete": true, "village_abduction_complete": true,
			"village_arrival_complete": true, "village_fight_complete": true, "village_left_complete": true})
	ck(game.map.get_current_state_name() == "RELIC_PICKUP", "Canyon waits in RELIC_PICKUP (%s)" % game.map.get_current_state_name())
	var player: Node2D = game.player
	var hp: int = player.current_health
	player.global_position = Vector2(1000, 370)
	for i in 30: await process_frame
	Input.action_press(&"move_left")  # гравець сам іде до краю
	await _until(func() -> bool: return player.event, 5.0)
	Input.action_release(&"move_left")
	ck(game.map.get_current_state_name() == "EXIT_CUTSCENE", "the edge starts the descent (%s)" % game.map.get_current_state_name())
	ck(game.get_quest_flag("canyon_bridge_collapsed"), "the bridge collapses as the cutscene opens")
	var x0: float = player.global_position.x
	Input.action_press(&"move_right")
	for i in 20: await process_frame
	Input.action_release(&"move_right")
	ck(absf(player.global_position.x - x0) < 1.0, "input is taken: move_right does nothing (dx=%.1f)" % (player.global_position.x - x0))
	await create_timer(1.2).timeout
	ck(game.map.get_node("Gorge").visible and game.map.get_node("Gorge").modulate.a > 0.99, "the gorge's ledges show")
	await _until(func() -> bool: return started.has("Canyon_ExitCutscene"), 5.0)
	ck(started.has("Canyon_ExitCutscene"), "Canyon_ExitCutscene plays (%s)" % [started])
	await _drain(dm)
	ck(player.event, "the dialogue ends, the cutscene keeps the input")

	print("[3] Kusakam climbs down behind the foreground rock, the camera floats up to the sky")
	var rock: Sprite2D = game.map.get_node(^"ForegroundRock")
	var below: Vector2 = game.map.get_node(^"Descent/Below").global_position
	var falls: Array[String] = []
	var watch := func() -> void:
		var anim: String = player.get_node(^"AnimationPlayer").current_animation
		if anim == "Fall" and not falls.has(anim): falls.append(anim)
	process_frame.connect(watch)
	await _until(func() -> bool: return player.global_position.distance_to(below) < 1.0, 10.0)
	# Кожен кут і середина кадру героя лягають на непрозорий піксель каменя — його не видно.
	var hero_sprite: Sprite2D = player.get_node(^"Sprite2D")
	var hero: Rect2 = hero_sprite.get_global_transform() * hero_sprite.get_rect()
	var rock_image: Image = rock.texture.get_image()
	var hidden := 0
	for p in [hero.position, hero.position + Vector2(hero.size.x, 0), hero.position + Vector2(0, hero.size.y), hero.end, hero.get_center()]:
		var local: Vector2 = rock.get_global_transform().affine_inverse() * p
		var inside := Rect2(Vector2.ZERO, rock_image.get_size()).has_point(local)
		if inside and rock_image.get_pixelv(Vector2i(local)).a > 0.5:
			hidden += 1
	ck(hidden == 5, "at the bottom the hero is wholly behind the rock (%d/5 points covered, hero %s)" % [hidden, hero])
	ck(rock.z_index > player.z_index, "the rock is drawn in front of the hero (z %d > %d)" % [rock.z_index, player.z_index])
	var camera: Camera2D = player.get_node(^"Camera2D")
	var sky_top: float = game.map.get_node(^"HighSky").global_position.y
	var half_h: float = camera.get_viewport_rect().size.y / camera.zoom.y / 2.0
	await _until(func() -> bool: return camera.get_screen_center_position().y - half_h < sky_top + 1.0, 8.0)
	ck(camera.get_screen_center_position().y < 0.0, "the camera has floated up above the room into the sky (y=%.0f)" % camera.get_screen_center_position().y)
	var sky_color: Color = game.map.get_node(^"HighSky").texture.gradient.sample(0.0)
	ck(sky_color.b > sky_color.r + 0.3, "the sky up there is blue (%s)" % sky_color)
	process_frame.disconnect(watch)
	ck(falls.is_empty(), "no Fall animation: Kusakam climbs, he does not fall")
	ck(player.current_health == hp, "no damage (%d → %d)" % [hp, player.current_health])

	print("[4] The cutscene ends on the road")
	await _until(func() -> bool: return game.map.scene_file_path.ends_with("DesertRoad.tscn"), 8.0)
	for i in 30: await process_frame
	ck(game.map.scene_file_path.ends_with("DesertRoad.tscn"), "player is on the Desert Road (%s)" % game.map.scene_file_path)
	var arrival: Node2D = game.map.get_node("ArrivalFromCanyon")
	ck(absf(player.global_position.x - arrival.global_position.x) < 48.0,
			"player stands at ArrivalFromCanyon (x=%.0f)" % player.global_position.x)
	ck(game.get_quest_flag("canyon_exit_complete"), "canyon_exit_complete set")
	ck(not player.event, "the player can move")
	ck(not camera.top_level and camera.position == Vector2.ZERO, "the camera follows the hero again")

	print("[5] Enter shows the next bubble line at once (Sapega, 2026-10-16)")
	await _drain(dm)
	await _until(func() -> bool: return not dm.is_bubble_playing(), 5.0)
	dm.bubble_time_scale = 1.0  # справжні 2–6 с на репліку
	dm.start_dialogue("res://dialogue_quest/Canyon_Exploration.dqd")  # 4 репліки Кусакама
	for i in 3: await process_frame
	ck(dm.is_bubble_playing(), "the monologue plays as a bubble")
	var t0 := Time.get_ticks_msec()
	for line in 4:
		var press := InputEventAction.new()
		press.action = &"dq_accept"
		press.pressed = true
		Input.parse_input_event(press)
		for i in 3: await process_frame
	ck(not dm.is_bubble_playing(), "4 presses → monologue over in %d ms, not ~10 s" % (Time.get_ticks_msec() - t0))
	dm.bubble_time_scale = 0.0

	print("[6] The scene goes away mid-monologue (menu / new game / load)")
	dm.bubble_time_scale = 1.0
	dm.start_dialogue("res://dialogue_quest/Canyon_Exploration.dqd")
	for i in 3: await process_frame
	ck(dm.is_bubble_playing(), "a monologue is playing")
	game.remove_child(player)  # облачко — дитина гравця, йде з ним, як при закритті Game
	for i in 3: await process_frame
	ck(not dm.is_bubble_playing(), "the monologue ended with its bubble, no show_line() on a freed node")
	game.add_child(player)
	dm.bubble_time_scale = 0.0
	started.clear()
	dm.start_dialogue("res://dialogue_quest/VillageAbduction.dqd")
	for i in 3: await process_frame
	ck(started == ["VillageAbduction"], "the next dialogue still plays, not stuck in the queue (%s)" % [started])
	await _drain(dm)

	print("RESULT:" + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
