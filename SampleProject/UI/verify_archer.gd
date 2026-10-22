extends SceneTree

## Пустельний лучник (BACKLOG 40, design/ranged_plan.md, D386) у справжній фізиці DesertRoad: тримає дистанцію,
## перед кожним пострілом — червоний відблиск на наконечнику (4b), стріла б'є героя; блок, парирування (стріла летить
## назад, D384), перекат і стрибок — справжніми подіями клавіатури й геймпада з InputMap.
##   godot --headless --path . --script res://SampleProject/UI/verify_archer.gd

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

## Справжня подія прив'язки дії [param action] класу [param kind] — копія з InputMap, натиснута чи відпущена.
func _event(action: StringName, kind: String, pressed: bool) -> InputEvent:
	for bound: InputEvent in InputMap.action_get_events(action):
		if bound.get_class() == kind:
			var ev: InputEvent = bound.duplicate()
			ev.device = 0
			ev.pressed = pressed
			return ev
	ck(false, "%s has a %s binding" % [action, kind])
	return null

func _press(action: StringName, kind: String, pressed: bool = true) -> void:
	Input.parse_input_event(_event(action, kind, pressed))

func _tap(action: StringName, kind: String) -> void:
	_press(action, kind)
	await physics_frame
	_press(action, kind, false)

var game: Node
var hero: Node
var sl: Node
var eb: Node
var archer: Node
## Скрипти проєкту — не за class_name: тест компілюється раніше за автозавантаження, яких вони торкаються.
var arrow_script: Script
var tell_script: Script
## Стріли лучника в порядку появи й коли кожна з'явилась (мс).
var enemy_arrows: Array = []
var arrow_times: Array[int] = []

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	arrow_script = load("res://SampleProject/Scripts/Combat/Arrow.gd")
	tell_script = load("res://SampleProject/Scripts/FX/EnemyTell.gd")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: banners, the game never pauses
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	hero.Max_Health = 9999  # міряємо шкоду від стріл, а не смерть
	hero.current_health = hero.Max_Health
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.set_physics_process(false)
			node._set_collisions_disabled(true)
			node.visible = false
	node_added.connect(func(n: Node) -> void:
		if n.get_script() == arrow_script:
			enemy_arrows.append(n)
			arrow_times.append(Time.get_ticks_msec()))

	await _spawn()
	await _keeps_distance()
	await _tell_then_shot()
	await _hit()
	await _block()
	await _parry()
	await _dodge()
	await _jump()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _spawn() -> void:
	print("[0] An archer from an EnemySpawnPoint of type 'archer': stats, bestiary (D386, D290)")
	var point: Node2D = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd").new()
	point.enemy_type = "archer"
	point.spawn_id = "verify_archer"
	game.map.add_child(point)
	point.global_position = hero.global_position + Vector2(300, 8)
	archer = point.spawn_enemy()
	await create_timer(0.5).timeout
	ck(archer != null and archer.get_script().resource_path.ends_with("ArcherEnemy.gd"), "the spawn point makes an ArcherEnemy (%s)" % archer)
	ck(archer.enemy_stats.enemy_type == "archer" and archer.Max_Health == 60 and archer.enemy_stats.xp_reward == 25,
			"archer stats: HP %d, XP %d" % [archer.Max_Health, archer.enemy_stats.xp_reward])
	ck(archer.is_on_floor(), "it stands on the road")
	var bestiary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/bestiary.json"))
	ck(bestiary.enemies.any(func(e: Dictionary) -> bool: return e.kind == "archer" and e.name == "Desert Archer"), "bestiary entry 'Desert Archer'")
	ck(sl.get_game_manager().player_state.journal.enemies.has("archer"), "seen → in the journal's bestiary")
	var pitch: Dictionary = root.get_node("AudioManager").enemy_voice_pitch
	ck(pitch.has("archer"), "a voice pitch for the archer")

## Герой стоїть на [param dx] px від лучника (обличчям до нього), на підлозі.
func _place_hero(dx: float) -> void:
	hero.global_position.x = archer.global_position.x + dx
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = -1 if dx > 0.0 else 1
	for i in 30:
		await physics_frame
		if hero.is_on_floor():
			break

func _keeps_distance() -> void:
	print("[1] It keeps its distance: backs away when the hero is close, closes in when far (D386)")
	hero.set_invulnerable(true, 4.0)  # тут міряємо рух, не стріли
	var x0: float = archer.global_position.x
	await _place_hero(-90.0)
	var backed := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await physics_frame
		if archer.enemy_logic.current_state == archer.enemy_logic.AIState.RETREAT:
			backed = true
		if absf(archer.global_position.x - hero.global_position.x) >= archer.keep_away:
			break
	var gap: float = absf(archer.global_position.x - hero.global_position.x)
	ck(backed and archer.global_position.x > x0 + 40.0, "close → it retreats away from the hero (%.0f → %.0f)" % [x0, archer.global_position.x])
	ck(gap >= archer.keep_away - 10.0, "until the gap is %.0f px (%.0f)" % [archer.keep_away, gap])
	await create_timer(1.0).timeout
	# Далі за дальність пострілу, але ближче за chase_range (далі — лучник «губить» героя й іде додому)
	await _place_hero(archer.attack_range * 1.2 + 30.0)
	hero.set_invulnerable(true, 4.0)
	var far: float = absf(archer.global_position.x - hero.global_position.x)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000 and absf(archer.global_position.x - hero.global_position.x) > archer.attack_range:
		await physics_frame
	var near: float = absf(archer.global_position.x - hero.global_position.x)
	ck(near <= archer.attack_range and near < far - 100.0, "far → it closes in to shooting range (%.0f → %.0f)" % [far, near])
	await create_timer(0.5).timeout

## Наступна стріла лучника за [param timeout_ms]: [стріла, мс появи] або [].
func _next_arrow(timeout_ms: int) -> Array:
	var seen := enemy_arrows.size()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_ms:
		await physics_frame
		for i in range(seen, enemy_arrows.size()):
			if is_instance_valid(enemy_arrows[i]) and not enemy_arrows[i].hero_side:
				return [enemy_arrows[i], arrow_times[i]]
	return []

## Чекаємо, доки стріла [param arrow] підлетить до героя ближче за [param gap] px (false — не долетіла).
func _arrow_within(arrow: Node, gap: float) -> bool:
	for i in 180:
		if not is_instance_valid(arrow):
			return false
		if absf(arrow.global_position.x - hero.global_position.x) <= gap:
			return true
		await physics_frame
	return false

## Кожна перевірка — про одну стрілу: лучник не стріляє (темп «ще не минув»), доки немає жодної стріли в польоті
## й жодного натягу; герой на 300 px — і лучник стріляє одразу.
func _ready_to_shoot() -> void:
	archer.enemy_logic.attack_ready_in = 1.0e9
	# Параметр без типу: у списку є й звільнені стріли, а типізований параметр на них обриває any()
	while archer.enemy_logic.is_attacking or enemy_arrows.any(func(a) -> bool:
			return is_instance_valid(a) and not a.hero_side and not a._stuck):
		await physics_frame
	await _place_hero(-300.0)
	while hero.combat.is_staggered() or hero.mover.is_rolling() or not hero.is_on_floor():
		await physics_frame
	hero.current_health = hero.Max_Health
	hero.is_invulnerable = false
	hero.invulnerability_timer = 0.0
	archer.enemy_logic.attack_ready_in = 0.0
	await physics_frame

func _tell_then_shot() -> void:
	print("[2] Every shot: the draw frames and a red glint on the arrowhead, then the arrow 0.25 s later (4b)")
	await _ready_to_shoot()
	var tells: Array[int] = []
	var glint_red := [false]
	var on_tell := func() -> void:
		tells.append(Time.get_ticks_msec())
		await process_frame
		for c in archer.get_children():
			if c.get_script() == tell_script:
				glint_red[0] = c.GLINT_OUTER.r > 0.9 and c.GLINT_OUTER.g < 0.3
	archer.enemy_logic.attack_telegraphed.connect(on_tell)
	var drew := false
	var shot: Array = []
	var t0 := Time.get_ticks_msec()
	var seen := enemy_arrows.size()
	while Time.get_ticks_msec() - t0 < 4000 and shot.is_empty():
		await physics_frame
		if archer.enemy_logic.is_attacking and archer.sprite.frame in [8, 9, 10]:
			drew = true
		if enemy_arrows.size() > seen:
			shot = [enemy_arrows[seen], arrow_times[seen]]
	archer.enemy_logic.attack_telegraphed.disconnect(on_tell)
	ck(drew, "the draw frames (8-10) during the wind-up")
	ck(tells.size() >= 1 and glint_red[0], "a red glint before the shot (%d tells)" % tells.size())
	ck(not shot.is_empty(), "then an arrow")
	if tells.is_empty() or shot.is_empty():
		return
	var lead: int = shot[1] - tells[0]
	ck(lead >= 180 and lead <= 360, "the arrow flies %d ms after the glint (parry window 250 ms)" % lead)
	var arrow: Node = shot[0]
	var y0: float = arrow.global_position.y
	ck(arrow.direction == -1 and absf(arrow.global_position.x - archer.global_position.x) < 50.0, "from the arrowhead, towards the hero")
	await create_timer(0.15).timeout
	if is_instance_valid(arrow):
		ck(arrow.global_position.y == y0, "straight")

func _hit() -> void:
	print("[3] Unguarded: the arrow hits, staggers the hero and breaks")
	await create_timer(1.0).timeout
	await _ready_to_shoot()
	var hp: int = hero.current_health
	var shot: Array = await _next_arrow(4000)
	ck(not shot.is_empty(), "an arrow")
	if shot.is_empty():
		return
	var staggered := false
	for i in 120:
		await physics_frame
		if hero.combat.is_staggered():
			staggered = true
		if not is_instance_valid(shot[0]):
			break
	await create_timer(0.1).timeout
	var expected: int = hero.mitigated_damage(int(archer.damage))
	ck(hp - hero.current_health == expected, "the hero lost %d HP (expected %d)" % [hp - hero.current_health, expected])
	ck(staggered, "and staggered (D264)")
	ck(not is_instance_valid(shot[0]), "the arrow is gone")

## Блок: тримати до пострілу (довше за вікно парирування) — стріла ламається об блок, шкоди немає.
func _block() -> void:
	print("[4] Block (key Ctrl, then pad LB): the arrow breaks on the guard, no damage")
	for kind in ["InputEventKey", "InputEventJoypadButton"]:
		await create_timer(1.0).timeout
		await _ready_to_shoot()
		var hp: int = hero.current_health
		var blocked := [0]
		var on_block := func(_a: Node) -> void: blocked[0] += 1
		eb.player_blocked.connect(on_block)
		_press(&"block", kind)
		var shot: Array = await _next_arrow(4000)
		if not shot.is_empty():
			for i in 120:
				await physics_frame
				if not is_instance_valid(shot[0]):
					break
		_press(&"block", kind, false)
		eb.player_blocked.disconnect(on_block)
		ck(not shot.is_empty() and blocked[0] == 1 and hero.current_health == hp,
				"%s: blocked (%d), HP %d → %d" % [kind, blocked[0], hp, hero.current_health])

## Парирування: блок за мить до влучання — стріла летить назад і б'є лучника (D384).
func _parry() -> void:
	print("[5] Parry (pad LB, then key Ctrl) right before the hit: the arrow flies back and hits the archer")
	for kind in ["InputEventJoypadButton", "InputEventKey"]:
		await create_timer(1.0).timeout
		await _ready_to_shoot()
		archer.current_health = archer.Max_Health
		var hp: int = hero.current_health
		var archer_hp: int = archer.current_health
		var parried := [0]
		var on_parry := func(_a: Node) -> void: parried[0] += 1
		eb.player_parried.connect(on_parry)
		var shot: Array = await _next_arrow(4000)
		var arrow: Node = null if shot.is_empty() else shot[0]
		if arrow and await _arrow_within(arrow, 70.0):
			_press(&"block", kind)
		var back := false
		for i in 120:
			await physics_frame
			if is_instance_valid(arrow) and arrow.hero_side:
				back = true
			if archer.current_health < archer_hp:
				break
		_press(&"block", kind, false)
		eb.player_parried.disconnect(on_parry)
		ck(parried[0] == 1 and hero.current_health == hp, "%s: parried (%d), no damage (HP %d → %d)" % [kind, parried[0], hp, hero.current_health])
		ck(back, "%s: the arrow turned back" % kind)
		ck(archer.current_health < archer_hp, "%s: and hit the archer (HP %d → %d)" % [kind, archer_hp, archer.current_health])
		await create_timer(0.6).timeout  # збій лучника від влучання минає

## Перекат крізь стрілу (невразливість) — шкоди немає, стріла летить далі.
func _dodge() -> void:
	print("[6] Roll through the arrow (key Shift, then pad RB): no damage, the arrow flies on")
	for kind in ["InputEventKey", "InputEventJoypadButton"]:
		await create_timer(1.0).timeout
		await _ready_to_shoot()
		var hp: int = hero.current_health
		var shot: Array = await _next_arrow(4000)
		var arrow: Node = null if shot.is_empty() else shot[0]
		var rolled := false
		if arrow and await _arrow_within(arrow, 90.0):
			await _tap(&"dodge", kind)
			rolled = hero.mover.is_rolling()
		var passed := false
		for i in 60:
			await physics_frame
			if is_instance_valid(arrow) and arrow.global_position.x < hero.global_position.x - 40.0:
				passed = true
				break
		ck(rolled and hero.current_health == hp, "%s: rolled, HP %d → %d" % [kind, hp, hero.current_health])
		ck(passed, "%s: the arrow flew on past the hero" % kind)
		await create_timer(0.5).timeout

## Стрибок над стрілою (вона летить на висоті грудей).
func _jump() -> void:
	print("[7] Jump over the arrow (key Space, then pad A): no damage")
	for kind in ["InputEventKey", "InputEventJoypadButton"]:
		await create_timer(1.0).timeout
		await _ready_to_shoot()
		var hp: int = hero.current_health
		var shot: Array = await _next_arrow(4000)
		var arrow: Node = null if shot.is_empty() else shot[0]
		var y0: float = hero.global_position.y
		var top: float = y0
		if arrow and await _arrow_within(arrow, 120.0):
			_press(&"jump", kind)
			for i in 20:
				await physics_frame
				top = minf(top, hero.global_position.y)
			_press(&"jump", kind, false)
		var passed := false
		for i in 60:
			await physics_frame
			top = minf(top, hero.global_position.y)
			if is_instance_valid(arrow) and arrow.global_position.x < hero.global_position.x - 40.0:
				passed = true
				break
		ck(top < y0 - 40.0, "%s: the hero jumped (%.0f px up)" % [kind, y0 - top])
		ck(passed and hero.current_health == hp, "%s: the arrow flew under him, HP %d → %d" % [kind, hp, hero.current_health])
		for i in 90:
			await physics_frame
			if hero.is_on_floor():
				break
