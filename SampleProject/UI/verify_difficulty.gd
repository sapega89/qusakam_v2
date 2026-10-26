extends SceneTree

## Складність (D642): чи бій досі важкий. Безголова симуляція рахує з тих самих формул, що й гра — Player.max HP і
## mitigated_damage, PlayerCombat.hit_damage і серія, SkillManager.skill_damage / skill_heal, справжні вороги з
## EnemyStats і enemy_variety.json (розмір, еліта) і боси зі своїх сцен — без жодної копії чисел.
## Рівень, на якому герой стрічає кожного ворога, — з XP-кривої й порядку кімнат (як verify_xp_curve), спорядження —
## те, що дає маршрут: мідний меч і шкіряна броня діда до Міста, із Міста — залізні меч, броня й щит (крамниці).
## Дві збірки: STRENGTH — усі очки атрибутів у Strength, JP не витрачені; SKILLS — очки 2 Strength / 2 Vitality /
## 1 Wisdom за рівень, JP на активні й пасивні навички дерева (Paladin після клятви).
##   [1] звичайний ворог: SKILLS-герой падає за 5–6 ударів і валить ворога за 4–6 своїх;
##   [2] бос: валить героя за 3–4 удари, падає приблизно за 40 (34–46) ударів SKILLS-героя;
##   [3] еліта (вид-еліта й заплановані великі види в точках BigSlot_*, D652) і бос: SKILLS-герой перемагає, STRENGTH — ні;
##   [4] найважчий хід боса не вбиває героя з повним HP одним ударом; [5] Strength дає спадну віддачу.
## Уроки навчання (D-28c) лишаються прохідними — це перевіряє verify_onboarding.
## Удар героя — легка серія (COMBO_DAMAGE) без криту, зі спини (панцир tank, щит shield-bearer); удар ворога —
## звичайний удар (у боса — удар комбо), герой не блокує й не ухиляється. «Перемагає»: за бій у N ударів герой
## пропускає ceil(N / OPENINGS) ударів (OPENINGS — скільки разів добрий гравець б'є на кожен пропущений удар)
## і має пережити їх із флягою (Healing Palm, усі заряди).
##   godot --headless --path . --script res://SampleProject/UI/verify_difficulty.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")

## Маршрут у порядку історії (verify_xp_curve: ROUTE + LAB_ROUTE).
const ROUTE := ["Canyon", "Village", "DesertRoad", "CityGates", "City", "MayorHall", "LabCells", "Laboratory", "LabBoss"]
const CITY := "City"
const KIND_NAMES := {"melee": "bandit", "bandit_brute": "bandit brute", "fast": "jackal", "tank": "scorpion", "archer": "archer", "shield": "shield-bearer",
		"vulture": "vulture", "bat": "bat", "fly": "Cthulhu fly",
		"jackal_cursed": "cursed jackal",
		"jackal_pack_leader": "jackal pack leader",
		"armoured_scorpion": "armoured scorpion",
		"heavy_archer": "heavy archer",
		"old_vulture": "old vulture",
		"tower_shield_guard": "tower shield guard"}
const GEAR_ROAD := {"sword": "copper_sword", "body": "leather_armor"}
const GEAR_CITY := {"sword": "iron_sword", "body": "iron_armor", "shield": "iron_shield"}
## Очки атрибутів SKILLS-збірки на кожен рівень.
const SKILL_ATTRIBUTES := {"strength": 2, "vitality": 2, "wisdom": 1}
## Порядок навчання SKILLS-збірки: що можна — вчиться, решта JP — у ранги активних.
const SKILL_ORDER := ["toughness", "shield_block", "weapon_training", "radiant_smite", "devotion", "fire_strike",
		"riposte_instinct", "aura_of_resolve", "mending_hands", "skys_grace", "skyfall_blessing", "fortitude", "last_stand"]
const OATH := "paladin"
## Клятва й дерево професії відкриваються на 5-му рівні (D280).
const OATH_LEVEL := 5
const OPENINGS := {"ordinary": 2, "elite": 4, "boss": 10}

const ORDINARY_TAKEN := [5, 6]
const ORDINARY_DEALT := [4, 6]
const BOSS_TAKEN := [3, 4]
const BOSS_DEALT := [34, 46]

var fails: Array[String] = []
## Бої маршруту: {fight, hero (рівень героя на початку), enemy (enemy_level)}.
var fights: Array[Dictionary] = []
var sl: Node
var game: Node
var hero: Node
## Скрипти гри вантажаться після автозавантажень (preload у SceneTree-скрипті їх ще не бачить).
var Rolls: Script
var SpawnPoint: Script
var Spawner: Script
var Variety: Script
var Boss: Script

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	Rolls = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	SpawnPoint = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	Spawner = load("res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd")
	Variety = load("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
	Boss = load("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	game = await Kit.boot(self)
	sl = root.get_node("ServiceLocator")
	hero = game.player
	hero.set_physics_process(false)

	var meetings := _meetings()
	meetings.append(_unplaced("old_vulture", "DesertRoad/Fight_Caravan"))
	meetings.append(_side_room("heavy_archer", "BanditCamp", ^"Fight_Camp"))
	for fight in ["DesertRoad/Fight_Caravan", "Laboratory/Fight_Lower"]:
		meetings.append(_tower_guard_at(fight))
	print("[0] each fight's enemy_level is the hero's level when he gets there (XP curve, room order)")
	for fight: Dictionary in fights:
		ck(fight.enemy == fight.hero, "%s: enemy_level %d, hero level %d" % [fight.fight, fight.enemy, fight.hero])
	print("[0b] D582: a big or cursed kind that is live meets the hero first with no other big or cursed kind beside it")
	var met := {}
	for fight: Dictionary in fights:
		for id: String in fight.big:
			if Variety.available(id) and not met.has(id):
				met[id] = true
				var others: Array = fight.big.filter(func(other: String) -> bool: return other != id)
				ck(others.is_empty(), "%s first meets the hero in %s, with no other big or cursed kind (%s)" % [id, fight.fight, others])
	var rows: Array[Dictionary] = []
	print("    the table: H = enemy hits that kill the hero, N = hero hits that kill it (flask in H+F)")
	print("    %-26s %3s %-8s %5s %4s %4s %3s %4s %5s %4s %4s %s" % ["enemy", "lvl", "build", "HP", "hit", "got", "H", "H+F", "e.HP", "atk", "N", "wins"])
	for meeting: Dictionary in meetings:
		for build: String in ["STRENGTH", "SKILLS"]:
			var row := await _fight(meeting, build)
			rows.append(row)
			print("    %-26s %3d %-8s %5d %4d %4d %3d %4d %5d %4d %4d %s" % [row.name, row.level, build, row.hero_hp, row.enemy_hit,
					row.got, row.taken, row.taken_flask, row.enemy_hp, row.atk, row.dealt, "yes" if row.wins else "no"])

	print("[1] an ordinary enemy: 5–6 hits kill the SKILLS hero, 4–6 of his kill it")
	for row in rows:
		if row.cls == "ordinary" and row.build == "SKILLS":
			ck(_in(row.taken, ORDINARY_TAKEN) and _in(row.dealt, ORDINARY_DEALT),
					"%s at level %d: %d hits kill the hero (%s), %d hits kill it (%s)" % [row.name, row.level, row.taken,
					ORDINARY_TAKEN, row.dealt, ORDINARY_DEALT])

	print("[2] a boss: 3–4 hits kill the SKILLS hero, about 40 of his kill it")
	for row in rows:
		if row.cls == "boss" and row.build == "SKILLS":
			ck(_in(row.taken, BOSS_TAKEN) and _in(row.dealt, BOSS_DEALT), "%s at level %d: %d hits kill the hero (%s), %d hits kill it (%s)"
					% [row.name, row.level, row.taken, BOSS_TAKEN, row.dealt, BOSS_DEALT])

	print("[3] skills make the difference: from the oath on, elites and bosses fall to the SKILLS hero, not to the STRENGTH one")
	print("    (before the oath both builds hold ≤ 4 JP and no active skill, so the road's lone elite must fall to either)")
	for row in rows:
		if row.cls in ["elite", "boss"]:
			ck(row.wins == (row.build == "SKILLS" or row.level < OATH_LEVEL), "%s at level %d, %s: %s (%d hits needed, %d blows taken, survives %d)"
					% [row.name, row.level, row.build, "wins" if row.wins else "loses", row.dealt,
					ceili(float(row.dealt) / OPENINGS[row.cls]), row.taken_flask - 1])

	print("[3b] the cursed jackal (D589, D652) is a live elite of its own in the Laboratory, not a planned one, and meets [3]")
	var cursed := rows.filter(func(r: Dictionary) -> bool: return String(r.name).begins_with("elite cursed jackal"))
	ck(cursed.size() >= 2 and cursed.all(func(r: Dictionary) -> bool: return r.cls == "elite" and r.wins == (r.build == "SKILLS")),
			"cursed jackal rows: %s" % [cursed.map(func(r: Dictionary) -> String: return "%s %s %s" % [r.name, r.build, "wins" if r.wins else "loses"])])
	print("[3c] the jackal pack leader (D652, D692) is a live elite of its own on the road, not a planned one, and meets [3]")
	var leader := rows.filter(func(r: Dictionary) -> bool: return String(r.name).begins_with("elite jackal pack leader"))
	ck(leader.size() >= 2 and rows.all(func(r: Dictionary) -> bool: return not String(r.name).begins_with("planned jackal_pack_leader"))
			and leader.all(func(r: Dictionary) -> bool: return r.cls == "elite" and r.wins == (r.build == "SKILLS" or r.level < OATH_LEVEL)),
			"pack leader rows: %s" % [leader.map(func(r: Dictionary) -> String: return "%s at level %d %s %s, HP %d, hit %d" % [r.name, r.level, r.build, "wins" if r.wins else "loses", r.enemy_hp, r.enemy_hit])])
	print("[3d] the bandit brute (D652, D693) is a live elite of its own, on the road and in the Laboratory, and meets [3]")
	var brutes := rows.filter(func(r: Dictionary) -> bool: return String(r.name).begins_with("elite bandit brute"))
	ck(brutes.size() >= 4 and rows.all(func(r: Dictionary) -> bool: return not String(r.name).begins_with("planned bandit_brute"))
			and brutes.all(func(r: Dictionary) -> bool: return r.cls == "elite" and r.wins == (r.build == "SKILLS" or r.level < OATH_LEVEL)),
			"brute rows: %s" % [brutes.map(func(r: Dictionary) -> String: return "%s at level %d %s %s, HP %d, hit %d" % [r.name, r.level, r.build, "wins" if r.wins else "loses", r.enemy_hp, r.enemy_hit])])

	print("[4] a boss's heaviest move takes a big bite but never kills a full-HP hero at once (a death reads as a missed roll)")
	for row in rows:
		if row.cls == "boss":
			ck(row.heavy_taken >= 2, "%s, %s: its heaviest move (%d) kills in %d hits" % [row.name, row.build, row.heavy, row.heavy_taken])

	print("[5] Strength gives diminishing returns (D642)")
	await _make_hero(20, true, "NONE")
	var gm: Node = sl.get_game_manager()
	var attrs: Node = sl.get_attribute_manager()
	var steps: Array[int] = []
	for i in 4:
		var before: int = gm.calculate_physical_damage()
		attrs.spend({"strength": 10})
		steps.append(gm.calculate_physical_damage() - before)
	ck(steps[0] == 10 and steps[1] < steps[0] and steps[2] < steps[1] and steps[3] < steps[2],
			"each 10 points of Strength add less Phys. Atk. (%s)" % [steps])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


func _in(value: int, window: Array) -> bool:
	return value >= window[0] and value <= window[1]


## Де герой стрічає ворогів: кожен бій (RoomEnemySpawner) на маршруті — рівень героя на його початку (XP — з EnemyStats
## точок, як verify_xp_curve) і enemy_level бою; вид точки, його еліта (D652: властивість виду) і рівні — одна зустріч.
## Точка BigSlot_* (великий вид без арту) дає ще й «заплановану» зустріч: звичайний вид з множниками еліти — так
## видно, чи бій витримає великий вид, коли той зʼявиться. Боси — їхні кімнати. Точка поза спавнером — бій рівня 1.
func _meetings() -> Array[Dictionary]:
	var xp: Node = sl.get_xp_manager()
	xp.reset()
	var out: Array[Dictionary] = []
	var seen := {}
	var city := false
	for room_name: String in ROUTE:
		city = city or room_name == CITY
		var room: Node = (load("res://SampleProject/Maps/%s.tscn" % room_name) as PackedScene).instantiate()
		var starts := {}
		var room_xp := 0
		for node: Node in room.find_children("*", "", true, false):
			if node.get_script() == SpawnPoint:
				var spawner: Node = node.get_parent() if node.get_parent().get_script() == Spawner else null
				var fight: String = "%s/%s" % [room_name, spawner.name if spawner else node.name]
				if not starts.has(fight):
					starts[fight] = xp.current_level
					fights.append({"fight": fight, "hero": xp.current_level, "enemy": spawner.enemy_level if spawner else 1, "big": []})
				if Variety.is_elite(node.kind()) or node.big_kind != "none":
					fights.filter(func(f: Dictionary) -> bool: return f.fight == fight)[0].big.append(node.kind() if node.big_kind == "none" else node.big_kind)
				var enemy_level: int = spawner.enemy_level if spawner else 1
				var kind: String = node.kind()
				var kinds: Array[bool] = [Variety.is_elite(kind)]
				if node.big_kind != "none" and kind != node.big_kind:
					kinds.append(true)  # заплановано: великий вид на місці звичайного
				for elite: bool in kinds:
					var planned: bool = elite and not Variety.is_elite(kind)
					var key := "%s|%s|%d|%d" % [node.big_kind if planned else kind, elite, starts[fight], enemy_level]
					if seen.has(key):
						continue
					seen[key] = true
					var label: String = ("planned %s as %s" % [node.big_kind, KIND_NAMES[kind]]) if planned \
							else "%s%s" % ["elite " if elite else "", KIND_NAMES[kind]]
					out.append({"cls": "elite" if elite else "ordinary", "kind": kind, "level": starts[fight],
							"enemy_level": enemy_level, "city": city, "stats": node.enemy_stats(), "planned": planned,
							"name": "%s L%d" % [label, enemy_level]})
				xp.add_xp(node.enemy_stats().xp_reward)
			elif node.get_script() == Boss:
				out.append({"cls": "boss", "kind": "boss", "name": String(node.display_name).trim_prefix("The "), "level": xp.current_level, "city": city,
						"scene": node.scene_file_path})
				room_xp += node.enemy_stats.xp_reward
		xp.add_xp(room_xp)
		room.free()
	return out


## Вартовий з баштовим щитом (D652, D693) — живий, але D682 не дала йому точки BigSlot_*: зустріч у бою [param fight],
## де стоїть звичайний щитоносець, на його рівні — щоб числа еліти пройшли ту саму перевірку [3] до клятви й після.
func _tower_guard_at(fight: String) -> Dictionary:
	var at: Dictionary = fights.filter(func(f: Dictionary) -> bool: return f.fight == fight)[0]
	return {"cls": "elite", "kind": "tower_shield_guard", "level": at.hero, "enemy_level": at.enemy, "city": fight.begins_with("Laboratory"),
			"stats": load("res://SampleProject/Resources/Enemies/enemy_stats_tower_shield_guard.tres"), "planned": false,
			"name": "%s (unplaced) L%d" % [KIND_NAMES.tower_shield_guard, at.enemy]}


## Великий вид, що вперше стоїть у бічній кімнаті поза ROUTE (D719: великий лучник — у таборі бандитів, D698): зустріч
## на рівні того бою (рівень бічної кімнати задано, D698), щоб числа еліти пройшли ту саму перевірку [3].
func _side_room(id: String, room_name: String, fight: NodePath) -> Dictionary:
	var room: Node = (load("res://SampleProject/Maps/%s.tscn" % room_name) as PackedScene).instantiate()
	var spawner: Node = room.get_node(fight)
	var slots: Array = spawner.get_children().filter(func(n: Node) -> bool: return n.get_script() == SpawnPoint and n.big_kind == id)
	ck(slots.size() == 1 and slots[0].kind() == id, "%s first stands in %s/%s (D719)" % [id, room_name, fight])
	var level: int = spawner.enemy_level
	room.free()
	return {"cls": "elite", "kind": id, "level": level, "enemy_level": level, "city": false,
			"stats": load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % id), "planned": false,
			"name": "%s (%s) L%d" % [KIND_NAMES[id], room_name, level]}


## Одна бійка: герой рівня зустрічі зі збіркою [param build] проти справжнього ворога.
## Живий великий вид, якого ще не поставлено на карту (D682 не дала старому грифу точки BigSlot_*): зустріч у бою
## [param fight], де літає звичайний гриф, на його рівні — щоб числа еліти пройшли ту саму перевірку [3].
func _unplaced(id: String, fight: String) -> Dictionary:
	var at: Dictionary = fights.filter(func(f: Dictionary) -> bool: return f.fight == fight)[0]
	return {"cls": "elite", "kind": id, "level": at.hero, "enemy_level": at.enemy, "city": false,
			"stats": load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % id), "planned": false,
			"name": "%s (unplaced) L%d" % [KIND_NAMES[id], at.enemy]}


func _fight(meeting: Dictionary, build: String) -> Dictionary:
	await _make_hero(meeting.level, meeting.city, build)
	var enemy := _enemy(meeting)
	add_child_enemy(enemy)
	await process_frame
	var hit: int = roundi(enemy.damage)
	var row := {"cls": meeting.cls, "name": meeting.name, "level": meeting.level, "build": build, "hero_hp": hero.Max_Health,
			"enemy_hit": hit, "enemy_hp": enemy.Max_Health}
	row.taken = _hits_to_kill_hero(hit, 0)
	Rolls.calm()
	row.got = hero.mitigated_damage(hit)
	Rolls.calm()
	row.atk = hero.combat.hit_damage()
	var flask: int = sl.get_skill_manager().get_charges("healing_palm") * sl.get_skill_manager().skill_heal("healing_palm") \
			if sl.get_skill_manager().is_unlocked("healing_palm") else 0
	row.taken_flask = _hits_to_kill_hero(hit, flask)
	row.dealt = _hits_to_kill(enemy.Max_Health)
	row.wins = ceili(float(row.dealt) / OPENINGS[meeting.cls]) < row.taken_flask
	if meeting.cls == "boss":
		var heaviest := 1.0
		for move: Dictionary in enemy.moves:
			heaviest = maxf(heaviest, float(move.get("damage", 1.0)))
		row.heavy = roundi(enemy.damage * heaviest)  # BossLogic._damage
		row.heavy_taken = _hits_to_kill_hero(row.heavy, 0)
	enemy.queue_free()
	await process_frame
	return row


func add_child_enemy(enemy: Node) -> void:
	enemy.position = Vector2(-100000, -100000)
	game.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED


func _enemy(meeting: Dictionary) -> Node:
	if meeting.cls == "boss":
		return (load(meeting.scene) as PackedScene).instantiate()
	var enemy: Node = (load(SpawnPoint.scene_path(meeting.kind)) as PackedScene).instantiate()
	enemy.enemy_stats = meeting.stats
	enemy.size_kind = "medium"
	enemy.level = meeting.enemy_level
	if meeting.planned:
		enemy.ready.connect(_as_elite.bind(enemy))
	return enemy


## Заплановний великий вид (D652) поки що — звичайний з множниками еліти D560 (його статів ще немає).
func _as_elite(enemy: Node) -> void:
	var marks: Dictionary = Variety.elite()
	enemy.Max_Health = roundi(enemy.Max_Health * marks.health)
	enemy.current_health = enemy.Max_Health
	enemy.base_damage *= marks.damage
	enemy.damage = enemy.base_damage


## Герой рівня [param level]: усе забуто, очки рівня видано наново й розкладено за збіркою (NONE — не вкладено нічого).
func _make_hero(level: int, city: bool, build: String) -> void:
	var sm: Node = sl.get_skill_manager()
	var attrs: Node = sl.get_attribute_manager()
	var gm: Node = sl.get_game_manager()
	sm._forget_all()
	sl.get_xp_manager().restore(level, 0)
	attrs._set_unspent(attrs.points_for_level(level))
	sm._set_job_points(sm.JP_PER_LEVEL * (level - 1))
	gm.player_state.oath = OATH if build == "SKILLS" and level >= OATH_LEVEL else ""
	if level >= 2:
		sm.unlock_skill("healing_palm")  # фляга (D504) — в обох збірок, без JP
	sm.refill_charges()
	var hero_id: String = gm.get_active_character().character_id
	var em: Node = sl.get_equipment_manager()
	for slot: String in ["sword", "body", "shield"]:
		em.unequip_item(hero_id, slot)
	var gear: Dictionary = GEAR_CITY if city else GEAR_ROAD
	for slot: String in gear:
		em.equip_item(hero_id, slot, gear[slot], sl.get_item_database().get_item(gear[slot]))
	await process_frame
	var points: int = attrs.get_unspent()
	if build == "STRENGTH":
		attrs.spend({"strength": points})
	elif build == "SKILLS":
		var per_level := 0
		for id: String in SKILL_ATTRIBUTES:
			per_level += SKILL_ATTRIBUTES[id]
		var allocation := {}
		for id: String in SKILL_ATTRIBUTES:
			allocation[id] = points * SKILL_ATTRIBUTES[id] / per_level
		if points > 0:
			attrs.spend(allocation)
		var learned := true
		while learned:
			learned = false
			for id: String in SKILL_ORDER:
				if not sm.is_unlocked(id) and sm.can_unlock(id) == sm.Result.OK:
					sm.unlock_skill(id)
					learned = true
		for id: String in _actives():
			while sm.can_upgrade(id) == sm.Result.OK:
				sm.upgrade_skill(id)
	hero.refresh_max_health()
	hero.current_health = hero.Max_Health
	sm._set_current_sp(sm.get_max_sp())


## Вивчені активні навички з ушкодженням, найсильніша перша.
func _actives() -> Array[String]:
	var sm: Node = sl.get_skill_manager()
	var out: Array[String] = []
	for id: String in sm.get_unlocked_skills():
		if sm.skill_database.get_skill(id).is_active() and sm.skill_database.get_skill(id).damage > 0:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return sm.skill_damage(a) > sm.skill_damage(b))
	return out


## Скільки ударів [param hit] вбивають героя (з [param heal] HP фляги зверху). Умовні пасивки бачать справжнє HP.
func _hits_to_kill_hero(hit: int, heal: int) -> int:
	var pool: int = hero.Max_Health + heal
	var hits := 0
	while pool > 0:
		hero.current_health = mini(pool, hero.Max_Health)
		Rolls.calm()
		pool -= hero.mitigated_damage(hit)
		hits += 1
	hero.current_health = hero.Max_Health
	return hits


## Скільки дій героя вбивають ворога з [param health] HP: бій починається з 0 SP; навичка, щойно SP вистачає (найсильніша з доступних;
## ультимат — раз за бій), інакше легкий удар серії, що дає SP.
func _hits_to_kill(health: int) -> int:
	var sm: Node = sl.get_skill_manager()
	var combat: Node = hero.combat
	var combo: Array[float] = combat._combo_damage()
	var sp := 0.0  # SP — лише з влучань цього бою (D504), без запасу з попередніх
	var used := {}
	var left := health
	var hits := 0
	var step := 0
	while left > 0:
		var cast := ""
		for id: String in _actives():
			var definition = sm.skill_database.get_skill(id)
			if definition.sp_cost <= sp and not used.has(id) and sm._has_required_weapon(definition):
				cast = id
				break
		if cast != "":
			var definition = sm.skill_database.get_skill(cast)
			sp -= definition.sp_cost
			if definition.ultimate:
				used[cast] = true
			left -= sm.skill_damage(cast) + roundi(sm.scaled(cast, definition.burn_dps) * definition.burn_duration)
		else:
			Rolls.calm()
			left -= roundi(combat.hit_damage() * combo[step % combo.size()])
			step += 1
			sp = minf(sp + sm.SP_PER_HIT + sm.sp_per_hit_bonus(), sm.get_max_sp())
		hits += 1
	return hits
