extends SceneTree

## Витривалість і стійкість (D776, D777) у справжньому вікні: панель героя з рядком ST під SP (шкала на 40 %),
## звичайний ворог з шкалою стійкості над головою (набрана частково) і смужка боса з шкалою стійкості під HP.
## Одне зображення: design/shots/stamina_poise.png.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_stamina_poise.gd

var game: Node


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
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
	var enemies: Array = []
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
			node.set_physics_process(false)
			node.detection_area.monitoring = false
	var target: Node = enemies[0]
	for e in enemies.slice(1):
		e.global_position.x = target.global_position.x + 1400  # не в кадрі
	target.global_position = hero.global_position + Vector2(160, 0)
	target.take_poise(target.poise_max * 0.55, hero.global_position.x)
	var boss: Node = load("res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn").instantiate()
	game.map.add_child(boss)
	boss.global_position = hero.global_position + Vector2(2400, -200)
	boss.set_physics_process(false)
	boss.bar.show()
	boss.take_poise(boss.poise_max * 0.4, hero.global_position.x)
	hero.stamina.spend(60.0)
	hero.stamina.set_physics_process(false)  # шкала стоїть на 40 %, не відновлюється до знімка
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var at: Vector2 = target.get_global_transform_with_canvas().origin
	var panel := Rect2i(0, 0, 600, 270)
	var plate := Rect2i(Vector2i(at) - Vector2i(150, 200), Vector2i(300, 270))
	var bar := Rect2i(540, 90, 840, 130)
	var sheet := Image.create(1440, 400, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	sheet.blit_rect(img.get_region(panel), Rect2i(Vector2i.ZERO, panel.size), Vector2i(0, 0))
	sheet.blit_rect(img.get_region(plate), Rect2i(Vector2i.ZERO, plate.size), Vector2i(620, 0))
	sheet.blit_rect(img.get_region(bar), Rect2i(Vector2i.ZERO, bar.size), Vector2i(0, 270))
	var out := ProjectSettings.globalize_path("res://design/shots/stamina_poise.png")
	sheet.save_png(out)
	print("saved %s; ST %.0f, enemy poise %.1f / %d, boss poise %.1f / %d" % [out, hero.stamina.current,
			target.poise_max - target.poise, target.poise_max, boss.poise_max - boss.poise, boss.poise_max])
	quit()


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
