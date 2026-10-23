extends SceneTree

## Асисти компаньйонів (D464, D465) у справжньому вікні DesertRoad: кожен асист окремо, два кадри — мить першого
## влучання (+0,08 с) і пізніше (+0,4 с), коли видно ланцюг, зірки й пил. Тег — після «--» (before / after):
## design/shots/companions/<тег>_<id>_<n>.png. Склеює before / after в одну картинку Scripts/Tools/companion_shots.py.
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_companion_assists.gd -- after

const OUT := "res://design/shots/companions"
const ORDER := ["astrit", "alisia", "urizen", "guard"]
const SHOT_DELAYS := [0.08, 0.4]
## Вирізка навколо середини між героєм і рядом ворогів (екранні px).
const CROP_SIZE := Vector2i(1100, 460)

var game: Node
var hero: Node2D
var enemies: Array = []
var _hit_at := -1


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var tag: String = OS.get_cmdline_user_args()[0]
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	get_first_node_in_group("tutorial_hint_display").modulate.a = 0.0
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	enemies = game.map.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies"))
	var cm: Node = sl.get_companion_manager()
	for f in cm.UNLOCK_FLAGS.values():
		game.set_quest_flag(f, true)
	root.get_node("EventBus").damage_dealt.connect(func(source: Node, _t: Node, _a: int) -> void:
		if _hit_at < 0 and source.is_in_group(&"companions"):
			_hit_at = Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in ORDER:
		_line_up()
		for i in 20: await physics_frame
		cm.reset()
		sl.get_game_manager().player_state.companion_party = [] if id == "guard" else [id]
		if id == "guard":
			cm.offer_guard(true)
		_hit_at = -1
		cm.call_next()
		while _hit_at < 0:
			await process_frame
		for n in SHOT_DELAYS.size():
			while Time.get_ticks_msec() - _hit_at < SHOT_DELAYS[n] * 1000.0:
				await process_frame
			await RenderingServer.frame_post_draw
			_snap("%s/%s_%s_%d.png" % [OUT, tag, id, n])
		while not get_nodes_in_group(&"companions").is_empty():
			await process_frame
	print("companion shots done: ", tag)
	quit(0)


## Вороги — у ряд перед героєм, стоять на місці (без виявлення героя), живі й міцні.
func _line_up() -> void:
	hero.mover.last_direction = 1
	hero.get_node(^"Sprite2D").flip_h = false
	for i in enemies.size():
		var e: Node = enemies[i]
		e.Max_Health = 9999
		e.current_health = 9999
		e.poise_max = 99
		e.poise = 99
		e.detection_area.monitoring = false
		e.enemy_logic.current_state = 0
		e.velocity = Vector2.ZERO
		e.global_position = Vector2(hero.global_position.x + 90 + i * 70, e.global_position.y)


func _snap(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	var mid: Vector2 = (hero.global_position + Vector2(hero.global_position.x + 90 + (enemies.size() - 1) * 70, hero.global_position.y)) / 2.0
	var at: Vector2 = root.get_viewport().get_canvas_transform() * mid
	var corner := (Vector2i(at) - Vector2i(CROP_SIZE.x / 2, 300)).clamp(Vector2i.ZERO, img.get_size() - CROP_SIZE)
	img.get_region(Rect2i(corner, CROP_SIZE)).save_png(ProjectSettings.globalize_path(path))
	print("shot ", path)


func _finish_dialogue(dm: Node) -> void:
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
