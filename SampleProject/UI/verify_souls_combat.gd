extends SceneTree

## Souls-lite бій (BACKLOG 4 + 15, design/souls_combat_plan.md, D264–D270) у справжній фізиці DesertRoad.
## Дії героя — через Input.parse_input_event (той самий шлях, що клавіша / кнопка геймпада → _unhandled_input).
##   godot --headless --path . --script res://SampleProject/UI/verify_souls_combat.gd

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

## Натиснути / відпустити дію так, як це робить клавіатура чи геймпад.
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
var enemies: Array = []

## Ворог стоїть на місці й не б'є, доки тест не відпустить.
func _freeze_all() -> void:
	for e in enemies:
		e.set_physics_process(false)

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")  # не ідентифікатор: скрипт тесту компілюється до autoload
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
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
	ck(enemies.size() >= 2, "enemies on DesertRoad (%d)" % enemies.size())
	ck(InputMap.has_action(&"heavy_attack") and InputMap.has_action(&"block"), "heavy_attack and block are registered (D270)")
	for action in [&"heavy_attack", &"block"]:
		var kinds: Array = InputMap.action_get_events(action).map(func(e: InputEvent) -> String: return e.get_class())
		ck("InputEventJoypadButton" in kinds and ("InputEventKey" in kinds or "InputEventMouseButton" in kinds),
				"%s has a keyboard/mouse and a pad binding (%s)" % [action, kinds])

	await _staggers()
	await _freeze_check()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## [0] «Вороги інколи заморожують героя» (D264): довгий бій ніколи не лишає героя без керування.
func _freeze_check() -> void:
	print("[0] A long melee never leaves the hero stuck (D264)")
	for e in enemies:
		e.set_physics_process(true)
	hero.global_position = enemies[0].global_position + Vector2(-80, 0)
	var stuck_seconds := 0
	var dir := 1
	for sec in 12:
		var x0: float = hero.global_position.x
		var act: StringName = &"move_right" if dir > 0 else &"move_left"
		Input.action_press(act)
		for f in 5:
			await _tap(&"attack")
			await create_timer(0.18).timeout
		Input.action_release(act)
		if absf(hero.global_position.x - x0) < 100.0:
			stuck_seconds += 1
		if sec % 3 == 2:
			dir = -dir
	ck(stuck_seconds <= 2, "the hero moved in at least 10 of 12 seconds of fighting (%d stuck)" % stuck_seconds)
	await create_timer(1.0).timeout
	ck(not hero.event and Engine.time_scale == 1.0 and not paused and not hero.combat.owns_animation() and not hero.mover.locked,
			"after the fight: no event lock, time scale 1, not paused, combat idle (event %s, ts %.2f, state %d)"
			% [hero.event, Engine.time_scale, hero.combat.state])
	hero.current_health = hero.Max_Health

## [1] Стійкість ворога і збій героя (D264, D265).
func _staggers() -> void:
	_freeze_all()
	await create_timer(0.8).timeout
	var target: Node = enemies[0]
	target.set_physics_process(true)
	target.poise_max = 3
	target.poise = 3
	target.current_health = target.Max_Health
	target.set_physics_process(false)
	var staggered: Array = []
	eb.enemy_staggered.connect(func(e: Node, d: float) -> void: staggered.append([e, d]))
	print("[1] Three light hits break a melee enemy's poise")
	hero.combat.attack_cooldown_time = 0.0  # тут міряємо стійкість, а не ритм серії
	for i in 3:
		hero.global_position = target.global_position + Vector2(-26, 0)
		hero.velocity = Vector2.ZERO
		await physics_frame
		hero.combat.perform_attack(1)
		await create_timer(0.4).timeout
	ck(staggered.size() == 1 and staggered[0][0] == target, "the third hit staggers it (%s)" % [staggered])
	ck(target.enemy_logic.stun_left > 0.0, "a staggered enemy stands (stun %.2f)" % target.enemy_logic.stun_left)
	hero.combat.apply_weapon_profile()

	print("[1b] A stagger breaks the enemy's wind-up")
	target.set_physics_process(true)
	await create_timer(1.0).timeout
	target.enemy_logic.stun_left = 0.0
	var swings: Array = []
	var on_swing := func(attacker: Node, _t: Node) -> void:
		if attacker == target: swings.append(Time.get_ticks_msec())
	eb.attack_started.connect(on_swing)
	target.combo_hits = 1
	hero.global_position = target.global_position + Vector2(-300, 0)
	target.enemy_logic.perform_attack()
	await create_timer(0.1).timeout
	target.stagger(0.6, hero.global_position.x)
	var hit_landed := false
	target.hitbox_damage.damage_applied.connect(func(_t: Node, _d: int) -> void: hit_landed = true)
	await create_timer(0.8).timeout
	ck(target.enemy_logic.attack_broken and not target.hitbox.monitoring, "the swing never came (broken %s, hitbox %s)" % [target.enemy_logic.attack_broken, target.hitbox.monitoring])

	print("[2] An enemy combo: three swings, the last a finisher (D265)")
	await create_timer(1.0).timeout
	swings.clear()
	target.combo_hits = 3
	target.combo_chance = 1.0
	var stagger_times: Array = []
	target.enemy_logic.attack_started.connect(func() -> void: stagger_times.append(target.hit_stagger_time()))
	target.enemy_logic.perform_attack()
	await create_timer(target.attack_windup + 2 * 0.25 + 3 * target.attack_active_time + 0.3).timeout
	ck(swings.size() == 3, "three swings in one attack (%d)" % swings.size())
	ck(stagger_times.size() == 3 and stagger_times[2] >= 0.6 and stagger_times[0] == target.stagger_time,
			"only the finisher staggers long (%s)" % [stagger_times])
	eb.attack_started.disconnect(on_swing)
	target.combo_hits = 2
	target.combo_chance = 0.5

	print("[3] An enemy hit staggers the hero: pushed away, no control, then free again (D264)")
	await create_timer(1.0).timeout
	target.set_physics_process(false)
	var got: Array = []
	eb.player_staggered.connect(func(d: float) -> void: got.append(d))
	hero.current_health = hero.Max_Health
	hero.global_position = target.global_position + Vector2(-40, 0)
	hero.velocity = Vector2.ZERO
	await physics_frame
	var x_before: float = hero.global_position.x
	hero.take_damage(5, target)
	ck(got.size() == 1 and hero.combat.is_staggered(), "the hit staggers the hero (%s)" % [got])
	ck(hero.get_node("AnimationPlayer").current_animation == &"Hurt", "the hurt animation plays (%s)" % hero.get_node("AnimationPlayer").current_animation)
	Input.action_press(&"move_right")
	await create_timer(0.15).timeout
	ck(hero.global_position.x < x_before - 20.0, "pushed away from the enemy, not walking into it (%.0f px)" % (hero.global_position.x - x_before))
	await _tap(&"attack")
	ck(not hero.combat.is_attacking, "no attack while staggered")
	await create_timer(0.3).timeout
	var x_free: float = hero.global_position.x
	await create_timer(0.2).timeout
	Input.action_release(&"move_right")
	ck(not hero.combat.is_staggered() and hero.global_position.x > x_free + 30.0, "control comes back (moved %.0f px)" % (hero.global_position.x - x_free))

	print("[3b] A tank hit freezes the hero longer (D253 'freeze')")
	await create_timer(0.6).timeout
	got.clear()
	var tank_time: float = load("res://SampleProject/Resources/Enemies/enemy_stats_tank.tres").stagger_time
	target.stagger_time = tank_time
	hero.take_damage(5, target)
	ck(got.size() == 1 and is_equal_approx(got[0], tank_time) and tank_time >= 0.6, "tank stagger %.2f s (%s)" % [tank_time, got])
	target.stagger_time = 0.25
	await create_timer(1.0).timeout
	print("[3c] A hit without an enemy source (burn, hazard) does not stagger")
	got.clear()
	hero.take_damage(5)
	ck(got.is_empty(), "no stagger without an enemy source")
