extends SceneTree

## Ефекти ударів ворогів (A17) у справжній сцені DesertRoad: кожен вид ворога й обидва боси.
##   [1] кадр удару (start_attack / strike) — EventBus.enemy_struck і шлейф своєї зброї (EnemyStrikeFX.WEAPONS):
##       дуга, кийок і пил, укол жала, щелепи, піке, ривок — лінії швидкості й пил; лучник — смуга на стрілі;
##   [2] удар, що влучив у героя: розтин у точці контакту, завмирання, тряска; еліта й бос — сильніше, велика шкода — теж;
##   [3] блок — іскри блоку, парирування — іскри парирування;
##   [4] стріла лучника, що застрягла, — дрібні іскри; якість Low — без пилу.
##   godot --headless --path . --script res://SampleProject/UI/verify_enemy_fx.gd

const ENEMIES := "res://SampleProject/Scenes/Characters/Enemies/"
const STATS := "res://SampleProject/Resources/Enemies/enemy_stats_%s.tres"
## Сцени, чия назва не enemy_<kind>.tscn (RoomEnemySpawner.SCENES).
const SCENE_OF := {"melee": "default_enemy.tscn"}
## Що показує звичайний удар виду (EnemyStrikeFX.smear_shown).
const SWING_PARTS := {
	"melee": [&"arc"], "shield": [&"arc"], "tower_shield_guard": [&"arc"],
	"bandit_brute": [&"club", &"dust"],
	"tank": [&"sting"], "armoured_scorpion": [&"sting"],
	"fast": [&"bite", &"speed_lines", &"dust"], "jackal_cursed": [&"bite", &"speed_lines", &"dust"],
	"jackal_pack_leader": [&"bite", &"speed_lines", &"dust"],
	"bat": [&"bite", &"speed_lines", &"dust"], "fly": [&"bite", &"speed_lines", &"dust"],
	"vulture": [&"dive"], "old_vulture": [&"dive"],
	"archer": [&"shot"], "heavy_archer": [&"shot"],
}
const BOSSES := {
	"lab_boss": "res://SampleProject/Scenes/Characters/Bosses/lab_boss.tscn",
	"scorpicore_warrior": "res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn",
}
## Скрипти з автозавантаженнями всередині — load після старту, не preload (SceneTree-скрипт компілюється раніше).
var VFX: GDScript

var fails: Array[String] = []
var game: Node
var hero: Node
var vfx: Node
var fx: Node
var parts: Array[StringName] = []
var struck: Array[StringName] = []
var tiers: Array[int] = []
var guards: Array[bool] = []
var sparks := 0
var floor_y: float
var arena_x: float

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _initialize() -> void:
	var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	VFX = load("res://SampleProject/Scripts/Systems/VFXHooks.gd")
	rolls.calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	root.get_node("DisplayManager").graphics_quality.apply("high")
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
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
	vfx = root.get_node("GameManager/VFXHooks")
	fx = vfx.get_node(^"EnemyStrikeFX")
	fx.smear_shown.connect(func(_enemy: Node2D, part: StringName) -> void: parts.append(part))
	fx.arrow_spark_shown.connect(func(_at: Vector2) -> void: sparks += 1)
	vfx.hurt_shown.connect(func(tier: int) -> void: tiers.append(tier))
	vfx.guard_shown.connect(func(parry: bool) -> void: guards.append(parry))
	root.get_node("EventBus").enemy_struck.connect(func(_enemy: Node2D, move: StringName, _dir: Vector2) -> void: struck.append(move))
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	await _swings()
	await _bosses()
	await _guard()
	await _low_quality()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


## Ворог виду [param kind] за 160 px праворуч від героя, ШІ стоїть (ефекти перевіряємо прямими викликами).
func _spawn(kind: String) -> Node:
	var enemy: Node = load(ENEMIES + SCENE_OF.get(kind, "enemy_%s.tscn" % kind)).instantiate()
	enemy.enemy_stats = load(STATS % kind)
	return await _place(enemy)


func _place(enemy: Node) -> Node:
	enemy.position = game.map.to_local(Vector2(arena_x + 160.0, floor_y - 40.0))
	game.map.add_child(enemy)
	for i in 30: await physics_frame
	enemy.set_physics_process(false)
	enemy.enemy_logic.set_physics_process(false)
	enemy.enemy_logic.set_process(false)
	enemy.player = hero  # лучник цілить у героя (ArcherEnemy._tilt_to), ШІ стоїть і сам не побачить
	enemy.Max_Health = 99999
	enemy.current_health = enemy.Max_Health
	return enemy


## Удар [param enemy] влучив у героя на [param amount]: розтин, завмирання, рівень сили. Повертає рівень.
func _landed(enemy: Node, amount: int) -> int:
	while hero.is_invulnerable or Engine.time_scale < 1.0:
		await physics_frame
	hero.current_health = hero.Max_Health
	tiers.clear()
	var impacts := _impacts()
	hero.take_damage(amount, enemy)
	var stopped := Engine.time_scale < 1.0
	var tier: int = tiers[0] if tiers.size() == 1 else -1
	ck(tiers.size() == 1 and _impacts() > impacts and stopped,
			"%s hit lands: impact at the contact point, hitstop (%s), tier %d" % [enemy.enemy_stats.enemy_type, stopped, tier])
	return tier


func _impacts() -> int:
	return hero.get_parent().get_children().filter(func(n: Node) -> bool: return n is HitImpact).size()


## Кадр удару [param enemy] у бік героя: start_attack (наземний, летючий, лучник) — чекаємо [param expect].
func _strike(enemy: Node, expect: Array, label: String) -> void:
	parts.clear()
	struck.clear()
	enemy.start_attack(-1)
	ck(struck.size() == 1, "%s: one enemy_struck on the strike frame (%s)" % [label, struck])
	ck(parts == expect, "%s: smear %s (expected %s)" % [label, parts, expect])
	enemy.end_attack()


## [1] + [2] Кожен вид: шлейф на кадрі удару, влучання — розтин і завмирання; еліта — важче.
func _swings() -> void:
	print("[1] Every enemy kind: the strike frame shows its own smear; [2] a landed hit shows the impact and hitstop")
	for kind: String in SWING_PARTS:
		var enemy := await _spawn(kind)
		await _strike(enemy, SWING_PARTS[kind], kind)
		if kind.ends_with("archer"):
			var arrow: Node = enemy.get_parent().get_children().filter(func(n: Node) -> bool: return n is Arrow).back()
			var streak: Sprite2D = arrow.get_node(^"Streak")
			ck(streak.visible and streak.modulate == load("res://SampleProject/Scripts/FX/EnemyTell.gd").GLINT_OUTER[arrow.tell],
					"%s: the arrow trails a streak in its tell colour" % kind)
			sparks = 0
			arrow._stick()
			ck(sparks == 1, "%s: a stuck arrow bursts small sparks" % kind)
			arrow.queue_free()
		var tier := await _landed(enemy, 5)
		ck(tier == (1 if enemy.elite or VFX.is_big_hurt(enemy) else 0),
				"%s: hurt tier %d (elite %s)" % [kind, tier, enemy.elite])
		enemy.queue_free()
		await physics_frame
	var bandit := await _spawn("melee")
	var tier := await _landed(bandit, roundi(hero.Max_Health * VFX.HEAVY_HURT_SHARE))
	ck(tier == 1, "a hit for a fifth of the hero's HP hits as heavy (tier %d)" % tier)
	bandit.queue_free()
	await physics_frame


## [1] + [2] Боси: серія — дуга зброї, slam — важка дуга й пил, ривок — ще й лінії; влучання — рівень боса.
func _bosses() -> void:
	print("[1b] Both bosses: the combo swing, the slam and the charge show their smears; [2b] a boss hit is the top tier")
	for id: String in BOSSES:
		var boss := await _place(load(BOSSES[id]).instantiate())
		boss.enemy_logic.last_move = boss.moves.filter(func(m: Dictionary) -> bool: return m.kind == "combo")[0]
		await _strike(boss, [&"arc"], id + " combo")
		var slam: Dictionary = boss.moves.filter(func(m: Dictionary) -> bool: return m.kind == "slam")[0]
		boss.enemy_logic.last_move = slam
		parts.clear()
		struck.clear()
		boss.strike(slam)
		ck(struck == [&"slam"] and parts == [&"slam", &"dust"], "%s slam: %s / %s" % [id, struck, parts])
		var charges: Array = boss.moves.filter(func(m: Dictionary) -> bool: return m.kind == "charge")
		if not charges.is_empty():
			boss.enemy_logic.last_move = charges[0]
			await _strike(boss, [&"arc", &"speed_lines", &"dust"], id + " charge")
		ck(await _landed(boss, 5) == 2, "%s: a landed hit is the boss tier" % id)
		boss.queue_free()
		await physics_frame


## [3] Блок і парирування героя — іскри блоку й парирування.
func _guard() -> void:
	print("[3] The hero blocks: block sparks; parries: parry sparks")
	var bandit := await _spawn("melee")
	hero.global_position = Vector2(bandit.global_position.x - 40.0, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	while hero.is_invulnerable or Engine.time_scale < 1.0:
		await physics_frame
	guards.clear()
	_press(&"block")
	await create_timer(hero.combat.PARRY_WINDOW - 0.1).timeout
	hero.take_damage(5, bandit)
	await create_timer(hero.combat.PARRY_WINDOW + 0.2).timeout
	hero.take_damage(5, bandit)
	_press(&"block", false)
	ck(guards == [true, false], "parry, then block: sparks %s (true = parry)" % [guards])
	bandit.queue_free()
	await create_timer(0.5).timeout


## [4] Low (D554): шлейфи лишаються, пилу немає.
func _low_quality() -> void:
	print("[4] Graphics quality Low: the smear stays, the dust goes")
	root.get_node("DisplayManager").graphics_quality.apply("low")
	var jackal := await _spawn("fast")
	await _strike(jackal, [&"bite", &"speed_lines"], "fast on Low")
	root.get_node("DisplayManager").graphics_quality.apply("high")
	jackal.queue_free()
	await physics_frame


func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
