extends ManagerBase
class_name PlayerStateManager

## 👤 PlayerStateManager - Управління станом гравця
## Винесено з GameManager для розділення відповідальностей
## Дотримується принципу Single Responsibility
## АДАПТИРОВАНО: Исключены level, experience, stat_points (используется система из текущего проекта)

# Локальний стан гравця (зберігається між сценами)
var player_state = {
	"current_health": 100,
	"max_health": 100,
	"current_potions": 0,
	"max_potions": 5,
	"player_position": {"x": 100, "y": 549},
	"current_scene": "VillageScene",
	"unlocked_skills": [],
	"game_time": 0.0,
	"strength": 10,
	"intelligence": 10,
	"dexterity": 10,
	"constitution": 10,
	"class_id": "champion",
	"subclass_id": "paladin",
	"character_id": "player_1",
	"equipment": {
		"sword": null,
		"polearm": null,
		"dagger": null,
		"axe": null,
		"bow": null,
		"staff": null,
		"shield": null,
		"head": null,
		"body": null,
		"accessory_1": null,
		"accessory_2": null
	}
}

# Сигнали
signal player_state_changed()
signal player_health_changed(new_health: int, max_health: int)

func _initialize():
	"""Ініціалізація PlayerStateManager"""
	print("👤 PlayerStateManager: Initialized")

# ============================================
# ОСНОВНІ МЕТОДИ
# ============================================

func get_player_state() -> Dictionary:
	"""Отримує поточний стан гравця"""
	return player_state.duplicate(true)

func set_player_state(new_state: Dictionary):
	"""Встановлює новий стан гравця"""
	player_state = new_state.duplicate(true)
	player_state_changed.emit()

func update_player_health(current: int, max_health: int = -1):
	"""Оновлює здоров'я гравця"""
	player_state.current_health = current
	if max_health > 0:
		player_state.max_health = max_health
	player_health_changed.emit(current, player_state.max_health)
	player_state_changed.emit()

func get_player_health() -> Dictionary:
	"""Отримує здоров'я гравця"""
	return {
		"current": player_state.current_health,
		"max": player_state.max_health
	}

func set_player_position(position: Vector2):
	"""Встановлює позицію гравця"""
	# player_position в PlayerStateResource - это Vector2, не Dictionary
	player_state.player_position = position
	player_state_changed.emit()

func get_player_position() -> Vector2:
	"""Отримує позицію гравця"""
	# player_position в PlayerStateResource - это Vector2, не Dictionary
	if player_state and player_state.player_position != Vector2.ZERO:
		return player_state.player_position
	return Vector2(100, 549)  # Дефолтная позиция

func reset_player_state():
	"""Скидає стан гравця до початкових значень"""
	player_state = {
		"current_health": 100,
		"max_health": 100,
		"current_potions": 0,
		"max_potions": 5,
		"player_position": {"x": 100, "y": 549},
		"current_scene": "VillageScene",
		"unlocked_skills": [],
		"game_time": 0.0,
		"strength": 10,
		"intelligence": 10,
		"dexterity": 10,
		"constitution": 10,
		"class_id": "champion",
		"subclass_id": "paladin",
		"character_id": "player_1",
		"equipment": {
			"sword": null,
			"polearm": null,
			"dagger": null,
			"axe": null,
			"bow": null,
			"staff": null,
			"shield": null,
			"head": null,
			"body": null,
			"accessory_1": null,
			"accessory_2": null
		}
	}
	player_state_changed.emit()
	print("👤 PlayerStateManager: Player state reset")

