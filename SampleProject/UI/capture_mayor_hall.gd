extends SceneTree

## Кадри зали мера (queue row 9.3): черга, пролам, бос вилазить, бій, перемога (дим) і програш, прибуття в лабораторію.
## Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_mayor_hall.gd -- <out_dir>
## Файли: <out_dir>/fb9_3_<shot>.png

const HALL := "res://SampleProject/Maps/MayorHall.tscn"

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()

	await _enter()
	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	await _page(3)
	_shot("queue")
	while not game.map.get_node(^"WallHole").visible:
		await _page(1)
	await create_timer(0.25).timeout
	_shot("wall_burst")
	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	await _page(2)
	_shot("collector_out")
	await _to_fight()
	var boss: Node2D = game.map.get_node(^"BrassCollector")
	game.player.Max_Health = 99999
	game.player.current_health = 99999
	game.player.global_position.x = boss.global_position.x - 200.0
	await create_timer(1.6).timeout
	_shot("fight")
	boss.current_health = 1
	game.player.global_position.x = boss.global_position.x - 50.0
	game.player.mover.last_direction = 1
	_press(&"attack")
	await create_timer(0.1).timeout
	_press(&"attack", false)
	dm.bubble_time_scale = 1.0  # MayorHall_Victory — монолог героя в облачках (D178)
	await _until(func() -> bool: return dm.is_bubble_playing(), 6.0)
	await create_timer(1.0).timeout
	_shot("win_gas")
	await _until(func() -> bool: return game.map.scene_file_path.ends_with("LabCells.tscn"), 30.0)
	dm.bubble_time_scale = 0.0
	await _drain()
	await create_timer(1.5).timeout
	_shot("win_lab")

	game.set_quest_flag("city_mayor_hall_complete", false)
	game.set_quest_flag("mayor_boss_defeated", false)
	await _enter()
	await _to_fight()
	boss = game.map.get_node(^"BrassCollector")
	game.player.current_health = 1
	game.player.global_position.x = boss.global_position.x - 90.0
	await _until(func() -> bool: return dm.is_dialogue_active(), 15.0)
	await _page(1)
	_shot("lose_dark")
	await _drain()
	await _until(func() -> bool: return game.map.scene_file_path.ends_with("LabCells.tscn"), 10.0)
	await create_timer(1.5).timeout
	_shot("lose_lab")
	quit()

func _enter() -> void:
	game.teleport_to_room(HALL, ^"Arrival")
	for i in 40: await physics_frame
	_press(&"move_right")
	await _until(func() -> bool: return game.map.get_current_state_name() != "QUEUE", 5.0)
	_press(&"move_right", false)

func _to_fight() -> void:
	while game.map.get_current_state_name() != "FIGHT":
		if dm.is_dialogue_active():
			await _page(1)
		await process_frame
	for i in 30: await physics_frame

## Гортає [param n] реплік і показує наступну повністю набраною.
func _page(n: int) -> void:
	for i in n:
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		for f in 6: await process_frame
	if dm.is_dialogue_active():
		dm.current_dialogue_box.finish()
	for f in 4: await process_frame

func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/fb9_3_%s.png" % [out_dir, name])
