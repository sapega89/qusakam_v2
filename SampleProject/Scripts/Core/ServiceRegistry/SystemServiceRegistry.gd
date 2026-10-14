extends RefCounted
class_name SystemServiceRegistry

## ⚙️ SystemServiceRegistry - Реестр системных сервисов
## Управляет временем, аудио, музыкой, отладкой и сценами

var time_manager: Node = null
var audio_manager: Node = null
var scene_manager: Node = null
var _is_registered: bool = false

func register(game_manager: Node) -> void:
	"""Регистрирует системные сервисы из GameManager и autoload"""
	if _is_registered:
		return  # Уже зарегистрировано, пропускаем

	if not game_manager:
		push_error("❌ SystemServiceRegistry: GameManager is null!")
		return

	_is_registered = true

	# Сервисы из GameManager
	time_manager = game_manager.get_node("TimeManager")
	scene_manager = game_manager.get_node("SceneManager")

	# Сервисы из autoload
	audio_manager = _find_autoload("AudioManager")

	print("⚙️ SystemServiceRegistry: Registered system services")
	_print_service_status("TimeManager", time_manager)
	_print_service_status("AudioManager", audio_manager)
	_print_service_status("SceneManager", scene_manager)

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
func get_time_manager() -> Node:
	return time_manager

func get_audio_manager() -> Node:
	return audio_manager

func get_scene_manager() -> Node:
	return scene_manager
