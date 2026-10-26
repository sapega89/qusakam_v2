extends SceneTree

## Знімок великого лучника (D652, D692) у його першому місці (D719): BanditCamp Fight_Camp, друга хвиля — щитоносець
## попереду, великий лучник (BigSlot_HeavyArcher_4) позаду. Панелі: стоять поруч із героєм; натяг (кадр 8) з жовтим відблиском на
## наконечнику; стріла летить униз у героя; ×3 на натягнутий лук. Усе в одному design/shots/big_archer/camp.png.
## Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_heavy_archer.gd

const PANEL := Vector2i(1100, 300)

var game: Node
var hero: Node
var panels: Array[Image] = []
var arrow_script: Script
var arrows: Array[Node] = []


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	arrow_script = load("res://SampleProject/Scripts/Combat/Arrow.gd")
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
	await game.teleport_to_room("res://SampleProject/Maps/BanditCamp.tscn", ^"Arrival")
	await create_timer(0.6).timeout
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	node_added.connect(func(n: Node) -> void:
		if n.get_script() == arrow_script:
			arrows.append(n))
	await create_timer(0.6).timeout

	# Друга хвиля табору в її справжніх точках
	var camp: Node = game.map.get_node(^"Fight_Camp")
	camp.trigger_area.set_deferred(&"monitoring", false)  # лише ця хвиля, без решти бою
	await physics_frame
	var bearer: Node = camp.get_node(^"EnemySpawnPoint3").spawn_enemy()
	var heavy: Node = camp.get_node(^"BigSlot_HeavyArcher_4").spawn_enemy()
	await process_frame
	heavy.enemy_logic.attack_ready_in = 1.0e9  # перший постріл — коли все стоїть на місцях
	for i in 30: await physics_frame
	hero.global_position = Vector2(heavy.global_position.x - 220.0, heavy.global_position.y - 30.0)
	for i in 60: await physics_frame
	bearer.set_physics_process(false)
	bearer.enemy_logic.last_direction = -1
	bearer._on_logic_direction_changed(-1)
	bearer.anim_player.play(&"idle")
	heavy.anim_player.play(&"idle")
	hero.mover.last_direction = 1
	await create_timer(0.3).timeout
	await _grab(_mid(heavy))

	var shots := arrows.size()
	heavy.enemy_logic.attack_ready_in = 0.0
	for i in 400:
		await physics_frame
		if heavy.enemy_logic.is_attacking and heavy.sprite.frame == 8 and _glint(heavy):
			break
	await _grab(_mid(heavy))
	await _grab(heavy.global_position + Vector2(-10, -10), 3.0)
	for i in 400:
		await physics_frame
		if arrows.size() > shots and absf(arrows[shots].global_position.x - heavy.global_position.x) > 110.0:
			break
	await _grab(_mid(heavy))

	var sheet := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, i * PANEL.y))
	var out := ProjectSettings.globalize_path("res://design/shots/big_archer/camp.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("saved ", out)
	quit()


## Середина між героєм і лучником, трохи вище (обидва цілком у панелі).
func _mid(heavy: Node) -> Vector2:
	return (hero.global_position + heavy.global_position) / 2.0 + Vector2(0, -10)


## Чи вже горить відблиск підказки (EnemyTell) на лучникові.
func _glint(enemy: Node) -> bool:
	for c in enemy.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("EnemyTell.gd"):
			return true
	return false


func _grab(world: Vector2, zoom: float = 1.0) -> void:
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	var mid: Vector2 = root.get_viewport().get_canvas_transform() * world
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(mid) - PANEL / 2 - Vector2i(0, 30), PANEL).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.convert(Image.FORMAT_RGBA8)
	var panel := Image.create(PANEL.x, PANEL.y, false, Image.FORMAT_RGBA8)
	panel.blit_rect(img, rect, Vector2i.ZERO)
	if zoom != 1.0:
		var crop := Vector2i(Vector2(PANEL) / zoom)
		panel = panel.get_region(Rect2i(PANEL / 2 - crop / 2, crop))
		panel.resize(PANEL.x, PANEL.y, Image.INTERPOLATE_NEAREST)
	panels.append(panel)
	Engine.time_scale = 1.0
