## Інтерфейс для об'єктів, які можуть наносити ушкодження
## Використовується для розділення відповідальностей (SOLID)
## В Godot 4.5 інтерфейси реалізуються через duck typing зі статичними методами
class_name IDamageDealer

## Перевіряє, чи об'єкт реалізує інтерфейс IDamageDealer
static func is_implemented_by(node: Node) -> bool:
	return node.has_method("deal_damage") and \
		   node.has_method("get_base_damage") and \
		   node.has_method("get_current_damage")

## Безпечно викликає deal_damage на об'єкті
static func safe_deal_damage(node: Node, target: Node, damage: int) -> void:
	if is_implemented_by(node) and IDamageable.is_implemented_by(target):
		node.deal_damage(target, damage)
	else:
		push_error("Node " + str(node) + " does not implement IDamageDealer or target does not implement IDamageable")

## Безпечно отримує базові ушкодження
static func safe_get_base_damage(node: Node) -> int:
	if is_implemented_by(node):
		return node.get_base_damage()
	return 0

## Безпечно отримує поточні ушкодження
static func safe_get_current_damage(node: Node) -> int:
	if is_implemented_by(node):
		return node.get_current_damage()
	return 0

