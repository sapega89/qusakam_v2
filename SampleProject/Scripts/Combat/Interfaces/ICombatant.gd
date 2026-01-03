## Інтерфейс для бойових сутностей (комбінація IDamageable та IDamageDealer)
## Використовується для розділення відповідальностей (SOLID)
## В Godot 4.5 інтерфейси реалізуються через duck typing зі статичними методами
class_name ICombatant

## Перевіряє, чи об'єкт реалізує інтерфейс ICombatant
static func is_implemented_by(node: Node) -> bool:
	return IDamageable.is_implemented_by(node) and \
		   IDamageDealer.is_implemented_by(node)

## Безпечно викликає take_damage на об'єкті
static func safe_take_damage(node: Node, damage: int, source: Node = null) -> void:
	IDamageable.safe_take_damage(node, damage, source)

## Безпечно викликає deal_damage на об'єкті
static func safe_deal_damage(node: Node, target: Node, damage: int) -> void:
	IDamageDealer.safe_deal_damage(node, target, damage)

## Безпечно перевіряє, чи об'єкт живий
static func safe_is_alive(node: Node) -> bool:
	return IDamageable.safe_is_alive(node)

## Безпечно отримує поточне здоров'я
static func safe_get_current_health(node: Node) -> int:
	return IDamageable.safe_get_current_health(node)

## Безпечно отримує максимальне здоров'я
static func safe_get_max_health(node: Node) -> int:
	return IDamageable.safe_get_max_health(node)

## Безпечно отримує базові ушкодження
static func safe_get_base_damage(node: Node) -> int:
	return IDamageDealer.safe_get_base_damage(node)

## Безпечно отримує поточні ушкодження
static func safe_get_current_damage(node: Node) -> int:
	return IDamageDealer.safe_get_current_damage(node)

