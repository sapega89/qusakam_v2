extends Resource
class_name GameCharacter

## Идентификатор персонажа
@export var character_id: String = ""

## Имя персонажа
@export var name: String = ""

## Класс и подкласс
@export var class_id: String = ""
@export var subclass_id: String = ""

## Цвет аватара
@export var avatar_color: Color = Color.WHITE

## Атрибуты персонажа (композиция)
@export var attributes: CharacterAttributes

## Экипировка (слот -> предмет)
var equipment: Dictionary = {}

## Инициализация атрибутов по умолчанию
func _init():
	if not attributes:
		attributes = CharacterAttributes.new()

## Получить статы экипировки из всех одетых предметов
func get_equipment_stats() -> Dictionary:
	var total_stats = {
		"attack": 0,
		"defense": 0,
		"magic": 0,
		"strength": 0,
		"intelligence": 0,
		"dexterity": 0,
		"constitution": 0
	}
	
	# Получить ItemDatabase
	var item_database = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_item_database"):
			item_database = service_locator.get_item_database()
	if not item_database:
		return total_stats
	
	# Суммировать статы из всех одетых предметов
	for slot_id in equipment.keys():
		var equipped_item = equipment[slot_id]
		if equipped_item and equipped_item is Dictionary:
			var item_id = equipped_item.get("id", "")
			if item_id != "":
				var item_data = item_database.get_item(item_id)
				if not item_data.is_empty():
					var stats = item_data.get("stats", {})
					if stats is Dictionary:
						# Прямые бонусы статов
						total_stats["attack"] += stats.get("attack", 0)
						total_stats["defense"] += stats.get("defense", 0)
						total_stats["magic"] += stats.get("magic", 0)
						
						# Бонусы к базовым атрибутам
						total_stats["strength"] += stats.get("strength", 0)
						total_stats["intelligence"] += stats.get("intelligence", 0)
						total_stats["dexterity"] += stats.get("dexterity", 0)
						total_stats["constitution"] += stats.get("constitution", 0)
	
	return total_stats

## Обновить бонусы атрибутов от экипировки
func update_equipment_bonuses():
	var equipment_stats = get_equipment_stats()
	attributes.set_equipment_bonuses(equipment_stats)

## Получить все эффективные статы (с учетом атрибутов и экипировки)
func get_effective_stats() -> Dictionary:
	update_equipment_bonuses()
	var equipment_stats = get_equipment_stats()
	return StatCalculator.calculate_all_stats(attributes, equipment_stats)

## Создать персонажа из словаря (для загрузки из GameManager)
## АДАПТИРОВАНО: Исключены level, experience, experience_to_next_level, stat_points
static func from_dict(data: Dictionary) -> GameCharacter:
	var character = GameCharacter.new()
	
	character.character_id = data.get("character_id", "")
	character.name = data.get("name", "")
	character.class_id = data.get("class_id", "")
	character.subclass_id = data.get("subclass_id", "")
	
	# Цвет аватара
	if data.has("avatar_color"):
		var color_data = data.avatar_color
		if color_data is Dictionary:
			character.avatar_color = Color(color_data.get("r", 1.0), color_data.get("g", 1.0), color_data.get("b", 1.0), color_data.get("a", 1.0))
		elif color_data is Color:
			character.avatar_color = color_data
	
	# Атрибуты (БЕЗ level/experience)
	if not character.attributes:
		character.attributes = CharacterAttributes.new()
	
	character.attributes.strength = data.get("strength", 10)
	character.attributes.intelligence = data.get("intelligence", 10)
	character.attributes.dexterity = data.get("dexterity", 10)
	character.attributes.constitution = data.get("constitution", 10)
	
	# Экипировка
	if data.has("equipment"):
		character.equipment = data.equipment.duplicate()
	
	return character

## Преобразовать персонажа в словарь (для сохранения в GameManager)
## АДАПТИРОВАНО: Исключены level, experience, experience_to_next_level, stat_points
func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"name": name,
		"class_id": class_id,
		"subclass_id": subclass_id,
		"avatar_color": {
			"r": avatar_color.r,
			"g": avatar_color.g,
			"b": avatar_color.b,
			"a": avatar_color.a
		},
		"strength": attributes.strength,
		"intelligence": attributes.intelligence,
		"dexterity": attributes.dexterity,
		"constitution": attributes.constitution,
		"equipment": equipment.duplicate()
	}

## Валидация персонажа
func validate() -> bool:
	return character_id != "" and name != "" and attributes.validate()

