extends SceneTree

## Невикористаний арт, підключений (wire-art): магічний і скляний (тріснутий) щит над позою Block, значки стану над
## ворогом (підпал + оглушення) і в панелі героя (оглушення), миша з норою в GatehouseCellar. Аркуш 3×2 клітинки по
## 600×560 px екрана. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_wire_art.gd -- design/shots/wire_art.png

const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const BANDIT_STATS := "res://SampleProject/Resources/Enemies/enemy_stats_melee.tres"
const CROP := Vector2i(600, 560)

var game: Node
var dm: Node


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	var sheet := Image.create(CROP.x * 3, CROP.y * 2, false, Image.FORMAT_RGBA8)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 60: await physics_frame
	await _drain()
	var hero: Node2D = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	var bandit: Node2D = load(BANDIT).instantiate()
	bandit.enemy_stats = load(BANDIT_STATS)
	bandit.position = game.map.to_local(hero.global_position + Vector2(140.0, -40.0))
	game.map.add_child(bandit)
	for i in 40: await physics_frame
	bandit.set_physics_process(false)
	bandit.Max_Health = 99999
	bandit.current_health = bandit.Max_Health
	hero.mover.last_direction = 1
	# 1: магічний щит тримається над Block
	hero.combat.block_held = true
	await create_timer(0.6).timeout
	await _shot(sheet, Vector2i(0, 0), hero.global_position + Vector2(0, -40), "magic shield, hold")
	# 2: скляний, дві тріщини
	hero.shield_spell.raise(&"glass")
	await create_timer(0.4).timeout
	for i in 2:
		hero.stamina.refill()
		hero.take_damage(10, bandit)
	await create_timer(0.1).timeout
	await _shot(sheet, Vector2i(1, 0), hero.global_position + Vector2(0, -40), "glass shield, crack_2")
	# 3: скляний розлітається уламками
	hero.stamina.refill()
	hero.take_damage(10, bandit)
	await create_timer(0.09).timeout
	await _shot(sheet, Vector2i(2, 0), hero.global_position + Vector2(0, -40), "glass shield, shatter")
	hero.combat.block_held = false
	# 4: ворог горить і оглушений; 5: оглушення в панелі героя
	bandit.apply_burn(1, 30.0)
	bandit.enemy_logic.stun_left = 30.0
	bandit.take_poise(3.0, hero.global_position.x)
	root.get_node("EventBus").player_staggered.emit(30.0)
	await create_timer(0.3).timeout
	await _shot(sheet, Vector2i(0, 1), bandit.global_position + Vector2(0, -60), "enemy: burning + stunned")
	await _shot(sheet, Vector2i(1, 1), Vector2.INF, "hero panel: stunned")
	# 6: миша в підвалі
	await game.teleport_to_room("res://SampleProject/Maps/GatehouseCellar.tscn", ^"Arrival")
	for i in 60: await physics_frame
	await _drain()
	var mouse: Node2D = game.map.get_node(^"Mouse1")
	game.player.global_position.x = mouse.global_position.x - 420.0
	await create_timer(1.0).timeout
	await _shot(sheet, Vector2i(2, 1), mouse.global_position + Vector2(48, -40), "mouse by its hole")
	sheet.save_png(out)
	print("saved ", out)
	quit()


## Клітинка навколо точки світу [param at] (Vector2.INF — лівий верхній кут екрана, панель героя).
func _shot(sheet: Image, cell: Vector2i, at: Vector2, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var corner := Vector2i.ZERO
	if at != Vector2.INF:
		var centre: Vector2 = root.get_final_transform() * (game.get_viewport().get_canvas_transform() * at)
		corner = (Vector2i(centre) - CROP / 2).clamp(Vector2i.ZERO, image.get_size() - CROP)
	var crop := image.get_region(Rect2i(corner, CROP))
	crop.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), cell * CROP)
	print(label)


func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
