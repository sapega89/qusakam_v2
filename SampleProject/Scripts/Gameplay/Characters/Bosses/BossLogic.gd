extends EnemyLogic

## Ходи боса (D301, D302, design/lab_boss_plan.md). Хід обирається не випадково, а за візерунком (D504): BossEnemy.pattern
## (у другій фазі — pattern_phase2) — це черга kind; береться перший наступний у черзі хід, у чию дальність зараз
## потрапляє герой і який не повторює щойно зроблений (повтор — лише коли нічого іншого не підходить). Жоден не
## підходить — бос іде до героя. Між ходами бос не стоїть: тримається на своїй preferred_range.
## combo — серія ударів хітбоксом з фіксованою довжиною й підказками (tells, у другій фазі tells_phase2); інші — свої:
##   charge   — ривок на distance px з живим хітбоксом;
##   slam     — ударна хвиля по підлозі на radius px в обидва боки, героя в повітрі не зачіпає;
##   fireball — вогняна куля на висоті героя (у другій фазі — count_phase2 штук поспіль);
##   pillar   — мітка на підлозі під героєм, потім стовп вогню width px (у другій фазі — ще по одному обабіч, side px);
##   drink    — не удар: бос п'є з фляги time с (D564), без підказки й шкоди — вікно для героя.
## Після кожного ходу бос recovery с стоїть у позі удару — вікно для відповіді героя. Підказка ходу — його tell
## (EnemyLogic.TELL_*): хвиля, куля й стовп — червоні, їх не блокують і не парирують (B133); шкоду від них несе сам
## снаряд, а не бос. Бос не відкидається (B134) і жетона удару не бере. Усі таймери стоять на паузі (B135).

const FIREBALL := preload("res://SampleProject/Scenes/FX/Bosses/boss_fireball.tscn")
const PILLAR := preload("res://SampleProject/Scenes/FX/Bosses/boss_pillar.tscn")
const SHOCKWAVE := preload("res://SampleProject/Scenes/FX/Bosses/boss_shockwave.tscn")

## Герой на тій самій підлозі, що й бос: різниця центрів тіл не більша (інакше він на іншому поверсі чи в стрибку).
const SAME_FLOOR := 120.0
const CHARGE_TIME := 0.45
const FIREBALL_GAP := 0.35
## Між ходами бос іде до preferred_range, якщо відхилився більше ніж на PREFERRED_BAND px, на частці своєї швидкості.
const PREFERRED_BAND := 30.0
const REPOSITION_SPEED := 0.6
## Відкритого героя (EnemyLogic._hero_opened) бос карає з досяжності своєї серії (combo) і ще до COMBO_STEP_IN px за нею.
const COMBO_STEP_IN := 60.0
## D775: герой стоїть у досяжності серії довше за REACH_PATIENCE с — бос б'є, не чекаючи кінця перерви (не стоїть перед
## ним).
const REACH_PATIENCE := 0.7
var _reach_wait := 0.0

## Останній обраний хід — для тестів і журналу.
var last_move: Dictionary = {}
## Хід combo, що зараз іде (його серія й відновлення), — не last_move: той можуть перезаписати посеред серії.
var _combo: Dictionary = {}
## Місце в черзі візерунка й фаза, для якої вона йде.
var pattern_at := 0
var _pattern_phase := 1


func token_free() -> bool:
	return true


func _punish_range() -> float:
	return _combo_reach() + COMBO_STEP_IN


## Бос між ходами тримає свою відстань (preferred_range, B159), а не відходить з досяжності, і не фінтує: його візерунок
## і так читається (D775).
func _decide_after_attack() -> void:
	pass


func _can_feint() -> bool:
	return false


func _series_fits(_windup: float) -> bool:
	return true


func _abandons() -> bool:
	return false


## Удар серії боса платить за його хід combo (D824).
func _swing_kind() -> StringName:
	return &"combo"


## Серію свого ходу бос б'є до кінця й без витривалості (D824): візерунок (D577) не ламається, бос видихнеться після неї.
func _breath_ends_series() -> bool:
	return false


## Бос карає лише великі вікна (D775): відновлення важкого й приземлення; флягу, каст і кінець серії — ні (його
## візерунок і так тисне, а вікно для ковтка біля боса герой має вибороти відходом).
func _hero_opened(adx: float) -> bool:
	if adx > _punish_range():
		return false
	return player.combat.state == PlayerCombat.State.HEAVY_RECOVERY or _land_left > 0.0


func _hold_token() -> void:
	pass


func handle_attack_state(delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	if absf(dx) > attack_range * 1.2:
		change_state(AIState.CHASE)
		return
	_face_player()
	var toward := 1 if dx > 0.0 else -1
	var adx := absf(dx)
	_reach_wait = _reach_wait + delta if adx <= _combo_reach() else 0.0
	var opened := _hero_opened(adx)
	if attack_ready_in <= 0.0 or opened or _reach_wait > REACH_PATIENCE:
		if _fits_any(dx):
			_reach_wait = 0.0
			if opened:
				tactic.emit(&"punish")
			_rest_after_swing()
			perform_attack()
		else:
			_step(toward, speed)
		return
	# Між ходами — не далі за досяжність ходу, заради якого бос тримає preferred_range (B-boss): інакше він стояв поза
	# дальністю серії (combo), і візерунок щоразу підміняв її хвилею чи ковтком, що дістають далі, — зброєю не бив ніколи.
	var far := minf(enemy.preferred_range + PREFERRED_BAND, _rest_reach())
	if absf(dx) > far:
		_step(toward, speed * REPOSITION_SPEED)
	elif absf(dx) < minf(enemy.preferred_range - PREFERRED_BAND, far):
		_step(-toward, speed * REPOSITION_SPEED)
	else:
		velocity.x = 0


func perform_attack() -> void:
	var move := pick_move()
	if move.is_empty():
		return
	last_move = move
	if move.kind == "drink":
		await _drink(move)
		return
	if move.kind == "combo":
		_combo = move
		await super.perform_attack()
		_rest()
		return
	is_attacking = true
	attack_broken = false
	tell_kind = StringName(move.tell)
	swing_windup = move.windup * enemy.windup_scale
	attack_started.emit()
	EventBus.attack_started.emit(enemy, player)
	enemy.telegraph(move)
	await wind_up(swing_windup)
	if not _interrupted():
		enemy.strike(move)
		enemy.stamina.spend(StringName(move.kind))  # D824: хід коштує витривалості з пулу боса
		match move.kind:
			"charge": await _charge(move)
			"slam": _slam(move)
			"fireball": await _fireballs(move)
			"pillar": await _pillars(move)
			_: assert(false, "BossLogic: unknown move kind %s" % move.kind)
		committed = false
		# Відновлення: бос стоїть у позі удару — вікно для відповіді героя (D265, D504).
		recovering = true
		await get_tree().create_timer(float(move.recovery), false).timeout
		recovering = false
	committed = false
	is_attacking = false
	enemy.stamina.take_winded()  # D824: пул вичерпано — після відновлення ходу (D316) бос видихається, тоді знову повний
	_rest()
	attack_ended.emit()
	_decide_after_attack()


## Ковток (D564): бос стоїть у позі ковтка time с, як у відновленні (recovering), — героєві бити у відповідь.
func _drink(move: Dictionary) -> void:
	is_attacking = true
	attack_broken = false
	enemy.drink(move)
	enemy.stamina.refill()  # D824: ковток — і подих
	recovering = true
	await get_tree().create_timer(float(move.time), false).timeout
	recovering = false
	is_attacking = false
	_rest()
	attack_ended.emit()
	_decide_after_attack()


## Серія ходу combo — фіксована (D504): по удару на кожну підказку tells (у другій фазі tells_phase2, якщо є).
func _swing_tells() -> Array[StringName]:
	var names: Array = _combo.tells
	if enemy.phase >= 2:
		names = _combo.get("tells_phase2", names)
	var tells: Array[StringName] = []
	for kind: String in names:
		tells.append(StringName(kind))
	return tells


func _recovery_time() -> float:
	return float(_combo.recovery)


## Перерва EnemyStats.attack_cooldown боса (D394) рахується від кінця ходу, а не від замаху: довгий замах боса інакше з'їдав би
## всю перерву, і новий хід починався б одразу після удару — героєві ніколи бити у відповідь.
func _rest() -> void:
	attack_ready_in = enemy.attack_cooldown * randf_range(RHYTHM_MIN, RHYTHM_MAX)  # не метроном (D775)


## Ривок (charge) дістає лише на свою смугу — distance плюс melee_reach (та сама, що креслить підказка, D522): з далі він
## спиняється перед героєм, не зачепивши (B-boss).
func _reach(move: Dictionary) -> float:
	var far: float = move.get("max_range", INF)
	if move.kind == "charge":
		far = minf(far, float(move.distance) + enemy.melee_reach)
	return far


func _fits(move: Dictionary, dx: float) -> bool:
	return dx >= move.get("min_range", 0.0) and dx <= _reach(move) and enemy.phase >= move.get("phase", 1)


## Час ходити: є хід, що дістає з [param dx] (герой праворуч — додатне). Коли наступний хід візерунка ще не дістає
## (_must_close), бос не б'є тим, що дістає далі, а підходить — хіба що дістає ривок, він сам скорочує відстань: хвиля
## чи ковток лишили б боса там, де він стоїть, і серію (combo) знову б підмінило (B-boss).
func _fits_any(dx: float) -> bool:
	var closing := _must_close(dx)
	return enemy.moves.any(func(m: Dictionary) -> bool: return _fits(m, absf(dx)) and (not closing or m.kind == "charge"))


## Наступний хід візерунка ще не дістає до героя, а підійти є куди (B-boss): бос іде до нього, а не підміняє його ходом,
## що дістає далі. Так лише з ходом, що дістає з preferred_range (заради нього бос там і стоїть: найманець і сокирник —
## серія); джин, що тримається далеко, по серію не йде. Наступний — той, що не повторює щойно зроблений.
func _must_close(dx: float) -> bool:
	var pattern: PackedStringArray = _pattern()
	if pattern.is_empty() or not can_step(1 if dx > 0.0 else -1):
		return false
	var at := pattern_at if enemy.phase == _pattern_phase else 0
	var kind := pattern[at % pattern.size()]
	if kind == last_move.get("kind", ""):
		kind = pattern[(at + 1) % pattern.size()]
	return enemy.moves.any(func(m: Dictionary) -> bool: return m.kind == kind and enemy.phase >= m.get("phase", 1) and absf(dx) > _reach(m) \
			and _reach(m) >= enemy.preferred_range)


## Найдальша досяжність серії (combo) у цій фазі; немає серії — 0.
func _combo_reach() -> float:
	var reach := 0.0
	for move: Dictionary in enemy.moves:
		if move.kind == "combo" and enemy.phase >= move.get("phase", 1):
			reach = maxf(reach, _reach(move))
	return reach


func _pattern() -> PackedStringArray:
	return enemy.pattern_phase2 if enemy.phase >= 2 and not enemy.pattern_phase2.is_empty() else enemy.pattern


## Найкоротша досяжність ходу цієї фази, що ще дістає з preferred_range (найманець і сокирник — серія, джин — куля).
func _rest_reach() -> float:
	var near := INF
	for move: Dictionary in enemy.moves:
		if enemy.phase >= move.get("phase", 1) and _reach(move) >= enemy.preferred_range:
			near = minf(near, _reach(move))
	return near


## Хід за візерунком (D504): наступний у черзі kind, що підходить за відстанню й фазою і не повторює останній хід;
## повтор — лише коли інших немає. Нова фаза — черга спочатку. Нічого не підходить — {}.
func pick_move() -> Dictionary:
	if enemy.phase != _pattern_phase:
		_pattern_phase = enemy.phase
		pattern_at = 0
	var dx := absf(player.global_position.x - enemy.global_position.x)
	var pattern := _pattern()
	var repeat := {}
	var repeat_at := -1
	for step in pattern.size():
		var at := (pattern_at + step) % pattern.size()
		for move: Dictionary in enemy.moves:
			if move.kind != pattern[at] or not _fits(move, dx):
				continue
			if move.kind == last_move.get("kind", ""):
				if repeat_at < 0:
					repeat = move
					repeat_at = at
				continue
			pattern_at = at + 1
			return move
	if repeat_at >= 0:
		pattern_at = repeat_at + 1
	return repeat


func _damage(move: Dictionary) -> int:
	return roundi(enemy.damage * move.get("damage", 1.0))


func _charge(move: Dictionary) -> void:
	var direction := last_direction if last_direction != 0 else 1
	enemy.damage = enemy.base_damage * move.get("damage", 1.0)  # хітбокс бере шкоду з enemy.damage
	enemy.start_attack(direction)
	start_knockback(direction * float(move.distance), false, CHARGE_TIME)
	await get_tree().create_timer(CHARGE_TIME, false).timeout
	enemy.end_attack()
	enemy.damage = enemy.base_damage


## Шкоду несе сама хвиля (B133): її не заблокувати й не парирувати, як і кулю й стовп.
func _slam(move: Dictionary) -> void:
	var wave: Node2D = SHOCKWAVE.instantiate()
	wave.radius = move.radius
	enemy.get_parent().add_child(wave)
	wave.global_position = enemy.global_position
	var hero: Node2D = player
	var grounded: bool = hero.is_on_floor() and absf(hero.global_position.y - enemy.global_position.y) <= SAME_FLOOR
	if grounded and absf(hero.global_position.x - enemy.global_position.x) <= float(move.radius):
		hero.take_damage(_damage(move), wave)


func _fireballs(move: Dictionary) -> void:
	var count: int = move.get("count_phase2", 1) if enemy.phase >= 2 else 1
	for i in count:
		if enemy.is_dead or attack_broken:
			return
		var ball: Area2D = FIREBALL.instantiate()
		ball.direction = last_direction if last_direction != 0 else 1
		ball.damage = _damage(move)
		enemy.get_parent().add_child(ball)
		ball.global_position = Vector2(enemy.global_position.x + ball.direction * enemy.melee_reach * 0.5, player.global_position.y - 24.0)
		if i < count - 1:
			await get_tree().create_timer(FIREBALL_GAP, false).timeout


func _pillars(move: Dictionary) -> void:
	var xs: Array[float] = [player.global_position.x]
	if enemy.phase >= 2:
		xs.append_array([xs[0] - float(move.side), xs[0] + float(move.side)])
	var pillars: Array[Node2D] = []
	for x in xs:
		var pillar: Node2D = PILLAR.instantiate()
		pillar.width = move.width
		pillar.damage = _damage(move)
		enemy.get_parent().add_child(pillar)
		pillar.global_position = Vector2(x, enemy.global_position.y)
		pillars.append(pillar)
	await pillars[0].finished
