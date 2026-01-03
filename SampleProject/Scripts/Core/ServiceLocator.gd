extends Node

## 🔌 ServiceLocator - Сервис-локатор для внедрения зависимостей
## Предоставляет централизованный доступ к менеджерам и сервисам через категоризированные реестры
## Согласно DIP и Single Responsibility Principle
## РЕФАКТОРИНГ ЭТАП 3.1: Разделен на 5 ServiceRegistry категорий

# Singleton instance (для обратной совместимости)
static var instance: Node = null

# Service Registries (категоризация сервисов) - lazy initialization
var core: CoreServiceRegistry = null
var ui: UIServiceRegistry = null
var gameplay: GameplayServiceRegistry = null
var systems: SystemServiceRegistry = null
var data: DataServiceRegistry = null

# Временная ссылка на GameManager для регистрации
var _game_manager: Node = null
var _registration_retry_count: int = 0
const MAX_REGISTRATION_RETRIES: int = 10

func _ready() -> void:
	"""Инициализация ServiceLocator с Registry подсистемой"""
	instance = self  # Для обратной совместимости

	# Создаем Registry instances
	core = CoreServiceRegistry.new()
	ui = UIServiceRegistry.new()
	gameplay = GameplayServiceRegistry.new()
	systems = SystemServiceRegistry.new()
	data = DataServiceRegistry.new()

	# Отложенная регистрация всех сервисов (включая Core)
	# Это гарантирует, что GameManager успел создать все менеджеры
	call_deferred("_register_all_registries")

	print("🔌 ServiceLocator: Initialized with ServiceRegistry architecture")

func _register_all_registries() -> void:
	"""Регистрирует все категории сервисов через Registry классы"""
	# Регистрируем Core сервисы (GameManager, SaveSystem)
	core.register()
	_game_manager = core.get_game_manager()

	# Если GameManager еще не найден, пытаемся еще раз
	if not _game_manager:
		_registration_retry_count += 1
		if _registration_retry_count >= MAX_REGISTRATION_RETRIES:
			push_error("ServiceLocator: GameManager not found after ", MAX_REGISTRATION_RETRIES, " retries!")
			return

		push_warning("ServiceLocator: GameManager not found, deferring registry registration (attempt ", _registration_retry_count, "/", MAX_REGISTRATION_RETRIES, ")")
		call_deferred("_register_all_registries")
		return

	# Регистрируем UI сервисы
	ui.register(_game_manager)

	# Регистрируем геймплейные сервисы
	gameplay.register(_game_manager)

	# Регистрируем системные сервисы
	systems.register(_game_manager)

	# Регистрируем сервисы данных
	data.register(_game_manager)

	print("🔌 ServiceLocator: All service registries initialized successfully")

## DEPRECATED: Старые методы регистрации (для обратной совместимости)
## Эти методы больше не используются - вся логика перенесена в ServiceRegistry классы
func _register_autoload_services() -> void:
	"""DEPRECATED: Используйте core.register() вместо этого"""
	push_warning("ServiceLocator._register_autoload_services() is deprecated - use core.register()")

func _register_managers() -> void:
	"""DEPRECATED: Используйте _register_all_registries() вместо этого"""
	push_warning("ServiceLocator._register_managers() is deprecated - use _register_all_registries()")

## ============================================================================
## GETTERS - Делегируют вызовы к соответствующим ServiceRegistry
## Сохраняют обратную совместимость с существующим кодом
## ============================================================================

## Core Services
func get_game_manager() -> Node:
	"""Получает GameManager из CoreServiceRegistry"""
	if not core:
		push_error("ServiceLocator: CoreServiceRegistry not initialized!")
		return null
	return core.get_game_manager()

func get_save_system() -> Node:
	"""Получает SaveSystem из CoreServiceRegistry"""
	if not core:
		push_error("ServiceLocator: CoreServiceRegistry not initialized!")
		return null
	return core.get_save_system()

## UI Services
func get_ui_manager() -> UIManager:
	"""Получает UIManager из UIServiceRegistry"""
	return ui.get_ui_manager()

func get_ui_update_manager() -> UIUpdateManager:
	"""Получает UIUpdateManager из UIServiceRegistry"""
	return ui.get_ui_update_manager()

func get_menu_manager() -> MenuManager:
	"""Получает MenuManager из UIServiceRegistry"""
	return ui.get_menu_manager()

func get_display_manager() -> Node:
	"""Получает DisplayManager из UIServiceRegistry"""
	return ui.get_display_manager()

## Gameplay Services
func get_character_manager() -> CharacterManager:
	"""Получает CharacterManager из GameplayServiceRegistry"""
	return gameplay.get_character_manager()

func get_equipment_manager() -> EquipmentManager:
	"""Получает EquipmentManager из GameplayServiceRegistry"""
	return gameplay.get_equipment_manager()

func get_player_state_manager() -> PlayerStateManager:
	"""Получает PlayerStateManager из GameplayServiceRegistry"""
	return gameplay.get_player_state_manager()

func get_enemy_state_manager() -> EnemyStateManager:
	"""Получает EnemyStateManager из GameplayServiceRegistry"""
	return gameplay.get_enemy_state_manager()

func get_inventory_manager() -> InventoryManager:
	"""Получает InventoryManager из GameplayServiceRegistry"""
	return gameplay.get_inventory_manager()

func get_dialogue_manager() -> GameDialogueManager:
	"""Получает DialogueManager из GameplayServiceRegistry"""
	return gameplay.get_dialogue_manager()

func get_xp_manager() -> XPManager:
	"""Получает XPManager из GameplayServiceRegistry"""
	return gameplay.get_xp_manager()

## System Services
func get_time_manager() -> TimeManager:
	"""Получает TimeManager из SystemServiceRegistry"""
	return systems.get_time_manager()

func get_audio_manager() -> Node:
	"""Получает AudioManager из SystemServiceRegistry"""
	return systems.get_audio_manager()

func get_music_manager() -> Node:
	"""Получает MusicManager из SystemServiceRegistry"""
	return systems.get_music_manager()

func get_debug_manager() -> Node:
	"""Получает DebugManager из SystemServiceRegistry"""
	return systems.get_debug_manager()

func get_scene_manager() -> SceneManager:
	"""Получает SceneManager из SystemServiceRegistry"""
	return systems.get_scene_manager()

## Data Services
func get_item_database() -> Node:
	"""Получает ItemDatabase из DataServiceRegistry"""
	return data.get_item_database()

func get_settings_manager() -> Node:
	"""Получает SettingsManager из DataServiceRegistry"""
	return data.get_settings_manager()

func get_localization_manager() -> GameLocalizationManager:
	"""Получает LocalizationManager из DataServiceRegistry"""
	return data.get_localization_manager()

## Special/Legacy Services
func get_dialogue_quest() -> Variant:
	"""Получает DialogueQuest singleton (legacy support)"""
	if Engine.has_singleton("DialogueQuest"):
		return Engine.get_singleton("DialogueQuest")
	push_warning("ServiceLocator: DialogueQuest singleton not found")
	return null
