extends SceneTree

## Знімок D589 / D582: проклятий шакал сам-на-сам у коридорі середнього поверху лабораторії (Fight_Cursed) — герой
## спускається драбиною, іде на захід, шакал біжить на нього з синьою піною (D653), припадає й стрибає з укусом.
## Два кадри в одному design/shots/lab_curse/cursed_jackal_corridor.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_lab_curse.gd

const LAB := "res://SampleProject/Maps/Laboratory.tscn"
const PANEL := Vector2i(900, 360)

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
	await game.teleport_to_room(LAB, ^"SavePoint_Entrance")
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
	# Під драбиною: на блоці середнього поверху, зона бою — трохи на захід.
	hero.global_position = Vector2(1480, 800 - 32)
	hero.velocity = Vector2.ZERO
	await create_timer(0.6).timeout
	var fight: Node = game.map.get_node(^"Fight_Cursed")
	Input.action_press(&"move_left")
	await _until(func() -> bool: return hero.global_position.x < 1290.0)
	Input.action_release(&"move_left")
	await _until(func() -> bool: return not fight.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies")).is_empty())
	var jackal: Node = fight.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies"))[0]
	print("spawned %s elite=%s HP %d damage %.0f" % [jackal.enemy_stats.enemy_type, jackal.elite, jackal.Max_Health, jackal.damage])
	hero.set_invulnerable(true, 30.0)
	var centre := func() -> Vector2: return (hero.global_position + jackal.global_position) / 2.0 + Vector2(0, -10)
	await _until(func() -> bool: return jackal.anim_player.current_animation == &"walk" and jackal.global_position.x > 1150.0)
	await create_timer(0.1).timeout
	await _grab(centre.call())
	await _until(func() -> bool: return jackal.anim_player.current_animation == &"attack" and jackal.anim_player.current_animation_position > 0.3)
	await _grab(centre.call())

	var sheet := Image.create(PANEL.x, PANEL.y * 2, false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, PANEL.y * i))
	var out := ProjectSettings.globalize_path("res://design/shots/lab_curse/cursed_jackal_corridor.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


func _until(done: Callable) -> void:
	for i in 900:
		if done.call():
			return
		await physics_frame
	push_error("capture_lab_curse: timed out")


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
