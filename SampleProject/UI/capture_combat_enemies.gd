extends SceneTree

## Знімок D504: три кольори підказки разом — бандит (жовта, парирувати), шакал (біла, блокувати), скорпіон (червона,
## ухилитись). Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_combat_enemies.gd

const SCENES := ["res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn", "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn", "res://SampleProject/Scenes/Characters/Enemies/enemy_tank.tscn"]
const KINDS := ["melee", "fast", "tank"]


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
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
	var hero: Node = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.global_position.x += 700.0
	await create_timer(0.6).timeout
	var floor_y: float = hero.global_position.y
	var enemies: Array = []
	for i in 3:
		var e: Node = load(SCENES[i]).instantiate()
		e.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % KINDS[i])
		e.position = game.map.to_local(Vector2(hero.global_position.x - 260.0 + i * 100.0, floor_y - 40.0))
		game.map.add_child(e)
		enemies.append(e)
	for i in 40: await physics_frame
	hero.global_position.x = enemies[0].global_position.x - 140.0
	await create_timer(0.5).timeout
	for e: Node in enemies:
		e.set_physics_process(false)
		while e.enemy_logic.is_attacking:
			await physics_frame
		e.attack_windup = 0.8
		e.combo_hits = 1
		e.enemy_logic.last_direction = -1
		e.enemy_view.update_direction(-1)
	for e: Node in enemies:
		e.enemy_logic.perform_attack()
	while not enemies[0].enemy_logic.committed:
		await process_frame
	await create_timer(0.12).timeout
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	var mid: Vector2 = root.get_viewport().get_canvas_transform() * ((enemies[0].global_position + enemies[2].global_position) / 2.0)
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(mid) - Vector2i(380, 130), Vector2i(760, 200)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var out := ProjectSettings.globalize_path("res://design/shots/combat_enemies/tells.png")
	img.get_region(rect).save_png(out)
	print("shot ", out, " ", rect)
	Engine.time_scale = 1.0
	quit()
