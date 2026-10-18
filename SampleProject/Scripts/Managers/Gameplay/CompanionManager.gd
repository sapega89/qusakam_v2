extends ManagerBase
class_name CompanionManager

## 🤝 Асисти компаньйонів (D201, D209): одна кнопка викликає наступного готового, у кожного свій кулдаун.
## Хто відкритий — рахується з сюжетних прапорців лабораторії (вони й так у сейві), окремого списку немає.
## Охоронець біля воріт міста — разовий туторіал: CityGates пропонує його на час бою (offer_guard).

## Кулдаун кожного компаньйона після виклику, с (мок, D209).
const COOLDOWN := 15.0
## Компаньйони лабораторії в порядку черги і прапорець, що їх відкриває (D209).
const UNLOCK_FLAGS := {
	"alisia": "lab_companion_01_complete",
	"astrit": "lab_companion_02_complete",
	"urizen": "lab_companion_03_complete",
}
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


## Кнопка асисту: охоронець, якщо його пропонують; інакше наступний за останнім викликаним, хто готовий.
## Повертає id того, хто вийшов, або "" — нікого.
func call_next() -> String:
	if _guard_offered:
		_guard_offered = false
		_send("guard")
		return "guard"
	var unlocked := get_unlocked()
	if unlocked.is_empty():
		return ""
	var start := unlocked.find(_last_called) + 1
	for i in unlocked.size():
		var id: String = unlocked[(start + i) % unlocked.size()]
		if is_ready(id):
			_cooldowns[id] = COOLDOWN
			_last_called = id
			_send(id)
			return id
	return ""


func clear_cooldowns() -> void:
	_cooldowns.clear()


## Компаньйон забігає до героя (CompanionAssist.start) і повідомляє всіх через EventBus.
func _send(companion_id: String) -> void:
	var hero: Node2D = ServiceLocator.get_game_manager().get_current_player()
	var actor: Node2D = SCENES[companion_id].instantiate()
	hero.get_parent().add_child(actor)
	actor.start(hero)
	EventBus.assist_called.emit(companion_id)
