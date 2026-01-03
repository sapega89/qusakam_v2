## Інтерфейс для компаньйонів, які допомагають гравцю
## Використовується для розділення відповідальностей (SOLID)
## В Godot 4.5 інтерфейси реалізуються через duck typing зі статичними методами
class_name ICompanionAssist

## Перевіряє, чи об'єкт реалізує інтерфейс ICompanionAssist
static func is_implemented_by(node: Node) -> bool:
	return node.has_method("assist") and \
		   node.has_method("get_assist_type") and \
		   node.has_method("can_assist")

## Безпечно викликає допомогу компаньйона
static func safe_assist(companion: Node, target: Node) -> void:
	if is_implemented_by(companion):
		companion.assist(target)
	else:
		push_error("Node " + str(companion) + " does not implement ICompanionAssist")

## Безпечно отримує тип допомоги
static func safe_get_assist_type(companion: Node) -> String:
	if is_implemented_by(companion):
		return companion.get_assist_type()
	return ""

## Безпечно перевіряє, чи компаньйон готовий допомогти
static func safe_can_assist(companion: Node) -> bool:
	if is_implemented_by(companion):
		return companion.can_assist()
	return false

