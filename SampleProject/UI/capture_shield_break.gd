extends SceneTree

## Знімок B200 / D843: розбитий баштовий щит. Вартовий (як у capture_tower_guard — на місці DesertRoad Fight_LoneShield)
## іде зі щитом; важкий удар розбиває щит — скалки shield_break_1–4 розлітаються з того місця, де він був; після збою
## вартовий іде далі аркушем без щита. Три кадри в одному design/shots/shield_break.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_shield_break.gd

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
	guard.break_shield(hero.global_position.x)
	await create_timer(0.004).timeout  # hitstop (time scale 0.05): кадр 1–2 скалок
	await _grab(centre.call())
	await _until(func() -> bool: return not guard.enemy_view.staggered and guard.anim_player.current_animation == &"walk")
	await create_timer(0.3).timeout
	await _grab(centre.call())
	print("guard broken: shield_up %s, sheet %s" % [guard.shield_up, guard.get_node(^"Sprite2D").texture.resource_path.get_file()])

	var sheet := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, PANEL.y * i))
	var out := ProjectSettings.globalize_path("res://design/shots/shield_break.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


func _until(done: Callable) -> void:
	for i in 900:
		if done.call():
			return
		await physics_frame
	push_error("capture_shield_break: timed out")


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
