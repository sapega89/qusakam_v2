extends RefCounted
class_name GameplayServiceRegistry

## 🎮 GameplayServiceRegistry - Реестр геймплейных сервисов
## Управляет персонажами, инвентарем, диалогами и состоянием игры

var character_manager: Node = null
var equipment_manager: Node = null
var player_state_manager: Node = null
var inventory_manager: Node = null
var dialogue_manager: Node = null
var xp_manager: Node = null
var skill_manager: Node = null
var game_flow: Node = null
var companion_manager: Node = null
var _is_registered: bool = false

func register(game_manager: Node) -> void:
	"""Регистрирует геймплейные сервисы из GameManager"""
	if _is_registered:
		return  # Уже зарегистрировано, пропускаем

	if not game_manager:
		push_error("❌ GameplayServiceRegistry: GameManager is null!")
		return

	_is_registered = true

	character_manager = game_manager.get_node("CharacterManager")
	equipment_manager = game_manager.get_node("EquipmentManager")
	player_state_manager = game_manager.get_node("PlayerStateManager")
	inventory_manager = game_manager.get_node("InventoryManager")
	dialogue_manager = game_manager.get_node("DialogueManager")
	xp_manager = game_manager.get_node("XPManager")
	skill_manager = game_manager.get_node("SkillManager")
	game_flow = game_manager.get_node("GameFlow")
	companion_manager = game_manager.get_node("CompanionManager")

	print("🎮 GameplayServiceRegistry: Registered gameplay services")
	_print_service_status("CharacterManager", character_manager)
	_print_service_status("EquipmentManager", equipment_manager)
	_print_service_status("PlayerStateManager", player_state_manager)
	_print_service_status("InventoryManager", inventory_manager)
	_print_service_status("DialogueManager", dialogue_manager)
	_print_service_status("XPManager", xp_manager)
	_print_service_status("SkillManager", skill_manager)
	_print_service_status("GameFlow", game_flow)
	_print_service_status("CompanionManager", companion_manager)

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

func get_inventory_manager() -> Node:
	return inventory_manager

func get_dialogue_manager() -> Node:
	return dialogue_manager

func get_xp_manager() -> Node:
	return xp_manager

func get_game_flow() -> Node:
	return game_flow

func get_companion_manager() -> Node:
	return companion_manager

func get_skill_manager() -> Node:
	return skill_manager
