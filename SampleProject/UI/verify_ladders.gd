extends SceneTree

## Драбини (D225) у справжній грі — на драбині крамниці на дорозі (DesertRoad/Ladder_Shop, на дах): ↑ знизу — нагору
## на дах, ↓ над драбиною — назад на дорогу; стрибок — зіскок; на драбині не б'є й не перекочується.
## Колись ці рядки ходили драбинами лабораторії (Ladder1/Ladder2 між поверхами); лабораторія v3 (D863, D865, B201)
## підіймається великими сходами, драбин у ній немає — рядки перенесено на драбину, що лишилась у грі, а сходи
## лабораторії перевіряє verify_laboratory.
##   godot --headless --path . --script res://SampleProject/UI/verify_ladders.gd

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

func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for i in frames: await physics_frame
	Input.action_release(action)
	await physics_frame

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_fight_complete", true)  # бій дороги не заважає (verify_branches)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 20: await physics_frame
	await _drain(sl.get_dialogue_manager())
	var p: Node2D = game.player
	var mover: Node = p.mover
	var ladder: Node2D = game.map.get_node(^"Ladder_Shop")
	var bottom: float = ladder.global_position.y + ladder.height

	print("[1] At the foot of the ladder, ↑ climbs up onto the shop roof")
	p.global_position = Vector2(ladder.global_position.x, bottom - 30)
	for i in 30: await physics_frame
	ck(p.is_on_floor() and not mover.is_climbing(), "stands on the road at the foot of the ladder (y %.0f)" % p.global_position.y)
	var y0 := p.global_position.y
	Input.action_press(&"move_up")
	for i in 10: await physics_frame
	ck(mover.is_climbing(), "↑ grabs the ladder from the floor (W is also jump — climbing wins)")
	for i in 240:
		await physics_frame
		if not mover.is_climbing():
			break
	Input.action_release(&"move_up")
	for i in 40: await physics_frame
	ck(not mover.is_climbing() and p.is_on_floor() and p.global_position.y < ladder.global_position.y,
			"reaches the roof and steps off (y %.0f → %.0f)" % [y0, p.global_position.y])

	print("[2] On the roof over the ladder, ↓ climbs back down to the road")
	var y1 := p.global_position.y
	Input.action_press(&"move_down")
	for i in 10: await physics_frame
	ck(mover.is_climbing(), "↓ grabs the ladder")
	for i in 240:
		await physics_frame
		if not mover.is_climbing():
			break
	Input.action_release(&"move_down")
	for i in 20: await physics_frame
	ck(not mover.is_climbing() and p.is_on_floor() and absf(p.global_position.y - y0) < 6.0,
			"back on the road (y %.0f → %.0f, was %.0f)" % [y1, p.global_position.y, y0])

	print("[3] Midway: no attack, no roll; jump lets go")
	p.global_position = Vector2(ladder.global_position.x, ladder.global_position.y + ladder.height * 0.5)
	await _hold(&"move_up", 4)
	ck(mover.is_climbing(), "grabbed midway")
	var attack := InputEventAction.new()
	attack.action = &"attack"
	attack.pressed = true
	p._unhandled_input(attack)
	ck(not p.combat.is_attacking, "no attack on the ladder")
	ck(not mover.start_roll(), "no roll on the ladder")
	await _hold(&"jump", 2)
	ck(not mover.is_climbing(), "jump lets go of the ladder")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
