extends SceneTree

## Кадри souls-lite бою (BACKLOG 4 + 15, D264–D268) у справжньому вікні: серія, важкий, блок, парирування,
## збій героя й ворога, подвійний ривок, зброя схована / в руці, дві зброї, булава, алебарда.
## Кожен кадр — вирізка 480×320 навколо героя.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_souls_combat.gd -- <тека>

var game: Node
var hero: Node
var eb: Node
var sl: Node
var enemies: Array = []
var out_dir: String


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
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
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
			node.Max_Health = 9999
			node.current_health = 9999
			node.poise_max = 99
			node.poise = 99
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			node.enemy_logic.current_state = 0
	var target: Node = enemies[0]
	for e in enemies.slice(1):
		e.global_position.x = target.global_position.x + 900  # не в кадрі
	var who: String = sl.get_game_manager().get_active_character().character_id
	var em: Node = sl.get_equipment_manager()
	var items: Node = sl.get_item_database()

	# Зброї не видно (поза боєм) і в руці (бій)
	em.equip_item(who, "sword", "iron_sword", items.get_item("iron_sword"))
	await _place(target, -110)
	await create_timer(3.5).timeout
	await _shot("fb4_sheathed")
	target.enemy_logic.current_state = 1
	await create_timer(0.4).timeout
	await _shot("fb4_drawn")
	target.enemy_logic.current_state = 0

	# Серія меча
	await _place(target, -40)
	for i in 3:
		await _press(&"attack")
		await create_timer(0.09).timeout
		await _shot("fb4_combo_%d" % (i + 1))
		await create_timer(0.24).timeout
	await create_timer(1.0).timeout

	# Важкий
	await _place(target, -45)
	await _press(&"heavy_attack")
	await create_timer(0.25).timeout
	await _shot("fb4_heavy_windup")
	await create_timer(0.22).timeout
	await _shot("fb4_heavy_strike")
	await create_timer(1.3).timeout

	# Блок і парирування
	await _place(target, -45)
	_action(&"block", true)
	await create_timer(0.4).timeout
	hero.take_damage(10, target)
	await create_timer(0.05).timeout
	await _shot("fb4_block")
	_action(&"block", false)
	await create_timer(0.6).timeout
	_action(&"block", true)
	for i in 3: await physics_frame
	hero.take_damage(10, target)
	await create_timer(0.12).timeout
	await _shot("fb4_parry")
	_action(&"block", false)
	await create_timer(1.2).timeout

	# Збій героя і ворога
	await _place(target, -45)
	hero.take_damage(10, target)
	await create_timer(0.08).timeout
	await _shot("fb4_stagger_hero")
	await create_timer(1.0).timeout
	target.poise = 1
	target.set_physics_process(true)  # відтінок збою ставить _physics_process ворога
	await _place(target, -40)
	await _press(&"attack")
	await create_timer(0.2).timeout
	await _shot("fb4_stagger_enemy")
	target.set_physics_process(false)
	await create_timer(1.5).timeout

	# Подвійний ривок у повітрі
	await _place(target, -300)
	hero.velocity = Vector2(0, -420)
	for i in 10: await physics_frame
	await _press(&"dodge")
	await create_timer(0.15).timeout
	await _press(&"dodge")
	await create_timer(0.05).timeout
	await _shot("fb4_double_dash")
	await create_timer(1.5).timeout

	# Дві зброї
	em.equip_item(who, "dagger", "iron_dagger", items.get_item("iron_dagger"))
	await _place(target, -40)
	await _press(&"attack")
	await create_timer(0.3).timeout
	await _press(&"attack")
	await create_timer(0.08).timeout
	await _shot("fb4_dual_wield")
	await create_timer(1.0).timeout
	em.unequip_item(who, "dagger")
	em.unequip_item(who, "sword")

	# Булава і алебарда
	em.equip_item(who, "mace", "iron_mace", items.get_item("iron_mace"))
	await create_timer(1.0).timeout
	await _place(target, -40)
	await _press(&"attack")
	await create_timer(0.1).timeout
	await _shot("fb4_mace")
	await create_timer(1.0).timeout
	em.unequip_item(who, "mace")
	em.equip_item(who, "polearm", "iron_halberd", items.get_item("iron_halberd"))
	await create_timer(1.0).timeout
	await _place(target, -70)
	await _press(&"attack")
	await create_timer(0.12).timeout
	await _shot("fb4_halberd")
	quit(0)


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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var at: Vector2 = root.get_viewport().get_canvas_transform() * hero.global_position
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(at) - Vector2i(240, 200), Vector2i(480, 320)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", rect)
