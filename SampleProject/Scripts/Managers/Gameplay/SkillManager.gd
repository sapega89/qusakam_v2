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
}

var game_manager: Node = null
var skill_database: Node = null

## Виконавчий шар бою. Замінний — тести підставляють свій.
## SkillManager сам ушкоджень НЕ рахує і про бій нічого не знає.
var combat_executor: SkillCombatExecutor = SkillCombatExecutor.new()

## Рантайм-перезарядки: skill_id -> секунд лишилось.
## Навмисно НЕ зберігається: SkillDefinition.cooldown — це конфігурація,
## а миттєвий стан не входить у збережений контракт player_state.
var _cooldowns: Dictionary = {}


func _initialize() -> void:
	var service_locator := ServiceLocatorHelper.get_service_locator()
	if service_locator:
		if service_locator.has_method("get_game_manager"):
			game_manager = service_locator.get_game_manager()
	skill_database = _resolve_skill_database()
	if skill_database == null:
		push_warning("⚠️ SkillManager: SkillDatabase not found")


func _process(delta: float) -> void:
	if _cooldowns.is_empty():
		return
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
	if skill_database == null or not skill_database.has_skill(skill_id):
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
	return Result.OK


func _resolve_skill_database() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree and tree.root:
		return tree.root.get_node_or_null(^"SkillDatabase")
	return null


# ── Доступ до стану ─────────────────────────────────────────────────────────

func _state() -> Dictionary:
	if game_manager and "player_state" in game_manager:
		return game_manager.player_state
	return {}


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
	if skill_database == null or not skill_database.has_skill(skill_id):
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

	# Ушкоджувальна навичка без цілі — відмова ще до витрат.
	if definition.damage > 0 and target == null:
		return _fail(skill_id, Result.NO_TARGET)

	# Ефект виконуємо до списання SP, щоб невдале застосування нічого не коштувало.
	if definition.damage > 0:
		var effect_source: Node = source if source != null else _default_source()
		if not combat_executor.execute(definition, effect_source, target):
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
	if game_manager and game_manager.has_method("get_current_player"):
		return game_manager.get_current_player()
	return null


func _player_level() -> int:
	var service_locator := ServiceLocatorHelper.get_service_locator()
	if service_locator and service_locator.has_method("get_xp_manager"):
		var xp_manager = service_locator.get_xp_manager()
		if xp_manager and xp_manager.has_method("get_level"):
			return int(xp_manager.get_level())
	return 1
