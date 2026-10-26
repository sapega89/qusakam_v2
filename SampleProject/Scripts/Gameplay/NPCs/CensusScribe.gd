extends NpcBase

## Писар біля міської брами (D726, D727, D728; oath_affinity_plan п. 5): після бою біля брами переписує героя —
## дивиться в очі (D587), питає ім'я, звідки й кому служить. Відповідь — клятва (SkillManager, назавжди), за будь-якого
## рівня; дерево відкривається з 5-го. «Не знаю» — питання, тоді порада: шлях, на який вказують відповіді разом із
## нахилами героя (OathLeanings). Уся розмова — один .dqd у звичайному вікні діалогу; вибори приходять сюди
## сигналами `signal|census|…`. До кінця бою біля брами писар мовчить; клятви ще немає — у нього знак (старі сейви
## без клятви приходять сюди ж).

const OathLeanings := preload("res://SampleProject/Scripts/Systems/OathLeanings.gd")
const CENSUS := "res://dialogue_quest/CityGates_Census.dqd"
## Очки, які одна відповідь писареві додає шляхові для поради (нахили важать до OathLeanings.ADVICE_WEIGHT).
const ANSWER := 4.0
const FIGHT_DONE := "city_gates_fight_complete"

var _answers: Dictionary = {}


func _ready() -> void:
	super._ready()
	if is_queued_for_deletion():
		return
	_dq().Signals.dialogue_signal.connect(_on_dialogue_signal)
	EventBus.oath_sworn.connect(func(_id: String) -> void: refresh_availability())
	load(GAME_PATH).get_singleton().quest_flag_changed.connect(func(_id: String, _value: Variant) -> void: refresh_availability())


func _skills() -> SkillManager:
	return ServiceLocator.get_skill_manager()


func _fight_done() -> bool:
	return load(GAME_PATH).get_singleton().get_quest_flag(FIGHT_DONE)


## Перепис ще треба пройти: бій скінчився, клятви немає.
func census_pending() -> bool:
	return _fight_done() and _skills().get_oath() == ""


## Розмова перепису. Повертається, коли вікно закрилось.
func start_census() -> void:
	_answers = {}
	var flags: DQFlags = _dq().Flags
	for path: String in OathLeanings.PATHS:
		flags.delete_flag("census_advice_" + path)
	flags.set_flag("census_low_level", ServiceLocator.get_xp_manager().get_level() < _oath_level())
	var dm := ServiceLocator.get_dialogue_manager()
	dm.start_dialogue(CENSUS)
	while await EventBus.dialogue_finished != CENSUS:
		pass


func _oath_level() -> int:
	return int(SkillDatabase.get_oath(OathLeanings.OATH_OF["samal"]).level)


func quest_marker() -> StringName:
	return &"oath" if census_pending() else super.quest_marker()


func menu_entries() -> Array:
	if not _fight_done():
		return []  # бій біля брами — писар під стіною, не до розмов
	if census_pending():
		return [{"id": &"census", "label": tr("Census")}]
	return super.menu_entries()


func _on_npc_choice(id: StringName) -> void:
	if id == &"census":
		start_census()


func _on_dialogue_signal(params: Array) -> void:
	if params.is_empty() or String(params[0]) != "census":
		return
	match String(params[1]):
		"answer":
			var path := String(params[2])
			_answers[path] = float(_answers.get(path, 0.0)) + ANSWER
		"advise":
			var advice := _skills().leanings.strongest(_answers)
			_dq().Flags.raise_flag("census_advice_" + advice)
		"pick":
			var verdict := _skills().swear_oath(OathLeanings.OATH_OF[String(params[2])])
			assert(verdict == SkillManager.Result.OK, "CensusScribe: oath refused (%d)" % verdict)


## Автолоад DialogueQuest — вузлом: тести компілюють NPC до автолоадів (як NpcBase з Game).
func _dq() -> Node:
	return get_node(^"/root/DialogueQuest")
