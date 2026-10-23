extends CharacterBody2D
class_name CombatBody2D

@export var Overide_Damage_Receiving: bool = false
@export var Starting_Health: int = 100
@export var Max_Health: int = 100
@export var is_invulnerable: bool = false
@export var invulnerability_duration: float = 0.5
## Нижче цього ушкодження здоровʼя не опускає (0 — звичайно, можна загинути). Навчальний бій (D-28c) ставить 1:
## лікування «нижче 40 %» приходить уже після удару, тож без підлоги фінішер з 45 % убивав би бандита посеред уроку.
var min_health: int = 0

var current_health: int
var is_dead: bool = false
var invulnerability_timer: float = 0.0

# Сигнали
signal damage_token(amount: int)
signal health_changed(new_health: int, max_health: int, animate: bool)
signal entity_died()
signal entity_revived()

func _ready() -> void:
	current_health = Starting_Health
	health_changed.emit(current_health, Max_Health, true)

func _process(delta: float) -> void:
	# Обробка невразливості
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			is_invulnerable = false

## Обробляє отримання ушкоджень, використовуйте take_damage() замість цього
## [param critical] — крит героя (D393): лише для цифри урону (DamageNumbers через EventBus.damage_received).
func register_damage(damage: int, ignore_overide: bool = false, critical: bool = false) -> void:
	# Перевірка невразливості
	if is_invulnerable and not ignore_overide:
		return

	# Перевірка смерті
	if is_dead and not ignore_overide:
		return

	if ignore_overide or (!Overide_Damage_Receiving and current_health > 0):
		var _old_health = current_health
		current_health = clampi(current_health - damage, mini(min_health, current_health), Max_Health)
		damage_token.emit(damage)
		health_changed.emit(current_health, Max_Health, true)

		# Емітуємо подію через EventBus
		var source = get_meta("last_damage_source", null) if has_meta("last_damage_source") else null
		EventBus.damage_received.emit(self, source, damage, critical)
		# Также эмитим damage_dealt когда источник наносит урон цели
		if source:
			EventBus.damage_dealt.emit(source, self, damage)
		if is_in_group(GameGroups.PLAYER):
			EventBus.player_health_changed.emit(current_health, Max_Health)
		elif is_in_group(GameGroups.ENEMIES):
			var enemy_id = name  # Використовуємо name замість get_enemy_id()
			EventBus.enemy_health_changed.emit(enemy_id, current_health, Max_Health)

		# Активація невразливості. Тривалість 0 (вороги) — без неї: таймер 0 ніколи не скинув би прапорець.
		if invulnerability_duration > 0.0:
			set_invulnerable(true, invulnerability_duration)

		# Перевірка смерті
		if current_health <= 0 and not is_dead:
			die()

## Реалізація IDamageable.take_damage()
func take_damage(damage: int, source: Node = null, critical: bool = false) -> void:
	# Зберігаємо джерело ушкоджень для EventBus. Без джерела (пастка, падіння) — скидаємо: інакше лишався
	# попередній кривдник, часто вже звільнений, і слухачі damage_received падали на ньому (звук, розтин).
	set_meta("last_damage_source", source)
	# B60: раніше тут було register_damage(damage, true) — обхід невразливості й перевірки смерті на кожному шляху ушкодження.
	register_damage(damage, false, critical)

func heal_damage(amount: int) -> void:
	if is_dead:
		return

	current_health = clampi(current_health + amount, 0, Max_Health)
	health_changed.emit(current_health, Max_Health, true)

func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0
	health_changed.emit(current_health, Max_Health, true)
	entity_died.emit()

	# Емітуємо подію через EventBus
	if is_in_group(GameGroups.PLAYER):
		EventBus.player_died.emit()
	elif is_in_group(GameGroups.ENEMIES):
		var enemy_id = name  # Використовуємо name замість get_enemy_id()
		EventBus.enemy_died.emit(enemy_id, global_position)

func revive(health_amount: int = -1) -> void:
	# Перевіряємо, чи вже не воскрешений
	if not is_dead:
		return

	# Якщо передано конкретну кількість здоров'я, примусово відновлюємо
	if health_amount != -1:
		is_dead = false
		current_health = clampi(health_amount, 1, Max_Health)
		health_changed.emit(current_health, Max_Health, true)
		entity_revived.emit()
		return

	# Стандартна логіка воскресіння тільки для мертвих
	is_dead = false
	current_health = Max_Health
	health_changed.emit(current_health, Max_Health, true)
	entity_revived.emit()

func get_health_percentage() -> float:
	return float(current_health) / float(Max_Health) if Max_Health > 0 else 0.0

## Реалізація IDamageable.is_alive()
func is_alive() -> bool:
	return not is_dead and current_health > 0

## Реалізація IDamageable.get_current_health()
func get_current_health() -> int:
	return current_health

## Реалізація IDamageable.get_max_health()
func get_max_health() -> int:
	return Max_Health

func set_invulnerable(active: bool, duration: float = 0.0) -> void:
	"""Вмикає/вимикає невразливість. Якщо duration > 0, вона автоматично вимкнеться."""
	is_invulnerable = active
	if active and duration > 0:
		invulnerability_timer = duration
	elif not active:
		invulnerability_timer = 0.0


## D443: тіла героя й ворогів зупиняють одне одного (крізь ворога — лише перекат, PlayerMover), але ніхто не стоїть
## на чужій голові: тіло, що лежить на іншому бійцеві, зісковзує вбік від його центру зі SLIDE_OFF_SPEED, доки не впаде.
## Шлях убік закритий (стіна, герой поруч) — зсуває того, хто внизу, в інший бік. Кличуть після move_and_slide() герой (PlayerMover) і кожен ворог
## (DefaultEnemy, отже й боси) — одне правило для всіх (B125).
## Бійці — не платформи (platform_floor_layers = 0 у Player.tscn і default_enemy.tscn): хто стоїть на іншому, не їде
## з ним і не отримує його швидкість, коли той зникає з-під ніг. Рухомих платформ у грі немає.
const SLIDE_OFF_SPEED := 240.0
## Наскільки нижче ніг шукати тіло під собою, px.
const STANDING_PROBE := 2.0

func slide_off_bodies(delta: float) -> void:
	var under := KinematicCollision2D.new()
	if not test_move(global_transform, Vector2(0, STANDING_PROBE), under) or not under.get_collider() is CombatBody2D:
		return
	if under.get_normal().y > -0.5:
		return  # торкається боком, а не стоїть зверху
	var other: CombatBody2D = under.get_collider()
	var away := 1.0 if global_position.x >= other.global_position.x else -1.0
	var step := Vector2(away * SLIDE_OFF_SPEED * delta, 0)
	if move_and_collide(step) != null:
		other.move_and_collide(-step)


## Габарит тіла (CollisionShape2D, прямокутник) у світових координатах.
func body_rect() -> Rect2:
	var collision: CollisionShape2D = get_node(^"CollisionShape2D")
	var size: Vector2 = collision.shape.get_rect().size * global_scale
	return Rect2(collision.global_position - size / 2.0, size)
