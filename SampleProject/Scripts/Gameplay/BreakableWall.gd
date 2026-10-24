extends StaticBody2D

## Тріснута стіна / брила (D583: секрет за стіною, що ламається): тримає героя, доки її не розбито важким ударом
## (PlayerCombat HEAVY_STRIKE — і важкий удар, і рипост). Легкий удар лише хитає її: «щось тут є».
## Що за нею — окремі вузли кімнати, які тіло брили закриває (ItemPickup, скриня): поки брила ціла, герой до них
## не дотягується. Розбита лишається розбитою: стан кімнати "broken_<імʼя вузла>" (D152 → сейв).

signal broken

const SHAKE_PX := 3.0
const BREAK_TIME := 0.4

var is_broken := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _hurt: Area2D = $Hurt
@onready var _debris: CPUParticles2D = $Debris


func _ready() -> void:
	if was_broken():
		queue_free()
		return
	_hurt.area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var combat: PlayerCombat = Game.get_singleton().player.combat
	if is_broken or area != combat.hitbox:
		return
	# Вхід хітбокса приходить кадром-двома пізніше за його ввімкнення — важкий удар тоді вже може бути у відновленні.
	if combat.state in [PlayerCombat.State.HEAVY_STRIKE, PlayerCombat.State.HEAVY_RECOVERY]:
		smash()
	else:
		AudioManager.play(&"block")
		var tween := create_tween()
		for x: float in [SHAKE_PX, -SHAKE_PX, 0.0]:
			tween.tween_property(_sprite, ^"position:x", x, 0.05)


## Розбити: тіло зникає, уламки летять, брила тане; стан кімнати памʼятає.
func smash() -> void:
	is_broken = true
	Game.get_singleton().set_room_state(_room(), _state_key(), true)
	AudioManager.play(&"hit_heavy")
	_shape.set_deferred(&"disabled", true)
	_hurt.set_deferred(&"monitoring", false)
	_debris.emitting = true
	var tween := create_tween()
	tween.tween_property(_sprite, ^"modulate:a", 0.0, BREAK_TIME)
	tween.tween_callback(func() -> void: _sprite.visible = false)
	broken.emit()


## Розбита раніше (стан кімнати). Так питають двері за брилою (RoomDoor.cover): вузол розбитої брили ще живе
## до кінця кадру, у якому вона себе звільняє.
func was_broken() -> bool:
	return Game.get_singleton().get_room_state(_room(), _state_key(), false)


func _room() -> String:
	return get_node(^"/root/MetSys").map_data.get_room_from_scene_path(owner.scene_file_path, false)


func _state_key() -> String:
	return "broken_%s" % name
