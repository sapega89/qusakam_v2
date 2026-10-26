extends SceneTree

## Кадри лука й лучника (BACKLOG 40, design/ranged_plan.md) у справжньому вікні: стійка з луком, швидкий постріл,
## натяг, заряджений лук, заряджений постріл, стріла в стіні; лучник натягує з відблиском, його стріла, блок,
## парирована стріла летить назад. Кожен кадр — вирізка 640×300 навколо героя (і лучника).
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_bow.gd -- <тека>

var game: Node
var hero: Node
var sl: Node
var archer: Node
var out_dir: String
var arrow_script: Script


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	arrow_script = load("res://SampleProject/Scripts/Combat/Arrow.gd")
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
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
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.set_physics_process(false)
			node._set_collisions_disabled(true)
			node.visible = false
	var who: String = sl.get_game_manager().get_active_character().character_id
	var em: Node = sl.get_equipment_manager()
	var items: Node = sl.get_item_database()
	em.equip_item(who, "bow", "short_bow", items.get_item("short_bow"))  # вдягнений — в руці (D475)

	# Лук: стійка, швидкий постріл, натяг, заряджено, заряджений постріл
	await _stand(hero.global_position.x)
	hero.combat._combat_left = 3.0
	await create_timer(0.3).timeout
	await _shot("bow_stance")
	_action(&"attack", true)
	await create_timer(0.1).timeout
	await _shot("bow_quick_shot")
	await create_timer(0.35).timeout
	await _shot("bow_draw")
	await create_timer(0.6).timeout
	await _shot("bow_charged")
	_action(&"attack", false)
	await create_timer(0.06).timeout
	await _shot("bow_charged_release")
	await create_timer(1.0).timeout
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 200)
	wall.add_child(shape)
	game.map.add_child(wall)
	wall.global_position = Vector2(hero.global_position.x + 200.0, hero.global_position.y - 60.0)
	await _stand(hero.global_position.x)
	_action(&"attack", true)
	await physics_frame
	_action(&"attack", false)
	await create_timer(0.4).timeout
	await _shot("bow_arrow_in_wall")
	wall.queue_free()
	await create_timer(1.0).timeout

	# Лучник
	var point: Node2D = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd").new()
	point.enemy_type = "archer"
	point.spawn_id = "capture_archer"
	game.map.add_child(point)
	point.global_position = hero.global_position + Vector2(300, 8)
	archer = point.spawn_enemy()
	await create_timer(0.3).timeout
	await _archer_ready()
	await archer.enemy_logic.attack_telegraphed
	for i in 3: await physics_frame
	await _shot("archer_glint", 960)
	await _next_enemy_arrow()
	await create_timer(0.25).timeout
	await _shot("archer_arrow", 960)
	await _archer_ready()
	_action(&"block", true)
	var arrow: Node = await _next_enemy_arrow()
	while is_instance_valid(arrow) and absf(arrow.global_position.x - hero.global_position.x) > 60.0:
		await physics_frame
	await _shot("hero_blocks_arrow", 960)
	_action(&"block", false)
	await _archer_ready()
	arrow = await _next_enemy_arrow()
	while is_instance_valid(arrow) and absf(arrow.global_position.x - hero.global_position.x) > 70.0:
		await physics_frame
	_action(&"block", true)
	for i in 10: await physics_frame
	await _shot("hero_parries_arrow_back", 960)
	_action(&"block", false)
	await create_timer(0.5).timeout
	quit()


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


func _stand(x: float) -> void:
	hero.global_position.x = x
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	for i in 20: await physics_frame


## Один постріл на кадр: лучник не стріляє, доки в повітрі є стріла чи йде натяг; герой за 300 px — і постріл.
func _archer_ready() -> void:
	archer.enemy_logic.attack_ready_in = 1.0e9
	while archer.enemy_logic.is_attacking or game.map.get_children().any(func(n: Node) -> bool:
			return n.get_script() == arrow_script and not n._stuck):
		await physics_frame
	await _stand(archer.global_position.x - 300.0)
	hero.current_health = hero.Max_Health
	archer.enemy_logic.attack_ready_in = 0.0


func _next_enemy_arrow() -> Node:
	while true:
		var node: Node = await node_added
		if node.get_script() == arrow_script and not node.hero_side:
			return node
	return null


func _action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Вирізка [param width]×300: герой за 180 px від лівого краю (з лучником — ширша, щоб і він був у кадрі).
func _shot(name: String, width: int = 640) -> void:
	await RenderingServer.frame_post_draw
	var at: Vector2 = hero.get_global_transform_with_canvas().origin - Vector2(180, 190)
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(at), Vector2i(width, 300)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", rect)
