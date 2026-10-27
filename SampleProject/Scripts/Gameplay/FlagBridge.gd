extends StaticBody2D

## Міст над проваллям (M7, граф Каньйону: «скинути міст з того боку»): з дальнього боку важіль (Lever) ставить
## прапорець [member flag] — міст опускається, і дорога стає суцільною. Доти він стоїть сторч біля дальнього краю,
## а колізії немає: герой падає в провалля й іде в обхід (русло, акведук). Початок вузла — опора на дальньому краю.

const RAISED_ANGLE := PI / 2.0
const LOWER_TIME := 0.6

## Прапорець квесту, що опускає міст.
@export var flag: String = ""

@onready var _plank: Sprite2D = $Plank
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	assert(flag != "", "FlagBridge: flag is required (%s)" % get_path())
	var game := Game.get_singleton()
	if game.get_quest_flag(flag):
		_set_lowered()
		return
	_plank.rotation = RAISED_ANGLE
	_shape.set_deferred(&"disabled", true)
	game.quest_flag_changed.connect(_on_quest_flag_changed)


func is_lowered() -> bool:
	return not _shape.disabled


func _on_quest_flag_changed(changed: String, value: Variant) -> void:
	if changed != flag or not value:
		return
	AudioManager.play(&"door")
	var tween := create_tween()
	tween.tween_property(_plank, ^"rotation", 0.0, LOWER_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_set_lowered)


func _set_lowered() -> void:
	_plank.rotation = 0.0
	_shape.set_deferred(&"disabled", false)
