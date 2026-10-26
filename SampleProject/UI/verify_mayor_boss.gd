extends SceneTree

## Бос Зали мера — сокирник Скорпікори (D468, D557, D642, design/lab_boss_plan.md slice 3).
##   [1] Герой очікуваного рівня (5: присяга, D297). Числа D642 (бос падає приблизно від 40 ударів, убиває героя за 3–4)
##       рахує verify_difficulty — для збірок SKILLS і STRENGTH із атрибутами, бронею й навичками (B144); тут — лише
##       для звіту, скільки б це було в героя без жодних вкладень.
##   [2] Кожен хід на арені DesertRoad (справжній AI, набір з одного ходу): підказка свого кольору (D573/D574)
##       з відблиском на сокирі, і удар влучає.
##   [3] Зала: велетенський скорпіон — лише кат-сцена (D557): виходить із проламу, стає дибки, вертається в пролам;
##       бою з ним нема, тіла й хітбоксу в нього нема, герой не втрачає HP. Перемога: скорпіон вертається, забирає
##       сокирника й іде; далі MayorHall_Victory і лабораторія. Програш (герой падає від удару боса) — у verify_mayor_hall.gd.
##   godot --headless --path . --script res://SampleProject/UI/verify_mayor_boss.gd

const WARRIOR := "res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn"
const HALL := "res://SampleProject/Maps/MayorHall.tscn"
const TEST_DIR := "user://verify_mayor_boss/"
const TEST_SLOT := 1
## XP до 5 рівня з xp_curve.json (100 + 150 + 200 + 250) — рівень героя в Залі мера (verify_xp_curve: 5 → 8 після боса).
const XP_TO_LEVEL_5 := 700
const EXPECTED_LEVEL := 5
## Підказки ходів (D574): серія — жовта, потім червона; ривок і удар об землю — червоні.
const TELLS := {"combo": [&"parry", &"dodge"], "slam": [&"dodge"], "charge": [&"dodge"]}

var fails: Array[String] = []
var game: Node
var sl: Node
var eb: Node
var dm: Node
var hero: Node
var floor_y := 0.0
var arena_x := 0.0
var level5_hp := 0
var started: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.hints = false  # D728: no «?» tips in this run
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	hero = game.player

	await _numbers()
	await _arena()
	await _hall()

	game.queue_free()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _numbers() -> void:
	print("[1] D642 at the expected level")
	var xp: Node = sl.get_xp_manager()
	xp.add_xp(XP_TO_LEVEL_5)
	var who: String = sl.get_game_manager().get_active_character().character_id
	sl.get_equipment_manager().equip_item(who, "sword", "iron_sword", sl.get_item_database().get_item("iron_sword"))
	await create_timer(0.3).timeout
	hero.refresh_max_health()
	level5_hp = hero.Max_Health
	var gm: Node = sl.get_game_manager()
	var hit: int = gm.calculate_physical_damage()
	var boss: Node = load(WARRIOR).instantiate()
	var boss_hp: int = boss.enemy_stats.max_health
	var hits := ceili(float(boss_hp) / hit)
	ck(xp.current_level == EXPECTED_LEVEL, "the hero is at level %d (%d)" % [EXPECTED_LEVEL, xp.current_level])
	print("    info: the boss (%d HP) takes %d light hits of %d from a hero with nothing invested (D642 lives in verify_difficulty)" % [boss_hp, hits, hit])
	# Лише сила: усі очки атрибутів рівнів 2–5 у Strength (attributes.json) — для звіту; спадну віддачу сили (D642)
	# ставить cloud/difficulty, тут лише видно, скільки вона зараз дає.
	var am: Node = sl.get_attribute_manager()
	var str_hit: int = hit + am.get_unspent() * int(am.get_definition("strength").per_point.attack)
	print("    info: strength-only build hits for %d → %d hits; level-5 hero has %d HP" % [str_hit, ceili(float(boss_hp) / str_hit), level5_hp])
	boss.free()

func _arena() -> void:
	print("[2] Each move: its tell colour on the axe, then the hit")
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain()
	await create_timer(1.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x
	var boss: Node = load(WARRIOR).instantiate()
	hero.global_position = Vector2(arena_x - 700.0, floor_y)  # за межею виявлення: бос не почне ходу сам
	boss.position = game.map.to_local(Vector2(arena_x + 300.0, floor_y - 40.0))
	game.map.add_child(boss)
	await create_timer(1.0).timeout
	boss.set_physics_process(false)
	ck(boss.is_in_group(&"boss") and boss.bar.get_node("%BossName").text == "The Scorpicore Axe-Warrior", "a boss with its bar (%s)" % boss.bar.get_node("%BossName").text)
	ck(boss.sprite.texture.resource_path.ends_with("mayor_hall_boss/sheet.png"), "drawn from the D644 sheet")
	for kind: String in ["combo", "slam", "charge"]:
		await _move(boss, kind, {"combo": -55.0, "slam": -180.0, "charge": -360.0}[kind])
	await _stagger(boss)
	boss.queue_free()
	await create_timer(0.3).timeout

## Бос робить лише [param kind]: підказки (EventBus.enemy_tell_shown і EnemyTell на ньому) і кожне падіння HP героя.
func _move(boss: Node, kind: String, dx: float) -> void:
	var all: Array[Dictionary] = boss.moves
	var move: Dictionary = all.filter(func(m: Dictionary) -> bool: return m.kind == kind)[0]
	var only: Array[Dictionary] = [move]
	boss.moves = only
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position = Vector2(boss.global_position.x + dx, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	await physics_frame
	var tells: Array[StringName] = []
	var on_tell := func(e: Node, t: StringName) -> void:
		if e == boss: tells.append(t)
	eb.enemy_tell_shown.connect(on_tell)
	var glints: Array = []
	var on_child := func(n: Node) -> void:
		if n.get_script() == preload("res://SampleProject/Scripts/FX/EnemyTell.gd"):
			glints.append([boss.anim_player.assigned_animation, n.glint_at, n.direction, boss.sprite.offset])
	boss.child_entered_tree.connect(on_child)
	boss.enemy_logic.last_move = {}
	boss.enemy_logic.attack_ready_in = 0.0
	var drops: Array[int] = []
	var hp: int = hero.current_health
	boss.set_physics_process(true)
	var began := false
	for i in 600:
		await physics_frame
		if hero.current_health < hp:
			drops.append(hp - hero.current_health)
		hp = hero.current_health
		if boss.enemy_logic.is_attacking and boss.enemy_logic.last_move.get("kind", "") == kind:
			began = true
		elif began:
			break
	await create_timer(0.9).timeout  # хвиля догоряє
	if hero.current_health < hp:
		drops.append(hp - hero.current_health)
	boss.set_physics_process(false)
	eb.enemy_tell_shown.disconnect(on_tell)
	boss.child_entered_tree.disconnect(on_child)
	boss.moves = all
	ck(tells == TELLS[kind], "%s: tells %s (D574: %s)" % [kind, tells, TELLS[kind]])
	var pose: String = {"combo": "attack", "slam": "slam", "charge": "charge"}[kind]
	var key := "tell_at_" + pose
	var at: Vector2 = boss.sprite.get_meta(key) if boss.sprite.has_meta(key) else boss.sprite.get_meta(&"tell_at")
	var on_axe := not glints.is_empty()
	for g: Array in glints:
		var want: Vector2 = boss.sprite.position + (g[3] + Vector2(at.x * g[2], at.y)) * boss.sprite.scale
		on_axe = on_axe and g[0] == pose and g[1].is_equal_approx(want)
	ck(on_axe, "%s: the glint sits on the axe of the %s pose %s (%s)" % [kind, pose, at, glints])
	# Серія: після першого влучання герой у збої й відкинутий (D264) — решта замахів може пройти повз.
	ck(not drops.is_empty() and drops.size() <= TELLS[kind].size(), "%s: it lands on a hero in range (%s)" % [kind, drops])
	for d: int in drops:
		var to_kill := ceili(float(level5_hp) / d)
		print("    info: %s: a hit of %d kills the level-%d hero with nothing invested (%d HP) in %d" % [kind, d, EXPECTED_LEVEL, level5_hp, to_kill])
	await create_timer(0.6).timeout

## Збій (поза stagger — перший кадр смерті з того ж аркуша): аркуш і кадри повертаються.
func _stagger(boss: Node) -> void:
	hero.global_position = Vector2(boss.global_position.x - 700.0, floor_y)
	boss.set_physics_process(true)
	boss.stagger(0.4, hero.global_position.x)
	await physics_frame
	var during: int = boss.sprite.frame
	await create_timer(0.8).timeout
	boss.set_physics_process(false)
	ck(during == 20 and not boss.enemy_view.staggered and boss.sprite.texture.resource_path.ends_with("mayor_hall_boss/sheet.png") and boss.sprite.hframes == 4,
			"stagger shows frame 20 of the same sheet, then it ends (%d, %s)" % [during, boss.sprite.texture.resource_path])

func _hall() -> void:
	print("[3] Mayor Hall: the giant scorpion only in the cutscene")
	await game.teleport_to_room(HALL, ^"Arrival")
	for i in 30: await physics_frame
	var hall: Node = game.map
	var scorpion: Node2D = hall.get_node(^"GiantScorpion")
	var warrior: Node2D = hall.get_node(^"ScorpicoreWarrior")
	ck(not scorpion.visible and scorpion.find_children("*", "CollisionObject2D", true, false).is_empty(),
			"the scorpion waits hidden, with no body or hitbox")
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	var hurt: Array[int] = []  # кожен удар по героєві (damage_token), а не HP: 400 XP боса піднімають рівень і Max_Health
	hero.damage_token.connect(func(amount: int) -> void: hurt.append(amount))
	var anims: Array[StringName] = []
	scorpion.get_node(^"AnimationPlayer").animation_started.connect(func(a: StringName) -> void: anims.append(a))
	started.clear()
	_press(&"move_right")
	var seen := false
	var deadline := Time.get_ticks_msec() + 40000
	while hall.get_current_state_name() != "FIGHT" and Time.get_ticks_msec() < deadline:
		if hall.get_current_state_name() != "QUEUE":
			_press(&"move_right", false)
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		seen = seen or (scorpion.visible and scorpion.modulate.a > 0.9)
		await process_frame
	for i in 10: await physics_frame
	ck(hall.get_current_state_name() == "FIGHT", "the cutscene ends in the fight")
	ck(seen and anims.has(&"walk") and anims.has(&"sting"), "the scorpion came out of the breach and reared (%s)" % [anims])
	ck(not scorpion.visible, "it went back into the breach before the fight")
	ck(hurt.is_empty(), "the scorpion did no damage (hits %s)" % [hurt])
	ck(started == ["City_MayorHall", "MayorHall_WallBurst"], "the D300 beats keep their talks (%s)" % [started])
	ck(get_nodes_in_group(&"boss").size() == 1 and get_first_node_in_group(&"boss") == warrior, "one boss in the fight: the axe-warrior (D557)")

	print("[4] Win: the scorpion hauls him off, the victory talk, the Laboratory")
	warrior.take_damage(warrior.current_health + 1000)
	var hits_at_win := hurt.size()
	anims.clear()
	var came_back := false
	var taken := false
	var gone_before_talk := false
	deadline = Time.get_ticks_msec() + 20000
	while not started.has("MayorHall_Victory") and Time.get_ticks_msec() < deadline:
		came_back = came_back or (scorpion.visible and scorpion.modulate.a > 0.9)
		taken = taken or (came_back and warrior.modulate.a < 0.05)
		await process_frame
	gone_before_talk = not scorpion.visible
	ck(came_back and anims.has(&"walk"), "the scorpion came back through the breach (%s)" % [anims])
	ck(taken, "the beaten warrior is taken away (alpha %.2f)" % warrior.modulate.a)
	ck(gone_before_talk, "the scorpion left before the victory talk")
	ck(started.has("MayorHall_Victory"), "the victory talk (%s)" % [started])
	ck(hurt.size() == hits_at_win, "no damage from the scorpion (hits %s)" % [hurt.slice(hits_at_win)])
	await _drain()
	deadline = Time.get_ticks_msec() + 10000
	while not (game.map != null and game.map.scene_file_path.ends_with("LabCells.tscn")) and Time.get_ticks_msec() < deadline:
		await process_frame
	ck(game.map != null and game.map.scene_file_path.ends_with("LabCells.tscn") and game.get_quest_flag("mayor_boss_defeated"),
			"then the Laboratory cells, mayor_boss_defeated set")
