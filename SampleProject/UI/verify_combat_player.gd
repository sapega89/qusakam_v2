extends SceneTree

## Бій з боку героя (D504: Tails of Iron + Salt and Sanctuary, D502) у справжній фізиці DesertRoad:
##   [1] удар саджає героя з кроком уперед; погляд не змінюється, доки удар не вийшов (B136);
##   [2] перекат і блок зривають удар лише на відновленні, замах важкого — ніколи; недобуте відновлення важкого
##       лишається кулдауном (B-9); буфер натискань 0.2 с крізь збій, буфер стрибка, стрибок зриває відновлення;
##   [3] витривалість (D775): ціни ударів і перекату, порожня шкала — ні удару, ні перекату, спалах; відновлення; блок;
##   [4] зілля зі швидкого слота: одна кнопка, у реальному часі, герой стоїть; удар до ковтка — зілля пропало;
##   [5] над звичайним ворогом смужки HP немає (D502);
##   [6] шкала стійкості над ворогом (D776): набирається, спадає, повна — збій; три удари серії не збивають.
## Дії героя — через Input.parse_input_event (той самий шлях, що клавіша / кнопка геймпада).
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_player.gd

const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const BANDIT_STATS := "res://SampleProject/Resources/Enemies/enemy_stats_melee.tres"

var fails: Array[String] = []
var game: Node
var hero: Node
var combat: Node
var bandit: Node
var hits: Array = []
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

func _tap(action: StringName) -> void:
	_press(action)
	await physics_frame
	_press(action, false)

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
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(1.5).timeout
	hero = game.player
	combat = hero.combat
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x
	bandit = load(BANDIT).instantiate()
	bandit.enemy_stats = load(BANDIT_STATS)
	bandit.position = game.map.to_local(Vector2(arena_x + 300.0, floor_y - 40.0))
	game.map.add_child(bandit)
	for i in 40: await physics_frame
	bandit.set_physics_process(false)
	bandit.Max_Health = 99999
	bandit.current_health = bandit.Max_Health
	bandit.damage_token.connect(func(d: int) -> void: hits.append(d))

	await _commitment()
	await _cancel_rules()
	await _stamina()
	await _potion(sl)
	await _no_enemy_bar()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


func _hero_at(x: float, y: float = floor_y) -> void:
	hero.global_position = Vector2(x, y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	await physics_frame


## Упритул до бандита, обличчям до нього.
func _hero_at_bandit() -> void:
	await _hero_at(bandit.hurt_rect().position.x - 30.0)
	bandit.enemy_view.update_direction(-1)
	bandit._face_shapes(-1)


func _until_ready() -> void:
	for i in 120:
		if combat.state == combat.State.READY and not hero.mover.is_rolling() and hero.is_on_floor():
			break
		await physics_frame
	await create_timer(0.7).timeout  # ривки повернулись


## [1] Удар саджає героя з кроком уперед; у повітрі погляд не змінюється, доки удар не вийшов (B136).
func _commitment() -> void:
	print("[1] An attack plants the hero with a short step; facing locks until the hit is out (D504, B136)")
	await _hero_at(arena_x)
	var x0: float = hero.global_position.x
	_press(&"move_right")
	combat.perform_attack(1)
	for i in 6: await physics_frame
	var stepped: float = hero.global_position.x - x0
	ck(stepped > 5.0 and stepped < 20.0, "the swing steps him forward (%.1f px)" % stepped)
	for i in 4: await physics_frame
	ck(absf(hero.velocity.x) < 1.0 and hero.global_position.x - x0 < 20.0,
			"holding right, he stays planted while the swing runs (%.1f px, v %.0f)" % [hero.global_position.x - x0, hero.velocity.x])
	_press(&"move_right", false)
	await _until_ready()
	# У повітрі він летить далі, але не розвертається до кінця удару
	await _hero_at(arena_x, floor_y - 220.0)
	combat.perform_attack(1)
	_press(&"move_left")
	var turned_early := false
	var hitbox_behind := false
	while combat.state == combat.State.SWING and not combat._hit_out:
		turned_early = turned_early or hero.last_direction != 1
		hitbox_behind = hitbox_behind or (combat._hit_on and combat.hitbox.position.x <= 0.0)
		await physics_frame
	ck(not turned_early, "holding back mid-swing does not turn him until the hit is out (B136)")
	ck(not hitbox_behind, "the hitbox stays in front, where he faces")
	for i in 4: await physics_frame
	ck(hero.last_direction == -1, "after the hit he may turn (facing %d)" % hero.last_direction)
	_press(&"move_left", false)
	await _until_ready()


## [2] Зрив удару (D504, редакція D456 / D521) і буфери.
func _cancel_rules() -> void:
	print("[2] A roll or a block cuts an attack only in its recovery; never a heavy's wind-up (D504, B-9)")
	# Перекат, натиснутий у замаху: удар виходить і влучає, перекат — щойно настало відновлення
	await _hero_at_bandit()
	hits.clear()
	combat.perform_attack(1)
	await _tap(&"dodge")
	var frames := 1
	var out_frame := -1
	while not hero.mover.is_rolling() and frames < 30:
		if out_frame < 0 and combat._hit_out:
			out_frame = frames
		await physics_frame
		frames += 1
	ck(hero.mover.is_rolling() and combat.state == combat.State.READY, "a roll pressed in the wind-up is buffered (frame %d)" % frames)
	ck(out_frame >= 0 and frames - out_frame <= 2, "it starts within 2 frames of the recovery (hit out at %d, roll at %d)" % [out_frame, frames])
	ck(hits.size() == 1, "the hit came out before the roll: it is paid for (%s)" % [hits])
	await _until_ready()
	# Блок, натиснутий у замаху, — лише на відновленні
	await _hero_at(arena_x)
	combat.perform_attack(1)
	_press(&"block")
	var early_block := false
	frames = 0
	while not combat.is_blocking() and frames < 30:
		early_block = early_block or (combat.is_blocking() and not combat._hit_out)
		if combat.state == combat.State.SWING and not combat._hit_out:
			out_frame = frames
		await physics_frame
		frames += 1
	ck(combat.is_blocking() and not early_block, "a block held from the wind-up guards only once the hit is out")
	ck(frames - out_frame <= 2, "the block comes within 2 frames of the recovery (%d)" % (frames - out_frame))
	_press(&"block", false)
	await _until_ready()
	# Важкий: замах і удар не зриває ні блок, ні перекат; блок — лише в останні HEAVY_CANCEL_LAST с відновлення
	await _hero_at(arena_x)
	combat.heavy_attack(1)
	await _tap(&"dodge")
	_press(&"block")
	var t0 := Time.get_ticks_msec()
	var rolled := false
	while not combat.is_blocking() and Time.get_ticks_msec() - t0 < 3000:
		rolled = rolled or hero.mover.is_rolling()
		await physics_frame
	var waited := (Time.get_ticks_msec() - t0) / 1000.0
	var earliest: float = combat.heavy_windup + combat.heavy_strike_time + combat.heavy_recovery - combat.HEAVY_CANCEL_LAST
	ck(not rolled, "a roll pressed in the heavy's wind-up never comes")
	ck(combat.is_blocking() and waited >= earliest - 0.05, "a held block guards only late in the heavy's recovery (%.2f s, from %.2f)" % [waited, earliest])
	_press(&"block", false)
	await _until_ready()
	# B-9: перекат у відновленні важкого не скасовує його залишок — він лишається кулдауном
	await _hero_at(arena_x)
	combat.heavy_attack(1)
	while not combat.can_cancel_attack():
		await physics_frame
	var left: float = combat._state_left
	await _tap(&"dodge")
	ck(hero.mover.is_rolling(), "a roll cuts the heavy's recovery late in it")
	ck(combat.attack_cooldown > left - 0.05, "the rest of the recovery stays a cooldown (%.2f of %.2f s, B-9)" % [combat.attack_cooldown, left])
	await _until_ready()
	# Буфер 0.2 с — і крізь збій (повна витривалість: важкий і перекати вище її витратили, тут міряють лише буфер)
	await _hero_at(arena_x)
	hero.stamina.refill()
	combat.stagger(0.15, hero.global_position.x - 10.0)
	await _tap(&"dodge")
	ck(not hero.mover.is_rolling(), "no roll while staggered")
	frames = 0
	while not hero.mover.is_rolling() and frames < 20:
		await physics_frame
		frames += 1
	ck(hero.mover.is_rolling(), "a roll pressed in a 0.15 s stagger starts after it (%d frames)" % frames)
	await _until_ready()
	# Удар, натиснутий у збої, теж чекає
	await _hero_at(arena_x)
	combat.stagger(0.15, hero.global_position.x - 10.0)
	combat.perform_attack(1)
	frames = 0
	while combat.state != combat.State.SWING and frames < 20:
		await physics_frame
		frames += 1
	ck(combat.state == combat.State.SWING, "an attack pressed in a stagger swings after it (%d frames)" % frames)
	await _until_ready()
	# Буфер стрибка: натиснутий за мить до приземлення
	await _hero_at(arena_x, floor_y - 15.0)
	hero.velocity.y = 300.0
	hero.mover.airtime = 1.0
	await _tap(&"jump")
	var jumped := false
	for i in 12:
		if hero.velocity.y < -1.0:
			jumped = true
			break
		await physics_frame
	ck(jumped, "a jump pressed just before landing is buffered")
	await _until_ready()
	# Стрибок зриває відновлення легкого удару
	await _hero_at(arena_x)
	combat.perform_attack(1)
	while not combat._hit_out:
		await physics_frame
	_press(&"jump")  # подія доходить до Input за кадр-два — тримаємо, доки не дійшла
	for i in 6:
		if hero.velocity.y < -1.0:
			break
		await physics_frame
	_press(&"jump", false)
	ck(hero.velocity.y < -1.0 and combat.state == combat.State.READY, "a jump cuts a swing's recovery (v.y %.0f)" % hero.velocity.y)
	await _until_ready()
	# Замах навички не зривається
	combat.state = combat.State.CAST_WINDUP
	combat._state_left = 0.5
	await _tap(&"dodge")
	ck(not hero.mover.is_rolling() and combat.state == combat.State.CAST_WINDUP, "a skill's wind-up is not cut by a roll")
	combat.state = combat.State.READY
	await _until_ready()


## [3] Витривалість (D775; повертає D537, скасовує D551).
func _stamina() -> void:
	print("[3] Stamina: swings, the heavy, rolls and the block spend it; empty = no swing or roll until it refills (D775)")
	var st: Node = hero.stamina
	var bus: Node = root.get_node("EventBus")
	var rows: Array = get_first_node_in_group(&"player_vitals_panel")._rows.get_children().map(func(r: Node) -> String: return r.name)
	ck(rows == ["HP", "SP", "ST"], "the hero panel shows HP, SP and ST under SP; XP is its own bar (D552: %s)" % [rows])
	var refused := [0]
	bus.player_stamina_refused.connect(func() -> void: refused[0] += 1)
	var swings := [0]
	bus.player_attacked.connect(func(_p: Node, _d: int) -> void: swings[0] += 1)
	await _hero_at(arena_x)
	# Тут лише витривалість: ворогів поруч спинено — вони відповідають на бій (D713) і збили б героя посеред серії
	var frozen: Array = []
	for e: Node in get_nodes_in_group(&"enemies"):
		if e.is_physics_processing():
			e.set_physics_process(false)
			frozen.append(e)
	await _until_ready()
	st.refill()
	# Ціни
	await _tap(&"attack")
	ck(is_equal_approx(st.current, st.MAX - st.COST_LIGHT), "a light swing costs %d (%.0f left)" % [st.COST_LIGHT, st.current])
	await _until_ready()
	for f in 60: await physics_frame
	st.refill()
	await _tap(&"heavy_attack")
	ck(is_equal_approx(st.current, st.MAX - st.COST_HEAVY), "the heavy costs %d at its wind-up (%.0f left)" % [st.COST_HEAVY, st.current])
	await _until_ready()
	st.refill()
	await _tap(&"dodge")
	for f in 3: await physics_frame
	ck(hero.mover.is_rolling() and is_equal_approx(st.current, st.MAX - st.roll_cost()), "a roll costs %d (%.0f left)" % [st.roll_cost(), st.current])
	while hero.mover.is_rolling():
		await physics_frame
	# Мішанина: тиснути удар без упину — шкала порожніє за півтори серії, далі ні удару, ні перекату
	await _until_ready()
	for f in 60: await physics_frame
	st.refill()
	swings[0] = 0
	refused[0] = 0
	var t := 0.0
	while not st.exhausted and t < 6.0:
		await _tap(&"attack")
		for f in 6: await physics_frame
		t += 0.1
		if combat.combo_step == combat.combo_length() - 1 and combat.state == combat.State.READY and combat.attack_cooldown > 0.0:
			while combat.attack_cooldown > 0.0:
				await physics_frame
			await _tap(&"heavy_attack")
			while combat.state != combat.State.READY:
				await physics_frame
	ck(st.exhausted and swings[0] <= 6, "mashing runs the bar dry within a combo and a half (%d swings and heavies)" % swings[0])
	await _until_ready()
	var before: int = swings[0]
	await _tap(&"attack")
	for f in 3: await physics_frame
	await _tap(&"dodge")
	for f in 3: await physics_frame
	ck(swings[0] == before and not hero.mover.is_rolling(), "empty: a swing and a roll are refused")
	ck(refused[0] >= 2, "each refusal flashes the ST row and sounds (%d refusals)" % refused[0])
	ck(get_first_node_in_group(&"player_vitals_panel")._rows_by_id["ST"].modulate != Color.WHITE, "the ST row is flashing")
	# Відновлення: швидко після паузи, діяти можна з RECOVER_AT
	var waited := 0.0
	while st.exhausted:
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	ck(waited < 1.4 and st.current >= st.RECOVER_AT, "the hero acts again after %.2f s (bar %.0f)" % [waited, st.current])
	while st.current < st.MAX:
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	ck(waited < 2.2, "the empty bar is full again in %.2f s" % waited)
	await _tap(&"attack")
	for f in 3: await physics_frame
	ck(swings[0] == before + 1, "after the refill the hero swings again")
	await _until_ready()
	for e: Node in frozen:
		if is_instance_valid(e):
			e.set_physics_process(true)
	# Блок: утримання й прийнятий удар коштують; з порожньою шкалою блок слабкий — пів шкоди і збій
	await _hero_at_bandit()
	st.refill()
	st.spend(50.0)
	await create_timer(st.REGEN_DELAY + 0.1).timeout
	var before_raise: float = st.current
	_press(&"block")
	for f in 2: await physics_frame
	ck(st.current < before_raise - st.BLOCK_RAISE + 2.0, "raising the block costs %d (%.0f → %.0f)" % [st.BLOCK_RAISE, before_raise, st.current])
	var held: float = st.current
	await create_timer(1.0).timeout
	ck(st.current > held and st.current - held < st.REGEN * st.BLOCK_REGEN * 1.0 + 3.0,
			"held, the bar refills at a third of the pace (+%.0f in 1 s)" % (st.current - held))
	st.refill()
	var hp: int = hero.current_health
	var left: float = st.current
	hero.take_damage(20, bandit)
	ck(hero.current_health == hp and not combat.is_staggered() and st.current <= left - st.COST_BLOCK + 0.5,
			"a blocked hit: no HP lost, no stagger, −%d stamina" % st.COST_BLOCK)
	st.spend(st.MAX)
	hero.take_damage(20, bandit)
	ck(hero.current_health < hp and combat.is_staggered(), "a blocked hit on an empty bar: a weak block, HP lost and staggered (−%d)" % (hp - hero.current_health))
	_press(&"block", false)
	await create_timer(0.3).timeout
	hero.current_health = hero.Max_Health
	st.refill()
	await _until_ready()


## [4] Швидкий слот зілля (D504): кнопка quick_potion, у реальному часі.
func _potion(sl: Node) -> void:
	print("[4] Potions are drunk in play from a quick slot, with a short animation lock (D504)")
	var inventory: Node = sl.get_inventory_manager()
	for id in ["potion_lesser", "potion", "potion_medium", "hi_potion"]:
		inventory.remove_item(id, inventory.get_item_count(id))
	for id in ["potion_lesser", "potion", "hi_potion"]:
		inventory.add_item(id, 1)
	# Тут лише зілля: вороги поруч спинено — вони карають ковток (D713, D764) і вже не кидають героя посеред бою (B164)
	var frozen: Array[Node] = []
	for e: Node in get_nodes_in_group(&"enemies"):
		if e.is_physics_processing():
			e.set_physics_process(false)
			frozen.append(e)
	while frozen.any(func(e: Node) -> bool: return is_instance_valid(e) and e.enemy_logic.is_attacking):
		await physics_frame
	await _hero_at(arena_x)
	hero.Max_Health = 500
	hero.current_health = 440
	await _tap(&"quick_potion")
	ck(combat.is_drinking() and combat.locks_movement(), "one button: he drinks, planted")
	ck(inventory.get_item_count("potion") == 0 and inventory.get_item_count("potion_lesser") == 1,
			"60 HP missing: the slot takes the Potion (75), the smallest that covers it")
	var label: Label = get_first_node_in_group(&"player_vitals_panel").get_node(^"%PotionChip/Pill/Count")
	ck(label.text == "×2", "the Q chip counts the potions left (%s)" % label.text)
	ck(hero.current_health == 440, "no heal before the sip")
	await create_timer(combat.DRINK_HEAL_AT + 0.05).timeout
	ck(hero.current_health == 500, "healed in real time (%d)" % hero.current_health)
	await create_timer(combat.DRINK_TIME - combat.DRINK_HEAL_AT).timeout
	ck(combat.state == combat.State.READY, "the lock ends")
	await _tap(&"quick_potion")
	ck(not combat.is_drinking(), "at full HP the slot keeps its potions")
	# Удар до ковтка — зілля пропало
	hero.current_health = 300
	await _tap(&"quick_potion")
	ck(inventory.get_item_count("hi_potion") == 0, "200 missing: the Hi-Potion")
	await create_timer(0.2).timeout
	combat.stagger(0.2, hero.global_position.x - 10.0)
	await create_timer(0.8).timeout
	ck(hero.current_health == 300, "a hit before the sip: no heal, the potion is lost (%d)" % hero.current_health)
	# У повітрі — ні
	await _hero_at(arena_x, floor_y - 200.0)
	await _tap(&"quick_potion")
	ck(not combat.is_drinking() and inventory.get_item_count("potion_lesser") == 1, "not in the air")
	await _until_ready()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	for e: Node in frozen:
		if is_instance_valid(e):
			e.set_physics_process(true)


## [5] D502: над звичайним ворогом смужки HP немає — ні одразу, ні після удару.
func _no_enemy_bar() -> void:
	print("[5] Ordinary enemies have no floating HP bar (D502)")
	var canvas: Node = game.get_node(^"UICanvas")
	var bars := func() -> int: return canvas.get_children().filter(func(n: Node) -> bool: return n.get_script() != null and String(n.get_script().resource_path).ends_with("HealthBar.gd")).size()
	var before: int = bars.call()
	var extra: Node = load(BANDIT).instantiate()
	extra.enemy_stats = load(BANDIT_STATS)
	extra.position = game.map.to_local(Vector2(arena_x - 300.0, floor_y - 40.0))
	game.map.add_child(extra)
	for i in 20: await physics_frame
	extra.set_physics_process(false)
	extra.take_damage(10, hero)
	for i in 10: await physics_frame
	ck(bars.call() == before, "no HealthBar appears for a bandit, even hurt (%d → %d)" % [before, bars.call()])
	ck(not "health_bar" in extra, "the enemy has no health_bar at all")
	await _poise_bar(extra)
	extra.queue_free()


## [6] Шкала стійкості (D776): є в кожного ворога; набирається з ударами, спадає без них; повна — збій і порожня.
## Скільки ударів — не важить: три легкі удари серії звичайного ворога не збивають.
func _poise_bar(enemy: Node) -> void:
	print("[6] Every enemy has a poise bar: it fills with hits, drains without them, and a full bar staggers (D776)")
	var bar: Control = enemy.get_children().filter(func(n: Node) -> bool: return n.name == "PoiseBar").front()
	var fill: ProgressBar = bar.get_node(^"Bar")
	var staggered := [0]
	var bus: Node = root.get_node("EventBus")
	var on_stagger := func(e: Node, _d: float) -> void:
		if e == enemy:
			staggered[0] += 1
	bus.enemy_staggered.connect(on_stagger)
	for i in 3:
		enemy.take_poise(combat.POISE_LIGHT, hero.global_position.x)
	await process_frame
	ck(staggered[0] == 0 and is_equal_approx(fill.value, 3.0) and bar.visible,
			"a three-hit combo fills 3 of %d and does not stagger (D776: no stagger from the third hit)" % enemy.poise_max)
	var held: float = fill.value
	enemy.set_physics_process(true)  # спадає на кроках фізики ворога
	await create_timer(enemy.POISE_DRAIN_DELAY + 1.0).timeout
	enemy.set_physics_process(false)
	ck(fill.value < held, "without hits the bar drains (%.1f → %.1f)" % [held, fill.value])
	enemy.take_poise(combat.POISE_HEAVY, hero.global_position.x, &"heavy")
	ck(combat.POISE_HEAVY >= 4 * combat.POISE_LIGHT, "a heavy fills %d, a light %d" % [combat.POISE_HEAVY, combat.POISE_LIGHT])
	enemy.take_poise(enemy.poise_max, hero.global_position.x, &"heavy")
	await process_frame
	ck(staggered[0] == 1 and enemy.last_stagger_source == &"" and is_zero_approx(fill.value) and enemy.is_staggered(),
			"a full bar staggers the enemy and empties (%.1f)" % fill.value)
	bus.enemy_staggered.disconnect(on_stagger)
