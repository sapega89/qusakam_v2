## Компонент застосування ушкоджень
## Висить на Hitbox (Area2D) та застосовує ушкодження до цілей
## Використовує HealthComponent цілі для застосування ушкоджень
extends Node
class_name DamageApplier

## Посилання на Hitbox (Area2D)
@export var hitbox: Area2D

## Посилання на власника (Node, який атакує)
@export var owner_body: Node

## Базові ушкодження
@export var base_damage: int = 10

## Поточні ушкодження (з урахуванням бонусів)
var current_damage: int = 10

## Чи активний компонент (для контролю через анімації)
var is_active: bool = false

## Список цілей, які вже отримали ушкодження в цій атаці
var hit_targets: Array[Node] = []

## Сигнал успішного попадання
signal damage_applied(target: Node, damage: int)

func _ready() -> void:
	# Автоматично знаходимо Hitbox, якщо не встановлено
	if not hitbox:
		hitbox = get_parent() as Area2D
		if not hitbox:
			push_error("DamageApplier: Parent is not Area2D")
	
	# Автоматично знаходимо власника
	if not owner_body:
		owner_body = get_parent().get_parent() as CombatBody2D
		if not owner_body:
			# Спробуємо знайти через групу
			var owner_node = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
			if not owner_node:
				owner_node = GameGroups.get_first_node_in_group(GameGroups.ENEMIES)
			if owner_node and owner_node is CombatBody2D:
				owner_body = owner_node
	
	# Підключаємося до сигналів Hitbox
	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Ініціалізуємо поточні ушкодження
	current_damage = base_damage
	
	# Отримуємо ушкодження з власника, якщо він реалізує IDamageDealer
	if owner_body and IDamageDealer.is_implemented_by(owner_body):
		current_damage = IDamageDealer.safe_get_current_damage(owner_body)

## Увімкнути застосування ушкоджень (викликається з анімації)
func enable_damage() -> void:
	is_active = true
	hit_targets.clear()

## Вимкнути застосування ушкоджень (викликається з анімації)
func disable_damage() -> void:
	is_active = false
	hit_targets.clear()

## Обробник входження тіла в Hitbox
func _on_hitbox_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	
	if not body:
		return
	
	# Не атакуємо себе
	if body == owner_body:
		return
	
	# Перевіряємо, чи ця ціль вже отримала ушкодження
	if body in hit_targets:
		return
	
	# Шукаємо HealthComponent у цілі
	var health_component = _find_health_component(body)
	
	if health_component:
		# Застосовуємо ушкодження через HealthComponent
		health_component.apply_damage(current_damage, owner_body)
	elif IDamageable.is_implemented_by(body):
		# Fallback: використовуємо IDamageable напряму
		IDamageable.safe_take_damage(body, current_damage, owner_body)
	else:
		# Якщо нічого не знайдено, пропускаємо
		return
	
	# Додаємо до списку вже вражених цілей
	hit_targets.append(body)
	
	# Емітуємо сигнал
	damage_applied.emit(body, current_damage)

## Знаходить HealthComponent у цілі
func _find_health_component(target: Node) -> HealthComponent:
	# Спочатку перевіряємо, чи є HealthComponent як дочірній ноду
	for child in target.get_children():
		if child is HealthComponent:
			return child
	
	# Якщо не знайдено, перевіряємо батьківський ноду (якщо target - це Area2D)
	if target.get_parent():
		for child in target.get_parent().get_children():
			if child is HealthComponent:
				return child
	
	# Якщо target сам є CombatBody2D, шукаємо HealthComponent у нього
	if target is CombatBody2D:
		for child in target.get_children():
			if child is HealthComponent:
				return child
	
	return null

## Оновлює поточні ушкодження (викликається при зміні статів)
func update_damage() -> void:
	if owner_body and IDamageDealer.is_implemented_by(owner_body):
		current_damage = IDamageDealer.safe_get_current_damage(owner_body)
	else:
		current_damage = base_damage
