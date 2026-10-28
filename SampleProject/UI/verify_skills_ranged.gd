extends SceneTree

## Навички дальнього бою й зон (v2 зріз 4, D-sv2r1, D-sv2r2) у справжній грі, на DesertRoad, по справжніх ворогах:
##   кидок (Holy Javelin — перший на лінії, Lightspear — прошиває всіх) і зона на землі (Hallowed Circle — шкода й
##   лікування щосекунди, Hellfire Stomp — удар і калюжа). SP — за кидок чи зону, влучання SP не дають; удар по героєві
##   на замаху зриває каст (D259): SP списано, нічого не вилетіло й не лягло.
##   godot --headless --path . --script res://SampleProject/UI/verify_skills_ranged.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

var game: Node
var player: Node2D
var sm: Node
var db: Node
var R
var State

## Ворог default_enemy на підлозі в [param dx] px від героя; стоїть (без AI), HP вистачить на весь тест.
func _enemy(dx: float) -> Node2D:
	var enemy: Node2D = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	game.map.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(dx, -10)
	enemy.Max_Health = 100000
	enemy.current_health = 100000
	return enemy

## Вороги стають на підлогу, потім стоять без AI.
func _settle(enemies: Array) -> void:
	for i in 30:
		await physics_frame
	for e in enemies:
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
	for i in 4:
		await physics_frame

func _clear(enemies: Array) -> void:
	for e in enemies:
		e.queue_free()
	await physics_frame

## Герой стоїть на підлозі в [param x], дивиться праворуч, SP повні.
func _reset_hero(x: float) -> void:
	player.global_position.x = x
	player.velocity = Vector2.ZERO
	player.last_direction = 1
	player.set_invulnerable(false)
	for i in 20:
		await physics_frame
		if player.is_on_floor():
			break
	sm.restore_sp(1000)

## Каст і очікування, доки герой знову вільний; повертає Result.
func _cast(skill_id: String) -> int:
	var result: int = sm.cast_skill(skill_id)
	for i in 300:
		if player.combat.state == State.READY:
			break
		await physics_frame
	return result

## Вузли мапи зі скриптом [param file] (снаряди SkillProjectile.gd, зони SkillZone.gd).
func _spawned(file: String) -> Array:
	return game.map.get_children().filter(func(n: Node) -> bool:
			return n.get_script() != null and n.get_script().resource_path.ends_with(file))

## Чекає, доки зникнуть усі снаряди й зони (не довше [param seconds] с).
func _wait_gone(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not (_spawned("SkillProjectile.gd").is_empty() and _spawned("SkillZone.gd").is_empty()):
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second

func _hurt(enemy: Node) -> int:
	return enemy.Max_Health - enemy.current_health

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain(sl.get_dialogue_manager())
	for e in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		e.queue_free()  # вороги кімнати — далі лише наші
	player = game.player
	sm = sl.get_skill_manager()
	sm.awaken_skills()  # D815: DesertRoad comes after the Canyon meditation
	R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	State = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State
	db = root.get_node("SkillDatabase")
	sm.set_max_sp(1000)
	for id in ["holy_javelin", "lightspear", "hallowed_circle", "hellfire_stomp"]:
		sl.get_game_manager().player_state.unlocked_skills.append(id)
	await _reset_hero(player.global_position.x)
	var home: float = player.global_position.x
	ck(player.is_on_floor(), "the hero stands on the DesertRoad floor (x %.0f)" % home)

	print("[1] Holy Javelin flies and hits an enemy far out of sword reach; SP for the throw, none back for the hit")
	var near := _enemy(380.0)
	await _settle([near])
	ck(sm.get_current_sp() == 1000 and not near in load("res://SampleProject/Scripts/Combat/Systems/SkillTargeting.gd").enemies_in_front(player),
			"the enemy is out of strike reach (%.0f px)" % (near.global_position.x - player.global_position.x))
	ck(await _cast("holy_javelin") == R.OK, "cast starts with nobody in front")
	ck(_spawned("SkillProjectile.gd").size() == 1 or _hurt(near) > 0, "a spear is in flight after the release")
	await _wait_gone(1.5)
	var javelin: int = sm.skill_damage("holy_javelin")
	ck(_hurt(near) == javelin, "hit for the skill's damage at %.0f px (%d of %d)" % [near.global_position.x - player.global_position.x, _hurt(near), javelin])
	ck(sm.get_current_sp() == 1000 - 9, "9 SP paid, no SP from the hit (%d)" % sm.get_current_sp())
	ck(absf(player.global_position.x - home) < 2.0, "the hero did not move")
	await _clear([near])

	print("[2] Holy Javelin stops at the first enemy; an enemy past its range is not hit")
	await _reset_hero(home)
	var first := _enemy(260.0)
	var second := _enemy(330.0)
	await _settle([first, second])
	ck(await _cast("holy_javelin") == R.OK, "cast")
	await _wait_gone(1.5)
	ck(_hurt(first) > 0 and _hurt(second) == 0, "only the first is hit (%d, %d)" % [_hurt(first), _hurt(second)])
	await _clear([first, second])
	await _reset_hero(home)
	var far := _enemy(700.0)
	await _settle([far])
	ck(await _cast("holy_javelin") == R.OK, "cast")
	await _wait_gone(1.5)
	ck(_hurt(far) == 0 and sm.get_current_sp() == 1000 - 9, "past 520 px: no hit, the miss still costs 9 SP (%d)" % _hurt(far))
	await _clear([far])

	print("[3] Lightspear pierces every enemy on its line, up to 600 px")
	await _reset_hero(home)
	first = _enemy(200.0)
	second = _enemy(420.0)
	far = _enemy(800.0)
	await _settle([first, second, far])
	ck(await _cast("lightspear") == R.OK, "cast")
	await _wait_gone(1.5)
	var spear: int = sm.skill_damage("lightspear")
	ck(_hurt(first) == spear and _hurt(second) == spear, "both on the line hit once (%d, %d of %d)" % [_hurt(first), _hurt(second), spear])
	ck(_hurt(far) == 0, "the one at 800 px is not (%d)" % _hurt(far))
	await _clear([first, second, far])

	print("[4] Hallowed Circle: enemies inside take its dps every second for its time, outside nothing; the hero heals")
	await _reset_hero(home)
	var inside := _enemy(90.0)
	var outside := _enemy(320.0)
	await _settle([inside, outside])
	player.current_health = player.Max_Health - 40
	var hp_before: int = player.current_health
	var dps: int = sm.zone_power("hallowed_circle", 6)
	var heal: int = sm.zone_power("hallowed_circle", 3)
	ck(await _cast("hallowed_circle") == R.OK, "cast with nobody in front")
	ck(_spawned("SkillZone.gd").size() == 1, "a zone lies on the ground")
	ck(sm.get_current_sp() == 1000 - 12, "12 SP paid (%d)" % sm.get_current_sp())
	await create_timer(3.2).timeout
	ck(_hurt(inside) == 3 * dps, "after 3 s: 3 ticks of %d (%d)" % [dps, _hurt(inside)])
	await _wait_gone(5.0)
	ck(_hurt(inside) == 6 * dps and _hurt(outside) == 0, "6 s: inside %d (6 × %d), outside %d" % [_hurt(inside), dps, _hurt(outside)])
	ck(player.current_health - hp_before == 6 * heal, "the hero in the circle healed %d (6 × %d)" % [player.current_health - hp_before, heal])
	await create_timer(1.5).timeout
	ck(_hurt(inside) == 6 * dps, "gone after its time: no more damage (%d)" % _hurt(inside))
	await _clear([inside, outside])

	print("[5] Hellfire Stomp: the stomp hits everyone in the pool, the pool burns for 5 s; outside nothing")
	await _reset_hero(home)
	inside = _enemy(60.0)
	var behind := _enemy(-60.0)
	outside = _enemy(260.0)
	await _settle([inside, behind, outside])
	var stomp: int = sm.skill_damage("hellfire_stomp")
	var pool: int = sm.zone_power("hellfire_stomp", 7)
	ck(await _cast("hellfire_stomp") == R.OK, "cast")
	ck(_hurt(inside) == stomp and _hurt(behind) == stomp, "the stomp hits both sides (%d, %d of %d)" % [_hurt(inside), _hurt(behind), stomp])
	await _wait_gone(6.0)
	ck(_hurt(inside) == stomp + 5 * pool and _hurt(outside) == 0, "pool: %d (= %d + 5 × %d), outside %d" % [_hurt(inside), stomp, pool, _hurt(outside)])
	await _clear([inside, behind, outside])

	print("[6] A blow during the wind-up interrupts: SP paid, nothing thrown or laid (D259)")
	for id in ["holy_javelin", "hallowed_circle"]:
		await _reset_hero(home)
		ck(sm.cast_skill(id) == R.OK and player.combat.state == State.CAST_WINDUP, "%s: winding up" % id)
		player.combat.stagger(0.3, player.global_position.x + 10.0)
		for i in 60:
			await physics_frame
		var cost: int = db.get_skill(id).sp_cost
		ck(_spawned("SkillProjectile.gd").is_empty() and _spawned("SkillZone.gd").is_empty() and sm.get_current_sp() == 1000 - cost
				and player.combat.casting_skill == "", "%s: nothing spawned, %d SP paid (%d)" % [id, cost, sm.get_current_sp()])

	print("[7] A zone only from the ground; a throw from the air works")
	await _reset_hero(home)
	player.velocity.y = -400.0
	for i in 4:
		await physics_frame
	ck(not player.is_on_floor() and sm.cast_skill("hallowed_circle") == R.BUSY, "Hallowed Circle in the air → BUSY")
	ck(sm.cast_skill("holy_javelin") == R.OK, "Holy Javelin in the air starts")
	for i in 120:
		if player.combat.state == State.READY:
			break
		await physics_frame
	await _wait_gone(1.5)

	print("[8] Data: the 4 are learnable now, with real fields instead of `draft`")
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/skills.json")).skills
	for id in ["holy_javelin", "lightspear", "hallowed_circle", "hellfire_stomp"]:
		var d = db.get_skill(id)
		var row: Dictionary = raw.filter(func(e: Dictionary) -> bool: return e.id == id)[0]
		ck(not d.planned and not row.has("draft") and (d.throws() or d.leaves_zone()) and d.vfx.ends_with("RangedSkill.tscn")
				and ResourceLoader.exists(d.vfx) and d.synergies.size() in [1, 2], "%s: built (throws %s, zone %s)" % [id, d.throws(), d.leaves_zone()])
	ck(db.get_skill("holy_javelin").projectile_range == 520.0 and db.get_skill("lightspear").projectile_pierce
			and db.get_skill("hallowed_circle").zone_heal == 3 and db.get_skill("hellfire_stomp").zone_time == 5.0, "the draft numbers became fields")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
