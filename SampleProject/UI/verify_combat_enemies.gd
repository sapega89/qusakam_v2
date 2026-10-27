extends SceneTree

## Вороги й боси за D504 / D494 (design/combat_critique_2026-10-23.md §B): кольорові підказки, межі парирування й рипост,
## удар після підказки не зривається (B134), боси не відкидаються, пауза зупиняє таймери боса (B135), ворог помічає
## героя лише на своєму поверсі чи на виду й не сходить з уступу (B139), жетон удару, відновлення й відхід, візерунки
## ходів боса, числа D494. Арена — DesertRoad без кімнатних ворогів, як у verify_bosses.
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_enemies.gd

const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const JACKAL := "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn"
const TANK := "res://SampleProject/Scenes/Characters/Enemies/enemy_tank.tscn"
const BRASS := "res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn"
const DJINN := "res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn"
const FIREBALL := "res://SampleProject/Scenes/FX/Bosses/boss_fireball.tscn"
const PILLAR := "res://SampleProject/Scenes/FX/Bosses/boss_pillar.tscn"
const ARROW := "res://SampleProject/Scenes/Combat/arrow.tscn"
const TELL_SCRIPT := preload("res://SampleProject/Scripts/FX/EnemyTell.gd")
const KINDS := ["block", "parry", "dodge"]
## D494: темп до проходу (D394) — новий мусить бути ×1.5.
const OLD_COOLDOWN := {"melee": 1.5, "fast": 1.0, "tank": 2.0, "archer": 2.2}
const OLD_DAMAGE := {"melee": 14.0, "fast": 10.0, "tank": 20.0, "archer": 12.0}

var fails: Array[String] = []
var game: Node
var eb: Node
var hero: Node
var floor_y := 0.0
var arena_x := 0.0


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _finish_dialogue(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()
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


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
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
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	await _numbers()
	await _tells()
	await _parry_limits()
	await _riposte()
	await _committed_swings()
	await _boss_pause()
	await _floors_and_ledges()
	await _token()
	await _recovery_and_back_off()
	await _lunges_and_pounce()
	await _boss_patterns()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


func _heal() -> void:
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health


func _spawn(path: String, dx: float, frozen: bool = true) -> Node:
	var enemy: Node = load(path).instantiate()
	if enemy.enemy_stats == null:
		var kind: String = {BANDIT: "melee", JACKAL: "fast", TANK: "tank"}[path]
		enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	enemy.position = game.map.to_local(Vector2(arena_x + dx, floor_y - 40.0))
	game.map.add_child(enemy)
	for i in 40: await physics_frame
	enemy.set_physics_process(not frozen)
	# Поки падав на підлогу, міг побачити героя й почати удар — він іде на таймерах і без фізики; чекаємо кінця
	while frozen and enemy.enemy_logic.is_attacking:
		await physics_frame
	return enemy


## Герой на підлозі арени за [param dx] px від [param enemy], обличчям до нього, вільний (не в блоці, не збитий).
func _place(enemy: Node, dx: float) -> void:
	_press(&"block", false)
	hero.global_position = Vector2(enemy.global_position.x + dx, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1 if dx < 0 else -1
	for i in 3: await physics_frame
	while hero.combat.state != hero.combat.State.READY:
		await physics_frame


func _done(enemy: Node) -> void:
	while is_instance_valid(enemy) and enemy.enemy_logic.is_attacking:
		await physics_frame
	enemy.queue_free()
	await create_timer(0.3).timeout


## [1] D494 → D642 → D754: перерви коротші за колишні (D494 сповільнив їх у ×1.5, D642 повернув), удар сильніший,
## замах не коротший за підказку.
func _numbers() -> void:
	print("[1] D642, D754: cooldowns shorter than the pre-D494 tempo, harder hits, readable wind-ups")
	var lead := 0.45
	for kind: String in OLD_COOLDOWN:
		var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
		ck(stats.attack_cooldown < OLD_COOLDOWN[kind] and stats.base_damage > OLD_DAMAGE[kind] and stats.attack_windup >= lead,
				"%s: cooldown %.2f s (shorter than %.2f, D754), damage %.0f (was %.0f), wind-up %.2f s" % [kind, stats.attack_cooldown, OLD_COOLDOWN[kind], stats.base_damage, OLD_DAMAGE[kind], stats.attack_windup])
		ck(stats.tell in KINDS and stats.finisher_tell in KINDS and stats.recovery > 0.0, "%s: tell %s, finisher %s, recovery %.2f s" % [kind, stats.tell, stats.finisher_tell, stats.recovery])
	for path in [BRASS, DJINN]:
		var boss: Node = load(path).instantiate()
		var ok := true
		for move: Dictionary in boss.moves:
			var tells: Array = move.get("tells", [move.get("tell", "")]) + move.get("tells_phase2", [])
			ok = ok and tells.all(func(t: String) -> bool: return t in KINDS) and move.has("recovery")
			if move.kind != "combo":
				ok = ok and move.tell == "dodge" and move.windup * boss.phase2_windup >= lead
		ck(ok and not boss.pattern.is_empty() and not boss.pattern_phase2.is_empty(), "%s: every move has a tell and a recovery; hazards are red; patterns set" % boss.name)
		boss.free()


## [2] Підказка: колір за ударом, за 0.45 с до удару, свій звук.
func _tells() -> void:
	print("[2] Colour tells 0.45 s ahead, each with its own sound (D504)")
	var sounds: Array = []
	var on_sound := func(event: StringName, _s: AudioStream, _b: StringName, _p: float) -> void:
		if String(event).begins_with("tell_"): sounds.append(event)
	root.get_node("AudioManager").sound_played.connect(on_sound)
	for spec: Array in [[BANDIT, ["parry", "dodge"]], [JACKAL, ["block", "block", "parry"]], [TANK, ["dodge"]]]:
		var enemy: Node = await _spawn(spec[0], 200.0)
		await _place(enemy, -400)
		enemy.combo_hits = spec[1].size()
		enemy.combo_chance = 1.0
		var shown: Array = []
		var drawn: Array = []
		var on_tell := func(e: Node, kind: StringName) -> void:
			if e == enemy:
				shown.append([String(kind), Time.get_ticks_msec()])
		var on_child := func(n: Node) -> void:
			if n.get_script() == TELL_SCRIPT:
				drawn.append(String(n.kind))
		eb.enemy_tell_shown.connect(on_tell)
		enemy.child_entered_tree.connect(on_child)
		sounds.clear()
		var strikes: Array = []
		# D775: серія б'є, лише доки дістає героя — герой стоїть у досяжності, невразливий (удари не відкидають його)
		hero.global_position = Vector2(enemy.global_position.x - 30.0, floor_y)
		hero.is_invulnerable = true
		enemy.enemy_logic.last_direction = -1
		enemy.enemy_logic.perform_attack()
		var was_on := false
		while enemy.enemy_logic.is_attacking:
			await physics_frame
			if enemy.hitbox.monitoring and not was_on:
				strikes.append(Time.get_ticks_msec())
			was_on = enemy.hitbox.monitoring
		eb.enemy_tell_shown.disconnect(on_tell)
		enemy.child_entered_tree.disconnect(on_child)
		hero.is_invulnerable = false
		var kinds: Array = shown.map(func(s: Array) -> String: return s[0])
		var leads: Array = []
		for i in mini(shown.size(), strikes.size()):
			leads.append(strikes[i] - shown[i][1])
		var name: String = enemy.enemy_stats.enemy_type
		ck(kinds == spec[1] and drawn == spec[1], "%s: tells %s, glints %s (expected %s)" % [name, kinds, drawn, spec[1]])
		ck(leads.size() == spec[1].size() and leads.all(func(ms: int) -> bool: return ms >= 400 and ms <= 520), "%s: each tell %s ms before its strike" % [name, leads])
		ck(sounds == kinds.map(func(k: String) -> StringName: return StringName("tell_" + k)), "%s: a sound per tell %s" % [name, sounds])
		await _done(enemy)
	root.get_node("AudioManager").sound_played.disconnect(on_sound)
	var colours: Dictionary = TELL_SCRIPT.GLINT_OUTER
	ck(colours[&"block"].g > 0.9 and colours[&"block"].b > 0.9 and colours[&"parry"].g > 0.6 and colours[&"parry"].b < 0.3
			and colours[&"dodge"].g < 0.3, "white, yellow and red glints (%s)" % [colours])


## Герой у блоці вже [param held] с, обличчям праворуч; потім удар [param tell] від [param enemy].
func _guarded_hit(enemy: Node, tell: StringName, held: float) -> Dictionary:
	var got := {"parried": 0, "blocked": 0, "lost": 0}
	var on_parry := func(_a: Node) -> void: got.parried += 1
	var on_block := func(_a: Node) -> void: got.blocked += 1
	eb.player_parried.connect(on_parry)
	eb.player_blocked.connect(on_block)
	await _place(enemy, -30)
	_press(&"block")
	await create_timer(held).timeout
	var hp0: int = hero.current_health
	enemy.enemy_logic.tell_kind = tell
	hero.take_damage(10, enemy)
	got.lost = hp0 - hero.current_health
	_press(&"block", false)
	eb.player_parried.disconnect(on_parry)
	eb.player_blocked.disconnect(on_block)
	await create_timer(1.2).timeout  # невразливість і збій минули
	enemy.enemy_logic.stun_left = 0.0
	return got


## [3] Парирування лише жовтих ударів; білі — лише блок; червоні й снаряди боса — ні те, ні те (B133).
func _parry_limits() -> void:
	print("[3] Parry limits: yellow parries, white only blocks, red and boss hazards neither (B133)")
	var bandit: Node = await _spawn(BANDIT, 200.0)
	bandit.poise_max = 99
	bandit.poise = 99
	var got := await _guarded_hit(bandit, &"parry", 0.1)
	ck(got.parried == 1 and got.lost == 0, "yellow in the window: parried, no damage (%s)" % [got])
	got = await _guarded_hit(bandit, &"parry", 0.5)
	ck(got.parried == 0 and got.blocked == 1 and got.lost == 0, "yellow after the window: a plain block (%s)" % [got])
	got = await _guarded_hit(bandit, &"block", 0.1)
	ck(got.parried == 0 and got.blocked == 1 and got.lost == 0, "white in the window: blocked, never parried (%s)" % [got])
	got = await _guarded_hit(bandit, &"dodge", 0.1)
	ck(got.parried == 0 and got.blocked == 0 and got.lost > 0, "red: neither blocked nor parried (%s)" % [got])
	bandit.enemy_logic.tell_kind = &"parry"

	# Стріла лучника (жовта) парирується й летить назад — але рипосту не відкриває
	await _place(bandit, -30)
	_press(&"block")
	await create_timer(0.1).timeout
	var arrow: Node = load(ARROW).instantiate()
	arrow.hero_side = false
	arrow.direction = -1
	arrow.damage = 10
	arrow.shooter = bandit
	game.map.add_child(arrow)
	arrow.global_position = hero.global_position + Vector2(60, -10)
	for i in 30:
		await physics_frame
		if arrow.hero_side:
			break
	ck(arrow.hero_side and hero.combat.riposte_left == 0.0, "a yellow arrow is parried back, and opens no riposte (hero side %s, riposte %.2f)" % [arrow.hero_side, hero.combat.riposte_left])
	_press(&"block", false)
	await create_timer(1.0).timeout
	await _done(bandit)

	var djinn: Node = await _spawn(DJINN, 450.0)
	var parried: Array = []
	var on_parry := func(a: Node) -> void: parried.append(a)
	eb.player_parried.connect(on_parry)
	# Куля: блок натиснуто перед самим влучанням, обличчям до неї
	hero.global_position = Vector2(arena_x, floor_y)
	hero.mover.last_direction = 1
	await create_timer(1.5).timeout  # кулі й стовпи з появи джина догоріли, невразливість минула
	hero.is_invulnerable = false
	var hp0: int = hero.current_health
	var ball: Node = load(FIREBALL).instantiate()
	ball.direction = -1
	ball.damage = 20
	game.map.add_child(ball)
	ball.global_position = Vector2(arena_x + 120.0, hero.global_position.y - 24.0)
	await create_timer(0.2).timeout
	_press(&"block")
	await create_timer(0.3).timeout
	_press(&"block", false)
	ck(hp0 - hero.current_health > 0 and parried.is_empty() and djinn.enemy_logic.stun_left <= 0.0,
			"fireball: a block in time neither blocks nor parries it, and the djinn 450 px away is not staggered (-%d HP, parried %s)" % [hp0 - hero.current_health, parried])
	await create_timer(1.2).timeout
	# Стовп під героєм, що стоїть у блоці
	_press(&"block")
	await create_timer(0.1).timeout
	hp0 = hero.current_health
	var pillar: Node = load(PILLAR).instantiate()
	pillar.damage = 20
	game.map.add_child(pillar)
	pillar.global_position = Vector2(hero.global_position.x, floor_y)
	await pillar.finished
	_press(&"block", false)
	ck(hp0 - hero.current_health > 0 and parried.is_empty(), "pillar: blocking does not hold it (-%d HP)" % (hp0 - hero.current_health))
	await create_timer(1.2).timeout
	# Хвиля: шкоду несе сама хвиля, не бос
	var brass: Node = await _spawn(BRASS, 600.0)
	await _place(brass, -150)
	_press(&"block")
	await create_timer(0.1).timeout
	hp0 = hero.current_health
	brass.enemy_logic._slam({"radius": 240.0, "damage": 1.0})
	_press(&"block", false)
	ck(hp0 - hero.current_health > 0 and parried.is_empty() and brass.enemy_logic.stun_left <= 0.0,
			"slam: a block facing the boss does not hold the shockwave, and nothing staggers the boss (-%d HP)" % (hp0 - hero.current_health))
	eb.player_parried.disconnect(on_parry)
	await create_timer(1.2).timeout
	brass.queue_free()
	djinn.queue_free()
	await create_timer(0.5).timeout


## [4] Рипост: вдале парирування відкриває вікно; наступний удар — важкий рипост ×3, що ламає будь-яку стійкість.
func _riposte() -> void:
	print("[4] A parry opens a riposte: a heavy x3 hit that ignores poise (D504)")
	var bandit: Node = await _spawn(BANDIT, 200.0)
	bandit.poise_max = 99
	bandit.poise = 99
	bandit.Max_Health = 99999
	bandit.current_health = bandit.Max_Health
	var hits: Array = []
	bandit.damage_token.connect(func(d: int) -> void: hits.append(d))
	var staggers: Array = []
	var on_stagger := func(e: Node, _d: float) -> void:
		if e == bandit: staggers.append(Time.get_ticks_msec())
	eb.enemy_staggered.connect(on_stagger)
	await _place(bandit, -30)
	_press(&"block")
	await create_timer(0.1).timeout
	bandit.enemy_logic.tell_kind = &"parry"
	hero.take_damage(10, bandit)
	_press(&"block", false)
	ck(staggers.size() == 1 and hero.combat.riposte_left > 0.8, "parried: the bandit reels, the riposte window is open (%.2f s)" % hero.combat.riposte_left)
	for i in 3: await physics_frame
	var expected := roundi(root.get_node("ServiceLocator").get_game_manager().calculate_physical_damage() * hero.combat.RIPOSTE_DAMAGE)
	await _tap(&"attack")
	var heavy: bool = hero.combat.state == hero.combat.State.HEAVY_STRIKE and hero.combat.riposting
	await create_timer(0.4).timeout
	ck(heavy and hits == [expected], "the next attack is a heavy riposte (heavy %s), %s damage (expected %d)" % [heavy, hits, expected])
	ck(staggers.size() == 2 and bandit.poise == bandit.poise_max, "it breaks a poise of 99 outright (staggers %d)" % staggers.size())
	await create_timer(1.3).timeout
	# Вікно минає
	hits.clear()
	bandit.enemy_logic.stun_left = 0.0
	await _place(bandit, -30)
	_press(&"block")
	await create_timer(0.1).timeout
	hero.take_damage(10, bandit)
	_press(&"block", false)
	await create_timer(hero.combat.RIPOSTE_WINDOW + 0.15).timeout
	await _tap(&"attack")
	ck(hero.combat.state == hero.combat.State.SWING and not hero.combat.riposting, "after %.1f s the window is gone: a plain swing" % hero.combat.RIPOSTE_WINDOW)
	eb.enemy_staggered.disconnect(on_stagger)
	await create_timer(0.8).timeout
	await _done(bandit)


## [5] B134, D754: замах і удар стоять на місці (відкидання їх не зсуває й не зриває), зриває лише збій; боси не відкидаються.
func _committed_swings() -> void:
	print("[5] B134, D754: a swing holds its ground — only a poise break stops it; bosses ignore knockback")
	var bandit: Node = await _spawn(BANDIT, 200.0)
	bandit.combo_hits = 1
	await _place(bandit, -400)
	bandit.enemy_logic.last_direction = -1
	bandit.enemy_logic.perform_attack()
	await create_timer(0.1).timeout
	var x_swing: float = bandit.global_position.x
	bandit.knockback(-40.0)
	await physics_frame
	var held: bool = absf(bandit.global_position.x - x_swing) < 1.0
	var struck := await _struck(bandit)
	ck(struck and held, "knockback during the wind-up neither moves it nor breaks the swing (D754; moved %s, struck %s)" % [not held, struck])
	while bandit.enemy_logic.is_attacking:  # серія дійшла до кінця — поза відновлення
		await physics_frame
	await create_timer(0.3).timeout
	bandit.enemy_logic.perform_attack()
	while not bandit.enemy_logic.committed:
		await physics_frame
	bandit.knockback(-40.0)
	bandit.stun(1.0)
	struck = await _struck(bandit)
	ck(struck and bandit.enemy_logic.stun_left <= 0.0, "after the tell, knockback and a stun do not stop it (struck %s)" % struck)
	await create_timer(0.3).timeout
	bandit.enemy_logic.perform_attack()
	while not bandit.enemy_logic.committed:
		await physics_frame
	bandit.take_poise(99, hero.global_position.x)
	struck = await _struck(bandit)
	ck(not struck, "after the tell, a poise break still stops it")
	await create_timer(0.8).timeout
	await _done(bandit)

	var brass: Node = await _spawn(BRASS, 300.0)
	var x0: float = brass.global_position.x
	brass.enemy_logic.knockback_left = 0.0  # ривок, що міг іти при появі (фізика вимкнена — не дорахувався)
	brass.knockback(80.0)
	brass.nudge(20.0)
	for i in 10: await physics_frame
	ck(brass.enemy_logic.knockback_left <= 0.0 and absf(brass.global_position.x - x0) < 1.0, "the boss does not move from knockback (%.1f px)" % (brass.global_position.x - x0))
	brass.enemy_logic.last_move = {}
	brass.moves = brass.moves.filter(func(m: Dictionary) -> bool: return m.kind == "slam")
	await _place(brass, -150)
	brass.enemy_logic.perform_attack()
	await create_timer(0.3).timeout
	brass.knockback(60.0)
	var waves: Array = []
	var on_child := func(n: Node) -> void:
		if n.scene_file_path.ends_with("boss_shockwave.tscn"): waves.append(n)
	game.map.child_entered_tree.connect(on_child)
	while brass.enemy_logic.is_attacking:
		await physics_frame
	game.map.child_entered_tree.disconnect(on_child)
	ck(waves.size() == 1, "a mace-strength hit during the slam's wind-up does not cancel it (waves %d)" % waves.size())
	brass.queue_free()
	await create_timer(0.5).timeout


## Удар відбувся: хітбокс увімкнувся до кінця серії.
func _struck(enemy: Node) -> bool:
	var on := false
	while enemy.enemy_logic.is_attacking and not enemy.enemy_logic.recovering:
		on = on or enemy.hitbox.monitoring
		await physics_frame
	return on


## [6] B135: пауза зупиняє стовп і відновлення боса.
func _boss_pause() -> void:
	print("[6] B135: boss timers stop while the game is paused")
	var djinn: Node = await _spawn(DJINN, 300.0)
	djinn.moves = djinn.moves.filter(func(m: Dictionary) -> bool: return m.kind == "pillar")
	await _place(djinn, -250)
	hero.is_invulnerable = false
	djinn.enemy_logic.last_move = {}
	djinn.enemy_logic.perform_attack()
	var pillar: Node = null
	for i in 200:
		await physics_frame
		for n in game.map.get_children():
			if n.scene_file_path.ends_with("boss_pillar.tscn"):
				pillar = n
		if pillar != null:
			break
	var hp0: int = hero.current_health
	paused = true
	await create_timer(1.3, true, false, true).timeout
	var lost_paused: int = hp0 - hero.current_health
	var alive: bool = is_instance_valid(pillar)
	paused = false
	while djinn.enemy_logic.is_attacking and not djinn.enemy_logic.recovering:
		await physics_frame
	ck(lost_paused == 0 and alive and hp0 - hero.current_health > 0,
			"a pillar marked before a 1.3 s pause waits it out, then burns (paused -%d, after -%d)" % [lost_paused, hp0 - hero.current_health])
	paused = true
	await create_timer(1.0, true, false, true).timeout
	var still: bool = djinn.enemy_logic.recovering
	paused = false
	ck(still, "the recovery (punish window) is not eaten by a pause")
	await _done(djinn)


## [7] B139: поверх і видимість; уступ і стіна.
func _floors_and_ledges() -> void:
	print("[7] B139: noticed only on its floor or in sight; walkers stop at ledges and walls")
	hero.global_position = Vector2(arena_x - 700.0, floor_y)
	await physics_frame
	var bandit: Node = await _spawn(BANDIT, 150.0, false)
	var slab := _static_box(Vector2(arena_x + 150.0, floor_y - 130.0), Vector2(700, 20))
	for i in 3: await physics_frame
	hero.set_physics_process(false)
	hero.global_position = Vector2(arena_x + 120.0, floor_y - 170.0)  # на плиті над бандитом
	var engaged: Array = []
	var on_state := func(s: int) -> void:
		if s in [bandit.enemy_logic.AIState.CHASE, bandit.enemy_logic.AIState.ATTACK]: engaged.append(s)
	bandit.enemy_logic.state_changed.connect(on_state)
	await create_timer(2.6).timeout
	ck(not bandit.enemy_logic.can_notice(hero) and engaged.is_empty() and not hero.combat._enemy_engaged(),
			"a hero on the slab above is not noticed: no chase, no fight (states %s)" % [engaged])
	hero.global_position = Vector2(arena_x - 60.0, floor_y)
	hero.set_physics_process(true)
	for i in 180:
		await physics_frame
		if not engaged.is_empty():
			break
	ck(bandit.enemy_logic.can_notice(hero) and not engaged.is_empty(), "on its floor he is noticed (states %s)" % [engaged])
	slab.queue_free()
	bandit.set_physics_process(false)
	await create_timer(0.8).timeout
	await _done(bandit)

	# Уступ: бандит на плиті в повітрі, герой на її висоті за краєм — бандит доходить до краю й стоїть
	var top := floor_y - 300.0
	var ledge := _static_box(Vector2(arena_x + 400.0, top + 10.0), Vector2(240, 20))
	bandit = load(BANDIT).instantiate()
	bandit.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	bandit.position = game.map.to_local(Vector2(arena_x + 400.0, top - 60.0))
	game.map.add_child(bandit)
	for i in 40: await physics_frame
	var feet0: float = bandit.global_position.y
	hero.set_physics_process(false)
	hero.global_position = Vector2(arena_x + 400.0 + 260.0, top - 30.0)
	bandit.enemy_logic.on_player_detected(hero)
	await create_timer(3.0).timeout
	var edge := arena_x + 400.0 + 120.0
	ck(bandit.is_on_floor() and absf(bandit.global_position.y - feet0) < 2.0 and bandit.global_position.x < edge and not bandit.enemy_logic.can_step(1),
			"the bandit stops at the ledge (x %.0f, edge %.0f, y %.0f→%.0f)" % [bandit.global_position.x, edge, feet0, bandit.global_position.y])
	bandit.queue_free()
	ledge.queue_free()
	hero.global_position = Vector2(arena_x, floor_y)
	hero.set_physics_process(true)
	await create_timer(0.5).timeout
	bandit = await _spawn(BANDIT, 200.0)
	var half: float = bandit.body_collision.shape.size.x * bandit.global_scale.x / 2.0
	var wall := _static_box(Vector2(bandit.global_position.x + half + 12.0, bandit.global_position.y), Vector2(20, 160))
	for i in 3: await physics_frame
	ck(not bandit.enemy_logic.can_step(1) and bandit.enemy_logic.can_step(-1), "a wall ahead blocks the step, open floor behind does not")
	wall.queue_free()
	await _done(bandit)


func _static_box(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	game.map.add_child(body)
	body.global_position = center
	return body


## [8] Жетон: замахуються одночасно не більше max_attackers(), і лише з одного боку героя (D770); решта чекає й переступає.
func _token() -> void:
	var most: int = load("res://SampleProject/Scripts/Gameplay/Components/EnemyLogic.gd").max_attackers()
	print("[8] At most %d enemies wind up at once (attack token, D642)" % most)
	var crowd: Array[Node] = []
	for i in most + 1:
		crowd.append(await _spawn(BANDIT, 170.0 + 60.0 * i))
	var a: Node = crowd[0]
	var last: Node = crowd[-1]
	await _place(crowd[1], -30)
	for e: Node in crowd:
		e.global_position.x = hero.global_position.x + 30.0  # D770: жетон беруть лише з одного боку героя — тут усі з правого
		e.enemy_logic.player = hero
		e.enemy_logic.change_state(e.enemy_logic.AIState.ATTACK)
		e.enemy_logic.attack_ready_in = 0.0
	for e: Node in crowd:
		e.enemy_logic.handle_attack_state(0.016)
	var states := crowd.map(func(e: Node) -> bool: return e.enemy_logic.is_attacking)
	var expected := []
	for i in most + 1:
		expected.append(i < most)
	ck(states == expected and a.enemy_logic.attackers() == most, "%d swing, the last waits (%s, tokens %d)" % [most, states, a.enemy_logic.attackers()])
	last.set_physics_process(false)  # чекає на місці: живий AI переступав би чи обходив героя (D770)
	while a.enemy_logic.is_attacking and not a.enemy_logic.recovering:
		await physics_frame
	last.set_physics_process(true)
	last.global_position.x = hero.global_position.x + 30.0  # удари перших відштовхнули героя (усі вони з одного боку)
	last.enemy_logic.handle_attack_state(0.016)
	ck(last.enemy_logic.is_attacking, "once one recovers, its token passes to the last")
	for e: Node in crowd:
		await _done(e)
	# D770: з другого боку героя не замахуються, поки б'ють з цього (оточений герой блоком рятується від одного боку за раз)
	var right: Node = await _spawn(BANDIT, 200.0)
	var left: Node = await _spawn(BANDIT, 260.0)
	for e: Node in [right, left]:
		e.global_position.x = hero.global_position.x + (30.0 if e == right else -30.0)
		e.enemy_logic.player = hero
		e.enemy_logic.change_state(e.enemy_logic.AIState.ATTACK)
		e.enemy_logic.attack_ready_in = 0.0
	right.enemy_logic.handle_attack_state(0.016)
	left.enemy_logic.handle_attack_state(0.016)
	ck(right.enemy_logic.is_attacking and not left.enemy_logic.is_attacking,
			"an enemy on the hero's other side waits while this side swings (D770: right %s, left %s)" % [right.enemy_logic.is_attacking, left.enemy_logic.is_attacking])
	for e: Node in [right, left]:
		await _done(e)


## [10] Випад і стрибок шакала (D768, D769): бандит з середньої відстані робить ривок з ударом; шакал стрибає — влучив,
## учепився: герой стоїть, укус — лише за LATCH_BITE_AT с, тоді герой відштовхує шакала й вільний; блок і перекат крізь
## стрибок рятують; учепитись може лише один шакал.
func _lunges_and_pounce() -> void:
	print("[10] Lunges from mid range; the jackal's pounce latches, bites after a beat and is shoved off; block and roll beat it (D768, D769)")
	var logic_script: Script = load("res://SampleProject/Scripts/Gameplay/Components/EnemyLogic.gd")
	var hits := [0]
	var count := func(target: Node, _source: Node, _amount: int, _critical: bool) -> void:
		if target == hero:
			hits[0] += 1
	eb.damage_received.connect(count)
	# Бандит: герой за 180 px, поза досяжністю удару (40 px), — випад дістає
	var bandit: Node = await _spawn(BANDIT, 0.0, false)
	bandit.enemy_logic._lunge_rest = 60.0  # сам не кидається: випади тут веде тест
	# Спершу спокій, тоді герой на місце (D775: щойно приземлений герой — відкритий, і ворог кинувся б карати сам)
	bandit.enemy_logic.player = hero
	await _quiet(bandit)
	await _place(bandit, -180)
	var x0: float = bandit.global_position.x
	hits[0] = 0
	bandit.enemy_logic.perform_lunge()
	await create_timer(bandit.enemy_stats.lunge_windup + logic_script.LUNGE_TIME + 0.15).timeout
	ck(hits[0] >= 1 and x0 - bandit.global_position.x >= 100.0, "a bandit lunges %.0f px from 180 px away and lands (%d hit)" % [x0 - bandit.global_position.x, hits[0]])
	await _done(bandit)
	_heal()
	# Шакал: герой стоїть за 200 px
	var jackal: Node = await _spawn(JACKAL, 0.0, false)
	jackal.enemy_logic._lunge_rest = 60.0
	jackal.enemy_logic._lunge_rest = 60.0
	jackal.enemy_logic.player = hero
	await _quiet(jackal)
	await _place(jackal, -200)
	hits[0] = 0
	jackal.enemy_logic.perform_lunge()
	var t := 0.0
	while logic_script.latched() == null and t < 1.5:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	ck(logic_script.latched() == jackal.enemy_logic and hero.combat.is_held() and hits[0] == 0,
			"the pounce latches on: the hero is held, no damage yet (latched %s, held %s)" % [logic_script.latched() != null, hero.combat.is_held()])
	var since := 0.0
	while hits[0] == 0 and since < 1.5:
		await physics_frame
		since += 1.0 / Engine.physics_ticks_per_second
	ck(absf(since - logic_script.LATCH_BITE_AT) <= 0.1 and hits[0] == 1, "the bite lands %.2f s after the latch (beat %.2f s), one bite" % [since, logic_script.LATCH_BITE_AT])
	while hero.combat.is_held():
		await physics_frame
	await create_timer(0.3).timeout
	ck(logic_script.latched() == null and absf(jackal.global_position.x - hero.global_position.x) >= 100.0 and hero.combat.state == hero.combat.State.READY,
			"the hero shoves the jackal off (%.0f px away) and is free" % absf(jackal.global_position.x - hero.global_position.x))
	await create_timer(1.0).timeout
	_heal()
	# Блок: білий відблиск — стрибок відбито, не вчепився
	jackal.enemy_logic._lunge_rest = 60.0
	await _quiet(jackal)
	await _place(jackal, -200)
	_press(&"block")
	await create_timer(0.1).timeout
	var latched_once := [false]
	hits[0] = 0
	jackal.enemy_logic.perform_lunge()
	t = 0.0
	while t < jackal.enemy_stats.lunge_windup + logic_script.LUNGE_TIME + 0.2:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		latched_once[0] = latched_once[0] or logic_script.latched() != null
	_press(&"block", false)
	ck(not latched_once[0] and hits[0] == 0, "a block turns the pounce away (latched %s, hits %d)" % [latched_once[0], hits[0]])
	await create_timer(1.2).timeout
	# Перекат крізь стрибок: невразливий — шакал пролітає
	jackal.enemy_logic._lunge_rest = 60.0
	await _quiet(jackal)
	await _place(jackal, -200)
	latched_once[0] = false
	hero.mover.last_direction = 1
	hits[0] = 0
	jackal.enemy_logic.perform_lunge()
	t = 0.0
	var rolled := false
	while t < jackal.enemy_stats.lunge_windup + logic_script.LUNGE_TIME + 0.3:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if not rolled and t >= jackal.enemy_stats.lunge_windup - 0.05:
			rolled = true
			_tap(&"dodge")
		latched_once[0] = latched_once[0] or logic_script.latched() != null
	ck(not latched_once[0] and hits[0] == 0, "a roll through the pounce (latched %s, hits %d)" % [latched_once[0], hits[0]])
	await _done(jackal)
	_heal()
	# Двоє стрибають разом — учепився один, другий кусає з льоту
	var pair: Array[Node] = [await _spawn(JACKAL, 0.0, false), await _spawn(JACKAL, 400.0, false)]
	for j: Node in pair:
		j.enemy_logic._lunge_rest = 60.0
	for j: Node in pair:
		await _quiet(j)
	await _place(pair[0], 200)
	var holders := {}
	hits[0] = 0
	for j: Node in pair:
		j.enemy_logic.player = hero
		j.enemy_logic.perform_lunge()
	t = 0.0
	while t < 1.6:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if logic_script.latched() != null:
			holders[logic_script.latched()] = true
	ck(holders.size() == 1, "two pounce at once: one latches (%d latched), the other bites in passing (%d hits)" % [holders.size(), hits[0]])
	for j: Node in pair:
		await _done(j)
	eb.damage_received.disconnect(count)
	_heal()


## Живий AI не б'є й не кидається сам, поки випад веде тест: удари — лише ті, що тест почав.
func _quiet(enemy: Node) -> void:
	while enemy.enemy_logic.is_attacking:
		await physics_frame
	enemy.enemy_logic.attack_ready_in = 60.0
	enemy.enemy_logic._lunge_rest = 60.0


## [9] Відновлення після серії й відхід: ворог не стоїть на місці.
func _recovery_and_back_off() -> void:
	print("[9] A recovery pose after each swing, then the enemy backs off; it no longer stands still")
	var bandit: Node = await _spawn(BANDIT, 200.0)
	bandit.combo_hits = 1
	await _place(bandit, -30)
	hero.is_invulnerable = true
	var x0: float = bandit.global_position.x
	bandit.set_physics_process(true)
	bandit.enemy_logic.player = hero
	bandit.enemy_logic.change_state(bandit.enemy_logic.AIState.ATTACK)
	bandit.enemy_logic.attack_ready_in = 0.0
	while not bandit.enemy_logic.recovering:
		await physics_frame
	var t0 := Time.get_ticks_msec()
	var frozen_pose: bool = bandit.anim_player.speed_scale == 0.0
	while bandit.enemy_logic.recovering:
		await physics_frame
	var held := Time.get_ticks_msec() - t0
	ck(frozen_pose and absi(held - roundi(bandit.recovery * 1000)) <= 80, "recovery pose held %d ms (stats %.2f s), the strike frame frozen" % [held, bandit.recovery])
	ck(bandit.enemy_logic.current_state == bandit.enemy_logic.AIState.RETREAT, "then it backs off (state %d)" % bandit.enemy_logic.current_state)
	var xs: Array = []
	for i in 30:
		await create_timer(0.1).timeout
		xs.append(bandit.global_position.x)
	var furthest: float = xs.map(func(x: float) -> float: return x - x0).max()
	ck(furthest >= 50.0, "it steps back %.0f px (back_off %.0f)" % [furthest, bandit.back_off])
	ck(xs.max() - xs.min() > 20.0, "between attacks it keeps moving (x %.0f..%.0f)" % [xs.min(), xs.max()])
	hero.is_invulnerable = false
	bandit.set_physics_process(false)
	await _done(bandit)
	var tank: Node = await _spawn(TANK, 200.0)
	await _place(tank, -30)
	hero.is_invulnerable = true
	tank.set_physics_process(true)
	tank.enemy_logic.player = hero
	tank.enemy_logic.change_state(tank.enemy_logic.AIState.ATTACK)
	tank.enemy_logic.attack_ready_in = 0.0
	while not tank.enemy_logic.recovering:
		await physics_frame
	while tank.enemy_logic.is_attacking:
		await physics_frame
	# D775: після удару й tank (back_off 0) виходить з досяжності удару героя, а не стоїть перед ним
	ck(tank.enemy_logic.current_state == tank.enemy_logic.AIState.RETREAT, "the tank steps back out of the hero's reach after its swing (state %d)" % tank.enemy_logic.current_state)
	while tank.enemy_logic.current_state == tank.enemy_logic.AIState.RETREAT:
		await physics_frame
	var gap: float = absf(tank.global_position.x - hero.global_position.x)
	ck(gap > tank.enemy_logic._hero_reach(), "it stops %.0f px from him, past his reach %.0f px (D775)" % [gap, tank.enemy_logic._hero_reach()])
	hero.is_invulnerable = false
	tank.set_physics_process(false)
	await _done(tank)


## Послідовність ходів боса з одного місця: щоразу pick_move, наче хід зроблено.
func _sequence(boss: Node, dx: float, count: int) -> Array:
	boss.global_position.x = hero.global_position.x + dx
	boss.enemy_logic.last_move = {}
	boss.enemy_logic.pattern_at = 0
	var kinds: Array = []
	for i in count:
		var move: Dictionary = boss.enemy_logic.pick_move()
		boss.enemy_logic.last_move = move
		kinds.append(move.get("kind", ""))
	return kinds


## [10] Візерунки ходів: правила дистанції, останнього ходу й фази; фіксовані серії; бос рухається між ходами.
func _boss_patterns() -> void:
	print("[10] Bosses follow patterns and simple rules, not random picks")
	var brass: Node = await _spawn(BRASS, 400.0)
	hero.global_position = Vector2(arena_x, floor_y)
	await physics_frame
	var near := _sequence(brass, 50.0, 6)
	ck(near == ["combo", "slam", "combo", "slam", "combo", "slam"], "Brass at 50 px: %s (charge does not fit, combo never twice running)" % [near])
	var mid := _sequence(brass, 200.0, 6)
	ck(mid == ["slam", "charge", "slam", "charge", "slam", "charge"], "Brass at 200 px: %s" % [mid])
	ck(_sequence(brass, 200.0, 6) == mid, "the same situation gives the same moves")
	var far := _sequence(brass, 360.0, 3)
	ck(far == ["charge", "charge", "charge"], "Brass at 360 px: only the charge fits, so it repeats (%s)" % [far])
	ck(_sequence(brass, 420.0, 1) == [""], "at 420 px the charge stops short (distance 320 + melee_reach 63, B-boss): no move")
	ck(_sequence(brass, 900.0, 1) == [""], "nothing in range: no move (it walks in instead)")
	brass.global_position.x = hero.global_position.x + 400.0
	# Фіксована серія: 2 удари, у другій фазі — 3
	for phase in [1, 2]:
		if phase == 2:
			brass.take_damage(brass.current_health - brass.Max_Health / 2 + 1)
			await physics_frame
		brass.moves = brass.moves.filter(func(m: Dictionary) -> bool: return m.kind == "combo")
		await _place(brass, -55)
		var swings: Array = []
		var on_tell := func(e: Node, kind: StringName) -> void:
			if e == brass: swings.append(String(kind))
		eb.enemy_tell_shown.connect(on_tell)
		hero.is_invulnerable = true  # удар не відкидає героя з досяжності серії
		while brass.enemy_logic.is_attacking:
			await physics_frame
		for run in 2:
			await _place(brass, -55)
			brass.enemy_logic.last_move = {}
			brass.enemy_logic.perform_attack()
			while brass.enemy_logic.is_attacking:
				await physics_frame
			await create_timer(0.2).timeout
		eb.enemy_tell_shown.disconnect(on_tell)
		hero.is_invulnerable = false
		var want: Array = ["parry", "dodge", "parry", "dodge"] if phase == 1 else ["parry", "parry", "dodge", "parry", "parry", "dodge"]
		ck(swings == want, "phase %d: the combo is fixed, twice the same %s" % [phase, swings])
		brass.moves = load(BRASS).instantiate().moves
	var p2 := _sequence(brass, 200.0, 6)
	ck(p2 == _sequence(brass, 200.0, 6) and not p2.has("") and range(1, p2.size()).all(func(i: int) -> bool: return p2[i] != p2[i - 1]),
			"phase 2 has its own pattern, no move twice running (%s)" % [p2])
	# Між ходами бос іде до своєї відстані
	await _place(brass, -300)
	brass.enemy_logic.player = hero
	brass.enemy_logic.change_state(brass.enemy_logic.AIState.ATTACK)
	brass.enemy_logic.attack_ready_in = 5.0
	var x0: float = brass.global_position.x
	brass.set_physics_process(true)
	await create_timer(1.0).timeout
	brass.set_physics_process(false)
	ck(x0 - brass.global_position.x > 30.0 and not brass.enemy_logic.is_attacking, "between moves the Brass walks towards its range (%.0f px)" % (x0 - brass.global_position.x))
	brass.queue_free()
	var djinn: Node = await _spawn(DJINN, 300.0)
	await _place(djinn, -80)
	djinn.enemy_logic.player = hero
	djinn.enemy_logic.change_state(djinn.enemy_logic.AIState.ATTACK)
	djinn.enemy_logic.attack_ready_in = 5.0
	x0 = djinn.global_position.x
	djinn.set_physics_process(true)
	await create_timer(1.0).timeout
	djinn.set_physics_process(false)
	ck(djinn.global_position.x - x0 > 30.0, "the djinn backs off towards its casting range (%.0f px)" % (djinn.global_position.x - x0))
	var cast := _sequence(djinn, 300.0, 5)
	ck(cast == ["fireball", "pillar", "fireball", "pillar", "fireball"], "the djinn at 300 px: %s" % [cast])
	djinn.queue_free()
