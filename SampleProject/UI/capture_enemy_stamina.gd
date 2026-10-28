extends SceneTree

## Витривалість ворогів (D824) у справжньому вікні: бандит у бою — шкала стійкості й під нею смужка витривалості на 60 %;
## другий бандит видихнувся — смужка червона, поза збою; смужка боса — HP, стійкість і витривалість на 50 %.
## Одне зображення: design/shots/enemy_stamina.png.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_enemy_stamina.gd

var game: Node


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	root.get_node("SaveSystem").settings_module.settings.hints = false
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue()
	await create_timer(2.5).timeout
	await _finish_dialogue()
	var hero: Node = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	await process_frame
	var fresh := _bandit(hero.global_position + Vector2(160, 0))
	var spent := _bandit(hero.global_position + Vector2(-160, 0))
	var boss: Node = load("res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn").instantiate()
	game.map.add_child(boss)
	boss.global_position = hero.global_position + Vector2(2400, -200)
	boss.set_physics_process(false)
	boss.bar.show()
	for i in 4: await process_frame
	fresh.take_poise(fresh.poise_max * 0.4, hero.global_position.x)
	fresh.stamina.current = fresh.stamina.max_stamina * 0.6
	fresh.stamina.spend(&"swing")  # 60 % − удар
	spent.stamina.current = spent.stamina.cost(&"swing")
	spent.stamina.spend(&"swing")
	spent.stamina.take_winded()
	boss.take_poise(boss.poise_max * 0.3, hero.global_position.x)
	boss.stamina.current = boss.stamina.max_stamina * 0.5 + boss.stamina.cost(&"slam")
	boss.stamina.spend(&"slam")
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var sheet := Image.create(1000, 540, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	var x := 0
	for enemy: Node in [fresh, spent]:
		var at: Vector2 = enemy.get_global_transform_with_canvas().origin
		var plate := img.get_region(Rect2i(Vector2i(at) - Vector2i(170, 330), Vector2i(340, 380)))
		sheet.blit_rect(plate, Rect2i(Vector2i.ZERO, plate.get_size()), Vector2i(x, 0))
		x += 360
	var bar := Rect2i(540, 90, 840, 150)
	sheet.blit_rect(img.get_region(bar), Rect2i(Vector2i.ZERO, bar.size), Vector2i(0, 390))
	var out := ProjectSettings.globalize_path("res://design/shots/enemy_stamina.png")
	sheet.save_png(out)
	print("saved %s; fresh %.0f / %.0f, spent %.0f (exhausted %s), boss %.0f / %.0f" % [out, fresh.stamina.current,
			fresh.stamina.max_stamina, spent.stamina.current, spent.stamina.exhausted, boss.stamina.current, boss.stamina.max_stamina])
	quit()


## Бандит у бою без ШІ: стоїть у стані ATTACK (смужки видно, як у бою).
func _bandit(at: Vector2) -> Node:
	var enemy: Node = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	game.map.add_child(enemy)
	enemy.global_position = at
	enemy.set_physics_process(false)
	enemy.detection_area.monitoring = false
	enemy.enemy_logic.change_state(enemy.enemy_logic.AIState.ATTACK)
	return enemy


func _finish_dialogue() -> void:
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
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
