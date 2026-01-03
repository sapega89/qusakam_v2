extends RefCounted
class_name GameplayServiceRegistry

## 🎮 GameplayServiceRegistry - Реестр геймплейных сервисов
## Управляет персонажами, инвентарем, диалогами и состоянием игры

var character_manager: Node = null
var equipment_manager: Node = null
var player_state_manager: Node = null
var enemy_state_manager: Node = null
var inventory_manager: Node = null
var dialogue_manager: Node = null
var xp_manager: Node = null
var _is_registered: bool = false

func register(game_manager: Node) -> void:
	"""Регистрирует геймплейные сервисы из GameManager"""
	if _is_registered:
		return  # Уже зарегистрировано, пропускаем

	if not game_manager:
		push_error("❌ GameplayServiceRegistry: GameManager is null!")
		return

	_is_registered = true

	character_manager = game_manager.get_node_or_null("CharacterManager")
	equipment_manager = game_manager.get_node_or_null("EquipmentManager")
	player_state_manager = game_manager.get_node_or_null("PlayerStateManager")
	enemy_state_manager = game_manager.get_node_or_null("EnemyStateManager")
	inventory_manager = game_manager.get_node_or_null("InventoryManager")
	dialogue_manager = game_manager.get_node_or_null("DialogueManager")
	xp_manager = game_manager.get_node_or_null("XPManager")

	print("🎮 GameplayServiceRegistry: Registered gameplay services")
	_print_service_status("CharacterManager", character_manager)
	_print_service_status("EquipmentManager", equipment_manager)
	_print_service_status("PlayerStateManager", player_state_manager)
	_print_service_status("EnemyStateManager", enemy_state_manager)
	_print_service_status("InventoryManager", inventory_manager)
	_print_service_status("DialogueManager", dialogue_manager)
	_print_service_status("XPManager", xp_manager)

func _print_service_status(name: String, service: Node) -> void:
	"""Выводит статус сервиса"""
	if service:
		print("  ✅ ", name, " found")
	else:
		push_warning("  ⚠️ ", name, " not found")

# Getters
func get_character_manager() -> Node:
	return character_manager

func get_equipment_manager() -> Node:
	return equipment_manager

func get_player_state_manager() -> Node:
	return player_state_manager

func get_enemy_state_manager() -> Node:
	return enemy_state_manager

func get_inventory_manager() -> Node:
	return inventory_manager

func get_dialogue_manager() -> Node:
	return dialogue_manager

func get_xp_manager() -> Node:
	return xp_manager
