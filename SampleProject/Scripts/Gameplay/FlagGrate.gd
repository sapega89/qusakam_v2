extends Sprite2D

## Намальована ґрата в арці (Aqueduct/README, wire-backdrops-2): стоїть, доки прапорець брами [member flag] не
## поставлено (важіль з дальнього боку), тоді піднімається, як решітка, і зникає — за нею темний прохід арки.
## Прохід замикає сама брама дверей (RoomDoor.gate_id); ґрата — лише її картинка.

const RAISE_TIME := 0.6

## Прапорець квесту, що відчиняє прохід (gates.json → брама → open_flag).
@export var flag: String = ""


func _ready() -> void:
	assert(flag != "", "FlagGrate: flag is required (%s)" % get_path())
	var game := Game.get_singleton()
	if game.get_quest_flag(flag):
		visible = false
		return
	game.quest_flag_changed.connect(_on_quest_flag_changed)


func _on_quest_flag_changed(changed: String, value: Variant) -> void:
	if changed != flag or not value:
		return
	var tween := create_tween()
	tween.tween_property(self, ^"position:y", position.y - texture.get_height() * scale.y, RAISE_TIME)
	tween.parallel().tween_property(self, ^"modulate:a", 0.0, RAISE_TIME)
	tween.tween_callback(hide)
