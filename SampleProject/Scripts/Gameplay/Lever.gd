extends Area2D

## Важіль короткого шляху (M7, world_structure_plan «a shortcut opened from the far side»): стоїть з дальнього боку
## замкненого проходу. E ставить прапорець квесту [member sets_flag] — його чекає брама з gates.json (RoomDoor,
## LockedDoor) або міст (FlagBridge), і вони відчиняються одразу. Потягнутий важіль лишається потягнутим: прапорець
## у сейві.

const PULLED_ANGLE := 0.9
const PULL_TIME := 0.25

## Прапорець, який ставить важіль.
@export var sets_flag: String = ""

@onready var _interactable: InteractableComponent = $Interactable
@onready var _handle: Node2D = $Handle


func _ready() -> void:
	assert(sets_flag != "", "Lever: sets_flag is required (%s)" % get_path())
	if Game.get_singleton().get_quest_flag(sets_flag):
		_set_pulled()
		return
	_interactable.interacted.connect(_on_interacted)


func is_pulled() -> bool:
	return not _interactable.enabled


func _on_interacted() -> void:
	AudioManager.play(&"door")
	_interactable.enabled = false
	create_tween().tween_property(_handle, ^"rotation", PULLED_ANGLE, PULL_TIME)
	Game.get_singleton().set_quest_flag(sets_flag, true)


func _set_pulled() -> void:
	_interactable.enabled = false
	_handle.rotation = PULLED_ANGLE
