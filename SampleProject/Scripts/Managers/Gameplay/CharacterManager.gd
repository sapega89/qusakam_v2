extends ManagerBase
class_name CharacterManager

## 👤 CharacterManager - Управление персонажами
## Отвечает только за управление персонажами и их данными
## Согласно SRP: одна ответственность - управление персонажами
## АДАПТИРОВАНО: Исключены level, experience, stat_points (используется система из текущего проекта)

# Preload GameCharacter script to ensure it's loaded (class_name should be available globally)
const GameCharacterScript = preload("res://SampleProject/Scripts/Systems/Character.gd")

# Character system - multiple characters support
var characters: Dictionary[String, GameCharacter] = {}  # Dictionary of character_id -> GameCharacter (Resource)
var active_character_id: String = "player_1"  # Currently active character
var active_character: GameCharacter  # Currently active character object (for quick access)

# Сигналы
signal character_changed(character_id: String)
signal character_initialized()

# Ссылка на GameManager для синхронизации с player_state (временная, для обратной совместимости)
var game_manager: Node = null

func _initialize():
	"""Инициализирует зависимости после того, как ServiceLocator зарегистрирует все сервисы"""
	# Получаем GameManager через ServiceLocator
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator:
		if service_locator and service_locator.has_method("get_game_manager"):
			game_manager = service_locator.get_game_manager()
		if not game_manager:
			push_warning("⚠️ CharacterManager: GameManager not found!")

	# Подключаемся к EventBus для обработки экипировки
	EventBus.equipment_equip_requested.connect(_on_equipment_equip_requested)
	EventBus.equipment_unequip_requested.connect(_on_equipment_unequip_requested)

func initialize_characters(character_data_list: Dictionary = {}):
	"""Инициализирует персонажей из словаря данных"""
	if character_data_list.is_empty():
		# Используем дефолтные данные
		character_data_list = _get_default_character_data()
	
	# Convert dictionaries to Character objects
	characters = {}
	for char_id in character_data_list.keys():
		var char_data = character_data_list[char_id]
		char_data["character_id"] = char_id
		# Копируем equipment slots из player_state если доступен
		if game_manager and "player_state" in game_manager:
			char_data["equipment"] = game_manager.player_state.equipment.duplicate()
		else:
			char_data["equipment"] = _get_default_equipment_slots()
		characters[char_id] = GameCharacterScript.from_dict(char_data)
	
	active_character_id = "player_1"
	active_character = characters.get(active_character_id)
	
	# Синхронизируем с player_state если доступен
	if game_manager:
		_sync_player_state_from_character()
	
	character_initialized.emit()
	print("✅ CharacterManager: Characters initialized, active: ", active_character_id)

func _get_default_character_data() -> Dictionary:
	"""Возвращает дефолтные данные персонажей (БЕЗ level/experience)"""
	return {
		"player_1": {
			"name": "Астрит",
			"class_id": "champion",
			"subclass_id": "paladin",
			"avatar_color": Color(0.2, 0.6, 0.9, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_2": {
			"name": "Уризен",
			"class_id": "fighter",
			"subclass_id": "guardian",
			"avatar_color": Color(0.9, 0.3, 0.3, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_3": {
			"name": "Кусакам",
			"class_id": "wizard",
			"subclass_id": "evoker",
			"avatar_color": Color(0.6, 0.3, 0.9, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_4": {
			"name": "Три темніх жреца",
			"class_id": "wizard",
			"subclass_id": "necromancer",
			"avatar_color": Color(0.1, 0.1, 0.1, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_5": {
			"name": "Гном механник",
			"class_id": "rogue",
			"subclass_id": "thief",
			"avatar_color": Color(0.8, 0.6, 0.4, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_6": {
			"name": "Алісия",
			"class_id": "druid",
			"subclass_id": "protector",
			"avatar_color": Color(0.3, 0.8, 0.3, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_7": {
			"name": "Суан",
			"class_id": "ranger",
			"subclass_id": "hunter",
			"avatar_color": Color(0.9, 0.7, 0.2, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		},
		"player_8": {
			"name": "Торговец",
			"class_id": "rogue",
			"subclass_id": "scoundrel",
			"avatar_color": Color(0.5, 0.5, 0.8, 1.0),
			"strength": 10,
			"intelligence": 10,
			"dexterity": 10,
			"constitution": 10
		}
	}

func _get_default_equipment_slots() -> Dictionary:
	"""Возвращает дефолтные слоты экипировки"""
	return {
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

func switch_character(character_id: String) -> bool:
	"""Переключает активного персонажа"""
	if not characters.has(character_id):
		print("⚠️ CharacterManager: Character not found: ", character_id)
		return false
	
	# Сохраняем состояние текущего персонажа
	if game_manager:
		_sync_character_from_player_state()
	
	# Переключаемся на нового персонажа
	active_character_id = character_id
	active_character = characters[character_id]
	
	# Обновляем бонусы экипировки для нового персонажа
	if active_character:
		active_character.update_equipment_bonuses()
	
	# Синхронизируем player_state с новым персонажем
	if game_manager:
		_sync_player_state_from_character()
	
	# Эмитируем сигнал
	character_changed.emit(character_id)
	print("✅ CharacterManager: Switched to character: ", character_id)
	return true

func get_character(character_id: String) -> GameCharacter:
	"""Получает объект персонажа по ID"""
	if characters.has(character_id):
		return characters[character_id]
	return null

func get_all_characters() -> Dictionary:
	"""Получает всех персонажей"""
	return characters

func get_active_character() -> GameCharacter:
	"""Получает активного персонажа"""
	return active_character

func get_active_character_id() -> String:
	"""Получает ID активного персонажа"""
	return active_character_id

func get_class_data(class_id: String, subclass_id: String = "") -> Dictionary:
	"""Загружает данные класса из JSON"""
	var file_path = "res://SampleProject/Resources/Data/pathfinder_classes.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("⚠️ CharacterManager: Could not open classes file: ", file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("⚠️ CharacterManager: Failed to parse classes JSON")
		return {}
	
	var data = json.data
	if not data.has("classes") or not data.classes.has(class_id):
		return {}
	
	var class_data = data.classes[class_id]
	var result = {
		"name": class_data.name,
		"description": class_data.description,
		"subclasses": {}
	}
	
	if subclass_id != "" and class_data.subclasses.has(subclass_id):
		result.subclass = class_data.subclasses[subclass_id]
	
	return result

func _sync_player_state_from_character():
	"""Синхронизирует player_state с данными активного персонажа (БЕЗ level/experience)"""
	if not active_character or not game_manager:
		return
	
	if not "player_state" in game_manager:
		return
	
	var player_state = game_manager.player_state
	# Исключены: level, experience, experience_to_next_level, stat_points
	player_state.strength = active_character.attributes.strength
	player_state.intelligence = active_character.attributes.intelligence
	player_state.dexterity = active_character.attributes.dexterity
	player_state.constitution = active_character.attributes.constitution
	player_state.class_id = active_character.class_id
	player_state.subclass_id = active_character.subclass_id
	player_state.character_id = active_character.character_id
	player_state.equipment = active_character.equipment.duplicate()

func _sync_character_from_player_state():
	"""Синхронизирует данные активного персонажа из player_state (БЕЗ level/experience)"""
	if not active_character or not game_manager:
		return
	
	if not "player_state" in game_manager:
		return
	
	var player_state = game_manager.player_state
	# Исключены: level, experience, experience_to_next_level, stat_points
	active_character.attributes.strength = player_state.strength
	active_character.attributes.intelligence = player_state.intelligence
	active_character.attributes.dexterity = player_state.dexterity
	active_character.attributes.constitution = player_state.constitution
	active_character.class_id = player_state.class_id
	active_character.subclass_id = player_state.subclass_id
	active_character.equipment = player_state.equipment.duplicate()

## Обработчик запроса на экипирование предмета (из EventBus)
func _on_equipment_equip_requested(character_id: String, slot_id: String, item_id: String, item_data: Dictionary) -> void:
	"""Обрабатывает запрос на экипирование через EventBus"""
	var character = get_character(character_id)
	if not character:
		push_warning("⚠️ CharacterManager: Character not found: ", character_id)
		return

	# Экипируем предмет
	character.equipment[slot_id] = {
		"id": item_id,
		"name": item_data.get("name", ""),
		"icon": item_data.get("icon_path", "")
	}

	# Обновляем бонусы экипировки
	character.update_equipment_bonuses()

	# SaveSystem (PlayerDataModule) сохраняет player_state.equipment, а не
	# character.equipment. Без этой синхронизации всё, что надето через
	# EquipmentManager/EventBus, терялось при сохранении.
	if character_id == active_character_id:
		_sync_player_state_from_character()

	# Уведомляем об успешном экипировании
	EventBus.equipment_equipped.emit(character_id, slot_id, item_id)
	print("✅ CharacterManager: Equipped ", item_id, " to ", slot_id, " for ", character_id)

## Обработчик запроса на снятие предмета (из EventBus)
func _on_equipment_unequip_requested(character_id: String, slot_id: String) -> void:
	"""Обрабатывает запрос на снятие экипировки через EventBus"""
	var character = get_character(character_id)
	if not character:
		push_warning("⚠️ CharacterManager: Character not found: ", character_id)
		return

	# Снимаем предмет
	character.equipment[slot_id] = null

	# Обновляем бонусы экипировки
	character.update_equipment_bonuses()

	# См. комментарий в _on_equipment_equip_requested — синхронизация нужна,
	# иначе снятие предмета не попадёт в сохранение.
	if character_id == active_character_id:
		_sync_player_state_from_character()

	# Уведомляем об успешном снятии
	EventBus.equipment_unequipped.emit(character_id, slot_id)
	print("✅ CharacterManager: Unequipped from ", slot_id, " for ", character_id)

func _exit_tree() -> void:
	"""Отключаемся от EventBus при удалении"""
	if EventBus.equipment_equip_requested.is_connected(_on_equipment_equip_requested):
		EventBus.equipment_equip_requested.disconnect(_on_equipment_equip_requested)
	if EventBus.equipment_unequip_requested.is_connected(_on_equipment_unequip_requested):
		EventBus.equipment_unequip_requested.disconnect(_on_equipment_unequip_requested)

