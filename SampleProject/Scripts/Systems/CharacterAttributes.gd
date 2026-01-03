extends Resource
class_name CharacterAttributes

## Базовые атрибуты персонажа
@export var strength: int = 10
@export var intelligence: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10

## Бонусы от экипировки (временные, не сохраняются)
var equipment_bonuses: Dictionary = {
	"strength": 0,
	"intelligence": 0,
	"dexterity": 0,
	"constitution": 0,
	"attack": 0,
	"defense": 0,
	"magic": 0
}

## Получить эффективное значение силы (базовое + бонусы)
func get_effective_strength() -> int:
	return strength + equipment_bonuses.get("strength", 0)

## Получить эффективное значение интеллекта (базовое + бонусы)
func get_effective_intelligence() -> int:
	return intelligence + equipment_bonuses.get("intelligence", 0)

## Получить эффективное значение ловкости (базовое + бонусы)
func get_effective_dexterity() -> int:
	return dexterity + equipment_bonuses.get("dexterity", 0)

## Получить эффективное значение телосложения (базовое + бонусы)
func get_effective_constitution() -> int:
	return constitution + equipment_bonuses.get("constitution", 0)

## Установить бонусы от экипировки
func set_equipment_bonuses(bonuses: Dictionary):
	equipment_bonuses = bonuses.duplicate()

## Сбросить бонусы от экипировки
func clear_equipment_bonuses():
	equipment_bonuses = {
		"strength": 0,
		"intelligence": 0,
		"dexterity": 0,
		"constitution": 0,
		"attack": 0,
		"defense": 0,
		"magic": 0
	}

## Валидация атрибутов
func validate() -> bool:
	return strength >= 0 and intelligence >= 0 and dexterity >= 0 and constitution >= 0

## Получить все базовые атрибуты как словарь
func get_base_attributes() -> Dictionary:
	return {
		"strength": strength,
		"intelligence": intelligence,
		"dexterity": dexterity,
		"constitution": constitution
	}

## Получить все эффективные атрибуты как словарь
func get_effective_attributes() -> Dictionary:
	return {
		"strength": get_effective_strength(),
		"intelligence": get_effective_intelligence(),
		"dexterity": get_effective_dexterity(),
		"constitution": get_effective_constitution()
	}

## Увеличить атрибут (для распределения очков)
func increase_attribute(attribute_name: String, amount: int = 1) -> bool:
	match attribute_name:
		"strength":
			strength += amount
			return true
		"intelligence":
			intelligence += amount
			return true
		"dexterity":
			dexterity += amount
			return true
		"constitution":
			constitution += amount
			return true
		_:
			return false

## Создать копию атрибутов
func duplicate_attributes() -> CharacterAttributes:
	var new_attributes = CharacterAttributes.new()
	new_attributes.strength = strength
	new_attributes.intelligence = intelligence
	new_attributes.dexterity = dexterity
	new_attributes.constitution = constitution
	return new_attributes

