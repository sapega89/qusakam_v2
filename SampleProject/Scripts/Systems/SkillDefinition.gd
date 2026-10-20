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
## Лікування цілі (D142: союзник поруч, інакше сам герой). 0 = навичка не лікує.
var heal: int = 0
## Слоти зброї, з якими навичка доступна (D141): ["sword", "dagger"] — меч або кинджал.
## Порожньо = без вимог.
var required_weapons: Array[String] = []
## D207: підпал (ушкодження за секунду, тривалість), ланцюг на сусіда (радіус, частка), оглушення (с).
var burn_dps: int = 0
var burn_duration: float = 0.0
var chain_radius: float = 0.0
var chain_ratio: float = 0.0
var stun: float = 0.0
## Пасивка (D207): який показник підсилює ("max_health", "shield_block") і на скільки на 1-му рангу.
var passive_stat: String = ""
var passive_value: float = 0.0

## Посилання на ресурси. Не завантажуються тут — це робота UI/VFX-шарів.
var icon: String = ""
var vfx: String = ""
## Каст (D259, D271): замах (удар по героєві його зриває), вивільнення, префікс анімацій тіла в Player.tscn.
var cast_windup: float = 0.0
var cast_release: float = 0.0
var cast_pose: String = ""


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
	definition.heal = maxi(0, int(data.get("heal", 0)))
	for slot in data.get("required_weapons", []):
		definition.required_weapons.append(String(slot))
	var burn: Dictionary = data.get("burn", {})
	definition.burn_dps = maxi(0, int(burn.get("dps", 0)))
	definition.burn_duration = maxf(0.0, float(burn.get("duration", 0.0)))
	var chain: Dictionary = data.get("chain", {})
	definition.chain_radius = maxf(0.0, float(chain.get("radius", 0.0)))
	definition.chain_ratio = clampf(float(chain.get("ratio", 0.0)), 0.0, 1.0)
	definition.stun = maxf(0.0, float(data.get("stun", 0.0)))
	var passive: Dictionary = data.get("passive", {})
	definition.passive_stat = String(passive.get("stat", ""))
	definition.passive_value = float(passive.get("value", 0.0))

	for entry in data.get("prerequisites", []):
		var prerequisite := String(entry).strip_edges()
		if not prerequisite.is_empty():
			definition.prerequisites.append(prerequisite)

	definition.icon = String(data.get("icon", ""))
	definition.vfx = String(data.get("vfx", ""))
	var cast: Dictionary = data.get("cast", {})
	definition.cast_windup = maxf(0.0, float(cast.get("windup", 0.0)))
	definition.cast_release = maxf(0.0, float(cast.get("release", 0.0)))
	definition.cast_pose = String(cast.get("pose", ""))

	# Пасивна навичка не активується, тому SP і перезарядка для неї не мають сенсу.
	if definition.skill_type == Type.PASSIVE:
		definition.sp_cost = 0
		definition.cooldown = 0.0
		definition.damage = 0
		definition.heal = 0
		definition.burn_dps = 0
		definition.chain_radius = 0.0
		definition.stun = 0.0

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
		"heal": heal,
		"required_weapons": required_weapons.duplicate(),
		"burn": {"dps": burn_dps, "duration": burn_duration},
		"chain": {"radius": chain_radius, "ratio": chain_ratio},
		"stun": stun,
		"passive": {"stat": passive_stat, "value": passive_value},
		"icon": icon,
		"vfx": vfx,
	}
