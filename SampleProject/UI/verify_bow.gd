extends SceneTree

## Лук героя (BACKLOG 40, design/ranged_plan.md, D380–D385) у справжній фізиці DesertRoad.
## Удар — справжні події миші й геймпада з InputMap (Input.parse_input_event → Player._unhandled_input):
## швидкий постріл на натискання, утримання — натяг і заряджений постріл, стріла летить прямо, влучає з відчуттям
## удару (розтин, завмирання, здригання) і застрягає в стіні.
##   godot --headless --path . --script res://SampleProject/UI/verify_bow.gd

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

## Справжня подія прив'язки дії [param action] класу [param kind] (InputEventMouseButton, InputEventJoypadButton,
## InputEventKey) — копія з InputMap, натиснута чи відпущена.
func _event(action: StringName, kind: String, pressed: bool) -> InputEvent:
	for bound: InputEvent in InputMap.action_get_events(action):
		if bound.get_class() == kind:
			var ev: InputEvent = bound.duplicate()
			ev.device = 0
			ev.pressed = pressed
			if ev is InputEventMouseButton:
				ev.position = Vector2(root.size) / 2.0  # посеред світу, не над HUD
				ev.global_position = ev.position
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
## Скрипти проєкту — не за class_name: тест компілюється раніше за автозавантаження, яких вони торкаються.
var arrow_script: Script
var impact_script: Script
var hero: Node
var sl: Node
var enemies: Array = []

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	arrow_script = load("res://SampleProject/Scripts/Combat/Arrow.gd")
	impact_script = load("res://SampleProject/Scripts/FX/HitImpact.gd")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: banners, the game never pauses
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
	ck(enemies.size() >= 2, "enemies on DesertRoad to shoot at (%d)" % enemies.size())
	for e in enemies:
		_park(e)

	await _item_and_grip()
	await _frames()
	await _quick_shot()
	await _arrow_hits()
	await _charged_shot()
	await _wall()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## Ворог не рухається, не б'є і не заважає стрілам, доки тест не поставить його мішенню.
func _park(e: Node) -> void:
	e.set_physics_process(false)
	e._set_collisions_disabled(true)
	e.visible = false

## Мішень: ворог на підлозі за [param dx] px перед героєм, повне HP, стійкість 3.
func _target(index: int, dx: float) -> Node:
	var e: Node = enemies[index]
	e._set_collisions_disabled(false)
	e.visible = true
	e.Max_Health = 500  # витримує і швидку, і заряджену стрілу
	e.current_health = e.Max_Health
	e.poise_max = 3
	e.poise = 3
	e.enemy_logic.stun_left = 0.0
	e.enemy_logic.knockback_left = 0.0
	e.enemy_logic.change_state(e.enemy_logic.AIState.IDLE)
	# На підлозі, де стоїть герой: низ його тіла 24 px нижче центру, у ворога — 16 px
	e.global_position = Vector2(hero.global_position.x + dx, hero.global_position.y + 24.0 - 16.0)
	return e

func _stand_hero(x: float) -> void:
	hero.global_position.x = x
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	for i in 20:
		await physics_frame
		if hero.is_on_floor():
			break
	await create_timer(0.35).timeout  # темп лука (attack_cooldown) скінчився

func _arrows(hero_side: bool) -> Array:
	return game.map.get_children().filter(func(n: Node) -> bool: return n.get_script() == arrow_script and n.hero_side == hero_side and not n.is_queued_for_deletion())

## Скільки реальних мс триває завмирання, що почнеться впродовж [param wait_ms] (0 — не почалось).
func _hitstop_ms(wait_ms: int) -> int:
	var deadline := Time.get_ticks_msec() + wait_ms
	while Engine.time_scale >= 1.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if Engine.time_scale >= 1.0:
		return 0
	var t0 := Time.get_ticks_msec()
	while Engine.time_scale < 1.0:
		await process_frame
	return Time.get_ticks_msec() - t0

func _item_and_grip() -> void:
	print("[0] The short bow: an item, its own grip, sold in the City; both hands on it (D383, D387)")
	var items: Node = sl.get_item_database()
	var em: Node = sl.get_equipment_manager()
	var gm: Node = sl.get_game_manager()
	var bow: Dictionary = items.get_item("short_bow")
	ck(bow.get("category") == "bow" and bow.get("grip") == "bow" and bow.get("type") == "weapon", "short_bow: weapon, category bow, grip bow (%s)" % bow)
	ck(load("res://SampleProject/Scripts/Systems/InventorySlotRules.gd").default_slot(bow) == "bow", "it goes into the bow slot")
	var merchants: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/merchants.json"))
	ck("short_bow" in merchants.merchants.city_merchant.items, "the caravan merchant in the City sells it")
	var who: String = gm.get_active_character().character_id
	em.equip_item(who, "shield", "iron_shield", items.get_item("iron_shield"))
	# Shield Block вивчено (без очок навичок і клятви — тест міряє хват, не дерево навичок)
	var unlocked: Array = gm.player_state.get("unlocked_skills", [])
	if "shield_block" not in unlocked:
		unlocked.append("shield_block")
	gm.player_state["unlocked_skills"] = unlocked
	em.equip_item(who, "bow", "short_bow", bow)
	await process_frame
	await process_frame  # D475 / D510: екіпірування одразу бере зброю в руку
	await process_frame
	ck(em.get_grip() == &"bow" and hero.combat.grip == &"bow", "the bow in hand → grip bow (%s)" % hero.combat.grip)
	ck(em.get_off_hand_item().is_empty(), "no off-hand weapon with a bow")
	var with_bow: int = hero.mitigated_damage(100)
	hero.combat.grip = &"one_handed"
	var with_sword_and_shield: int = hero.mitigated_damage(100)
	hero.combat.grip = &"bow"
	ck(with_bow > with_sword_and_shield, "no Shield Block with the bow (%d vs %d one-handed)" % [with_bow, with_sword_and_shield])
	ck(hero.combat.attack_cooldown_time == bow.weapon_profile.cooldown, "shot tempo from the profile (%.2f s)" % hero.combat.attack_cooldown_time)

func _frames() -> void:
	print("[1] Bow frames: library 'bow' on the hero, 96x96 cells, no overlay sprite (D385)")
	var anim: AnimationPlayer = hero.get_node("AnimationPlayer")
	ck(anim.has_animation_library(&"bow"), "Player.tscn has the bow library")
	for name in ["Idle", "Run", "Attack1", "Draw", "Charged", "Release"]:
		var a: Animation = anim.get_animation(StringName("bow/" + name)) if anim.has_animation(StringName("bow/" + name)) else null
		var ok := a != null
		if ok:
			var tex: Texture2D = a.track_get_key_value(a.find_track(^"Sprite2D:texture", Animation.TYPE_VALUE), 0)
			ok = tex.resource_path.contains("/Weapons/bow/") and tex.get_size() == Vector2(96, 96) \
					and a.track_get_key_value(a.find_track(^"Sprite2D:offset", Animation.TYPE_VALUE), 0) == Vector2(0, -16)
		ck(ok, "bow/%s: bow frames, offset (0, -16)" % name)
	await _stand_hero(hero.global_position.x)
	hero.combat._combat_left = hero.combat.COMBAT_LINGER  # бій: лук у руці
	await create_timer(0.2).timeout
	ck(String(anim.current_animation) == "bow/Idle", "in combat the hero stands with the bow lowered (%s)" % anim.current_animation)
	ck(not hero.get_node("WeaponMount/Pivot").visible, "no overlay sprite for the bow")

## [2] Швидкий постріл: на натискання, стріла по прямій, рух не стоїть (D380, D382).
func _quick_shot() -> void:
	print("[2] Quick shot on the press (mouse, then pad X): an arrow at once, flying straight; the hero keeps moving")
	var anim: AnimationPlayer = hero.get_node("AnimationPlayer")
	for kind in ["InputEventMouseButton", "InputEventJoypadButton"]:
		await _stand_hero(hero.global_position.x)
		var before: int = _arrows(true).size()
		_press(&"attack", kind)
		var t0 := Time.get_ticks_msec()
		var arrow: Node = null
		while Time.get_ticks_msec() - t0 < 300 and arrow == null:
			await physics_frame
			var fresh := _arrows(true)
			if fresh.size() > before:
				arrow = fresh.back()
		var ms := Time.get_ticks_msec() - t0
		_press(&"attack", kind, false)
		ck(arrow != null and ms <= 120, "%s: an arrow %d ms after the press" % [kind, ms])
		ck(String(anim.current_animation) == "bow/Attack1" or String(anim.assigned_animation) == "bow/Attack1", "%s: the quick-shot frames (%s)" % [kind, anim.assigned_animation])
		ck(not hero.combat.locks_movement(), "%s: a quick shot does not root the hero" % kind)
		if arrow == null:
			continue
		var start: Vector2 = arrow.global_position
		ck(absf(start.x - hero.global_position.x - hero.combat.ARROW_FROM.x) < 40.0 and absf(start.y - hero.global_position.y - hero.combat.ARROW_FROM.y) < 2.0,
				"%s: the arrow leaves from the nocked arrowhead (%s vs hero %s)" % [kind, start, hero.global_position])
		await create_timer(0.2).timeout
		if is_instance_valid(arrow):
			var moved: Vector2 = arrow.global_position - start
			ck(moved.x > 120.0 and absf(moved.y) < 0.01, "%s: straight along the facing (%s in 0.2 s)" % [kind, moved])
		await create_timer(1.0).timeout
	# Темп лука: натискання в темпі — стріла на кожне; натиснуте посеред пострілу — одне в черзі, після темпу
	await _stand_hero(hero.global_position.x)
	var seen: Array = _arrows(true)
	var already: int = seen.size()
	for i in 3:
		await _tap(&"attack", "InputEventMouseButton")
		for f in 19:
			await physics_frame
			for a in _arrows(true):
				if a not in seen:
					seen.append(a)
	ck(seen.size() - already == 3, "three taps at the bow's tempo → three arrows (%d)" % (seen.size() - already))
	await _stand_hero(hero.global_position.x)
	seen = _arrows(true)
	already = seen.size()
	await _tap(&"attack", "InputEventJoypadButton")
	await create_timer(0.1).timeout
	await _tap(&"attack", "InputEventJoypadButton")  # посеред пострілу — у черзі
	for f in 30:
		await physics_frame
		for a in _arrows(true):
			if a not in seen:
				seen.append(a)
	ck(seen.size() - already == 2, "a press during a shot is buffered and fires after the tempo (%d arrows)" % (seen.size() - already))
	# Рух під час пострілу
	await _stand_hero(hero.global_position.x)
	var x0: float = hero.global_position.x
	Input.action_press(&"move_right")
	await physics_frame
	await _tap(&"attack", "InputEventJoypadButton")
	await create_timer(0.15).timeout
	Input.action_release(&"move_right")
	ck(hero.global_position.x - x0 > 40.0, "running while shooting (%.0f px in 0.15 s)" % (hero.global_position.x - x0))
	await create_timer(1.0).timeout

## [3] Влучання (D381): шкода ×0.7, стійкість, розтин, завмирання, здригання; без прошивання стріла зникає.
func _arrow_hits() -> void:
	print("[3] A quick arrow hits: x0.7 damage, poise, cut, hitstop, flinch; it stops in the first enemy")
	await _stand_hero(hero.global_position.x)
	var near := _target(0, 220.0)
	var far := _target(1, 300.0)
	await physics_frame
	var hp_near: int = near.current_health
	var hp_far: int = far.current_health
	var expected := roundi(hero.combat.hit_damage() * hero.combat.QUICK_SHOT_DAMAGE)
	var sprite: Sprite2D = near.get_node("Sprite2D")
	var base_scale: Vector2 = sprite.scale
	var cuts: Array[int] = [0]
	var count_cut := func(n: Node) -> void:
		if n.get_script() == impact_script:
			cuts[0] += 1
	node_added.connect(count_cut)
	await _tap(&"attack", "InputEventMouseButton")
	var flinched := false
	var ms := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await process_frame
		if sprite.scale != base_scale:
			flinched = true
		if Engine.time_scale < 1.0:
			ms = await _hitstop_ms(10)
			break
	await create_timer(0.4).timeout
	ck(hp_near - near.current_health == expected, "the near enemy lost %d HP (expected %d = x0.7)" % [hp_near - near.current_health, expected])
	ck(far.current_health == hp_far, "the arrow stopped in the first enemy (far one untouched)")
	ck(near.poise == 2, "a light poise hit (poise %d of 3)" % near.poise)
	ck(ms >= 30, "hitstop on the hit (%d ms)" % ms)
	ck(flinched, "the enemy flinched")
	node_added.disconnect(count_cut)
	ck(cuts[0] == 1, "one cut streak on the enemy (%d)" % cuts[0])
	ck(near.enemy_logic.current_state != near.enemy_logic.AIState.IDLE or not near.is_physics_processing(), "a shot enemy turns on the hero (state %d)" % near.enemy_logic.current_state)
	_park(near)
	_park(far)
	await create_timer(0.5).timeout

## [4] Утримання — натяг і заряджений постріл (D380): прошиває, ×1.8, важкий хітстоп; недотягнутий — без стріли;
## важкий удар (pad B) — одразу натяг; перекат зриває натяг.
func _charged_shot() -> void:
	print("[4] Hold attack: draw, charged, release → a piercing x1.8 arrow; early release lowers the bow; heavy draws at once; dodge cancels")
	var anim: AnimationPlayer = hero.get_node("AnimationPlayer")
	await _stand_hero(hero.global_position.x)
	var a := _target(0, 200.0)
	var b := _target(1, 280.0)
	await physics_frame
	var hp_a: int = a.current_health
	var hp_b: int = b.current_health
	var expected := roundi(hero.combat.hit_damage() * hero.combat.CHARGED_SHOT_DAMAGE)
	_press(&"attack", "InputEventMouseButton")  # квик-стріла злітає одразу — її шкоду віднімаємо нижче
	await create_timer(0.5).timeout
	ck(hero.combat.state == hero.combat.State.DRAW and String(anim.current_animation) == "bow/Draw", "holding → drawing (%s)" % anim.current_animation)
	ck(hero.combat.locks_movement(), "the draw roots the hero")
	await create_timer(0.5).timeout
	ck(hero.combat.state == hero.combat.State.CHARGED and String(anim.current_animation) == "bow/Charged", "then charged, the glow frames loop (%s)" % anim.current_animation)
	var quick := roundi(hero.combat.hit_damage() * hero.combat.QUICK_SHOT_DAMAGE)
	hp_a -= quick  # швидка стріла з натискання влучила в першого
	var heavy_ms := 0
	_press(&"attack", "InputEventMouseButton", false)
	await physics_frame
	var charged: Array = _arrows(true).filter(func(x: Node) -> bool: return x.pierce)
	ck(charged.size() == 1 and String(anim.current_animation) == "bow/Release", "release → one charged arrow (%d), release frames" % charged.size())
	heavy_ms = await _hitstop_ms(500)
	await create_timer(0.5).timeout
	ck(hp_a - a.current_health == expected and hp_b - b.current_health == expected,
			"it pierces: both enemies lost %d (%d, %d)" % [expected, hp_a - a.current_health, hp_b - b.current_health])
	ck(heavy_ms >= 80, "heavy hit feel on the charged hit (%d ms hitstop)" % heavy_ms)
	ck(b.poise <= 0 or b.poise == b.poise_max or b.enemy_logic.stun_left > 0.0, "heavy poise: the far one staggered (poise %d, stun %.2f)" % [b.poise, b.enemy_logic.stun_left])
	_park(a)
	_park(b)
	await create_timer(0.8).timeout
	# Відпустили раніше — лук опускається, другої стріли немає
	await _stand_hero(hero.global_position.x)
	_press(&"attack", "InputEventJoypadButton")
	await create_timer(0.45).timeout
	var flying: int = _arrows(true).size()
	_press(&"attack", "InputEventJoypadButton", false)
	await create_timer(0.2).timeout
	ck(hero.combat.state == hero.combat.State.READY and _arrows(true).filter(func(x: Node) -> bool: return x.pierce).is_empty(),
			"pad: early release → no charged arrow, the bow lowered (state %d, %d → %d arrows)" % [hero.combat.state, flying, _arrows(true).size()])
	await create_timer(1.0).timeout
	# Важкий удар з луком — одразу натяг, без швидкої стріли
	await _stand_hero(hero.global_position.x)
	var before: int = _arrows(true).size()
	_press(&"heavy_attack", "InputEventJoypadButton")
	await create_timer(0.15).timeout
	ck(hero.combat.state == hero.combat.State.DRAW and _arrows(true).size() == before, "pad B (heavy) draws at once, no quick arrow")
	await create_timer(0.6).timeout
	_press(&"heavy_attack", "InputEventJoypadButton", false)
	await physics_frame
	ck(_arrows(true).any(func(x: Node) -> bool: return x.pierce), "releasing heavy looses the charged arrow")
	await create_timer(1.0).timeout
	# Перекат зриває натяг
	await _stand_hero(hero.global_position.x)
	_press(&"heavy_attack", "InputEventMouseButton")
	await create_timer(0.3).timeout
	await _tap(&"dodge", "InputEventKey")
	await physics_frame
	ck(hero.mover.is_rolling() and hero.combat.state == hero.combat.State.READY, "dodge (key) cancels the draw and rolls (state %d)" % hero.combat.state)
	_press(&"heavy_attack", "InputEventMouseButton", false)
	await create_timer(1.0).timeout

## [5] Стріла застрягає в стіні (D381) і за ним нікого не б'є.
func _wall() -> void:
	print("[5] An arrow stops on a wall and sticks, then fades")
	await _stand_hero(hero.global_position.x)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 200)
	wall.add_child(shape)
	game.map.add_child(wall)
	wall.global_position = Vector2(hero.global_position.x + 160.0, hero.global_position.y - 60.0)
	var behind := _target(0, 240.0)
	await physics_frame
	var hp: int = behind.current_health
	await _tap(&"attack", "InputEventJoypadButton")
	await create_timer(0.35).timeout
	var stuck: Array = _arrows(true)
	ck(stuck.size() == 1 and stuck[0]._stuck, "the arrow is stuck (%d arrows)" % stuck.size())
	if stuck.size() == 1:
		var x: float = stuck[0].global_position.x
		ck(absf(x - wall.global_position.x) < 40.0, "at the wall (arrow x %.0f, wall %.0f)" % [x, wall.global_position.x])
		await create_timer(0.2).timeout
		ck(is_instance_valid(stuck[0]) and absf(stuck[0].global_position.x - x) < 0.01, "it stays there")
	ck(behind.current_health == hp, "the enemy behind the wall is untouched")
	await create_timer(1.0).timeout
	ck(_arrows(true).is_empty(), "the stuck arrow fades away")
	wall.queue_free()
	_park(behind)
