extends SaveModule
class_name PlayerDataModule

## 🎮 PlayerDataModule - Сохранение данных игрока
## Управляет: позиция, здоровье, характеристики, навыки, экипировка

func _ready():
	module_name = "PlayerDataModule"

## Сохраняет данные игрока
func save() -> Dictionary:
	var data = {}

	# Получаем GameManager через ServiceLocator
	var game_manager = _get_game_manager()
	if not game_manager:
		log_error("GameManager not found, cannot save player data")
		return data

	# Получаем player_state
	if not game_manager.has("player_state"):
		log_error("player_state not found in GameManager")
		return data

	var player_state = game_manager.player_state

	# Сохраняем здоровье
	data["current_health"] = player_state.get("current_health", 0)
	data["max_health"] = player_state.get("max_health", 0)

	# Сохраняем позицию
	var pos = player_state.get("player_position", Vector2(100, 549))
	data["player_position"] = {"x": pos.x, "y": pos.y}

	# Сохраняем текущую сцену
	data["current_scene"] = player_state.get("current_scene", "")

	# Сохраняем характеристики (без level/experience)
	data["strength"] = player_state.get("strength", 10)
	data["intelligence"] = player_state.get("intelligence", 10)
	data["dexterity"] = player_state.get("dexterity", 10)
	data["constitution"] = player_state.get("constitution", 10)

	# Сохраняем навыки
	data["unlocked_skills"] = player_state.get("unlocked_skills", []).duplicate()

	# Сохраняем экипировку
	data["equipment"] = player_state.get("equipment", {}).duplicate()

	# Сохраняем информацию о персонаже
	data["class_id"] = player_state.get("class_id", "champion")
	data["subclass_id"] = player_state.get("subclass_id", "paladin")
	data["character_id"] = player_state.get("character_id", "player_1")

	# Сохраняем игровое время
	data["game_time"] = player_state.get("game_time", 0.0)

	# Сохраняем имя игрока
	data["player_name"] = player_state.get("player_name", "Player")

	log_info("Player data saved: position=%s, health=%d/%d" % [pos, data["current_health"], data["max_health"]])

	return data

## Загружает данные игрока
func load_data(data: Dictionary) -> void:
	if not validate_data(data):
		log_error("Invalid player data")
		return

	# Получаем GameManager через ServiceLocator
	var game_manager = _get_game_manager()
	if not game_manager:
		log_error("GameManager not found, cannot load player data")
		return

	# Получаем player_state
	if not game_manager.has("player_state"):
		log_error("player_state not found in GameManager")
		return

	var player_state = game_manager.player_state

	# Загружаем здоровье (только если есть сохраненные данные)
	if "current_health" in data and data.current_health > 0:
		player_state.current_health = data.current_health
	if "max_health" in data and data.max_health > 0:
		player_state.max_health = data.max_health

	# Загружаем позицию
	if "player_position" in data:
		var pos_data = data.player_position
		if pos_data is Dictionary:
			player_state.player_position = Vector2(pos_data.get("x", 100), pos_data.get("y", 549))
		else:
			player_state.player_position = pos_data

	# Загружаем текущую сцену
	if "current_scene" in data:
		player_state.current_scene = data.current_scene

	# Загружаем характеристики
	if "strength" in data:
		player_state.strength = data.strength
	if "intelligence" in data:
		player_state.intelligence = data.intelligence
	if "dexterity" in data:
		player_state.dexterity = data.dexterity
	if "constitution" in data:
		player_state.constitution = data.constitution

	# Загружаем навыки
	if "unlocked_skills" in data:
		var skills_data = data.unlocked_skills
		if skills_data is Array:
			var typed_skills: Array[String] = []
			for skill in skills_data:
				if skill is String:
					typed_skills.append(skill)
			player_state.unlocked_skills = typed_skills
		else:
			player_state.unlocked_skills = []

	# Загружаем экипировку
	if "equipment" in data:
		player_state.equipment = data.equipment.duplicate() if data.equipment is Dictionary else {}

	# Загружаем информацию о персонаже
	if "class_id" in data:
		player_state.class_id = data.class_id
	if "subclass_id" in data:
		player_state.subclass_id = data.subclass_id
	if "character_id" in data:
		player_state.character_id = data.character_id

	# Загружаем игровое время
	if "game_time" in data:
		player_state.game_time = data.game_time

	# Загружаем имя игрока
	if "player_name" in data:
		player_state.player_name = data.player_name

	log_info("Player data loaded: position=%s, health=%d/%d" % [player_state.player_position, player_state.current_health, player_state.max_health])

## Возвращает данные без сохранения
func get_data() -> Dictionary:
	return save()

## Устанавливает данные без загрузки из файла
func set_data(data: Dictionary) -> void:
	load_data(data)

## Получает GameManager через ServiceLocator
func _get_game_manager():
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_game_manager"):
			return service_locator.get_game_manager()
	return null

## Валидация данных
func validate_data(data: Dictionary) -> bool:
	if not super.validate_data(data):
		return false

	# Проверяем обязательные поля
	if not data.has("player_position"):
		log_warning("Missing player_position in data")
		return false

	return true
