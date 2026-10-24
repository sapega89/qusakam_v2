extends SceneTree

## Чібі-кадри Маліка, алхіміка й охоронця (D677) і Алісія на операційному столі (B127) — у справжньому вікні LabCells:
##   inject — алхімік колє (кадр inject), situp — репліка Lab_Cells_Injection, malik — герой біля Маліка після сцени,
##   guard — охоронець-компаньйон (вхід і удар списом) поруч із героєм.
## Тег — після «--»: before зберігає кадри, after склеює before над after в одну картинку на кадр:
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_chibi_npcs.gd -- before
## Файли: design/shots/chibi_npcs/<тег>_<кадр>.png, after — ще й ba_<кадр>.png (before зверху).

const OUT := "res://design/shots/chibi_npcs"
const CELLS := "res://SampleProject/Maps/LabCells.tscn"
const GUARD := "res://SampleProject/Scenes/Characters/Companions/companion_guard.tscn"
## Світова область кадру навколо точки (px світу).
const CROP_WORLD := Vector2(640, 300)

var game: Node
var dm: Node
var tag := ""
var shots: Array[String] = []


func _initialize() -> void:
	tag = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	await game.teleport_to_room(CELLS, ^"Arrival")
	var cells: Node2D = game.map
	var anim: AnimationPlayer = cells.get_node(^"Scientist/AnimationPlayer")
	var table: Vector2 = (cells.get_node(^"Marks/Table") as Node2D).global_position
	var inject_done := false
	var situp_done := false
	var talks: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: talks.append(id.get_file().get_basename()))
	var deadline := Time.get_ticks_msec() + 60000
	while cells.get_current_state_name() != "AWAKE" and Time.get_ticks_msec() < deadline:
		if not inject_done and anim.current_animation == "inject":
			inject_done = true
			await create_timer(0.2).timeout
			await _shot("inject", table + Vector2(0, -80))
		if dm.is_dialogue_active() and not dm.is_bubble_playing():
			if not situp_done and talks.has("Lab_Cells_Injection"):
				situp_done = true
				await create_timer(0.3).timeout
				await _shot("situp", table + Vector2(0, -80))
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
	for i in 60: await physics_frame
	await _drain()
	var malik: Node2D = cells.get_node(^"Malik")
	game.player.global_position = malik.global_position + Vector2(-90, -24)
	for i in 60: await physics_frame
	await create_timer(0.5).timeout
	await _shot("malik", malik.global_position + Vector2(-40, -70))

	# Охоронець — лише його спрайт із companion_guard.tscn (без логіки асиста), вхід і удар (strike_frame)
	var hero_pos: Vector2 = game.player.global_position
	var assist: Node2D = (load(GUARD) as PackedScene).instantiate()
	for i in 2:
		var sprite: AnimatedSprite2D = assist.get_node(^"Sprite").duplicate()
		sprite.position = hero_pos + Vector2(110 + 130 * i, 24)
		sprite.animation = &"enter" if i == 0 else &"strike"
		sprite.frame = 0 if i == 0 else int(assist.get(&"strike_frame"))
		cells.add_child(sprite)
	assist.free()
	for i in 10: await process_frame
	await _shot("guard", hero_pos + Vector2(130, -50))
	if tag == "after":
		for name in shots:
			_combine(name)
	quit()


func _shot(name: String, world_center: Vector2) -> void:
	await process_frame
	var xform: Transform2D = root.get_canvas_transform()
	var a: Vector2 = xform * (world_center - CROP_WORLD / 2.0)
	var b: Vector2 = xform * (world_center + CROP_WORLD / 2.0)
	var img := root.get_texture().get_image()
	var rect := Rect2i(Rect2(a, b - a)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png("%s/%s_%s.png" % [OUT, tag, name])
	shots.append(name)


## before зверху, after знизу.
func _combine(name: String) -> void:
	var before := Image.load_from_file("%s/before_%s.png" % [OUT, name])
	var after := Image.load_from_file("%s/after_%s.png" % [OUT, name])
	before.convert(Image.FORMAT_RGBA8)
	after.convert(Image.FORMAT_RGBA8)
	var out := Image.create(maxi(before.get_width(), after.get_width()), before.get_height() + after.get_height() + 4, false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	out.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), Vector2i.ZERO)
	out.blit_rect(after, Rect2i(Vector2i.ZERO, after.get_size()), Vector2i(0, before.get_height() + 4))
	out.save_png("%s/ba_%s.png" % [OUT, name])


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
