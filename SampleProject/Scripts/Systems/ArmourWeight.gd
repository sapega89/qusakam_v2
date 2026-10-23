extends RefCounted

## Вага броні (D592; без витривалості — D551): легка — довший перекат, важка — більше захисту й коротший перекат.
## Клас задає вдягнений обладунок (слот body, items.json "weight"); без обладунку — armour_weight.json "unarmoured".
##   const ArmourWeight = preload("res://SampleProject/Scripts/Systems/ArmourWeight.gd")

const DATA_PATH := "res://SampleProject/Resources/Data/armour_weight.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


## Клас ваги обладунку [param item] (запис ItemDatabase) або "unarmoured"-клас для {}.
static func class_of(item: Dictionary) -> String:
	return String(data().unarmoured) if item.is_empty() else String(item.weight)


static func row(weight_class: String) -> Dictionary:
	return data().classes[weight_class]


## Клас ваги героя — за вдягненим обладунком.
static func worn_class() -> String:
	var body = ServiceLocator.get_game_manager().player_state.equipment.get("body")
	return class_of({} if body == null else ServiceLocator.get_item_database().get_item(String(body.id)))


## Частка, на яку перекат довший (мінус — коротший).
static func roll_length() -> float:
	return float(row(worn_class()).roll_length)


## Захист, що додає клас ваги обладунку [param item] (GameCharacter.get_equipment_stats).
static func defense_of(item: Dictionary) -> int:
	return int(row(class_of(item)).defense)
