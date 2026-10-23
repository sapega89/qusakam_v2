extends RefCounted

## Вага броні (D592; без витривалості — D551): легка — довший перекат, важка — більше захисту й коротший перекат.
## Клас задає вдягнений обладунок (слот body, items.json "weight"); без обладунку — armour_weight.json "unarmoured".
## Без автозавантажень: скрипт тягне GameCharacter, а його компілюють і тести до появи автозавантажень.
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


## Частка, на яку перекат довший (мінус — коротший) з обладунком [param item] ({} — без нього).
static func roll_length_of(item: Dictionary) -> float:
	return float(row(class_of(item)).roll_length)


## Захист, що додає клас ваги обладунку [param item] (GameCharacter.get_equipment_stats).
static func defense_of(item: Dictionary) -> int:
	return int(row(class_of(item)).defense)
