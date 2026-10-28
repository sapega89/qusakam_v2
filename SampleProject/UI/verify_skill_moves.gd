extends SceneTree

## Навички руху (v2 зріз 3, D812) у справжній грі, на DesertRoad, по справжніх ворогах:
##   ривок (Dash Strike, Shield Charge, Blood Rush, Wind Step) і стрибок з ударом (Heaven's Anvil, Dune Quake).
## Тіла зупиняють (D443), за спину ворога ніхто не потрапляє, промах коштує SP, удар по героєві зриває рух.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_moves.gd

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
var R
var State
var bus: Node
## Що бачили, поки йшла навичка: пози тіла, чи герой був у повітрі, чи був невразливий.
var poses: Array[String] = []
var flew := false
var invulnerable_seen := false

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

## Каст навички й очікування, доки герой знову вільний; записує пози, політ і невразливість.
func _cast(skill_id: String) -> int:
	poses.clear()
	flew = false
	invulnerable_seen = false
	var result: int = sm.cast_skill(skill_id)
	for i in 300:
		if player.combat.state == State.READY:
			break
		if poses.is_empty() or poses[-1] != String(player.animation):
			poses.append(String(player.animation))
		flew = flew or not player.is_on_floor()
		invulnerable_seen = invulnerable_seen or (player.is_invulnerable and player.combat.state == State.CAST_MOVE)
		await physics_frame
	return result

## Струмінь крові Blood Rush (MoveSkill.tscn → Drain): видно — відстань його правого кінця від [param target], px; ні — INF.
func _drain_gap(target: Node) -> float:
	for child in player.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("MoveSkillFX.gd"):
			var drain: AnimatedSprite2D = child.get_node("Drain")
			if drain.visible:
				return drain.to_global(Vector2(drain.sprite_frames.get_frame_texture(&"default", 0).get_width(), 0)).distance_to(target.global_position)
	return INF

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
	bus = root.get_node("EventBus")
	var db: Node = root.get_node("SkillDatabase")
	sm.set_max_sp(1000)
	for id in ["dash_strike", "shield_charge", "heavens_anvil", "blood_rush", "wind_step", "dune_quake"]:
		sl.get_game_manager().player_state.unlocked_skills.append(id)
	await _reset_hero(player.global_position.x)
	var home: float = player.global_position.x
	ck(player.is_on_floor(), "the hero stands on the DesertRoad floor (x %.0f)" % home)

	print("[1] Dash Strike with nobody near: the hero dashes its distance, the whiff costs SP (D812)")
	var sp: int = sm.get_current_sp()
	var failed: Array = []
	var on_fail := func(id: String, reason: int) -> void: failed.append([id, reason])
	bus.skill_failed.connect(on_fail)
	ck(await _cast("dash_strike") == R.OK, "cast starts without an enemy in front (a gap closer)")
	var moved: float = player.global_position.x - home
	ck(absf(moved - 180.0) <= 12.0, "dashed 180 px forward (%.1f)" % moved)
	ck(poses.slice(0, 3) == ["LungeCutWindup", "LungeCutMove", "LungeCutStrike"], "poses: LungeCutWindup → LungeCutMove → LungeCutStrike (H3) %s" % [poses])
	ck(sm.get_current_sp() == sp - 5 and failed == [["dash_strike", R.NO_TARGET]], "whiff: 5 SP paid, NO_TARGET (%d → %d, %s)" % [sp, sm.get_current_sp(), failed])
	bus.skill_failed.disconnect(on_fail)

	print("[2] Dash Strike at two enemies in a row: stops at the first, cuts only it, never gets behind (D443)")
	await _reset_hero(home)
	var first := _enemy(150.0)
	var second := _enemy(162.0)  # теж у досяжності удару, але ріже лише першого
	await _settle([first, second])
	ck(await _cast("dash_strike") == R.OK, "cast")
	ck(_hurt(first) > 0 and _hurt(second) == 0, "only the first enemy is cut (%d, %d)" % [_hurt(first), _hurt(second)])
	ck(player.body_rect().end.x <= first.body_rect().position.x + 1.0, "the hero stops in front of it (hero right %.1f, enemy left %.1f)"
			% [player.body_rect().end.x, first.body_rect().position.x])
	ck(player.global_position.x - home > 20.0, "and did dash toward it (%.1f px)" % (player.global_position.x - home))
	await _clear([first, second])

	print("[3] Dash Strike from point blank: no move through the body")
	await _reset_hero(home)
	first = _enemy(45.0)
	await _settle([first])
	var start: float = player.global_position.x
	ck(await _cast("dash_strike") == R.OK and _hurt(first) > 0, "hit at once (%d)" % _hurt(first))
	ck(player.global_position.x < first.global_position.x and player.global_position.x - start < 10.0,
			"the hero stays in front (%.1f → %.1f, enemy %.1f)" % [start, player.global_position.x, first.global_position.x])
	await _clear([first])

	print("[4] Shield Charge: the Run loop, hits everyone in front and knocks them back; no shield visual yet")
	await _reset_hero(home)
	first = _enemy(170.0)
	second = _enemy(182.0)  # вороги проходять одне крізь одного — обидва в досяжності удару
	await _settle([first, second])
	ck(await _cast("shield_charge") == R.OK, "cast")
	ck(poses.slice(0, 3) == ["ShieldChargeWindup", "ShieldChargeMove", "ShieldChargeStrike"], "poses: ShieldChargeWindup → ShieldChargeMove → ShieldChargeStrike (H3) %s" % [poses])
	ck(_hurt(first) > 0 and _hurt(second) > 0, "both enemies in front are hit (%d, %d; hero %.0f, enemies %.0f, %.0f)"
			% [_hurt(first), _hurt(second), player.global_position.x, first.global_position.x, second.global_position.x])
	ck(first.enemy_logic.knockback_left > 0.0 and first.enemy_logic.knockback_speed > 0.0, "and knocked back, away from the hero (%.0f px/s)" % first.enemy_logic.knockback_speed)
	ck(player.body_rect().end.x <= first.body_rect().position.x + 1.0, "the charge stops at the first body")
	await _clear([first, second])

	print("[5] Blood Rush: the hit drinks 30 % of its damage")
	await _reset_hero(home)
	first = _enemy(170.0)
	await _settle([first])
	var deficit: int = player.Max_Health / 2
	player.current_health = player.Max_Health - deficit
	var damage: int = sm.skill_damage("blood_rush")
	var drains: Array = []
	var on_drain := func(_source: Node, target: Node, _amount: int) -> void:
		(func() -> void: drains.append(_drain_gap(target))).call_deferred()
	root.get_node("EventBus").skill_drained.connect(on_drain)
	ck(await _cast("blood_rush") == R.OK and _hurt(first) > 0, "cast and hit (%d)" % _hurt(first))
	root.get_node("EventBus").skill_drained.disconnect(on_drain)
	ck(drains.size() == 1 and drains[0] <= 2.0, "the drain wisp (H3) runs from the target to the hero, its far end %s px from the target" % [drains])
	ck(player.current_health == player.Max_Health - deficit + roundi(damage * 0.3), "healed %d of %d damage" % [player.current_health - (player.Max_Health - deficit), damage])
	player.current_health = player.Max_Health
	await _clear([first])

	print("[6] Wind Step: invulnerable during the step, cuts the first enemy")
	await _reset_hero(home)
	first = _enemy(150.0)
	await _settle([first])
	ck(await _cast("wind_step") == R.OK and _hurt(first) > 0 and invulnerable_seen, "hit (%d), invulnerable while stepping (%s)" % [_hurt(first), invulnerable_seen])
	await _clear([first])

	print("[7] Heaven's Anvil: leaps, lands in front of the enemy (not behind), the slam hits both sides")
	await _reset_hero(home)
	first = _enemy(150.0)
	var behind := _enemy(-30.0)  # біля старту: після стрибка — позаду героя, у досяжності стовпа
	await _settle([first, behind])
	start = player.global_position.x
	ck(await _cast("heavens_anvil") == R.OK, "cast")
	ck(flew and poses == ["LeapSlamWindup", "LeapSlamMove", "LeapSlamStrike"], "flies: LeapSlamWindup → LeapSlamMove (held up and down) → LeapSlamStrike (H3) %s" % [poses])
	ck(player.body_rect().end.x <= first.body_rect().position.x + 1.0 and player.global_position.x > start + 20.0,
			"landed in front of the enemy ahead (%.1f → %.1f, enemy left %.1f)" % [start, player.global_position.x, first.body_rect().position.x])
	ck(_hurt(first) > 0 and _hurt(behind) > 0, "pillars on both sides hit both (%d, %d; hero %.0f, enemies %.0f, %.0f)"
			% [_hurt(first), _hurt(behind), player.global_position.x, first.global_position.x, behind.global_position.x])
	await _clear([first, behind])

	print("[8] Heaven's Anvil with nobody ahead: the full leap (200 px)")
	await _reset_hero(home)
	ck(await _cast("heavens_anvil") == R.OK, "cast")
	ck(absf(player.global_position.x - home - 200.0) <= 15.0, "leapt %.1f px" % (player.global_position.x - home))

	print("[9] Dune Quake: the sand wave reaches 240 px both ways and knocks down (stun until slice 6's state)")
	await _reset_hero(home)
	first = _enemy(140.0)
	behind = _enemy(-60.0)
	var far := _enemy(-420.0)
	await _settle([first, behind, far])
	ck(await _cast("dune_quake") == R.OK, "cast")
	ck(poses == ["LeapSlamWindup", "LeapSlamMove", "LeapSlamStrike"], "the leap-slam poses (H3) %s" % [poses])
	ck(_hurt(first) > 0 and _hurt(behind) > 0 and _hurt(far) == 0, "both near enemies hit, the far one not (%d, %d, %d; hero %.0f, enemies %.0f, %.0f, %.0f)"
			% [_hurt(first), _hurt(behind), _hurt(far), player.global_position.x, first.global_position.x, behind.global_position.x, far.global_position.x])
	ck(first.enemy_logic.stun_left > 0.5 and behind.enemy_logic.stun_left > 0.5, "knocked down for 1.2 s (%.2f)" % first.enemy_logic.stun_left)
	await _clear([first, behind, far])

	print("[10] A blow during the dash interrupts it: SP paid, no hit (D259)")
	await _reset_hero(home)
	first = _enemy(200.0)
	await _settle([first])
	sp = sm.get_current_sp()
	ck(sm.cast_skill("dash_strike") == R.OK, "cast")
	for i in 60:
		if player.combat.state == State.CAST_MOVE:
			break
		await physics_frame
	ck(player.combat.state == State.CAST_MOVE, "the hero is moving")
	player.combat.stagger(0.3, player.global_position.x + 10.0)
	for i in 60:
		await physics_frame
	ck(_hurt(first) == 0 and sm.get_current_sp() == sp - 5 and player.combat.casting_skill == "", "no hit, 5 SP paid (%d)" % _hurt(first))
	await _clear([first])

	print("[11] Not from the air; a plain skill still needs an enemy in front")
	await _reset_hero(home)
	player.velocity.y = -400.0
	for i in 4:
		await physics_frame
	ck(not player.is_on_floor() and sm.cast_skill("dash_strike") == R.BUSY, "in the air → BUSY")
	await _reset_hero(home)
	sl.get_game_manager().player_state.unlocked_skills.append("electric_strike")
	ck(sm.cast_skill("electric_strike") != R.OK and player.combat.state == State.READY, "Electric Strike with nobody in front does not start")

	print("[12] Data: the 6 are learnable now, with the effect scene")
	var all_ok := true
	for id in ["dash_strike", "shield_charge", "heavens_anvil", "blood_rush", "wind_step", "dune_quake"]:
		var d = db.get_skill(id)
		if d.planned or not d.moves() or not ResourceLoader.exists(d.vfx) or d.move_hits == "":
			all_ok = false
			print("    ", id)
	ck(all_ok, "not planned, a move block, MoveSkill.tscn")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
