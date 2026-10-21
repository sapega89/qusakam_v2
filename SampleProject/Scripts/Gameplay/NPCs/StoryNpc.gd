extends NpcBase
class_name StoryNpc

## Сюжетний NPC, що лишається у світі (D169): дід у Village (grandfather.tscn — його малюнок і люлька, D295).
## Пункт Quest з'являється, щойно квест видано (quest_flag), і перечитує розмову, якою його видали,
## а наприкінці — поточну ціль основного квесту (D158, D159, D161). Розмова не запускається вдруге.

## Прапорець, що ставиться, коли NPC видав квест.
@export var quest_flag: String = ""
## Id .dqd, яким квест видано.
@export var quest_dialogue: String = ""


func _ready() -> void:
	super._ready()
	# Прапорець ставиться посеред сцени (і при завантаженні сейва) — пункт мусить з'явитися одразу.
	Game.get_singleton().quest_flag_changed.connect(func(_id: String, _value: Variant): refresh_availability())


func menu_entries() -> Array:
	var entries := super.menu_entries()
	if Game.get_singleton().get_quest_flag(quest_flag):
		entries.append({"id": &"quest", "label": "Quest"})
	return entries


func _on_npc_choice(id: StringName) -> void:
	if id == &"quest":
		var tail: Array[Dictionary] = [{"speaker": "", "text": tr("Current objective: %s") % Game.get_singleton().current_objective}]
		ServiceLocatorHelper.get_service_locator().get_dialogue_manager().replay(
				"res://dialogue_quest/%s.dqd" % quest_dialogue, tail)
