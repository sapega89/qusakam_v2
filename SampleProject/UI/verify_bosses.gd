extends SceneTree

## Боси (queue row 9.2, D301/D302, design/lab_boss_plan.md): Brass Collector і вогняний джин на арені DesertRoad
## (кімнатних ворогів прибрано). Кожен хід — справжній AI боса з набором з одного ходу; дії героя — через
## Input.parse_input_event (атака, ривок, стрибок, блок), як клавіатура / геймпад.
##   godot --headless --path . --script res://SampleProject/UI/verify_bosses.gd

const BRASS := "res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn"
const DJINN := "res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn"
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
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

func _tap(action: StringName) -> void:
	_press(action)
	await physics_frame
	await physics_frame
	_press(action, false)

var game: Node
var eb: Node
var sl: Node
var hero: Node
var floor_y := 0.0
var arena_x := 0.0

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
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
	_heal()
	hero.global_position.x += 700.0  # арена: подалі від лівої стіни кімнати
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	await _brass()
	_heal()  # 400 XP — новий рівень перераховує Max_Health героя
	hero.global_position = Vector2(arena_x, floor_y)
	await create_timer(0.3).timeout
	await _djinn()
	_heal()
	await _defeat_handler()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _heal() -> void:
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health

func _spawn(path: String, dx: float) -> Node:
	var boss: Node = load(path).instantiate()
	boss.position = game.map.to_local(Vector2(arena_x + dx, floor_y - 40.0))
	game.map.add_child(boss)
	await create_timer(1.0).timeout
	return boss

## Герой стоїть на [param dx] px від боса, обличчям до нього.
func _place(boss: Node, dx: float) -> void:
	hero.global_position = Vector2(boss.global_position.x + dx, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1 if dx < 0 else -1
	await physics_frame
	await physics_frame

func _hazards() -> Array:
	return game.map.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.contains("/FX/Bosses/"))

## Бос робить лише [param kind]: чекаємо, поки хід почнеться ([param on_start] — дія героя під час нього) і скінчиться.
func _run_move(boss: Node, kind: String, dx: float, on_start: Callable = Callable()) -> int:
	var all: Array[Dictionary] = boss.moves
	boss.moves = all.filter(func(m: Dictionary) -> bool: return m.kind == kind)
	await _place(boss, dx)
	boss.enemy_logic.last_move = {}
	boss.enemy_logic.attack_ready_in = 0.0
	var hp0: int = hero.current_health
	boss.set_physics_process(true)
	var started := false
	for i in 400:
		await physics_frame
		if boss.enemy_logic.last_move.get("kind", "") == kind:
			started = true
			break
	if started and on_start.is_valid():
		await on_start.call()
	for i in 400:
		if not boss.enemy_logic.is_attacking:
			break
		await physics_frame
	boss.set_physics_process(false)
	boss.moves = all
	ck(started, "%s: the boss ran %s" % [boss.name, kind])
	await create_timer(0.9).timeout  # хвилі й стовпи догоряють
	return hp0 - hero.current_health

## Підказки боса (4b): кожен EnemyTell, що з'явився на босі, — [анімація, відблиск, довжина лінії, напрямок].
func _watch_tells(boss: Node, into: Array) -> Callable:
	var cb := func(n: Node) -> void:
		if n.get_script() == preload("res://SampleProject/Scripts/FX/EnemyTell.gd"):
			into.append([boss.anim_player.assigned_animation, n.glint_at, n.line_length, n.direction, boss.sprite.offset])
	boss.child_entered_tree.connect(cb)
	return cb

## Відблиск ходу стоїть на зброї пози [param pose] самого боса (meta tell_at[_<pose>]), а не там, де він у бандита.
func _check_tell(boss: Node, tells: Array, kind: String, pose: String, line: float) -> void:
	var sprite: Sprite2D = boss.sprite
	var key := "tell_at_" + pose
	var at: Vector2 = sprite.get_meta(key) if sprite.has_meta(key) else sprite.get_meta(&"tell_at")
	var ok := not tells.is_empty()
	for t: Array in tells:
		var want: Vector2 = sprite.position + (t[4] + Vector2(at.x * t[3], at.y)) * sprite.scale  # t[4] — зсув нахилу замаху
		ok = ok and t[0] == pose and t[1].is_equal_approx(want) and is_equal_approx(t[2], line)
	ck(ok and at != Vector2(3, -26), "%s %s: glint on its own %s point %s (not the bandit's), ground line %.0f px (%s)" % [boss.name, kind, pose, at, line, tells])

## Перерва між ходами — ігровий час (4b): під стоп-кадром (time_scale 0) і на паузі вона стоїть, потім минає.
func _game_time_cooldown(boss: Node) -> void:
	var all: Array[Dictionary] = boss.moves
	boss.moves = all.filter(func(m: Dictionary) -> bool: return m.kind == "combo")
	await _place(boss, -55)
	Engine.time_scale = 0.0  # стоп-кадр, як TimeManager.hitstop
	boss.enemy_logic.attack_ready_in = 0.3
	boss.set_physics_process(true)
	await create_timer(0.6, true, false, true).timeout
	var r1: float = boss.enemy_logic.attack_ready_in
	var frozen: bool = not boss.enemy_logic.is_attacking and r1 > 0.25
	Engine.time_scale = 1.0
	paused = true
	await create_timer(0.6, true, false, true).timeout
	var held: bool = not boss.enemy_logic.is_attacking and is_equal_approx(boss.enemy_logic.attack_ready_in, r1)
	paused = false
	var waited := 0
	while not boss.enemy_logic.is_attacking and waited < 120:
		await physics_frame
		waited += 1
	ck(frozen and held and boss.enemy_logic.is_attacking,
			"%s: the cooldown waits out hitstop and pause on game time, then the next move comes (hitstop %s, pause %s, then %d frames)" % [boss.name, frozen, held, waited])
	while boss.enemy_logic.is_attacking:
		await physics_frame
	boss.set_physics_process(false)
	boss.moves = all
	await create_timer(0.9).timeout

func _check_vanished(boss: Node, kind: String) -> void:
	await create_timer(0.6).timeout
	ck(_hazards().is_empty(), "%s: %s hazards are gone afterwards (%s)" % [boss.name, kind, _hazards()])

## Вбивства в бестіарії (-1 — ворога там нема, його не зустріли).
func _kills(kind: String) -> int:
	for e: Dictionary in JournalRecords.enemies():
		if e.kind == kind:
			return e.kills
	return -1

func _common_start(boss: Node, title: String, xp_reward: int) -> void:
	ck(boss.is_in_group(&"boss") and boss.enemy_logic.get_script().resource_path.ends_with("BossLogic.gd"), "%s: a boss with BossLogic" % title)
	ck(boss.health_bar == null, "%s: no bar over its head" % title)
	ck(is_instance_valid(boss.bar) and boss.bar.get_parent() == game.get_node(^"UICanvas"), "%s: boss bar on UICanvas" % title)
	ck(boss.bar.visible and boss.bar.get_node("%BossName").text == title, "%s: bar shown once it saw the hero, named (%s)" % [title, boss.bar.get_node("%BossName").text])
	ck(boss.enemy_stats.xp_reward == xp_reward, "%s: XP reward %d" % [title, boss.enemy_stats.xp_reward])
	ck(_kills(boss.enemy_stats.enemy_type) == 0, "%s: in the bestiary once met (D290)" % title)

## Удари героя збивають стійкість боса (D265): поки стійкість не вичерпана — замах іде; вичерпана — збій.
func _poise(boss: Node) -> void:
	var staggered: Array = []
	var cb := func(e: Node, _d: float) -> void: staggered.append(e)
	eb.enemy_staggered.connect(cb)
	boss.poise = 2
	hero.combat.attack_cooldown_time = 0.0
	for i in 4:
		await _place(boss, -60)
		await _tap(&"attack")
		await create_timer(0.35).timeout
	eb.enemy_staggered.disconnect(cb)
	hero.combat.apply_weapon_profile()
	ck(staggered.has(boss), "%s: hero's attacks break its poise → stagger (%d)" % [boss.name, staggered.size()])
	boss.poise = boss.poise_max
	await create_timer(1.2).timeout

## Блок рівно перед ударом — парирування: шкоди нема, бос у збої (D264).
func _parry(boss: Node, windup: float) -> void:
	var parried: Array = []
	var cb := func(a: Node) -> void: parried.append(a)
	eb.player_parried.connect(cb)
	var hp0: int = hero.current_health
	await _run_move(boss, "combo", -55, func() -> void:
		await create_timer(windup - 0.1).timeout
		_press(&"block"))
	_press(&"block", false)
	eb.player_parried.disconnect(cb)
	ck(parried.has(boss) and hero.current_health == hp0, "%s: a block just before the swing parries it (parried %s, HP %d→%d)" % [boss.name, parried.size(), hp0, hero.current_health])
	await create_timer(1.0).timeout

func _phase2(boss: Node) -> void:
	boss.take_damage(boss.current_health - boss.Max_Health / 2 + 1)
	await physics_frame
	ck(boss.phase == 2 and boss.windup_scale < 1.0, "%s: phase 2 at half HP (phase %d, windup x%.2f)" % [boss.name, boss.phase, boss.windup_scale])
	var bar: ProgressBar = boss.bar.get_node("%BossHp")
	ck(is_equal_approx(bar.value, boss.current_health), "%s: the bar follows HP (%d / %d)" % [boss.name, bar.value, boss.current_health])

func _death(boss: Node, title: String) -> void:
	var xp: Node = sl.get_xp_manager()
	var gained: Array = []
	var on_xp := func(amount: int, _total: int) -> void: gained.append(amount)
	xp.xp_gained.connect(on_xp)
	var kills0: int = _kills(boss.enemy_stats.enemy_type)
	var played: Array = []
	boss.anim_player.animation_started.connect(func(a: StringName) -> void: played.append(a))
	boss.take_damage(boss.current_health + 1000)
	await create_timer(2.5).timeout
	ck(boss.is_dead and played.has(&"death"), "%s: dies with its death animation (%s)" % [title, played])
	xp.xp_gained.disconnect(on_xp)
	ck(gained == [boss.enemy_stats.xp_reward], "%s: death gives %d XP (got %s)" % [title, boss.enemy_stats.xp_reward, gained])
	ck(_kills(boss.enemy_stats.enemy_type) == kills0 + 1, "%s: the kill is counted in the bestiary" % title)
	ck(not boss.bar.visible, "%s: the bar hides on death" % title)
	ck(game.map.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Coin")).is_empty(), "%s: no coins — the room gives the reward (D300)" % title)
	await create_timer(1.5).timeout
	boss.queue_free()
	await create_timer(0.3).timeout

func _brass() -> void:
	print("[1] The Brass Collector (D301)")
	var boss: Node = await _spawn(BRASS, 300)
	boss.set_physics_process(false)
	await _common_start(boss, "The Brass Collector", 400)

	var tells: Array = []
	var tell_cb := _watch_tells(boss, tells)
	var lost := await _run_move(boss, "combo", -55)
	ck(lost > 0, "Sweep hits a hero in reach (-%d HP)" % lost)
	_check_tell(boss, tells, "combo", "attack", 0.0)
	await _game_time_cooldown(boss)
	ck(boss.get_meta(&"voiced_swings", 0) > 0, "D278 voice hook counted its swings (roar on the first)")
	var poses: Array = []
	var on_anim := func(a: StringName) -> void: poses.append(a)
	boss.anim_player.animation_started.connect(on_anim)
	var pose_at_wave: Array = []
	var on_child := func(_n: Node) -> void:
		for i in 12:
			pose_at_wave.append([boss.anim_player.current_animation, boss.sprite.frame])
			await physics_frame
	game.map.child_entered_tree.connect(on_child)
	tells.clear()
	lost = await _run_move(boss, "slam", -180)
	_check_tell(boss, tells, "slam", "slam", 0.0)
	boss.anim_player.animation_started.disconnect(on_anim)
	game.map.child_entered_tree.disconnect(on_child)
	ck(poses.find(&"slam_strike") == poses.find(&"slam") + 1 and pose_at_wave.has([&"slam_strike", 17]),
			"Slam: wind-up pose, then the strike pose with the wave (%s)" % [poses])
	ck(lost > 0, "Slam: the shockwave hits a hero on the floor 180 px away (-%d HP)" % lost)
	await _check_vanished(boss, "slam")
	lost = await _run_move(boss, "slam", -180, func() -> void:
		await create_timer(1.0 * boss.windup_scale - 0.12).timeout
		await _tap(&"jump"))
	ck(lost == 0, "Slam: jumping over the shockwave avoids it (-%d HP)" % lost)
	lost = await _run_move(boss, "slam", -200, func() -> void:
		_press(&"move_left")
		await create_timer(0.6).timeout
		_press(&"move_left", false))
	ck(lost == 0 and absf(hero.global_position.x - boss.global_position.x) > 240.0, "Slam: a hero who walks out of its radius is missed (-%d HP, %.0f px)" % [lost, absf(hero.global_position.x - boss.global_position.x)])
	var x0: float = boss.global_position.x
	tells.clear()
	lost = await _run_move(boss, "charge", -360)
	_check_tell(boss, tells, "charge", "charge", float(boss.moves.filter(func(m: Dictionary) -> bool: return m.kind == "charge")[0].distance) + boss.melee_reach)
	boss.child_entered_tree.disconnect(tell_cb)
	ck(lost > 0 and absf(boss.global_position.x - x0) > 200.0, "Charge: dashes %.0f px and hits (-%d HP)" % [absf(boss.global_position.x - x0), lost])
	await _parry(boss, 0.7)
	await _poise(boss)
	await _phase2(boss)
	await _death(boss, "The Brass Collector")

func _djinn() -> void:
	print("[2] The fire djinn (D302)")
	var boss: Node = await _spawn(DJINN, 300)
	boss.set_physics_process(false)
	await _common_start(boss, "The Fire Djinn", 500)

	var tells: Array = []
	var tell_cb := _watch_tells(boss, tells)
	var lost := await _run_move(boss, "combo", -60)
	ck(lost > 0, "Claws hit a hero in reach (-%d HP)" % lost)
	_check_tell(boss, tells, "combo", "attack", 0.0)
	tells.clear()
	lost = await _run_move(boss, "fireball", -300)
	ck(lost > 0, "Fireball hits a hero standing in its path (-%d HP)" % lost)
	_check_tell(boss, tells, "fireball", "fireball", 0.0)
	await _check_vanished(boss, "fireball")
	lost = await _run_move(boss, "fireball", -300, func() -> void:
		for i in 200:
			var balls := _hazards()
			if not balls.is_empty() and absf(balls[0].global_position.x - hero.global_position.x) < 90.0:
				break
			await physics_frame
		hero.mover.roll_ready_in = 0.0
		await _tap(&"dodge"))
	ck(lost == 0, "Fireball: a dodge through it takes no damage (i-frames, -%d HP)" % lost)
	tells.clear()
	lost = await _run_move(boss, "pillar", -250)
	ck(lost > 0, "Pillar hits a hero standing on the mark (-%d HP)" % lost)
	_check_tell(boss, tells, "pillar", "pillar", 0.0)
	boss.child_entered_tree.disconnect(tell_cb)
	await _check_vanished(boss, "pillar")
	lost = await _run_move(boss, "pillar", -250, func() -> void:
		for i in 200:
			if not _hazards().is_empty():
				break
			await physics_frame
		hero.mover.last_direction = -1
		hero.mover.roll_ready_in = 0.0
		await _tap(&"dodge"))
	ck(lost == 0, "Pillar: dodging off the mark avoids it (-%d HP)" % lost)
	await _parry(boss, 0.5)
	await _poise(boss)
	await _phase2(boss)
	var counted: Array = [0, 0]
	var counter := func(n: Node) -> void:
		if n.scene_file_path.ends_with("boss_fireball.tscn"): counted[0] += 1
		elif n.scene_file_path.ends_with("boss_pillar.tscn"): counted[1] += 1
	game.map.child_entered_tree.connect(counter)
	await _run_move(boss, "fireball", -300)
	await _run_move(boss, "pillar", -250)
	game.map.child_entered_tree.disconnect(counter)
	ck(counted == [2, 3], "phase 2: two fireballs in a row and three pillars (%s)" % [counted])
	await _death(boss, "The Fire Djinn")

func _defeat_handler() -> void:
	print("[3] Player.defeat_handler replaces the Game Over screen")
	var called: Array = []
	await create_timer(1.5).timeout  # i-frames of the last hit are over
	hero.defeat_handler = func() -> void: called.append(true)
	hero.current_health = 1
	hero.take_damage(50)
	await create_timer(0.5).timeout
	ck(called.size() == 1, "the hero's defeat called the handler (dead %s, HP %d, invulnerable %s)" % [hero.is_dead, hero.current_health, hero.is_invulnerable])
	ck(get_first_node_in_group(&"game_over_screen") == null, "no Game Over screen")
	hero.defeat_handler = Callable()
	hero.revive(hero.Max_Health)
