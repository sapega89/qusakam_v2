extends Node
class_name SaveModule

## 💾 SaveModule - Базовый класс для всех модулей сохранения
## Определяет интерфейс, который должен реализовать каждый модуль

## Имя модуля (для логирования)
var module_name: String = "SaveModule"

## Сохраняет данные модуля и возвращает Dictionary для сериализации
func save() -> Dictionary:
	push_error("SaveModule: save() must be overridden in %s" % get_script().resource_path)
	return {}

## Загружает данные модуля из Dictionary
func load_data(_data: Dictionary) -> void:
	push_error("SaveModule: load_data() must be overridden in %s" % get_script().resource_path)

func log_info(message: String) -> void:
	print("💾 [%s] %s" % [module_name, message])

func log_warning(message: String) -> void:
	push_warning("⚠️ [%s] %s" % [module_name, message])

func log_error(message: String) -> void:
	push_error("❌ [%s] %s" % [module_name, message])
