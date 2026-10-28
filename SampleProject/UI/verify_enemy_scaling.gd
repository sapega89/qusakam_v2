extends SceneTree

## Рівень ворогів за героєм (D840; EnemyScaling), часткове: рівень ворога = підлога + зсув зони + зсув виду
## + ⌊max(0, герой − підлога) × 0.5⌋, не вище XPManager.MAX_LEVEL. Підлога звичайного й еліти — enemy_level бою (D670),
## боса — рівень, під який зроблено його числа (enemy_variety.json scaling.boss_levels). Зсув виду: звичайний 0, еліта +1,
## бос +2; зсув зони — scaling.zone_offsets за кімнатою (Laboratory +1, BanditCamp +1, решта 0; у боса зони немає).
##   [1] формула на рівнях героя 1, 5, 10, 20 — підлоги 1, 4, 9, 19 і зони 0, +1 — і дані зон;
##   [2] звичайний бандит: рівень, HP і шкода за таблицями levels, досвід не росте (D670, verify_xp_curve);
##   [3] еліта (бандит-громило): рівень +1, HP і шкода з множниками еліти, досвід — свій;
##   [4] підлога: бій 9-го рівня не слабшає перед героєм 1-го і 5-го й росте на половину відриву героя 20-го;
##   [5] боси (Brass Collector, Scorpicore, Fire Djinn, Mercenary): підлога + 2 + половина відриву, HP і шкода — відношення
##       таблиць levels до підлоги, ходи й досвід ті самі;
##   [6] повернення ворогів (D492): після медитації бій Dunes зʼявляється на новому рівні героя;
##   [7] зона: вороги бою Лабораторії (Fight_Fly, рівень 8) стоять на сходинку вище, ніж той самий бій без зони.
##   godot --headless --path . --script res://SampleProject/UI/verify_enemy_scaling.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const HERO_LEVELS: Array[int] = [1, 5, 10, 20]
const BOSSES := {
	"brass_collector": "res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn",
	"scorpicore_warrior": "res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn",
	"fire_djinn": "res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn",
	"lab_boss": "res://SampleProject/Scenes/Characters/Bosses/lab_boss.tscn",
}

var fails: Array[String] = []
var game: Node
var xp: Node
var Scaling: Script
var Variety: Script
var SpawnPoint: Script


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	Scaling = load("res://SampleProject/Scripts/Gameplay/EnemyScaling.gd")
	Variety = load("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
	SpawnPoint = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	game = await Kit.boot(self)
	xp = root.get_node("ServiceLocator").get_xp_manager()
	game.player.set_physics_process(false)

	_formula()
	await _ordinary()
	await _elite()
	await _floor()
	await _bosses()
	await _respawn()
	await _zone()

	xp.restore(1, 0)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


func _formula() -> void:
	print("[1] the formula: floor + zone + kind + ⌊max(0, hero − floor) × 0.5⌋, capped at 20; kinds ordinary 0, elite +1, boss +2")
	var scaling: Dictionary = Variety.data().scaling
	var offsets: Dictionary = scaling.offsets
	ck(int(offsets.ordinary) == 0 and int(offsets.elite) == 1 and int(offsets.boss) == 2, "offsets %s" % [offsets])
	ck(Scaling.HERO_LEAD_SHARE == 0.5, "an enemy gains half the hero's lead over its floor (%s)" % Scaling.HERO_LEAD_SHARE)
	ck(Scaling.zone_offset("Laboratory") == 1 and Scaling.zone_offset("BanditCamp") == 1 and Scaling.zone_offset("DesertRoad") == 0
			and Scaling.zone_offset("LabBoss") == 0 and scaling.zone_offsets.size() == 5
			and ["LabMiddleFloor", "LabTopFloor", "LabGuardPocket"].all(func(r: String) -> bool: return Scaling.zone_offset(r) == 1),
			"zones: the Laboratory's fight rooms +1 (its three floors and the guard's alcove, v3), Bandit Camp +1, every other room 0 (%s)" % [scaling.zone_offsets])
	# [підлога, зона] → герой → [звичайний, еліта, бос]
	var expect := {
		[1, 0]: {1: [1, 2, 3], 5: [3, 4, 5], 10: [5, 6, 7], 20: [10, 11, 12]},
		[4, 1]: {1: [5, 6, 7], 5: [5, 6, 7], 10: [8, 9, 10], 20: [13, 14, 15]},
		[9, 0]: {1: [9, 10, 11], 5: [9, 10, 11], 10: [9, 10, 11], 20: [14, 15, 16]},
		[9, 1]: {1: [10, 11, 12], 5: [10, 11, 12], 10: [10, 11, 12], 20: [15, 16, 17]},
		[19, 1]: {1: [20, 20, 20], 5: [20, 20, 20], 10: [20, 20, 20], 20: [20, 20, 20]},
	}
	for room: Array in expect:
		for hero: int in HERO_LEVELS:
			var got := []
			for kind: String in ["ordinary", "elite", "boss"]:
				got.append(Scaling.scaled_level(room[0], room[1], hero, kind))
			ck(got == expect[room][hero], "floor %d, zone +%d, hero %d: ordinary / elite / boss %s (expected %s)"
					% [room[0], room[1], hero, got, expect[room][hero]])


## Ворог виду [param kind] з підлогою [param floor_level] — як його ставить RoomEnemySpawner (розмір medium), поза
## ареною й без обробки: рахуються лише стати, як у verify_difficulty.
func _spawn(kind: String, floor_level: int) -> Node:
	var enemy: Node = (load(SpawnPoint.scene_path(kind)) as PackedScene).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	enemy.size_kind = "medium"
	enemy.level = floor_level
	_add(enemy)
	return enemy


func _add(enemy: Node) -> void:
	enemy.position = Vector2(-100000, -100000)
	game.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED


## HP, шкода й досвід, які має дати рівень [param level] виду [param kind] (та сама послідовність множень, що й гра).
func _check_stats(enemy: Node, kind: String, level: int, label: String) -> void:
	var stats: Resource = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	var size: Dictionary = Variety.size("medium")
	var grown: Dictionary = Variety.level(level)
	var health: float = size.health * grown.health
	var hit: float = size.damage * grown.damage
	var xp_mult: float = size.xp
	if Variety.is_elite(kind):
		var marks: Dictionary = Variety.elite()
		health *= marks.health
		hit *= marks.damage
		xp_mult *= marks.xp
	ck(enemy.scaled_level == level and enemy.Max_Health == roundi(stats.max_health * health)
			and is_equal_approx(enemy.base_damage, stats.base_damage * hit) and enemy.xp_reward == roundi(stats.xp_reward * xp_mult),
			"%s: level %d, HP %d, damage %.1f, XP %d (the base XP %d does not grow with the level)"
			% [label, enemy.scaled_level, enemy.Max_Health, enemy.base_damage, enemy.xp_reward, stats.xp_reward])


func _ordinary() -> void:
	print("[2] an ordinary bandit from a level-1 fight gains half the hero's lead: hero 1 / 5 / 10 / 20 → 1 / 3 / 5 / 10")
	var want := {1: 1, 5: 3, 10: 5, 20: 10}
	for hero: int in HERO_LEVELS:
		xp.restore(hero, 0)
		var bandit := _spawn("melee", 1)
		await process_frame
		_check_stats(bandit, "melee", want[hero], "hero %d, bandit" % hero)
		bandit.queue_free()
	await process_frame


func _elite() -> void:
	print("[3] an elite (bandit brute) from a level-1 fight stands one above an ordinary one: 2 / 4 / 6 / 11")
	ck(Variety.is_elite("bandit_brute"), "the bandit brute is an elite kind")
	var want := {1: 2, 5: 4, 10: 6, 20: 11}
	for hero: int in HERO_LEVELS:
		xp.restore(hero, 0)
		var brute := _spawn("bandit_brute", 1)
		await process_frame
		_check_stats(brute, "bandit_brute", want[hero], "hero %d, elite bandit brute" % hero)
		brute.queue_free()
	await process_frame


func _floor() -> void:
	print("[4] the floor: a level-9 fight does not get weaker for a low hero and grows by half a hero 20's lead: 9 / 9 / 9 / 14")
	var want := {1: 9, 5: 9, 10: 9, 20: 14}
	for hero: int in HERO_LEVELS:
		xp.restore(hero, 0)
		var scorpion := _spawn("tank", 9)
		await process_frame
		_check_stats(scorpion, "tank", want[hero], "hero %d, scorpion of a level-9 fight" % hero)
		ck(scorpion.level == 9, "hero %d: its fight level (floor) stays 9 (%d)" % [hero, scorpion.level])
		scorpion.queue_free()
	await process_frame


func _bosses() -> void:
	print("[5] bosses: two above the level their numbers were made for, plus half the hero's lead over it; moves and XP unchanged")
	for id: String in BOSSES:
		var floor_level: int = Scaling.boss_level(id)
		for hero: int in HERO_LEVELS:
			xp.restore(hero, 0)
			var boss: Node = (load(BOSSES[id]) as PackedScene).instantiate()
			var stats: Resource = boss.enemy_stats
			var moves: Array = boss.moves.duplicate(true)
			_add(boss)
			await process_frame
			var level: int = mini(floor_level + 2 + maxi(0, hero - floor_level) / 2, 20)
			var at: Dictionary = Variety.level(floor_level)
			var now: Dictionary = Variety.level(level)
			ck(boss.level == floor_level and boss.scaled_level == level
					and boss.Max_Health == roundi(stats.max_health * (now.health / at.health))
					and is_equal_approx(boss.base_damage, stats.base_damage * (now.damage / at.damage))
					and boss.xp_reward == stats.xp_reward and boss.moves == moves,
					"%s, hero %d: level %d (floor %d), HP %d (made %d), damage %.1f (made %.0f), XP %d"
					% [id, hero, boss.scaled_level, floor_level, boss.Max_Health, stats.max_health, boss.base_damage,
					stats.base_damage, boss.xp_reward])
			boss.queue_free()
			await process_frame
	ck(Scaling.boss_level("scorpicore_warrior") == 5 and Scaling.boss_level("lab_boss") == 16,
			"floors: the Scorpicore's numbers were made for level 5 (D678), the Mercenary's for 16 (D661)")


func _respawn() -> void:
	print("[6] D492: enemies that come back after a meditation are rescaled to the hero's new level")
	xp.restore(1, 0)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	await Kit.frames(self, 16)
	await Kit.drain(self)
	var hero: Node = game.player
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	await process_frame
	var spawner: Node = game.map.get_node(^"Fight_Dunes")
	ck(spawner.respawns and spawner.enemy_level == 2, "Fight_Dunes is an ordinary level-2 fight (respawns %s, level %d)"
			% [spawner.respawns, spawner.enemy_level])
	for hero_level: int in [1, 10]:
		xp.restore(hero_level, 0)
		await spawner.spawn_all_enemies()
		await Kit.frames(self, 4)
		var got: Array = []
		var want: Array = []
		for enemy: Node in spawner.spawned_enemies:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			got.append(enemy.scaled_level)
			want.append(Scaling.scaled_level(2, 0, hero_level, "elite" if enemy.elite else "ordinary"))
		ck(not got.is_empty() and got == want, "hero %d: the Dunes enemies stand at %s (expected %s)" % [hero_level, got, want])
		for enemy: Node in spawner.spawned_enemies:
			enemy.queue_free()
		spawner.spawned_enemies.clear()
		await process_frame
		game.meditate()  # D492: бій забуває своїх — наступний запуск спавнить усіх заново
		# У грі вороги повертаються з новим завантаженням кімнати, тобто з новими точками; ці вже spawn_once.
		for point: Node in spawner.spawn_points:
			point.has_spawned = false


func _zone() -> void:
	print("[7] a zone: the Laboratory's fights stand one step above the same fight elsewhere (zone +1)")
	xp.restore(1, 0)
	await game.teleport_to_room("res://SampleProject/Maps/Laboratory.tscn", ^"SavePoint_Entrance/Seat")
	await Kit.frames(self, 16)
	await Kit.drain(self)
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	await process_frame
	var spawner: Node = game.map.get_node(^"Fight_Fly")
	await spawner.spawn_all_enemies()
	await Kit.frames(self, 4)
	var got: Array = []
	for enemy: Node in spawner.spawned_enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		got.append([enemy.zone_offset, enemy.scaled_level, enemy.scaled_level - Scaling.scaled_level(8, 0, 1, "elite" if enemy.elite else "ordinary")])
	ck(spawner.enemy_level == 8 and not got.is_empty() and got.all(func(g: Array) -> bool: return g[0] == 1 and g[2] == 1),
			"hero 1, Laboratory/Fight_Fly (level 8): [zone, level, steps above the zone-less fight] %s" % [got])
	for enemy: Node in spawner.spawned_enemies:
		enemy.queue_free()
	await process_frame
