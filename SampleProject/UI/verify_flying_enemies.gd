extends SceneTree

## Летючі вороги (D445, D558, D582, D637; design/flying_enemies_plan.md, зрізи 1 і 2): гриф і кажан — той самий
## DefaultEnemy з FlyingLogic (EnemyStats.flying), без гравітації й без перевірок уступу.
##   [1] сцени й стати: форми з кадрів fly / dive / bite (D519), числа шакала (гриф) і половина (кажан);
##   [2] летючий ніколи не сідає: патруль і бій — у повітрі;
##   [3] гриф угорі недосяжний (зона-ціль вимкнена, удар героя не влучає), низько — влучає;
##   [4] піке після червоної підказки йде прямою лінією й влучає в героя, що стоїть;
##   [5] перекат під піке — промах;
##   [6] кажан кусає (біла підказка) й відлітає назад;
##   [7] поведінку вибирають стати, а не сцена; смерть — падає на землю й рахується в бестіарії;
##   [8] розстановка: гриф лише надворі, перший — сам, далі долучається до бою; кажанів у демо немає; муха Ктулху — одна, сама й еліта в Лабораторії (D589, D582).
##   godot --headless --path . --script res://SampleProject/UI/verify_flying_enemies.gd

const VULTURE := "res://SampleProject/Scenes/Characters/Enemies/enemy_vulture.tscn"
const BAT := "res://SampleProject/Scenes/Characters/Enemies/enemy_bat.tscn"
const FLY := "res://SampleProject/Scenes/Characters/Enemies/enemy_fly.tscn"
const STATS := "res://SampleProject/Resources/Enemies/enemy_stats_%s.tres"
## Рівна підлога DesertRoad (y 384) до сюжетного бою — тут тест ставить своїх ворогів.
const ARENA := Vector2(560, 368)
const FLOOR_Y := 384.0
const OUTDOORS := ["Canyon", "DesertRoad", "CityGates"]

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
var hit_areas: GDScript
## Скрипт логіки — не за class_name: тест компілюється раніше за автозавантаження, яких вона торкається.
var flying_logic: GDScript
var tells: Array = []

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	hit_areas = load("res://SampleProject/Scripts/Combat/HitAreas.gd")
	flying_logic = load("res://SampleProject/Scripts/Gameplay/Components/FlyingLogic.gd")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: banners, the game never pauses
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
	eb.enemy_tell_shown.connect(func(enemy: Node, kind: StringName) -> void: tells.append([enemy, kind, Time.get_ticks_msec()]))
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
	_clear_arena()
	await process_frame

	_scenes()
	await _never_lands()
	await _out_of_reach()
	await _dive_hits()
	await _roll_under()
	await _bat_bites()
	await _reuse_and_death()
	_placements()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## Чиста арена: вороги кімнати не заважають; герой — повний і на арені.
func _clear_arena() -> void:
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 9999
	hero.current_health = hero.Max_Health
	hero.global_position = Vector2(ARENA.x, FLOOR_Y - 24.0)
	hero.velocity = Vector2.ZERO

func _spawn(path: String, kind: String, at: Vector2) -> Node:
	var enemy: Node = load(path).instantiate()
	enemy.enemy_stats = load(STATS % kind)
	enemy.size_kind = "medium"
	enemy.position = at
	game.map.add_child(enemy)
	return enemy

func _shape_rect(enemy: Node, path: NodePath) -> Rect2:
	return hit_areas.shape_rect(enemy.get_node(path))

func _feet(enemy: Node) -> float:
	var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	return enemy.global_position.y + body.position.y + body.shape.get_rect().end.y

## [1] Сцени й стати.
func _scenes() -> void:
	print("[1] Scenes and stats: shapes from the fly / dive / bite frames (D519), provisional numbers (Q74)")
	var jackal: Resource = load(STATS % "fast")
	var vs: Resource = load(STATS % "vulture")
	var bs: Resource = load(STATS % "bat")
	ck(vs.flying and vs.flight_attack == "dive" and bs.flying and bs.flight_attack == "bite", "both kinds fly: the vulture dives, the bat bites")
	ck(vs.max_health == jackal.max_health and vs.base_damage == jackal.base_damage and vs.speed == jackal.speed
			and is_equal_approx(vs.attack_windup, 0.6) and vs.tell == "dodge",
			"vulture: the jackal's HP %d, damage %d, speed %d, a 0.6 s wind-up, a red tell" % [vs.max_health, vs.base_damage, vs.speed])
	# XP — менше за шакала: два грифи на дорозі не мають зсунути рівень 5 з останнього вбивства біля воріт (D280, verify_xp_curve)
	ck(vs.xp_reward * 2 < 15, "vulture XP %d: the oath level still lands on the last City Gates kill" % vs.xp_reward)
	ck(bs.max_health * 2 == jackal.max_health and bs.base_damage * 2 == jackal.base_damage and bs.tell == "block",
			"bat: half the jackal's HP (%d) and damage (%d), a white tell" % [bs.max_health, bs.base_damage])
	var fs: Resource = load(STATS % "fly")
	ck(fs.flying and fs.flight_attack == "bite" and fs.max_health == bs.max_health and fs.base_damage == bs.base_damage and fs.tell == "block",
			"Cthulhu fly: the bat's numbers (D589: it takes the bats' place), elite on top")
	for kind in ["vulture", "bat", "fly"]:
		var enemy: Node = load({"vulture": VULTURE, "bat": BAT, "fly": FLY}[kind]).instantiate()
		var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
		var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
		var stats: Resource = load(STATS % kind)
		var body: Rect2 = hit_areas.body_rect(sprite, anim)
		ck(_shape_rect(enemy, ^"Hurtbox/CollisionShape2D").is_equal_approx(body), "%s: hurtbox = the fly frames %s" % [kind, body])
		var strike: Rect2 = hit_areas.strike_rect(sprite, anim, stats.attack_active_time)
		if kind != "vulture":  # укус — зубами, від центру вперед (як у D519)
			strike = Rect2(Vector2(0, strike.position.y), Vector2(strike.end.x, strike.size.y))
		ck(_shape_rect(enemy, ^"hitbox/CollisionShape2D").is_equal_approx(strike), "%s: hitbox = the %s frames %s" % [kind, "dive" if kind == "vulture" else "bite", strike])
		enemy.free()

## [2] Ніколи не сідає: 2 с патруль без героя поруч, 4 с бій над героєм.
func _never_lands() -> void:
	print("[2] A flier never lands")
	for kind in ["vulture", "bat"]:
		hero.global_position = Vector2(ARENA.x - 600.0, FLOOR_Y - 24.0)
		var home := Vector2(ARENA.x, 250.0)
		var enemy: Node = _spawn(VULTURE if kind == "vulture" else BAT, kind, home)
		await physics_frame
		ck(enemy.enemy_logic.get_script() == flying_logic and enemy.collision_layer == 0, "%s: FlyingLogic, a body heroes and enemies pass under" % kind)
		var lowest := -INF
		var drift := 0.0
		for i in 120:
			await physics_frame
			drift = maxf(drift, absf(enemy.global_position.y - home.y))
		ck(drift <= 12.0, "%s: patrols at its height (drift %.1f px)" % [kind, drift])
		hero.global_position = Vector2(ARENA.x - 100.0, FLOOR_Y - 24.0)
		var chased := false
		for i in 240:
			await physics_frame
			lowest = maxf(lowest, _feet(enemy))
			chased = chased or enemy.enemy_logic.current_state != 0
			hero.current_health = hero.Max_Health
		ck(chased, "%s: chases the hero in the air" % kind)
		ck(lowest < FLOOR_Y - 1.0 and not enemy.is_on_floor(), "%s: never touches the floor (lowest feet y %.0f, floor %.0f)" % [kind, lowest, FLOOR_Y])
		enemy.queue_free()
		await physics_frame
	_clear_arena()

## [3] Гриф угорі недосяжний; низько — так.
func _out_of_reach() -> void:
	print("[3] The vulture cannot be hit while high")
	_clear_arena()
	var vulture: Node = _spawn(VULTURE, "vulture", Vector2(ARENA.x + 60.0, 230.0))
	await physics_frame
	vulture.enemy_logic.attack_ready_in = 999.0  # лише кружляє
	vulture.enemy_logic.change_state(1)  # CHASE
	for i in 90: await physics_frame
	var height: float = _feet(hero) - vulture.global_position.y
	ck(not vulture.reachable() and not vulture.get_node(^"Hurtbox").monitorable and vulture.hurt_rect() == Rect2(),
			"circling %.0f px over the hero's feet: no hurtbox" % height)
	var hp: int = vulture.current_health
	vulture.take_damage(10, hero)
	ck(vulture.current_health == hp, "a blow (or arrow, or skill) does nothing while it is high")
	# Справжній удар героя: гриф угорі просто перед ним — повз; той самий гриф низько — влучає
	vulture.set_physics_process(false)
	vulture.global_position = hero.global_position + Vector2(40.0 * hero.last_direction, -10.0)
	await physics_frame
	await _tap(&"attack")
	for i in 30: await physics_frame
	ck(vulture.current_health == hp, "the hero's swing through a high vulture misses (HP %d)" % vulture.current_health)
	vulture.enemy_logic.low = true
	vulture.get_node(^"Hurtbox").monitorable = true
	for i in 30: await physics_frame
	await _tap(&"attack")
	for i in 30: await physics_frame
	ck(vulture.current_health < hp, "the same swing hits it while it is low (HP %d → %d)" % [hp, vulture.current_health])
	vulture.queue_free()
	await physics_frame

## Гриф над героєм, готовий пікірувати.
func _diver() -> Node:
	_clear_arena()
	tells.clear()
	var vulture: Node = _spawn(VULTURE, "vulture", Vector2(ARENA.x + 80.0, 230.0))
	await physics_frame
	vulture.enemy_logic.change_state(1)
	return vulture

## [4] Піке влучає в героя, що стоїть.
func _dive_hits() -> void:
	print("[4] The dive hits a standing hero, after a red tell, along a straight line")
	var vulture: Node = await _diver()
	var logic: Node = vulture.enemy_logic
	var line: Array[Vector2] = []
	var hit_at := -1
	var low_seen := false
	var target := Vector2.ZERO
	for i in 600:
		await physics_frame
		if logic.phase == logic.Phase.DIVE:
			line.append(vulture.global_position)
			target = logic._target
			low_seen = low_seen or vulture.reachable()
		if hero.current_health < hero.Max_Health:
			hit_at = Time.get_ticks_msec()
			break
	ck(hit_at > 0, "the standing hero is hit (HP %d/%d)" % [hero.current_health, hero.Max_Health])
	ck(hero.Max_Health - hero.current_health == int(vulture.damage), "for the vulture's damage (%d)" % (hero.Max_Health - hero.current_health))
	ck(tells.size() >= 1 and tells[0][0] == vulture and tells[0][1] == &"dodge", "a red (dodge) tell first (%s)" % [tells.map(func(t: Array) -> StringName: return t[1])])
	ck(tells.size() >= 1 and hit_at - tells[0][2] >= 400, "the tell comes %d ms before the hit" % (hit_at - tells[0][2] if tells.size() > 0 else -1))
	var off := 0.0
	if line.size() >= 3:
		var dir: Vector2 = (target - line[0]).normalized()
		for p in line:
			off = maxf(off, absf((p - line[0]).cross(dir)))
	ck(line.size() >= 3 and off < 2.0, "the dive keeps one line, locked at the tell (%d frames, off by %.2f px)" % [line.size(), off])
	ck(low_seen, "it can be hit during the dive")
	# Після піке — набирає висоту, і стає недосяжним
	var climbed := false
	for i in 300:
		await physics_frame
		hero.current_health = hero.Max_Health
		if logic.phase == logic.Phase.NONE and not vulture.reachable():
			climbed = true
			break
	ck(climbed and _feet(hero) - vulture.global_position.y > 60.0, "then climbs back out of reach (%.0f px over the hero's feet)" % (_feet(hero) - vulture.global_position.y))
	vulture.queue_free()
	await physics_frame

## [5] Перекат під грифом: піке проходить повз.
func _roll_under() -> void:
	print("[5] The roll passes under the dive (D443)")
	var vulture: Node = await _diver()
	var logic: Node = vulture.enemy_logic
	var rolled := false
	var dove := false
	for i in 600:
		await physics_frame
		if logic.phase == logic.Phase.DIVE and not rolled and vulture.global_position.distance_to(hero.global_position) < 110.0:
			var toward: StringName = &"move_right" if vulture.global_position.x > hero.global_position.x else &"move_left"
			Input.action_press(toward)
			await _tap(&"dodge")
			Input.action_release(toward)
			rolled = true
		dove = dove or logic.phase == logic.Phase.DIVE
		if rolled and logic.phase == logic.Phase.NONE:
			break
	ck(rolled and dove, "the hero rolled as the vulture came down")
	ck(hero.current_health == hero.Max_Health, "the dive misses the rolling hero (HP %d/%d)" % [hero.current_health, hero.Max_Health])
	vulture.queue_free()
	await physics_frame

## [6] Кажан кусає й відлітає.
func _bat_bites() -> void:
	print("[6] A bat bites and backs off")
	_clear_arena()
	tells.clear()
	var bat: Node = _spawn(BAT, "bat", hero.global_position + Vector2(120.0, -20.0))
	await physics_frame
	bat.enemy_logic.change_state(1)
	var logic: Node = bat.enemy_logic
	var bitten := false
	var wave_min := INF
	var wave_max := -INF
	for i in 600:
		await physics_frame
		if not logic.is_attacking and logic.current_state == 1:
			wave_min = minf(wave_min, bat.global_position.y)
			wave_max = maxf(wave_max, bat.global_position.y)
		if hero.current_health < hero.Max_Health:
			bitten = true
			break
	ck(bitten and hero.Max_Health - hero.current_health == int(bat.damage), "the bat bites for %d" % (hero.Max_Health - hero.current_health))
	ck(tells.size() >= 1 and tells[0][1] == &"block", "after a white (block) tell")
	ck(wave_max - wave_min >= 10.0, "it flies in a wavy line (%.0f px up and down)" % (wave_max - wave_min))
	var near: float = absf(bat.global_position.x - hero.global_position.x)
	var backed := false
	var far := near
	for i in 240:
		await physics_frame
		hero.current_health = hero.Max_Health
		far = maxf(far, absf(bat.global_position.x - hero.global_position.x))
		backed = backed or logic.current_state == 3  # RETREAT
		if backed and logic.current_state == 1:
			break
	ck(backed and far - near >= 40.0, "then backs off (%.0f → %.0f px from the hero) and comes again" % [near, far])
	ck(bat.reachable(), "a bat can always be hit")
	bat.queue_free()
	await physics_frame

## [7] Поведінку вибирають стати (новий вид — свій аркуш і стати); смерть.
func _reuse_and_death() -> void:
	print("[7] The behaviour comes from the stats; death and the bestiary")
	_clear_arena()
	var other: Node = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	other.enemy_stats = load(STATS % "bat")
	other.position = Vector2(ARENA.x + 200.0, 260.0)
	game.map.add_child(other)
	await physics_frame
	ck(other.enemy_logic.get_script() == flying_logic and other.enemy_logic.style == &"bite" and other.flying,
			"any enemy scene with the bat's stats flies and bites like a bat (a new kind = a sheet + stats, D589)")
	other.queue_free()
	var journal: GDScript = load("res://SampleProject/Scripts/Systems/journal_records.gd")
	var before := _kills(journal, "vulture")
	var vulture: Node = _spawn(VULTURE, "vulture", Vector2(ARENA.x + 150.0, 240.0))
	await physics_frame
	vulture.enemy_logic.low = true
	vulture.take_damage(1000, hero)
	for i in 90: await physics_frame
	ck(vulture.is_dead and absf(_feet(vulture) - FLOOR_Y) < 3.0, "a dead vulture falls to the ground (feet y %.0f)" % _feet(vulture))
	ck(_kills(journal, "vulture") == before + 1, "the kill counts in the bestiary")
	var entries: Array = journal.enemies().map(func(e: Dictionary) -> String: return e.kind)
	ck(entries.has("vulture"), "the bestiary has the vulture (%s)" % [entries])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var kinds: Array = data.enemies.map(func(e: Dictionary) -> String: return e.kind)
	ck(kinds.has("vulture") and kinds.has("bat"), "bestiary.json: vulture and bat entries")
	for e: Dictionary in data.enemies:
		if e.kind in ["vulture", "bat"]:
			for po in ["en", "uk"]:
				var text := FileAccess.get_file_as_string("res://SampleProject/Resources/Translations/%s.po" % po)
				ck(text.contains('msgid "%s"' % e.name) and text.contains('msgid "%s"' % e.text), "%s.po: %s" % [po, e.name])

func _kills(journal: GDScript, kind: String) -> int:
	for e: Dictionary in journal.enemies():
		if e.kind == kind:
			return e.kills
	return 0

## [8] Розстановка (D558, D582, D589).
func _placements() -> void:
	print("[8] Placements")
	var spawn_script: Script = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	var vultures: Array = []
	var flies: Array = []
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var room: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for p: Node in room.find_children("*", "Node2D", true, false):
			if p.get_script() != spawn_script:
				continue
			if p.enemy_type == "bat":
				ck(false, "%s: no bats in the demo (no cave room; the Laboratory gets the Cthulhu flies, D589)" % file)
			if p.enemy_type == "fly":
				var spawner: Node = p.get_parent()
				flies.append([file.get_basename(), spawner.get_child_count() - 1, p.elite, p.size])
			if p.enemy_type == "vulture":
				vultures.append([file.get_basename(), String(p.get_parent().name), p.position])
		room.free()
	print("  info vultures: %s" % [vultures])
	# Trigger — теж дитина спавнера, тому точок = дітей − 1
	ck(flies == [["Laboratory", 1, "always", "medium"]], "one Cthulhu fly, in the Laboratory, alone, always elite, medium (%s)" % [flies])
	ck(vultures.size() >= 2 and vultures.all(func(v: Array) -> bool: return v[0] in OUTDOORS), "vultures only outdoors (%d)" % vultures.size())
	var map: Node = game.map
	var lone: Node = map.get_node(^"Fight_LoneVulture")
	var first: Node = lone.spawn_points[0]
	ck(lone.spawn_points.size() == 1 and first.enemy_type == "vulture" and lone.variant_size(first) == "medium" and not lone.variant_elite(first),
			"DesertRoad: the first vulture comes alone, medium, never elite")
	var road: Array = vultures.filter(func(v: Array) -> bool: return v[0] == "DesertRoad")
	ck(road.all(func(v: Array) -> bool: return v[2].x >= first.position.x or v[1] == "Fight_LoneVulture"), "no vulture on the road before the lone one")
	var caravan: Array = map.get_node(^"Fight_Caravan").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(caravan.back() == "vulture" and caravan.size() > 1, "later a vulture joins the Caravan's ground fight, last (%s)" % [caravan])
	var lone_x: float = first.global_position.x
	for name in ["Fight_LoneShield", "Fight_Dunes"]:
		var zone: Area2D = map.get_node(NodePath(name)).trigger_area
		ck(absf(zone.global_position.x - lone_x) >= 120.0, "%s's zone is %.0f px from the lone vulture" % [name, absf(zone.global_position.x - lone_x)])
