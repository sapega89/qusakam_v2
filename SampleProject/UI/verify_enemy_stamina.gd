extends SceneTree

## Витривалість ворогів (D824, design/enemy_stamina_plan.md, EnemyStamina): числа з enemy_variety.json, удар платить у мить
## удару, шкала набирається, поки ворог не б'є; не вистачає на удар — не б'є; удар, що її вичерпав, кінчає серію, і ворог
## видихається (стоїть, тінь, звук, червона смужка); смужка під шкалою стійкості видна лише в бою; бос б'є свій візерунок
## далі й видихається після відновлення ходу. [8] — темп ударів бандита й шакала з витривалістю й без неї (звіт).
##   godot --headless --path . --script res://SampleProject/UI/verify_enemy_stamina.gd

const EnemyVariety = preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const JACKAL := "res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn"
const VULTURE := "res://SampleProject/Scenes/Characters/Enemies/enemy_vulture.tscn"
const BRASS := "res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn"
const STATS := {BANDIT: "melee", JACKAL: "fast", VULTURE: "vulture"}
## Скільки секунд рахуємо темп ударів у [8].
const RATE_TIME := 40.0

var fails: Array[String] = []
var game: Node
var hero: Node
var eb: Node
var floor_y := 0.0
var arena_x := 0.0

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746
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
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.is_invulnerable = true  # удари не відкидають і не вбивають героя: міряємо самого ворога
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	_data()
	await _spend_and_regen()
	await _cannot_afford()
	await _winded()
	await _bar_when_engaged()
	await _flier_spends()
	await _boss_keeps_pattern()
	await _rates()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _spawn(path: String, dx: float) -> Node:
	var enemy: Node = load(path).instantiate()
	if STATS.has(path):
		enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % STATS[path])
	enemy.position = game.map.to_local(Vector2(arena_x + dx, floor_y - 40.0))
	game.map.add_child(enemy)
	enemy.Max_Health = 999999
	enemy.current_health = enemy.Max_Health
	await create_timer(0.4).timeout
	return enemy

func _place_hero(dx_from: Node, dx: float) -> void:
	hero.global_position = Vector2(dx_from.global_position.x + dx, floor_y)
	hero.velocity = Vector2.ZERO
	await physics_frame

## Чекає першого удару (хітбокс увімкнувся) до [param limit] с; true — вдарив.
func _await_strike(enemy: Node, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		await physics_frame
		t += 1.0 / 60.0
		if enemy.hitbox.monitoring:
			return true
	return false

func _data() -> void:
	print("[1] numbers per kind from enemy_variety.json")
	for id in EnemyVariety.kind_ids():
		var row := EnemyVariety.stamina(id, false)
		ck(float(row.max) > 0.0 and float(row.swing) > 0.0 and float(row.regen) > 0.0 and float(row.winded) > 0.0,
				"%s: max %.0f, swing %.0f, lunge %.0f, pounce %.0f, regen %.0f/s after %.1f s, winded %.1f s" % [id, row.max, row.swing,
				row.lunge, row.pounce, row.regen, row.delay, row.winded])
	var base := EnemyVariety.stamina("melee", false)
	var brute := EnemyVariety.stamina("bandit_brute", false)
	ck(is_equal_approx(float(brute.max), float(base.max) * float(EnemyVariety.data().stamina.elite.max)), "an elite's pool is its kind's × elite.max (%.0f)" % brute.max)
	ck(is_equal_approx(float(EnemyVariety.stamina("jackal_cursed", false).swing), float(EnemyVariety.stamina("fast", false).swing)),
			"a big kind without a row takes its base kind's costs")
	var boss := EnemyVariety.stamina("brass_collector", true)
	ck(float(boss.max) > 0.0 and boss.has("combo") and boss.has("charge") and boss.has("slam"), "bosses: own pool %.0f, costs per move kind" % boss.max)

func _spend_and_regen() -> void:
	print("[2] a swing spends at the strike; it refills while the enemy does not attack")
	var bandit := await _spawn(BANDIT, 0.0)
	var st: Node = bandit.stamina
	await _place_hero(bandit, -40.0)
	bandit.enemy_logic.attack_ready_in = 0.0
	var before: float = st.current
	ck(is_equal_approx(before, st.max_stamina), "starts full (%.0f)" % before)
	var struck := await _await_strike(bandit, 4.0)
	ck(struck and is_equal_approx(st.current, before - st.cost(&"swing")), "the first blow of the series costs %.0f (%.0f → %.0f)" % [st.cost(&"swing"), before, st.current])
	while bandit.enemy_logic.is_attacking:
		await physics_frame
	var after: float = st.current
	await _place_hero(bandit, -900.0)  # герой далеко — ворог не б'є
	bandit.enemy_logic.change_state(bandit.enemy_logic.AIState.IDLE)
	await create_timer(st.delay * 0.5).timeout
	ck(is_equal_approx(st.current, after) or st.current < after + 2.0, "no refill during the %.1f s delay (%.0f)" % [st.delay, st.current])
	await create_timer(st.delay * 0.5 + 0.5).timeout
	var gained: float = st.current - after
	ck(gained > st.regen * 0.3 and gained < st.regen * 0.7 + 1.0, "then about %.0f/s (+%.0f in 0.5 s)" % [st.regen, gained])
	bandit.queue_free()
	await create_timer(0.2).timeout

func _cannot_afford() -> void:
	print("[3] cannot pay the next blow → keeps away and does not attack")
	var bandit := await _spawn(BANDIT, 0.0)
	var st: Node = bandit.stamina
	st.regen = 0.0  # держимо шкалу внизу
	st.current = st.cost(&"swing") - 1.0
	var tactics: Array[StringName] = []
	bandit.enemy_logic.tactic.connect(func(name: StringName) -> void: tactics.append(name))
	await _place_hero(bandit, -40.0)
	bandit.enemy_logic.attack_ready_in = 0.0
	var struck := await _await_strike(bandit, 3.0)
	ck(not struck and not bandit.enemy_logic.is_attacking, "no swing and no lunge for 3 s with %.0f < %.0f" % [st.current, st.cost(&"swing")])
	ck(&"catch_breath" in tactics, "it says catch_breath (%s)" % [tactics])
	var gap: float = absf(hero.global_position.x - bandit.global_position.x)
	ck(gap > bandit.enemy_logic._hero_reach(), "it stands out of the hero's reach (%.0f > %.0f px)" % [gap, bandit.enemy_logic._hero_reach()])
	st.regen = EnemyVariety.stamina("melee", false).regen
	var back := await _await_strike(bandit, 6.0)
	ck(back, "having refilled, it attacks again (%.0f)" % st.current)
	bandit.queue_free()
	await create_timer(0.2).timeout

func _winded() -> void:
	print("[4] the blow that empties the bar ends the series; the enemy is winded and open")
	var bandit := await _spawn(BANDIT, 0.0)
	var st: Node = bandit.stamina
	var sounds: Array[StringName] = []
	var on_winded := func(enemy: Node, time: float) -> void:
		if enemy == bandit:
			sounds.append(&"winded %.1f" % time)
	eb.enemy_winded.connect(on_winded)
	st.current = st.cost(&"swing")  # рівно на один удар: серія з двох (combo_chance 1.0) уривається після першого
	await _place_hero(bandit, -40.0)
	bandit.enemy_logic.attack_ready_in = 0.0
	var strikes := 0
	var was_on := false
	var t := 0.0
	while t < 5.0 and (strikes == 0 or bandit.enemy_logic.is_attacking):
		await physics_frame
		t += 1.0 / 60.0
		if bandit.hitbox.monitoring and not was_on:
			strikes += 1
		was_on = bandit.hitbox.monitoring
	ck(strikes == 1, "one blow, not the series of %d (%d)" % [bandit.combo_hits, strikes])
	ck(st.exhausted and st.winded_left > 0.0, "winded for %.1f s (left %.2f)" % [st.winded_time, st.winded_left])
	ck(bandit.enemy_logic.stun_left > 0.0, "it stands, stunned for the window (stun %.2f)" % bandit.enemy_logic.stun_left)
	await physics_frame
	ck(bandit.sprite.modulate.is_equal_approx(bandit.STUN_TINT), "the tint shows (%s)" % bandit.sprite.modulate)
	ck(not sounds.is_empty(), "EventBus.enemy_winded (the stamina_empty sound in SoundHooks): %s" % [sounds])
	var strip: Control = bandit.find_children("EnemyStaminaBar", "", true, false)[0]
	ck(strip.get_node(^"Bar").theme_type_variation == &"EnemyStaminaBarSpent", "the strip turns red (%s)" % strip.get_node(^"Bar").theme_type_variation)
	var hit := false
	t = 0.0
	while t < st.winded_time:
		await physics_frame
		t += 1.0 / 60.0
		hit = hit or bandit.enemy_logic.is_attacking
	ck(not hit, "no attack while winded")
	var stats: Dictionary = EnemyVariety.stamina("melee", false)
	var back_in: float = float(stats.delay) + st.max_stamina * st.recover_at / st.regen
	var back := await _await_strike(bandit, back_in + 4.0)
	ck(back and not st.exhausted, "it fights again once it has %.0f %% (%.1f s from empty)" % [st.recover_at * 100.0, back_in])
	ck(strip.get_node(^"Bar").theme_type_variation == &"EnemyStaminaBar", "the strip is its own colour again")
	eb.enemy_winded.disconnect(on_winded)
	bandit.queue_free()
	await create_timer(0.2).timeout

func _bar_when_engaged() -> void:
	print("[5] the strip under the poise bar, only while engaged")
	var bandit := await _spawn(BANDIT, 0.0)
	while bandit.enemy_logic.is_attacking:
		await physics_frame
	await _place_hero(bandit, -1200.0)
	bandit.enemy_logic.change_state(bandit.enemy_logic.AIState.IDLE)
	await create_timer(0.2).timeout
	var poise: Control = bandit.find_children("PoiseBar", "", true, false)[0]
	var strip: Control = poise.get_node(^"EnemyStaminaBar")
	ck(strip != null, "the strip is a child of the poise bar")
	ck(not strip.is_visible_in_tree(), "hidden while the enemy is not fighting (state %d, attacking %s, stun %.2f, engaged %s)" % [bandit.enemy_logic.current_state, bandit.enemy_logic.is_attacking, bandit.enemy_logic.stun_left, bandit.is_engaged()])
	await _place_hero(bandit, -150.0)
	var t := 0.0
	while t < 2.0 and not bandit.is_engaged():
		await physics_frame
		t += 1.0 / 60.0
	await process_frame
	await process_frame
	ck(bandit.is_engaged() and strip.is_visible_in_tree(), "shown once it fights (engaged %s, strip %s)" % [bandit.is_engaged(), strip.is_visible_in_tree()])
	ck(is_equal_approx(strip.position.y, UITokens.POISE_BAR_HEIGHT + UITokens.ENEMY_STAMINA_GAP) and is_equal_approx(strip.size.y, UITokens.ENEMY_STAMINA_HEIGHT)
			and is_equal_approx(strip.size.x, poise.size.x), "under the poise bar: y %.0f, %.0f × %.0f (poise %.0f × %.0f)" % [strip.position.y, strip.size.x, strip.size.y, poise.size.x, poise.size.y])
	var fill: StyleBoxFlat = strip.get_node(^"Bar").get_theme_stylebox(&"fill")
	var poise_fill: StyleBoxFlat = poise.get_node(^"Bar").get_theme_stylebox(&"fill")
	ck(fill.bg_color.is_equal_approx(UITokens.ENEMY_STAMINA_FILL) and not fill.bg_color.is_equal_approx(poise_fill.bg_color),
			"its own colour from the theme (%s), not the poise yellow (%s)" % [fill.bg_color.to_html(false), poise_fill.bg_color.to_html(false)])
	bandit.queue_free()
	await create_timer(0.2).timeout

func _flier_spends() -> void:
	print("[6] a flier pays for its dive")
	var vulture := await _spawn(VULTURE, 0.0)
	var st: Node = vulture.stamina
	vulture.global_position = Vector2(arena_x, floor_y - 160.0)
	await _place_hero(vulture, -10.0)
	var struck := await _await_strike(vulture, 8.0)
	ck(struck and st.current <= st.max_stamina - st.cost(&"swing") + 1.0, "the dive costs %.0f (%.0f left)" % [st.cost(&"swing"), st.current])
	vulture.queue_free()
	await create_timer(0.2).timeout

func _boss_keeps_pattern() -> void:
	print("[7] a boss keeps its pattern: empty pool → the move still runs, then winded after its recovery, then full")
	var endless := await _boss_run(false)
	var spent := await _boss_run(true)
	ck(spent.picked.size() >= 4 and spent.picked == endless.picked, "the same moves in the same order with an empty pool %s as with an endless one %s" % [spent.picked, endless.picked])
	ck(spent.combo_blows == endless.combo_blows, "combo series keep their length (%s vs %s)" % [spent.combo_blows, endless.combo_blows])
	ck(endless.winded_after.is_empty() and not spent.winded_after.is_empty() and spent.winded_after[0] == spent.picked[0],
			"winded right after the move that emptied it (%s)" % [spent.winded_after])
	ck(not spent.winded_in_recovery, "never winded during a move's own recovery (D316 stands)")
	ck(spent.refilled, "the pool is full again the moment the window ends")

## Бос ходить ~4 ходи; [param empty] — пул майже порожній на старті. Ходи, удари серій, після яких ходів видихнувся.
func _boss_run(empty: bool) -> Dictionary:
	var boss := await _spawn(BRASS, 140.0)
	var logic: Node = boss.enemy_logic
	var st: Node = boss.stamina
	if not empty:
		ck(st.regen <= 0.0 and is_equal_approx(st.max_stamina, float(EnemyVariety.stamina("brass_collector", true).max)), "own pool %.0f, no refill mid-fight" % st.max_stamina)
		var row: Control = boss.bar.get_node(^"%BossStamina")
		ck(is_equal_approx(row.get_node(^"Bar").max_value, st.max_stamina), "the boss bar has a stamina row under poise")
		st.max_stamina = 1.0e9
		st.current = st.max_stamina
	while logic.is_attacking:
		await physics_frame
	await _place_hero(boss, -50.0)
	logic.pattern_at = 0
	logic.last_move = {}
	if empty:
		st.current = 1.0  # перший же хід вичерпає пул
	logic.attack_ready_in = 0.0
	var out := {"picked": [], "combo_blows": [], "winded_after": [], "winded_in_recovery": false, "refilled": false}
	var t := 0.0
	var was_attacking := false
	var was_winded := false
	var was_on := false
	var last_kind := ""
	while t < 30.0 and out.picked.size() < 4:
		await physics_frame
		t += 1.0 / 60.0
		hero.global_position = Vector2(boss.global_position.x - 50.0, floor_y)
		if logic.is_attacking and not was_attacking:
			last_kind = logic.last_move.get("kind", "")
			out.picked.append(last_kind)
			if last_kind == "combo":
				out.combo_blows.append(0)
		if boss.hitbox.monitoring and not was_on and last_kind == "combo":
			out.combo_blows[-1] += 1
		was_on = boss.hitbox.monitoring
		if was_attacking and not logic.is_attacking and st.winded_left > 0.0:
			out.winded_after.append(last_kind)
		if logic.recovering and st.winded_left > 0.0:
			out.winded_in_recovery = true
		was_attacking = logic.is_attacking
		if was_winded and st.winded_left <= 0.0:
			out.refilled = is_equal_approx(st.current, st.max_stamina) and not st.exhausted
		was_winded = st.winded_left > 0.0
	boss.queue_free()
	await create_timer(0.3).timeout
	return out

## Темп: скільки ударів за RATE_TIME с вид завдає невразливому героєві, що стоїть поруч, з витривалістю і з
## нескінченною (для звіту, D824: бої не мають стати легкими).
func _rates() -> void:
	print("[8] tempo against a hero who stands in reach (strikes in %.0f s)" % RATE_TIME)
	for path in [BANDIT, JACKAL]:
		var with_st := await _count(path, false)
		var without := await _count(path, true)
		var ratio := float(with_st.strikes) / maxf(1.0, float(without.strikes))
		print("  %s: %d strikes, winded %d× with stamina; %d without (×%.2f)" % [STATS[path], with_st.strikes, with_st.winded, without.strikes, ratio])
		ck(ratio >= 0.6, "%s keeps at least 60 %% of its tempo (×%.2f)" % [STATS[path], ratio])
		ck(with_st.winded >= 1 or with_st.breaths >= 1, "%s runs short at least once (winded %d, catch_breath %d)" % [STATS[path], with_st.winded, with_st.breaths])

func _count(path: String, endless: bool) -> Dictionary:
	var enemy := await _spawn(path, 0.0)
	var st: Node = enemy.stamina
	if endless:
		st.max_stamina = 1.0e9
		st.current = st.max_stamina
	var out := {"strikes": 0, "winded": 0, "breaths": 0}
	st.winded.connect(func(_time: float) -> void: out.winded += 1)
	enemy.enemy_logic.tactic.connect(func(name: StringName) -> void:
		if name == &"catch_breath":
			out.breaths += 1)
	await _place_hero(enemy, -60.0)
	var was_on := false
	var t := 0.0
	while t < RATE_TIME:
		await physics_frame
		t += 1.0 / 60.0
		if absf(hero.global_position.x - enemy.global_position.x) > 400.0:
			hero.global_position.x = enemy.global_position.x - 60.0
		if enemy.hitbox.monitoring and not was_on:
			out.strikes += 1
		was_on = enemy.hitbox.monitoring
	enemy.queue_free()
	await create_timer(0.3).timeout
	return out
