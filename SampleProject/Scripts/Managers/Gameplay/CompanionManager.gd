extends ManagerBase
class_name CompanionManager

## 🤝 Асисти компаньйонів (D201, D209): одна кнопка викликає наступного готового, у кожного свій кулдаун.
## Хто відкритий — player_state.companions (зберігається, PlayerDataModule). Хто з'являється і як б'є —
## сцени асистів, зрізи 2–3 [[companion_assist_plan]]. Охоронець біля воріт — разовий туторіал, не в загоні.

## Кулдаун кожного компаньйона після виклику, с (мок, D209).
const COOLDOWN := 15.0
## Компаньйони лабораторії в порядку черги (D209).
const ROSTER: Array[String] = ["alisia", "astrit", "urizen"]

## companion_id -> секунд до готовності. Миттєвий стан, не зберігається (як перезарядки навичок).
var _cooldowns: Dictionary = {}
## Хто був викликаний останнім — черга йде далі від нього.
var _last_called := ""


func _initialize() -> void:
	pass


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
			EventBus.assist_ready.emit(id)


func unlock(companion_id: String) -> void:
	assert(companion_id in ROSTER, "CompanionManager: unknown companion '%s'" % companion_id)
	var unlocked: Array = _state().companions
	if companion_id not in unlocked:
		unlocked.append(companion_id)


func is_unlocked(companion_id: String) -> bool:
	return companion_id in _state().companions


## Відкриті компаньйони в порядку черги (ROSTER), а не в порядку відкриття.
func get_unlocked() -> Array[String]:
	return ROSTER.filter(func(id: String) -> bool: return is_unlocked(id))


func is_ready(companion_id: String) -> bool:
	return is_unlocked(companion_id) and not _cooldowns.has(companion_id)


func get_remaining_cooldown(companion_id: String) -> float:
	return float(_cooldowns.get(companion_id, 0.0))


## Кнопка асисту: наступний за останнім викликаним, хто готовий. Повертає його id або "" — нікого.
func call_next() -> String:
	var unlocked := get_unlocked()
	if unlocked.is_empty():
		return ""
	var start := unlocked.find(_last_called) + 1
	for i in unlocked.size():
		var id: String = unlocked[(start + i) % unlocked.size()]
		if is_ready(id):
			_cooldowns[id] = COOLDOWN
			_last_called = id
			EventBus.assist_called.emit(id)
			return id
	return ""


func clear_cooldowns() -> void:
	_cooldowns.clear()


func _state() -> Dictionary:
	return ServiceLocator.get_game_manager().player_state
