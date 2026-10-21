extends NpcBase

## Хранитель клятви в місті (BACKLOG 22, D281): жриця Неба — Paladin, відьма — Dark Knight, дервіш — Warden.
## Меню: Talk → Swear the oath → друге меню «I swear… (permanent)» / «Not yet» — єдиний вибір у грі, зроблений
## тим самим меню дій NPC, а не вікном вибору діалогу (D113). Unlearn skills — скидання навичок за монети (D282).
## Фас — коли стоїть, молитва / читання / кружляння — коли сам (D295); профіль до героя — поки говорить (NpcBase).

## Клятва цього хранителя (skills.json → oaths).
@export var oath_id: String = ""
## Розмова після клятви саме йому (замість talk_dialogue).
@export var sworn_dialogue: String = ""
## Яке підменю підтвердження відкрите: &"oath", &"respec" або &"" — звичайне меню.
var _confirming: StringName = &""
var _first_talk: String = ""


func _ready() -> void:
	_first_talk = talk_dialogue
	super._ready()
	EventBus.oath_sworn.connect(func(_id: String) -> void: _sync_talk())
	_sync_talk()


func _skills() -> SkillManager:
	return ServiceLocator.get_skill_manager()


func _oath_name() -> String:
	return String(SkillDatabase.get_oath(oath_id).name)


## Після клятви цьому хранителеві він говорить інше.
func _sync_talk() -> void:
	talk_dialogue = sworn_dialogue if _skills().get_oath() == oath_id else _first_talk


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
		&"respec":
			if skills.can_respec() == SkillManager.Result.NOT_ENOUGH_COINS:
				return [{"id": &"not_yet", "label": tr("Not enough coins (%d needed)") % skills.respec_price()}]
			return [
				{"id": &"unlearn", "label": tr("Forget every skill and attribute point for %d coins") % skills.respec_price()},
				{"id": &"not_yet", "label": tr("Not yet")},
			]
	var entries := super.menu_entries()
	if skills.get_oath() == "":
		entries.append({"id": &"oath", "label": tr("Swear the oath")})
	# D282 + D335: скидання і навичок, і очок атрибутів — пропонується, коли вкладено хоч щось.
	if skills.can_respec() != SkillManager.Result.NOTHING_TO_RESET:
		entries.append({"id": &"respec", "label": tr("Unlearn skills and attributes (%d coins)") % skills.respec_price()})
	return entries


func _close_npc_menu() -> void:
	_confirming = &""
	super._close_npc_menu()


func _on_npc_choice(id: StringName) -> void:
	match id:
		&"oath", &"respec":
			_open_confirm(id)
		&"swear":
			_skills().swear_oath(oath_id)
			ServiceLocatorHelper.get_service_locator().get_dialogue_manager().start_dialogue(sworn_dialogue)
		&"unlearn":
			_skills().respec()


func _open_confirm(kind: StringName) -> void:
	_confirming = kind
	interactable.enabled = false
	npc_menu.setup(menu_entries())
	npc_menu.open()
