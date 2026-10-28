extends SceneTree

## Тінь героя, як у MK1 (hero-shadow): стоїть — на підлозі під ногами; у стрибку — на тій самій підлозі,
## менша й блідіша; на драбині й без підлоги в межах досяжності — немає; підскок на камінь (D764) її не рухає;
## після переходу в іншу кімнату — жодного кадру зі старим зсувом.
##   godot --headless --path . --script res://SampleProject/UI/verify_hero_shadow.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(dm)
	var p: CharacterBody2D = game.player
	var shadow: Node2D = p.get_node(^"Shadow")

	print("[0] Node: behind the hero's drawing, in front of the floor")
	ck(shadow.get_index() < p.get_node(^"Sprite2D").get_index() and shadow.z_index == 0 and shadow.z_as_relative,
		"Shadow is drawn before Sprite2D at the hero's own z")
	ck(shadow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest filtering")

	for room: Array in [["DesertRoad", ^"Arrival_Start"], ["LabBoss", ^"Arrival"]]:
		# у повітрі перед переходом: зсув тіні тоді не 24, і жоден кадр після переходу не може його показати
		Input.action_press(&"jump")
		for i in 12: await physics_frame
		Input.action_release(&"jump")
		var air_offset := shadow.position.y
		var air_at := p.global_position
		var stale := [0]
		var watch := func() -> void:
			if shadow.visible and absf(shadow.position.y - air_offset) < 0.01 and p.global_position.distance_to(air_at) > 64.0:
				stale[0] += 1
		process_frame.connect(watch)
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % room[0], room[1])
		for i in 5: await process_frame
		process_frame.disconnect(watch)
		ck(absf(air_offset - 24.0) > 20.0 and stale[0] == 0,
			"%s: entered mid-jump (offset %.0f), no frame shows the old offset (%d)" % [room[0], air_offset, stale[0]])
		for i in 40: await physics_frame
		await _drain(dm)
		for i in 10: await physics_frame
		var feet := p.global_position.y + 24.0
		print("[1] %s standing at %s" % [room[0], p.global_position])
		ck(p.is_on_floor() and shadow.visible, "%s: standing, the shadow is drawn" % room[0])
		ck(absf(shadow.global_position.y - feet) < 0.5 and absf(shadow.global_position.x - p.global_position.x) < 0.5,
			"%s: under the feet (shadow %s, feet y %.1f)" % [room[0], shadow.global_position, feet])
		ck(is_equal_approx(shadow.scale.x, 1.5) and is_equal_approx(shadow.modulate.a, shadow.ground_alpha),
			"%s: full size ×1.5, alpha %.2f (%.2f, %.2f)" % [room[0], shadow.ground_alpha, shadow.scale.x, shadow.modulate.a])

		print("[2] %s mid-jump" % room[0])
		Input.action_press(&"jump")
		var top := 0.0
		var top_scale := 1.5
		var top_alpha: float = shadow.ground_alpha
		var on_floor_y := true
		for i in 60:
			await physics_frame
			if p.is_on_floor():
				continue
			on_floor_y = on_floor_y and shadow.visible and absf(shadow.global_position.y - feet) < 1.0
			var h := feet - (p.global_position.y + 24.0)
			if h > top:
				top = h
				top_scale = shadow.scale.x
				top_alpha = shadow.modulate.a
		Input.action_release(&"jump")
		ck(top > 60.0, "%s: the hero jumped (%.0f px)" % [room[0], top])
		ck(on_floor_y, "%s: in the air the shadow stays on the floor y %.1f" % [room[0], feet])
		ck(top_scale < 1.0 and top_scale > 0.6, "%s: smaller at the top (scale %.2f of 1.5)" % [room[0], top_scale])
		ck(top_alpha < shadow.top_alpha + 0.05 and top_alpha > shadow.top_alpha - 0.001, "%s: fainter at the top (alpha %.2f, ground %.2f)" % [room[0], top_alpha, shadow.ground_alpha])
		for i in 60: await physics_frame
		if room[0] != "DesertRoad":
			continue
		# дорога під відкритим небом: 300 px над нею (ще в кімнаті) підлоги в межах досяжності немає — як над прірвою
		print("[3] %s over a pit: no floor within reach" % room[0])
		p.global_position -= Vector2(0.0, 300.0)
		p.velocity = Vector2.ZERO
		await physics_frame
		await physics_frame
		ck(not p.is_on_floor() and is_nan(shadow.height) and not shadow.visible, "300 px above the floor, the shadow is not drawn")
		var seen_at := NAN
		for i in 180:
			await physics_frame
			if shadow.visible and is_nan(seen_at):
				seen_at = feet - (p.global_position.y + 24.0)
			if p.is_on_floor():
				break
		ck(seen_at <= shadow.reach and seen_at > shadow.reach - 30.0, "falling, it appears once the floor is within reach (%.0f px)" % seen_at)
		ck(p.is_on_floor() and shadow.visible, "landed: the shadow is back")

	print("[4] Meditation hop (D764): only the drawing hops")
	var at := shadow.global_position
	p.set_visual_offset(Vector2(0.0, -16.0))
	for i in 3: await physics_frame
	ck(shadow.visible and shadow.global_position.is_equal_approx(at), "the shadow stays on the floor (%s)" % shadow.global_position)
	p.set_visual_offset(Vector2.ZERO)

	print("[5] Ladder: hidden while climbing (the road's shop ladder — the Laboratory has none since v3, D863)")
	game.set_quest_flag("desert_road_fight_complete", true)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 20: await physics_frame
	await _drain(dm)
	var ladder: Node2D = game.map.get_node(^"Ladder_Shop")
	p.global_position = Vector2(ladder.global_position.x, ladder.global_position.y + ladder.height - 30)
	for i in 30: await physics_frame
	ck(p.is_on_floor() and shadow.visible, "at the foot of the ladder, the shadow is drawn")
	Input.action_press(&"move_up")
	for i in 30: await physics_frame
	ck(p.mover.is_climbing() and not shadow.visible, "on the ladder, the shadow is hidden")
	Input.action_release(&"move_up")

	print("RESULT: ALL PASS" if fails.is_empty() else "RESULT: %d FAIL" % fails.size())
	quit()
