extends ManagerBase
class_name CompanionManager

## 🤝 Асисти компаньйонів (D201, D209): одна кнопка викликає наступного готового, у кожного свій кулдаун.
## Хто відкритий — рахується з сюжетних прапорців лабораторії (вони й так у сейві), окремого списку немає.
## Охоронець біля воріт міста — разовий туторіал: CityGates пропонує його на час бою (offer_guard).
## Загін (D220): до PARTY_SIZE відкритих, порядок = черга кнопки; гравець збирає його в Status,
## новий компаньйон сам стає в загін, якщо є місце. Зберігається в player_state.companion_party.

## Кулдаун кожного компаньйона після виклику, с (мок, D209).
const COOLDOWN := 15.0
## Компаньйони лабораторії в порядку черги і прапорець, що їх відкриває (D209).
const UNLOCK_FLAGS := {
	"alisia": "lab_companion_01_complete",
	"astrit": "lab_companion_02_complete",
	"urizen": "lab_companion_03_complete",
}
## Скільки компаньйонів ходить з героєм (лор: тест межі в лабораторії, D220).
const PARTY_SIZE := 3
const NAMES := {"alisia": "Алісия", "astrit": "Астрит", "urizen": "Уризен"}
const PORTRAIT_PATH := "res://SampleProject/Assets/Characters/Companions/%s/portrait.tres"
const SCENES := {
	"guard": preload("res://SampleProject/Scenes/Characters/Companions/companion_guard.tscn"),
	"alisia": preload("res://SampleProject/Scenes/Characters/Companions/companion_alisia.tscn"),
	"astrit": preload("res://SampleProject/Scenes/Characters/Companions/companion_astrit.tscn"),
	"urizen": preload("res://SampleProject/Scenes/Characters/Companions/companion_urizen.tscn"),
}

## companion_id -> секунд до готовності. Миттєвий стан, не зберігається (як перезарядки навичок).
var _cooldowns: Dictionary = {}
## Хто був викликаний останнім — черга йде далі від нього.
var _last_called := ""
## Охоронець біля воріт зараз доступний (CityGates, на час бою).
var _guard_offered := false


## ManagerBase вимагає: стан загону живе в player_state, кулдауни — тут, готувати нічого.
func _initialize() -> void:
	pass


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
			EventBus.assist_ready.emit(id)


func is_unlocked(companion_id: String) -> bool:
	return Game.get_singleton().get_quest_flag(UNLOCK_FLAGS[companion_id])


## Відкриті компаньйони лабораторії в порядку черги.
func get_unlocked() -> Array[String]:
	var out: Array[String] = []
	for id in UNLOCK_FLAGS:
		if is_unlocked(id):
			out.append(id)
	return out


func is_ready(companion_id: String) -> bool:
	return is_unlocked(companion_id) and not _cooldowns.has(companion_id)


func get_remaining_cooldown(companion_id: String) -> float:
	return float(_cooldowns.get(companion_id, 0.0))


## CityGates: на час бою біля воріт кнопка асисту кличе охоронця (туторіал, D209).
func offer_guard(offered: bool) -> void:
	_guard_offered = offered


func is_guard_offered() -> bool:
	return _guard_offered


## Загін у порядку черги (D220).
func get_party() -> Array:
	return ServiceLocator.get_game_manager().player_state.companion_party


func is_in_party(companion_id: String) -> bool:
	return companion_id in get_party()


## Status: узяти в загін (у кінець черги, якщо є місце) або залишити в таборі. Повертає, чи тепер у загоні.
func toggle_party(companion_id: String) -> bool:
	var party := get_party()
	if companion_id in party:
		party.erase(companion_id)
	elif party.size() < PARTY_SIZE and is_unlocked(companion_id):
		party.append(companion_id)
	EventBus.companion_party_changed.emit()
	return companion_id in party


## Лабораторія: щойно поставлено прапорець [param flag] — компаньйон, якого він відкриває, стає в загін, якщо є місце.
func join_on_unlock(flag: String) -> void:
	var companion_id: Variant = UNLOCK_FLAGS.find_key(flag)
	if companion_id == null:
		return
	if not is_in_party(companion_id) and get_party().size() < PARTY_SIZE:
		toggle_party(companion_id)
	EventBus.companion_joined.emit(companion_id)  # D230: сповіщення, навіть якщо загін повний (тоді — у таборі)


## Кнопка асисту: охоронець, якщо його пропонують; інакше наступний у загоні за останнім викликаним, хто готовий.
## Повертає id того, хто вийшов, або "" — нікого.
func call_next() -> String:
	var id := peek_next()
	if id == "guard":
		_guard_offered = false
	elif id != "":
		_cooldowns[id] = COOLDOWN
		_last_called = id
	if id != "":
		_send(id)
	return id


## Хто вийде на наступне натискання (для HUD), або "" — нікого готового.
func peek_next() -> String:
	if _guard_offered:
		return "guard"
	var party := get_party()
	var start := party.find(_last_called) + 1
	for i in party.size():
		var id: String = party[(start + i) % party.size()]
		if is_ready(id):
			return id
	return ""


## Хто з тих, що на кулдауні, звільниться першим (для HUD), або "".
func get_soonest_on_cooldown() -> String:
	var best := ""
	for id in _cooldowns:
		if best == "" or _cooldowns[id] < _cooldowns[best]:
			best = id
	return best


## Нова сесія гри (Game): кулдауни, черга й пропозиція охоронця не переходять з минулої.
func reset() -> void:
	_cooldowns.clear()
	_last_called = ""
	_guard_offered = false


## Компаньйон забігає до героя (CompanionAssist.start) і повідомляє всіх через EventBus.
func _send(companion_id: String) -> void:
	var hero: Node2D = ServiceLocator.get_game_manager().get_current_player()
	var actor: Node2D = SCENES[companion_id].instantiate()
	# У кімнату, а не до героя (він дитина Game): при переході актор, монети й кішка зникають разом із кімнатою.
	Game.get_singleton().map.add_child(actor)
	actor.start(hero)
	EventBus.assist_called.emit(companion_id)
