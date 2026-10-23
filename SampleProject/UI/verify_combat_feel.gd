extends SceneTree

## Відчуття бою з плейтесту 2026-10-23 у справжній фізиці DesertRoad:
##   D443 — ворог зупиняє героя, крізь нього проходить лише перекат; хто впав на іншого — зісковзує (і бос, B125);
##   D456 — удар зривається перекатом чи блоком, перекат починається за 2 кадри фізики, ранній — у буфері;
##   D444 — у шакала перед ривком лише відблиск, без червоної лінії.
## Дії героя — через Input.parse_input_event (той самий шлях, що клавіша / кнопка геймпада).
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_feel.gd

const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const JACKAL := "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn"
const BRASS := "res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn"

var fails: Array[String] = []
var game: Node
var hero: Node
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

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _initialize() -> void:
	var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	rolls.calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(1.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	await _bodies_block()
	await _slide_off()
	await _boss()
	await _cancel()
	await _jackal_tell()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


## Ворог [param path] стоїть на підлозі на [param dx] px від арени; AI вимкнено ([param frozen]).
func _spawn(path: String, dx: float, frozen: bool = true) -> Node:
	var enemy: Node = load(path).instantiate()
	if enemy.enemy_stats == null:
		enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % ("fast" if path == JACKAL else "melee"))
	enemy.position = game.map.to_local(Vector2(arena_x + dx, floor_y - 40.0))
	game.map.add_child(enemy)
	for i in 40: await physics_frame
	enemy.set_physics_process(not frozen)
	return enemy


func _hero_at(x: float) -> void:
	hero.global_position = Vector2(x, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	await physics_frame


## [1] D443: хід у ворога зупиняється на його тілі; перекат проходить крізь нього, і після нього тіла знову тверді.
func _bodies_block() -> void:
	print("[1] Enemies block the hero; only the roll goes through (D443)")
	var bandit: Node = await _spawn(BANDIT, 120.0)
	await _hero_at(arena_x)
	_press(&"move_right")
	await create_timer(1.2).timeout
	_press(&"move_right", false)
	await physics_frame
	var gap: float = bandit.body_rect().position.x - hero.body_rect().end.x
	ck(gap >= -1.0 and gap <= 3.0, "walking into the bandit stops at its body (gap %.1f px)" % gap)
	ck(hero.is_on_floor() and absf(hero.global_position.y - floor_y) < 2.0, "the hero stays on the floor, not on top (y %.1f vs %.1f)" % [hero.global_position.y, floor_y])
	_press(&"dodge")
	await physics_frame
	_press(&"dodge", false)
	while hero.mover.is_rolling():
		await physics_frame
	for i in 10: await physics_frame
	ck(hero.global_position.x > bandit.global_position.x + 30.0, "the roll goes through the bandit (hero x %.0f, bandit x %.0f)" % [hero.global_position.x, bandit.global_position.x])
	ck(not hero.get_collision_exceptions().has(bandit), "after the roll the bandit blocks again")
	hero.mover.last_direction = -1
	_press(&"move_left")
	await create_timer(1.0).timeout
	_press(&"move_left", false)
	await physics_frame
	gap = hero.body_rect().position.x - bandit.body_rect().end.x
	ck(gap >= -1.0 and gap <= 3.0, "walking back into it stops again (gap %.1f px)" % gap)
	bandit.queue_free()
	await create_timer(0.3).timeout


## [2] D443: ворог, що впав на героя, і герой, що впав на ворога, зісковзують на підлогу.
func _slide_off() -> void:
	print("[2] Nobody stands on anyone's head (D443)")
	var bandit: Node = await _spawn(BANDIT, 300.0)
	var bandit_floor: float = bandit.global_position.y
	await _hero_at(arena_x)
	bandit.global_position = hero.global_position + Vector2(4, -70)
	bandit.velocity = Vector2.ZERO
	bandit.set_physics_process(true)
	bandit.enemy_logic.set_physics_process(false)
	await create_timer(1.2).timeout
	ck(bandit.is_on_floor() and absf(bandit.global_position.y - bandit_floor) < 2.0,
			"a bandit dropped on the hero slides off to the floor (y %.1f vs %.1f)" % [bandit.global_position.y, bandit_floor])
	bandit.set_physics_process(false)
	await _hero_at(bandit.global_position.x - 80.0)
	hero.global_position = bandit.global_position + Vector2(-3, -80)
	await create_timer(1.2).timeout
	ck(hero.is_on_floor() and absf(hero.global_position.y - floor_y) < 2.0,
			"the hero dropped on a bandit slides off to the floor (y %.1f vs %.1f)" % [hero.global_position.y, floor_y])
	bandit.queue_free()
	await create_timer(0.3).timeout


## [3] B125: бос на героєві не висить — зісковзує; його ривок (charge) зупиняється на тілі героя, бос — на підлозі.
func _boss() -> void:
	print("[3] The Mayor Hall boss never hangs above Kusakam (B125, D443)")
	var boss: Node = await _spawn(BRASS, 300.0)
	var boss_floor: float = boss.global_position.y
	await _hero_at(arena_x)
	boss.global_position = hero.global_position + Vector2(10, -150)
	boss.velocity = Vector2.ZERO
	boss.set_physics_process(true)
	boss.enemy_logic.set_physics_process(false)
	await create_timer(1.5).timeout
	ck(boss.is_on_floor() and absf(boss.global_position.y - boss_floor) < 2.0,
			"the boss dropped on the hero slides off to the floor (y %.1f vs %.1f)" % [boss.global_position.y, boss_floor])
	ck(not boss.body_rect().intersects(hero.body_rect()) and boss.body_rect().end.y > hero.body_rect().position.y,
			"the boss is beside the hero, not above him")
	# Ривок: бос за 250 px праворуч, лише charge; герой стоїть на шляху
	var all: Array[Dictionary] = boss.moves
	boss.moves = all.filter(func(m: Dictionary) -> bool: return m.kind == "charge")
	boss.set_physics_process(false)
	boss.global_position.x = hero.global_position.x + 250.0
	boss.enemy_logic.set_physics_process(true)
	hero.set_invulnerable(true, 5.0)
	boss.enemy_logic.last_direction = -1
	boss.set_physics_process(true)
	boss.enemy_logic.attack_ready_in = 0.0
	boss.enemy_logic.last_move = {}
	var x0: float = boss.global_position.x
	var highest: float = boss.global_position.y
	var started := false
	for i in 300:
		await physics_frame
		highest = minf(highest, boss.global_position.y)
		if boss.enemy_logic.last_move.get("kind", "") == "charge":
			started = true
		if started and not boss.enemy_logic.is_attacking:
			break
	boss.set_physics_process(false)
	boss.moves = all
	ck(started, "the boss charged")
	ck(x0 - boss.global_position.x > 100.0 and boss.global_position.x > hero.global_position.x and boss.body_rect().position.x >= hero.body_rect().end.x - 1.0,
			"the charge runs %.0f px and stops at the hero's body, not through it (boss x %.0f, hero x %.0f)" % [x0 - boss.global_position.x, boss.global_position.x, hero.global_position.x])
	ck(boss_floor - highest < 2.0, "the boss stays on the floor through the charge (rose %.1f px)" % (boss_floor - highest))
	ck(_boss_logic_has_no_jump(), "the boss has no jump move to check (BossLogic: charge, slam, fireball, pillar, combo)")
	boss.queue_free()
	await create_timer(0.3).timeout


func _boss_logic_has_no_jump() -> bool:
	var source: String = load("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossLogic.gd").source_code
	return not source.contains("jump")


## [4] D456: удар зриває перекат (за 2 кадри фізики) і блок; зірваний удар не б'є; ранній перекат — у буфері.
func _cancel() -> void:
	print("[4] An attack is cut short by a roll or a block (D456)")
	var bandit: Node = await _spawn(BANDIT, 300.0)
	bandit.Max_Health = 99999
	bandit.current_health = bandit.Max_Health
	var hits: Array = []
	bandit.damage_token.connect(func(d: int) -> void: hits.append(d))
	await _hero_at(arena_x)
	var combat: Node = hero.combat
	# Перекат посеред удару
	combat.perform_attack(1)
	await physics_frame
	ck(combat.state == combat.State.SWING, "the swing is on")
	_press(&"dodge")
	var frames := 0
	while not hero.mover.is_rolling() and frames < 10:
		await physics_frame
		frames += 1
	_press(&"dodge", false)
	ck(frames <= 2 and combat.state == combat.State.READY, "a roll during a swing starts within 2 physics frames (%d) and ends the swing" % frames)
	while hero.mover.is_rolling():
		await physics_frame
	await create_timer(0.9).timeout
	# Зірваний удар не б'є: ворог у зоні, перекат того ж кадру, що й удар
	await _hero_at(bandit.hurt_rect().position.x - 30.0)
	hero.mover.last_direction = 1
	bandit.enemy_view.update_direction(-1)
	bandit._face_shapes(-1)
	hits.clear()
	combat.perform_attack(1)
	_press(&"dodge")
	await physics_frame
	_press(&"dodge", false)
	await create_timer(0.4).timeout
	ck(hits.is_empty(), "a swing cancelled before its hit lands deals no damage (%s)" % [hits])
	while hero.mover.is_rolling():
		await physics_frame
	await create_timer(0.9).timeout
	await _hero_at(arena_x)
	# Важкий: замах зриває блок
	combat.heavy_attack(1)
	await physics_frame
	ck(combat.state == combat.State.HEAVY_WINDUP, "the heavy wind-up is on")
	_press(&"block")
	frames = 0
	while not combat.is_blocking() and frames < 10:
		await physics_frame
		frames += 1
	ck(frames <= 2, "block during a heavy wind-up guards within 2 physics frames (%d)" % frames)
	_press(&"block", false)
	await create_timer(0.3).timeout
	# Легкий удар зриває блок
	combat.perform_attack(1)
	await physics_frame
	_press(&"block")
	frames = 0
	while not combat.is_blocking() and frames < 10:
		await physics_frame
		frames += 1
	ck(frames <= 2, "block during a swing guards within 2 physics frames (%d)" % frames)
	_press(&"block", false)
	await create_timer(0.9).timeout
	# Буфер: перекат натиснуто в збої — починається, щойно збій минає
	combat.stagger(0.05, hero.global_position.x - 10.0)
	_press(&"dodge")
	await physics_frame
	_press(&"dodge", false)
	ck(not hero.mover.is_rolling(), "no roll while staggered")
	frames = 0
	while not hero.mover.is_rolling() and frames < 12:
		await physics_frame
		frames += 1
	ck(hero.mover.is_rolling(), "a roll pressed a few frames early is buffered and starts after the stagger (%d frames)" % frames)
	while hero.mover.is_rolling():
		await physics_frame
	await create_timer(0.9).timeout
	# Замах навички не зривається
	combat.state = combat.State.CAST_WINDUP
	combat._state_left = 0.5
	_press(&"dodge")
	await physics_frame
	_press(&"dodge", false)
	ck(not hero.mover.is_rolling() and combat.state == combat.State.CAST_WINDUP, "a skill's wind-up is not cancelled by a roll")
	combat.state = combat.State.READY
	await create_timer(0.3).timeout
	bandit.queue_free()


## [5] D444: шакал перед ривком — лише відблиск, червоної лінії немає.
func _jackal_tell() -> void:
	print("[5] No red line before the jackal's lunge (D444)")
	var jackal: Node = await _spawn(JACKAL, 200.0)
	await _hero_at(arena_x)
	jackal.enemy_logic.last_direction = -1
	jackal.enemy_logic.perform_attack()
	var tell: Node = null
	for i in 60:
		await physics_frame
		for child in jackal.get_children():
			if "line_length" in child:
				tell = child
		if tell != null:
			break
	ck(tell != null and tell.line_length == 0.0, "the jackal's tell is the glint alone (line %s)" % (tell.line_length if tell != null else "no tell"))
	await create_timer(1.0).timeout
	jackal.queue_free()
