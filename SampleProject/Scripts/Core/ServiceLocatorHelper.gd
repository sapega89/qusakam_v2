extends RefCounted
class_name ServiceLocatorHelper

## Вспомогательный класс для безопасного доступа к ServiceLocator
## Используется когда ServiceLocator может быть еще не загружен

static func get_service_locator() -> Node:
	"""Безопасно получает ServiceLocator singleton"""
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator")
	return null

static func get_manager(method_name: String) -> Variant:
	"""Безопасно получает менеджер через ServiceLocator"""
	var service_locator = get_service_locator()
	if service_locator and service_locator.has_method(method_name):
		return service_locator.call(method_name)
	return null

