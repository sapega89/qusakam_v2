extends SceneTree

## Бій у реальній фізиці (DesertRoad, 4 вороги): гравець бʼє ворога, вороги наздоганяють і
## бʼють гравця, смерть ворога доходить до кінця (анімація, зникнення, лут, стан).
## Раніше бій не покривав жоден тест — рефакторинг DefaultEnemy / EnemyLogic / EnemyView
## (D131) перевіряти було нічим.
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_flow.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

# Без типів CombatBody2D / EnemyLogic / GameGroups: скрипт тесту компілюється до autoload,
# а ці класи посилаються на EventBus — тип у тесті ламає компіляцію всього ланцюга.
func _enemies(road: Node) -> Array:
	var found: Array = []
	for node in road.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			found.append(node)
	return found

## Проклацує справжній діалог до кінця (accept як Enter / клік у грі).
func _finish_dialogue(dm: Node) -> void:
	# Діалоги йдуть ланцюжком із паузою між ними (черга DialogueManager) — доки не стихне.
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

func _initialize() -> void:
	# D393: кидки крита й ухилення з CALM_SEED — жоден не спрацює, бій точний
	var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	rolls.calm()
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())  # вступ Canyon
	var inv: Node = sl.get_inventory_manager()

	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 10: await process_frame
	var road: Node = game.map
	for i in 6: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())  # репліка перед боєм
	await create_timer(2.5).timeout
	var enemies: Array = _enemies(road)
	ck(enemies.size() == 4, "4 enemies spawned (%d)" % enemies.size())

	print("[0] Enemies appear on the floor at their points and move with the room (B61)")
	var points: Array = road.get_node("EnemySpawner").get_children().filter(func(p: Node) -> bool: return p.is_in_group(&"enemy_spawn_points"))
	for e in enemies:
		var point: Node2D = points.filter(func(p: Node) -> bool: return e.name == "Enemy_%s" % p.spawn_id)[0]
		ck(e.is_on_floor() and absf(e.global_position.y - point.global_position.y) < 1.0,
				"%s stands on the floor at its point (y %.1f vs %.1f)" % [e.name, e.global_position.y, point.global_position.y])
	var x_before: float = enemies[0].global_position.x
	road.position.x += 100.0
	ck(is_equal_approx(enemies[0].global_position.x, x_before + 100.0), "an enemy moves with its room (%.1f → %.1f)" % [x_before, enemies[0].global_position.x])
	road.position.x -= 100.0

	print("[0b] An enemy dropped onto the player slides off to the floor (B58, D443)")
	var dropped = enemies[3]
	dropped.set_physics_process(true)
	game.player.global_position = Vector2(dropped.global_position.x, game.player.global_position.y)
	game.player.velocity = Vector2.ZERO
	await create_timer(0.3).timeout
	dropped.global_position = game.player.global_position + Vector2(0, -60)
	dropped.velocity = Vector2.ZERO
	# D443: зісковзує з героя, а з ворогів поруч — теж. Чекаємо кроки фізики, а не секунди: під навантаженням набору
	# за 2 с реального часу фізика встигала менше кроків, і ворог ще не доїжджав до підлоги.
	for i in 240:
		await physics_frame
		if dropped.is_on_floor() and absf(dropped.global_position.y - points[3].global_position.y) < 1.0:
			break
	ck(dropped.is_on_floor() and absf(dropped.global_position.y - points[3].global_position.y) < 1.0,
			"the enemy stands on the floor, not on the player (enemy y %.1f, floor-level %.1f, player y %.1f)"
			% [dropped.global_position.y, points[3].global_position.y, game.player.global_position.y])

	print("[1] The player hits an enemy")
	# Удари героя міряємо по ворогах, що стоять: живий AI б'є з випадковими серіями (D265), а з D264 кожен
	# його удар збиває героя й зриває його замах — звідси «то влучив, то ні» (feedback 4b). Бій AI — [2]–[2e].
	# Вимкнена фізика зупиняє лише нові удари: замах, що вже йде, — корутина на таймерах і б'є до кінця.
	for e in enemies:
		e.set_physics_process(false)
	while enemies.any(func(e: Node) -> bool: return e.enemy_logic.is_attacking) or game.player.combat.owns_animation():
		await physics_frame
	await create_timer(0.6).timeout  # невразливість після останнього удару минула
	var target = enemies[0]
	# Сусіди — подалі: зона-ціль = намальоване тіло (B128), і удар по цілі зачепив би й того, хто стоїть поруч
	var parked: Array = enemies.filter(func(e: Node) -> bool: return e != target)
	var parked_at: Array = parked.map(func(e: Node) -> Vector2: return e.global_position)
	for e in parked:  # і не під довгою алебардою (134 px, D268), і не впирають відкинутого ворога булавою
		e.global_position.x = target.global_position.x - 600
	var hits: Array = []
	target.damage_token.connect(func(d: int) -> void: hits.append(d))
	var hp_before: int = target.current_health
	var dmg: int = game.player.combat.hit_damage()
	game.player.global_position = target.global_position + Vector2(-30, 0)
	game.player.velocity = Vector2.ZERO
	await create_timer(0.05).timeout
	game.player.combat.perform_attack(1)
	await create_timer(0.6).timeout
	# B57: хітбокс бив і через DamageApplier, і через Hurtbox ворога — два ушкодження за удар.
	ck(hits == [dmg], "one hit = one damage event of %d (got %s)" % [dmg, hits])
	ck(target.current_health == hp_before - dmg, "enemy lost exactly %d HP (%d → %d)" % [dmg, hp_before, target.current_health])

	print("[1b] An attack facing away misses")
	hits.clear()
	hp_before = target.current_health
	game.player.global_position = target.global_position + Vector2(-30, 0)
	await create_timer(0.05).timeout
	game.player.combat.perform_attack(-1)
	await create_timer(0.6).timeout
	ck(hits.is_empty() and target.current_health == hp_before, "a miss deals no damage (events %s)" % [hits])

	print("[1e] An attack in the air lands (it used to be cancelled by Jump / Fall)")
	await create_timer(0.3).timeout
	hits.clear()
	game.player.global_position = target.global_position + Vector2(-30, -6)
	game.player.velocity = Vector2(0, -150)
	await physics_frame
	game.player.combat.perform_attack(1)
	await create_timer(0.6).timeout
	ck(hits == [dmg], "the airborne swing hits once for %d (got %s)" % [dmg, hits])
	target.heal_damage(dmg)  # далі цей ворог потрібен з тим самим HP

	print("[1c] The hit is the menu's Phys. Atk. and grows with the weapon (B62, D199)")
	var gm: Node = sl.get_game_manager()
	ck(dmg == gm.calculate_physical_damage(), "unarmed hit %d = Phys. Atk. %d" % [dmg, gm.calculate_physical_damage()])
	var sword: Dictionary = sl.get_item_database().get_item("iron_sword")
	var hero: String = gm.get_active_character().character_id
	sl.get_equipment_manager().equip_item(hero, "sword", "iron_sword", sword)
	await process_frame
	var armed: int = game.player.combat.hit_damage()
	ck(armed == dmg + int(sword.stats.attack), "iron_sword adds its attack %d (%d → %d)" % [int(sword.stats.attack), dmg, armed])
	hits.clear()
	hp_before = target.current_health
	game.player.global_position = target.global_position + Vector2(-30, 0)
	await create_timer(0.05).timeout
	game.player.combat.perform_attack(1)
	await create_timer(0.6).timeout
	ck(hits == [armed], "the armed hit deals %d (got %s)" % [armed, hits])
	sl.get_equipment_manager().unequip_item(hero, "sword")
	await process_frame

	print("[1d] Weapon in hand: reach, equip draws, knockback, bare hands (D202, D203, D475)")
	var em: Node = sl.get_equipment_manager()
	var items: Node = sl.get_item_database()
	em.equip_item(hero, "polearm", "iron_halberd", items.get_item("iron_halberd"))
	await process_frame
	ck(gm.player_state.weapon_in_hand == "polearm" and is_equal_approx(game.player.combat.attack_cooldown_time, 0.8),
			"the halberd is drawn: cooldown %.1f" % game.player.combat.attack_cooldown_time)
	target.current_health = target.Max_Health  # після [1]–[1c] у цілі 25 HP — алебарда (48) її б добила
	target.set_physics_process(false)  # стоїть на місці, поки міряємо дальність
	hits.clear()
	game.player.global_position = target.global_position + Vector2(-70, 0)
	await create_timer(0.1).timeout
	game.player.combat.perform_attack(1)
	await create_timer(0.5).timeout
	ck(hits.size() == 1, "the halberd reaches an enemy 70 px away (events %s)" % [hits])
	# Тут міряємо поштовх булави, а не відповідь ворога на удар (D713): ворог, що замахується, стоїть на місці
	target.answer_hits = 0
	target.enemy_logic.attack_ready_in = 99.0
	target.set_physics_process(true)
	await create_timer(0.9).timeout  # кулдаун алебарди
	em.equip_item(hero, "mace", "iron_mace", items.get_item("iron_mace"))
	await process_frame
	ck(gm.player_state.weapon_in_hand == "mace", "equipping the mace draws it (D475) (%s)" % gm.player_state.weapon_in_hand)
	ck(not InputMap.has_action(&"weapon_next") and not InputMap.has_action(&"weapon_prev"), "D475: no weapon-switch action")
	game.player.global_position = target.global_position + Vector2(-30, 0)
	await create_timer(0.1).timeout
	target.current_health = target.Max_Health  # удар булави (65) інакше вбив би ціль — мертвий не відлітає
	var x_before_hit: float = target.global_position.x
	hits.clear()
	game.player.combat.perform_attack(1)
	await create_timer(0.3).timeout
	ck(target.global_position.x - x_before_hit >= 40.0, "the mace knocks the enemy back (%.0f px)" % (target.global_position.x - x_before_hit))
	for i in parked.size():  # назад на свої місця — наступні кроки ставлять героя відносно них
		parked[i].global_position = parked_at[i]
	em.unequip_item(hero, "mace")
	em.unequip_item(hero, "polearm")
	await process_frame
	ck(gm.player_state.weapon_in_hand == "" and is_equal_approx(game.player.combat.attack_cooldown_time, 0.5),
			"nothing equipped → bare hands (%s, %.1f s)" % [gm.player_state.weapon_in_hand, game.player.combat.attack_cooldown_time])

	game.player.Max_Health = 9999  # D642: вороги б'ють сильніше й частіше — герой рівня 1 загинув би, і пауза Game Over спинила б решту перевірок
	game.player.current_health = game.player.Max_Health
	print("[2] Enemies chase and hit the player")
	game.player.current_health = game.player.Max_Health
	var player_hp: int = game.player.current_health
	game.player.global_position = enemies[1].global_position + Vector2(-60, 0)
	# Б'ється той, біля кого герой; решта, застиглі з [1], — подалі: їхні тіла (D443) стали б на шляху його ривку (D504)
	var others: Array = enemies.filter(func(e: Node) -> bool: return e != enemies[1])
	var others_at: Array = others.map(func(e: Node) -> Vector2: return e.global_position)
	for e in others:
		e.global_position.x = game.player.global_position.x - 600
	enemies[1].set_physics_process(true)
	for i in 40:  # до 8 с: серія випадкова (D265), а між ударами ворог задкує й чекає (D504)
		await create_timer(0.2).timeout
		if game.player.current_health < player_hp:
			break
	ck(game.player.current_health < player_hp, "player lost HP (%d → %d)" % [player_hp, game.player.current_health])
	ck(enemies[1].enemy_logic.current_state != 0 or enemies[2].enemy_logic.current_state != 0, "enemies left IDLE")
	enemies[1].set_physics_process(false)
	while enemies[1].enemy_logic.is_attacking:
		await physics_frame
	for i in others.size():
		others[i].global_position = others_at[i]

	print("[2b] Invulnerability frames (B60)")
	for e in enemies:
		e.set_physics_process(false)  # вороги не бʼють, поки міряємо
	# Замах, що вже йде, б'є до кінця (див. [1]); швидкий ворог з темпом 1.0 с (D394) частіше ловиться посеред серії
	while enemies.any(func(e: Node) -> bool: return e.enemy_logic.is_attacking):
		await physics_frame
	# B113: фіксована 1 с часом не покривала удар, що зачепив героя вже після серії, — вороги виходять із фізичного
	# світу (їхні хітбокси нікого не торкнуться), а невразливість від їхнього удару чекаємо до справжнього кінця.
	for e in enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 300:
		if not game.player.is_invulnerable:
			break
		await process_frame
	ck(not game.player.is_invulnerable, "the invulnerability from the enemies' last hit ends on its own")
	game.player.current_health = game.player.Max_Health
	var player_hits: Array = []
	game.player.damage_token.connect(func(d: int) -> void: player_hits.append(d))
	game.player.take_damage(5)
	game.player.take_damage(5)
	ck(player_hits == [5], "two hits in one frame on the player count once (got %s)" % [player_hits])
	await create_timer(game.player.invulnerability_duration + 0.1).timeout
	game.player.take_damage(5)
	ck(player_hits == [5, 5], "after the invulnerability window the player is hit again (got %s)" % [player_hits])
	var enemy_hp: int = enemies[2].current_health
	enemies[2].take_damage(1)
	enemies[2].take_damage(1)
	ck(enemies[2].current_health == enemy_hp - 2, "an enemy (no invulnerability) takes both hits (%d → %d)" % [enemy_hp, enemies[2].current_health])
	for e in enemies:
		e.process_mode = Node.PROCESS_MODE_INHERIT  # назад у світ; фізика лишається вимкненою, як далі чекає [2c]

	print("[2c] Enemy attack: wind-up, then the hitbox in front (B59, D198)")
	var attacker = enemies[1]
	var buddy = enemies[2]
	for e in enemies:  # D443: тіла тверді — герой, поставлений у сусіда, розштовхувався б із ним
		if e != attacker:
			e.global_position.x = attacker.global_position.x + 600
	attacker.combo_hits = 1  # тут — один удар D198; серії (D265) — verify_souls_combat
	var hits_p: Array = []
	game.player.damage_token.connect(func(d: int) -> void: hits_p.append(d))
	var swing: float = attacker.attack_windup + attacker.attack_active_time + 0.15
	await create_timer(0.6).timeout  # невразливість гравця з [2b] минула
	# Герой — на 6 px усередині намальованого удару ворога (D519: хітбокс — кадри удару; у шакала зграї кінчик
	# укусу ближче за 40 px)
	var strike: CollisionShape2D = attacker.get_node(^"hitbox/CollisionShape2D")
	var reach: float = absf(strike.position.x) + (strike.shape as RectangleShape2D).size.x / 2.0 + 12.0 - 6.0
	print("  info %s attacks, the hero %.1f px in front" % [attacker.enemy_stats.enemy_type, reach])
	game.player.global_position = Vector2(attacker.global_position.x + reach, game.player.global_position.y)
	await create_timer(0.2).timeout
	attacker.enemy_logic.last_direction = 1
	attacker.enemy_logic.perform_attack()
	await create_timer(attacker.attack_windup * 0.5).timeout
	ck(hits_p.is_empty(), "no damage during the wind-up (got %s)" % [hits_p])
	await create_timer(swing).timeout
	ck(hits_p == [int(attacker.damage)], "the swing hits the player in front once (got %s)" % [hits_p])

	# Фізика ворогів вимкнена — крок AI (process_ai) робимо самі: під час замаху він лише розвертає.
	# Відкидання з попередніх кроків без фізики не спливає — скидаємо, інакше process_ai чекає на нього.
	attacker.enemy_logic.knockback_left = 0.0
	await create_timer(0.6).timeout
	hits_p.clear()
	game.player.global_position = Vector2(attacker.global_position.x - reach, game.player.global_position.y)
	await create_timer(0.2).timeout
	attacker.enemy_logic.last_direction = 1
	attacker.enemy_logic.perform_attack()  # гравець за спиною на початку замаху
	attacker.enemy_logic.process_ai(0.0)
	await create_timer(swing).timeout
	ck(hits_p.size() == 1, "the enemy turns during the wind-up and hits the player behind (got %s)" % [hits_p])

	await create_timer(0.6).timeout
	hits_p.clear()
	game.player.global_position = Vector2(attacker.global_position.x + reach, game.player.global_position.y)
	attacker.enemy_logic.last_direction = 1
	attacker.enemy_logic.perform_attack()
	await create_timer(attacker.attack_windup - 0.25 + 0.05).timeout
	game.player.global_position = Vector2(attacker.global_position.x - reach, game.player.global_position.y)
	attacker.enemy_logic.process_ai(0.0)
	await create_timer(swing).timeout
	ck(hits_p.is_empty(), "late in the wind-up the swing is committed: getting behind dodges it (got %s)" % [hits_p])

	game.player.set_physics_process(false)
	game.player.global_position = attacker.global_position + Vector2(40, -90)
	attacker.enemy_logic.perform_attack()
	await create_timer(swing).timeout
	ck(hits_p.is_empty(), "the player above the enemy is not hit (got %s)" % [hits_p])
	game.player.set_physics_process(true)

	game.player.global_position = attacker.global_position + Vector2(-400, 0)
	buddy.global_position = attacker.global_position + Vector2(40, 0)
	var buddy_hp: int = buddy.current_health
	attacker.enemy_logic.perform_attack()
	await create_timer(swing).timeout
	ck(buddy.current_health == buddy_hp, "an enemy's swing does not hurt another enemy (%d → %d)" % [buddy_hp, buddy.current_health])

	print("[2d] Roll: distance, invulnerability, cooldown, no attack mid-roll (D200)")
	var pl = game.player
	var mover = pl.mover
	var dodge := InputEventAction.new()
	dodge.action = &"dodge"
	dodge.pressed = true
	var swing_ev := InputEventAction.new()
	swing_ev.action = &"attack"
	swing_ev.pressed = true
	pl.global_position = Vector2(attacker.global_position.x - 500, pl.global_position.y)
	await create_timer(0.8).timeout  # приземлився, невразливість минула
	mover.last_direction = 1
	var x0: float = pl.global_position.x
	var roll_hits: Array = []
	pl.damage_token.connect(func(d: int) -> void: roll_hits.append(d))
	pl._unhandled_input(dodge)
	ck(mover.is_rolling() and pl.is_invulnerable, "the roll starts and the player is invulnerable")
	pl.take_damage(5)
	pl._unhandled_input(swing_ev)
	ck(roll_hits.is_empty(), "no damage during the roll (got %s)" % [roll_hits])
	ck(not pl.combat.is_attacking, "no attack mid-roll")
	await create_timer(mover.roll_duration + 0.1).timeout
	ck(not mover.is_rolling() and not pl.is_invulnerable, "the roll ends, invulnerability with it")
	# Допуск — два фізичні кадри перекату.
	ck(absf(pl.global_position.x - x0 - mover.roll_distance) < mover.roll_distance / mover.roll_duration / 30.0, "rolled ~%.0f px right (%.1f)" % [mover.roll_distance, pl.global_position.x - x0])
	# D264: два ривки підряд, третій — після паузи
	pl._unhandled_input(dodge)
	ck(mover.is_rolling(), "a second roll right away (double dash, D264)")
	await create_timer(mover.roll_duration + 0.05).timeout
	pl._unhandled_input(dodge)
	ck(not mover.is_rolling(), "the cooldown blocks a third roll")
	await create_timer(mover.roll_cooldown).timeout
	pl._unhandled_input(dodge)
	ck(mover.is_rolling(), "a roll is possible again after the cooldown")
	await create_timer(mover.roll_duration + 0.1).timeout

	print("[2d'] Fall faces where the hero moves, both ways (Sapega 2026-10-20 «анімація падіння в одну сторону»)")
	var stand: Vector2 = pl.global_position
	for dir: StringName in [&"move_left", &"move_right"]:
		pl.global_position.y -= 300.0
		Input.action_press(dir)
		for i in 8: await physics_frame
		var falling_left: bool = pl.get_node("Sprite2D").flip_h
		ck(pl.animation == &"Fall" and falling_left == (dir == &"move_left"),
				"falling while holding %s: anim %s, flip_h %s" % [dir, pl.animation, falling_left])
		Input.action_release(dir)
		await create_timer(0.8).timeout  # приземлився
	# Назад на підлогу, звідки підняли: швидкі вороги (D738) встигають підійти, і герой падав би комусь на голову
	pl.global_position = stand
	pl.velocity = Vector2.ZERO
	await create_timer(0.3).timeout

	print("[2e] Enemy types: the tank's long armoured swing, the fast one's lunge (D208)")
	var type_hits: Array = []
	pl.damage_token.connect(func(d: int) -> void: type_hits.append(d))
	for e in enemies:
		e.global_position.x = pl.global_position.x - 400  # не заважають
	var tank = enemies[0]
	tank._apply_stats(load("res://SampleProject/Resources/Enemies/enemy_stats_tank.tres"))
	tank.current_health = tank.Max_Health
	await create_timer(0.6).timeout
	# Ставимо вже після очікування: живий AI ходить швидко (D738) і за 0.6 с відійшов би (B128: удар бандита-сцени сягає 34.5 px)
	tank.global_position = Vector2(pl.global_position.x + 40, tank.global_position.y)
	tank.enemy_logic.last_direction = -1
	tank.enemy_logic.perform_attack()
	await create_timer(0.5).timeout
	ck(type_hits.is_empty(), "the tank is still winding up at 0.5 s")
	tank.stun(0.5)
	ck(tank.enemy_logic.stun_left <= 0.0, "armour: a stun does not cancel the tank's swing")
	await create_timer(tank.attack_windup - 0.5 + 0.15).timeout
	ck(type_hits.size() == 1, "the tank's swing lands after its %.1f s wind-up (%s)" % [tank.attack_windup, type_hits])
	await create_timer(1.0).timeout
	type_hits.clear()
	tank.enemy_logic.perform_attack()
	await create_timer(0.2).timeout
	tank.knockback(60.0)  # як удар булавою посеред замаху
	await create_timer(0.9).timeout
	ck(type_hits.is_empty(), "a heavy hit (knockback) breaks the tank's swing (%s)" % [type_hits])
	var tank_hp: int = tank.current_health
	tank.enemy_logic.last_direction = 1 if pl.global_position.x > tank.global_position.x else -1
	tank.take_damage(20, pl)
	ck(tank.current_health == tank_hp - 6, "the tank's shell: a hit from the front deals 30 %% (%d → %d)" % [tank_hp, tank.current_health])
	tank_hp = tank.current_health
	tank.enemy_logic.last_direction *= -1
	tank.take_damage(20, pl)
	ck(tank.current_health == tank_hp - 20, "from behind, full damage (%d → %d)" % [tank_hp, tank.current_health])
	tank.global_position.x = pl.global_position.x - 400
	var fast = enemies.filter(func(e: Node) -> bool: return e.enemy_stats.enemy_type == "fast")[0]
	fast.set_physics_process(true)  # ривок рухає тіло
	fast.enemy_logic._lunge_rest = 60.0  # стрибок шакала (D740) тут ні до чого: удар тест веде сам (perform_attack)
	await create_timer(0.6).timeout
	# Ставимо вже після очікування: живий AI за 0.6 с відходить (B128: укус 34.5 + ривок 60 + пів героя 12 > 100)
	fast.global_position = Vector2(pl.global_position.x + 100, fast.global_position.y)
	type_hits.clear()
	var fast_x0: float = fast.global_position.x
	fast.enemy_logic.last_direction = -1
	fast.enemy_logic.perform_attack()
	await create_timer(fast.attack_windup + fast.attack_active_time + 0.1).timeout
	ck(fast_x0 - fast.global_position.x >= 40.0, "the fast enemy lunges forward (%.0f px)" % (fast_x0 - fast.global_position.x))
	ck(type_hits.size() == 1, "the lunge reaches a hero 100 px away (%s)" % [type_hits])
	fast.set_physics_process(false)
	for e in enemies:
		e.set_physics_process(true)

	print("[3] Enemy death runs to the end")
	var potions_before: int = inv.get_item_count("potion")
	var coins_before: int = inv.get_item_count("coin")
	game.player.current_health = game.player.Max_Health
	var victim = enemies[1]
	victim.die()
	await create_timer(1.0).timeout
	ck(victim.visible and victim.anim_player.current_animation == "death", "the death animation is shown, not skipped (F8)")
	var coins_dropped: int = victim.get_parent().get_children().filter(func(n: Node) -> bool: return n.scene_file_path == "res://SampleProject/Scenes/Gameplay/Objects/Coin.tscn").size()
	await create_timer(3.0).timeout
	ck(not victim.visible, "dead enemy is hidden")
	ck(not victim.is_alive(), "dead enemy is not alive")
	ck(coins_dropped > 0 or inv.get_item_count("coin") > coins_before, "death gave loot: coins (%d dropped)" % coins_dropped)
	ck(inv.get_item_count("potion") == potions_before, "no potions from a kill (4b)")

	for enemy in _enemies(road):
		if enemy.is_alive():
			enemy.die()
	await create_timer(1.0).timeout
	ck(game.get_quest_flag("desert_road_fight_complete"), "all dead → fight complete")

	print("[4] The player leaves the tree mid-attack (scene change)")
	var player: Node = game.player
	var combat: Node = player.combat
	await create_timer(combat.attack_cooldown_time).timeout
	combat.perform_attack(1)
	ck(combat.is_attacking, "attack started")
	game.remove_child(player)
	for i in 3: await process_frame
	ck(not combat.is_attacking, "attack ended off-tree, no get_tree() on null")
	game.add_child(player)

	ck(rolls.rolls <= rolls.CALM_ROLLS, "the fight stayed inside the calm rolls (%d of %d)" % [rolls.rolls, rolls.CALM_ROLLS])
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
