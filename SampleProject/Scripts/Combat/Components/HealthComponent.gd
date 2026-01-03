## Компонент управління здоров'ям
## Використовується для розділення відповідальності (SOLID)
## Підвішується до CombatBody2D через сцену
extends Node
class_name HealthComponent

## Посилання на CombatBody2D (власник)
@export var owner_body: CombatBody2D

## Застосовує ушкодження до власника
## Викликається з DamageApplier
func apply_damage(damage: int, source: Node = null) -> void:
	if not owner_body:
		push_error("HealthComponent: owner_body is null")
		return
	
	if not owner_body.is_alive():
		return
	
	# Використовуємо IDamageable інтерфейс
	if IDamageable.is_implemented_by(owner_body):
		IDamageable.safe_take_damage(owner_body, damage, source)
	else:
		# Fallback для сумісності
		if owner_body.has_method("take_damage"):
			owner_body.take_damage(damage, source)

## Отримує поточне здоров'я
func get_current_health() -> int:
	if not owner_body:
		return 0
	return owner_body.get_current_health()

## Отримує максимальне здоров'я
func get_max_health() -> int:
	if not owner_body:
		return 0
	return owner_body.get_max_health()

## Перевіряє, чи власник живий
func is_alive() -> bool:
	if not owner_body:
		return false
	return owner_body.is_alive()

func _ready() -> void:
	# Автоматично знаходимо власника, якщо не встановлено
	if not owner_body:
		owner_body = get_parent() as CombatBody2D
		if not owner_body:
			push_error("HealthComponent: Parent is not CombatBody2D")
