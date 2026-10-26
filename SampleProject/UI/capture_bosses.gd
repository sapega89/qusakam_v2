extends SceneTree

## Кадри босів (queue row 9.2): кожен бос у спокої, кожен хід з його небезпекою, смужка боса. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_bosses.gd -- <out_dir> [boss…]
## Без імен — усі боси (brass, djinn, lab). Файли: <out_dir>/fb9_2_<boss>_<shot>.png

const BOSSES := {
	"brass": "res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn",
	"djinn": "res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn",
	"lab": "res://SampleProject/Scenes/Characters/Bosses/lab_boss.tscn",
}

var game: Node
var hero: Node
var out_dir := ""
var floor_y := 0.0
var arena_x := 0.0
var only: PackedStringArray = []

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	only = OS.get_cmdline_user_args().slice(1)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(1.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.global_position.x += 700.0
	await create_timer(1.0).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	if only.is_empty() or only.has("brass"):
		await _brass()
	if only.is_empty() or only.has("djinn"):
		await _djinn()
	if only.is_empty() or only.has("lab"):
		await _lab()
	quit()

func _brass() -> void:
	var brass: Node = await _spawn("brass")
	await _move(brass, "combo", -110, "brass_sweep", func() -> void: await _anim(brass, &"attack", 0.68))
	await _move(brass, "charge", -360, "brass_charge", func() -> void: await _anim(brass, &"charge_strike", 0.2))
	await _move(brass, "slam", -200, "brass_slam", func() -> void: await _hazard(0.12))
	await _move(brass, "combo", -110, "brass_tell_sweep", func() -> void: await _tell(brass))
	await _move(brass, "charge", -360, "brass_tell_charge", func() -> void: await _tell(brass))
	await _move(brass, "slam", -200, "brass_tell_slam", func() -> void: await _tell(brass))
	brass.queue_free()
	hero.global_position = Vector2(arena_x, floor_y)
	await create_timer(0.5).timeout

func _djinn() -> void:
	var djinn: Node = await _spawn("djinn")
	await _move(djinn, "combo", -100, "djinn_claws", func() -> void: await _anim(djinn, &"attack", 0.48))
	await _move(djinn, "fireball", -320, "djinn_fireball", func() -> void: await _hazard(0.3))
	await _move(djinn, "pillar", -220, "djinn_pillar_mark", func() -> void: await _hazard(0.25))
	await _move(djinn, "pillar", -220, "djinn_pillar_fire", func() -> void: await _hazard(0.72))
	await _move(djinn, "combo", -100, "djinn_tell_claws", func() -> void: await _tell(djinn))
	await _move(djinn, "fireball", -320, "djinn_tell_fireball", func() -> void: await _tell(djinn))
	await _move(djinn, "pillar", -220, "djinn_tell_pillar", func() -> void: await _tell(djinn))
	djinn.take_damage(djinn.current_health - djinn.Max_Health / 2 + 1)
	await _move(djinn, "pillar", -220, "djinn_phase2_pillars", func() -> void: await _hazard(0.72))
	djinn.queue_free()
	hero.global_position = Vector2(arena_x, floor_y)
	await create_timer(0.5).timeout

## Найманець (D466, D564): булава (дві ланки), палиця з хвилею, ковток; підказки ходів.
func _lab() -> void:
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 1.0  # кпин при ковтку видно на кадрі
	var lab: Node = await _spawn("lab")
	await _move(lab, "combo", -50, "lab_mace", func() -> void: await _anim(lab, &"attack", 0.4))
	await _move(lab, "slam", -150, "lab_club_raise", func() -> void: await _anim(lab, &"slam", 0.5))
	await _move(lab, "slam", -150, "lab_club_slam", func() -> void: await _hazard(0.12))
	await _move(lab, "drink", -120, "lab_drink", func() -> void: await _anim(lab, &"drink", 0.5))
	await _move(lab, "combo", -50, "lab_tell_mace", func() -> void: await _tell(lab))
	await _move(lab, "slam", -150, "lab_tell_club", func() -> void: await _tell(lab))
	lab.queue_free()

func _finish_dialogue(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame

func _spawn(key: String) -> Node:
	var boss: Node = load(BOSSES[key]).instantiate()
	hero.global_position = Vector2(arena_x - 700.0, floor_y)  # за межею виявлення: бос стоїть спокійно
	await create_timer(0.3).timeout
	boss.position = game.map.to_local(Vector2(arena_x + 160.0, floor_y - 40.0))
	game.map.add_child(boss)
	await create_timer(1.0).timeout
	boss.detection_area.set_deferred(&"monitoring", false)  # кадр спокою: героя поруч ще «не бачить»
	await physics_frame
	await physics_frame
	hero.global_position = Vector2(arena_x - 40.0, floor_y)
	await create_timer(0.8).timeout
	await _shot(key + "_idle")
	boss.set_physics_process(false)
	boss.detection_area.monitoring = true
	await create_timer(0.5).timeout
	return boss

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/fb9_2_%s.png" % [out_dir, name])
	print("shot ", name)

func _anim(boss: Node, anim: StringName, after: float) -> void:
	for i in 300:
		if boss.anim_player.current_animation == anim:
			break
		await physics_frame
	await create_timer(after).timeout

## Підказка ходу (4b): відблиск на зброї (і лінія ривка) — кадр, коли він розгорнувся. Підказка живе 0.25 с,
## а повільний кадр без GPU проскакує її цілком — тож час сповільнюємо й зупиняємо до знімка (_move вертає 1).
func _tell(boss: Node) -> void:
	Engine.time_scale = 0.1
	for i in 3000:
		if boss.get_children().any(func(n: Node) -> bool: return n.get_script() == preload("res://SampleProject/Scripts/FX/EnemyTell.gd")):
			break
		await process_frame
	await create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 0.0

func _hazard(after: float) -> void:
	for i in 300:
		if game.map.get_children().any(func(n: Node) -> bool: return n.scene_file_path.contains("/FX/Bosses/")):
			break
		await physics_frame
	await create_timer(after).timeout

## Бос робить лише [param kind]; кадр — коли [param moment] дочекався своєї миті.
func _move(boss: Node, kind: String, dx: float, name: String, moment: Callable) -> void:
	var all: Array[Dictionary] = boss.moves
	boss.moves = all.filter(func(m: Dictionary) -> bool: return m.kind == kind)
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position = Vector2(boss.global_position.x + dx, floor_y)
	hero.velocity = Vector2.ZERO
	boss.enemy_logic.attack_ready_in = 0.0
	hero.set_physics_process(false)  # удар не відкидає героя з дальності ходу, поки знімаємо
	boss.set_physics_process(true)
	await moment.call()
	await _shot(name)
	Engine.time_scale = 1.0
	for i in 400:
		if not boss.enemy_logic.is_attacking:
			break
		await physics_frame
	boss.set_physics_process(false)
	hero.set_physics_process(true)
	boss.moves = all
	await create_timer(1.2).timeout
