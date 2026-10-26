extends SceneTree

## Знімок D652 / D692: броньований скорпіон у своїй першій точці — DesertRoad Fight_Caravan, BigSlot_ArmouredScorpion_1.
## Панель 1 — увесь бій каравану (великий скорпіон зліва, звичайний справа); 2 — великий і звичайний скорпіон поруч
## із героєм; 3 — удар жалом (кадр удару) з F9-зонами (D519): жовта зона-ціль, червоний хітбокс, біле тіло.
## Усе в design/shots/enemy_variety/armoured_scorpion.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_armoured_scorpion.gd

const PANEL := Vector2i(1100, 300)
const OUT := "res://design/shots/enemy_variety/armoured_scorpion.png"

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
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	await create_timer(1.0).timeout
	hero = game.player
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	var caravan: Node = game.map.get_node(^"Fight_Caravan")
	# Герой поза дальністю виявлення (300), поки вороги зʼявляються: ніхто не б'є, підказка блоку не вискакує
	hero.global_position = Vector2(caravan.get_node(^"BigSlot_ArmouredScorpion_1").global_position.x - 600.0, hero.global_position.y)
	await create_timer(0.6).timeout
	await caravan.spawn_all_enemies()  # хвилями по двоє (spawn_in_waves)
	await create_timer(0.8).timeout
	var big: Node = caravan.get_node(^"BigSlot_ArmouredScorpion_1").spawned_enemy
	var small: Node = caravan.get_node(^"EnemySpawnPoint5").spawned_enemy
	print("big: %s HP %d, damage %.1f, elite %s; small: %s HP %d" % [big.enemy_stats.enemy_type, big.Max_Health, big.base_damage,
			big.elite, small.enemy_stats.enemy_type, small.Max_Health])
	var enemies: Array = caravan.spawn_points.map(func(p: Node) -> Node: return p.spawned_enemy)
	for e: Node in enemies:
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
		e.anim_player.play(&"idle")
	_face_left(enemies)
	hero.global_position.x = big.global_position.x - 200.0
	await create_timer(1.0).timeout
	_face_left(enemies)
	await _grab(Vector2(big.global_position.x + 160.0, big.global_position.y), 0.85)

	# Поруч: герой, великий і звичайний скорпіон
	small.global_position = Vector2(big.global_position.x + 170.0, small.global_position.y)
	hero.global_position = Vector2(big.global_position.x - 130.0, hero.global_position.y)
	hero.mover.last_direction = 1
	await create_timer(1.0).timeout
	_face_left([big, small])
	await _grab(big.global_position + Vector2(40, 0), 1.6)

	# Удар жалом із F9-зонами
	small.queue_free()
	hero.global_position = Vector2(big.global_position.x - 70.0, hero.global_position.y)
	game.get_node(^"HitAreaDebug").get_script().enabled = true
	big.anim_player.play(&"attack")
	big.anim_player.seek(0.72, true)
	big.anim_player.pause()
	big.hitbox.monitorable = true
	await create_timer(1.0).timeout
	_face_left([big])
	await _grab(big.global_position + Vector2(0, -10), 2.0)

	var out := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		out.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, i * PANEL.y))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT)
	quit()


## Вороги дивляться ліворуч, на героя (кадри намальовано обличчям праворуч).
func _face_left(enemies: Array) -> void:
	for e: Node in enemies:
		e.enemy_logic.last_direction = -1
		e._on_logic_direction_changed(-1)


## Панель [constant PANEL] навколо точки світу [param world], збільшена в [param zoom] раз (менше 1 — ширший кадр).
func _grab(world: Vector2, zoom: float) -> void:
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	var mid := Vector2i(root.get_viewport().get_canvas_transform() * world)
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var crop := Vector2i(Vector2(PANEL) / zoom)
	var rect := Rect2i(mid - crop / 2, crop).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var panel := img.get_region(rect)
	panel.resize(PANEL.x, PANEL.y, Image.INTERPOLATE_NEAREST if zoom >= 1.0 else Image.INTERPOLATE_BILINEAR)
	panels.append(panel)
	Engine.time_scale = 1.0
