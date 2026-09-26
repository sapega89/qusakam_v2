extends RefCounted
class_name SkillDefinition

## Опис однієї навички. Дані приходять з skills.json через SkillDatabase.
##
## Тут НЕМАЄ бойових формул і немає UI — лише дані та їх валідація.
## Ефекти навичок додаються пізніше, у бойовій фазі.

enum Type { ACTIVE, PASSIVE }

var id: String = ""
var name: String = ""
var description: String = ""

## Прив'язка до класу/підкласу з pathfinder_classes.json.
## Порожній рядок = навичка доступна будь-якому класу.
var class_id: String = ""
var subclass_id: String = ""

var skill_type: Type = Type.ACTIVE

## Вартість розблокування в Job Points.
var jp_cost: int = 0
## Мінімальний рівень персонажа.
var required_level: int = 1
## Ідентифікатори навичок, які треба вивчити раніше.
var prerequisites: Array[String] = []

## Лише для ACTIVE: витрата SP і перезарядка в секундах.
var sp_cost: int = 0
var cooldown: float = 0.0

## Пряме ушкодження навички. 0 = навичка не завдає прямого ушкодження.
## Це КОНФІГУРАЦІЯ, а не формула: застосуванням займається SkillCombatExecutor
## через наявний HealthComponent.apply_damage().
var damage: int = 0

## Посилання на ресурси. Не завантажуються тут — це робота UI/VFX-шарів.
var icon: String = ""
var vfx: String = ""


static func type_from_string(value: String) -> Type:
	return Type.PASSIVE if value.strip_edges().to_lower() == "passive" else Type.ACTIVE


## Створює визначення зі словника JSON. Повертає null, якщо запис некоректний,
## тому база даних може безпечно пропустити биті дані замість падіння.
static func from_dict(data: Dictionary) -> SkillDefinition:
	var skill_id := String(data.get("id", "")).strip_edges()
	if skill_id.is_empty():
		return null

	var definition := SkillDefinition.new()
	definition.id = skill_id
	definition.name = String(data.get("name", ""))
	definition.description = String(data.get("description", ""))
	definition.class_id = String(data.get("class_id", ""))
	definition.subclass_id = String(data.get("subclass_id", ""))
	definition.skill_type = type_from_string(String(data.get("skill_type", "active")))

	# Від'ємні витрати/рівні — некоректні дані, а не «безкоштовна» навичка.
	definition.jp_cost = maxi(0, int(data.get("jp_cost", 0)))
	definition.required_level = maxi(1, int(data.get("required_level", 1)))
	definition.sp_cost = maxi(0, int(data.get("sp_cost", 0)))
	definition.cooldown = maxf(0.0, float(data.get("cooldown", 0.0)))
	definition.damage = maxi(0, int(data.get("damage", 0)))

	for entry in data.get("prerequisites", []):
		var prerequisite := String(entry).strip_edges()
		if not prerequisite.is_empty():
			definition.prerequisites.append(prerequisite)

	definition.icon = String(data.get("icon", ""))
	definition.vfx = String(data.get("vfx", ""))

	# Пасивна навичка не активується, тому SP і перезарядка для неї не мають сенсу.
	if definition.skill_type == Type.PASSIVE:
		definition.sp_cost = 0
		definition.cooldown = 0.0
		definition.damage = 0

	return definition


func is_active() -> bool:
	return skill_type == Type.ACTIVE


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"class_id": class_id,
		"subclass_id": subclass_id,
		"skill_type": "active" if is_active() else "passive",
		"jp_cost": jp_cost,
		"required_level": required_level,
		"prerequisites": prerequisites.duplicate(),
		"sp_cost": sp_cost,
		"cooldown": cooldown,
		"damage": damage,
		"icon": icon,
		"vfx": vfx,
	}
