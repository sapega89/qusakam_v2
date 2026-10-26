extends SceneTree

## Спритність у бою (B84 → D393) і темп ворогів зі статів (B111 → D394), у справжній фізиці DesertRoad.
## [1] крит ×1.5 у PlayerCombat.hit_damage; [2] ухилення в Player.mitigated_damage — 0, без збою й невразливості;
## [3] швидкість атаки скорочує замах; [4] кожен ворог б'є з темпом свого EnemyStats.attack_cooldown.
## Кидки — CombatRolls: CALM_SEED (жоден не спрацює) або засів, з яким наступний кидок випаде (_lucky).
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_stats.gd

var fails: Array[String] = []
var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")

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

## Засів, з яким наступний кидок з шансом [param chance] випаде.
func _lucky(chance: float) -> void:
	var rng: RandomNumberGenerator = rolls.rng
	for s in range(1, 100000):
		rng.seed = s
		if rng.randf() < chance:
			rng.seed = s
			return
	ck(false, "no seed rolls under %.3f" % chance)

func _initialize() -> void:
	rolls.calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var eb: Node = root.get_node("EventBus")  # не ідентифікатор: скрипт тесту компілюється до autoload
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(1.0).timeout
	var hero: Node = game.player
	var combat: Node = hero.combat
	var gm: Node = sl.get_game_manager()
	var enemies: Array = []
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
			node.set_physics_process(false)
	ck(enemies.size() >= 2, "enemies on DesertRoad (%d)" % enemies.size())
	while enemies.any(func(e: Node) -> bool: return e.enemy_logic.is_attacking) or combat.owns_animation():
		await physics_frame
	var target: Node = enemies[0]
	var landed: Array = []
	eb.damage_received.connect(func(t: Node, _s: Node, amount: int, critical: bool) -> void: landed.append([t, amount, critical]))

	print("[1] Crit (D393): a roll at calculate_critical_chance, x1.5")
	var base: int = gm.calculate_physical_damage()
	var crit_chance: float = gm.calculate_critical_chance()
	ck(crit_chance > 0.0 and crit_chance <= 0.5, "crit chance from the stats (%.3f)" % crit_chance)
	rolls.calm()
	ck(combat.hit_damage() == base and not combat.critical, "calm roll: the plain hit %d" % base)
	_lucky(crit_chance)
	var crit: int = combat.hit_damage()
	ck(crit == roundi(base * 1.5) and combat.critical, "lucky roll: a crit for %d (x1.5 of %d)" % [crit, base])
	_lucky(crit_chance)
	target.current_health = target.Max_Health
	var hp: int = target.current_health
	hero.global_position = target.global_position + Vector2(-26, 0)
	hero.velocity = Vector2.ZERO
	await create_timer(0.05).timeout
	landed.clear()
	combat.perform_attack(1)
	await create_timer(0.6).timeout
	ck(landed == [[target, crit, true]] and target.current_health == hp - crit,
			"a critical swing lands %d, flagged critical, on the enemy (%s, HP %d → %d)" % [crit, landed, hp, target.current_health])

	print("[2] Evasion (D393): a roll at calculate_dodge_chance, an evaded hit deals 0")
	var dodge: float = gm.calculate_dodge_chance()
	ck(dodge > 0.0 and dodge <= 0.5, "dodge chance from the stats (%.3f)" % dodge)
	rolls.calm()
	var plain: int = hero.mitigated_damage(20)
	ck(plain > 0, "calm roll: 20 mitigates to %d" % plain)
	_lucky(dodge)
	ck(hero.mitigated_damage(20) == 0, "lucky roll: mitigated to 0")
	await create_timer(0.6).timeout  # невразливість після попередніх ударів минула
	hero.current_health = hero.Max_Health
	var evaded: Array = []
	var staggered: Array = []
	eb.player_evaded.connect(func(source: Node) -> void: evaded.append(source))
	eb.player_staggered.connect(func(d: float) -> void: staggered.append(d))
	landed.clear()
	_lucky(dodge)
	hero.take_damage(20, target)
	ck(hero.current_health == hero.Max_Health and evaded == [target] and landed.is_empty(),
			"the evaded hit: no HP lost, player_evaded from the enemy (%s), no damage event (%s)" % [evaded, landed])
	ck(not hero.is_invulnerable and staggered.is_empty(), "no i-frames and no stagger after an evade (staggers %s)" % [staggered])
	rolls.calm()
	hero.take_damage(20, target)
	ck(hero.current_health == hero.Max_Health - plain and evaded.size() == 1, "the next, unlucky hit lands %d" % plain)

	print("[3] Attack speed (D393): calculate_attack_speed shortens the swing")
	await create_timer(0.8).timeout
	while combat.owns_animation() or combat.attack_cooldown > 0.0:
		await physics_frame
	var speed: float = gm.calculate_attack_speed()
	ck(speed > 1.0, "attack speed from the stats (x%.2f)" % speed)
	combat.perform_attack(-1)  # від ворога: влучання дало б стоп-кадр і довший замах
	ck(is_equal_approx(combat._state_left, combat.swing_time / speed), "the swing lasts %.3f s = %.2f / %.2f" % [combat._state_left, combat.swing_time, speed])
	var frames: int = 0
	while combat.state == combat.State.SWING:
		await physics_frame
		frames += 1
	var took: float = float(frames) / Engine.physics_ticks_per_second  # кадри фізики, не годинник
	ck(took < combat.swing_time, "the swing ended sooner than the bare %.2f s (%.3f s)" % [combat.swing_time, took])
	var attributes: Object = gm._active_attributes()
	var dex: int = attributes.dexterity
	attributes.dexterity = dex + 20
	var faster: float = gm.calculate_attack_speed()
	await create_timer(1.0).timeout
	combat.perform_attack(-1)
	ck(faster > speed and is_equal_approx(combat._state_left, combat.swing_time / faster),
			"more dexterity, a shorter swing (x%.2f: %.3f s)" % [faster, combat._state_left])
	attributes.dexterity = dex

	print("[4] Enemy tempo from EnemyStats.attack_cooldown (B111, D394)")
	ck(not "attack_cooldown" in enemies[0].enemy_logic, "EnemyLogic keeps no tempo of its own")
	var tempos := {}
	hero.Max_Health = 9999  # тут лише темп: чотири серії D642 інакше вбивають героя рівня 1, і пауза Game Over зупиняє бій
	hero.current_health = hero.Max_Health
	for e in enemies:
		if not e.is_alive():
			continue
		var logic: Node = e.enemy_logic
		hero.global_position = e.global_position + Vector2(-30, 0)
		logic.player = hero
		logic.change_state(logic.AIState.ATTACK)
		logic.attack_ready_in = 0.0
		logic.handle_attack_state(0.0)
		tempos[e.enemy_stats.enemy_type] = logic.attack_ready_in
		ck(is_equal_approx(logic.attack_ready_in, e.enemy_stats.attack_cooldown),
				"%s (%s) waits its stats' %.2f s (%.2f)" % [e.name, e.enemy_stats.enemy_type, e.enemy_stats.attack_cooldown, logic.attack_ready_in])
		# D504: замахуються разом не більше двох (жетон) — наступний ворог чекав би, доки цей не скінчить
		while logic.is_attacking:
			await physics_frame
	ck(tempos.has("fast") and is_equal_approx(tempos.fast, 1.0), "the fast enemy swings every 1.0 s (D642, was D494's 1.5) (%s)" % [tempos])

	ck(rolls.rolls <= rolls.CALM_ROLLS, "inside the calm rolls (%d of %d)" % [rolls.rolls, rolls.CALM_ROLLS])
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
