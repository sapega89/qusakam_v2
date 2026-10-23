extends ManagerBase
class_name AttributeManager

## 💪 AttributeManager — очки атрибутів (BACKLOG 44, D335): Strength, Agility, Vitality, Wisdom.
##
## Кожен рівень дає points_per_level очок (5); що дає одне очко — дані attributes.json, не код.
## Стан — лише в player_state (його зберігає PlayerDataModule):
##   attribute_points — ще не вкладені очки
##   attributes       — {attribute_id: вкладено очок}
## Окремо від старих strength/dexterity/... у player_state: ті CharacterManager переписує з персонажа при кожному
## вдяганні речі, тож тримати там вкладені очки не можна (як із subclass_id і клятвою, D280).
##
## Бонуси читають власники формул: GameManager (атака, HP, крит, ухилення, швидкість), SkillManager (SP, сила
## навичок, відновлення SP). Тут формул немає — лише «скільки очок × скільки дає очко».

enum Result {
	OK,
	UNKNOWN_ATTRIBUTE,
	NOT_ENOUGH_POINTS,
	NOTHING_TO_SPEND,
}

const DATA_PATH := "res://SampleProject/Resources/Data/attributes.json"
## Показники, які хтось справді читає (bonus); інший ключ у даних — помилка даних, не тихий нуль.
const KNOWN_STATS: Array[String] = ["attack", "max_health", "crit_chance", "dodge_chance", "attack_speed", "max_sp", "skill_power", "sp_per_hit"]

var points_per_level: int = 0
## Визначення в порядку файлу: {id, name, description, per_point}.
var definitions: Array[Dictionary] = []
var _caps: Dictionary = {}

var game_manager: Node = null


func _initialize() -> void:
	game_manager = ServiceLocator.get_game_manager()
	_load_data()
	EventBus.player_leveled_up.connect(_on_player_leveled_up)


func _load_data() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data != null and data.has("points_per_level") and data.has("attributes"), "AttributeManager: bad %s" % DATA_PATH)
	points_per_level = int(data.points_per_level)
	_caps = data.get("caps", {})
	definitions.clear()
	for entry: Dictionary in data.attributes:
		for stat: String in entry.per_point:
			assert(stat in KNOWN_STATS, "AttributeManager: %s gives unknown stat '%s'" % [entry.id, stat])
		definitions.append(entry)


func _on_player_leveled_up(new_level: int, old_level: int) -> void:
	_set_unspent(get_unspent() + points_per_level * (new_level - old_level))


# ── Читання ─────────────────────────────────────────────────────────────────

func attribute_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(String(definition.id))
	return ids


func has_attribute(attribute_id: String) -> bool:
	return attribute_id in attribute_ids()


func get_definition(attribute_id: String) -> Dictionary:
	for definition in definitions:
		if definition.id == attribute_id:
			return definition
	assert(false, "AttributeManager: unknown attribute %s" % attribute_id)
	return {}


func _state() -> Dictionary:
	return game_manager.player_state


## Ще не вкладені очки.
func get_unspent() -> int:
	return int(_state().get("attribute_points", 0))


## Вкладені в атрибут очки.
func get_points(attribute_id: String) -> int:
	return int(_state().get("attributes", {}).get(attribute_id, 0))


func spent_total() -> int:
	var total := 0
	for attribute_id in attribute_ids():
		total += get_points(attribute_id)
	return total


## Сума того, що дають вкладені очки, на показник [param stat] (див. KNOWN_STATS). Нічого не вкладено — 0.
func bonus(stat: String) -> float:
	assert(stat in KNOWN_STATS, "AttributeManager.bonus: unknown stat %s" % stat)
	var total := 0.0
	for definition in definitions:
		total += effective_points(definition, get_points(String(definition.id))) * float(definition.per_point.get(stat, 0.0))
	return total


## Спадна віддача (D642): з "diminishing" {step, factor} кожні step очок дають у factor разів менше за попередні
## (Strength: 1–10 повністю, 11–20 наполовину, 21–30 на чверть…). Без "diminishing" — скільки вкладено, стільки й діє.
func effective_points(definition: Dictionary, points: int) -> float:
	if not definition.has("diminishing"):
		return points
	var step := int(definition.diminishing.step)
	var factor := float(definition.diminishing.factor)
	var total := 0.0
	var weight := 1.0
	var left := points
	while left > 0:
		total += mini(left, step) * weight
		left -= step
		weight *= factor
	return total


## Значення показника з урахуванням стелі з даних (caps): крит, ухилення, швидкість.
func capped(stat: String, value: float) -> float:
	return minf(value, float(_caps[stat])) if _caps.has(stat) else value


## Що дадуть [param points] очок атрибута понад уже вкладені (для панелі деталей і плану; зі спадною віддачею).
func preview(attribute_id: String, points: int) -> Dictionary:
	var out := {}
	var definition := get_definition(attribute_id)
	var now := get_points(attribute_id)
	var gain := effective_points(definition, now + points) - effective_points(definition, now)
	for stat: String in definition.per_point:
		out[stat] = float(definition.per_point[stat]) * gain
	return out


# ── Витрата ─────────────────────────────────────────────────────────────────

## Чи можна вкласти [param allocation] ({attribute_id: очок}) за раз. Не змінює стан.
func can_spend(allocation: Dictionary) -> Result:
	var total := 0
	for attribute_id: String in allocation:
		if not has_attribute(attribute_id):
			return Result.UNKNOWN_ATTRIBUTE
		total += int(allocation[attribute_id])
	if total <= 0:
		return Result.NOTHING_TO_SPEND
	if total > get_unspent():
		return Result.NOT_ENOUGH_POINTS
	return Result.OK


## Вкладає очки (екран Skills, Accept — D330). Одна подія на все вкладення.
func spend(allocation: Dictionary) -> Result:
	var verdict := can_spend(allocation)
	if verdict != Result.OK:
		return verdict
	var spent: Dictionary = _state().get("attributes", {}).duplicate()
	var total := 0
	for attribute_id: String in allocation:
		var points := int(allocation[attribute_id])
		spent[attribute_id] = int(spent.get(attribute_id, 0)) + points
		total += points
	_state()["attributes"] = spent
	_set_unspent(get_unspent() - total)
	EventBus.attributes_changed.emit()
	return Result.OK


## Скидання разом із навичками (D282): усі вкладені очки повертаються. Повертає, скільки повернуто.
func reset() -> int:
	var refund := spent_total()
	if refund == 0:
		return 0
	_state()["attributes"] = {}
	_set_unspent(get_unspent() + refund)
	EventBus.attributes_changed.emit()
	return refund


## Сейв без очок атрибутів (до D335): нічого не вкладено, а невкладених — стільки, скільки дали б рівні.
func points_for_level(level: int) -> int:
	return points_per_level * maxi(0, level - 1)


func _set_unspent(value: int) -> void:
	var previous := get_unspent()
	var clamped := maxi(0, value)
	_state()["attribute_points"] = clamped
	if clamped != previous:
		EventBus.attribute_points_changed.emit(clamped, previous)
