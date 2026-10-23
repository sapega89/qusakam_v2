## Компонент застосування ушкоджень
## Висить на Hitbox (Area2D) та застосовує ушкодження до цілей
## Використовує HealthComponent цілі для застосування ушкоджень
extends Node
class_name DamageApplier

## Посилання на Hitbox (Area2D)
@export var hitbox: Area2D

## Посилання на власника (Node, який атакує)
@export var owner_body: Node

## Група цілей (напр. &"player" для ворога). Порожньо — будь-яке тіло зі здоровʼям.
@export var target_group: StringName = &""

## Базові ушкодження
@export var base_damage: int = 10

## Поточні ушкодження (з урахуванням бонусів)
var current_damage: int = 10

## Удар — крит (D393; ставить PlayerCombat), ціль показує більшу цифру.
var critical: bool = false
## Частка, на яку удар сильніший по збитому ворогу (D592, Breaker's Ring); ставить PlayerCombat на кожен удар.
var staggered_bonus: float = 0.0

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
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	
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

	# Ворог не бʼє сусіднього ворога
	if target_group != &"" and not body.is_in_group(target_group):
		return
	
	# Перевіряємо, чи ця ціль вже отримала ушкодження
	if body in hit_targets:
		return
	
	# Шукаємо HealthComponent у цілі
	var health_component = _find_health_component(body)
	
	# D592: по збитому ворогу удар сильніший на staggered_bonus (оберіг Breaker's Ring)
	var amount := current_damage
	if staggered_bonus > 0.0 and body is DefaultEnemy and body.is_staggered():
		amount = roundi(amount * (1.0 + staggered_bonus))
	if health_component:
		# Застосовуємо ушкодження через HealthComponent
		health_component.apply_damage(amount, owner_body, critical)
	elif IDamageable.is_implemented_by(body):
		# Гравець — CombatBody2D без HealthComponent: шкода напряму.
		IDamageable.safe_take_damage(body, amount, owner_body, critical)
	else:
		# Тіло без здоровʼя (стіна, тригер) — не ціль.
		return
	
	# Додаємо до списку вже вражених цілей
	hit_targets.append(body)
	
	# Емітуємо сигнал
	damage_applied.emit(body, amount)

## Зона-ціль ворога (B128): удар по ній — удар по самому ворогу (hit_targets не дасть влучити двічі).
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group(GameGroups.HURTBOX):
		_on_hitbox_body_entered(area.get_parent())

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
