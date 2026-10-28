extends SceneTree

## Різновиди ворогів (D495, D560, D582, D652; design/enemy_variety_plan.md): розміри small / medium (спрайт, форми B128 і
## стати з enemy_variety.json), еліта як властивість виду (HP ×2.5, шкода ×2.3, D754; великі види чекають на арт у точках
## BigSlot_*), щитоносець (удар спереду — у щит, у спину — по тілу, важкий розбиває щит і збиває його), розстановка по
## кімнатах, проклята піна (D653) і проклятий шакал (D589, D649, D675), живий вид-еліта, сам-на-сам, потім пара;
## ватажок зграї шакалів (D692): живий вид-еліта на місці BigSlot_JackalPackLeader_*;
## бандит-громило (D693): живий вид-еліта на місці BigSlot_BanditBrute_*.
##   godot --headless --path . --script res://SampleProject/UI/verify_enemy_variety.gd

const SCENES := {
	"melee": "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn",
	"tank": "res://SampleProject/Scenes/Characters/Enemies/enemy_tank.tscn",
	"fast": "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn",
	"shield": "res://SampleProject/Scenes/Characters/Enemies/enemy_shield.tscn",
	"jackal_cursed": "res://SampleProject/Scenes/Characters/Enemies/enemy_jackal_cursed.tscn",
	"jackal_pack_leader": "res://SampleProject/Scenes/Characters/Enemies/enemy_jackal_pack_leader.tscn",
	"bandit_brute": "res://SampleProject/Scenes/Characters/Enemies/enemy_bandit_brute.tscn",
}
const HitAreas = preload("res://SampleProject/Scripts/Combat/HitAreas.gd")
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
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
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
	_pack_art()
	await _elites()
	_placements()
	await _shield()
	await _foam()
	_cursed_jackal()
	await _pack_leader()
	await _armoured_scorpion()
	await _old_vulture()
	await _brute()
	await _tower_guard()

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

## [1b] Звичайний шакал — шакал зграї в стилі ватажка (D692/D693): аркуш jackal_pack 4×5 клітинок 96×72, ряди як у
## ватажка (idle 0–1, walk 4–7, attack 8–10, hurt 12, death 16–18), лапи на лінії підлоги, де стоїть бандит.
func _pack_art() -> void:
	print("[1b] The ordinary jackal is the pack jackal (D692/D693): its sheet, the leader's rows, paws on the floor line")
	var jackal: Node = load(SCENES.fast).instantiate()
	var bandit: Node = load(SCENES.melee).instantiate()
	var sprite: Sprite2D = jackal.get_node(^"Sprite2D")
	var anim: AnimationPlayer = jackal.get_node(^"AnimationPlayer")
	const SHEET := "res://SampleProject/Assets/Characters/Enemies/jackal_pack/sheet.png"
	ck(sprite.texture.resource_path == SHEET and variety.kind("fast").sheet == SHEET and sprite.hframes == 4 and sprite.vframes == 5
			and sprite.texture.get_size() == Vector2(384, 360), "enemy_fast and kinds.fast draw %s, 4x5 cells of 96x72" % SHEET.get_file())
	var rows := {&"idle": [0, 1], &"walk": [4, 5, 6, 7], &"attack": [8, 9, 10], &"stagger": [12], &"death": [16, 17, 18]}
	for a: StringName in rows:
		ck(HitAreas.anim_frames(anim, a, 0.0, INF) == Array(rows[a], TYPE_INT, "", null), "%s: frames %s" % [a, rows[a]])
	ck(sprite.texture.resource_path.get_base_dir().get_file() != "jackal" and not ResourceLoader.exists(
			"res://SampleProject/Assets/Characters/Enemies/jackal/sheet.png"), "the old jackal art is gone")
	var paws: float = HitAreas.body_rect(sprite, anim).end.y
	var floor_line: float = HitAreas.body_rect(bandit.get_node(^"Sprite2D"), bandit.get_node(^"AnimationPlayer")).end.y
	ck(is_equal_approx(paws, floor_line), "its drawn paws stand where the bandit's feet do (%.1f vs %.1f px below its centre)" % [paws, floor_line])
	jackal.free()
	bandit.free()

## [2] Еліта — властивість виду (D652): лише види з "elite": true мають множники D560 (HP ×2.5; шкода ×2.3 і стійкість ×1.6,
## удари героя її не відкидають — D754); без контуру; D829: росте на elite.scale понад свою сцену. Великі види (base) — еліта, кожен зі своїм аркушем; без аркуша вид не зʼявляється.
func _elites() -> void:
	print("[2] Elites are kinds (D652): only elite kinds get HP x2.5, damage x2.3, poise x2.0 and no knockback (D754, D777); no outline, grown x1.5 (D829, D842); big kinds wait for their art")
	var marks: Dictionary = variety.elite()
	ck(is_equal_approx(marks.health, 2.5) and is_equal_approx(marks.damage, 2.3) and is_equal_approx(marks.poise, 2.0) and marks.knockback_immune
			and not marks.has("chance") and is_equal_approx(marks.scale, 1.5) and not marks.has("outline_color"),
			"enemy_variety.json elite: HP x2.5, damage x2.3, poise x2.0, not pushed, grown x1.5 (D829, D842); no roll, no outline")
	var elite_kinds: Array = variety.kind_ids().filter(func(id: String) -> bool: return variety.is_elite(id))
	print("  info elite kinds: %s" % [elite_kinds])
	const PLANNED := ["bandit_brute", "jackal_pack_leader", "armoured_scorpion", "heavy_archer", "tower_shield_guard",
			"old_vulture", "jackal_cursed"]
	ck(variety.big_kinds() == PLANNED, "the planned big kinds have their slots (%s)" % [variety.big_kinds()])
	var bases := {"bandit_brute": "melee", "jackal_pack_leader": "fast", "armoured_scorpion": "tank", "heavy_archer": "archer",
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
	# D840: еліта стоїть на рівень вище героя (рівень 1 тут) — множники рівня 2 понад еліту
	var fly_grown: Dictionary = variety.level(fly.scaled_level)
	ck(fly.elite and fly.scaled_level == 2 and fly.Max_Health == roundi(fly_stats.max_health * fly_grown.health * 2.5)
			and is_equal_approx(fly.base_damage, fly_stats.base_damage * fly_grown.damage * marks.damage)
			and fly.xp_reward == roundi(fly_stats.xp_reward * marks.xp),
			"the Cthulhu fly is an elite (level %d, D840): HP %d, damage %.1f, XP %d" % [fly.scaled_level, fly.Max_Health, fly.base_damage, fly.xp_reward])
	var fly_scene: Node = load("res://SampleProject/Scenes/Characters/Enemies/enemy_fly.tscn").instantiate()
	ck(_near(fly.get_node(^"Sprite2D").scale, fly_scene.get_node(^"Sprite2D").scale * marks.scale) and fly.get_node(^"Sprite2D").material == null
			and plain.get_node(^"Sprite2D").material == null, "an elite is its own art: no outline glow, grown x%.2f over its scene (D829)" % marks.scale)
	fly_scene.free()
	for e in [plain, fly]:
		e.queue_free()
	await _heavy_archer()
	await process_frame

## Великий лучник (D652, D692: лук, не арбалет) — живий вид: свій аркуш і сцена на поведінці лучника, еліта, більший
## за звичайного лучника.
func _heavy_archer() -> void:
	ck(variety.available("heavy_archer") and variety.kind("heavy_archer").sheet.ends_with("/archer_heavy/sheet.png"),
			"the heavy archer's sheet has landed (Enemies/archer_heavy, D692)")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_heavy_archer.tres")
	var marks: Dictionary = variety.elite()
	var heavy: Node = load(spawn_script.scene_path("heavy_archer")).instantiate()
	heavy.enemy_stats = stats
	heavy.position = ARENA + Vector2(200, 0)
	game.map.add_child(heavy)
	var archer: Node = load(spawn_script.scene_path("archer")).instantiate()
	await process_frame
	ck(heavy.get_script().resource_path.ends_with("ArcherEnemy.gd") and stats.enemy_type == "heavy_archer",
			"the heavy archer runs on the archer's behaviour (ArcherEnemy)")
	var grown: Dictionary = variety.level(heavy.scaled_level)  # D840: еліта — рівень героя + 1
	ck(heavy.elite and heavy.scaled_level == 2 and heavy.Max_Health == roundi(stats.max_health * grown.health * marks.health)
			and is_equal_approx(heavy.base_damage, stats.base_damage * grown.damage * marks.damage),
			"the heavy archer is an elite (level %d, D840): HP %d, damage %.1f" % [heavy.scaled_level, heavy.Max_Health, heavy.base_damage])
	var big: Vector2 = _rect_size(heavy.get_node(^"Hurtbox/CollisionShape2D"))
	var small: Vector2 = _rect_size(archer.get_node(^"Hurtbox/CollisionShape2D"))
	var big_feet: float = heavy.get_node(^"Hurtbox/CollisionShape2D").position.y + big.y / 2.0
	var small_feet: float = archer.get_node(^"Hurtbox/CollisionShape2D").position.y + small.y / 2.0
	ck(big.y > small.y * 1.2 and absf(big_feet - small_feet) <= 1.0,
			"bigger than a desert archer (drawn body %.0f vs %.0f px tall), drawn feet on its floor line (%.1f vs %.1f)"
			% [big.y, small.y, big_feet, small_feet])
	archer.free()
	heavy.queue_free()

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
			and brute.kind() == "bandit_brute" and brute.spawn_id == "Fight_LoneElite_EnemySpawnPoint1",
			"DesertRoad: the lone elite is the bandit brute, alone (spawn_id kept for saves)")
	# D719: перший лучник дороги — звичайний, на рівні бою; великий лучник уперше — у таборі бандитів.
	var mesa_archer: Node = map.get_node(^"Fight_Mesa").spawn_points[1]
	ck(mesa_archer.name == "EnemySpawnPoint4" and mesa_archer.big_kind == "none" and mesa_archer.kind() == "archer"
			and mesa_archer.spawn_id == "Fight_Mesa_EnemySpawnPoint4",
			"Mesa (D719): the archer's place behind the shield-bearer is the ordinary archer (spawn_id kept for saves)")
	var road_archers: Array = []
	for p: Node in map.find_children("*", "Node2D", true, false):
		if p.get_script() == spawn_script and p.kind() in ["archer", "heavy_archer"]:
			road_archers.append("%s/%s %s" % [p.get_parent().name, p.name, p.kind()])
	ck(road_archers == ["Fight_Mesa/EnemySpawnPoint4 archer"],
			"DesertRoad (D719): no heavy archer on the road, its one archer is the Mesa's ordinary one (%s)" % [road_archers])
	var camp_room: Node = load("res://SampleProject/Maps/BanditCamp.tscn").instantiate()
	var camp: Array = []
	for p: Node in camp_room.get_node(^"Fight_Camp").get_children():
		if p.get_script() == spawn_script:
			camp.append(p)
	var camp_heavy: Array = camp.filter(func(p: Node) -> bool: return p.big_kind == "heavy_archer")
	ck(camp_heavy.size() == 1 and camp_heavy[0].name == "BigSlot_HeavyArcher_4" and camp_heavy[0].kind() == "heavy_archer"
			and camp_heavy[0].enemy_type == "archer" and camp_heavy[0].spawn_id == "Fight_Camp_EnemySpawnPoint4",
			"Bandit Camp (D719): one heavy archer among the camp's bandits, on the old archer point (spawn_id kept)")
	# Хвилі по 3 (D698): громило в першій, великий лучник у другій, за щитоносцем — дві еліти не стоять разом.
	var waves: Array = camp.map(func(p: Node) -> String: return p.kind())
	var wave_size: int = camp_room.get_node(^"Fight_Camp").wave_size
	ck(waves.slice(0, wave_size).has("bandit_brute") and not waves.slice(0, wave_size).has("heavy_archer")
			and waves.slice(wave_size).has("heavy_archer") and not waves.slice(wave_size).has("bandit_brute")
			and waves.slice(wave_size).has("shield"),
			"Bandit Camp: the brute in wave 1, the heavy archer in wave 2 behind a shield-bearer, never side by side (%s)" % [waves])
	camp_room.free()
	ck(lone_shield.spawn_points[0].global_position.x < map.get_node(^"Fight_Mesa").spawn_points[0].global_position.x,
			"the lone shield-bearer comes before the Mesa pair")
	var mesa: Array = map.get_node(^"Fight_Mesa").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(mesa == ["shield", "archer", "fast"], "Mesa (D817): the first wave is a shield-bearer in front and an archer behind, a jackal follows (%s)" % [mesa])
	var caravan: Array = map.get_node(^"Fight_Caravan").spawn_points.map(func(p: Node) -> String: return p.enemy_type)
	ck(caravan == ["tank", "melee", "shield"], "Caravan (D817): the armoured scorpion with a bandit and a shield-bearer, no more (%s)" % [caravan])
	var story: Node = map.get_node(^"EnemySpawner")
	var story_sizes: Array = story.spawn_points.map(func(p: Node) -> String: return story.variant_size(p))
	ck(story_sizes.all(func(s: String) -> bool: return s == "medium"), "the story fight keeps medium sizes (%s)" % [story_sizes])
	var rolled: Array = []
	for name in ["Fight_Dunes", "Fight_Mesa", "Fight_Caravan"]:
		var spawner: Node = map.get_node(NodePath(name))
		for p in spawner.spawn_points:
			rolled.append("%s %s %s" % [p.spawn_id, p.kind(), spawner.variant_size(p)])
	print("  info DesertRoad sizes: %s" % ", ".join(rolled))
	var lab: Node = load("res://SampleProject/Maps/LabTopFloor.tscn").instantiate()
	var lab_shield := false
	for p: Node in lab.get_node(^"Fight_Lower").get_children():
		lab_shield = lab_shield or (p.get_script() == spawn_script and p.enemy_type == "shield")
	ck(lab_shield, "LabTopFloor Fight_Lower (before the boss): a shield-bearer in the big group")
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
	ck(slots.size() == 13, "13 big slots: 4 on DesertRoad (the Dunes bandit and the Mesa archer are no slots, D582, D719; the old vulture's chest, D722), 2 in the Bandit Camp (D643, D719), 7 in the Laboratory (the tower guard's chest, D724) (%d)" % slots.size())
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
## проклятому шакалі, як його спавнить гра (його сцена й стати).
func _foam() -> void:
	print("[5] The cursed foam (D653): glowing blue drops from the mouth, in the hit-VFX layer, on any kind with foam")
	var jackal: Node = load(SCENES.jackal_cursed).instantiate()
	jackal.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_jackal_cursed.tres")
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
	ck(jackal.elite and jackal.Max_Health == roundi(load("res://SampleProject/Resources/Enemies/enemy_stats_fast.tres").max_health
			* variety.level(jackal.scaled_level).health * 2.5),
			"the horror jackal is an elite (level %d, D840: hero + 1; HP %d)" % [jackal.scaled_level, jackal.Max_Health])
	jackal.set_physics_process(false)  # стоїть: погляд задає тест
	jackal.enemy_logic.set_physics_process(false)
	jackal.enemy_view._offset_to(0.0, 0.01)  # нахил замаху (більший шакал D766 дістає героя з точки тесту) — геть
	await create_timer(0.05).timeout
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


## [6] Проклятий шакал (D589, D649, D652, D675): живий вид-еліта з власним аркушем, поведінка шакала (enemy_fast), числа
## шакала з множниками еліти й рівня бою (D642 — бій перевіряє verify_difficulty). Розстановка (D582): уперше сам-на-сам
## у коридорі середнього поверху, без мухи поруч; далі пара — друга хвиля нижнього бою перед босом; муха лишається одна.
func _cursed_jackal() -> void:
	print("[6] The cursed jackal (D589, D652): a live elite kind with the jackal's behaviour, alone first, then a pair")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_jackal_cursed.tres")
	var fast: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_fast.tres")
	ck(variety.available("jackal_cursed") and variety.is_elite("jackal_cursed") and spawn_script.scene_path("jackal_cursed") == SCENES.jackal_cursed,
			"its sheet, scene and stats exist: the kind spawns, and it is an elite")
	var same := true
	# attack_range і lunge — від свого намальованого розміру (D766): удар дістає туди, куди сягає кадр (verify_hit_areas)
	for prop in ["speed", "base_damage", "attack_windup", "attack_cooldown", "max_health", "poise",
			"combo_hits", "tell", "finisher_tell", "recovery", "back_off", "flying"]:
		same = same and stats.get(prop) == fast.get(prop)
	ck(stats.enemy_type == "jackal_cursed" and same, "the jackal's behaviour and base numbers (enemy_fast), its own kind for the bestiary and the elite marks")
	var sheet: Texture2D = load(variety.kind("jackal_cursed").sheet)
	var enemy: Node = load(SCENES.jackal_cursed).instantiate()
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	ck(sheet.get_width() == 96 * sprite.hframes and sheet.get_height() == 72 * sprite.vframes and sprite.vframes == 5,
			"96x72 cells, rows idle / walk / attack / hurt / death (%dx%d)" % [sprite.hframes, sprite.vframes])
	var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
	var frames := {}
	for a: StringName in [&"idle", &"walk", &"attack", &"stagger", &"death"]:
		frames[a] = HitAreas.anim_frames(anim, a, 0.0, INF)
	ck(frames == {&"idle": [0, 1], &"walk": [4, 5, 6, 7], &"attack": [8, 9, 10], &"stagger": [12], &"death": [16, 17, 18]},
			"animations play the sheet's rows (%s)" % [frames])
	enemy.free()
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var entry: Array = bestiary.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "jackal_cursed")
	ck(entry.size() == 1 and _translated(entry[0].name) and _translated(entry[0].text), "bestiary entry, en and uk")

	# Лабораторія v3 (D865): бої в кімнатах поверхів, у порядку шляху вгору.
	var lab_rooms: Array[Node] = []
	for room_name in ["Laboratory", "LabGuardPocket", "LabMiddleFloor", "LabTopFloor"]:
		lab_rooms.append(load("res://SampleProject/Maps/%s.tscn" % room_name).instantiate())
	var lab_fights: Array[Node] = []
	for room: Node in lab_rooms:
		lab_fights.append_array(room.get_children().filter(func(n: Node) -> bool: return n.has_node(^"Trigger")))
	var placed: Array[String] = []
	var first := ""
	for spawner: Node in lab_fights:
		var kinds: Array = []
		for p: Node in spawner.find_children("*", "Node2D", true, false):
			if p.get_script() == spawn_script:
				kinds.append(p.kind())
		if kinds.has("jackal_cursed"):
			placed.append("%s %s" % [spawner.name, kinds])
			if first.is_empty():
				first = spawner.name
				ck(kinds == ["jackal_cursed"] and spawner.enemy_level == 9, "%s: the first cursed jackal comes alone, nothing cursed beside it (%s)" % [spawner.name, kinds])
	print("  info cursed jackals: %s" % ", ".join(placed))
	ck(first == "Fight_Cursed", "the first one stands on the middle floor, just off the great stairs (%s)" % first)
	var middle_floor: Node = lab_rooms[2]
	var lone: Node2D = middle_floor.get_node(^"Fight_Cursed")
	var middle: Node2D = middle_floor.get_node(^"Fight_Middle")
	ck(lone.get_node(^"Trigger").position.x - middle.get_node(^"Trigger").position.x >= 400.0 and lone.get_node(^"BigSlot_JackalCursed_1").position.y == 368.0,
			"room to learn it: the next fight's zone is 400+ px further west, the jackal on the floor")
	var lower: Array = []
	var top_floor: Node = lab_rooms[3]
	for p: Node in top_floor.get_node(^"Fight_Lower").get_children():
		if p.get_script() == spawn_script:
			lower.append(p.kind())
	ck(lower.slice(2) == ["jackal_cursed", "jackal_cursed"] and top_floor.get_node(^"Fight_Lower").wave_size == 2,
			"later: a pair, the second wave of the fight before the boss (%s)" % [lower])
	ck(placed.size() == 2, "nowhere else: the lone one and the pair (%d fights)" % placed.size())
	var fly: Array = []
	for room: Node in lab_rooms:
		for p: Node in room.find_children("*", "Node2D", true, false):
			if p.get_script() == spawn_script and p.kind() == "fly":
				fly.append(String(p.get_parent().name))
	ck(fly == ["Fight_Fly"] and lab_fights.find(lab_rooms[0].get_node(^"Fight_Fly")) < lab_fights.find(lone),
			"the fly stays one, alone, before the jackal (%s)" % [fly])
	for room: Node in lab_rooms:
		room.free()

## [6b] Ватажок зграї шакалів (D652, D692): живий вид-еліта з власним аркушем, поведінка шакала (enemy_fast), числа шакала
## з множниками еліти й рівня бою (D642 — бій перевіряє verify_difficulty). Розстановка (D582, D682): кожна точка
## BigSlot_JackalPackLeader_* спавнить його; у першій зустрічі поруч немає іншого великого чи проклятого виду.
func _pack_leader() -> void:
	print("[6b] The jackal pack leader (D652, D692): a live elite kind with the jackal's behaviour in its slots")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_jackal_pack_leader.tres")
	var fast: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_fast.tres")
	ck(variety.available("jackal_pack_leader") and variety.is_elite("jackal_pack_leader")
			and spawn_script.scene_path("jackal_pack_leader") == SCENES.jackal_pack_leader,
			"its sheet, scene and stats exist: the kind spawns, and it is an elite")
	var same := true
	# attack_range і lunge — від свого намальованого розміру (D766): удар дістає туди, куди сягає кадр (verify_hit_areas)
	for prop in ["speed", "base_damage", "attack_windup", "attack_cooldown", "max_health", "poise",
			"combo_hits", "tell", "finisher_tell", "recovery", "back_off", "flying", "xp_reward"]:
		same = same and stats.get(prop) == fast.get(prop)
	ck(stats.enemy_type == "jackal_pack_leader" and same, "the jackal's behaviour and base numbers (enemy_fast), its own kind for the bestiary and the elite marks")
	var sheet: Texture2D = load(variety.kind("jackal_pack_leader").sheet)
	var enemy: Node = load(SCENES.jackal_pack_leader).instantiate()
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	ck(sheet.resource_path.ends_with("Enemies/jackal_leader/sheet.png") and sheet.get_width() == 96 * sprite.hframes
			and sheet.get_height() == 72 * sprite.vframes and sprite.hframes == 4 and sprite.vframes == 5,
			"the D692 sheet, 96x72 cells, rows idle / walk / attack / hurt / death (%dx%d)" % [sprite.hframes, sprite.vframes])
	var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
	var frames := {}
	for a: StringName in [&"idle", &"walk", &"attack", &"stagger", &"death"]:
		frames[a] = HitAreas.anim_frames(anim, a, 0.0, INF)
	ck(frames == {&"idle": [0, 1], &"walk": [4, 5, 6, 7], &"attack": [8, 9, 10], &"stagger": [12], &"death": [16, 17, 18]},
			"animations play the sheet's rows (%s)" % [frames])
	ck(not variety.kind("jackal_pack_leader").has("foam"), "no cursed foam: it is a living jackal, not one of the alchemist's beasts")
	enemy.free()
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var entry: Array = bestiary.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "jackal_pack_leader")
	ck(entry.size() == 1 and _translated(entry[0].name) and _translated(entry[0].text), "bestiary entry, en and uk")

	# Кожна точка ватажка в кожній кімнаті спавнить його; бій, де він уперше, — без іншого великого чи проклятого виду.
	var placed: Array[String] = []
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var room: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for p: Node in room.find_children("BigSlot_JackalPackLeader_*", "Node2D", true, false):
			var fight: Node = p.get_parent()
			var big: Array = []
			for q: Node in fight.get_children():
				if q.get_script() == spawn_script and variety.is_elite(q.kind()):
					big.append(q.kind())
			placed.append("%s %s/%s %s, big kinds in the fight %s" % [file.get_basename(), fight.name, p.name, p.kind(), big])
			ck(p.kind() == "jackal_pack_leader" and p.big_kind == "jackal_pack_leader", "%s/%s spawns the pack leader" % [fight.name, p.name])
		room.free()
	print("  info pack leaders: %s" % ", ".join(placed))
	ck(placed.size() == 1, "one slot: DesertRoad Fight_Dunes (%d)" % placed.size())

	# Живий бій Fight_Dunes (рівень 2): перша хвиля — бандит, друга — ватажок сам (D817), еліта рівня бою.
	var dunes: Node = game.map.get_node(^"Fight_Dunes")
	var kinds: Array = dunes.spawn_points.map(func(p: Node) -> String: return p.kind())
	ck(kinds == ["melee", "jackal_pack_leader"] and dunes.wave_size == 1,
			"Fight_Dunes (D817): a bandit first, the leader alone in the second wave, no other big kind (%s)" % [kinds])
	dunes.spawn_all_enemies()
	await create_timer(dunes.wave_delay + 0.5).timeout
	var leader: Node = dunes.get_node(^"Enemy_Fight_Dunes_EnemySpawnPoint4")
	var grown: Dictionary = variety.level(leader.scaled_level)  # D840: еліта — рівень бою + 1 (герой 1-го рівня)
	var marks: Dictionary = variety.elite()
	ck(leader.scene_file_path == SCENES.jackal_pack_leader and leader.elite and leader.level == 2 and leader.scaled_level == 3
			and leader.Max_Health == roundi(stats.max_health * grown.health * marks.health)
			and is_equal_approx(leader.base_damage, stats.base_damage * grown.damage * marks.damage),
			"in the game it is the pack leader, an elite of a level-2 fight at level 3 (D840): HP %d, damage %.1f" % [leader.Max_Health, leader.base_damage])
	var jackal: Node = load(SCENES.fast).instantiate()
	var paws := [HitAreas.frame_rect(leader.get_node(^"Sprite2D"), 0).end.y, HitAreas.frame_rect(jackal.get_node(^"Sprite2D"), 0).end.y]
	jackal.free()
	ck(absf(paws[0] - paws[1]) <= 1.0, "its drawn paws stand on a medium jackal's line (%.1f vs %.1f px below its centre)" % paws)
	dunes.despawn_all_enemies()
	await process_frame


## [6c] Броньований скорпіон (D652, D692): живий великий вид — свій аркуш і сцена, поведінка скорпіона (tank), числа еліти
## на рівні бою (D642); обидві його точки BigSlot_ArmouredScorpion_* спавнять його; є в бестіарії англійською й українською.
func _armoured_scorpion() -> void:
	print("[6c] The armoured scorpion is live: its own art, the scorpion's behaviour, elite numbers at its fight's level")
	const ID := "armoured_scorpion"
	ck(variety.available(ID) and variety.kind(ID).sheet.ends_with("scorpion_armoured/sheet.png"), "its sheet, scene and stats exist")
	var tank: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_tank.tres")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % ID)
	ck(stats.enemy_type == ID and stats.super_armor == tank.super_armor and is_equal_approx(stats.front_damage, tank.front_damage)
			and stats.tell == tank.tell and stats.finisher_tell == tank.finisher_tell and stats.max_health == tank.max_health
			and is_equal_approx(stats.base_damage, tank.base_damage) and is_equal_approx(stats.attack_windup, tank.attack_windup),
			"the scorpion's behaviour: armoured front x%.1f, super armour, %s tell, base HP %d / damage %.0f as the scorpion"
			% [stats.front_damage, stats.tell, stats.max_health, stats.base_damage])
	for slot: Array in [["DesertRoad", "Fight_Caravan"], ["LabTopFloor", "Fight_Lower"]]:
		var room: Node = load("res://SampleProject/Maps/%s.tscn" % slot[0]).instantiate()
		var point: Node = room.get_node(NodePath("%s/BigSlot_ArmouredScorpion_1" % slot[1]))
		var level: int = point.get_parent().enemy_level
		ck(point.kind() == ID and spawn_script.scene_path(point.kind()) == variety.kind(ID).scene,
				"%s/%s: BigSlot_ArmouredScorpion_1 spawns it" % slot)
		var enemy: Node = load(variety.kind(ID).scene).instantiate()
		enemy.enemy_stats = point.enemy_stats()
		enemy.level = level
		enemy.position = ARENA
		game.map.add_child(enemy)
		await process_frame
		var grown: Dictionary = variety.level(enemy.scaled_level)  # D840: еліта — рівень бою + 1 (герой 1-го рівня, без зони)
		ck(enemy.elite and enemy.scaled_level == level + 1 and enemy.size_kind == "medium" and enemy.Max_Health == roundi(stats.max_health * grown.health * 2.5)
				and is_equal_approx(enemy.base_damage, stats.base_damage * grown.damage * variety.elite().damage) and enemy.xp_reward == stats.xp_reward,
				"%s, level %d: an elite, HP %d, damage %.1f, XP %d" % [slot[1], level, enemy.Max_Health, enemy.base_damage, enemy.xp_reward])
		enemy.queue_free()
		room.free()
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var entry: Array = bestiary.enemies.filter(func(e: Dictionary) -> bool: return e.kind == ID)
	var en: Translation = load("res://SampleProject/Resources/Translations/en.po")
	var uk: Translation = load("res://SampleProject/Resources/Translations/uk.po")
	ck(entry.size() == 1 and en.get_message(entry[0].name) != StringName() and en.get_message(entry[0].text) != StringName() and entry[0].name == "Armoured Scorpion" and String(uk.get_message(entry[0].name)) == "Броньований скорпіон"
			and uk.get_message(entry[0].text) != StringName(), "bestiary: Armoured Scorpion, in English and Ukrainian")
	await process_frame


## [7] Старий гриф (D652, D692): живий великий вид — свій аркуш і сцена, поведінка грифа (летить, піке), числа еліти
## на рівні бою (D642). Точок BigSlot_OldVulture_* немає (D682): перший гриф дороги — звичайний і сам (D582), а в
## Каравані вже є великий скорпіон. Тест бере точку грифа з big_kind = old_vulture на рівнях дороги, де літають грифи.
func _old_vulture() -> void:
	print("[7] The old vulture is live: its own art, the vulture's behaviour, elite numbers at the road's levels")
	const ID := "old_vulture"
	ck(variety.available(ID) and variety.kind(ID).sheet.ends_with("vulture_old/sheet.png")
			and variety.kind(ID).scene == "res://SampleProject/Scenes/Characters/Enemies/enemy_old_vulture.tscn", "its sheet, scene and stats exist")
	var vulture: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_vulture.tres")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % ID)
	ck(stats.enemy_type == ID and stats.flying and stats.flight_attack == vulture.flight_attack and stats.tell == vulture.tell
			and stats.max_health == vulture.max_health and is_equal_approx(stats.base_damage, vulture.base_damage)
			and is_equal_approx(stats.attack_windup, vulture.attack_windup) and is_equal_approx(stats.hover_height, vulture.hover_height)
			and stats.xp_reward == vulture.xp_reward,
			"the vulture's behaviour: flies, %s, %s tell, base HP %d / damage %.0f / XP %d as the vulture"
			% [stats.flight_attack, stats.tell, stats.max_health, stats.base_damage, stats.xp_reward])
	var placed: Array = []
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var room: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for p: Node in room.find_children("*", "Node2D", true, false):
			if p.get_script() == spawn_script and (p.big_kind == ID or p.enemy_type == ID):
				placed.append("%s/%s" % [file.get_basename(), p.get_parent().name])
		room.free()
	ck(placed == ["DesertRoad/Fight_OldVulture"], "D722: its one place is DesertRoad Fight_OldVulture, alone over a chest (%s)" % [placed])
	for level in [2, 3]:
		var point: Node = spawn_script.new()
		point.enemy_type = "vulture"
		point.big_kind = ID
		ck(point.kind() == ID and spawn_script.scene_path(point.kind()) == variety.kind(ID).scene, "a vulture point with big_kind old_vulture spawns it")
		var enemy: Node = load(variety.kind(ID).scene).instantiate()
		enemy.enemy_stats = point.enemy_stats()
		enemy.level = level
		enemy.position = ARENA + Vector2(0, -150)
		game.map.add_child(enemy)
		await process_frame
		var grown: Dictionary = variety.level(enemy.scaled_level)  # D840: еліта — рівень бою + 1 (герой 1-го рівня, без зони)
		ck(enemy.elite and enemy.scaled_level == level + 1 and enemy.size_kind == "medium" and enemy.flying and enemy.Max_Health == roundi(stats.max_health * grown.health * 2.5)
				and is_equal_approx(enemy.base_damage, stats.base_damage * grown.damage * variety.elite().damage) and enemy.xp_reward == stats.xp_reward,
				"level %d: a flying elite, HP %d, damage %.1f, XP %d" % [level, enemy.Max_Health, enemy.base_damage, enemy.xp_reward])
		enemy.queue_free()
		point.free()
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var entry: Array = bestiary.enemies.filter(func(e: Dictionary) -> bool: return e.kind == ID)
	var en: Translation = load("res://SampleProject/Resources/Translations/en.po")
	var uk: Translation = load("res://SampleProject/Resources/Translations/uk.po")
	ck(entry.size() == 1 and entry[0].name == "Old Vulture" and en.get_message(entry[0].name) != StringName() and en.get_message(entry[0].text) != StringName()
			and String(uk.get_message(entry[0].name)) == "Старий гриф" and uk.get_message(entry[0].text) != StringName(),
			"bestiary: Old Vulture, in English and Ukrainian")
	await process_frame


## [9] Бандит-громило (D652, D693): живий вид-еліта з власним аркушем на поведінці бандита (default_enemy) — повільний
## важкий удар булавою в землю; тіло й HP бандита, множники еліти й рівня бою (D642 — бій перевіряє verify_difficulty).
## Розстановка (D582, D682): кожна точка BigSlot_BanditBrute_* спавнить його; уперше — сам у Fight_LoneElite.
func _brute() -> void:
	print("[9] The bandit brute (D652, D693): a live elite kind on the bandit's behaviour with a slow heavy smash")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_bandit_brute.tres")
	var melee: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	ck(variety.available("bandit_brute") and variety.is_elite("bandit_brute")
			and spawn_script.scene_path("bandit_brute") == SCENES.bandit_brute,
			"its sheet, scene and stats exist: the kind spawns, and it is an elite")
	var same := true
	for prop in ["base_damage", "max_health", "xp_reward", "detection_range", "chase_range", "flying"]:
		same = same and stats.get(prop) == melee.get(prop)
	ck(stats.enemy_type == "bandit_brute" and same, "the bandit's HP, blow and XP (enemy_melee), its own kind for the bestiary and the elite marks")
	ck(stats.attack_windup > melee.attack_windup and stats.speed < melee.speed and stats.combo_hits == 1 and stats.tell == "dodge"
			and stats.poise > melee.poise and stats.recovery > melee.recovery,
			"a slow heavy smash: windup %.1f s (bandit %.1f), one blow, red glint (dodge only), walks %d (bandit %d), poise %d, recovery %.2f s"
			% [stats.attack_windup, melee.attack_windup, stats.speed, melee.speed, stats.poise, stats.recovery])
	var sheet: Texture2D = load(variety.kind("bandit_brute").sheet)
	var enemy: Node = load(SCENES.bandit_brute).instantiate()
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	ck(sheet.resource_path.ends_with("Enemies/bandit_brute/sheet.png") and sheet.get_width() == 96 * sprite.hframes
			and sheet.get_height() == 96 * sprite.vframes and sprite.hframes == 4 and sprite.vframes == 5,
			"the D693 sheet, 96x96 cells, rows idle / walk / attack / hurt / death (%dx%d)" % [sprite.hframes, sprite.vframes])
	var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
	var frames := {}
	for a: StringName in [&"idle", &"walk", &"attack", &"stagger", &"death"]:
		frames[a] = HitAreas.anim_frames(anim, a, 0.0, INF)
	ck(frames == {&"idle": [0, 1], &"walk": [4, 5, 6, 7], &"attack": [8, 9, 10], &"stagger": [12], &"death": [16, 17, 18]},
			"animations play the sheet's rows (%s)" % [frames])
	var strike: float = anim.get_meta(&"attack_strike_time")
	ck(HitAreas.anim_frames(anim, &"attack", 0.0, strike) == [8] and HitAreas.anim_frames(anim, &"attack", strike, strike + stats.attack_active_time) == [9],
			"the club is over his shoulder for the whole windup, and the live strike is the smash into the ground (frame 9)")
	var smash := HitAreas.frame_rect(sprite, 9)
	var hit := HitAreas.shape_rect(enemy.get_node(^"hitbox/CollisionShape2D"))
	ck(absf(hit.end.x - smash.end.x) <= 1.0 and absf(hit.end.y - smash.end.y) <= 1.0,
			"the hitbox's front is the club on the ground (%.1f, floor %.1f; drawn %.1f, %.1f)" % [hit.end.x, hit.end.y, smash.end.x, smash.end.y])
	ck(not variety.kind("bandit_brute").has("foam"), "no cursed foam: he is a man, not one of the alchemist's beasts")
	enemy.free()
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var entry: Array = bestiary.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "bandit_brute")
	ck(entry.size() == 1 and _translated(entry[0].name) and _translated(entry[0].text), "bestiary entry, en and uk")

	# Кожна точка громила в кожній кімнаті спавнить його.
	var placed: Array[String] = []
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var room: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for p: Node in room.find_children("BigSlot_BanditBrute_*", "Node2D", true, false):
			var fight: Node = p.get_parent()
			var big: Array = []
			for q: Node in fight.get_children():
				if q.get_script() == spawn_script and variety.is_elite(q.kind()):
					big.append(q.kind())
			placed.append("%s %s/%s L%d, elites in the fight %s" % [file.get_basename(), fight.name, p.name, fight.enemy_level, big])
			ck(p.kind() == "bandit_brute" and p.enemy_type == "melee", "%s/%s spawns the bandit brute" % [fight.name, p.name])
		room.free()
	print("  info bandit brutes: %s" % ", ".join(placed))
	ck(placed.size() == 4, "four slots: DesertRoad Fight_LoneElite, the Bandit Camp's Fight_Camp (D698), Laboratory Fight_Upper x2 (%d)" % placed.size())

	# Живий бій Fight_LoneElite (рівень 2): громило сам, еліта рівня бою, ноги на лінії бандита.
	var lone: Node = game.map.get_node(^"Fight_LoneElite")
	ck(lone.spawn_points.size() == 1 and lone.enemy_level == 2, "Fight_LoneElite: the brute alone, the road's first elite (D582)")
	lone.spawn_all_enemies()
	await create_timer(0.5).timeout
	var brute: Node = lone.get_node(^"Enemy_Fight_LoneElite_EnemySpawnPoint1")
	var grown: Dictionary = variety.level(brute.scaled_level)  # D840: еліта — рівень бою + 1 (герой 1-го рівня)
	var marks: Dictionary = variety.elite()
	ck(brute.scene_file_path == SCENES.bandit_brute and brute.elite and brute.level == 2 and brute.scaled_level == 3
			and brute.Max_Health == roundi(stats.max_health * grown.health * marks.health)
			and is_equal_approx(brute.base_damage, stats.base_damage * grown.damage * marks.damage),
			"in the game it is the bandit brute, an elite of a level-2 fight at level 3 (D840): HP %d, damage %.1f" % [brute.Max_Health, brute.base_damage])
	var bandit: Node = load(SCENES.melee).instantiate()
	var feet := [HitAreas.frame_rect(brute.get_node(^"Sprite2D"), 0).end.y, HitAreas.frame_rect(bandit.get_node(^"Sprite2D"), 0).end.y]
	bandit.free()
	ck(absf(feet[0] - feet[1]) <= 1.0, "his drawn feet stand on a medium bandit's line (%.1f vs %.1f px below his centre)" % feet)
	lone.despawn_all_enemies()
	await process_frame


## Розбитий вартовий: зона-ціль, хітбокс і тіло — з малюнка без щита (B128, як міряє verify_hit_areas), attack_range
## меншає на стільки, на скільки коротшав удар. Вартовий дивиться ліворуч — зони дзеркальні.
func _check_broken_areas(guard: Node, range_before: float, reach_before: float) -> void:
	var sprite: Sprite2D = guard.enemy_view.rest_sprite()
	var mirror := func(r: Rect2) -> Rect2: return Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)
	var body: Rect2 = mirror.call(HitAreas.body_rect(sprite, guard.anim_player))
	var strike := HitAreas.strike_rect(sprite, guard.anim_player, guard.attack_active_time)
	var reach: Rect2 = mirror.call(Rect2(0.0, strike.position.y, strike.end.x, strike.size.y))
	var hurt := HitAreas.shape_rect(guard.get_node(^"Hurtbox/CollisionShape2D"))
	var hit := HitAreas.shape_rect(guard.get_node(^"hitbox/CollisionShape2D"))
	ck(hurt.is_equal_approx(body) and hit.is_equal_approx(reach), "broken: hurtbox %s = the shieldless body, hitbox %s = its strike" % [hurt, hit])
	var body_half: float = guard.get_node(^"CollisionShape2D").shape.get_rect().end.x
	ck(is_equal_approx(body_half, -body.position.x), "broken: the blocking body's front is his own front, %.1f px" % body_half)
	const HERO_HALF := 12.0  # verify_hit_areas
	ck(guard.attack_range > body_half + HERO_HALF and is_equal_approx(guard.attack_range - strike.end.x, range_before - reach_before)
			and is_equal_approx(guard.enemy_logic.attack_range, guard.attack_range),
			"broken: attack_range %.1f → %.1f, as much closer as his strike got shorter (%.1f → %.1f); past body contact %.1f"
			% [range_before, guard.attack_range, reach_before, strike.end.x, body_half + HERO_HALF])
	sprite.free()


## [8] Вартовий з баштовим щитом (D652, D693): живий великий вид — свій аркуш і сцена, поведінка щитоносця (спереду
## щит, у спину тіло, важкий удар розбиває щит): щит розлітається скалками, і вартовий далі без щита (D843). Числа еліти на рівнях, де стоять щитоносці (D642). Точок BigSlot_TowerShieldGuard_* немає (D682).
func _tower_guard() -> void:
	print("[8] The tower shield guard is live: its own art, the shield-bearer's behaviour, a broken shield stays broken, elite numbers")
	const ID := "tower_shield_guard"
	ck(variety.available(ID) and variety.kind(ID).sheet.ends_with("shield_tower/sheet.png")
			and spawn_script.scene_path(ID) == "res://SampleProject/Scenes/Characters/Enemies/enemy_tower_shield_guard.tscn", "its sheet, scene and stats exist")
	var shield: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_shield.tres")
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % ID)
	ck(stats.enemy_type == ID and stats.tell == shield.tell and stats.max_health == shield.max_health
			and is_equal_approx(stats.base_damage, shield.base_damage) and is_equal_approx(stats.attack_windup, shield.attack_windup)
			and stats.xp_reward == shield.xp_reward,
			"the shield-bearer's numbers: %s tell, base HP %d / damage %.0f / XP %d" % [stats.tell, stats.max_health, stats.base_damage, stats.xp_reward])

	var guard: Node = load(spawn_script.scene_path(ID)).instantiate()
	guard.enemy_stats = stats
	guard.position = ARENA
	game.map.add_child(guard)
	await create_timer(0.3).timeout
	guard.poise_max = 99
	guard.poise = 99
	guard.enemy_logic.last_direction = -1
	guard._on_logic_direction_changed(-1)
	guard.set_physics_process(false)  # стоїть і не б'є
	var blocked: Array = []
	var broken: Array = []
	var staggered: Array = []
	eb.enemy_shield_blocked.connect(func(e: Node, at: Vector2) -> void: blocked.append([e, at]))
	eb.enemy_shield_broken.connect(func(e: Node, _at: Vector2) -> void: broken.append(e))
	eb.enemy_staggered.connect(func(e: Node, t: float) -> void: staggered.append([e, t]))
	var hp: int = guard.current_health
	var shield_at: Node2D = guard.get_node(^"Sprite2D/Shield")

	await _place_hero(guard, -45)
	await _tap(&"attack")
	await create_timer(0.5).timeout
	ck(guard.current_health == hp and blocked.size() == 1 and blocked[0][0] == guard and guard.poise == 99,
			"a light hit from the front: blocked (HP %d → %d, blocks %d, poise %d)" % [hp, guard.current_health, blocked.size(), guard.poise])
	ck(guard.shield_up and shield_at.position.x < 0.0 and blocked[0][1].x < guard.global_position.x,
			"the sparks come off the drawn shield, in front (left): %.0f px" % (blocked[0][1].x - guard.global_position.x))

	await create_timer(1.0).timeout
	await _place_hero(guard, 45)
	await _tap(&"attack")
	await create_timer(0.5).timeout
	ck(guard.current_health < hp and blocked.size() == 1, "a hit in the back lands (HP %d → %d)" % [hp, guard.current_health])
	hp = guard.current_health

	await create_timer(1.0).timeout
	guard.set_physics_process(true)  # збій спливає в _physics_process
	var range_before: float = guard.attack_range
	var reach_before := HitAreas.shape_rect(guard.get_node(^"hitbox/CollisionShape2D")).size.x
	var bursts: Array[Dictionary] = []
	game.map.child_entered_tree.connect(func(n: Node) -> void:
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).animation == &"break":
			var seen := func() -> void:
				var still: Sprite2D = guard.enemy_view.rest_sprite()
				bursts.append({transform = n.global_transform, offset = n.offset, flip_h = n.flip_h, cell = guard.global_transform * Transform2D(0.0, still.scale, 0.0, still.position),
						frames = n.sprite_frames.get_frame_count(&"break"), texture = n.sprite_frames.get_frame_texture(&"break", 0).resource_path})
				still.free()
			seen.call_deferred())
	await _place_hero(guard, -45)
	await _tap(&"heavy_attack")
	await create_timer(0.6).timeout
	var guard_break: float = variety.shield().guard_break_stagger
	ck(not guard.shield_up and broken == [guard] and guard.current_health == hp,
			"a heavy attack from the front breaks the guard, the shield takes the blow (broken %d, HP %d)" % [broken.size(), guard.current_health])
	ck(staggered.any(func(s: Array) -> bool: return s[0] == guard and is_equal_approx(s[1], guard_break))
			and guard.enemy_view.staggered and guard.get_node(^"Sprite2D").frame == 12,
			"guard break: staggered %.1f s on the hurt frame, the shield knocked aside (frame %d)" % [guard_break, guard.get_node(^"Sprite2D").frame])
	var sprite: Sprite2D = guard.get_node(^"Sprite2D")
	ck(sprite.texture == guard.noshield_sheet and guard.noshield_sheet.resource_path.ends_with("shield_tower/sheet_noshield.png"),
			"the shield is gone from his frames: the shieldless sheet (D843)")
	ck(bursts.size() == 1 and bursts[0].frames == 4 and bursts[0].texture.ends_with("shield_break_1.png"),
			"the shield bursts into shards (shield_break_1-4): %d burst" % bursts.size())
	if bursts.size() == 1:
		var burst: Dictionary = bursts[0]
		ck(burst.transform.is_equal_approx(burst.cell) and burst.offset == Vector2(0, -13) and burst.flip_h and sprite.flip_h,
				"the shards stand on his cell at rest (scale %.2f), mirrored to his facing (left)" % burst.transform.get_scale().x)
	var tracks: Array[String] = []
	for anim_name in guard.anim_player.get_animation_list():
		var anim: Animation = guard.anim_player.get_animation(anim_name)
		for t in anim.get_track_count():
			if String(anim.track_get_path(t)).ends_with(":texture"):
				tracks.append("%s/%d" % [anim_name, t])
	ck(tracks.is_empty(), "no animation of his keys Sprite2D:texture, so nothing puts the shield back %s" % [tracks])
	_check_broken_areas(guard, range_before, reach_before)
	await _place_hero(guard, -45)
	guard.take_damage(20, hero)  # удар спереду, поки герой ще виходить із важкого
	ck(guard.current_health < hp and blocked.size() == 1, "guard broken: a light hit from the front lands (HP %d → %d)" % [hp, guard.current_health])
	hp = guard.current_health

	await create_timer(guard_break + 0.5).timeout
	guard.set_physics_process(false)
	guard.enemy_logic.last_direction = -1
	guard._on_logic_direction_changed(-1)
	ck(not guard.shield_up and sprite.texture == guard.noshield_sheet, "after the stagger the shield does not come back (D843)")
	ck(game.map.get_children().all(func(n: Node) -> bool: return not (n is AnimatedSprite2D and n.animation == &"break")),
			"the shards are gone once they have played")
	await _place_hero(guard, -45)
	await _tap(&"attack")
	await create_timer(0.5).timeout
	ck(guard.current_health < hp and blocked.size() == 1, "a light hit from the front still lands (HP %d → %d, blocks %d)" % [hp, guard.current_health, blocked.size()])
	for anim_name in [&"walk", &"attack", &"stagger", &"idle"]:
		guard.anim_player.play(anim_name)
		guard.anim_player.advance(0.3)
	ck(sprite.texture == guard.noshield_sheet, "playing his animations keeps the shieldless sheet")
	guard.queue_free()

	var placed: Array = []
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var room: Node = load("res://SampleProject/Maps/" + file).instantiate()
		for p: Node in room.find_children("*", "Node2D", true, false):
			if p.get_script() == spawn_script and p.big_kind == ID:
				placed.append("%s/%s/%s" % [file.get_basename(), p.get_parent().name, p.name])
		room.free()
	ck(placed == ["LabGuardPocket/Fight_TowerGuard/BigSlot_TowerShieldGuard_1"], "D724: its one place is the Laboratory guard's alcove (LabGuardPocket) Fight_TowerGuard, alone over a chest (%s)" % [placed])
	for level in [3, 10]:
		var point: Node = spawn_script.new()
		point.enemy_type = "shield"
		point.big_kind = ID
		ck(point.kind() == ID, "a shield point with big_kind tower_shield_guard spawns it")
		var enemy: Node = load(spawn_script.scene_path(point.kind())).instantiate()
		enemy.enemy_stats = point.enemy_stats()
		enemy.level = level
		enemy.position = ARENA + Vector2(0, 0)
		game.map.add_child(enemy)
		await process_frame
		var grown: Dictionary = variety.level(enemy.scaled_level)  # D840: еліта — рівень бою + 1 (герой 1-го рівня, без зони)
		ck(enemy.elite and enemy.scaled_level == level + 1 and enemy.size_kind == "medium" and enemy.Max_Health == roundi(stats.max_health * grown.health * 2.5)
				and is_equal_approx(enemy.base_damage, stats.base_damage * grown.damage * variety.elite().damage) and enemy.xp_reward == stats.xp_reward,
				"level %d: an elite, HP %d, damage %.1f, XP %d" % [level, enemy.Max_Health, enemy.base_damage, enemy.xp_reward])
		enemy.queue_free()
		point.free()
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	var entry: Array = bestiary.enemies.filter(func(e: Dictionary) -> bool: return e.kind == ID)
	var en: Translation = load("res://SampleProject/Resources/Translations/en.po")
	var uk: Translation = load("res://SampleProject/Resources/Translations/uk.po")
	ck(entry.size() == 1 and entry[0].name == "Tower Shield Guard" and en.get_message(entry[0].text) != StringName()
			and String(uk.get_message(entry[0].name)) == "Вартовий з баштовим щитом" and uk.get_message(entry[0].text) != StringName(),
			"bestiary: Tower Shield Guard, in English and Ukrainian")
	await process_frame


func _translated(text: String) -> bool:
	var ok := true
	for lang in ["en", "uk"]:
		var po: String = FileAccess.get_file_as_string("res://SampleProject/Resources/Translations/%s.po" % lang)
		ok = ok and po.contains("msgid \"%s\"\nmsgstr \"" % text) and not po.contains("msgid \"%s\"\nmsgstr \"\"" % text)
	return ok
