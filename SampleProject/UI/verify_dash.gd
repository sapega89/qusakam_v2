extends SceneTree

## Ривок (D200, D264) і уступ (Sapega 2026-10-24): ривок із землі, що зійшов зі сходинки, падає на нижню платформу
## ще до кінця ривку; ривок, початий у повітрі, — рівний; ривок по рівній підлозі — тієї самої довжини.
## Справжня фізика DesertRoad, дії — через Input.parse_input_event.
##   godot --headless --path . --script res://SampleProject/UI/verify_dash.gd

const STEP := 16.0  # висота сходинки, px
const FEET := 24.0  # від центру героя до низу його тіла (CollisionShape2D 24×40, зсув 4)

var fails: Array[String] = []
var hero: Node
var mover: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
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

func _tap(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)

## Поставити героя в [param at] обличчям праворуч, з повними ривками, і дочекатись, поки стане на підлогу.
func _stand(at: Vector2) -> void:
	hero.global_position = at
	hero.velocity = Vector2.ZERO
	mover.last_direction = 1
	mover.dash_charges = mover.dash_charges_max
	mover.roll_ready_in = 0.0
	for i in 30: await physics_frame

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	hero = game.player
	mover = hero.mover
	# Ні ворогів, ні боїв секцій — лише рух героя
	var spawner_script: Script = load("res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd")
	for node in game.map.get_children():
		if node.get_script() == spawner_script and node.trigger_area:
			node.trigger_area.monitoring = false
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	await _stand(hero.global_position)
	ck(hero.is_on_floor(), "the hero stands on DesertRoad's floor")
	var start: Vector2 = hero.global_position
	var floor_y: float = start.y + FEET

	print("[c] A ground dash on flat floor: the same distance, the same height")
	await _tap(&"dodge")
	ck(mover.is_rolling() and not mover.air_dash, "a ground dash started")
	while mover.is_rolling():
		await physics_frame
	var expected: float = mover.roll_distance * mover.roll_length / mover.roll_duration
	var dx: float = hero.global_position.x - start.x
	ck(absf(dx - expected) < 12.0, "dash distance %.0f px (roll_distance × roll_length / roll_duration = %.0f)" % [dx, expected])
	ck(absf(hero.global_position.y - start.y) < 1.0 and hero.is_on_floor(),
			"stays on the floor (dy %.1f)" % (hero.global_position.y - start.y))

	print("[a] A ground dash off a %d px step falls under gravity and lands before the dash ends" % int(STEP))
	var step := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(200, STEP)
	step.add_child(shape)
	game.map.add_child(step)
	step.global_position = Vector2(start.x - 100.0, floor_y - STEP / 2.0)  # правий край — у start.x
	await _stand(Vector2(start.x - 14.0, floor_y - STEP - FEET - 2.0))
	var top_y: float = hero.global_position.y
	ck(hero.is_on_floor() and absf(top_y - (floor_y - STEP - FEET)) < 1.5, "the hero stands on the step (y %.1f)" % top_y)
	await _tap(&"dodge")
	ck(mover.is_rolling() and not mover.air_dash, "a ground dash started on the step")
	var left_floor := false
	var falling_ok := true
	var landed_rolling := false
	var prev_y: float = hero.global_position.y
	var vx_ok := true
	for i in 60:
		await physics_frame
		var y: float = hero.global_position.y
		if mover.is_rolling() and absf(hero.velocity.x - mover.roll_distance / mover.roll_duration) > 0.5:
			vx_ok = false
		if not hero.is_on_floor():
			left_floor = true
			if y <= prev_y:
				falling_ok = false
		elif left_floor:
			landed_rolling = mover.is_rolling()
			break
		prev_y = y
	ck(left_floor, "the dash leaves the step")
	ck(falling_ok, "loses height every frame in the air")
	ck(vx_ok, "keeps the dash's horizontal speed while falling")
	ck(landed_rolling and absf(hero.global_position.y - (floor_y - FEET)) < 1.5,
			"lands on the lower platform before the dash ends (y %.1f, still dashing %s)" % [hero.global_position.y, landed_rolling])
	step.queue_free()
	await physics_frame

	print("[b] An air dash (D264) keeps its height")
	await _stand(start)
	hero.velocity = Vector2(0, -350)
	for i in 8: await physics_frame
	ck(not hero.is_on_floor(), "in the air")
	await _tap(&"dodge")
	ck(mover.is_rolling() and mover.air_dash, "an air dash started")
	var y0: float = hero.global_position.y
	var level := true
	while mover.is_rolling():
		await physics_frame
		if absf(hero.global_position.y - y0) > 0.5:
			level = false
	ck(level, "level for the whole dash (dy %.1f)" % (hero.global_position.y - y0))

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
