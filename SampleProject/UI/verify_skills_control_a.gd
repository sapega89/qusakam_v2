extends SceneTree

## Навички контролю, перша половина зрізу 6 (v2, D877) у справжній грі, на DesertRoad, по справжніх ворогах:
##   Rising Slash підкидає легкого ворога (важкого — ні), Ground Slam збиває з ніг усіх у радіусі з обох боків і нікого
##   поза ним, Sweeping Arc — кількох перед героєм, Shield Bash і Stone Palm б'ють по стійкості (guard, D777) першого.
##   Кожна платить свої SP; без цілі — не починається й не платить.
##   godot --headless --path . --script res://SampleProject/UI/verify_skills_control_a.gd

const CONTROL := ["rising_slash", "ground_slam", "sweeping_arc", "shield_bash", "stone_palm"]

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
var home := 0.0

## Ворог default_enemy на підлозі в [param dx] px від героя; HP вистачить на весь тест.
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
		e.detection_area.monitoring = false
	for i in 4:
		await physics_frame

func _clear(enemies: Array) -> void:
	for e in enemies:
		e.queue_free()
	await physics_frame

func _reset_hero() -> void:
	player.global_position.x = home
	player.velocity = Vector2.ZERO
	player.last_direction = 1
	for i in 20:
		await physics_frame
		if player.is_on_floor():
			break
	sm.restore_sp(1000)

## Каст навички й очікування, доки герой знову вільний.
func _cast(skill_id: String) -> int:
	var result: int = sm.cast_skill(skill_id)
	for i in 300:
		if player.combat.state == State.READY:
			break
		await physics_frame
	return result

func _hurt(enemy: Node) -> int:
	return enemy.Max_Health - enemy.current_health

## Не preload і не class_name: PlayerCombat бере EventBus, а автозавантаження ще немає, коли компілюється цей скрипт.
func _combat_script() -> GDScript:
	return load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd")

func _sp(id: String) -> int:
	return db.get_skill(id).sp_cost

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення
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
	sm.awaken_skills()  # D815
	db = root.get_node("SkillDatabase")
	R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	State = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State
	var bus: Node = root.get_node("EventBus")
	sm.set_max_sp(1000)
	sl.get_game_manager().player_state.unlocked_skills.append_array(CONTROL)
	home = player.global_position.x
	await _reset_hero()
	ck(player.is_on_floor(), "the hero stands on the DesertRoad floor")

	print("[1] Rising Slash lifts a light enemy into the air; SP paid")
	var light := _enemy(34.0)
	await _settle([light])
	light.set_physics_process(true)  # падає й злітає сам; героя не бачить (detection вимкнено)
	var floor_y: float = light.global_position.y
	var top := [floor_y]
	var watch := func() -> void: top[0] = minf(top[0], light.global_position.y)
	physics_frame.connect(watch)
	var staggered: Array = []
	var on_stagger := func(enemy: Node, time: float) -> void: staggered.append([enemy, time])
	bus.enemy_staggered.connect(on_stagger)
	var sp: int = sm.get_current_sp()
	ck(await _cast("rising_slash") == R.OK, "the cast starts with an enemy in front")
	for i in 60: await physics_frame
	physics_frame.disconnect(watch)
	var lift: float = floor_y - top[0]
	ck(_hurt(light) > 0, "the cut lands (%d)" % _hurt(light))
	ck(lift >= 40.0, "the enemy flew up %.0f px (launch 0.8 s)" % lift)
	ck(staggered.any(func(s: Array) -> bool: return s[0] == light and is_equal_approx(s[1], 0.8)), "its wind-up is broken: staggered for the launch, 0.8 s")
	ck(sm.get_current_sp() == sp - _sp("rising_slash"), "%d SP paid (%d → %d)" % [_sp("rising_slash"), sp, sm.get_current_sp()])
	ck(absf(light.global_position.y - floor_y) <= 2.0, "it lands back on the floor (%.1f)" % (light.global_position.y - floor_y))
	await _clear([light])

	print("[2] Rising Slash does not lift a heavy (large) enemy")
	await _reset_hero()
	var heavy := _enemy(34.0)
	await _settle([heavy])
	heavy.size_kind = "large"
	heavy.set_physics_process(true)
	floor_y = heavy.global_position.y
	top[0] = floor_y
	var watch_heavy := func() -> void: top[0] = minf(top[0], heavy.global_position.y)
	physics_frame.connect(watch_heavy)
	await _cast("rising_slash")
	for i in 30: await physics_frame
	physics_frame.disconnect(watch_heavy)
	ck(_hurt(heavy) > 0 and floor_y - top[0] < 4.0, "hurt (%d) but stays on the ground (%.0f px)" % [_hurt(heavy), floor_y - top[0]])
	await _clear([heavy])
	bus.enemy_staggered.disconnect(on_stagger)

	print("[3] Ground Slam knocks down everyone within 140 px on both sides, nobody outside")
	await _reset_hero()
	var behind := _enemy(-100.0)
	var ahead := _enemy(100.0)
	var far := _enemy(320.0)
	await _settle([behind, ahead, far])
	sp = sm.get_current_sp()
	ck(await _cast("ground_slam") == R.OK, "the cast starts")
	ck(_hurt(behind) > 0 and _hurt(ahead) > 0, "both near enemies hit (behind %d, ahead %d)" % [_hurt(behind), _hurt(ahead)])
	ck(behind.enemy_logic.stun_left > 0.9 and ahead.enemy_logic.stun_left > 0.9 and behind.is_staggered(),
			"both knocked down ~1.2 s (%.2f, %.2f)" % [behind.enemy_logic.stun_left, ahead.enemy_logic.stun_left])
	ck(_hurt(far) == 0 and far.enemy_logic.stun_left == 0.0, "the enemy 320 px away is untouched (%d, %.2f)" % [_hurt(far), far.enemy_logic.stun_left])
	ck(sm.get_current_sp() == sp - _sp("ground_slam"), "%d SP paid" % _sp("ground_slam"))
	await _clear([ahead, far])
	behind.enemy_logic.stun_left = 0.0
	await _reset_hero()
	ck(await _cast("ground_slam") == R.OK and _hurt(behind) > 0, "it starts with the only enemy behind the hero")
	await _clear([behind])
	await _reset_hero()
	sp = sm.get_current_sp()
	ck(sm.cast_skill("ground_slam") == R.NO_TARGET and sm.get_current_sp() == sp and player.combat.state == State.READY,
			"nobody around: NO_TARGET, no SP")

	print("[4] Sweeping Arc hits several in front within 160 px and knocks them down; not behind, not farther")
	await _reset_hero()
	var row: Array = [_enemy(40.0), _enemy(95.0), _enemy(150.0)]
	var back := _enemy(-60.0)
	var beyond := _enemy(300.0)
	await _settle(row + [back, beyond])
	sp = sm.get_current_sp()
	ck(await _cast("sweeping_arc") == R.OK, "the cast starts")
	ck(row.all(func(e: Node) -> bool: return _hurt(e) > 0 and e.enemy_logic.stun_left > 0.7),
			"all 3 in front hit and knocked down %s" % [row.map(func(e: Node) -> String: return "%d/%.2f" % [_hurt(e), e.enemy_logic.stun_left])])
	ck(_hurt(back) == 0 and _hurt(beyond) == 0, "the one behind and the one 300 px ahead are untouched (%d, %d)" % [_hurt(back), _hurt(beyond)])
	ck(sm.get_current_sp() == sp - _sp("sweeping_arc"), "%d SP paid" % _sp("sweeping_arc"))
	await _clear(row + [back, beyond])

	print("[5] Shield Bash: 2.5 heavies of guard damage to the first enemy; on a worn guard it breaks a committed wind-up (D777)")
	await _reset_hero()
	var bashed := _enemy(34.0)
	var next := _enemy(60.0)
	await _settle([bashed, next])
	var heavy_poise: float = _combat_script().POISE_HEAVY
	var full: float = bashed.poise
	sp = sm.get_current_sp()
	ck(await _cast("shield_bash") == R.OK, "the cast starts")
	ck(_hurt(bashed) > 0 and is_equal_approx(full - bashed.poise, heavy_poise * 2.5), "%.1f guard damage (%.1f → %.1f of %d)" % [heavy_poise * 2.5, full, bashed.poise, bashed.poise_max])
	ck(_hurt(next) == 0 and next.poise == next.poise_max, "only the first enemy is bashed")
	ck(sm.get_current_sp() == sp - _sp("shield_bash"), "%d SP paid" % _sp("shield_bash"))
	bashed.poise = heavy_poise * 2.0  # гарда вже надбита
	bashed.enemy_logic.stun_left = 0.0
	bashed.enemy_logic.is_attacking = true  # замах іде, підказку вже показано: оглушення його не зриває (B134)
	bashed.enemy_logic.committed = true
	await _reset_hero()
	await _cast("shield_bash")
	ck(bashed.enemy_logic.attack_broken and bashed.enemy_logic.stun_left > 0.5 and bashed.poise == bashed.poise_max,
			"guard broken: the committed wind-up is broken, staggered %.2f s, the bar refills" % bashed.enemy_logic.stun_left)
	await _clear([bashed, next])

	print("[6] Stone Palm: huge guard damage, little HP damage")
	await _reset_hero()
	var palmed := _enemy(34.0)
	await _settle([palmed])
	palmed.poise_max = 99
	palmed.poise = 99.0
	var heavies: float = _combat_script().POISE_HEAVY * 3.0
	sp = sm.get_current_sp()
	ck(await _cast("stone_palm") == R.OK, "the cast starts")
	ck(is_equal_approx(99.0 - palmed.poise, heavies), "3 heavies of guard damage, %.1f (%.1f)" % [heavies, 99.0 - palmed.poise])
	ck(_hurt(palmed) > 0 and sm.skill_damage("stone_palm") < sm.skill_damage("sweeping_arc") / 2, "little HP damage (%d)" % _hurt(palmed))
	ck(sm.get_current_sp() == sp - _sp("stone_palm"), "%d SP paid" % _sp("stone_palm"))
	await _clear([palmed])

	print("[7] Data: the 5 are built, with the control block and ControlSkill.tscn")
	var all_ok := true
	for id in CONTROL:
		var d = db.get_skill(id)
		if d.planned or d.vfx.get_file() != "ControlSkill.tscn" or not ResourceLoader.exists(d.vfx):
			all_ok = false
			print("    ", id)
	ck(all_ok, "not planned, the effect scene exists")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
