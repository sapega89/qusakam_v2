extends SceneTree

## Знімок D692 / D693: звичайні шакали — шакали зграї в стилі ватажка — у своєму першому бою (DesertRoad Fight_Dunes):
## герой стає в зону бою, шакали біжать на нього (кадр 1), один стрибає з укусом (кадр 2). Два кадри в одному
## design/shots/jackal_pack/pack_dunes.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_jackal_pack.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const PANEL := Vector2i(900, 360)

var game: Node
var hero: Node
var panels: Array[Image] = []


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	await create_timer(0.5).timeout
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	await create_timer(0.6).timeout
	var fight: Node = game.map.get_node(^"Fight_Dunes")
	# Вхід у зону бою (тригер на x 2170) — герой стає в неї, бій стартує сам.
	hero.global_position = Vector2(2200, 340)
	hero.velocity = Vector2.ZERO
	hero.set_invulnerable(true, 30.0)
	await _until(func() -> bool: return not _jackals(fight).is_empty())
	var jackals: Array = _jackals(fight)
	for j: Node in jackals:
		print("spawned %s %s size %s HP %d" % [j.name, j.enemy_stats.enemy_type, j.size_kind, j.Max_Health])
	var first: Node = jackals[0]
	var centre := func() -> Vector2: return (hero.global_position + first.global_position) / 2.0 + Vector2(0, -10)
	await _until(func() -> bool: return first.anim_player.current_animation == &"walk")
	await create_timer(0.15).timeout  # камера доїжджає за героєм, шакал біжить
	await _grab(centre.call())
	await _until(func() -> bool: return jackals.any(_biting))
	await _grab(centre.call())

	var sheet := Image.create(PANEL.x, PANEL.y * 2, false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, PANEL), Vector2i(0, PANEL.y * i))
	var out := ProjectSettings.globalize_path("res://design/shots/jackal_pack/pack_dunes.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


## Шакал у стрибку з укусом (attack після кадру присідання).
func _biting(j: Node) -> bool:
	return is_instance_valid(j) and j.anim_player.current_animation == &"attack" and j.anim_player.current_animation_position > 0.2


## Шакали бою [param fight] (вид fast).
func _jackals(fight: Node) -> Array:
	return fight.find_children("*", "CharacterBody2D", false, false).filter(func(e: Node) -> bool: return e.enemy_stats.enemy_type == "fast")


func _until(done: Callable) -> void:
	for i in 900:
		if done.call():
			return
		await physics_frame
	push_error("capture_jackal_pack: timed out")


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
