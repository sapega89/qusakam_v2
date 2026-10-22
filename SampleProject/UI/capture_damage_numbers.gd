extends SceneTree

## Кадри цифр урону (D66, D393) у справжньому вікні DesertRoad: удар по ворогу, крит, удар по героєві, ухилення.
## Кожен кадр — вирізка 480×320 навколо героя.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_damage_numbers.gd -- <тека>

var game: Node
var hero: Node
var sl: Node
var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
var out_dir: String


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	rolls.calm()
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	sl.get_save_system().settings_module.settings.tutorial_windows = false  # D289
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue()
	await create_timer(2.5).timeout
	await _finish_dialogue()
	hero = game.player
	var enemies: Array = []
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
	var gm: Node = sl.get_game_manager()

	await _place(target, -40)
	hero.combat.perform_attack(1)
	await create_timer(0.3).timeout
	await _shot("damage_numbers_enemy_hit")
	await create_timer(1.5).timeout

	_lucky(gm.calculate_critical_chance())
	hero.combat.perform_attack(1)
	await create_timer(0.3).timeout
	await _shot("damage_numbers_crit")
	await create_timer(1.5).timeout

	rolls.calm()
	hero.take_damage(12, target)
	await create_timer(0.3).timeout
	await _shot("damage_numbers_hero_hit")
	await create_timer(1.5).timeout

	await _place(target, -40)
	_lucky(gm.calculate_dodge_chance())
	hero.take_damage(12, target)
	await create_timer(0.3).timeout
	await _shot("damage_numbers_evaded")
	quit()


## Засів, з яким наступний кидок з шансом [param chance] випаде.
func _lucky(chance: float) -> void:
	var rng: RandomNumberGenerator = rolls.rng
	for s in range(1, 100000):
		rng.seed = s
		if rng.randf() < chance:
			rng.seed = s
			return


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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var at: Vector2 = root.get_viewport().get_canvas_transform() * hero.global_position
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(at) - Vector2i(240, 200), Vector2i(480, 320)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", rect)
