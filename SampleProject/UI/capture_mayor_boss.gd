extends SceneTree

## Кадри боса Зали мера (D468, D557): сокирник Скорпікори — підказка удару об землю (червоний відблиск на сокирі)
## і сам удар з хвилею; у залі — велетенський скорпіон дибки в кат-сцені. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_mayor_boss.gd -- <out_dir>
## Файли: <out_dir>/mayor_boss_<shot>.png

const WARRIOR := "res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn"
const HALL := "res://SampleProject/Maps/MayorHall.tscn"

var game: Node
var hero: Node
var dm: Node
var out_dir := ""
var floor_y := 0.0
var arena_x := 0.0

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue()
	await create_timer(1.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.global_position.x += 700.0
	await create_timer(1.0).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	var boss: Node = load(WARRIOR).instantiate()
	hero.global_position = Vector2(arena_x - 700.0, floor_y)
	boss.position = game.map.to_local(Vector2(arena_x + 160.0, floor_y - 40.0))
	game.map.add_child(boss)
	await create_timer(1.0).timeout
	boss.set_physics_process(false)
	await _slam(boss, "slam_tell", _tell.bind(boss))
	await _slam(boss, "slam", _wave)
	boss.queue_free()

	await game.teleport_to_room(HALL, ^"Arrival")
	for i in 30: await physics_frame
	var scorpion: Node2D = game.map.get_node(^"GiantScorpion")
	var anim: AnimationPlayer = scorpion.get_node(^"AnimationPlayer")
	var ev := InputEventAction.new()
	ev.action = &"move_right"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 6000:
		if game.map.get_current_state_name() != "QUEUE":
			ev.pressed = false
			Input.parse_input_event(ev)
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		if anim.current_animation == &"sting":
			break
		await process_frame
	await create_timer(0.5).timeout
	await _shot("scorpion_rears")
	quit()

func _finish_dialogue() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/mayor_boss_%s.png" % [out_dir, name])
	print("shot ", name)

## Підказка (живе 0.25 с) — час сповільнюємо й зупиняємо на ній.
func _tell(boss: Node) -> void:
	Engine.time_scale = 0.1
	for i in 3000:
		if boss.get_children().any(func(n: Node) -> bool: return n.get_script() == preload("res://SampleProject/Scripts/FX/EnemyTell.gd")):
			break
		await process_frame
	await create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 0.0

func _wave() -> void:
	for i in 300:
		if game.map.get_children().any(func(n: Node) -> bool: return n.scene_file_path.contains("/FX/Bosses/")):
			break
		await physics_frame
	await create_timer(0.12).timeout

## Бос робить лише удар об землю; кадр — коли [param moment] дочекався своєї миті.
func _slam(boss: Node, name: String, moment: Callable) -> void:
	var all: Array[Dictionary] = boss.moves
	var only: Array[Dictionary] = all.filter(func(m: Dictionary) -> bool: return m.kind == "slam")
	boss.moves = only
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position = Vector2(boss.global_position.x - 200.0, floor_y)
	hero.velocity = Vector2.ZERO
	boss.enemy_logic.last_move = {}
	boss.enemy_logic.attack_ready_in = 0.0
	hero.set_physics_process(false)  # удар не відкидає героя, поки знімаємо
	boss.set_physics_process(true)
	await moment.call()
	await _shot(name)
	Engine.time_scale = 1.0
	for i in 400:
		if not boss.enemy_logic.is_attacking:
			break
		await physics_frame
	boss.set_physics_process(false)
	hero.set_physics_process(true)
	boss.moves = all
	await create_timer(1.0).timeout
