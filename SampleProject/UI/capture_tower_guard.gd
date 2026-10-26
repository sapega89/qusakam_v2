extends SceneTree

## Знімок D693 / D582: вартовий з баштовим щитом. Точки BigSlot для нього немає (D682), тож знімок ставить його туди,
## де дорога вперше показує щитоносця (DesertRoad Fight_LoneShield, сам; сам бій прибрано, щоб не спавнив свого).
## Вартовий іде до героя зі щитом попереду, коле мечем повз край щита, а важкий удар відбиває щит убік (кадр hurt).
## Три кадри в одному design/shots/big_guard/tower_guard_lone_shield.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_tower_guard.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const PANEL := Vector2i(900, 300)

var game: Node
var hero: Node
var panels: Array[Image] = []


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
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
	var fight: Node = game.map.get_node(^"Fight_LoneShield")
	var at: Vector2 = fight.get_node(^"EnemySpawnPoint1").global_position
	fight.free()
	hero.global_position = at + Vector2(-170, -20)
	hero.velocity = Vector2.ZERO
	hero.set_invulnerable(true, 30.0)
	var point: Node = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd").new()
	point.enemy_type = "shield"
	point.big_kind = "tower_shield_guard"
	var guard: Node = load(point.scene_path(point.kind())).instantiate()
	guard.enemy_stats = point.enemy_stats()
	guard.level = 2
	guard.global_position = at
	game.map.add_child(guard)
	point.free()
	await process_frame
	print("spawned %s elite=%s level %d HP %d damage %.0f" % [guard.enemy_stats.enemy_type, guard.elite, guard.level, guard.Max_Health, guard.damage])
	var centre := func() -> Vector2: return (hero.global_position + guard.global_position) / 2.0 + Vector2(0, -20)
	await _until(func() -> bool: return guard.anim_player.current_animation == &"walk" and guard.global_position.x < at.x - 40.0)
	await _grab(centre.call())
	var sprite: Sprite2D = guard.get_node(^"Sprite2D")
	await _until(func() -> bool: return guard.anim_player.current_animation == &"attack" and sprite.frame == 9 and guard.anim_player.current_animation_position > 0.6)
	guard.anim_player.pause()  # кадр удару на знімку, а не наступний
	await _grab(centre.call())
	guard.anim_player.play()
	print("thrust: frame %d at %.2f s" % [sprite.frame, guard.anim_player.current_animation_position])
	await create_timer(1.0).timeout
	guard.break_shield(hero.global_position.x)
	await create_timer(0.25).timeout
	await _grab(centre.call())
	print("guard broken: shield_up %s, frame %d" % [guard.shield_up, sprite.frame])

	var sheet := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, PANEL.y * i))
	var out := ProjectSettings.globalize_path("res://design/shots/big_guard/tower_guard_lone_shield.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


func _until(done: Callable) -> void:
	for i in 900:
		if done.call():
			return
		await physics_frame
	push_error("capture_tower_guard: timed out")


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
