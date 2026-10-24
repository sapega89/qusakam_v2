extends SceneTree

## Різновиди ворогів (D495, D560, D582, D652; design/enemy_variety_plan.md): розміри small / medium (спрайт, форми B128 і
## стати з enemy_variety.json), еліта як властивість виду (HP ×2.5, шкода ×1.5; великі види чекають на арт у точках
## BigSlot_*), щитоносець (удар спереду — у щит, у спину — по тілу, важкий розбиває щит і збиває його), розстановка по
## кімнатах і проклята піна (D653).
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
var spawn_script: GDScript

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	variety = load("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
	spawn_script = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
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
	await _foam()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## Ворог [param kind] розміру [param size_kind] на арені, на [param dx] від її центру.
func _spawn(kind: String, size_kind: String, dx: float) -> Node:
	var enemy: Node = load(SCENES[kind]).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	enemy.size_kind = size_kind
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

## [1] Розміри (D560, D652): small ×0.8, medium ×1.0 — спрайт, тіло, хітбокс, зона-ціль, дальність удару й стати.
## Великого розміру немає: більший ворог — свій вид.
func _sizes() -> void:
	print("[1] Sizes: small x0.8 and medium x1.0, no scaled large (D652) — sprite, shapes (D519) and stats from data")
	var sizes: Dictionary = variety.data().sizes
	ck(sizes.keys() == ["small", "medium"] and is_equal_approx(sizes.small.scale, 0.8) and is_equal_approx(sizes.medium.scale, 1.0),
			"enemy_variety.json: small 0.8 / medium 1.0 and nothing else (%s)" % [sizes.keys()])
	for kind in ["melee", "tank", "fast"]:
		var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
		var base: Node = _spawn(kind, "medium", -200)
		await process_frame
		var sprite_scale: Vector2 = base.get_node(^"Sprite2D").scale
		var hurt: Vector2 = _rect_size(base.get_node(^"Hurtbox/CollisionShape2D"))
		var strike: Vector2 = _rect_size(base.get_node(^"hitbox/CollisionShape2D"))
		var body: Vector2 = _rect_size(base.get_node(^"CollisionShape2D"))
		var feet: float = _feet(base)
		ck(base.Max_Health == stats.max_health and is_equal_approx(base.attack_range, stats.attack_range),
				"%s medium: stats as in the .tres (HP %d)" % [kind, base.Max_Health])
		var m: Dictionary = sizes.small
		var s: float = m.scale
		var e: Node = _spawn(kind, "small", 200)
		await process_frame
		ck(_near(e.get_node(^"Sprite2D").scale, sprite_scale * s), "%s small: sprite x%.1f" % [kind, s])
		ck(_near(_rect_size(e.get_node(^"Hurtbox/CollisionShape2D")), hurt * s)
				and _near(_rect_size(e.get_node(^"hitbox/CollisionShape2D")), strike * s)
				and _near(_rect_size(e.get_node(^"CollisionShape2D")), body * s),
				"%s small: hurtbox, hitbox and body x%.1f (%s)" % [kind, s, _rect_size(e.get_node(^"Hurtbox/CollisionShape2D"))])
		ck(is_equal_approx(_feet(e), feet), "%s small: feet stay on the floor line (%.1f)" % [kind, _feet(e)])
		ck(e.Max_Health == roundi(stats.max_health * m.health) and is_equal_approx(e.base_damage, stats.base_damage * m.damage)
				and is_equal_approx(e.speed, stats.speed * m.speed) and is_equal_approx(e.attack_range, stats.attack_range * s)
				and e.xp_reward == roundi(stats.xp_reward * m.xp),
				"%s small: HP %d, damage %.1f, speed %.1f, reach %.1f, XP %d" % [kind, e.Max_Health, e.base_damage, e.speed, e.attack_range, e.xp_reward])
		e.queue_free()
		ck(_near(_rect_size(base.get_node(^"CollisionShape2D")), body), "%s: a small one does not shrink the scene's shared body" % kind)
		base.queue_free()
	await process_frame
	var counts := {"small": 0, "medium": 0}
	const N := 8000
	for i in N:
		counts[variety.roll_size("melee", "Room%d.tscn/Fight_EnemySpawnPoint%d" % [i / 4, i % 4])] += 1
	ck(absf(counts.small / float(N) - 1.0 / 3.0) < 0.03, "a bandit's sizes follow its weights small 1 : medium 2 (%s)" % counts)
	var stable := true
	for i in 50:
		var key := "DesertRoad.tscn/Fight_Dunes_EnemySpawnPoint%d" % i
		stable = stable and variety.roll_size("fast", key) == variety.roll_size("fast", key)
	ck(stable, "the same room and point roll the same every time")

## [2] Еліта — властивість виду (D652): лише види з "elite": true мають множники D560 (HP ×2.5, шкода ×1.5); без контуру
## й без росту. Великі види (base) — еліта, кожен зі своїм аркушем; без аркуша вид не зʼявляється.
func _elites() -> void:
	print("[2] Elites are kinds (D652): only elite kinds get HP x2.5 and damage x1.5; no outline, no growth; big kinds wait for their art")
	var marks: Dictionary = variety.elite()
	ck(is_equal_approx(marks.health, 2.5) and is_equal_approx(marks.damage, 1.5) and not marks.has("chance") and not marks.has("scale")
			and not marks.has("outline_color"), "enemy_variety.json elite: HP x2.5, damage x1.5; no roll, no scale, no outline")
	var elite_kinds: Array = variety.kind_ids().filter(func(id: String) -> bool: return variety.is_elite(id))
	print("  info elite kinds: %s" % [elite_kinds])
	const PLANNED := ["bandit_brute", "jackal_pack_leader", "armoured_scorpion", "heavy_crossbowman", "tower_shield_guard",
			"old_vulture", "jackal_cursed"]
	ck(variety.big_kinds() == PLANNED, "the planned big kinds have their slots (%s)" % [variety.big_kinds()])
	var bases := {"bandit_brute": "melee", "jackal_pack_leader": "fast", "armoured_scorpion": "tank", "heavy_crossbowman": "archer",
			"tower_shield_guard": "shield", "old_vulture": "vulture", "jackal_cursed": "fast"}
	for id: String in PLANNED:
		var k: Dictionary = variety.kind(id)
		ck(k.elite and k.base == bases[id] and k.sizes.keys() == ["medium"], "%s: an elite, stands in for %s, one size" % [id, k.base])
	ck(variety.is_elite("fly") and variety.available("fly"), "the humanoid Cthulhu fly (D651) is an elite kind and its sheet exists")
	ck(variety.kind("jackal_cursed").has("foam") and not variety.kind("fast").has("foam"), "the horror jackal (D649) carries the cursed foam (D653)")
	ck(elite_kinds.all(func(id: String) -> bool: return id == "fly" or id in PLANNED), "no ordinary kind is an elite")
	for id: String in variety.kind_ids():
		if variety.available(id):
			var scene: String = spawn_script.scene_path(id)
			ck(ResourceLoader.exists(scene) and ResourceLoader.exists("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % id),
					"%s has its sheet, so it has its scene and stats" % id)
		else:
			ck(id in PLANNED, "%s: disabled until its sheet, scene and stats exist (%s)" % [id, variety.kind(id).sheet])
			if ResourceLoader.exists(variety.kind(id).sheet):
				print("  INFO %s: the sheet has landed, the kind waits for its scene and stats" % id)

	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	var plain: Node = _spawn("melee", "medium", -200)
	var fly: Node = load("res://SampleProject/Scenes/Characters/Enemies/enemy_fly.tscn").instantiate()
	var fly_stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_fly.tres")
	fly.enemy_stats = fly_stats
	fly.position = ARENA + Vector2(200, -120)
	game.map.add_child(fly)
	await process_frame
	ck(not plain.elite and plain.Max_Health == stats.max_health and is_equal_approx(plain.base_damage, stats.base_damage),
			"a bandit is not an elite: HP %d, damage %.1f" % [plain.Max_Health, plain.base_damage])
	ck(fly.elite and fly.Max_Health == roundi(fly_stats.max_health * 2.5) and is_equal_approx(fly.base_damage, fly_stats.base_damage * 1.5)
			and fly.xp_reward == roundi(fly_stats.xp_reward * marks.xp),
			"the Cthulhu fly is an elite: HP %d, damage %.1f, XP %d" % [fly.Max_Health, fly.base_damage, fly.xp_reward])
	var fly_scene: Node = load("res://SampleProject/Scenes/Characters/Enemies/enemy_fly.tscn").instantiate()
	ck(_near(fly.get_node(^"Sprite2D").scale, fly_scene.get_node(^"Sprite2D").scale) and fly.get_node(^"Sprite2D").material == null
			and plain.get_node(^"Sprite2D").material == null, "an elite is its own art: no outline glow, not scaled up")
	fly_scene.free()
	for e in [plain, fly]:
		e.queue_free()
	await process_frame

## [3] Розстановка (D582, D652): кожен новий вид спершу сам-на-сам на DesertRoad, далі в парі, юрби — біля скрині й перед
## босом. Де розстановка хотіла еліту чи великого — точка BigSlot_<вид>, що поки спавнить звичайний вид.
func _placements() -> void:
	print("[3] Placements (D582): BigSlot_* points wait for their big kinds and spawn the ordinary kind for now")
	var map: Node = game.map
	var lone_shield: Node = map.get_node(^"Fight_LoneShield")
	var lone_elite: Node = map.get_node(^"Fight_LoneElite")
	ck(lone_shield.spawn_points.size() == 1 and lone_shield.spawn_points[0].kind() == "shield"
			and lone_shield.variant_size(lone_shield.spawn_points[0]) == "medium",
			"DesertRoad: a lone medium shield-bearer first")
	var brute: Node = lone_elite.spawn_points[0]
	ck(lone_elite.spawn_points.size() == 1 and brute.name == "BigSlot_BanditBrute_1" and brute.big_kind == "bandit_brute"
			and brute.kind() == "melee" and brute.spawn_id == "Fight_LoneElite_EnemySpawnPoint1",
			"DesertRoad: the lone elite's place waits for the bandit brute and spawns a bandit for now (spawn_id kept for saves)")
	ck(lone_shield.spawn_points[0].global_position.x < map.get_node(^"Fight_Mesa").spawn_points[0].global_position.x,
			"the lone shield-bearer comes before the Mesa pair")
	var mesa: Array = map.get_node(^"Fight_Mesa").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(mesa.slice(2) == ["shield", "archer"], "Mesa: the second wave is a shield-bearer in front and an archer behind (%s)" % [mesa])
	var caravan: Array = map.get_node(^"Fight_Caravan").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(caravan.has("shield") and caravan.size() == 5, "Caravan (guards the chest): a big group with a shield-bearer and a vulture (D445) (%s)" % [caravan])
	var story: Node = map.get_node(^"EnemySpawner")
	var story_sizes: Array = story.spawn_points.map(func(p: Node) -> String: return story.variant_size(p))
	ck(story_sizes.all(func(s: String) -> bool: return s == "medium"), "the story fight keeps medium sizes (%s)" % [story_sizes])
	var rolled: Array = []
	for name in ["Fight_Dunes", "Fight_Mesa", "Fight_Caravan"]:
		var spawner: Node = map.get_node(NodePath(name))
		for p in spawner.spawn_points:
			rolled.append("%s %s %s" % [p.spawn_id, p.kind(), spawner.variant_size(p)])
	print("  info DesertRoad sizes: %s" % ", ".join(rolled))
	var lab: Node = load("res://SampleProject/Maps/Laboratory.tscn").instantiate()
	var lab_shield := false
	for p: Node in lab.get_node(^"Fight_Lower").get_children():
		lab_shield = lab_shield or (p.get_script() == spawn_script and p.enemy_type == "shield")
	ck(lab_shield, "Laboratory Fight_Lower (before the boss): a shield-bearer in the big group")
	lab.free()
	# Усі кімнати: нічого великого чи елітного без свого виду; BigSlot_* названі за видом і стоять на його base.
	var slots: Array = []
	var ok_names := true
	var ok_kinds := true
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var room: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for p: Node in room.find_children("*", "Node2D", true, false):
			if p.get_script() != spawn_script:
				continue
			var slot: bool = String(p.name).begins_with("BigSlot_")
			ok_names = ok_names and slot == (p.big_kind != "none")
			if p.big_kind != "none":
				var camel := "".join(Array(p.big_kind.split("_")).map(func(w: String) -> String: return w.capitalize()))
				ok_names = ok_names and String(p.name).begins_with("BigSlot_%s_" % camel)
				ok_kinds = ok_kinds and variety.kind(p.big_kind).base == p.enemy_type
				slots.append("%s %s/%s %s→%s" % [file.get_basename(), p.get_parent().name, p.name, p.big_kind, p.kind()])
			ok_kinds = ok_kinds and variety.available(p.kind()) and p.size in ["auto", "small", "medium"]
		room.free()
	ck(ok_names, "a spawn point is named BigSlot_<Kind>_n exactly when it waits for a big kind")
	ck(ok_kinds, "every point spawns a kind whose art exists, and a slot stands on its big kind's base")
	ck(slots.size() == 12, "12 big slots: 5 on DesertRoad, 7 in the Laboratory (%d)" % slots.size())
	print("  info big slots: %s" % ", ".join(slots))

func _place_hero(target: Node, dx: float) -> void:
	hero.global_position = target.global_position + Vector2(dx, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1 if dx < 0 else -1
	await physics_frame

## [4] Щит (D560): удар спереду щит приймає (іскри, звук, без шкоди й стійкості); у спину — по тілу; важкий розбиває
## щит (поза збою з кадрів бандита), далі звичайні удари спереду проходять.
func _shield() -> void:
	print("[4] The shield-bearer: the front is blocked, the back is not, a heavy attack breaks the shield")
	var bearer: Node = _spawn("shield", "medium", 0)
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


## [5] Проклята піна (D653): ефект у шарі влучань, сяйні сині краплі з пащі, дзеркалиться з поглядом. Перевіряємо на
## сцені шакала зі статами виду jackal_cursed (його аркуша ще немає — так гра його й не спавнить).
func _foam() -> void:
	print("[5] The cursed foam (D653): glowing blue drops from the mouth, in the hit-VFX layer, on any kind with foam")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_fast.tres").duplicate()
	stats.enemy_type = "jackal_cursed"
	var jackal: Node = load(SCENES.fast).instantiate()
	jackal.enemy_stats = stats
	jackal.position = ARENA
	game.map.add_child(jackal)
	await create_timer(0.4).timeout
	var sprite: Sprite2D = jackal.get_node(^"Sprite2D")
	var foam: Node2D = sprite.get_node(^"CursedFoam")
	var drops: CPUParticles2D = foam.get_node(^"Drops")
	var mouth: Array = variety.kind("jackal_cursed").foam
	ck(not foam.z_as_relative and foam.z_index == load("res://SampleProject/Scenes/FX/HitImpact.tscn").instantiate().z_index,
			"drawn in the hit-VFX layer (z %d)" % foam.z_index)
	ck(drops.emitting and not drops.local_coords and drops.gravity.y > 0.0,
			"drops keep falling in the world")
	var core: Color = drops.color_ramp.get_color(0)
	var tint: Color = drops.color_ramp.get_color(1)
	ck(core.get_luminance() > 0.85 and tint.b > tint.r + 0.3 and tint.b > tint.g, "the foam glows: a near-white core fading to blue (%s → %s)" % [core, tint])
	ck(jackal.elite and jackal.Max_Health == roundi(load("res://SampleProject/Resources/Enemies/enemy_stats_fast.tres").max_health * 2.5),
			"the horror jackal is an elite (HP %d)" % jackal.Max_Health)
	jackal.set_physics_process(false)  # стоїть: погляд задає тест
	jackal.enemy_logic.set_physics_process(false)
	jackal._on_logic_direction_changed(1)
	for i in 2: await process_frame  # process_frame приходить раніше за _process вузлів
	var right: Vector2 = foam.position - sprite.get_rect().get_center()
	jackal._on_logic_direction_changed(-1)
	for i in 2: await process_frame
	var left: Vector2 = foam.position - sprite.get_rect().get_center()
	ck(right.is_equal_approx(Vector2(mouth[0], mouth[1])) and left.is_equal_approx(Vector2(-mouth[0], mouth[1])),
			"the foam sits at the mouth and follows the facing (%s / %s from the frame centre)" % [right, left])
	var plain: Node = _spawn("fast", "medium", 200)
	await process_frame
	ck(not plain.get_node(^"Sprite2D").has_node(^"CursedFoam"), "an ordinary jackal has no foam")
	jackal.queue_free()
	plain.queue_free()
