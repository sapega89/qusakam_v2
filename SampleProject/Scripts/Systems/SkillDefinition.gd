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
## Дерево (D279): "" — стовбур Holy Warrior, інакше id клятви з skills.json → oaths (D280).
var oath: String = ""

var skill_type: Type = Type.ACTIVE

## Вартість розблокування в Job Points.
var jp_cost: int = 0
## D674: ранги — найвищий (активні 5, пасивки 3), JP за кожен ранг понад перший і частка ефекту першого рангу,
## яку додає кожен ранг понад перший (ушкодження, лікування, підпал, значення пасивки).
const MAX_RANK_ACTIVE := 5
const MAX_RANK_PASSIVE := 3
var max_rank: int = MAX_RANK_ACTIVE
var rank_jp: int = 1
var rank_bonus: float = 0.15
## D674: клітинка у вікні навичок — (стовпець, ряд) у панелі свого дерева.
var slot: Vector2i = Vector2i.ZERO
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
## D496: умова пасивки (D207-хук passive_value): "" — завжди; "below_hp" — HP героя нижче частки [member passive_condition_value];
## "after_parry" / "after_skill" — [member passive_condition_value] с після парирування / застосованої навички.
var passive_condition: String = ""
var passive_condition_value: float = 0.0

## B137: частки Phys. Atk. і Elem. Atk. героя, що додаються до damage / heal.
var damage_phys: float = 0.0
var damage_elem: float = 0.0
var heal_phys: float = 0.0
var heal_elem: float = 0.0
## D491: ультимативна навичка професії — довга перезарядка, тряска камери, подвійне кільце на хотбарі (D453).
var ultimate: bool = false
## D504: фляга — заряди замість SP і перезарядки, поповнюються при збереженні. 0 — навичка не фляга.
var charges: int = 0
## D496: синергії — [{skill, per_rank}]: кожен ранг пасивки свого дерева додає per_rank до сили навички.
var synergies: Array[Dictionary] = []
## D497: скільки JP треба вкласти в дерево базового класу, щоб вивчити цю навичку професії. 0 — без вимоги.
var base_jp: int = 0
## D535 (v2, зріз 1): навичка вже в даних, але ще не збудована — її не можна вивчити чи застосувати,
## екран навичок показує її замкненою («Coming later»).
var planned: bool = false

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
	definition.oath = String(data.get("oath", ""))
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
	var condition: Dictionary = passive.get("condition", {})
	definition.passive_condition = String(condition.get("type", ""))
	definition.passive_condition_value = float(condition.get("value", 0.0))
	var damage_scaling: Dictionary = data.get("damage_scaling", {})
	definition.damage_phys = maxf(0.0, float(damage_scaling.get("phys", 0.0)))
	definition.damage_elem = maxf(0.0, float(damage_scaling.get("elem", 0.0)))
	var heal_scaling: Dictionary = data.get("heal_scaling", {})
	definition.heal_phys = maxf(0.0, float(heal_scaling.get("phys", 0.0)))
	definition.heal_elem = maxf(0.0, float(heal_scaling.get("elem", 0.0)))
	definition.ultimate = bool(data.get("ultimate", false))
	definition.charges = maxi(0, int(data.get("charges", 0)))
	for synergy: Dictionary in data.get("synergies", []):
		definition.synergies.append({"skill": String(synergy.skill), "per_rank": float(synergy.per_rank)})
	definition.base_jp = maxi(0, int(data.get("base_jp", 0)))
	definition.planned = bool(data.get("planned", false))
	# D674: у skills.json блок rank є в кожної навички (verify_skill_ranks); тестові записи без нього — ранги за видом.
	var rank: Dictionary = data.get("rank", {})
	var passive_kind := definition.skill_type == Type.PASSIVE
	definition.max_rank = maxi(1, int(rank.get("max", MAX_RANK_PASSIVE if passive_kind else MAX_RANK_ACTIVE)))
	definition.rank_jp = maxi(1, int(rank.get("jp", 1)))
	definition.rank_bonus = maxf(0.0, float(rank.get("bonus", 0.25 if passive_kind else 0.15)))
	var cell: Array = data.get("slot", [0, 0])
	definition.slot = Vector2i(int(cell[0]), int(cell[1]))

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
		definition.damage_phys = 0.0
		definition.damage_elem = 0.0
		definition.heal_phys = 0.0
		definition.heal_elem = 0.0
		definition.ultimate = false
		definition.charges = 0
		definition.synergies.clear()

	return definition


## D674: множник ефекту на ранзі [param rank] (0 — як на першому): 1 + bonus за кожен ранг понад перший.
func rank_factor(rank: int) -> float:
	return 1.0 + rank_bonus * (maxi(1, rank) - 1)


func is_active() -> bool:
	return skill_type == Type.ACTIVE


## Тон іконки (D602): ультимейт — золото, пасивка — сталево-блакитний, решта активних — слонова кістка.
func icon_tint() -> Color:
	if ultimate:
		return UITokens.SKILL_ICON_ULTIMATE
	return UITokens.SKILL_ICON_ACTIVE if is_active() else UITokens.SKILL_ICON_PASSIVE


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"class_id": class_id,
		"subclass_id": subclass_id,
		"oath": oath,
		"skill_type": "active" if is_active() else "passive",
		"jp_cost": jp_cost,
		"rank": {"max": max_rank, "jp": rank_jp, "bonus": rank_bonus},
		"slot": [slot.x, slot.y],
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
		"passive": {"stat": passive_stat, "value": passive_value,
				"condition": {"type": passive_condition, "value": passive_condition_value}},
		"damage_scaling": {"phys": damage_phys, "elem": damage_elem},
		"heal_scaling": {"phys": heal_phys, "elem": heal_elem},
		"ultimate": ultimate,
		"charges": charges,
		"synergies": synergies.duplicate(true),
		"base_jp": base_jp,
		"planned": planned,
		"icon": icon,
		"vfx": vfx,
	}
