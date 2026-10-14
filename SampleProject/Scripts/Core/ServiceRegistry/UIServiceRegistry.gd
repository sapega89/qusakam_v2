extends RefCounted
class_name UIServiceRegistry

## 🖥️ UIServiceRegistry - Реестр UI сервисов
## Управляет всеми менеджерами интерфейса

var ui_manager: Node = null
var menu_manager: Node = null
var display_manager: Node = null
var _is_registered: bool = false

func register(game_manager: Node) -> void:
	"""Регистрирует UI сервисы из GameManager"""
	if _is_registered:
		return  # Уже зарегистрировано, пропускаем

	if not game_manager:
		push_error("❌ UIServiceRegistry: GameManager is null!")
		return

	_is_registered = true

	ui_manager = game_manager.get_node("UIManager")
	menu_manager = game_manager.get_node("MenuManager")
	display_manager = _find_autoload("DisplayManager")

	print("🖥️ UIServiceRegistry: Registered UI services")
	_print_service_status("UIManager", ui_manager)
	_print_service_status("MenuManager", menu_manager)
	_print_service_status("DisplayManager", display_manager)

func _find_autoload(autoload_name: String) -> Node:
	"""Находит autoload по имени через scene tree"""
	return Engine.get_main_loop().root.get_node("/root/" + autoload_name)

func _print_service_status(name: String, service: Node) -> void:
	"""Выводит статус сервиса"""
	if service:
		print("  ✅ ", name, " found")
	else:
		push_warning("  ⚠️ ", name, " not found")

# Getters
func get_ui_manager() -> Node:
	return ui_manager

func get_menu_manager() -> Node:
	return menu_manager

func get_display_manager() -> Node:
	return display_manager
