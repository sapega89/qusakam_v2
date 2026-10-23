extends NpcBase

## Хранитель клятви в місті (BACKLOG 22, D281): жриця Неба — Paladin, відьма — Dark Knight, дервіш — Warden.
## Меню: Talk → Swear the oath → друге меню «I swear… (permanent)» / «Not yet» — єдиний вибір у грі, зроблений
## тим самим меню дій NPC, а не вікном вибору діалогу (D113). Скидання навичок тут більше немає: воно на місці медитації (D592).
## Фас — коли стоїть, молитва / читання / кружляння — коли сам (D295); профіль до героя — поки говорить (NpcBase).

## Клятва цього хранителя (skills.json → oaths).
@export var oath_id: String = ""
## Розмова після клятви саме йому (замість talk_dialogue).
@export var sworn_dialogue: String = ""
## Яке підменю підтвердження відкрите: &"oath" або &"" — звичайне меню.
var _confirming: StringName = &""
var _first_talk: String = ""


func _ready() -> void:
	_first_talk = talk_dialogue
	super._ready()
	EventBus.oath_sworn.connect(func(_id: String) -> void:
		_sync_talk()
		refresh_availability())
	_sync_talk()


func _skills() -> SkillManager:
	return ServiceLocator.get_skill_manager()


func _oath_name() -> String:
	return String(SkillDatabase.get_oath(oath_id).name)


## Після клятви цьому хранителеві він говорить інше.
func _sync_talk() -> void:
	talk_dialogue = sworn_dialogue if _skills().get_oath() == oath_id else _first_talk


## Клятви ще немає — герб (D452): її можна взяти в будь-якого з трьох хранителів, а можна й не брати.
func quest_marker() -> StringName:
	if _skills().get_oath() == "":
		return &"oath"
	return super.quest_marker()


func menu_entries() -> Array:
	var skills := _skills()
	match _confirming:
		&"oath":
			if skills.can_swear_oath(oath_id) == SkillManager.Result.LEVEL_TOO_LOW:
				return [{"id": &"not_yet", "label": tr("Come back at level %d") % int(SkillDatabase.get_oath(oath_id).level)}]
			return [
				{"id": &"swear", "label": tr("I swear: %s (permanent)") % _oath_name()},
				{"id": &"not_yet", "label": tr("Not yet")},
			]
	var entries := super.menu_entries()
	if skills.get_oath() == "":
		entries.append({"id": &"oath", "label": tr("Swear the oath")})
	return entries


func _close_npc_menu() -> void:
	_confirming = &""
	super._close_npc_menu()


func _on_npc_choice(id: StringName) -> void:
	match id:
		&"oath":
			_open_confirm(id)
		&"swear":
			_skills().swear_oath(oath_id)
			ServiceLocatorHelper.get_service_locator().get_dialogue_manager().start_dialogue(sworn_dialogue)


func _open_confirm(kind: StringName) -> void:
	_confirming = kind
	interactable.enabled = false
	npc_menu.setup(menu_entries())
	npc_menu.open()
