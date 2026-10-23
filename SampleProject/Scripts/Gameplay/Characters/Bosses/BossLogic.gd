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

## Останній обраний хід — для тестів і журналу.
var last_move: Dictionary = {}
## Хід combo, що зараз іде (його серія й відновлення), — не last_move: той можуть перезаписати посеред серії.
var _combo: Dictionary = {}
## Місце в черзі візерунка й фаза, для якої вона йде.
var pattern_at := 0
var _pattern_phase := 1


func token_free() -> bool:
	return true


func _hold_token() -> void:
	pass


func handle_attack_state(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	if absf(dx) > attack_range * 1.2:
		change_state(AIState.CHASE)
		return
	_face_player()
	var toward := 1 if dx > 0.0 else -1
	if attack_ready_in <= 0.0:
		if _fits_any(absf(dx)):
			attack_ready_in = enemy.attack_cooldown
			perform_attack()
		else:
			_step(toward, speed)
		return
	var err: float = absf(dx) - enemy.preferred_range
	if absf(err) > PREFERRED_BAND:
		_step(toward if err > 0.0 else -toward, speed * REPOSITION_SPEED)
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
	_rest()
	attack_ended.emit()
	_decide_after_attack()


## Ковток (D564): бос стоїть у позі ковтка time с, як у відновленні (recovering), — героєві бити у відповідь.
func _drink(move: Dictionary) -> void:
	is_attacking = true
	attack_broken = false
	enemy.drink(move)
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
	attack_ready_in = enemy.attack_cooldown


func _fits(move: Dictionary, dx: float) -> bool:
	return dx >= move.get("min_range", 0.0) and dx <= move.get("max_range", INF) and enemy.phase >= move.get("phase", 1)


func _fits_any(dx: float) -> bool:
	return enemy.moves.any(func(m: Dictionary) -> bool: return _fits(m, dx))


## Хід за візерунком (D504): наступний у черзі kind, що підходить за відстанню й фазою і не повторює останній хід;
## повтор — лише коли інших немає. Нова фаза — черга спочатку. Нічого не підходить — {}.
func pick_move() -> Dictionary:
	if enemy.phase != _pattern_phase:
		_pattern_phase = enemy.phase
		pattern_at = 0
	var dx := absf(player.global_position.x - enemy.global_position.x)
	var pattern: PackedStringArray = enemy.pattern_phase2 if enemy.phase >= 2 and not enemy.pattern_phase2.is_empty() else enemy.pattern
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
