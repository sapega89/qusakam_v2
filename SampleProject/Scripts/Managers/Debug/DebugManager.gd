extends ManagerBase
class_name DebugManager

## 🐛 DebugManager - Управління дебаг-режимом
## Винесено з GameManager для розділення відповідальностей
## Дотримується принципу Single Responsibility

# Дебаг режим
var debug_mode_enabled: bool = false

# Сигнали
signal debug_mode_toggled(enabled: bool)
signal debug_command_executed(command: String, result: Dictionary)

func _initialize():
	"""Ініціалізація DebugManager"""
	print("🐛 DebugManager: Initialized")

func toggle_debug_mode() -> bool:
	"""Перемикає дебаг-режим"""
	debug_mode_enabled = not debug_mode_enabled
	debug_mode_toggled.emit(debug_mode_enabled)
	print("🐛 DebugManager: Debug mode toggled: ", debug_mode_enabled)
	return debug_mode_enabled

func set_debug_mode(enabled: bool):
	"""Встановлює дебаг-режим"""
	debug_mode_enabled = enabled
	debug_mode_toggled.emit(debug_mode_enabled)
	print("🐛 DebugManager: Debug mode set to: ", debug_mode_enabled)

func is_debug_mode_enabled() -> bool:
	"""Перевіряє, чи увімкнено дебаг-режим"""
	return debug_mode_enabled

func execute_debug_command(command: String, params: Dictionary = {}) -> Dictionary:
	"""Виконує дебаг-команду"""
	if not debug_mode_enabled:
		return {"success": false, "error": "Debug mode is disabled"}
	
	var result = {"success": false, "command": command}
	
	match command:
		"add_hp":
			var player = _get_player()
			if player and player.has_method("heal_damage"):
				var amount = params.get("amount", 10)
				player.heal_damage(amount)
				result = {"success": true, "message": "Added " + str(amount) + " HP"}
		
		"remove_hp":
			var player = _get_player()
			if player and player.has_method("take_damage"):
				var amount = params.get("amount", 10)
				player.take_damage(amount)
				result = {"success": true, "message": "Removed " + str(amount) + " HP"}
		
		"add_potion":
			if Engine.has_singleton("ServiceLocator"):
				var service_locator = Engine.get_singleton("ServiceLocator")
				var game_manager = service_locator.get_game_manager() if service_locator and service_locator.has_method("get_game_manager") else null
				if game_manager and game_manager.has_method("add_to_inventory"):
					game_manager.add_to_inventory("potion", 1)
					result = {"success": true, "message": "Added 1 potion"}
		
		"teleport":
			var player = _get_player()
			if player:
				var position = params.get("position", Vector2(100, 500))
				player.global_position = position
				result = {"success": true, "message": "Teleported to " + str(position)}
		
		"kill_enemy":
			var enemies = _get_enemies()
			if not enemies.is_empty():
				var closest = _get_closest_enemy(enemies)
				if closest:
					if closest.has_method("take_damage"):
						var damage = closest.current_health + 100 if closest.has("current_health") else 1000
						closest.take_damage(damage)
						result = {"success": true, "message": "Killed enemy: " + closest.name}
		
		"revive_enemies":
			var enemies = _get_enemies()
			var count = 0
			for enemy in enemies:
				if enemy.has("is_dead") and enemy.is_dead and enemy.has_method("revive"):
					enemy.revive()
					count += 1
			result = {"success": true, "message": "Revived " + str(count) + " enemies"}
		
		"next_scene":
			if Engine.has_singleton("ServiceLocator"):
				var service_locator = Engine.get_singleton("ServiceLocator")
				var game_manager = service_locator.get_game_manager() if service_locator and service_locator.has_method("get_game_manager") else null
				if game_manager and game_manager.has_method("go_to_next_level"):
					game_manager.go_to_next_level()
					result = {"success": true, "message": "Transitioning to next scene"}
		
		"prev_scene":
			if Engine.has_singleton("ServiceLocator"):
				var service_locator = Engine.get_singleton("ServiceLocator")
				var game_manager = service_locator.get_game_manager() if service_locator and service_locator.has_method("get_game_manager") else null
				if game_manager and game_manager.has_method("go_to_previous_level"):
					game_manager.go_to_previous_level()
					result = {"success": true, "message": "Transitioning to previous scene"}
		
		_:
			result = {"success": false, "error": "Unknown command: " + command}
	
	debug_command_executed.emit(command, result)
	return result

func _get_player() -> Node:
	"""Отримує гравця"""
	return GameGroups.get_first_node_in_group(GameGroups.PLAYER)

func _get_enemies() -> Array:
	"""Отримує всіх ворогів"""
	return GameGroups.get_nodes_in_group(GameGroups.ENEMIES)

func _get_closest_enemy(enemies: Array) -> Node:
	"""Отримує найближчого ворога"""
	var player = _get_player()
	if not player:
		return null
	
	var closest = null
	var min_dist = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var is_dead = false
		if enemy.has("is_dead"):
			is_dead = enemy.is_dead
		
		if is_dead:
			continue
		
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	
	return closest
