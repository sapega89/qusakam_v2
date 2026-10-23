extends SceneTree

## Піке грифа (D445, design/flying_enemies_plan.md) на справжній DesertRoad, чотири кадри в одному
## design/shots/flying_enemies/vulture_dive.png: кружляє над героєм поза досяжністю → замах і червона підказка →
## піке по прямій → низько пролітає крізь героя (тут його можна бити; герой тут невразливий, щоб не вилізла підказка).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##     --script res://SampleProject/UI/capture_flying_enemies.gd

const VULTURE := "res://SampleProject/Scenes/Characters/Enemies/enemy_vulture.tscn"
const PANEL := Vector2i(640, 440)

var game: Node
var hero: Node
var panels: Array[Image] = []


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
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
	hero.Max_Health = 9999
	hero.current_health = 9999
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.global_position.x = 560.0
	await create_timer(0.6).timeout

	var vulture: Node = load(VULTURE).instantiate()
	vulture.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_vulture.tres")
	vulture.position = game.map.to_local(hero.global_position + Vector2(90, -150))
	game.map.add_child(vulture)
	await physics_frame
	var logic: Node = vulture.enemy_logic
	logic.attack_ready_in = 2.0
	logic.change_state(1)
	var centre := func() -> Vector2: return (hero.global_position + vulture.global_position) / 2.0
	await create_timer(1.4).timeout
	await _grab(centre.call())
	await _until(func() -> bool: return logic.committed)
	await create_timer(0.15).timeout
	await _grab(centre.call())
	await _until(func() -> bool: return logic.phase == logic.Phase.DIVE)
	hero.set_invulnerable(true, 2.0)  # без удару: підказка про блок (на збій героя) закрила б останній кадр
	await create_timer(0.18).timeout
	await _grab(centre.call())
	await _until(func() -> bool: return logic.phase == logic.Phase.GLIDE)
	await create_timer(0.15).timeout
	await _grab(centre.call())

	var sheet := Image.create(PANEL.x * 2, PANEL.y * 2, false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(PANEL.x * (i % 2), PANEL.y * (i / 2)))
	var out := ProjectSettings.globalize_path("res://design/shots/flying_enemies/vulture_dive.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


func _until(done: Callable) -> void:
	for i in 600:
		if done.call():
			return
		await physics_frame


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
