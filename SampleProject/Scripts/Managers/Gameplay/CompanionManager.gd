extends ManagerBase
class_name CompanionManager

## 🤝 Асисти компаньйонів (D201, D209, D515): одна кнопка викликає наступного з загону. На полі — лише один:
## поки він виступає, кнопка нікого не кличе (assist_denied — звук і трус слота), а коли піде — стартує спільний кулдаун.
## Хто відкритий — рахується з сюжетних прапорців лабораторії (вони й так у сейві), окремого списку немає.
## Охоронець біля воріт міста — разовий туторіал: CityGates пропонує його на час бою (offer_guard).
## Загін (D220): до PARTY_SIZE відкритих, порядок = черга кнопки; гравець збирає його в Status.
## Відкритий компаньйон сам у загін не стає (D464): лише доступний, доки гравець не вибере його в Status;
## кнопка кличе тільки вибраних. Зберігається в player_state.companion_party.

## Спільний кулдаун після того, як компаньйон пішов з поля, с (умовно, D515; раніше — 15 с у кожного, D209).
const COOLDOWN := 8.0
## Компаньйони лабораторії в порядку черги і прапорець, що їх відкриває (D209).
const UNLOCK_FLAGS := {
	"alisia": "lab_companion_01_complete",
	"astrit": "lab_companion_02_complete",
	"urizen": "lab_companion_03_complete",
}
## Скільки компаньйонів ходить з героєм (лор: тест межі в лабораторії, D220).
const PARTY_SIZE := 3
## Ключі перекладу (uk.po): Label перекладає сам, складені рядки — через tr().
const NAMES := {"alisia": "Alisia", "astrit": "Astrit", "urizen": "Urizen"}
const PORTRAIT_PATH := "res://SampleProject/Assets/Characters/Companions/%s/portrait.tres"
const SCENES := {
	"guard": preload("res://SampleProject/Scenes/Characters/Companions/companion_guard.tscn"),
	"alisia": preload("res://SampleProject/Scenes/Characters/Companions/companion_alisia.tscn"),
	"astrit": preload("res://SampleProject/Scenes/Characters/Companions/companion_astrit.tscn"),
	"urizen": preload("res://SampleProject/Scenes/Characters/Companions/companion_urizen.tscn"),
}

## Стан слота асисту (HUD, D515).
enum State { NONE, READY, ACTIVE, COOLDOWN }

## Секунд до готовності спільного кулдауну. Миттєвий стан, не зберігається (як перезарядки навичок).
var _cooldown := 0.0
## Хто зараз на полі (id), або "" — нікого, і його вузол.
var _active := ""
var _active_actor: Node2D
## Хто був викликаний останнім — черга йде далі від нього.
var _last_called := ""
## Охоронець біля воріт зараз доступний (CityGates, на час бою).
var _guard_offered := false


## ManagerBase вимагає: стан загону живе в player_state, кулдауни — тут, готувати нічого.
func _initialize() -> void:
	pass


func _process(delta: float) -> void:
	if _cooldown <= 0.0:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = 0.0
		EventBus.assist_ready.emit(peek_next())


func is_unlocked(companion_id: String) -> bool:
	return Game.get_singleton().get_quest_flag(UNLOCK_FLAGS[companion_id])


## Відкриті компаньйони лабораторії в порядку черги.
func get_unlocked() -> Array[String]:
	var out: Array[String] = []
	for id in UNLOCK_FLAGS:
		if is_unlocked(id):
			out.append(id)
	return out


## Кнопку можна натиснути: ніхто не на полі й спільний кулдаун минув.
func is_free() -> bool:
	return _active == "" and _cooldown <= 0.0


func is_ready(companion_id: String) -> bool:
	return is_unlocked(companion_id) and is_free()


func get_remaining_cooldown() -> float:
	return _cooldown


## Хто зараз на полі, або "".
func get_active() -> String:
	return _active


## Стан слота асисту для HUD: нікого в черзі / готовий / на полі / кулдаун.
func get_state() -> State:
	if _active != "":
		return State.ACTIVE
	if get_next_in_queue() == "":
		return State.NONE
	return State.COOLDOWN if _cooldown > 0.0 else State.READY


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


## Лабораторія: щойно поставлено прапорець [param flag] — компаньйон, якого він відкриває, тепер доступний (D464):
## у загін його бере гравець у Status. Сповіщення на екрані (D230).
func announce_unlock(flag: String) -> void:
	EventBus.companion_joined.emit(UNLOCK_FLAGS.find_key(flag))


## Кнопка асисту: охоронець, якщо його пропонують; інакше наступний у загоні за останнім викликаним.
## Повертає id того, хто вийшов, або "" — нікого. Поки хтось на полі чи йде кулдаун — відмова (assist_denied).
func call_next() -> String:
	var id := get_next_in_queue()
	if id == "":
		return ""
	if not is_free():
		EventBus.assist_denied.emit(_active if _active != "" else id)
		return ""
	if id == "guard":
		_guard_offered = false
	else:
		_last_called = id
	_send(id)
	return id


## Хто вийде на наступне натискання, або "" — нікого готового.
func peek_next() -> String:
	return get_next_in_queue() if is_free() else ""


## Хто наступний у черзі, незалежно від кулдауну (HUD показує його й під кулдауном), або "" — черга порожня.
func get_next_in_queue() -> String:
	if _guard_offered:
		return "guard"
	var party := get_party()
	var start := party.find(_last_called) + 1
	for i in party.size():
		var id: String = party[(start + i) % party.size()]
		if is_unlocked(id):
			return id
	return ""


## Нова сесія гри (Game): кулдаун, черга, хто на полі й пропозиція охоронця не переходять з минулої.
func reset() -> void:
	_cooldown = 0.0
	_active = ""
	_active_actor = null
	_last_called = ""
	_guard_offered = false


## Компаньйон забігає до героя (CompanionAssist.start) і повідомляє всіх через EventBus.
func _send(companion_id: String) -> void:
	var hero: Node2D = ServiceLocator.get_game_manager().get_current_player()
	var actor: Node2D = SCENES[companion_id].instantiate()
	# У кімнату, а не до героя (він дитина Game): при переході актор, монети й кішка зникають разом із кімнатою.
	Game.get_singleton().map.add_child(actor)
	_active = companion_id
	_active_actor = actor
	# Пішов сам або зник разом з кімнатою — поле вільне, стартує спільний кулдаун (D515).
	actor.tree_exiting.connect(_on_actor_left.bind(actor))
	actor.start(hero)
	EventBus.assist_called.emit(companion_id)


## Актор минулої сесії, що зникає з її кімнатою вже після reset(), кулдаун нової не запускає.
func _on_actor_left(actor: Node2D) -> void:
	if actor != _active_actor:
		return
	_active = ""
	_active_actor = null
	_cooldown = COOLDOWN
	EventBus.assist_left.emit()
