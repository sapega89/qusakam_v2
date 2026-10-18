extends ManagerBase
class_name SkillManager

## 🎓 SkillManager — бойові/класові навички, Job Points і SP.
##
## Стан не дублюється: єдине джерело — player_state (PlayerStateManager),
## який уже зберігається через PlayerDataModule. Свого сховища менеджер не має.
##
## Traversal-здібності (Player.abilities, MetSys) — окрема система; тут їх немає.
##
## Розподіл відповідальності:
##   SkillManager      — перевірки (вивчено / SP / перезарядка), витрати, події
##   SkillCombatExecutor — сам бойовий ефект через наявний HealthComponent
##   UI                — лише запитує застосування, ушкоджень не рахує
## Формул ушкоджень у цьому файлі немає і бути не повинно.

## Причини відмови — щоб UI і тести не розбирали рядки.
enum Result {
	OK,
	UNKNOWN_SKILL,
	ALREADY_UNLOCKED,
	NOT_ENOUGH_JP,
	LEVEL_TOO_LOW,
	MISSING_PREREQUISITE,
	NOT_UNLOCKED,
	NOT_ACTIVE,
	NOT_ENOUGH_SP,
	ON_COOLDOWN,
	NO_TARGET,
	EFFECT_FAILED,
	INVALID_SLOT,
	NOT_ACTIVE_SKILL,
	SLOT_EMPTY,
	WRONG_WEAPON,  # D141: навичка вимагає іншої зброї в руках
	MAX_RANK,  # D150: навичка вже на найвищому рівні
}

## D149: очки навичок (JP) за кожен рівень персонажа.
const JP_PER_LEVEL := 2
## D150: рівні навички 1..20, кожен понад перший — +10 % ефекту; покращення коштує 1 очко.
const MAX_RANK := 20
const RANK_BONUS := 0.10
const UPGRADE_COST := 1

## D146: тимчасове відновлення SP за секунду.
const SP_REGEN_PER_SECOND := 1.0

var game_manager: Node = null
var skill_database: Node = null

## Виконавчий шар бою. Замінний — тести підставляють свій.
## SkillManager сам ушкоджень НЕ рахує і про бій нічого не знає.
var combat_executor: SkillCombatExecutor = SkillCombatExecutor.new()

## Рантайм-перезарядки: skill_id -> секунд лишилось.
## Навмисно НЕ зберігається: SkillDefinition.cooldown — це конфігурація,
## а миттєвий стан не входить у збережений контракт player_state.
var _cooldowns: Dictionary = {}
var _sp_regen_debt := 0.0


func _initialize() -> void:
	game_manager = ServiceLocator.get_game_manager()
	skill_database = SkillDatabase
	EventBus.player_leveled_up.connect(_on_player_leveled_up)


func _on_player_leveled_up(new_level: int, old_level: int) -> void:
	add_job_points(JP_PER_LEVEL * (new_level - old_level))


# ── Рівні навичок (D150) ────────────────────────────────────────────────────

## 0 — не вивчено; вивчена навичка має рівень 1, доки її не покращили.
func get_rank(skill_id: String) -> int:
	if not is_unlocked(skill_id):
		return 0
	return int(_state().get("skill_ranks", {}).get(skill_id, 1))


func can_upgrade(skill_id: String) -> Result:
	if not skill_database.has_skill(skill_id):
		return Result.UNKNOWN_SKILL
	if not is_unlocked(skill_id):
		return Result.NOT_UNLOCKED
	if get_rank(skill_id) >= MAX_RANK:
		return Result.MAX_RANK
	if get_job_points() < UPGRADE_COST:
		return Result.NOT_ENOUGH_JP
	return Result.OK


func upgrade_skill(skill_id: String) -> Result:
	var verdict := can_upgrade(skill_id)
	if verdict != Result.OK:
		return verdict
	spend_job_points(UPGRADE_COST)
	var rank := get_rank(skill_id) + 1
	var state := _state()
	var ranks: Dictionary = state.get("skill_ranks", {})
	ranks[skill_id] = rank
	state["skill_ranks"] = ranks
	EventBus.skill_upgraded.emit(skill_id, rank)
	return Result.OK


## Ушкодження чи лікування з урахуванням рівня: база × (1 + 10 % за кожен рівень понад перший).
func scaled(skill_id: String, base: int) -> int:
	return roundi(base * _rank_factor(skill_id))


func _rank_factor(skill_id: String) -> float:
	return 1.0 + RANK_BONUS * (get_rank(skill_id) - 1)


## Сума вивчених пасивок на показник [param stat] з урахуванням рангу (D207): Toughness → "max_health",
## Shield Block → "shield_block". Нічого не вивчено — 0.
func passive_value(stat: String) -> float:
	var total := 0.0
	for skill_id in get_unlocked_skills():
		var definition: SkillDefinition = skill_database.get_skill(skill_id)
		if not definition.is_active() and definition.passive_stat == stat:
			total += definition.passive_value * _rank_factor(skill_id)
	return total


func _process(delta: float) -> void:
	_regen_sp(delta)
	for skill_id in _cooldowns.keys():
		var remaining: float = _cooldowns[skill_id] - delta
		if remaining <= 0.0:
			_cooldowns.erase(skill_id)
		else:
			_cooldowns[skill_id] = remaining


# ── Перезарядка ─────────────────────────────────────────────────────────────

func is_skill_on_cooldown(skill_id: String) -> bool:
	return _cooldowns.has(skill_id)


func get_remaining_cooldown(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


## Скидає всі перезарядки (наприклад, при завантаженні збереження).
func clear_cooldowns() -> void:
	_cooldowns.clear()


## Повна перевірка перед застосуванням — без побічних ефектів.
func can_use_skill(skill_id: String) -> Result:
	if not skill_database.has_skill(skill_id):
		return Result.UNKNOWN_SKILL
	if not is_unlocked(skill_id):
		return Result.NOT_UNLOCKED
	var definition: SkillDefinition = skill_database.get_skill(skill_id)
	if not definition.is_active():
		return Result.NOT_ACTIVE
	if is_skill_on_cooldown(skill_id):
		return Result.ON_COOLDOWN
	if definition.sp_cost > 0 and get_current_sp() < definition.sp_cost:
		return Result.NOT_ENOUGH_SP
	if not _has_required_weapon(definition):
		return Result.WRONG_WEAPON
	return Result.OK


## Зброя саме в руці, а не просто вдягнена (D202).
func _has_required_weapon(definition: SkillDefinition) -> bool:
	if definition.required_weapons.is_empty():
		return true
	return String(_state().get("weapon_in_hand", "")) in definition.required_weapons


## SP відновлюється щосекунди (D146), без дробових списань.
func _regen_sp(delta: float) -> void:
	if get_current_sp() >= get_max_sp():
		_sp_regen_debt = 0.0
		return
	_sp_regen_debt += delta * SP_REGEN_PER_SECOND
	if _sp_regen_debt >= 1.0:
		restore_sp(int(_sp_regen_debt))
		_sp_regen_debt -= floorf(_sp_regen_debt)


func _state() -> Dictionary:
	return game_manager.player_state


func get_unlocked_skills() -> Array:
	return _state().get("unlocked_skills", [])


func is_unlocked(skill_id: String) -> bool:
	return skill_id in get_unlocked_skills()


# ── Job Points ──────────────────────────────────────────────────────────────

func get_job_points() -> int:
	return int(_state().get("job_points", 0))


## Нараховує JP. Де саме вони нараховуються — ще не вирішено, тому метод
## навмисно не викликається жодною ігровою системою.
func add_job_points(amount: int) -> int:
	if amount <= 0:
		return get_job_points()
	return _set_job_points(get_job_points() + amount)


## Списує JP. Повертає false, якщо не вистачає — у мінус піти не можна.
func spend_job_points(amount: int) -> bool:
	if amount <= 0:
		return false
	var current := get_job_points()
	if current < amount:
		return false
	_set_job_points(current - amount)
	return true


func _set_job_points(value: int) -> int:
	var state := _state()
	if state.is_empty():
		return 0
	var previous := int(state.get("job_points", 0))
	var clamped := maxi(0, value)
	state["job_points"] = clamped
	if clamped != previous:
		EventBus.job_points_changed.emit(clamped, previous)
	return clamped


# ── SP ──────────────────────────────────────────────────────────────────────

func get_current_sp() -> int:
	return int(_state().get("current_sp", 0))


func get_max_sp() -> int:
	return int(_state().get("max_sp", 0))


## Встановлює максимум SP; поточне значення підтягується під нову межу.
func set_max_sp(value: int) -> void:
	var state := _state()
	if state.is_empty():
		return
	state["max_sp"] = maxi(0, value)
	_set_current_sp(mini(get_current_sp(), get_max_sp()))


func spend_sp(amount: int) -> bool:
	if amount <= 0:
		return false
	var current := get_current_sp()
	if current < amount:
		return false
	_set_current_sp(current - amount)
	return true


func restore_sp(amount: int) -> int:
	if amount <= 0:
		return get_current_sp()
	return _set_current_sp(get_current_sp() + amount)


func _set_current_sp(value: int) -> int:
	var state := _state()
	if state.is_empty():
		return 0
	var clamped := clampi(value, 0, get_max_sp())
	var previous := int(state.get("current_sp", 0))
	state["current_sp"] = clamped
	if clamped != previous:
		EventBus.sp_changed.emit(clamped, get_max_sp())
	return clamped


# ── Розблокування ───────────────────────────────────────────────────────────

## Чи можна вивчити навичку зараз. Не змінює стан.
func can_unlock(skill_id: String) -> Result:
	if not skill_database.has_skill(skill_id):
		return Result.UNKNOWN_SKILL
	if is_unlocked(skill_id):
		return Result.ALREADY_UNLOCKED

	var definition: SkillDefinition = skill_database.get_skill(skill_id)
	if _player_level() < definition.required_level:
		return Result.LEVEL_TOO_LOW
	for prerequisite in definition.prerequisites:
		if not is_unlocked(prerequisite):
			return Result.MISSING_PREREQUISITE
	if get_job_points() < definition.jp_cost:
		return Result.NOT_ENOUGH_JP
	return Result.OK


## Вивчає навичку: перевірка → списання JP → запис у player_state → сигнал.
func unlock_skill(skill_id: String) -> Result:
	var verdict := can_unlock(skill_id)
	if verdict != Result.OK:
		return verdict

	var definition: SkillDefinition = skill_database.get_skill(skill_id)
	if definition.jp_cost > 0 and not spend_job_points(definition.jp_cost):
		return Result.NOT_ENOUGH_JP

	var state := _state()
	var unlocked: Array = state.get("unlocked_skills", [])
	unlocked.append(skill_id)
	state["unlocked_skills"] = unlocked

	EventBus.skill_unlocked.emit(skill_id)
	return Result.OK


# ── Бойовий лоадаут ─────────────────────────────────────────────────────────
#
# equipped_skills — це СПОРЯДЖЕННЯ (що зараз на панелі), окреме від
# unlocked_skills (що взагалі вивчено). Зберігається в player_state поруч,
# тому окремої системи збереження не потрібно.
#
# Кількість слотів задана Figma (Game Scene / Combat HUD 434:6556 — чотири
# Hotbar Bind), а не вигадана. Див. design/combat_hud_mapping.md

const SLOT_COUNT := 4


func _loadout() -> Array:
	var state := _state()
	if state.is_empty():
		return []
	var loadout: Array = state.get("equipped_skills", [])
	# Нормалізуємо довжину: старі збереження могли мати інший або порожній масив.
	while loadout.size() < SLOT_COUNT:
		loadout.append("")
	if loadout.size() > SLOT_COUNT:
		loadout = loadout.slice(0, SLOT_COUNT)
	state["equipped_skills"] = loadout
	return loadout


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


func get_equipped_skill(slot: int) -> String:
	if not is_valid_slot(slot):
		return ""
	return String(_loadout()[slot])


func get_equipped_skills() -> Array:
	return _loadout().duplicate()


## У якому слоті стоїть навичка, або -1.
func get_slot_of_skill(skill_id: String) -> int:
	if skill_id.is_empty():
		return -1
	return _loadout().find(skill_id)


## Ставить навичку в слот. Дозволені лише вивчені АКТИВНІ навички.
## Дублікатів не буває: якщо навичка вже в іншому слоті, вона переїжджає
## (а те, що стояло в цільовому слоті, займає звільнене місце).
func equip_skill(skill_id: String, slot: int) -> Result:
	if not is_valid_slot(slot):
		return Result.INVALID_SLOT
	if not skill_database.has_skill(skill_id):
		return Result.UNKNOWN_SKILL
	if not is_unlocked(skill_id):
		return Result.NOT_UNLOCKED
	var definition: SkillDefinition = skill_database.get_skill(skill_id)
	if not definition.is_active():
		return Result.NOT_ACTIVE_SKILL

	var loadout := _loadout()
	var existing := loadout.find(skill_id)
	if existing == slot:
		return Result.OK
	if existing != -1:
		# Переміщення: міняємо вміст слотів місцями, а не копіюємо навичку.
		loadout[existing] = loadout[slot]
	loadout[slot] = skill_id
	_commit_loadout(loadout)
	return Result.OK


func unequip_skill(slot: int) -> Result:
	if not is_valid_slot(slot):
		return Result.INVALID_SLOT
	var loadout := _loadout()
	if String(loadout[slot]).is_empty():
		return Result.SLOT_EMPTY
	loadout[slot] = ""
	_commit_loadout(loadout)
	return Result.OK


func swap_equipped_skills(slot_a: int, slot_b: int) -> Result:
	if not is_valid_slot(slot_a) or not is_valid_slot(slot_b):
		return Result.INVALID_SLOT
	if slot_a == slot_b:
		return Result.OK
	var loadout := _loadout()
	var carried = loadout[slot_a]
	loadout[slot_a] = loadout[slot_b]
	loadout[slot_b] = carried
	_commit_loadout(loadout)
	return Result.OK


func _commit_loadout(loadout: Array) -> void:
	var state := _state()
	if state.is_empty():
		return
	state["equipped_skills"] = loadout
	EventBus.equipped_skills_changed.emit(loadout.duplicate())


## Застосувати навичку зі слота панелі. Слот лише розв'язується в skill_id —
## усі перевірки й витрати робить use_skill().
func use_slot(slot: int, target: Node = null, source: Node = null) -> Result:
	if not is_valid_slot(slot):
		return Result.INVALID_SLOT
	var skill_id := get_equipped_skill(slot)
	if skill_id.is_empty():
		return Result.SLOT_EMPTY
	return use_skill(skill_id, target, source)


# ── Застосування ────────────────────────────────────────────────────────────

## Життєвий цикл активної навички:
##   перевірки → списання SP → бойовий ефект → старт перезарядки → події.
##
## Невдала спроба не завдає ушкоджень, не витрачає SP і не запускає перезарядку:
## усі перевірки виконуються ДО будь-якої зміни стану.
##
## [code]target[/code] — ціль бойового ефекту. Якщо навичка має damage > 0,
## ціль обов'язкова.
func use_skill(skill_id: String, target: Node = null, source: Node = null) -> Result:
	var verdict := can_use_skill(skill_id)
	if verdict != Result.OK:
		return _fail(skill_id, verdict)

	var definition: SkillDefinition = skill_database.get_skill(skill_id)

	var effect_source: Node = source if source != null else _default_source()

	# Ефект виконуємо до списання SP, щоб невдале застосування нічого не коштувало.
	# Без явної цілі (хотбар) — ціль за D142: усе перед героєм / союзник поруч або сам герой.
	if definition.damage > 0:
		var targets: Array[Node] = []
		if target != null:
			targets.append(target)
		else:
			targets = SkillTargeting.enemies_in_front(effect_source)
		if targets.is_empty():
			return _fail(skill_id, Result.NO_TARGET)
		var hit := false
		var amount := scaled(skill_id, definition.damage)
		for each in targets:
			if combat_executor.execute(definition, effect_source, each, amount):
				hit = true
				combat_executor.apply_status(definition, each, scaled(skill_id, definition.burn_dps))
		if not hit:
			return _fail(skill_id, Result.EFFECT_FAILED)
		# D207: ланцюг — ще й найближчий інший ворог біля першої цілі, частиною ушкодження
		if definition.chain_radius > 0.0:
			var next := SkillTargeting.chain_target(targets[0], targets, definition.chain_radius)
			if next != null:
				combat_executor.execute(definition, effect_source, next, roundi(amount * definition.chain_ratio))
	if definition.heal > 0:
		var patient: Node = target if target != null else SkillTargeting.heal_target(effect_source)
		if not combat_executor.heal(definition, patient, scaled(skill_id, definition.heal)):
			return _fail(skill_id, Result.EFFECT_FAILED)

	if definition.sp_cost > 0:
		spend_sp(definition.sp_cost)
	if definition.cooldown > 0.0:
		_cooldowns[skill_id] = definition.cooldown

	EventBus.skill_used.emit(skill_id)
	return Result.OK


func _fail(skill_id: String, reason: Result) -> Result:
	EventBus.skill_failed.emit(skill_id, int(reason))
	return reason


## Джерело ушкодження за умовчанням — поточний гравець.
func _default_source() -> Node:
	return game_manager.get_current_player()


func _player_level() -> int:
	return ServiceLocator.get_xp_manager().get_level()
