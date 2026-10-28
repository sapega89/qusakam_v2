extends SceneTree

## Стійки й баффи (skills v2 зріз 5, D-sv2s1) у справжній грі, на DesertRoad, по справжніх ворогах:
##   Counter Stance (удар у стійці заблоковано й відповідено, червоний влучає), Mirror Stance (стріла летить назад),
##   Centered Breath (канал у бою, удар зриває), Battle Cry (сила ударів на час, звичайні вороги здригаються), Aegis
##   (бар'єр поглинає), Blood Price (ціна в HP, три посилені влучання), Rally (наступний асист сильніший і довший).
## Кожна платить SP; бафф видно в рядку стану героя (HUD), поки діє.
##   godot --headless --path . --script res://SampleProject/UI/verify_skills_stance.gd

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

const ARROW := "res://SampleProject/Scenes/Combat/arrow.tscn"

var game: Node
var player: Node2D
var sm: Node
var gm: Node
var db: Node
var R
var State
var EnemyLogic
var row: Node

## Ворог default_enemy на підлозі в [param dx] px від героя; стоїть (без AI), HP вистачить на весь тест.
func _enemy(dx: float) -> Node2D:
	var enemy: Node2D = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	game.map.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(dx, -10)
	enemy.Max_Health = 100000
	enemy.current_health = 100000
	return enemy

func _settle(enemies: Array) -> void:
	for i in 30:
		await physics_frame
	for e in enemies:
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
		e.enemy_logic.tell_kind = EnemyLogic.TELL_PARRY
	for i in 4:
		await physics_frame

func _hurt(enemy: Node) -> int:
	return enemy.Max_Health - enemy.current_health

## Герой вільний, на підлозі, дивиться праворуч, HP і SP повні, невразливість знята.
func _reset_hero() -> void:
	for i in 120:
		if player.combat.state == State.READY:
			break
		await physics_frame
	player.velocity = Vector2.ZERO
	player.last_direction = 1
	player.set_invulnerable(false)
	player.current_health = player.Max_Health
	sm.restore_sp(1000)
	await physics_frame

## Каст і очікування кінця замаху: стан бою після нього (CAST_RELEASE — вивільнення, тобто стійка).
func _cast(skill_id: String) -> int:
	var result: int = sm.cast_skill(skill_id)
	for i in 200:
		if player.combat.state != State.CAST_WINDUP:
			break
		await physics_frame
	return result

func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await physics_frame

## Значки баффів у рядку стану героя (HUD).
func _icons() -> Array[String]:
	return row.buff_ids()

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
	gm = sl.get_game_manager()
	db = root.get_node("SkillDatabase")
	sm.awaken_skills()  # D815
	R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	State = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State
	EnemyLogic = load("res://SampleProject/Scripts/Gameplay/Components/EnemyLogic.gd")
	row = get_first_node_in_group(&"player_vitals_panel")._states
	sm.set_max_sp(1000)
	for id in ["counter_stance", "mirror_stance", "centered_breath", "battle_cry", "aegis", "blood_price", "rally"]:
		gm.player_state.unlocked_skills.append(id)
	for i in 30:
		await physics_frame
	ck(player.is_on_floor() and sm.stances != null, "the hero stands on the DesertRoad floor; SkillManager has its stances")

	print("[1] Counter Stance: a blow taken in it is blocked and answered hard (D-sv2s1)")
	var front := _enemy(40)
	var back := _enemy(-40)
	await _settle([front, back])
	await _reset_hero()
	var sp: int = sm.get_current_sp()
	var hp: int = player.current_health
	ck(await _cast("counter_stance") == R.OK, "cast starts (no enemy needed)")
	ck(sm.stances.stance() == "counter_stance" and player.combat.state == State.CAST_RELEASE and String(player.animation) == "Block",
			"the stance holds in the Block pose (%s)" % player.animation)
	ck(sp - sm.get_current_sp() == db.get_skill("counter_stance").sp_cost, "SP paid: %d" % (sp - sm.get_current_sp()))
	ck("counter_stance" in _icons(), "the HUD status row shows Counter Stance %s" % [_icons()])
	ck(player.shield_spell.spell == &"magic", "the magic shield (H2) stands over the stance")
	var answers: Array = []
	sm.stances.countered.connect(func(id: String, by: Node) -> void: answers.append([id, by]))
	player.take_damage(30, front)
	await physics_frame
	ck(player.current_health == hp, "the hero takes nothing (%d → %d)" % [hp, player.current_health])
	ck(_hurt(front) == sm.skill_damage("counter_stance") and answers.size() == 1 and answers[0][1] == front,
			"the attacker takes the counter: %d (skill damage %d)" % [_hurt(front), sm.skill_damage("counter_stance")])
	ck(sm.stances.stance() == "" and String(player.animation) == "HeavyStrike", "one answer ends the stance; the hero strikes (%s)" % player.animation)
	await physics_frame
	ck("counter_stance" not in _icons(), "the icon leaves the HUD")
	await _reset_hero()
	hp = player.current_health
	await _cast("counter_stance")
	player.take_damage(30, back)
	ck(player.current_health == hp and _hurt(back) == sm.skill_damage("counter_stance"), "a blow from behind is answered too (%d)" % _hurt(back))
	await _reset_hero()

	print("[2] Counter Stance: a red (unblockable) attack still hits and breaks the stance")
	hp = player.current_health
	var before: int = _hurt(front)
	await _cast("counter_stance")
	front.enemy_logic.tell_kind = EnemyLogic.TELL_DODGE
	player.take_damage(30, front)
	await physics_frame
	await physics_frame
	ck(player.current_health < hp and _hurt(front) == before, "the red blow hurts (%d → %d), no counter" % [hp, player.current_health])
	ck(sm.stances.stance() == "" and player.combat.state == State.STAGGER, "the stance is broken, the hero staggers")
	front.enemy_logic.tell_kind = EnemyLogic.TELL_PARRY
	await _reset_hero()

	print("[3] Counter Stance ends after its time; then a blow lands")
	await _cast("counter_stance")
	await _wait(db.get_skill("counter_stance").buff_time + 0.1)
	ck(sm.stances.stance() == "" and player.combat.state == State.READY, "the stance is over after %.1f s" % db.get_skill("counter_stance").buff_time)
	hp = player.current_health
	before = _hurt(front)
	player.take_damage(30, front)
	ck(player.current_health < hp and _hurt(front) == before, "a blow after it hurts and is not answered")
	for e in [front, back]:
		e.queue_free()
	await _reset_hero()

	print("[4] Mirror Stance: an archer's arrow flies back (D-sv2s1, D384)")
	var archer := _enemy(220)
	await _settle([archer])
	sp = sm.get_current_sp()
	hp = player.current_health
	ck(await _cast("mirror_stance") == R.OK and sm.stances.stance() == "mirror_stance", "Mirror Stance holds")
	ck(sp - sm.get_current_sp() == db.get_skill("mirror_stance").sp_cost, "SP paid: %d" % (sp - sm.get_current_sp()))
	var arrow: Node = load(ARROW).instantiate()
	arrow.hero_side = false
	arrow.direction = -1
	arrow.damage = 12
	arrow.shooter = archer
	game.map.add_child(arrow)
	arrow.global_position = player.global_position + Vector2(60, -10)
	var turned := false
	for i in 30:
		await physics_frame
		if not is_instance_valid(arrow):
			break
		turned = turned or (arrow.hero_side and arrow.direction == 1)
	var reflected: int = roundi(12 * db.get_skill("mirror_stance").reflect_ratio * sm._skill_factor("mirror_stance", -1))
	ck(player.current_health == hp and turned, "the hero takes nothing, the arrow turns back (%d → %d)" % [hp, player.current_health])
	for i in 40:
		await physics_frame
		if _hurt(archer) > 0:
			break
	ck(_hurt(archer) == reflected, "it hits the archer for %d (reflect %d)" % [_hurt(archer), reflected])
	ck(sm.stances.stance() == "mirror_stance" or player.combat.state != State.CAST_RELEASE, "an arrow does not end Mirror Stance")
	archer.queue_free()
	var brawler := _enemy(40)
	await _settle([brawler])
	await _reset_hero()
	await _cast("mirror_stance")
	hp = player.current_health
	player.take_damage(30, brawler)
	ck(player.current_health < hp and _hurt(brawler) == 0, "a melee blow is not mirrored: it hurts")
	brawler.queue_free()
	await _reset_hero()

	print("[5] Centered Breath: in battle only; the channel heals HP and restores SP; a blow breaks it")
	for i in 300:
		if not player.combat.in_combat():
			break
		await physics_frame
	ck(not player.combat.in_combat() and sm.cast_skill("centered_breath") == R.NO_TARGET, "out of battle: refused")
	var foe := _enemy(40)
	await _settle([foe])
	player.current_health = 20
	sm.restore_sp(1000)
	sm.spend_sp(sm.get_current_sp() - 10)
	player.combat._in_combat = true
	player.combat._combat_left = 3.0
	var heal: int = sm.skill_heal("centered_breath")
	var restore: int = roundi(db.get_skill("centered_breath").sp_restore * sm._skill_factor("centered_breath", -1))
	ck(sm.cast_skill("centered_breath") == R.OK and String(player.animation) == "Meditate", "the channel starts in the Meditate pose")
	await _wait(db.get_skill("centered_breath").cast_windup + 0.1)
	ck(player.current_health == 20 + heal and sm.get_current_sp() == 10 + restore, "HP 20 → %d (+%d), SP 10 → %d (+%d)" % [player.current_health, heal, sm.get_current_sp(), restore])
	await _reset_hero()
	player.current_health = 20
	player.combat._in_combat = true
	player.combat._combat_left = 3.0
	sm.cast_skill("centered_breath")
	await _wait(0.5)
	player.take_damage(5, foe)
	await _wait(db.get_skill("centered_breath").cast_windup)
	ck(player.current_health < 20, "a blow in the channel breaks it: nothing healed (HP %d)" % player.current_health)
	foe.queue_free()
	await _reset_hero()

	print("[6] Battle Cry: the hero's hits are stronger for its time, then not; ordinary enemies close by flinch")
	var weak := _enemy(80)
	var elite := _enemy(-80)
	var far := _enemy(400)
	await _settle([weak, elite, far])
	elite.elite = true
	var base_hit: int = player.combat.hit_damage()
	var cry: SkillDefinition = db.get_skill("battle_cry")
	var bonus: float = cry.attack_bonus * sm._skill_factor("battle_cry", -1)
	sp = sm.get_current_sp()
	ck(await _cast("battle_cry") == R.OK, "Battle Cry cast")
	await physics_frame
	ck(sp - sm.get_current_sp() == cry.sp_cost, "SP paid: %d" % (sp - sm.get_current_sp()))
	ck(player.combat.hit_damage() == roundi(base_hit * (1.0 + bonus)) and player.combat.hit_damage() > base_hit,
			"a hit deals %d instead of %d (+%d %%)" % [player.combat.hit_damage(), base_hit, roundi(bonus * 100)])
	ck(weak.is_staggered() and not elite.is_staggered() and not far.is_staggered(), "the ordinary enemy within %d px flinches; the elite and the far one do not" % cry.flinch_radius)
	ck("battle_cry" in _icons(), "the HUD shows Battle Cry")
	await _wait(cry.buff_time + 0.1)
	ck(player.combat.hit_damage() == base_hit and not sm.stances.is_on("battle_cry"), "after %.0f s the hit is back to %d" % [cry.buff_time, player.combat.hit_damage()])
	ck("battle_cry" not in _icons(), "and the icon is gone")
	for e in [weak, elite, far]:
		e.queue_free()
	await _reset_hero()

	print("[7] Aegis: a barrier soaks damage for its time")
	var brute := _enemy(40)
	await _settle([brute])
	var aegis: SkillDefinition = db.get_skill("aegis")
	var pool: int = roundi((aegis.absorb + aegis.absorb_elem * gm.calculate_magic_damage()) * sm._skill_factor("aegis", -1))
	sp = sm.get_current_sp()
	hp = player.current_health
	ck(await _cast("aegis") == R.OK and sm.stances.absorb_left() == pool, "the barrier holds %d" % sm.stances.absorb_left())
	ck(sp - sm.get_current_sp() == aegis.sp_cost and "aegis" in _icons(), "SP paid: %d; the HUD shows Aegis" % (sp - sm.get_current_sp()))
	await _reset_hero()
	hp = player.current_health
	var small: int = player.mitigated_damage(10)
	player.take_damage(10, brute)
	ck(player.current_health == hp and sm.stances.absorb_left() == pool - small and player.combat.state == State.READY,
			"a blow it soaks whole: no HP lost, no stagger, %d left" % sm.stances.absorb_left())
	var big: int = 10
	while player.mitigated_damage(big) < sm.stances.absorb_left() + 20:
		big += 1  # 20 HP через бар'єр — герой живий
	var through: int = player.mitigated_damage(big) - sm.stances.absorb_left()
	player.take_damage(big, brute)
	ck(hp - player.current_health == through and not sm.stances.is_on("aegis"), "a blow past it: %d through, the barrier is gone" % (hp - player.current_health))
	await _reset_hero()
	await _cast("aegis")
	await _wait(aegis.buff_time + 0.1)
	ck(not sm.stances.is_on("aegis") and "aegis" not in _icons(), "unbroken, it fades after %.0f s" % aegis.buff_time)
	await _reset_hero()

	print("[8] Blood Price: costs HP; the next hits deal more")
	var price: SkillDefinition = db.get_skill("blood_price")
	var cost: int = roundi(player.Max_Health * price.hp_cost)
	base_hit = player.combat.hit_damage()
	sp = sm.get_current_sp()
	hp = player.current_health
	ck(await _cast("blood_price") == R.OK, "Blood Price cast")
	await physics_frame
	ck(hp - player.current_health == cost and player.combat.state != State.STAGGER, "HP %d → %d: %d %% of Max HP, no stagger" % [hp, player.current_health, roundi(price.hp_cost * 100)])
	ck(sp - sm.get_current_sp() == price.sp_cost and "blood_price" in _icons(), "SP paid: %d; the HUD shows Blood Price" % (sp - sm.get_current_sp()))
	var boosted: int = roundi(base_hit * (1.0 + price.hit_bonus * sm._skill_factor("blood_price", -1)))
	var hits: Array = []
	for i in price.buff_hits:
		hits.append(player.combat.hit_damage())
		brute.take_damage(hits[-1], player)
	ck(hits.all(func(h: int) -> bool: return h == boosted), "%d hits deal %s (base %d)" % [price.buff_hits, hits, base_hit])
	ck(player.combat.hit_damage() == base_hit and sm.stances.blood_hits() == 0 and "blood_price" not in _icons(), "the 4th hit is back to %d, the icon is gone" % base_hit)
	await _reset_hero()
	player.current_health = cost
	sp = sm.get_current_sp()
	ck(sm.cast_skill("blood_price") == R.EFFECT_FAILED and sm.get_current_sp() == sp and player.current_health == cost, "with only %d HP left: refused, nothing paid" % cost)
	brute.queue_free()
	await _reset_hero()

	print("[9] Rally: the next assist hits harder and lasts longer")
	var cm: Node = sl.get_companion_manager()
	ck(cm.get_next_in_queue() == "" and sm.cast_skill("rally") == R.NO_TARGET, "no companion in the party: refused")
	cm.offer_guard(true)
	var plain: Node = cm.SCENES["guard"].instantiate()
	var rally: SkillDefinition = db.get_skill("rally")
	var factor: float = sm._skill_factor("rally", -1)
	sp = sm.get_current_sp()
	ck(await _cast("rally") == R.OK and sm.stances.is_on("rally") and "rally" in _icons(), "Rally cast; the HUD shows it")
	ck(sp - sm.get_current_sp() == rally.sp_cost, "SP paid: %d" % (sp - sm.get_current_sp()))
	await _reset_hero()
	ck(cm.call_next() == "guard", "the guard is called")
	var actor: Node = cm._active_actor
	ck(actor.damage == roundi(plain.damage * (1.0 + rally.assist_damage * factor)) and is_equal_approx(actor.hold_time, plain.hold_time * (1.0 + rally.assist_duration))
			and is_equal_approx(actor.stun, plain.stun * (1.0 + rally.assist_duration)),
			"its assist: damage %d → %d, stay %.2f → %.2f s" % [plain.damage, actor.damage, plain.hold_time, actor.hold_time])
	ck(not sm.stances.is_on("rally") and "rally" not in _icons(), "Rally is spent on that assist")
	plain.free()

	print("[10] Death clears every buff")
	await _reset_hero()
	sm.stances.use(db.get_skill("battle_cry"), player)
	sm.stances.use(db.get_skill("aegis"), player)
	root.get_node("EventBus").player_respawned.emit()
	await physics_frame
	ck(not sm.stances.is_on("battle_cry") and not sm.stances.is_on("aegis") and _icons().is_empty(), "nothing left on respawn")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
