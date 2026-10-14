extends RefCounted
class_name ServiceLocatorHelper

## Доступ до ServiceLocator зі статичного коду (RefCounted, Resource),
## де autoload-імʼя `ServiceLocator` недоступне.
## Автозавантаження Godot 4 — вузли в /root, а не Engine-синглтони (B43, B50).

static func get_service_locator() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"ServiceLocator")

static func get_manager(method_name: String) -> Variant:
	return get_service_locator().call(method_name)
