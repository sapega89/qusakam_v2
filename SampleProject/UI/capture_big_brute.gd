extends SceneTree

## Знімок D693 / D582: бандит-громило у своїй першій точці (DesertRoad Fight_LoneElite, BigSlot_BanditBrute_1) — сам.
## Герой стає в зону бою, громило тягне булаву до нього, закидає її на плече (червоний спалах — лише ухилитись) і гупає
## нею в землю. Три кадри в одному design/shots/big_brute/bandit_brute_lone_elite.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_big_brute.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const PANEL := Vector2i(900, 300)

var game: Node
var hero: Node
var panels: Array[Image] = []


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	await create_timer(0.5).timeout
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	await create_timer(0.6).timeout
	var fight: Node = game.map.get_node(^"Fight_LoneElite")
	# Вхід у зону бою (тригер на x 4300) — герой стає в неї, бій стартує сам.
	hero.global_position = Vector2(4320, 340)
	hero.velocity = Vector2.ZERO
	hero.set_invulnerable(true, 30.0)
	await _until(func() -> bool: return fight.has_node(^"Enemy_Fight_LoneElite_EnemySpawnPoint1"))
	var brute: Node = fight.get_node(^"Enemy_Fight_LoneElite_EnemySpawnPoint1")
	await process_frame
	print("spawned %s elite=%s level %d HP %d damage %.0f" % [brute.enemy_stats.enemy_type, brute.elite, brute.level, brute.Max_Health, brute.damage])
	var centre := func() -> Vector2: return (hero.global_position + brute.global_position) / 2.0 + Vector2(0, -20)
	await _until(func() -> bool: return brute.anim_player.current_animation == &"walk" and brute.global_position.x < 4440.0)
	await _grab(centre.call())
	var sprite: Sprite2D = brute.get_node(^"Sprite2D")
	await _until(func() -> bool: return brute.anim_player.current_animation == &"attack" and sprite.frame == 8 and brute.anim_player.current_animation_position > 0.4)
	await _grab(centre.call())
	await _until(func() -> bool: return brute.anim_player.current_animation == &"attack" and sprite.frame == 9)
	await _grab(centre.call())

	var sheet := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, PANEL.y * i))
	var out := ProjectSettings.globalize_path("res://design/shots/big_brute/bandit_brute_lone_elite.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


func _until(done: Callable) -> void:
	for i in 900:
		if done.call():
			return
		await physics_frame
	push_error("capture_big_brute: timed out")


## Кадр навколо [param world] (світові px), PANEL завбільшки, у panels.
func _grab(world: Vector2) -> void:
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	var mid: Vector2 = root.get_viewport().get_canvas_transform() * world
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(mid) - PANEL / 2, PANEL).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.convert(Image.FORMAT_RGBA8)
	var panel := Image.create(PANEL.x, PANEL.y, false, Image.FORMAT_RGBA8)
	panel.blit_rect(img, rect, Vector2i.ZERO)
	panels.append(panel)
	Engine.time_scale = 1.0
