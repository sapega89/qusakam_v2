extends SceneTree

## Знімок D560, D652, D653: ряд розмірів (малий і середній бандит, шакал і проклятий шакал з піною — своя сцена й стати) і бій зі щитоносцем — удар спереду в щит
## (іскри), важкий удар розбиває щит (щит відлітає, поза збою), удар без щита. Усе в одному design/shots/enemy_variety/
## shield_fight.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_enemy_variety.gd

const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const SHIELD := "res://SampleProject/Scenes/Characters/Enemies/enemy_shield.tscn"
const JACKAL := "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn"
const JACKAL_CURSED := "res://SampleProject/Scenes/Characters/Enemies/enemy_jackal_cursed.tscn"
const PANEL := Vector2i(1100, 270)

var game: Node
var hero: Node
var eb: Node
var panels: Array[Image] = []


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
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
	await create_timer(0.6).timeout
	var floor_y: float = hero.global_position.y

	# Ряд розмірів: малий і середній бандит, шакал, проклятий шакал з піною (D653)
	var lineup: Array = []
	var variants := [[BANDIT, "melee", "small"], [BANDIT, "melee", "medium"], [JACKAL, "fast", "medium"], [JACKAL_CURSED, "jackal_cursed", "medium"]]
	for i in variants.size():
		lineup.append(_spawn(variants[i][0], variants[i][1], variants[i][2], Vector2(hero.global_position.x + 120.0 + i * 95.0, floor_y)))
	for i in 40: await physics_frame
	for e: Node in lineup:
		e.set_physics_process(false)
		e.enemy_logic.last_direction = -1
		e.enemy_view.update_direction(-1)
		e.anim_player.play(&"idle")
	hero.global_position.x = lineup[0].global_position.x - 120.0
	await create_timer(0.4).timeout
	await _grab((lineup[0].global_position + lineup[3].global_position) / 2.0 + Vector2(-30, 0))
	await create_timer(0.5).timeout
	await _grab(lineup[3].global_position + Vector2(-25, 20), 4.0)
	for e: Node in lineup:
		e.queue_free()

	# Бій зі щитоносцем
	var bearer: Node = _spawn(SHIELD, "shield", "medium", Vector2(hero.global_position.x + 220.0, floor_y))
	for i in 40: await physics_frame
	bearer.set_physics_process(false)
	bearer.poise_max = 99
	bearer.poise = 99
	bearer.enemy_logic.last_direction = -1
	bearer._on_logic_direction_changed(-1)
	bearer.anim_player.play(&"idle")

	var blocked := [false]
	eb.enemy_shield_blocked.connect(func(_e: Node2D, _at: Vector2) -> void: blocked[0] = true)
	await _place_hero(bearer, -80)
	await _tap(&"attack")
	while not blocked[0]:
		await physics_frame
	await create_timer(0.05).timeout
	await _grab(bearer.global_position + Vector2(-40, 0))

	await create_timer(1.2).timeout
	var broken := [false]
	eb.enemy_shield_broken.connect(func(_e: Node2D, _at: Vector2) -> void: broken[0] = true)
	await _place_hero(bearer, -80)
	await _tap(&"heavy_attack")
	while not broken[0]:
		await physics_frame
	await create_timer(0.22).timeout
	await _grab(bearer.global_position + Vector2(-20, 0))

	await create_timer(1.6).timeout
	var hp: int = bearer.current_health
	await _place_hero(bearer, -80)
	await _tap(&"attack")
	while bearer.current_health == hp:
		await physics_frame
	await create_timer(0.03).timeout
	await _grab(bearer.global_position + Vector2(-40, 0))

	var sheet := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, panels[i].get_size()), Vector2i(0, PANEL.y * i))
	var out := ProjectSettings.globalize_path("res://design/shots/enemy_variety/shield_fight.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


## [param kind] — вид з enemy_variety.json.
func _spawn(scene: String, kind: String, size_kind: String, at: Vector2) -> Node:
	var e: Node = load(scene).instantiate()
	e.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	e.size_kind = size_kind
	e.position = game.map.to_local(at - Vector2(0, 40))
	game.map.add_child(e)
	return e


func _place_hero(target: Node, dx: float) -> void:
	hero.global_position = target.global_position + Vector2(dx, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1 if dx < 0 else -1
	await physics_frame


func _tap(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Кадр навколо [param world] (світові px), PANEL завбільшки, у panels; [param zoom] — збільшений центр кадру.
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
