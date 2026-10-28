extends SceneTree

## Навички контролю й добивання (v2 зріз 6б, D-sv2cb1) у справжній грі, на DesertRoad, по справжніх ворогах:
##   Chain of Night тягне й тримає, Sand Veil засліплює, Dread Howl збиває й лякає, Radiant Flare оглушає навколо,
##   Night Reaper б'є довгим серпом, Soul Harvest добиває лише під порогом чи з розбитим щитом (D495) і повертає SP.
##   godot --headless --path . --script res://SampleProject/UI/verify_skills_control_b.gd

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

const SKILLS := ["chain_of_night", "sand_veil", "dread_howl", "radiant_flare", "night_reaper", "soul_harvest"]

var game: Node
var player: Node2D
var sm: Node
var db: Node
var gm: Node
var R
var State

## Ворог [param scene] на підлозі в [param dx] px від героя, HP вистачить на весь тест. [param idle] — без погоні:
## AI живе (відкидання, збій, страх), але героя не помічає й не б'є.
func _enemy(dx: float, idle: bool = true, scene: String = "default_enemy", stats: String = "melee") -> Node2D:
	var enemy: Node2D = load("res://SampleProject/Scenes/Characters/Enemies/%s.tscn" % scene).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % stats)
	game.map.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(dx, -10)
	enemy.Max_Health = 100000
	enemy.current_health = 100000
	if idle:
		enemy.detection_area.monitoring = false
		enemy.enemy_logic.detection_range = 0.0
	return enemy

## Вороги стають на підлогу; дім — там, де стали (IDLE не тягне їх назад).
func _settle(enemies: Array) -> void:
	for i in 30:
		await physics_frame
	for e in enemies:
		e.enemy_logic.home_position = e.global_position

func _clear(enemies: Array) -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	await physics_frame
	await physics_frame

## Герой стоїть у [param x], дивиться праворуч, SP повні, клятва навички [param skill_id].
func _reset_hero(x: float, skill_id: String) -> void:
	player.global_position.x = x
	player.velocity = Vector2.ZERO
	player.last_direction = 1
	player.mover.last_direction = 1
	player.current_health = player.Max_Health
	for i in 20:
		await physics_frame
		if player.is_on_floor():
			break
	gm.player_state["oath"] = db.get_skill(skill_id).oath
	sm.restore_sp(1000)

## Каст і очікування, доки герой знову вільний.
func _cast(skill_id: String) -> int:
	var result: int = sm.cast_skill(skill_id)
	for i in 300:
		if player.combat.state == State.READY:
			break
		await physics_frame
	return result

func _gap(enemy: Node2D) -> float:
	return absf(enemy.global_position.x - player.global_position.x)

func _hurt(enemy: Node) -> int:
	return enemy.Max_Health - enemy.current_health

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

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
	db = root.get_node("SkillDatabase")
	gm = sl.get_game_manager()
	R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	State = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State
	sm.set_max_sp(1000)
	for id in SKILLS:
		gm.player_state.unlocked_skills.append(id)
	var home: float = player.global_position.x
	await _reset_hero(home, "chain_of_night")
	ck(player.is_on_floor(), "the hero stands on the DesertRoad floor (x %.0f)" % home)

	print("[1] Data: the 6 skills are built, their draft numbers are real keys")
	for id in SKILLS:
		var d: SkillDefinition = db.get_skill(id)
		ck(not d.planned and d.vfx.get_file() == "ControlSkill.tscn" and d.release_pose != "", "%s: built, ControlSkill.tscn, cast %s" % [id, d.release_pose])
	var chain: SkillDefinition = db.get_skill("chain_of_night")
	var veil: SkillDefinition = db.get_skill("sand_veil")
	var howl: SkillDefinition = db.get_skill("dread_howl")
	var flare: SkillDefinition = db.get_skill("radiant_flare")
	var reaper: SkillDefinition = db.get_skill("night_reaper")
	var harvest: SkillDefinition = db.get_skill("soul_harvest")
	ck(chain.area_hits == "first" and chain.area_reach == 420.0 and chain.pull_hold > 0.0, "Chain of Night: the nearest enemy within 420 px, held %.1f s" % chain.pull_hold)
	ck(veil.area_hits == "front" and veil.area_reach == 180.0 and veil.blind_time == 3.0 and veil.blind_miss == 0.6, "Sand Veil: 180 px ahead, blind 3 s, 60 % misses")
	ck(howl.area_hits == "around" and howl.area_reach == 220.0 and howl.fear_time == 2.0 and howl.fear_flinch == 0.4, "Dread Howl: 220 px around, fear 2 s, flinch 0.4 s")
	ck(flare.area_hits == "around" and flare.area_reach == 200.0 and flare.stun == 1.2, "Radiant Flare: 200 px around, stun 1.2 s")
	ck(reaper.area_hits == "front" and reaper.area_reach == 260.0 and reaper.burn_dps > 0, "Night Reaper: 260 px ahead, burns")
	ck(harvest.execute_below == 0.2 and harvest.execute_refund == 10, "Soul Harvest: executes at 20 % HP, 10 SP back")

	print("[2] Chain of Night: pulls the nearest enemy ahead to the hero and holds it for its time")
	await _reset_hero(home, "chain_of_night")
	var near: Node2D = _enemy(300.0)
	var far: Node2D = _enemy(380.0)
	await _settle([near, far])
	var sp: int = sm.get_current_sp()
	var gap_before := _gap(near)
	ck(await _cast("chain_of_night") == R.OK, "cast starts with the enemy %.0f px away, beyond strike reach" % gap_before)
	ck(sm.get_current_sp() == sp - sm.sp_cost(chain), "SP paid (%d → %d)" % [sp, sm.get_current_sp()])
	for i in 20: await physics_frame
	var pulled := _gap(near)
	ck(pulled < 90.0 and _hurt(near) > 0, "the nearest enemy is pulled to the hero (%.0f → %.0f px) and cut (%d)" % [gap_before, pulled, _hurt(near)])
	ck(_hurt(far) == 0 and absf(_gap(far) - 380.0) < 12.0, "the one behind it is not touched")
	var held := near.global_position.x
	var hold: float = chain.pull_hold * sm.control_factor("chain_of_night")
	ck(near.enemy_logic.stun_left > hold - 0.6, "held: staggered %.2f s of %.2f" % [near.enemy_logic.stun_left, hold])
	near.enemy_logic.detection_range = 300.0  # держить і того, хто вже б'ється
	await _wait(hold - 0.5)
	ck(absf(near.global_position.x - held) < 2.0 and not near.enemy_logic.is_attacking, "it stands held for its time (moved %.1f px)" % absf(near.global_position.x - held))
	await _wait(0.8)
	ck(near.enemy_logic.stun_left <= 0.0, "the hold ends after its time")
	await _clear([near, far])
	await _reset_hero(home, "chain_of_night")
	var out_of_reach: Node2D = _enemy(520.0)
	await _settle([out_of_reach])
	sp = sm.get_current_sp()
	ck(sm.cast_skill("chain_of_night") == R.NO_TARGET and sm.get_current_sp() == sp, "nobody within 420 px: no cast, no SP")
	await _clear([out_of_reach])

	print("[3] Sand Veil: enemies ahead lose the hero; those behind do not")
	await _reset_hero(home, "sand_veil")
	var chaser: Node2D = _enemy(170.0, false)
	var behind: Node2D = _enemy(-170.0, false)
	await _settle([chaser, behind])
	chaser.enemy_logic.max_lost_time = 99.0  # не йде додому, поки сліпий: видно саме втрату героя
	chaser.enemy_logic.change_state(chaser.enemy_logic.AIState.CHASE)
	await physics_frame
	sp = sm.get_current_sp()
	ck(await _cast("sand_veil") == R.OK, "cast with an enemy ahead")
	ck(sm.get_current_sp() == sp - sm.sp_cost(veil), "SP paid (%d → %d)" % [sp, sm.get_current_sp()])
	ck(chaser.enemy_logic.blind_left > 2.0 and behind.enemy_logic.blind_left == 0.0, "the one ahead is blind (%.1f s), the one behind is not" % chaser.enemy_logic.blind_left)
	var blind_gap := _gap(chaser)
	ck(blind_gap > 100.0 and not chaser.enemy_logic.can_notice(player), "the blind one does not see the hero %.0f px away" % blind_gap)
	await _wait(1.2)
	ck(_gap(chaser) >= blind_gap - 8.0, "it does not come for him (%.0f → %.0f px)" % [blind_gap, _gap(chaser)])
	ck(_gap(behind) < 120.0, "the one behind still comes for him (%.0f px)" % _gap(behind))
	chaser.enemy_logic.blind_miss = 1.0
	chaser.start_attack(-1)
	ck(not chaser.hitbox_damage.is_active, "a blind swing misses (miss chance 1.0: the hitbox deals nothing)")
	chaser.end_attack()
	chaser.enemy_logic.blind_left = 0.0
	ck(not chaser.enemy_logic.blind_misses() and chaser.enemy_logic.can_notice(player), "the veil ends: it sees the hero again")
	await _clear([chaser, behind])

	print("[4] Dread Howl: everyone in range staggers; the weak flee, the elite only flinch")
	await _reset_hero(home, "dread_howl")
	var weak: Node2D = _enemy(110.0)
	var elite: Node2D = _enemy(-110.0)
	elite.elite = true
	var outside: Node2D = _enemy(420.0)
	await _settle([weak, elite, outside])
	sp = sm.get_current_sp()
	ck(await _cast("dread_howl") == R.OK, "cast with enemies around")
	ck(sm.get_current_sp() == sp - sm.sp_cost(howl), "SP paid (%d → %d)" % [sp, sm.get_current_sp()])
	ck(weak.enemy_logic.stun_left > 0.0 and elite.enemy_logic.stun_left > 0.0, "both in range stagger (%.2f, %.2f s)" % [weak.enemy_logic.stun_left, elite.enemy_logic.stun_left])
	ck(outside.enemy_logic.stun_left == 0.0 and outside.enemy_logic.fear_left == 0.0, "the one 420 px away is untouched")
	ck(weak.enemy_logic.fear_left > 1.5 and elite.enemy_logic.fear_left == 0.0, "the weak one is afraid (%.1f s), the elite is not" % weak.enemy_logic.fear_left)
	var weak_gap := _gap(weak)
	var elite_x := elite.global_position.x
	await _wait(1.2)
	ck(_gap(weak) > weak_gap + 40.0, "the weak one flees (%.0f → %.0f px)" % [weak_gap, _gap(weak)])
	ck(absf(elite.global_position.x - elite_x) < 40.0, "the elite does not run (moved %.0f px)" % absf(elite.global_position.x - elite_x))
	await _clear([weak, elite, outside])
	await _reset_hero(home, "dread_howl")
	sp = sm.get_current_sp()
	ck(sm.cast_skill("dread_howl") == R.NO_TARGET and sm.get_current_sp() == sp, "nobody around: no cast, no SP")

	print("[5] Radiant Flare: hits and stuns everyone around, both sides")
	await _reset_hero(home, "radiant_flare")
	var front: Node2D = _enemy(90.0)
	var back: Node2D = _enemy(-90.0)
	var away: Node2D = _enemy(420.0)
	await _settle([front, back, away])
	sp = sm.get_current_sp()
	ck(await _cast("radiant_flare") == R.OK, "cast")
	ck(sm.get_current_sp() == sp - sm.sp_cost(flare), "SP paid")
	ck(_hurt(front) > 0 and _hurt(back) > 0 and front.enemy_logic.stun_left > 0.8 and back.enemy_logic.stun_left > 0.8,
			"front and back are hit (%d, %d) and stunned" % [_hurt(front), _hurt(back)])
	ck(_hurt(away) == 0 and away.enemy_logic.stun_left == 0.0, "the one 420 px away is untouched")
	await _clear([front, back, away])

	print("[6] Night Reaper: a long crescent ahead, burning")
	await _reset_hero(home, "night_reaper")
	var close: Node2D = _enemy(60.0)
	var long: Node2D = _enemy(240.0)
	var rear: Node2D = _enemy(-80.0)
	await _settle([close, long, rear])
	ck(await _cast("night_reaper") == R.OK, "cast")
	ck(_hurt(close) > 0 and _hurt(long) > 0 and close.burn_left > 0.0 and long.burn_left > 0.0,
			"the near one and the one 240 px ahead are hit and burn (%d, %d)" % [_hurt(close), _hurt(long)])
	ck(_hurt(rear) == 0, "the one behind is not")
	await _clear([close, long, rear])

	print("[7] Soul Harvest: kills only below its threshold or with a broken guard; SP back for a kill")
	var xp_got: Array[int] = []
	sl.get_xp_manager().xp_gained.connect(func(amount: int, _total: int) -> void: xp_got.append(amount))
	await _reset_hero(home, "soul_harvest")
	var healthy: Node2D = _enemy(60.0)
	healthy.current_health = 25000  # 25 %: above the 20 % threshold
	await _settle([healthy])
	sp = sm.get_current_sp()
	ck(await _cast("soul_harvest") == R.OK and healthy.is_alive() and _hurt(healthy) > 75000,
			"above the threshold: a plain hit, it lives (%d HP)" % healthy.current_health)
	ck(sm.get_current_sp() == sp - sm.sp_cost(harvest), "SP paid, nothing back (%d → %d)" % [sp, sm.get_current_sp()])
	healthy.current_health = 15000  # 15 %
	await _reset_hero(home, "soul_harvest")
	sp = sm.get_current_sp()
	ck(await _cast("soul_harvest") == R.OK and not healthy.is_alive(), "below the threshold (15 %): executed")
	ck(sm.get_current_sp() == sp - sm.sp_cost(harvest) + harvest.execute_refund, "SP paid and %d back (%d → %d)" % [harvest.execute_refund, sp, sm.get_current_sp()])
	ck(not xp_got.is_empty(), "the kill gives XP (%s)" % [xp_got])
	await _clear([healthy])
	await _reset_hero(home, "soul_harvest")
	var guard: Node2D = _enemy(60.0, true, "enemy_shield", "shield")
	await _settle([guard])
	guard.break_shield(player.global_position.x)
	await physics_frame
	ck(guard.guard_broken(), "the shield-bearer's shield breaks: guard broken while it staggers")
	sp = sm.get_current_sp()
	ck(await _cast("soul_harvest") == R.OK and not guard.is_alive(), "a broken guard at full HP: executed")
	ck(sm.get_current_sp() == sp - sm.sp_cost(harvest) + harvest.execute_refund, "SP back for it too")
	await _clear([guard])
	await _reset_hero(home, "soul_harvest")
	var shielded: Node2D = _enemy(-60.0, true, "enemy_shield", "shield")
	await _settle([shielded])
	ck(not shielded.guard_broken(), "a shield still up is no broken guard")
	await _clear([shielded])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
