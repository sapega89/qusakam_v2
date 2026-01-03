extends RefCounted
class_name DataServiceRegistry

## 📊 DataServiceRegistry - Реестр сервисов данных
## Управляет базами данных, настройками и локализацией

var item_database: Node = null
var settings_manager: Node = null
var localization_manager: Node = null
var _is_registered: bool = false

func register(game_manager: Node) -> void:
	"""Регистрирует сервисы данных из GameManager и autoload"""
	if _is_registered:
		return  # Уже зарегистрировано, пропускаем

	_is_registered = true

	# Сервисы из GameManager
	if game_manager:
		settings_manager = game_manager.get_node_or_null("SettingsManager")

	# Сервисы из autoload
	item_database = _find_autoload("ItemDatabase")
	localization_manager = _find_autoload("LocalizationManager")

	print("📊 DataServiceRegistry: Registered data services")
	_print_service_status("ItemDatabase", item_database)
	_print_service_status("SettingsManager", settings_manager)
	_print_service_status("LocalizationManager", localization_manager)

func _find_autoload(autoload_name: String) -> Node:
	"""Находит autoload по имені через scene tree"""
	var autoload_path = "/root/" + autoload_name
	var node = Engine.get_main_loop().root.get_node_or_null(autoload_path)
	if not node:
		# Fallback: попробувати через Engine.get_singleton для старих autoload
		if Engine.has_singleton(autoload_name):
			node = Engine.get_singleton(autoload_name)
	return node

func _print_service_status(name: String, service: Node) -> void:
	"""Выводит статус сервиса"""
	if service:
		print("  ✅ ", name, " found")
	else:
		push_warning("  ⚠️ ", name, " not found")

# Getters
func get_item_database() -> Node:
	return item_database

func get_settings_manager() -> Node:
	return settings_manager

func get_localization_manager() -> Node:
	return localization_manager
