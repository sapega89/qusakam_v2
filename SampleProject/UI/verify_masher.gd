extends SceneTree

## Справжній бій (D642, D754): verify_difficulty рахує удари на папері, а тут герой б'ється в справжній кімнаті
## маршруту, справжніми подіями вводу, проти справжнього AI. Герой — рівня, на якому він туди приходить
## (XP-крива, як verify_difficulty), зі спорядженням маршруту й збіркою SKILLS або STRENGTH (verify_difficulty._make_hero).
## Два боти:
##   MASHER — лише легкий удар (і важкий, щойно серія скінчилась), іде на ворога, п'є флягу на низькому HP;
##            ніколи не блокує, не парирує, не робить ривка й не стрибає;
##   GOOD   — те саме, але на показану підказку білий і жовтий удари блокує (жовтий парирує, далі рипост), від
##            червоного робить ривок геть; флягу п'є й навичками б'є (коли є SP), лише коли поруч ніхто не замахується.
## Звіт по кожному бою: хто переміг, HP героя, час, скільки ударів ворога влучило, скільки секунд кожен ворог
## стояв збитий (збій, оглушення, відкидання), скільки замахів зірвано й скільки разів кілька ворогів били разом.
## Перевірки (D642): [1] MASHER перемагає одного звичайного ворога, але втрачає HP; [2] MASHER (обидві збірки) програє
## кожній еліті, обом босам і групі з 3+; [3] GOOD перемагає їх (SKILLS); [4] бос, як його зустрічає гравець (вхід у
## кімнату, кат-сцена, смужка боса, музика бою), б'є зброєю героя, що стоїть і тисне удар, і героя, що чекає трохи поза
## досяжністю сокири (B159); [5] вороги роблять випади (D768), шакал учепився в масера (D769), а група стоїть з обох боків
## героя (D770). Кожен бій друкує ще: за скільки с вороги дійшли до героя, яку частку часу вони були з обох боків, випади й хватки.
## Бій групи хаотичний (кадр туди-сюди — інша гілка): не той результат — друга спроба з іншими кидками, і вимога —
## хоч в одній з двох.
##   godot --headless --path . --script res://SampleProject/UI/verify_masher.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
## Поруч героя для «з обох боків» (D770), px — як EnemyLogic.FLANK_NEAR.
const FLANK_NEAR := 320.0

## Гра йде в SPEED раз швидше за годинник, а фізика — у SPEED раз частіше: крок фізики той самий, 1/60 с.
const SPEED := 4.0
## Бій довше за CAP с ігрового часу — нічия (рахується як «не переміг»).
const CAP := 150.0
const ROUTE := ["Canyon", "Village", "DesertRoad", "CityGates", "City", "MayorHall", "LabCells", "Laboratory", "LabBoss"]
const CITY_INDEX := 4
const GEAR_ROAD := {"sword": "copper_sword", "body": "leather_armor"}
const GEAR_CITY := {"sword": "iron_sword", "body": "iron_armor", "shield": "iron_shield"}
const SKILL_ATTRIBUTES := {"strength": 2, "vitality": 2, "wisdom": 1}
const SKILL_ORDER := ["toughness", "shield_block", "weapon_training", "radiant_smite", "devotion", "fire_strike",
		"riposte_instinct", "aura_of_resolve", "mending_hands", "skys_grace", "skyfall_blessing", "fortitude", "last_stand"]
const OATH := "paladin"
const OATH_LEVEL := 5
## Бої маршруту: кімната, бій (RoomEnemySpawner) або бос, клас (single — один звичайний, group — 3+, elite, boss).
## Сусідні бої — у різних кімнатах: Game.load_room не перевантажує кімнату, що вже стоїть.
const FIGHTS := [
	{"name": "lone bandit (Village)", "room": "Village", "fight": "EnemySpawner", "cls": "single"},
	{"name": "road's first fight: 2 bandits, 2 jackals", "room": "DesertRoad", "fight": "EnemySpawner", "cls": "group"},
	{"name": "City Gates: 2 bandits, archer", "room": "CityGates", "fight": "EnemySpawner", "cls": "group"},
	{"name": "lone bandit brute", "room": "DesertRoad", "fight": "Fight_LoneElite", "cls": "elite"},
	{"name": "Lab middle: bandit, 2 jackals, scorpion", "room": "Laboratory", "fight": "Fight_Middle", "cls": "group"},
	{"name": "Mayor Hall boss", "room": "MayorHall", "boss": "ScorpicoreWarrior", "cls": "boss"},
	{"name": "Caravan: armoured scorpion and 4", "room": "DesertRoad", "fight": "Fight_Caravan", "cls": "group"},
	{"name": "cursed jackal", "room": "Laboratory", "fight": "Fight_Cursed", "cls": "elite"},
	{"name": "Laboratory boss", "room": "LabBoss", "boss": "Mercenary", "cls": "boss"},
]
## Сюжетні прапорці перед кожним боєм: кімната одразу в стані свого бою.
const FLAGS := {"desert_road_fight_complete": false, "city_gates_intro_complete": true, "city_gates_fight_complete": false,
		"city_gates_after_fight_complete": false, "lab_boss_talk_complete": false, "lab_boss_fight_complete": false}
## Масер п'є флягу нижче цієї частки HP; GOOD — нижче своєї, коли ніхто поруч не замахується.
const MASHER_FLASK_AT := 0.35
const GOOD_FLASK_AT := 0.45
## Як часто бот тисне удар, с ігрового часу.
const PRESS_EVERY := 0.1
## GOOD: блок — за стільки с до удару (парирування — у перші PlayerCombat.PARRY_WINDOW с блоку); ривок — за стільки.
const BLOCK_LEAD := 0.18
const ROLL_LEAD := 0.12
## [4] (B159): скільки с герой стоїть і тисне біля боса; скільки с чекає за спиною боса і на якій відстані від нього
## (досяжність серії боса — 69–72 px, межа його відпочинку між ходами була 90 px).
## [5] (D770): у найкращому бою групи вороги з обох боків героя хоч таку частку часу.
const SURROUND := 0.3
const BOSS_MASH := 12.0
const BOSS_WAIT := 6.0
const BOSS_WAIT_GAP := 86
## Швидкість стріли лучника (arrow.tscn, Arrow.speed), px/с.
const ARROW_SPEED := 900.0

var fails: Array[String] = []
var game: Node
var sl: Node
var hero: Node
var Boss: Script
var Rolls: Script
var SpawnPoint: Script
var Spawner: Script
var EnemyLogicScript: Script
## Рівень героя на початку кожного бою: "<кімната>/<бій>" → рівень (XP-крива, порядок кімнат).
var levels := {}
var city_rooms := {}

## Стан одного бою (заповнює _watch).
var hits_taken := 0
## Влучання героя в ворогів і скільки з них — у другого-третього ворога тим самим ударом.
var hero_hits := 0
var cleaves := 0
## Удари ворогів, що прийшли, поки герой невразливий після попереднього удару (не перекат).
var iframed := 0
## Скільки разів HP героя виросло (фляга подіяла) і HP кадром раніше.
var heals := 0
var _hp_before := 0
var _last_hit_frame := -10
var swings := {}
var strikes := {}
var stagger_time := {}
var together := 0
var together_time := 0.0
var flasks := 0
var parries := 0
var blocks := 0
var rolls := 0
var _telegraphs: Array[Dictionary] = []
## Ігровий час до першого контакту (хтось із ворогів на своїй engage_range від героя) — як швидко вороги закривають
## відстань (D767); -1 — не було.
var contact := -1.0
## Кадри, коли поруч (FLANK_NEAR) хоч двоє наземних ворогів, і з них — коли вороги з обох боків героя (D770).
var near_frames := 0
var both_frames := 0
## Випади (D768) і хватки шакала (D769).
var lunges := 0
var latches := 0
var _was_latched := false
## Бій ще випускає хвилі (RoomEnemySpawner.all_enemies_spawned не прийшов).
var _spawning := false

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	Boss = load("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd")
	SpawnPoint = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	Spawner = load("res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd")
	Rolls = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	EnemyLogicScript = load("res://SampleProject/Scripts/Gameplay/Components/EnemyLogic.gd")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	game = await Kit.boot(self)
	sl = root.get_node("ServiceLocator")
	hero = game.player
	root.get_node("EventBus").damage_received.connect(_on_damage)
	root.get_node("EventBus").player_parried.connect(func(_s: Node) -> void: parries += 1)
	root.get_node("EventBus").player_blocked.connect(func(_s: Node) -> void: blocks += 1)
	_levels()
	Engine.physics_ticks_per_second = roundi(60 * SPEED)
	# Кадр на крок фізики, як у грі на 60 к/с: таймери замахів (create_timer) спрацьовують на кадрах — за ліміту кадрів
	# із налаштувань (fps_limit, його міняють інші тести) кілька кроків фізики йшли б за кадр, і бій щоразу був би інший
	Engine.max_fps = roundi(60 * SPEED)
	Engine.max_physics_steps_per_frame = 16
	sl.get_time_manager().set_time_scale(SPEED)

	var rows: Array[Dictionary] = []
	for bot: String in ["MASHER", "GOOD"]:
		for build: String in (["SKILLS", "STRENGTH"] if bot == "MASHER" else ["SKILLS"]):
			for fight: Dictionary in FIGHTS:
				# MASHER_ONLY=<bot>,<частина назви бою> — лише ці бої (для налагодження)
				var only := OS.get_environment("MASHER_ONLY").split(",")
				if only[0] != "" and (only[0] != bot or (only.size() > 1 and not String(fight.name).contains(only[1]))):
					continue
				var row := await _run(fight, bot, build, 0)
				_print_row(row)
				# Бій групи хаотичний: кадр раніше чи пізніше — і жива інша гілка. Не той результат — ще одна спроба
				# з іншими кидками; вимога — хоч в одній з двох (бій, що поплив у легкий, програє обидві)
				if not _as_expected(row):
					row = await _run(fight, bot, build, 1)
					_print_row(row)
				rows.append(row)

	print("[1] the masher beats a lone ordinary enemy, but it costs him HP")
	for row in rows:
		if row.bot == "MASHER" and row.cls == "single":
			ck(row.won and row.hp_left < 0.95, "%s, %s: %s with %d%% HP" % [row.name, row.build, _verdict(row), roundi(row.hp_left * 100)])
	print("[2] the masher loses to every elite, both bosses and a group of 3+ (D642)")
	for row in rows:
		if row.bot == "MASHER" and row.cls != "single":
			ck(not row.won, "%s, %s: %s (enemy HP left %d%%)" % [row.name, row.build, _verdict(row), roundi(row.enemy_left * 100)])
	print("[3] a hero who blocks, parries and rolls well still wins them")
	for row in rows:
		if row.bot == "GOOD":
			ck(row.won, "%s, %s: %s with %d%% HP" % [row.name, row.build, _verdict(row), roundi(row.hp_left * 100)])

	print("[4] each boss, met as the player meets it, swings its weapon and lands it (B159)")
	for fight: Dictionary in FIGHTS:
		if fight.cls == "boss":
			await _boss_meeting(fight)
	if not rows.is_empty():
		print("[5] enemies lunge, jackals latch on, and a group stands on both sides of the hero (D768-D770)")
		var lunged := 0
		var latched := 0
		var surround := {"MASHER": 0.0, "GOOD": 0.0}
		for row in rows:
			lunged += row.lunges
			if row.bot == "MASHER":
				latched += row.latches
			if row.cls == "group":
				surround[row.bot] = maxf(surround[row.bot], row.both)
		ck(lunged >= 5, "enemies lunge from mid range (%d lunges in all fights)" % lunged)
		ck(latched >= 1, "a jackal's pounce latches on a hero who does not block or roll (%d times)" % latched)
		for bot: String in surround:
			ck(surround[bot] >= SURROUND, "%s: in some group fight enemies stand on both sides of the hero %d%% of the time (before D770: 0-3%%)"
					% [bot, roundi(surround[bot] * 100)])

	sl.get_time_manager().set_time_scale(1.0)
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


## Бос через справжній початок бою (B159): герой заходить у кімнату з Arrival, іде праворуч до тригера, кат-сцену
## дочитано — бій. (а) Герой стоїть і тисне легкий удар BOSS_MASH с; (б) герой за спиною боса, за BOSS_WAIT_GAP px, просто
## стоїть BOSS_WAIT с. В обох бос має влучити зброєю (джерело шкоди — сам бос, не хвиля): раніше в (б) він стояв
## на 89 px, поза досяжністю серії (69 px), і лише бив об землю.
func _boss_meeting(fight: Dictionary) -> void:
	var level: int = levels["%s/%s" % [fight.room, fight.boss]]
	game.set_room_states({})
	for flag: String in FLAGS:
		game.set_quest_flag(flag, FLAGS[flag])
	if hero.is_dead:
		hero.revive()
	hero.is_dying = false
	var music := [false]
	var on_fight := func(_room: Node, on: bool) -> void: music[0] = music[0] or on
	root.get_node("EventBus").boss_fight_changed.connect(on_fight)
	await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % fight.room, ^"Arrival")
	await _settle()
	hero = game.player
	_release_all()
	await _make_hero(level, city_rooms[fight.room], "SKILLS")
	var room: Node = game.map
	var boss: Node = room.get_node(NodePath(fight.boss))
	var dm: Node = sl.get_dialogue_manager()
	_hold_move(1)
	var t := 0.0
	while room.get_current_state_name() != "FIGHT" and t < 120.0:
		if room.get_current_state_name() != "QUEUE" and room.get_current_state_name() != "WAIT":
			_hold_move(0)
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await physics_frame
		t += Engine.time_scale / Engine.physics_ticks_per_second
	_release_all()
	root.get_node("EventBus").boss_fight_changed.disconnect(on_fight)
	ck(room.get_current_state_name() == "FIGHT", "%s: the room's intro leads to the fight (%s)" % [fight.name, room.get_current_state_name()])
	ck(boss.bar.visible and music[0], "%s: the boss bar is up and the fight music started (bar %s, boss_fight_changed %s)" % [fight.name, boss.bar.visible, music[0]])
	hero.defeat_handler = func() -> void: pass
	for connection: Dictionary in boss.entity_died.get_connections():
		if connection.callable.get_object() == room:
			boss.entity_died.disconnect(connection.callable)
	# (а) стоїть і тисне: обличчям до боса (крок до нього — і стоп), далі лише удар
	_hold_move(signi(int(boss.global_position.x - hero.global_position.x)))
	await physics_frame
	_hold_move(0)
	var landed := [0, 0]
	var count := func(target: Node, source: Node, _amount: int, _critical: bool) -> void:
		if target == hero and source == boss:
			landed[0] += 1
	root.get_node("EventBus").damage_received.connect(count)
	var started := [0]
	var on_swing := func() -> void: started[0] += 1
	boss.enemy_logic.attack_started.connect(on_swing)
	t = 0.0
	var press := 0.0
	while t < BOSS_MASH and not hero.is_dead:
		await physics_frame
		var dt: float = Engine.time_scale / Engine.physics_ticks_per_second
		t += dt
		press -= dt
		if press <= 0.0:
			_tap(&"attack")
			press = PRESS_EVERY
	var mash_hits: int = landed[0]
	var mash_swings: int = started[0]
	ck(mash_hits >= 2, "%s: on a hero who stands and mashes the boss swings %d times and its weapon lands %d (in %.1f s, hero %s)"
			% [fight.name, mash_swings, mash_hits, t, "down" if hero.is_dead else "standing"])
	# (б) за спиною боса, трохи поза досяжністю його серії, і просто стоїть
	if hero.is_dead:
		hero.revive()
	hero.is_dying = false
	hero.current_health = hero.Max_Health
	var side := -signf(hero.global_position.x - boss.global_position.x)
	_place_hero(Vector2(boss.global_position.x + side * BOSS_WAIT_GAP, hero.global_position.y))
	_hold_move(int(-side))
	await physics_frame
	_hold_move(0)
	landed[0] = 0
	started[0] = 0
	t = 0.0
	while t < BOSS_WAIT and not hero.is_dead:
		await physics_frame
		t += Engine.time_scale / Engine.physics_ticks_per_second
	ck(landed[0] >= 1, "%s: on a hero who waits %d px behind it the boss swings %d times and its weapon lands %d (in %.1f s)"
			% [fight.name, BOSS_WAIT_GAP, started[0], landed[0], t])
	root.get_node("EventBus").damage_received.disconnect(count)
	boss.enemy_logic.attack_started.disconnect(on_swing)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	if hero.is_dead:
		hero.revive()
	hero.is_dying = false
	hero.defeat_handler = Callable()


## Те, чого вимагає D642: MASHER перемагає одного звичайного ворога, втративши HP, і програє решті; GOOD перемагає.
func _as_expected(row: Dictionary) -> bool:
	if row.bot == "GOOD":
		return row.won
	return row.won and row.hp_left < 0.95 if row.cls == "single" else not row.won


func _verdict(row: Dictionary) -> String:
	return "wins" if row.won else ("time cap" if row.capped else "loses")


func _print_row(row: Dictionary) -> void:
	print("    %-6s %-8s %-42s L%-2d %-8s hero HP %3d%% enemy HP %3d%% %5.1fs hits %2d flasks %d/%d parry %d block %d roll %d | together %d (%.1fs) | hero hits %d (%d cleaved) | strikes in i-frames %d | contact %.1fs | both sides %s | lunges %d latches %d"
			% [row.bot, row.build, row.name, row.level, _verdict(row), roundi(row.hp_left * 100), roundi(row.enemy_left * 100),
			row.time, row.hits, row.heals, row.flasks, row.parries, row.blocks, row.rolls, row.together, row.together_time, row.hero_hits, row.cleaves, row.iframed,
			row.contact, "%d%%" % roundi(row.both * 100) if row.both >= 0.0 else "-", row.lunges, row.latches])
	for line: String in row.enemies:
		print("        " + line)


## Рівень героя на початку кожного бою й боса — як verify_difficulty._meetings: XP точок спавну за порядком кімнат.
func _levels() -> void:
	var xp: Node = sl.get_xp_manager()
	xp.reset()
	for i in ROUTE.size():
		var room_name: String = ROUTE[i]
		city_rooms[room_name] = i >= CITY_INDEX
		var room: Node = (load("res://SampleProject/Maps/%s.tscn" % room_name) as PackedScene).instantiate()
		var room_xp := 0
		for node: Node in room.find_children("*", "", true, false):
			if node.get_script() == SpawnPoint:
				var spawner: Node = node.get_parent() if node.get_parent().get_script() == Spawner else node
				var key := "%s/%s" % [room_name, spawner.name]
				if not levels.has(key):
					levels[key] = xp.current_level
				xp.add_xp(node.enemy_stats().xp_reward)
			elif node.get_script() == Boss:
				levels["%s/%s" % [room_name, node.name]] = xp.current_level
				room_xp += node.enemy_stats.xp_reward
		xp.add_xp(room_xp)
		room.free()


## Один бій: кімната начисто, герой рівня бою зі збіркою [param build], бій кімнати, бот [param bot] до кінця.
func _run(fight: Dictionary, bot: String, build: String, attempt: int) -> Dictionary:
	var key: String = "%s/%s" % [fight.room, fight.get("boss", fight.get("fight"))]
	var level: int = levels[key]
	game.set_room_states({})
	# Кімната — одразу в стані свого бою: без вступних кат-сцен (тест міряє бій, а не сюжет)
	for flag: String in FLAGS:
		game.set_quest_flag(flag, FLAGS[flag])
	await game.load_room("res://SampleProject/Maps/%s.tscn" % fight.room)
	if fight.has("boss"):
		# Бос спить (стан до бою), а вступна кат-сцена (черга й пролам, розмова) не почнеться: бій почне _start_boss
		game.map.current_state = game.map.State.FIGHT
	await physics_frame
	_place_hero(_start_spot(fight, false))  # одразу: старі координати героя в новій кімнаті можуть бути за її межею (MetSys)
	if game.room_changing:
		await game.room_change_finished
	await _settle()
	hero = game.player
	_release_all()
	if hero.is_dead:
		hero.revive()
	hero.is_dying = false
	await _make_hero(level, city_rooms[fight.room], build)
	seed(hash("%s|%s|%s|%d" % [fight.name, bot, build, attempt]))  # кидки бою (серії ворогів) не залежать від боїв перед ним
	Rolls.calm()  # без криту й ухилення (D393), як verify_difficulty: перші CombatRolls.CALM_ROLLS кидків бою спокійні
	var enemies: Array[Node] = []
	var spawner: Node = null
	_spawning = false
	if fight.has("boss"):
		enemies.append(await _start_boss(fight))
	else:
		spawner = await _start_fight(fight)
	hero.defeat_handler = func() -> void: pass  # без Game Over і кат-сцени поразки: бій міряє тест
	hits_taken = 0
	hero_hits = 0
	cleaves = 0
	iframed = 0
	heals = 0
	_hp_before = hero.current_health
	swings = {}
	strikes = {}
	stagger_time = {}
	together = 0
	together_time = 0.0
	flasks = 0
	parries = 0
	blocks = 0
	rolls = 0
	_telegraphs = []
	contact = -1.0
	near_frames = 0
	both_frames = 0
	lunges = 0
	latches = 0
	_was_latched = false
	var tracked: Array[Node] = []
	var ids: Array[int] = []  # ідентифікатори tracked: мертвий ворог звільняється раніше за звіт
	var total_hp := 0
	var t := 0.0
	var press_left := 0.0
	var heavy_due := false
	while t < CAP:
		await physics_frame
		var dt: float = Engine.time_scale / Engine.physics_ticks_per_second
		t += dt
		if spawner:
			for enemy: Node in spawner.spawned_enemies:
				if is_instance_valid(enemy) and not enemy in enemies:
					enemies.append(enemy)
		for enemy: Node in enemies:
			if is_instance_valid(enemy) and not enemy in tracked:
				tracked.append(enemy)
				ids.append(enemy.get_instance_id())
				total_hp += enemy.Max_Health
				_track(enemy)
		_watch(tracked, dt)
		if contact < 0.0:
			for e: Node in tracked:
				if is_instance_valid(e) and e.is_alive() and absf(e.global_position.x - hero.global_position.x) <= e.enemy_logic.engage_range():
					contact = t
		if hero.current_health > _hp_before and not hero.is_dead:
			heals += 1
		_hp_before = hero.current_health
		var alive := tracked.filter(func(e: Node) -> bool: return is_instance_valid(e) and e.is_alive())
		if hero.is_dead or (alive.is_empty() and not _spawning and not tracked.is_empty()):
			break
		if tracked.is_empty() and t > 10.0:
			ck(false, "%s: the fight's enemies appear" % fight.name)
			break
		press_left -= dt
		if bot == "MASHER":
			heavy_due = _masher(alive, press_left <= 0.0, heavy_due)
		else:
			heavy_due = _good(alive, press_left <= 0.0, heavy_due, t)
		if press_left <= 0.0:
			press_left = PRESS_EVERY
	_release_all()
	var left_hp := 0
	var lines: Array[String] = []
	for i in tracked.size():
		var enemy: Node = tracked[i]
		var id: int = ids[i]
		var alive_now: bool = is_instance_valid(enemy) and enemy.is_alive()
		if alive_now:
			left_hp += enemy.current_health
		var times := ""
		for phase: String in ["chase", "ready", "cooldown", "swing", "recover", "stun", "knock", "other"]:
			times += " %s %.1f" % [phase, swings[id].get(phase, 0.0)]
		lines.append("%-22s %s: swings %2d, told %2d, struck %2d, broken before tell %2d / after %2d | time:%s" % [swings[id].name,
				"alive" if alive_now else "dead ", swings[id].n, swings[id].told, strikes.get(id, 0), swings[id].n - swings[id].told,
				swings[id].told - strikes.get(id, 0), times + " | strikes at dx " + " ".join(swings[id].get("at", []))])
	var row := {"bot": bot, "build": build, "name": fight.name + (" (2nd try)" if attempt > 0 else ""), "cls": fight.cls, "level": level,
			"won": not hero.is_dead and left_hp == 0 and t < CAP, "capped": t >= CAP and not hero.is_dead,
			"hp_left": float(maxi(hero.current_health, 0)) / hero.Max_Health, "enemy_left": float(left_hp) / maxi(total_hp, 1),
			"time": t, "hits": hits_taken, "flasks": flasks, "parries": parries, "blocks": blocks, "rolls": rolls,
			"together": together, "together_time": together_time, "contact": contact, "lunges": lunges, "latches": latches,
			"both": float(both_frames) / near_frames if near_frames > 0 else -1.0, "hero_hits": hero_hits, "cleaves": cleaves, "iframed": iframed, "heals": heals, "enemies": lines}
	# Що лишилось — геть, щоб наступна кімната почалась начисто
	for enemy: Node in tracked:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if hero.is_dead:
		hero.revive()
	hero.is_dying = false
	return row


## Репліки кімнати дочитано, кат-сцени скінчились: 30 кадрів поспіль герой вільний.
func _settle() -> void:
	var calm := 0
	for i in 3000:
		if sl.get_dialogue_manager().is_dialogue_active():
			await Kit.drain(self)
			calm = 0
		elif hero.event:
			calm = 0
		else:
			calm += 1
			if calm >= 30:
				return
		await process_frame
	ck(false, "the room settles before the fight (dialogue %s, hero in event %s)" % [sl.get_dialogue_manager().is_dialogue_active(), hero.event])


## Де герой починає бій: за 260 px від крайньої точки бою (чи від місця боса) — ліворуч, а коли там стіна чи інша
## підлога, то праворуч; ближче, якщо далі уступ, — на тій самій підлозі, з якої прийшов би герой. Одразу після
## завантаження кімнати (фізика ще не готова) — без звіту про невдачу ([param report]).
func _start_spot(fight: Dictionary, report: bool = true) -> Vector2:
	var points: Array[Node2D] = []
	if fight.has("boss"):
		var room: Node = game.map
		points.append(room.get_node(^"Marks/WarriorStand") if room.has_node(^"Marks/WarriorStand") else room.get_node(NodePath(fight.boss)))
	else:
		for point: Node2D in game.map.find_child(fight.fight, true, false).spawn_points:
			points.append(point)
	points.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	for side: int in [-1, 1]:
		var at: Node2D = points[0] if side < 0 else points[-1]
		var floor_y := _floor_at(at.global_position.x, at.global_position.y)
		for gap in range(260, 50, -10):
			var x: float = at.global_position.x + side * gap
			if absf(_floor_at(x, at.global_position.y) - floor_y) <= 2.0 and _open(at.global_position, x):
				return Vector2(x, at.global_position.y - 8.0)
	if report:
		var probe: Array[String] = []
		for gap in range(260, 50, -50):
			probe.append("%d:%.0f/%s" % [gap, _floor_at(points[0].global_position.x - gap, points[0].global_position.y), _open(points[0].global_position, points[0].global_position.x - gap)])
		ck(false, "%s: a start spot on the fight's floor (left of %s, floor %.0f: %s)" % [fight.name, points[0].global_position,
				_floor_at(points[0].global_position.x, points[0].global_position.y), probe])
	return points[0].global_position


## Між точкою [param from] і x на її висоті немає стіни (тіла героя й ворогів — не стіна).
func _open(from: Vector2, x: float) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, Vector2(x, from.y))
	ray.collision_mask = 1
	var bodies: Array[RID] = [hero.get_rid()]
	for enemy: Node in get_nodes_in_group(&"enemies"):
		bodies.append(enemy.get_rid())
	ray.exclude = bodies
	return game.map.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## Верх підлоги під точкою (x, y): промінь донизу з 16 px над нею.
func _floor_at(x: float, y: float) -> float:
	var ray := PhysicsRayQueryParameters2D.create(Vector2(x, y - 16.0), Vector2(x, y + 120.0))
	ray.collision_mask = 1
	return game.map.get_world_2d().direct_space_state.intersect_ray(ray).get("position", Vector2(x, INF)).y


## Бій кімнати [param fight]: решта боїв кімнати вимкнена, герой за 260 px ліворуч від найближчої точки (на її підлозі).
func _start_fight(fight: Dictionary) -> Node:
	var target: Node = null
	for spawner: Node in game.map.find_children("*", "", true, false):
		if spawner.get_script() != Spawner:
			continue
		if spawner.name == fight.fight:
			target = spawner
			continue
		spawner.despawn_all_enemies()
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
		if spawner.trigger_area:
			spawner.trigger_area.set_deferred(&"monitoring", false)
	for enemy: Node in get_nodes_in_group(&"enemies"):
		if not enemy in target.spawned_enemies:
			enemy.queue_free()
	if target.trigger_area:
		target.trigger_area.set_deferred(&"monitoring", false)
	target.despawn_all_enemies()
	game.set_room_state(target._room, target.state_key, null)
	_place_hero(_start_spot(fight))
	await Kit.frames(self, 20)
	_spawning = target.spawn_in_waves
	if _spawning:
		target.all_enemies_spawned.connect(func() -> void: _spawning = false, CONNECT_ONE_SHOT)
	target.spawn_all_enemies()
	await Kit.frames(self, 2)
	return target


## Бос кімнати: стоїть на своєму місці, кат-сцени пропущено, бій кімнати почато (_fight), а смерть боса не веде далі
## сюжетом (тест міряє лише бій).
func _start_boss(fight: Dictionary) -> Node:
	var room: Node = game.map
	var boss: Node = room.get_node(NodePath(fight.boss))
	for connection: Dictionary in boss.entity_died.get_connections():
		if connection.callable.get_object() == room:
			boss.entity_died.disconnect(connection.callable)
	if room.has_node(^"Marks/WarriorStand"):
		boss.global_position = (room.get_node(^"Marks/WarriorStand") as Node2D).global_position
		boss.show()
		room._set_barrier(true)
	_place_hero(_start_spot(fight))
	await Kit.frames(self, 20)
	room._fight()
	boss.enemy_logic.detection_range = maxf(boss.enemy_logic.detection_range, 900.0)
	boss.enemy_logic.on_player_detected(hero)
	return boss


func _place_hero(at: Vector2) -> void:
	game.place_player(at)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1


func _track(enemy: Node) -> void:
	var id := enemy.get_instance_id()
	swings[id] = {"n": 0, "told": 0, "name": "%s%s" % ["elite " if enemy.elite else "", enemy.enemy_type if "enemy_type" in enemy and enemy.enemy_type != "" else enemy.name]}
	strikes[id] = 0
	enemy.enemy_logic.attack_started.connect(_on_swing.bind(enemy))
	enemy.enemy_logic.attack_telegraphed.connect(_on_telegraph.bind(enemy))


## Замах ворога: інший ворог уже замахується чи б'є — «разом».
func _on_swing(enemy: Node) -> void:
	swings[enemy.get_instance_id()].n += 1
	if enemy.enemy_logic.get(&"lunging"):
		lunges += 1
	for other: Node in get_nodes_in_group(&"enemies"):
		if other != enemy and is_instance_valid(other) and other.is_alive() and other.enemy_logic.is_attacking \
				and not other.enemy_logic.recovering:
			together += 1
			return


func _on_telegraph(enemy: Node) -> void:
	swings[enemy.get_instance_id()].told += 1
	# Стріла лучника долітає за відстань / швидкість стріли після пострілу — блок має стояти тоді
	var flight: float = absf(enemy.global_position.x - hero.global_position.x) / ARROW_SPEED if enemy.enemy_logic.get_script().resource_path.ends_with("ArcherLogic.gd") else 0.0
	_telegraphs.append({"enemy": enemy, "tell": enemy.enemy_logic.tell_kind, "strike_in": enemy.enemy_logic.tell_time + flight,
			"lunge": enemy.enemy_logic.get(&"lunging") == true,
			"boss": enemy.get_script() == Boss, "kind": enemy.enemy_logic.get("last_move").get("kind", "combo") if enemy.get_script() == Boss else "swing"})


func _on_damage(target: Node, source: Node, _amount: int, _critical: bool) -> void:
	if target == hero:
		hits_taken += 1
		if is_instance_valid(source):
			source.set_meta(&"masher_landed", true)
	elif source == hero:
		hero_hits += 1
		var frame := Engine.get_physics_frames()
		if frame - _last_hit_frame <= 2:
			cleaves += 1
		_last_hit_frame = frame


## Кожен кадр: збій ворогів, удари (хітбокс увімкнувся), кілька замахів разом.
func _watch(tracked: Array[Node], dt: float) -> void:
	var attacking := 0
	for enemy: Node in tracked:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var id := enemy.get_instance_id()
		var logic: Node = enemy.enemy_logic
		if logic.stun_left > 0.0 or logic.knockback_left > 0.0 and not logic.is_attacking:
			stagger_time[id] = stagger_time.get(id, 0.0) + dt
		var phase := "stun" if logic.stun_left > 0.0 else "knock" if logic.knockback_left > 0.0 \
				else "recover" if logic.recovering else "swing" if logic.is_attacking \
				else "chase" if logic.current_state == logic.AIState.CHASE \
				else "cooldown" if logic.current_state == logic.AIState.ATTACK and logic.attack_ready_in > 0.0 \
				else "ready" if logic.current_state == logic.AIState.ATTACK else "other"
		swings[id][phase] = swings[id].get(phase, 0.0) + dt
		var on: bool = enemy.hitbox.monitoring
		if on and not enemy.get_meta(&"masher_on", false):
			strikes[id] += 1
			swings[id]["at"] = swings[id].get("at", []) + ["%d%s" % [roundi(absf(hero.global_position.x - enemy.global_position.x)), "i" if hero.is_invulnerable else ""]]
		if on and not enemy.get_meta(&"masher_on", false):
			enemy.set_meta(&"masher_landed", false)
		if on and hero.is_invulnerable and not hero.mover.is_rolling() and not enemy.get_meta(&"masher_iframed", false) \
				and not enemy.get_meta(&"masher_landed", false):
			enemy.set_meta(&"masher_iframed", true)
			iframed += 1
		if not on:
			enemy.set_meta(&"masher_iframed", false)
		enemy.set_meta(&"masher_on", on)
		if logic.is_attacking and not logic.recovering:
			attacking += 1
	if attacking >= 2:
		together_time += dt
	var sides := {}
	var near := 0
	for enemy: Node in tracked:
		if is_instance_valid(enemy) and enemy.is_alive() and not enemy.flying:
			var gap: float = enemy.global_position.x - hero.global_position.x
			if absf(gap) <= FLANK_NEAR:
				near += 1
				sides[signf(gap)] = true
	if near >= 2:
		near_frames += 1
		if sides.has(1.0) and sides.has(-1.0):
			both_frames += 1
	var holder: Node = EnemyLogicScript.latched()
	if holder != null and not _was_latched:
		latches += 1
	_was_latched = holder != null
	for tg: Dictionary in _telegraphs:
		tg.strike_in -= dt
	_telegraphs = _telegraphs.filter(func(tg: Dictionary) -> bool: return tg.strike_in > -0.4 and is_instance_valid(tg.enemy))


func _nearest(alive: Array) -> Node:
	var best: Node = null
	for enemy: Node in alive:
		if best == null or absf(enemy.global_position.x - hero.global_position.x) < absf(best.global_position.x - hero.global_position.x):
			best = enemy
	return best


## MASHER: іде на найближчого, тисне легкий удар; щойно серія скінчилась — важкий; фляга нижче MASHER_FLASK_AT.
func _masher(alive: Array, press: bool, heavy_due: bool) -> bool:
	var target := _nearest(alive)
	if target == null:
		_hold_move(0)
		return heavy_due
	var dx: float = target.global_position.x - hero.global_position.x
	_hold_move(signi(int(dx)) if absf(dx) > 24.0 else 0)
	if float(hero.current_health) / hero.Max_Health < MASHER_FLASK_AT and _flask():
		return heavy_due
	var combat: Node = hero.combat
	if combat.combo_step == combat.combo_length() - 1 and combat.attack_cooldown > 0.0 and combat.state == combat.State.READY:
		heavy_due = true
	if press:
		if heavy_due and combat.state == combat.State.READY:
			_tap(&"heavy_attack")
			return false
		_tap(&"attack")
	return heavy_due


## GOOD: не б'є, коли поруч замах; жовте й біле — блок (жовте — парирування, далі рипост), червоне — ривок геть;
## фляга, коли ніхто не замахується; навичка, коли є SP.
func _good(alive: Array, press: bool, heavy_due: bool, _t: float) -> bool:
	var target := _nearest(alive)
	if target == null:
		_hold_move(0)
		return heavy_due
	var dx: float = target.global_position.x - hero.global_position.x
	var combat: Node = hero.combat
	# Найближча загроза: показана підказка ворога, що дістає героя
	var threat: Dictionary = {}
	for tg: Dictionary in _telegraphs:
		var enemy: Node = tg.enemy
		if not enemy.is_alive() or tg.strike_in < -0.25:
			continue
		var reach: float = enemy.enemy_logic.attack_range + enemy.lunge + 70.0
		if tg.lunge:
			reach = enemy.enemy_stats.lunge_to + 70.0  # випад (D768) дістає з середньої відстані
		if tg.boss and tg.kind in ["slam", "charge"]:
			reach = 1000.0
		if absf(enemy.global_position.x - hero.global_position.x) > reach:
			continue
		if threat.is_empty() or tg.strike_in < threat.strike_in:
			threat = tg
	var winding := false
	for e: Node in alive:
		if e.enemy_logic.is_attacking and not e.enemy_logic.recovering \
				and absf(e.global_position.x - hero.global_position.x) <= e.enemy_logic.attack_range + e.lunge + 90.0:
			winding = true
	if not threat.is_empty():
		var from: float = threat.enemy.global_position.x
		if threat.tell == &"dodge":
			_set_block(false)
			if threat.strike_in <= ROLL_LEAD and threat.strike_in > -0.05 and not hero.mover.is_rolling():
				_hold_move(-signi(int(from - hero.global_position.x)) if from != hero.global_position.x else -1)
				if hero.mover.can_roll():
					_tap(&"dodge")
					rolls += 1
			return heavy_due
		_hold_move(signi(int(from - hero.global_position.x)) if absf(from - hero.global_position.x) > 1.0 else 0)  # лицем до удару
		_set_block(threat.strike_in <= BLOCK_LEAD)
		return heavy_due
	_set_block(false)
	if combat.riposte_left > 0.0:
		_hold_move(signi(int(dx)))
		if press:
			_tap(&"attack")
		return heavy_due
	# Легкий удар можна зірвати блоком чи перекатом на відновленні (D456) — його б'ють і тоді, коли хтось замахується;
	# фляга й навичка (замах не зривається) — лише коли поруч ніхто не замахується
	if not winding and float(hero.current_health) / hero.Max_Health < GOOD_FLASK_AT and _flask():
		return heavy_due
	_hold_move(signi(int(dx)) if absf(dx) > 24.0 else 0)
	if press and not winding and absf(dx) < 90.0 and _cast_best():
		return heavy_due
	if press:
		_tap(&"attack")
	return heavy_due


## Фляга (Healing Palm, D504) зі свого слота хотбара, якщо є заряд. true — натиснуто.
func _flask() -> bool:
	var sm: Node = sl.get_skill_manager()
	if not sm.is_unlocked("healing_palm") or sm.can_use_skill("healing_palm") != sm.Result.OK or hero.combat.state != hero.combat.State.READY:
		return false
	_hold_move(0)
	_tap(StringName("skill_slot_%d" % (sm.get_slot_of_skill("healing_palm") + 1)))
	flasks += 1
	return true


## Найсильніша навичка з ушкодженням, на яку вистачає SP, — зі свого слота.
func _cast_best() -> bool:
	var sm: Node = sl.get_skill_manager()
	if hero.combat.state != hero.combat.State.READY:
		return false
	var best := ""
	for id: String in sm.get_unlocked_skills():
		var definition = sm.skill_database.get_skill(id)
		if definition.is_active() and definition.damage > 0 and sm.get_slot_of_skill(id) >= 0 and sm.can_use_skill(id) == sm.Result.OK:
			if best == "" or sm.skill_damage(id) > sm.skill_damage(best):
				best = id
	if best == "":
		return false
	_tap(StringName("skill_slot_%d" % (sm.get_slot_of_skill(best) + 1)))
	return true


var _move_held := 0
var _block_held := false

func _hold_move(dir: int) -> void:
	if dir == _move_held:
		return
	if _move_held != 0:
		_action(&"move_right" if _move_held > 0 else &"move_left", false)
	if dir != 0:
		_action(&"move_right" if dir > 0 else &"move_left", true)
	_move_held = dir


func _set_block(on: bool) -> void:
	if on != _block_held:
		_action(&"block", on)
		_block_held = on


func _release_all() -> void:
	_hold_move(0)
	_set_block(false)


func _tap(action: StringName) -> void:
	_action(action, true)
	_action(action, false)


func _action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Герой рівня [param level] — як verify_difficulty._make_hero.
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
		sm.unlock_skill("healing_palm")
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
	else:
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
		for id: String in sm.get_unlocked_skills():
			var definition = sm.skill_database.get_skill(id)
			if definition.is_active() and definition.damage > 0:
				while sm.can_upgrade(id) == sm.Result.OK:
					sm.upgrade_skill(id)
	hero.refresh_max_health()
	hero.current_health = hero.Max_Health
	sm._set_current_sp(0)  # SP — лише з влучань цього бою (D504)
