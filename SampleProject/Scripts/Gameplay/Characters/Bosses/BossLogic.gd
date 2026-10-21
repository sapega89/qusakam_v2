extends EnemyLogic

## Ходи боса (D301, D302, design/lab_boss_plan.md): з moves боса обирається один хід, у чию дальність зараз
## потрапляє герой, — випадково за вагою. combo — спільна серія ударів хітбоксом (D265); інші — свої:
##   charge   — ривок на distance px з живим хітбоксом;
##   slam     — ударна хвиля по підлозі на radius px в обидва боки, героя в повітрі не зачіпає;
##   fireball — вогняна куля на висоті героя (у другій фазі — count штук поспіль);
##   pillar   — мітка на підлозі під героєм, потім стовп вогню width px (у другій фазі — ще по одному обабіч, side px).
## Після свого ходу бос recovery с стоїть у позі удару — вікно для відповіді героя.
## Замах будь-якого ходу — як у звичайних ворогів: спершу стежить за героєм, далі напрямок зафіксовано; збій (D264)
## його зриває, оглушення — ні (броня боса). Шкода — через Player.take_damage(…, бос): блок, парирування, перекат
## і збій героя працюють як з усіма.

const FIREBALL := preload("res://SampleProject/Scenes/FX/Bosses/boss_fireball.tscn")
const PILLAR := preload("res://SampleProject/Scenes/FX/Bosses/boss_pillar.tscn")
const SHOCKWAVE := preload("res://SampleProject/Scenes/FX/Bosses/boss_shockwave.tscn")

## Герой на тій самій підлозі, що й бос: різниця центрів тіл не більша (інакше він на іншому поверсі чи в стрибку).
const SAME_FLOOR := 120.0
const CHARGE_TIME := 0.45
const FIREBALL_GAP := 0.35

## Останній обраний хід — для тестів і журналу.
var last_move: Dictionary = {}


func perform_attack() -> void:
	var move := pick_move()
	last_move = move
	if move.kind == "combo":
		await super.perform_attack()
		_rest()
		return
	is_attacking = true
	attack_broken = false
	winding_up = true
	attack_started.emit()
	EventBus.attack_started.emit(enemy, player)
	enemy.telegraph(move)
	var windup: float = move.windup * enemy.windup_scale
	await get_tree().create_timer(windup * TRACK_PART).timeout
	winding_up = false
	await get_tree().create_timer(windup * (1.0 - TRACK_PART)).timeout
	if not (enemy.is_dead or stun_left > 0.0 or attack_broken):
		enemy.strike(move)
		match move.kind:
			"charge": await _charge(move)
			"slam": _slam(move)
			"fireball": await _fireballs(move)
			"pillar": await _pillars(move)
			_: assert(false, "BossLogic: unknown move kind %s" % move.kind)
		# Відновлення: бос стоїть у позі удару — вікно для відповіді героя (D265).
		await get_tree().create_timer(float(move.recovery)).timeout
	is_attacking = false
	_rest()
	attack_ended.emit()
	_decide_after_attack()


## Перерва attack_cooldown рахується від кінця ходу, а не від замаху: довгий замах боса інакше з'їдав би
## всю перерву, і новий хід починався б одразу після удару — героєві ніколи бити у відповідь.
func _rest() -> void:
	last_attack_time = Time.get_ticks_msec() / 1000.0


## Хід для поточної відстані до героя й фази боса, випадково за вагою.
func pick_move() -> Dictionary:
	var dx := absf(player.global_position.x - enemy.global_position.x)
	var fits: Array[Dictionary] = []
	var total := 0.0
	for move: Dictionary in enemy.moves:
		if dx >= move.get("min_range", 0.0) and dx <= move.get("max_range", INF) and enemy.phase >= move.get("phase", 1):
			fits.append(move)
			total += move.get("weight", 1.0)
	assert(not fits.is_empty(), "BossLogic: %s has no move for %.0f px" % [enemy.name, dx])
	var roll := randf() * total
	for move in fits:
		roll -= move.get("weight", 1.0)
		if roll <= 0.0:
			return move
	return fits[-1]


func _damage(move: Dictionary) -> int:
	return roundi(enemy.damage * move.get("damage", 1.0))


func _charge(move: Dictionary) -> void:
	var direction := last_direction if last_direction != 0 else 1
	enemy.damage = enemy.base_damage * move.get("damage", 1.0)  # хітбокс бере шкоду з enemy.damage
	enemy.start_attack(direction)
	start_knockback(direction * float(move.distance), false, CHARGE_TIME)
	await get_tree().create_timer(CHARGE_TIME).timeout
	enemy.end_attack()
	enemy.damage = enemy.base_damage


func _slam(move: Dictionary) -> void:
	var wave: Node2D = SHOCKWAVE.instantiate()
	wave.radius = move.radius
	enemy.get_parent().add_child(wave)
	wave.global_position = enemy.global_position
	var hero: Node2D = player
	var grounded: bool = hero.is_on_floor() and absf(hero.global_position.y - enemy.global_position.y) <= SAME_FLOOR
	if grounded and absf(hero.global_position.x - enemy.global_position.x) <= float(move.radius):
		hero.take_damage(_damage(move), enemy)


func _fireballs(move: Dictionary) -> void:
	var count: int = move.get("count_phase2", 1) if enemy.phase >= 2 else 1
	for i in count:
		if enemy.is_dead or attack_broken:
			return
		var ball: Area2D = FIREBALL.instantiate()
		ball.direction = last_direction if last_direction != 0 else 1
		ball.damage = _damage(move)
		ball.source = enemy
		enemy.get_parent().add_child(ball)
		ball.global_position = Vector2(enemy.global_position.x + ball.direction * enemy.melee_reach * 0.5, player.global_position.y - 24.0)
		if i < count - 1:
			await get_tree().create_timer(FIREBALL_GAP).timeout


func _pillars(move: Dictionary) -> void:
	var xs: Array[float] = [player.global_position.x]
	if enemy.phase >= 2:
		xs.append_array([xs[0] - float(move.side), xs[0] + float(move.side)])
	var pillars: Array[Node2D] = []
	for x in xs:
		var pillar: Node2D = PILLAR.instantiate()
		pillar.width = move.width
		pillar.damage = _damage(move)
		pillar.source = enemy
		enemy.get_parent().add_child(pillar)
		pillar.global_position = Vector2(x, enemy.global_position.y)
		pillars.append(pillar)
	await pillars[0].finished
