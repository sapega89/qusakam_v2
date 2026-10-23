extends SceneTree

## Кадри для вікон туторіалу (BACKLOG 28, D-28e): кожен рух зіграно в справжній грі й записано вирізками
## 500×240 навколо героя (ShotFrame 1000×480 — рівно 2×) у SampleProject/Assets/UI/Tutorial/<набір>/0.png…
## Тема в tutorial.json називає набір полем "frames"; tutorial_menu.gd крутить їх по колу.
## Потрібне вікно (не --headless):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_tutorial_frames.gd
## Після запуску — `godot --headless --path . --import`, щоб нові PNG отримали .import.

const OUT := "res://SampleProject/Assets/UI/Tutorial"
const SIZE := Vector2i(500, 240)

var game: Node
var hero: Node
var sl: Node
var target: Node
## Центр вирізки: герой або середина між героєм і ворогом (бій видно цілком).
var _with_enemy := false


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
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue()
	await create_timer(2.5).timeout
	await _finish_dialogue()
	get_first_node_in_group("tutorial_hint_display").modulate.a = 0.0  # плашки не в кадрі
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	var enemies: Array = game.map.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies"))
	target = enemies[0]
	for e in enemies:
		e.Max_Health = 9999
		e.current_health = 9999
		e.poise_max = 99
		e.poise = 99
		_freeze(e, true)
		if e != target:
			e.global_position.x += 3000  # лише один ворог у кадрі
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 2:
		xp.add_xp(1000)
	sl.get_skill_manager().unlock_skill("healing_palm")

	# Рух: крок, стрибок, подвійний ривок
	await _place(-800)
	_with_enemy = false
	_action(&"move_right", true)
	_record("move_jump", 14, 0.1)
	await create_timer(0.35).timeout
	await _press(&"jump")
	await create_timer(0.75).timeout
	await _press(&"dodge")
	await create_timer(0.12).timeout
	await _press(&"dodge")
	await _done()
	_action(&"move_right", false)
	await create_timer(1.0).timeout

	# Серія з трьох ударів голими руками, ворог стоїть
	_with_enemy = true
	await _place(-45)
	_record("combo", 10, 0.09)
	for i in 3:
		await _press(&"attack")
		await create_timer(0.28).timeout
	await _done()
	await create_timer(1.2).timeout

	# Важкий удар
	await _place(-45)
	_record("heavy", 10, 0.08)
	await _press(&"heavy_attack")
	await _done()
	await create_timer(1.5).timeout

	# Длань лікування (D252): поранений герой лікується зі слота 1
	_with_enemy = false
	await _place(-300)
	hero.current_health = 5000
	_record("heal", 12, 0.1)
	await _press(&"skill_slot_1")
	await _done()
	await create_timer(1.0).timeout

	# Виклик компаньйона (D209)
	var cm: Node = sl.get_companion_manager()
	game.set_quest_flag("lab_companion_01_complete", true)
	cm.join_on_unlock("lab_companion_01_complete")
	await _place(-160)
	_with_enemy = true
	_record("assist", 12, 0.1)
	await _press(&"assist")
	await _done()
	await create_timer(2.0).timeout

	# Живий ворог: ривок крізь удар, блок, парирування на червоний відблиск (D264)
	_freeze(target, false)
	var logic: Node = target.enemy_logic
	await _place(-70)
	await _signal_or_timeout(logic.attack_started, 6.0)
	_record("dodge", 10, 0.07)
	await _signal_or_timeout(logic.attack_telegraphed, 2.0)
	await _press(&"dodge")
	await _done()
	await create_timer(1.5).timeout

	await _place(-70)
	_action(&"block", true)
	await _signal_or_timeout(logic.attack_started, 6.0)
	_record("block", 10, 0.08)
	await _done()
	_action(&"block", false)
	await create_timer(1.5).timeout

	await _place(-70)
	await _signal_or_timeout(logic.attack_started, 6.0)
	_record("parry", 12, 0.07)
	await _signal_or_timeout(logic.attack_telegraphed, 2.0)
	_action(&"block", true)
	await create_timer(0.3).timeout
	_action(&"block", false)
	await _done()
	print("frames done")
	quit(0)


func _freeze(enemy: Node, frozen: bool) -> void:
	enemy.set_physics_process(not frozen)
	enemy.detection_area.monitoring = not frozen
	if frozen:
		enemy.enemy_logic.current_state = 0


var _recording := false


## Запис іде паралельно з діями; дочекатися кінця — await _done().
func _record(set_name: String, count: int, interval: float) -> void:
	var dir := ProjectSettings.globalize_path(OUT).path_join(set_name)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	_recording = true
	_record_loop(dir, count, interval)


func _done() -> void:
	while _recording:
		await process_frame


func _record_loop(dir: String, count: int, interval: float) -> void:
	var ground_y: float = hero.global_position.y  # вирізка не скаче за стрибком: рамка стоїть, герой стрибає в ній
	for i in count:
		await RenderingServer.frame_post_draw
		var center: Vector2 = hero.global_position
		if _with_enemy:
			center = (hero.global_position + target.global_position) / 2.0
		center.y = ground_y
		var at: Vector2 = root.get_viewport().get_canvas_transform() * center
		var img: Image = root.get_texture().get_image()
		var corner := Vector2i(at) - Vector2i(SIZE.x / 2, 150)
		corner = corner.clamp(Vector2i.ZERO, img.get_size() - SIZE)
		img.get_region(Rect2i(corner, SIZE)).save_png(dir.path_join("%d.png" % i))
		await create_timer(interval).timeout
	print("frames ", dir.get_file(), " ", count)
	_recording = false


func _signal_or_timeout(sig: Signal, seconds: float) -> void:
	var fired := [false]
	var on_fire := func(_a: Variant = null, _b: Variant = null) -> void: fired[0] = true
	sig.connect(on_fire, CONNECT_ONE_SHOT)
	var left := seconds
	while not fired[0] and left > 0.0:
		await process_frame
		left -= 1.0 / 60.0
	if not fired[0]:
		sig.disconnect(on_fire)
		print("  timeout waiting for ", sig.get_name())


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


func _place(dx: float) -> void:
	hero.global_position = target.global_position + Vector2(dx, -4)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	for i in 12: await physics_frame


func _action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _press(action: StringName) -> void:
	_action(action, true)
	await physics_frame
	_action(action, false)
