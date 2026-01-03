extends CharacterBody2D
class_name CombatBody2D

@export var Overide_Damage_Receiving: bool = false
@export var Damage_Receiver: Node
@export var Starting_Health: int = 100
@export var Max_Health: int = 100
@export var is_invulnerable: bool = false
@export var invulnerability_duration: float = 0.5

var current_health: int
var is_dead: bool = false
var invulnerability_timer: float = 0.0

# Сигнали
signal damage_token(amount: int)
signal health_changed(new_health: int, max_health: int, animate: bool)
signal entity_died()
signal entity_revived()

func _ready() -> void:
	if Damage_Receiver and Damage_Receiver.has_signal("damage_received"):
		Damage_Receiver.damage_received.connect(register_damage)
	current_health = Starting_Health
	health_changed.emit(current_health, Max_Health, true)

func _process(delta: float) -> void:
	# Обробка невразливості
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			is_invulnerable = false

## Обробляє отримання ушкоджень, використовуйте take_damage() замість цього
func register_damage(damage: int, ignore_overide: bool = false) -> void:
	# Перевірка невразливості
	if is_invulnerable and not ignore_overide:
		return
		
	# Перевірка смерті
	if is_dead and not ignore_overide:
		return
		
	if ignore_overide or (!Overide_Damage_Receiving and current_health > 0):
		var _old_health = current_health
		current_health = clampi(current_health - damage, 0, Max_Health)
		damage_token.emit(damage)
		health_changed.emit(current_health, Max_Health, true)
		
		# Емітуємо подію через EventBus
		if Engine.has_singleton("EventBus"):
			var source = get_meta("last_damage_source", null) if has_meta("last_damage_source") else null
			EventBus.damage_received.emit(self, source, damage)
			# Также эмитим damage_dealt когда источник наносит урон цели
			if source:
				EventBus.damage_dealt.emit(source, self, damage)
			if is_in_group(GameGroups.PLAYER):
				EventBus.player_health_changed.emit(current_health, Max_Health)
			elif is_in_group(GameGroups.ENEMIES):
				var enemy_id = name  # Використовуємо name замість get_enemy_id()
				EventBus.enemy_health_changed.emit(enemy_id, current_health, Max_Health)
		
		# Активація невразливості
		if not is_invulnerable:
			is_invulnerable = true
			invulnerability_timer = invulnerability_duration
			
		# Перевірка смерті
		if current_health <= 0 and not is_dead:
			die()

## Реалізація IDamageable.take_damage()
func take_damage(damage: int, source: Node = null) -> void:
	# Зберігаємо джерело ушкоджень для EventBus
	if source:
		set_meta("last_damage_source", source)
	register_damage(damage, true)

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
	if Engine.has_singleton("EventBus"):
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

