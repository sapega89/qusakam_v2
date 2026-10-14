extends RefCounted
class_name CoreServiceRegistry

## 🔧 CoreServiceRegistry - Реестр основных системных сервисов
## Управляет GameManager и SaveSystem

var game_manager: Node = null
var save_system: Node = null
var _is_registered: bool = false

func register() -> void:
	"""Регистрирует основные сервисы из autoload"""
	if _is_registered:
		return  # Уже зарегистрировано, пропускаем

	_is_registered = true
	game_manager = _find_autoload("GameManager")
	save_system = _find_autoload("SaveSystem")

	print("🔧 CoreServiceRegistry: Registered core services")
	if game_manager:
		print("  ✅ GameManager found")
	else:
		push_warning("  ⚠️ GameManager not found")

	if save_system:
		print("  ✅ SaveSystem found")
	else:
		push_warning("  ⚠️ SaveSystem not found")

func _find_autoload(autoload_name: String) -> Node:
	"""Находит autoload по имени через scene tree"""
	return Engine.get_main_loop().root.get_node("/root/" + autoload_name)

# Getters
func get_game_manager() -> Node:
	return game_manager

func get_save_system() -> Node:
	return save_system
