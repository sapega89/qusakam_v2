## Інтерфейс для об'єктів, які можуть отримувати ушкодження
## Використовується для розділення відповідальностей (SOLID)
## В Godot 4.5 інтерфейси реалізуються через duck typing зі статичними методами
class_name IDamageable

## Перевіряє, чи об'єкт реалізує інтерфейс IDamageable
static func is_implemented_by(node: Node) -> bool:
	return node.has_method("take_damage") and \
		   node.has_method("is_alive") and \
		   node.has_method("get_current_health") and \
		   node.has_method("get_max_health")

## Безпечно викликає take_damage на об'єкті
static func safe_take_damage(node: Node, damage: int, source: Node = null) -> void:
	if is_implemented_by(node):
		node.take_damage(damage, source)
	else:
		push_error("Node " + str(node) + " does not implement IDamageable")

## Безпечно перевіряє, чи об'єкт живий
static func safe_is_alive(node: Node) -> bool:
	if is_implemented_by(node):
		return node.is_alive()
	return false

## Безпечно отримує поточне здоров'я
static func safe_get_current_health(node: Node) -> int:
	if is_implemented_by(node):
		return node.get_current_health()
	return 0

## Безпечно отримує максимальне здоров'я
static func safe_get_max_health(node: Node) -> int:
	if is_implemented_by(node):
		return node.get_max_health()
	return 0

