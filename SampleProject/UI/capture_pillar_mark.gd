extends SceneTree

## Мітка стовпа вогню на підлозі зали боса лабораторії (H4, D302/D316): один стовп під героєм (як у грі), другий —
## обабіч на 140 px (друга фаза). Кадри — яскрава й тьмяна фаза пульсу анімації mark і вогонь на піку. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_pillar_mark.gd -- <out_dir>
## Файли: <out_dir>/pillar_mark_bright.png, pillar_mark_dim.png, pillar_mark_fire.png; друкує екранні x,y міток (для вирізок).

const PILLAR := preload("res://SampleProject/Scenes/FX/Bosses/boss_pillar.tscn")
## Ступні героя на 24 px нижче його центру, ступні джина — на 16 (стовп стоїть у y боса, BossLogic._pillars).
const FEET_DY := 24.0 - 16.0
const SIDE := 140.0

func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(dm)
	# зала після бою: найманця нема, кат-сцен нема — лише підлога
	game.set_quest_flag("lab_boss_fight_complete", true)
	game.set_quest_flag("lab_after_boss_complete", true)
	await game.teleport_to_room("res://SampleProject/Maps/LabBoss.tscn", ^"Arrival")
	for i in 30: await physics_frame
	var hero: Node2D = game.player
	hero.global_position = Vector2(500.0, 360.0)
	for i in 60: await physics_frame
	await _drain(dm)
	await create_timer(0.5).timeout
	var y := hero.global_position.y + FEET_DY
	var pillars: Array[Node2D] = []
	for x in [hero.global_position.x, hero.global_position.x + SIDE]:
		var pillar: Node2D = PILLAR.instantiate()
		game.map.add_child(pillar)
		pillar.global_position = Vector2(x, y)
		pillars.append(pillar)
	await process_frame
	Engine.time_scale = 0.0  # мітка лишається, таймер стовпа стоїть
	for shot: Array in [["bright", 0.05], ["dim", 0.2]]:
		for p in pillars:
			(p.get_node("AnimationPlayer") as AnimationPlayer).seek(shot[1], true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/pillar_mark_%s.png" % [out_dir, shot[0]])
	for p in pillars:  # вогонь на піку — чи стовп росте з мітки
		var anim: AnimationPlayer = p.get_node("AnimationPlayer")
		anim.play(&"fire")
		anim.seek(0.2, true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/pillar_mark_fire.png" % out_dir)
	for p in pillars:
		var at: Vector2 = p.get_global_transform_with_canvas().origin
		print("MARK at %d,%d" % [roundi(at.x), roundi(at.y)])
	quit()

func _drain(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
