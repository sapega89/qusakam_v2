extends SceneTree

## Плавність героя (BACKLOG feedback 20, D262): стрибок іде Jump → Apex → Fall → Land → Idle,
## пил приземлення — кілька дрібних клаптів і зникає за ~0.3 с.
##   godot --headless --path . --script res://SampleProject/UI/verify_hero_motion.gd
## У вікні з `-- --shots=<dir>` ще й знімає героя в стрибку й пил (fb20_*.png):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/verify_hero_motion.gd -- --shots=<dir>

var fails: Array[String] = []
var shots_dir := ""
var game: Node
var dust_born: Array[int] = []
var dust_gone: Array[int] = []
var dust_particles := 0

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var at: Vector2 = game.player.get_global_transform_with_canvas().origin
	var img: Image = root.get_texture().get_image()
	img.get_region(Rect2i(Vector2i(at) - Vector2i(160, 120), Vector2i(320, 220))).save_png(shots_dir.path_join("fb20_%s.png" % name))


func _on_node_added(node: Node) -> void:
	if node.name == &"LandingDust":
		dust_born.append(Time.get_ticks_msec())
		dust_particles += node.amount + node.get_node(^"Left").amount
		node.tree_exiting.connect(func() -> void: dust_gone.append(Time.get_ticks_msec()))


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	# D737: розмова сюжету тримає героя, і монолог облачком теж. Вступ Каньйону — два монологи з паузою ~0,1 с між ними,
	# тож чекаємо, доки сюжет мовчить пів секунди поспіль; облачка — прискорені.
	dm.bubble_time_scale = 0.05
	var quiet := 0
	var deadline := Time.get_ticks_msec() + 60000
	while quiet < 30 and Time.get_ticks_msec() < deadline:
		quiet = 0 if dm.is_story_busy() else quiet + 1
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
		await physics_frame
	dm.bubble_time_scale = 1.0
	var pl: Node = game.player
	var anim: AnimationPlayer = pl.get_node("AnimationPlayer")
	for i in 30: await physics_frame
	ck(pl.is_on_floor(), "the hero stands on the floor before the jump")
	node_added.connect(_on_node_added)

	print("[1] A full jump plays every transition frame in order")
	var seen: Array[String] = []
	Input.action_press(&"jump")
	var shot_at := {}
	for i in 180:
		await physics_frame
		var cur: String = anim.current_animation
		if seen.is_empty() or seen[-1] != cur:
			seen.append(cur)
			if cur in ["Jump", "Apex", "Fall"] and not shot_at.has(cur):
				shot_at[cur] = true
				for k in 3 if cur == "Jump" else 1: await process_frame
				await _shot(cur.to_lower())
			if cur == "Land":
				# приземлення й пил: одразу, через 0.1 і 0.2 с
				await _shot("land")
				await create_timer(0.1).timeout
				await _shot("dust_1")
				await create_timer(0.1).timeout
				await _shot("dust_2")
		if seen[-1] == "Idle" and seen.size() > 1:
			break
	Input.action_release(&"jump")
	var order := ["Jump", "Apex", "Fall", "Land", "Idle"]
	var at := 0
	for name in seen:
		if at < order.size() and name == order[at]:
			at += 1
	ck(at == order.size(), "Jump → Apex → Fall → Land → Idle (saw %s)" % [seen])
	ck(anim.get_animation(&"Idle").track_get_key_count(0) >= 4, "Idle breathes over 4 keys (%d)" % anim.get_animation(&"Idle").track_get_key_count(0))

	print("[2] Landing dust is short and sparse (Ender Lilies)")
	await create_timer(0.5).timeout
	ck(dust_born.size() == 1, "one dust puff per landing (%d)" % dust_born.size())
	ck(dust_particles <= 6, "at most 6 particles (%d)" % dust_particles)
	ck(dust_gone.size() == dust_born.size() and dust_born.size() > 0 and dust_gone[0] - dust_born[0] <= 450,
			"the dust is gone within ~0.35 s (%s ms)" % [(dust_gone[0] - dust_born[0]) if dust_gone.size() > 0 and dust_born.size() > 0 else -1])
	await _shot("after")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0)
