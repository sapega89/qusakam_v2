extends RefCounted
class_name SkillPlan

## 📝 SkillPlan — вибір на екрані Skills, ще не прийнятий (D330, BACKLOG 43 + 44).
##
## Гравець позначає навички (вивчити / підняти ранг) і очки атрибутів; нічого не витрачено, доки не Accept.
## Будь-яку позначку можна зняти; знята навичка тягне за собою позначки, яким вона була передумовою.
## Правил тут немає: «чи можна» питаємо в SkillManager.check_unlock / check_upgrade з уявним станом
## (вивчене + заплановане, очок лишилось), «скільки очок» — в AttributeManager.

signal changed

var _skills: SkillManager
var _attributes: AttributeManager
## Позначки навичок у порядку вибору; перша позначка невивченої навички — вивчення, решта — ранги.
var _picks: Array[String] = []
## attribute_id → очок позначено.
var _attribute_picks: Dictionary = {}


func _init(skills: SkillManager, attributes: AttributeManager) -> void:
	_skills = skills
	_attributes = attributes


func is_empty() -> bool:
	return _picks.is_empty() and _attribute_picks.is_empty()


# ── Навички ─────────────────────────────────────────────────────────────────

func has_skill_picks() -> bool:
	return not _picks.is_empty()


## Скільки разів навичку позначено.
func skill_picks(skill_id: String) -> int:
	return _picks.count(skill_id)


## Ранг після Accept (0 — так і лишиться не вивченою).
func planned_rank(skill_id: String) -> int:
	return _skills.get_rank(skill_id) + skill_picks(skill_id)


## Вивчене разом із запланованим до вивчення.
func planned_unlocked() -> Array:
	var unlocked: Array = _skills.get_unlocked_skills().duplicate()
	for skill_id in _picks:
		if not skill_id in unlocked:
			unlocked.append(skill_id)
	return unlocked


## Очок навичок піде на позначене.
func jp_cost() -> int:
	return _cost_of(_picks)


func jp_left() -> int:
	return _skills.get_job_points() - jp_cost()


func _cost_of(picks: Array[String]) -> int:
	var total := 0
	var seen: Array[String] = []
	for skill_id in picks:
		var learns := not _skills.is_unlocked(skill_id) and not skill_id in seen
		total += _skills.skill_database.get_skill(skill_id).jp_cost if learns else SkillManager.UPGRADE_COST
		seen.append(skill_id)
	return total


## Вердикт SkillManager для ще однієї позначки з урахуванням уже позначеного.
func can_pick(skill_id: String) -> SkillManager.Result:
	var rank := planned_rank(skill_id)
	if rank == 0:
		return _skills.check_unlock(skill_id, planned_unlocked(), jp_left(), planned_ranks())
	return _skills.check_upgrade(skill_id, rank, jp_left(), planned_unlocked(), planned_ranks())


## Ранги після Accept для позначених навичок — для лімітів дерев і порогів (D497).
func planned_ranks() -> Dictionary:
	var ranks := {}
	for skill_id in _picks:
		ranks[skill_id] = planned_rank(skill_id)
	return ranks


func pick(skill_id: String) -> SkillManager.Result:
	var verdict := can_pick(skill_id)
	if verdict == SkillManager.Result.OK:
		_picks.append(skill_id)
		changed.emit()
	return verdict


## Знімає останню позначку навички; позначки, що на неї спирались, знімаються теж.
func unpick(skill_id: String) -> bool:
	var at := _picks.rfind(skill_id)
	if at == -1:
		return false
	_picks.remove_at(at)
	_revalidate()
	changed.emit()
	return true


## Перебирає позначки заново по порядку: та, що вже не проходить (передумову знято), відпадає.
func _revalidate() -> void:
	var old := _picks.duplicate()
	_picks.clear()
	for skill_id in old:
		if can_pick(skill_id) == SkillManager.Result.OK:
			_picks.append(skill_id)


# ── Атрибути ────────────────────────────────────────────────────────────────

func attribute_points(attribute_id: String) -> int:
	return int(_attribute_picks.get(attribute_id, 0))


func attribute_points_left() -> int:
	var total := 0
	for attribute_id: String in _attribute_picks:
		total += int(_attribute_picks[attribute_id])
	return _attributes.get_unspent() - total


func pick_attribute(attribute_id: String) -> bool:
	assert(_attributes.has_attribute(attribute_id), "SkillPlan: unknown attribute %s" % attribute_id)
	if attribute_points_left() <= 0:
		return false
	_attribute_picks[attribute_id] = attribute_points(attribute_id) + 1
	changed.emit()
	return true


func unpick_attribute(attribute_id: String) -> bool:
	var points := attribute_points(attribute_id)
	if points == 0:
		return false
	if points == 1:
		_attribute_picks.erase(attribute_id)
	else:
		_attribute_picks[attribute_id] = points - 1
	changed.emit()
	return true


# ── Прийняти / скасувати ────────────────────────────────────────────────────

## Cancel / Esc: усе позначене відкидається, нічого не витрачено.
func clear() -> void:
	if is_empty():
		return
	_picks.clear()
	_attribute_picks.clear()
	changed.emit()


## Accept: позначене витрачається в тому порядку, в якому вибране. Кожен крок уже перевірений планом, тож відмова
## SkillManager тут — помилка правил, а не гравця.
func accept() -> void:
	var picks := _picks.duplicate()
	var allocation := _attribute_picks.duplicate()
	_picks.clear()
	_attribute_picks.clear()
	for skill_id in picks:
		var verdict: SkillManager.Result = _skills.upgrade_skill(skill_id) if _skills.is_unlocked(skill_id) \
				else _skills.unlock_skill(skill_id)
		assert(verdict == SkillManager.Result.OK, "SkillPlan.accept: %s refused (%d)" % [skill_id, verdict])
	if not allocation.is_empty():
		var spent := _attributes.spend(allocation)
		assert(spent == AttributeManager.Result.OK, "SkillPlan.accept: attributes refused (%d)" % spent)
	changed.emit()
