extends RefCounted
class_name ServiceLocatorHelper

## Вспомогательный класс для безопасного доступа к ServiceLocator
## Используется когда ServiceLocator может быть еще не загружен

static func get_service_locator() -> Node:
	"""Безопасно получает ServiceLocator singleton

	ВАЖНО: автозагрузки Godot 4 НЕ регистрируются в Engine-синглтонах —
	они живут как узлы в /root. Поэтому Engine.has_singleton("ServiceLocator")
	всегда возвращает false, и раньше этот метод всегда отдавал null.
	Из-за этого у всех наследников BaseMenuComponent game_manager был пустым.
	"""
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		if tree.root:
			var locator := tree.root.get_node_or_null(^"ServiceLocator")
			if locator:
				return locator
	# Запасной путь на случай, если ServiceLocator всё же зарегистрируют синглтоном.
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator")
	return null

static func get_manager(method_name: String) -> Variant:
	"""Безопасно получает менеджер через ServiceLocator"""
	var service_locator = get_service_locator()
	if service_locator and service_locator.has_method(method_name):
		return service_locator.call(method_name)
	return null

