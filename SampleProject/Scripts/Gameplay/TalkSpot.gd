extends Area2D

## Розмова з NPC, що відчиняє шлях (D562: «ключем або розмовами з НПЦ»). Стоїть поверх NPC без власного меню
## (вартовий брами, GateGuard.gd): поруч — "[E] Talk", E грає [member dialogue], а її кінець ставить
## прапорець квесту [member sets_flag] — його чекає брама з gates.json (RoomDoor або LockedDoor).
## Говорити можна знову: прапорець просто лишається.

## Розмова, res://dialogue_quest/<id>.dqd.
@export_file("*.dqd") var dialogue: String = ""
## Прапорець, який ставить кінець розмови.
@export var sets_flag: String = ""
## Говорить лише з цим прапорцем гри (порожньо — завжди): вартовий брами — після бою біля неї.
@export var after_flag: String = ""

@onready var _interactable: InteractableComponent = $Interactable


func _ready() -> void:
	assert(dialogue != "" and sets_flag != "", "TalkSpot: dialogue and sets_flag are required (%s)" % get_path())
	var game := Game.get_singleton()
	_interactable.enabled = after_flag == "" or bool(game.get_quest_flag(after_flag))
	game.quest_flag_changed.connect(_on_quest_flag_changed)
	_interactable.interacted.connect(_on_interacted)


func _on_quest_flag_changed(flag: String, value: Variant) -> void:
	if flag == after_flag and value:
		_interactable.enabled = true


func _on_interacted() -> void:
	var dm := ServiceLocator.get_dialogue_manager()
	dm.dialogue_finished.connect(_on_dialogue_finished)
	dm.start_dialogue(dialogue)


func _on_dialogue_finished(finished: String) -> void:
	if finished != dialogue:
		return
	ServiceLocator.get_dialogue_manager().dialogue_finished.disconnect(_on_dialogue_finished)
	Game.get_singleton().set_quest_flag(sets_flag, true)
