extends SceneTree

## Souls-lite бій (BACKLOG 4 + 15, design/souls_combat_plan.md, D264–D270) у справжній фізиці DesertRoad.
## Дії героя — через Input.parse_input_event (той самий шлях, що клавіша / кнопка геймпада → _unhandled_input).
##   godot --headless --path . --script res://SampleProject/UI/verify_souls_combat.gd

var fails: Array[String] = []

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

## Натиснути / відпустити дію так, як це робить клавіатура чи геймпад.
func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tap(action: StringName) -> void:
	_press(action)
	await physics_frame
	_press(action, false)

var game: Node
var eb: Node
var hero: Node
var enemies: Array = []

## Ворог стоїть на місці й не б'є, доки тест не відпустить.
func _freeze_all() -> void:
	for e in enemies:
		e.set_physics_process(false)

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")  # не ідентифікатор: скрипт тесту компілюється до autoload
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
	ck(enemies.size() >= 2, "enemies on DesertRoad (%d)" % enemies.size())
	ck(InputMap.has_action(&"heavy_attack") and InputMap.has_action(&"block"), "heavy_attack and block are registered (D270)")
	for action in [&"heavy_attack", &"block"]:
		var kinds: Array = InputMap.action_get_events(action).map(func(e: InputEvent) -> String: return e.get_class())
		ck("InputEventJoypadButton" in kinds and ("InputEventKey" in kinds or "InputEventMouseButton" in kinds),
				"%s has a keyboard/mouse and a pad binding (%s)" % [action, kinds])

	await _staggers()
	await _hero_moves(sl)
	await _movement()
	await _weapons(sl)
	await _freeze_check()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## [0] «Вороги інколи заморожують героя» (D264): довгий бій ніколи не лишає героя без керування.
func _freeze_check() -> void:
	print("[0] A long melee never leaves the hero stuck (D264)")
	for e in enemies:
		e.set_physics_process(true)
		e.detection_area.monitoring = true
	hero.Max_Health = 9999  # тут міряємо керування, а не смерть
	hero.current_health = hero.Max_Health
	hero.global_position = enemies[0].global_position + Vector2(-80, 0)
	var stuck_seconds := 0
	var dir := 1
	for sec in 12:
		var x0: float = hero.global_position.x
		var act: StringName = &"move_right" if dir > 0 else &"move_left"
		Input.action_press(act)
		for f in 5:
			await _tap(&"attack")
			await create_timer(0.18).timeout
		Input.action_release(act)
		if absf(hero.global_position.x - x0) < 100.0:
			stuck_seconds += 1
		dir = -dir  # туди-сюди — не виходить з кімнати
	ck(stuck_seconds <= 2, "the hero moved in at least 10 of 12 seconds of fighting (%d stuck)" % stuck_seconds)
	await create_timer(1.0).timeout
	ck(not hero.event and Engine.time_scale == 1.0 and not paused and not hero.combat.owns_animation() and not hero.mover.locked,
			"after the fight: no event lock, time scale 1, not paused, combat idle (event %s, ts %.2f, state %d)"
			% [hero.event, Engine.time_scale, hero.combat.state])
	hero.current_health = hero.Max_Health

## [1] Стійкість ворога і збій героя (D264, D265).
func _staggers() -> void:
	_freeze_all()
	await create_timer(0.8).timeout
	var target: Node = enemies[0]
	target.set_physics_process(true)
	target.poise_max = 3
	target.poise = 3
	target.Max_Health = 9999  # серія героя не вбиває ціль, поки міряємо
	target.current_health = target.Max_Health
	target.set_physics_process(false)
	var staggered: Array = []
	eb.enemy_staggered.connect(func(e: Node, d: float) -> void: staggered.append([e, d]))
	print("[1] Three light hits break a melee enemy's poise")
	hero.combat.attack_cooldown_time = 0.0  # тут міряємо стійкість, а не ритм серії
	for i in 3:
		hero.global_position = target.global_position + Vector2(-26, 0)
		hero.velocity = Vector2.ZERO
		await physics_frame
		hero.combat.perform_attack(1)
		await create_timer(0.4).timeout
	ck(staggered.size() == 1 and staggered[0][0] == target, "the third hit staggers it (%s)" % [staggered])
	ck(target.enemy_logic.stun_left > 0.0, "a staggered enemy stands (stun %.2f)" % target.enemy_logic.stun_left)
	hero.combat.apply_weapon_profile()

	print("[1b] A stagger breaks the enemy's wind-up")
	target.set_physics_process(true)
	await create_timer(1.0).timeout
	target.enemy_logic.stun_left = 0.0
	var swings: Array = []
	var on_swing := func(attacker: Node, _t: Node) -> void:
		if attacker == target: swings.append(Time.get_ticks_msec())
	eb.attack_started.connect(on_swing)
	target.combo_hits = 1
	hero.global_position = target.global_position + Vector2(-300, 0)
	target.enemy_logic.perform_attack()
	await create_timer(0.1).timeout
	target.stagger(0.6, hero.global_position.x)
	var hit_landed := false
	target.hitbox_damage.damage_applied.connect(func(_t: Node, _d: int) -> void: hit_landed = true)
	await create_timer(0.8).timeout
	ck(target.enemy_logic.attack_broken and not target.hitbox.monitoring, "the swing never came (broken %s, hitbox %s)" % [target.enemy_logic.attack_broken, target.hitbox.monitoring])

	print("[2] An enemy combo: three swings, the last a finisher (D265)")
	await create_timer(1.0).timeout
	swings.clear()
	target.combo_hits = 3
	target.combo_chance = 1.0
	var stagger_times: Array = []
	target.enemy_logic.attack_started.connect(func() -> void: stagger_times.append(target.hit_stagger_time()))
	target.enemy_logic.perform_attack()
	await create_timer(target.attack_windup + 2 * 0.25 + 3 * target.attack_active_time + 0.3).timeout
	ck(swings.size() == 3, "three swings in one attack (%d)" % swings.size())
	ck(stagger_times.size() == 3 and stagger_times[2] >= 0.6 and stagger_times[0] == target.stagger_time,
			"only the finisher staggers long (%s)" % [stagger_times])
	eb.attack_started.disconnect(on_swing)
	target.combo_hits = 2
	target.combo_chance = 0.5

	print("[3] An enemy hit staggers the hero: pushed away, no control, then free again (D264)")
	await create_timer(1.0).timeout
	target.set_physics_process(false)
	var got: Array = []
	eb.player_staggered.connect(func(d: float) -> void: got.append(d))
	hero.current_health = hero.Max_Health
	hero.global_position = target.global_position + Vector2(-40, 0)
	hero.velocity = Vector2.ZERO
	await physics_frame
	var x_before: float = hero.global_position.x
	hero.take_damage(5, target)
	ck(got.size() == 1 and hero.combat.is_staggered(), "the hit staggers the hero (%s)" % [got])
	ck(hero.get_node("AnimationPlayer").current_animation == &"Hurt", "the hurt animation plays (%s)" % hero.get_node("AnimationPlayer").current_animation)
	Input.action_press(&"move_right")
	await create_timer(0.15).timeout
	ck(hero.global_position.x < x_before - 20.0, "pushed away from the enemy, not walking into it (%.0f px)" % (hero.global_position.x - x_before))
	await _tap(&"attack")
	ck(not hero.combat.is_attacking, "no attack while staggered")
	await create_timer(0.3).timeout
	var x_free: float = hero.global_position.x
	await create_timer(0.2).timeout
	Input.action_release(&"move_right")
	ck(not hero.combat.is_staggered() and hero.global_position.x > x_free + 30.0, "control comes back (moved %.0f px)" % (hero.global_position.x - x_free))

	print("[3b] A tank hit freezes the hero longer (D253 'freeze')")
	await create_timer(0.6).timeout
	got.clear()
	var tank_time: float = load("res://SampleProject/Resources/Enemies/enemy_stats_tank.tres").stagger_time
	target.stagger_time = tank_time
	hero.take_damage(5, target)
	ck(got.size() == 1 and is_equal_approx(got[0], tank_time) and tank_time >= 0.6, "tank stagger %.2f s (%s)" % [tank_time, got])
	target.stagger_time = 0.25
	await create_timer(1.0).timeout
	print("[3c] A hit without an enemy source (burn, hazard) does not stagger")
	got.clear()
	hero.take_damage(5)
	ck(got.is_empty(), "no stagger without an enemy source")

## Ціль для ударів героя: стоїть, не б'є, не збивається (стійкість велика), повне HP.
func _dummy() -> Node:
	_freeze_all()
	var target: Node = enemies[0]
	target.poise_max = 99
	target.poise = 99
	target.current_health = target.Max_Health
	target.enemy_logic.stun_left = 0.0
	return target

func _place_hero(target: Node, dx: float) -> void:
	hero.global_position = target.global_position + Vector2(dx, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1 if dx < 0 else -1
	await physics_frame

## [4]–[7] Серія, важкий удар, блок, парирування, зірваний каст (D264, D269).
func _hero_moves(sl: Node) -> void:
	await create_timer(1.0).timeout
	var target := _dummy()
	var hits: Array = []
	target.damage_token.connect(func(d: int) -> void: hits.append(d))
	var d: int = hero.combat.hit_damage()

	print("[4] Light combo: three presses, three hits, the finisher 1.4x, then a recovery")
	await _place_hero(target, -26)
	await _tap(&"attack")
	await create_timer(0.1).timeout
	await _tap(&"attack")  # посеред удару — у черзі
	await create_timer(0.35).timeout
	await _tap(&"attack")
	await create_timer(0.45).timeout
	ck(hits == [d, d, roundi(d * 1.4)], "three hits %s (expected %d, %d, %d)" % [hits, d, d, roundi(d * 1.4)])
	ck(hero.combat.combo_step == 2 and hero.combat.attack_cooldown > 0.0, "the finisher ends the combo with a recovery (step %d, cooldown %.2f)" % [hero.combat.combo_step, hero.combat.attack_cooldown])
	hits.clear()
	await _tap(&"attack")
	await create_timer(0.1).timeout
	ck(not hero.combat.is_attacking, "no swing during the recovery")
	print("[4b] The chain expires: a late press starts a new combo")
	await create_timer(1.0).timeout
	await _tap(&"attack")
	await create_timer(0.3 + 0.5).timeout
	await _tap(&"attack")
	await create_timer(0.1).timeout
	ck(hero.combat.combo_step == 0, "after a pause the combo starts over (step %d)" % hero.combat.combo_step)
	await create_timer(1.0).timeout

	print("[5] Heavy attack: a rooted wind-up, then 2.2x with knockback")
	hits.clear()
	target.poise_max = 3
	target.poise = 3
	var staggered: Array = []
	var on_stagger := func(e: Node, _t: float) -> void: staggered.append(e)
	eb.enemy_staggered.connect(on_stagger)
	await _place_hero(target, -30)
	var x0: float = hero.global_position.x
	Input.action_press(&"move_right")
	await _tap(&"heavy_attack")
	await create_timer(0.2).timeout
	ck(hero.combat.state == hero.combat.State.HEAVY_WINDUP and absf(hero.global_position.x - x0) < 8.0, "wind-up roots the hero (state %d, moved %.0f)" % [hero.combat.state, hero.global_position.x - x0])
	await create_timer(0.35).timeout
	Input.action_release(&"move_right")
	ck(hits == [roundi(d * 2.2)], "one heavy hit %s (expected %d)" % [hits, roundi(d * 2.2)])
	ck(staggered.has(target), "a heavy hit breaks a melee enemy's poise (3) at once")
	eb.enemy_staggered.disconnect(on_stagger)
	await create_timer(1.2).timeout

	print("[5b] A hit during the heavy wind-up staggers the hero and cancels the heavy (D259)")
	target = _dummy()
	hits.clear()
	await _place_hero(target, -30)
	await _tap(&"heavy_attack")
	await create_timer(0.1).timeout
	hero.take_damage(5, target)
	await create_timer(0.6).timeout
	ck(hero.combat.state != hero.combat.State.HEAVY_STRIKE and hits.is_empty(), "the heavy never landed (hits %s)" % [hits])
	await create_timer(0.6).timeout

	print("[6] Block: front hits take 30%, no stagger; a hit from behind is not blocked")
	var got: Array = []
	eb.player_staggered.connect(func(t: float) -> void: got.append(t))
	await _place_hero(target, -30)
	hero.current_health = hero.Max_Health
	_press(&"block")
	await create_timer(0.3).timeout
	ck(hero.combat.is_blocking(), "holding block blocks")
	var hp0: int = hero.current_health
	hero.take_damage(20, target)
	ck(hp0 - hero.current_health == hero.mitigated_damage(6) and got.is_empty(), "blocked: %d HP lost (expected %d), staggers %s" % [hp0 - hero.current_health, hero.mitigated_damage(6), got])
	await create_timer(0.6).timeout
	hero.mover.last_direction = -1  # спиною до ворога
	hp0 = hero.current_health
	hero.take_damage(20, target)
	ck(hp0 - hero.current_health == hero.mitigated_damage(20) and got.size() == 1, "from behind: full %d HP and a stagger" % (hp0 - hero.current_health))
	_press(&"block", false)
	await create_timer(0.8).timeout

	print("[6b] Parry: a hit right after pressing block deals nothing and staggers the enemy")
	var parried: Array = []
	eb.player_parried.connect(func(a: Node) -> void: parried.append(a))
	await _place_hero(target, -30)
	got.clear()
	hp0 = hero.current_health
	_press(&"block")
	await physics_frame
	await physics_frame
	hero.take_damage(20, target)
	ck(hero.current_health == hp0 and got.is_empty() and parried == [target], "parried: no damage, no stagger (%d → %d)" % [hp0, hero.current_health])
	ck(target.enemy_logic.stun_left >= 0.9, "the attacker is staggered 1 s (%.2f)" % target.enemy_logic.stun_left)
	print("[6c] A tank-strength hit breaks the guard")
	await create_timer(0.5).timeout
	target.stagger_time = 0.6
	hero.take_damage(20, target)
	ck(got.size() == 1, "guard broken: staggered (%s)" % [got])
	target.stagger_time = 0.25
	_press(&"block", false)
	await create_timer(1.0).timeout

	print("[7] D259: a hit during a skill cast spends the SP and starts the cooldown, no effect")
	var sm: Node = sl.get_skill_manager()
	sm.clear_cooldowns()
	sm.restore_sp(999)
	var sp0: int = sm.get_current_sp()
	var interrupted: Array = []
	eb.skill_interrupted.connect(func(id: String) -> void: interrupted.append(id))
	ck(hero.combat.begin_cast(sm.skill_database.get_skill("fire_strike")), "a cast starts")
	hero.take_damage(5, target)
	ck(interrupted == ["fire_strike"] and sm.get_current_sp() == sp0 - 6 and sm.is_skill_on_cooldown("fire_strike"),
			"interrupted: SP %d → %d, cooldown %s" % [sp0, sm.get_current_sp(), sm.is_skill_on_cooldown("fire_strike")])
	ck(hero.combat.casting_skill == "", "the cast is over")
	await create_timer(1.0).timeout

func _root_meta(path: String, key: String) -> Variant:
	var st: SceneState = load(path).get_state()
	for i in st.get_node_property_count(0):
		if st.get_node_property_name(0, i) == "metadata/" + key:
			return st.get_node_property_value(0, i)
	return null

## [8] Подвійний ривок, [9] у місті поза боєм — хода (D264, D266).
func _movement() -> void:
	_freeze_all()
	for e in enemies:
		e.detection_area.monitoring = false  # герой ходитиме поруч — не помічати
		e.enemy_logic.current_state = 0  # IDLE — ніхто не женеться
		e.enemy_logic.is_attacking = false
	var mover: Node = hero.mover
	await create_timer(1.0).timeout
	print("[8] Double dash: two in a row, a third waits; the second works in the air")
	await _place_hero(enemies[1], 0)
	mover.dash_charges = mover.dash_charges_max
	mover.roll_ready_in = 0.0
	await _tap(&"dodge")
	ck(mover.is_rolling() and mover.dash_charges == 1, "first dash (charges %d)" % mover.dash_charges)
	await create_timer(0.12).timeout
	await _tap(&"dodge")
	ck(mover.is_rolling() and mover.dash_charges == 0, "second dash chained (charges %d)" % mover.dash_charges)
	await create_timer(0.35).timeout
	await _tap(&"dodge")
	ck(not mover.is_rolling(), "a third dash waits for the refill")
	await create_timer(0.7).timeout
	ck(mover.dash_charges == 2, "both dashes back 0.6 s after the last (%d)" % mover.dash_charges)
	hero.velocity = Vector2(0, -350)
	for i in 8: await physics_frame
	ck(not hero.is_on_floor(), "in the air")
	await _tap(&"dodge")
	var y0: float = hero.global_position.y
	await create_timer(0.15).timeout
	ck(mover.is_rolling() and absf(hero.global_position.y - y0) < 2.0, "an air dash is level (dy %.1f)" % (hero.global_position.y - y0))
	await create_timer(1.5).timeout

	print("[9] Towns: walk out of combat, run in a fight (D251, D266)")
	for town in ["Village", "City", "CityGates", "MayorHall"]:
		ck(_root_meta("res://SampleProject/Maps/%s.tscn" % town, "town") == true, "%s is a town" % town)
	for wild in ["Canyon", "DesertRoad", "Laboratory"]:
		ck(_root_meta("res://SampleProject/Maps/%s.tscn" % wild, "town") == null, "%s is wild" % wild)
	await _place_hero(enemies[1], 0)
	game.map.set_meta(&"town", true)
	await create_timer(hero.combat.COMBAT_LINGER + 0.2).timeout
	ck(not hero.combat.in_combat(), "no fight on")

	Input.action_press(&"move_left")
	await create_timer(0.5).timeout
	ck(absf(hero.velocity.x) <= mover.walk_speed + 1.0 and hero.animation == &"Walk", "in town: walks %.0f px/s, %s" % [absf(hero.velocity.x), hero.animation])
	enemies[0].enemy_logic.current_state = 1  # CHASE — бій почався
	await create_timer(0.3).timeout
	ck(hero.combat.in_combat() and absf(hero.velocity.x) > mover.walk_speed + 50.0 and hero.animation == &"Run", "in a fight: runs %.0f px/s, %s" % [absf(hero.velocity.x), hero.animation])
	Input.action_release(&"move_left")
	enemies[0].enemy_logic.current_state = 0
	game.map.remove_meta(&"town")

## [10]–[12] Хвати, зброя за спиною, удар для кожного типу зброї (D250, D267, D268).
func _weapons(sl: Node) -> void:
	var em: Node = sl.get_equipment_manager()
	var items: Node = sl.get_item_database()
	var gm: Node = sl.get_game_manager()
	var who: String = gm.get_active_character().character_id
	var wv: Node = hero.get_node("WeaponMount")
	var anim: AnimationPlayer = hero.get_node("AnimationPlayer")
	var equip := func(slot: String, id: String) -> void:
		em.equip_item(who, slot, id, items.get_item(id))
	await create_timer(0.5).timeout

	print("[10] Grips: two-handed halberd, sword + dagger dual-wield, a shield ends dual-wield (D267)")
	equip.call("polearm", "iron_halberd")
	await process_frame
	ck(em.get_grip() == &"two_handed" and hero.combat.grip == &"two_handed", "the halberd is two-handed (%s)" % em.get_grip())
	equip.call("shield", "iron_shield")
	sl.get_skill_manager().unlock_skill("shield_block")
	await process_frame
	var with_shield: int = hero.mitigated_damage(100)
	em.cycle_weapon(1)  # щось одноручне? немає — лишається алебарда
	ck(hero.mitigated_damage(100) == with_shield, "same weapon, same mitigation")
	em.unequip_item(who, "polearm")
	equip.call("sword", "iron_sword")
	await process_frame
	ck(hero.combat.grip == &"one_handed", "sword + shield is one-handed (%s)" % hero.combat.grip)
	var one_handed_mitigation: int = hero.mitigated_damage(100)
	equip.call("polearm", "iron_halberd")
	while gm.player_state.weapon_in_hand != "polearm":
		em.cycle_weapon(1)
	await process_frame
	ck(hero.mitigated_damage(100) > one_handed_mitigation or sl.get_skill_manager().passive_value("shield_block") == 0.0,
			"no Shield Block with a two-handed weapon (%d vs %d)" % [hero.mitigated_damage(100), one_handed_mitigation])
	em.unequip_item(who, "shield")
	em.unequip_item(who, "polearm")
	equip.call("dagger", "iron_dagger")
	while gm.player_state.weapon_in_hand != "sword":
		em.cycle_weapon(1)
	await process_frame
	ck(hero.combat.grip == &"dual" and em.get_off_hand_item().id == "iron_dagger" and wv.off_pivot.visible,
			"sword in hand + dagger = dual-wield, the dagger shown in the off hand (%s)" % hero.combat.grip)
	ck(hero.combat.combo_length() == 4, "dual-wield combo has 4 swings (%d)" % hero.combat.combo_length())

	print("[10b] The dual-wield combo: four faster swings, the last 1.4x")
	var target := _dummy()
	var hits: Array = []
	target.damage_token.connect(func(dd: int) -> void: hits.append(dd))
	var d: int = hero.combat.hit_damage()
	await _place_hero(target, -26)
	for i in 4:  # одне натискання на удар — черга тримає одне
		await _tap(&"attack")
		await create_timer(0.2).timeout
	await create_timer(0.6).timeout
	ck(hits == [d, d, d, roundi(d * 1.4)], "four hits %s" % [hits])
	em.unequip_item(who, "dagger")
	em.unequip_item(who, "sword")
	await process_frame

	print("[11] Hidden out of combat, drawn when a fight starts or on a swing (D268)")
	equip.call("sword", "iron_sword")
	await create_timer(hero.combat.COMBAT_LINGER + 0.3).timeout
	ck(not hero.combat.in_combat() and wv.sheathed and not wv.pivot.visible and not wv.off_pivot.visible, "no fight: the sword is out of sight (Sapega 2026-10-21)")
	enemies[0].enemy_logic.current_state = 1  # CHASE
	await create_timer(0.4).timeout
	ck(not wv.sheathed and wv.pivot.visible and wv.pivot.position.distance_to(wv.HAND_REST) < 1.0, "a fight starts: drawn into the hand (%s)" % wv.pivot.position)
	enemies[0].enemy_logic.current_state = 0
	await create_timer(hero.combat.COMBAT_LINGER + 0.4).timeout
	await process_frame
	ck(wv.sheathed and not wv.pivot.visible, "the fight is over: the sword vanishes")
	await _tap(&"attack")
	await physics_frame
	await process_frame
	ck(not wv.sheathed and wv.pivot.visible, "a swing draws it at once")
	await create_timer(0.8).timeout

	print("[12a] The hitbox reaches as far as the swing is drawn (D268, Sapega 2026-10-21)")
	var box: RectangleShape2D = hero.get_node("Hitbox/CollisionShape2D").shape
	for case in [["sword", "iron_sword"], ["mace", "iron_mace"], ["polearm", "iron_halberd"], ["dagger", "iron_dagger"]]:
		equip.call(case[0], case[1])
		while gm.player_state.weapon_in_hand != case[0]:
			em.cycle_weapon(1)
		await process_frame
		ck(absf(box.size.x - wv.drawn_reach()) <= 2.0, "%s: hitbox %.0f px, drawn %.0f px" % [case[1], box.size.x, wv.drawn_reach()])
	em.unequip_item(who, "dagger")
	em.unequip_item(who, "mace")
	em.unequip_item(who, "polearm")
	equip.call("sword", "iron_sword")
	await process_frame

	print("[12] Each weapon type swings its own way (D268)")
	var played: Array = []
	var log_anim := func(name: StringName) -> void: played.append(name)
	anim.animation_started.connect(log_anim)
	for case in [["sword", "iron_sword", &"Attack"], ["mace", "iron_mace", &"AttackSmash"], ["polearm", "iron_halberd", &"AttackThrust"]]:
		em.unequip_item(who, "sword")
		equip.call(case[0], case[1])
		while gm.player_state.weapon_in_hand != case[0]:
			em.cycle_weapon(1)
		await create_timer(1.2).timeout
		played.clear()
		await _tap(&"attack")
		await physics_frame
		ck(played.has(case[2]), "%s swings with %s (%s)" % [case[1], case[2], played])
		em.unequip_item(who, case[0])
	await create_timer(1.2).timeout
	played.clear()
	await _tap(&"heavy_attack")
	await create_timer(0.6).timeout
	ck(played.has(&"HeavyWindup") and played.has(&"HeavyStrike"), "heavy: wind-up then strike (%s)" % [played])
	await create_timer(1.2).timeout
	played.clear()
	_press(&"block")
	await create_timer(0.1).timeout
	ck(played.has(&"Block"), "block pose (%s)" % [played])
	_press(&"block", false)
	anim.animation_started.disconnect(log_anim)
	await create_timer(0.5).timeout
