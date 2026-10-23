extends SceneTree

## Різновиди ворогів (D495, D560, D582; design/enemy_variety_plan.md): розміри (спрайт, форми B128 і стати з
## enemy_variety.json), еліта (1 з 8, засіяна кімнатою й точкою; HP ×2.5, шкода ×1.5, контур і трохи більша), щитоносець
## (удар спереду — у щит, у спину — по тілу, важкий розбиває щит і збиває його) і розстановка по кімнатах.
##   godot --headless --path . --script res://SampleProject/UI/verify_enemy_variety.gd

const SCENES := {
	"melee": "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn",
	"tank": "res://SampleProject/Scenes/Characters/Enemies/enemy_tank.tscn",
	"fast": "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn",
	"shield": "res://SampleProject/Scenes/Characters/Enemies/enemy_shield.tscn",
}
## Рівна підлога DesertRoad (y 384) до сюжетного бою — тут тест ставить своїх ворогів.
const ARENA := Vector2(560, 368)

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
## Скрипти проєкту — не за class_name: тест компілюється раніше за автозавантаження, яких вони торкаються.
var variety: GDScript

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	variety = load("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: banners, the game never pauses
	await process_frame
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
	hero.Max_Health = 9999
	hero.current_health = hero.Max_Health
	# Чиста арена: вороги кімнати не заважають
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	await process_frame

	await _sizes()
	await _elites()
	_placements()
	await _shield()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## Ворог [param kind] розміру [param size_kind] (еліта — [param elite]) на арені, на [param dx] від її центру.
func _spawn(kind: String, size_kind: String, elite: bool, dx: float) -> Node:
	var enemy: Node = load(SCENES[kind]).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	enemy.size_kind = size_kind
	enemy.elite = elite
	enemy.position = ARENA + Vector2(dx, 0)
	game.map.add_child(enemy)
	return enemy

func _rect_size(shape: CollisionShape2D) -> Vector2:
	return (shape.shape as RectangleShape2D).size

func _feet(enemy: Node) -> float:
	var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	return body.position.y + _rect_size(body).y / 2.0

func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01

## [1] Розміри (D560): small ×0.8, medium ×1.0, large ×1.3 — спрайт, тіло, хітбокс, зона-ціль, дальність удару й стати.
func _sizes() -> void:
	print("[1] Sizes: small x0.8, medium x1.0, large x1.3 — sprite, shapes (D519) and stats from data")
	var sizes: Dictionary = variety.data().sizes
	ck(is_equal_approx(sizes.small.scale, 0.8) and is_equal_approx(sizes.medium.scale, 1.0) and is_equal_approx(sizes.large.scale, 1.3),
			"enemy_variety.json: 0.8 / 1.0 / 1.3")
	for kind in ["melee", "tank", "fast"]:
		var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
		var base: Node = _spawn(kind, "medium", false, -200)
		await process_frame
		var sprite_scale: Vector2 = base.get_node(^"Sprite2D").scale
		var hurt: Vector2 = _rect_size(base.get_node(^"Hurtbox/CollisionShape2D"))
		var strike: Vector2 = _rect_size(base.get_node(^"hitbox/CollisionShape2D"))
		var body: Vector2 = _rect_size(base.get_node(^"CollisionShape2D"))
		var feet: float = _feet(base)
		ck(base.Max_Health == stats.max_health and is_equal_approx(base.attack_range, stats.attack_range),
				"%s medium: stats as in the .tres (HP %d)" % [kind, base.Max_Health])
		for size_kind in ["small", "large"]:
			var m: Dictionary = sizes[size_kind]
			var s: float = m.scale
			var e: Node = _spawn(kind, size_kind, false, 200)
			await process_frame
			ck(_near(e.get_node(^"Sprite2D").scale, sprite_scale * s), "%s %s: sprite x%.1f" % [kind, size_kind, s])
			ck(_near(_rect_size(e.get_node(^"Hurtbox/CollisionShape2D")), hurt * s)
					and _near(_rect_size(e.get_node(^"hitbox/CollisionShape2D")), strike * s)
					and _near(_rect_size(e.get_node(^"CollisionShape2D")), body * s),
					"%s %s: hurtbox, hitbox and body x%.1f (%s)" % [kind, size_kind, s, _rect_size(e.get_node(^"Hurtbox/CollisionShape2D"))])
			ck(is_equal_approx(_feet(e), feet), "%s %s: feet stay on the floor line (%.1f)" % [kind, size_kind, _feet(e)])
			ck(e.Max_Health == roundi(stats.max_health * m.health) and is_equal_approx(e.base_damage, stats.base_damage * m.damage)
					and is_equal_approx(e.speed, stats.speed * m.speed) and is_equal_approx(e.attack_range, stats.attack_range * s)
					and e.xp_reward == roundi(stats.xp_reward * m.xp),
					"%s %s: HP %d, damage %.1f, speed %.1f, reach %.1f, XP %d" % [kind, size_kind, e.Max_Health, e.base_damage, e.speed, e.attack_range, e.xp_reward])
			e.queue_free()
		ck(_near(_rect_size(base.get_node(^"CollisionShape2D")), body), "%s: a big one does not grow the scene's shared body" % kind)
		base.queue_free()
	await process_frame

## [2] Еліта (D560): 1 з 8, засіяна кімнатою й точкою; HP ×2.5, шкода ×1.5, контур і трохи більша.
func _elites() -> void:
	print("[2] Elites: 1 in 8 seeded per room, HP x2.5, damage x1.5, an outline and a slightly larger size")
	var marks: Dictionary = variety.elite()
	ck(is_equal_approx(marks.chance, 0.125) and is_equal_approx(marks.health, 2.5) and is_equal_approx(marks.damage, 1.5),
			"enemy_variety.json: chance 1/8, HP x2.5, damage x1.5")
	var elites := 0
	var counts := {"small": 0, "medium": 0, "large": 0}
	const N := 8000
	for i in N:
		var key := "Room%d.tscn/Fight_EnemySpawnPoint%d" % [i / 4, i % 4]
		if variety.roll_elite(key):
			elites += 1
		counts[variety.roll_size(key)] += 1
	var rate := float(elites) / N
	ck(rate > 0.11 and rate < 0.14, "elite rate over %d spawns: %.3f" % [N, rate])
	ck(absf(counts.medium / float(N) - 0.5) < 0.03 and absf(counts.small / float(N) - 0.25) < 0.03,
			"sizes follow the weights 1:2:1 (%s)" % counts)
	var stable := true
	for i in 50:
		var key := "DesertRoad.tscn/Fight_Dunes_EnemySpawnPoint%d" % i
		stable = stable and variety.roll_elite(key) == variety.roll_elite(key) and variety.roll_size(key) == variety.roll_size(key)
	ck(stable, "the same room and point roll the same every time")

	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	var plain: Node = _spawn("melee", "medium", false, -200)
	var elite: Node = _spawn("melee", "medium", true, 200)
	await process_frame
	var sprite: Sprite2D = elite.get_node(^"Sprite2D")
	ck(elite.Max_Health == roundi(stats.max_health * 2.5) and is_equal_approx(elite.base_damage, stats.base_damage * 1.5)
			and elite.xp_reward == roundi(stats.xp_reward * marks.xp),
			"elite bandit: HP %d, damage %.1f, XP %d" % [elite.Max_Health, elite.base_damage, elite.xp_reward])
	ck(_near(sprite.scale, plain.get_node(^"Sprite2D").scale * marks.scale), "elite: slightly larger (x%.2f)" % marks.scale)
	ck(sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader.resource_path.ends_with("elite_outline.gdshader")
			and plain.get_node(^"Sprite2D").material == null, "elite: the outline glow; a plain one has none")
	var big: Node = _spawn("melee", "large", true, 0)
	await process_frame
	ck(big.Max_Health == roundi(stats.max_health * 1.8 * 2.5), "large elite: multipliers stack (HP %d)" % big.Max_Health)
	for e in [plain, elite, big]:
		e.queue_free()
	await process_frame

## [3] Розстановка (D582): кожен новий вид спершу сам-на-сам на DesertRoad, далі в парі, юрби — біля скрині й перед босом.
func _placements() -> void:
	print("[3] Placements (D582)")
	var map: Node = game.map
	var lone_shield: Node = map.get_node(^"Fight_LoneShield")
	var lone_elite: Node = map.get_node(^"Fight_LoneElite")
	ck(lone_shield.spawn_points.size() == 1 and lone_shield.spawn_points[0].enemy_type == "shield"
			and not lone_shield.variant_elite(lone_shield.spawn_points[0]) and lone_shield.variant_size(lone_shield.spawn_points[0]) == "medium",
			"DesertRoad: a lone medium shield-bearer, never elite, first")
	ck(lone_elite.spawn_points.size() == 1 and lone_elite.variant_elite(lone_elite.spawn_points[0]),
			"DesertRoad: a lone elite bandit after the caravan, before the save point")
	ck(lone_shield.spawn_points[0].global_position.x < map.get_node(^"Fight_Mesa").spawn_points[0].global_position.x,
			"the lone shield-bearer comes before the Mesa pair")
	var mesa: Array = map.get_node(^"Fight_Mesa").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(mesa.slice(2) == ["shield", "archer"], "Mesa: the second wave is a shield-bearer in front and an archer behind (%s)" % [mesa])
	var caravan: Array = map.get_node(^"Fight_Caravan").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(caravan.has("shield") and caravan.size() == 5, "Caravan (guards the chest): a big group with a shield-bearer and a vulture (D445) (%s)" % [caravan])
	var spawner_script: Script = load("res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd")
	var spawners := map.get_children().filter(func(n: Node) -> bool: return n.get_script() == spawner_script)
	ck(spawners.size() == 7 and spawners.all(func(n: Node) -> bool: return not n.elite_rolls),
			"DesertRoad: no random elites before the lone one has taught them (%d fights)" % spawners.size())
	var story: Node = map.get_node(^"EnemySpawner")
	var story_sizes: Array = story.spawn_points.map(func(p: Node) -> String: return story.variant_size(p))
	ck(story_sizes.all(func(s: String) -> bool: return s == "medium"), "the story fight keeps medium sizes (%s)" % [story_sizes])
	var rolled: Array = []
	for name in ["Fight_Dunes", "Fight_Mesa", "Fight_Caravan"]:
		var spawner: Node = map.get_node(NodePath(name))
		for p in spawner.spawn_points:
			rolled.append("%s %s %s" % [p.spawn_id, p.enemy_type, spawner.variant_size(p)])
	print("  info DesertRoad sizes: %s" % ", ".join(rolled))
	# Лабораторія: кидки еліти — тими самими ключами, що й RoomEnemySpawner (кімната MetSys + spawn_id)
	var lab: Node = load("res://SampleProject/Maps/Laboratory.tscn").instantiate()
	var room: String = root.get_node("MetSys").map_data.get_room_from_scene_path(lab.scene_file_path, false)
	var lab_rolls: Array = []
	var lab_shield := false
	for name in ["Fight_Upper", "Fight_Middle", "Fight_Lower"]:
		var spawner: Node = lab.get_node(NodePath(name))
		ck(spawner.elite_rolls and spawner.respawns, "Laboratory %s: elites roll there" % name)
		for p in spawner.get_children():
			if p.get_script() == load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd"):
				var key := "%s/%s_%s" % [room, name, p.name]
				lab_rolls.append("%s_%s %s %s%s" % [name, p.name, p.enemy_type, variety.roll_size(key), " ELITE" if variety.roll_elite(key) else ""])
				lab_shield = lab_shield or (name == "Fight_Lower" and p.enemy_type == "shield")
	ck(lab_shield, "Laboratory Fight_Lower (before the boss): a shield-bearer in the big group")
	print("  info Laboratory rolls: %s" % ", ".join(lab_rolls))
	lab.free()

func _place_hero(target: Node, dx: float) -> void:
	hero.global_position = target.global_position + Vector2(dx, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1 if dx < 0 else -1
	await physics_frame

## [4] Щит (D560): удар спереду щит приймає (іскри, звук, без шкоди й стійкості); у спину — по тілу; важкий розбиває
## щит (поза збою з кадрів бандита), далі звичайні удари спереду проходять.
func _shield() -> void:
	print("[4] The shield-bearer: the front is blocked, the back is not, a heavy attack breaks the shield")
	var bearer: Node = _spawn("shield", "medium", false, 0)
	await create_timer(0.3).timeout
	bearer.set_physics_process(false)  # стоїть і не б'є
	bearer.poise_max = 99
	bearer.poise = 99
	bearer.enemy_logic.last_direction = -1
	bearer._on_logic_direction_changed(-1)
	var blocked: Array = []
	var broken: Array = []
	var staggered: Array = []
	eb.enemy_shield_blocked.connect(func(e: Node, _at: Vector2) -> void: blocked.append(e))
	eb.enemy_shield_broken.connect(func(e: Node, _at: Vector2) -> void: broken.append(e))
	eb.enemy_staggered.connect(func(e: Node, t: float) -> void: staggered.append([e, t]))
	var hp: int = bearer.current_health

	await _place_hero(bearer, -30)
	await _tap(&"attack")
	await create_timer(0.5).timeout
	ck(bearer.current_health == hp and blocked == [bearer] and bearer.poise == 99,
			"a light hit from the front: blocked (HP %d → %d, blocks %d, poise %d)" % [hp, bearer.current_health, blocked.size(), bearer.poise])
	ck(bearer.shield_up and bearer.get_node(^"Sprite2D/Shield").scale.x < 0.0, "the shield stays up, held to the front (left)")

	await create_timer(1.0).timeout
	await _place_hero(bearer, 30)
	await _tap(&"attack")
	await create_timer(0.5).timeout
	ck(bearer.current_health < hp and blocked.size() == 1, "a hit in the back lands (HP %d → %d)" % [hp, bearer.current_health])
	hp = bearer.current_health

	await create_timer(1.0).timeout
	await _place_hero(bearer, -30)
	await _tap(&"heavy_attack")
	await create_timer(0.6).timeout
	ck(not bearer.shield_up and broken == [bearer], "a heavy attack from the front breaks the shield (broken %d)" % broken.size())
	ck(bearer.current_health == hp, "the breaking blow is taken by the shield (HP %d)" % bearer.current_health)
	var guard_break: float = variety.shield().guard_break_stagger
	ck(staggered.any(func(s: Array) -> bool: return s[0] == bearer and is_equal_approx(s[1], guard_break))
			and bearer.enemy_view.staggered, "guard break: staggered %.1f s in the bandit's stagger frames" % guard_break)
	ck(not bearer.has_node(^"Sprite2D/Shield"), "the shield flew off the bandit")

	await create_timer(guard_break + 0.6).timeout
	await _place_hero(bearer, -30)
	await _tap(&"attack")
	await create_timer(0.5).timeout
	ck(bearer.current_health < hp and blocked.size() == 1, "shieldless: a light hit from the front lands (HP %d → %d)" % [hp, bearer.current_health])

	var stats: Resource = bearer.enemy_stats
	ck(stats.enemy_type == "shield", "the shield-bearer is its own kind for the bestiary")
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	ck(bestiary.enemies.any(func(e: Dictionary) -> bool: return e.kind == "shield"), "bestiary has a shield-bearer entry")
	bearer.queue_free()
