extends SceneTree

## Правки арту fe96e88a (remaining_work Art 3–4) у грі: Малік, алхімік, жриця, дід, кадр смерті джина, дальній шар
## зали боса, ворог у збої (D264) і важкий удар кинджала. Кожен кадр — виріз навколо героя/NPC під камерою гри;
## Scripts/Tools/art_fixes_sheet.py складає їх в один design/shots/art_fixes_all.png. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_art_fixes.gd -- <out_dir>
## Файли: <out_dir>/<кадр>.png

const CROP := Vector2i(480, 400)
const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()

	# [кімната, мітка входу, вузол NPC, кадр, поза з правкою або "" — та, що грає]
	for spot: Array in [
		["LabCells", ^"Arrival", ^"Malik", "malik", ""],
		["LabCells", ^"Arrival", ^"Scientist", "alchemist", ""],
		["City", ^"OathPriest", ^"OathPriest", "priestess", "work"],
		["Village", ^"Arrival", ^"OldManQuest", "grandfather", "idle"],
	]:
		await _room(spot[0], spot[1])
		var npc: Node2D = game.map.get_node(spot[2])
		game.player.global_position.x = npc.global_position.x - 140.0
		for i in 60: await physics_frame
		await _drain()
		await create_timer(0.4).timeout
		game.player.global_position.x = npc.global_position.x - 140.0  # NPC ходять — герой знову поруч
		if spot[4] != "":
			var npc_anim: AnimationPlayer = npc.get_node(^"AnimationPlayer")
			npc_anim.play(StringName(spot[4]))
			npc_anim.advance(0.0)
		for i in 6: await physics_frame
		await _shot(npc, spot[3], Vector2(0, -150))

	# Зала джина: дальній шар (руни) — увесь екран; джин — кадр смерті 12 (death 0).
	await _room("LabBoss", ^"Arrival")
	game.player.global_position.x = 400.0
	for i in 60: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/boss_far.png" % out_dir)
	var djinn: Node2D = game.map.get_node(^"FireDjinn")
	djinn.set_physics_process(false)
	game.player.global_position.x = djinn.global_position.x - 260.0
	for i in 30: await physics_frame
	var djinn_anim: AnimationPlayer = djinn.get_node(^"AnimationPlayer")
	djinn_anim.play(&"death")
	djinn_anim.seek(0.1, true)
	djinn_anim.pause()
	await _shot(djinn, "djinn_death0", Vector2(0, -110))

	# Кинджал: важкий удар по бандиту — замах (Heavy/1), удар (Heavy/2), бандит у збої (poise 3 — збитий одразу).
	await _room("DesertRoad", ^"Arrival_Start")
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	game.player.global_position.x += 700.0
	for i in 30: await physics_frame
	var em: Node = sl.get_equipment_manager()
	var who: String = sl.get_game_manager().get_active_character().character_id
	for slot in ["sword", "dagger", "mace", "polearm", "shield"]:
		em.unequip_item(who, slot)
	em.equip_item(who, "dagger", "iron_dagger", sl.get_item_database().get_item("iron_dagger"))
	await process_frame  # D475 / D510: екіпірування одразу бере зброю в руку
	game.player.is_invulnerable = true  # замах бандита не перебиває важкий удар позою Hurt
	var bandit: CharacterBody2D = load(BANDIT).instantiate()
	bandit.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	game.map.add_child(bandit)
	bandit.global_position = game.player.global_position + Vector2(70, -20)
	bandit.Max_Health = 999999
	bandit.current_health = bandit.Max_Health
	for i in 40: await physics_frame
	await _drain()
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies") and node != bandit:
			node.queue_free()  # хвиля спавнера секції — у кадрі лише наш бандит
	# Бандит стоїть перед героєм (інакше пробігає крізь нього, D197) — до удару без AI, далі живий: збій, тінь
	bandit.set_physics_process(false)
	bandit.global_position.x = game.player.global_position.x + 60.0
	await physics_frame
	# Те, що робить кнопка heavy_attack (Player._input); подія Input під xvfb доходила не щоразу
	game.player.combat.heavy_attack(1)
	var hero_anim: AnimationPlayer = game.player.get_node(^"AnimationPlayer")
	var bandit_anim: AnimationPlayer = bandit.get_node(^"AnimationPlayer")
	var bandit_sprite: Sprite2D = bandit.get_node(^"Sprite2D")
	await _until(func() -> bool: return hero_anim.current_animation == &"dagger/HeavyWindup")
	await create_timer(0.15).timeout
	await _shot(game.player, "dagger_heavy1", Vector2(30, -40))
	await _until(func() -> bool: return hero_anim.current_animation == &"dagger/HeavyStrike")
	await _shot(game.player, "dagger_heavy2", Vector2(30, -40))
	bandit.set_physics_process(true)
	await _until(func() -> bool: return bandit_anim.current_animation == &"stagger")
	bandit_anim.pause()  # кадр 0 триває 0.18 с — під xvfb знімок інакше встигав лише кадр 1
	await _shot(bandit, "bandit_stagger0", Vector2(0, -40))
	bandit_anim.play()
	await _until(func() -> bool: return bandit_sprite.frame == 1)
	await _shot(bandit, "bandit_stagger1", Vector2(0, -40))
	quit()

## Чекає умову до 3 с (кадри під xvfb ідуть нерівно — фіксовані паузи промахувалися повз позу).
func _until(ok: Callable) -> void:
	for i in 180:
		if ok.call():
			return
		await physics_frame
	print("timed out waiting for a pose")

func _room(room: String, mark: NodePath) -> void:
	if not game.map.scene_file_path.ends_with(room + ".tscn"):
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % room, mark)
		for i in 30: await physics_frame
		await _drain()

## Виріз CROP навколо [param node] (+[param shift] px екрана) з кадру гри.
func _shot(node: Node2D, name: String, shift: Vector2) -> void:
	var cam: Camera2D = game.player.get_node(^"Camera2D")
	# Пролог нової гри (Cutscene) лишає камеру top_level на старті — тут вона знову за героєм, одразу на ньому
	cam.top_level = false
	cam.position = Vector2.ZERO
	cam.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	# Від того, що камера справді показує (межі кімнати), а не від її цілі
	var at := (node.global_position - cam.get_screen_center_position()) * cam.zoom + Vector2(root.size) / 2.0 + shift
	var image := root.get_texture().get_image()
	var corner := Vector2i(at) - CROP / 2
	corner = corner.clamp(Vector2i.ZERO, image.get_size() - CROP)
	image.get_region(Rect2i(corner, CROP)).save_png("%s/%s.png" % [out_dir, name])
	print("shot %s at %s, camera %s (%s)" % [name, corner, cam.get_screen_center_position(), node.get_node(^"AnimationPlayer").current_animation if node.has_node(^"AnimationPlayer") else ""])

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
