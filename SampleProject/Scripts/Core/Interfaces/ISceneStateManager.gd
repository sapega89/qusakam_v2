## 🔄 ISceneStateManager - Інтерфейс для управління стейтами сцен
## Використовується для уніфікованого доступу до стейт-менеджерів різних сцен
## Дотримується принципу Interface Segregation Principle

class_name ISceneStateManager
extends RefCounted

## Перевіряє, чи реалізує нода інтерфейс ISceneStateManager
static func is_implemented_by(node: Node) -> bool:
	if not node:
		return false
	
	# Перевіряємо наявність основних методів
	return node.has_method("get_current_state_name") and \
		   node.has_method("change_state_by_name")

## Безпечно отримує назву поточного стейту
static func safe_get_current_state_name(node: Node) -> String:
	if not is_implemented_by(node):
		return "UNKNOWN"
	
	return node.get_current_state_name()

## Безпечно змінює стейт за назвою
static func safe_change_state_by_name(node: Node, state_name: String) -> bool:
	if not is_implemented_by(node):
		DebugLogger.warning("ISceneStateManager: Node не реалізує інтерфейс: %s" % node.name, "ISceneStateManager")
		return false
	
	if not node.has_method("change_state_by_name"):
		DebugLogger.warning("ISceneStateManager: Node не має методу change_state_by_name: %s" % node.name, "ISceneStateManager")
		return false
	
	node.change_state_by_name(state_name)
	return true

## Знаходить стейт-менеджер в сцені
static func find_state_manager_in_scene(scene: Node) -> Node:
	if not scene:
		return null
	
	# Перевіряємо саму сцену
	if is_implemented_by(scene):
		return scene
	
	# Шукаємо в дочірніх вузлах
	for child in scene.get_children():
		if is_implemented_by(child):
			return child
		
		# Рекурсивний пошук (один рівень глибини)
		for grandchild in child.get_children():
			if is_implemented_by(grandchild):
				return grandchild
	
	return null
