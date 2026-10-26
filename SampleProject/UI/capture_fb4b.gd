extends SceneTree

## Кадри черги 4b у справжньому вікні: замах ворога з відблиском, лінія ривка, парирування, блок без шкоди,
## влучання героя посеред завмирання, фінішер, удар по героєві (червоні краї, рядок HP) — і аркуш з усіх.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_fb4b.gd -- <тека>

var game: Node
var hero: Node
var sl: Node
var out_dir: String
var shots: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
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
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	var by_type: Dictionary = {}
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.Max_Health = 9999
			node.current_health = 9999
			node.poise_max = 99
			node.poise = 99
			node.combo_hits = 1
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			node.enemy_logic.current_state = 0
			by_type[node.enemy_stats.enemy_type] = node
			node.global_position.x += 2000  # прибрати з кадру; потрібних повертаємо нижче
	var melee: Node = by_type["melee"]
	var fast: Node = by_type["fast"]
	melee.global_position.x -= 2000

	# Замах із відблиском: відблиск спалахує за 0.25 с до удару
	await _place(melee, -90)
	melee.enemy_logic.last_direction = -1
	melee.enemy_view.update_direction(-1)
	melee.enemy_logic.perform_attack()
	await create_timer(0.2).timeout
	await _shot("fb4b_windup_pose", false, melee)
	await create_timer(melee.attack_windup - 0.25 + 0.08 - 0.2).timeout
	await _shot("fb4b_windup_tell", false, melee)
	await create_timer(1.5).timeout

	# Лінія ривка (fast)
	melee.global_position.x += 2000
	fast.global_position.x -= 2000
	await _place(fast, -150)
	fast.enemy_logic.last_direction = -1
	fast.enemy_view.update_direction(-1)
	fast.enemy_logic.perform_attack()
	await create_timer(fast.attack_windup - 0.25 + 0.1).timeout
	await _shot("fb4b_lunge_tell", false, fast)
	await create_timer(1.5).timeout
	fast.global_position.x += 2000
	melee.global_position.x -= 2000

	# Парирування: блок натиснуто 0.15 с до удару
	await _place(melee, -45)
	_action(&"block", true)
	await create_timer(0.15).timeout
	hero.take_damage(14, melee)
	await create_timer(0.03).timeout
	await _shot("fb4b_parry")
	_action(&"block", false)
	await create_timer(1.5).timeout

	# Блок без шкоди
	await _place(melee, -45)
	var hp0: int = hero.current_health
	_action(&"block", true)
	await create_timer(0.5).timeout
	hero.take_damage(14, melee)
	await create_timer(0.03).timeout
	await _shot("fb4b_block")
	print("block: HP %d → %d" % [hp0, hero.current_health])
	_action(&"block", false)
	await create_timer(1.2).timeout

	# Влучання посеред завмирання, потім фінішер серії
	await _place(melee, -50)
	await _press(&"attack")
	await _during_hitstop("fb4b_hitfeel_hit")
	await create_timer(0.35).timeout
	await _press(&"attack")
	await create_timer(0.4).timeout
	await _press(&"attack")
	await _during_hitstop("fb4b_hitfeel_finisher")
	await create_timer(1.5).timeout

	# Удар по героєві: важкий (як tank) — червоні краї, рядок HP, розтин; кадр усього екрана
	await _place(melee, -45)
	melee.stagger_time = 0.6
	hero.take_damage(20, melee)
	await create_timer(0.02).timeout
	await _shot("fb4b_hurt", true)
	await create_timer(1.0).timeout
	_sheet()
	quit(0)


func _during_hitstop(name: String) -> void:
	for i in 30:
		if Engine.time_scale < 1.0:
			break
		await process_frame
	await _shot(name)


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


func _place(target: Node, dx: float) -> void:
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


## Вирізка 480×320 навколо героя (або посередині між ним і [param also]), або весь екран ([param full]).
func _shot(name: String, full: bool = false, also: Node2D = null) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if not full:
		var focus: Vector2 = hero.global_position if also == null else (hero.global_position + also.global_position) / 2.0
		var at: Vector2 = root.get_viewport().get_canvas_transform() * focus
		var rect := Rect2i(Vector2i(at) - Vector2i(240, 200), Vector2i(480, 320)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(rect)
	img.save_png(out_dir.path_join(name + ".png"))
	shots.append(name)
	print("shot ", name)


## Аркуш: три в ряд, клітинка 480×320 (кадр усього екрана — зменшений).
func _sheet() -> void:
	var cell := Vector2i(480, 320)
	var cols := 3
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var img := Image.load_from_file(out_dir.path_join(shots[i] + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() > cell.x:
			img.resize(cell.x, roundi(cell.x * img.get_height() / float(img.get_width())))
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size().min(cell)), Vector2i(i % cols, i / cols) * cell)
	sheet.save_png(out_dir.path_join("fb4b_sheet.png"))
