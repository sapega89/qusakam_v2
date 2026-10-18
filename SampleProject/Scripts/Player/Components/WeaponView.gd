extends Node2D

## Зброя в руці героя (D223): спрайт тієї, що в руці (Assets/Weapons/<id>.png, малює
## Scripts/Tools/draw_weapons.py), дзеркалиться за поглядом героя. Удар — дуга (меч, булава) або
## випад (алебарда, кинджал). У спокої опущена вперед-донизу (меч, булава) чи вперед, як піка
## (алебарда, кинджал) — не перекриває обличчя.
## Голі руки — зброї не видно. Розмітка — Player.tscn → WeaponMount.

const TEXTURE := "res://SampleProject/Assets/Weapons/%s.png"
## Точка хвату — стільки пікселів текстури від низу (як GRIP у draw_weapons.py).
const GRIP := 3
## Колючу зброю виносять уперед, решту — замахом.
const THRUST := ["polearm", "dagger"]

## Кути, градуси: 0 — вістрям угору, більше — вперед за поглядом.
@export var rest_angle := 135.0
@export var thrust_rest_angle := 80.0
@export var swing_from := -110.0
@export var swing_to := 115.0
## Випад: на скільки px уперед виходить колюча зброя.
@export var thrust_reach := 14.0
@export var strike_time := 0.12
@export var recover_time := 0.12

@onready var player: Node2D = get_parent()
@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Weapon
var _base: Vector2
var _thrust := false
var _tween: Tween


func _ready() -> void:
	_base = pivot.position
	EventBus.weapon_in_hand_changed.connect(func(_slot: String) -> void: _refresh())
	EventBus.player_attacked.connect(_on_player_attacked)
	_refresh()


func _process(_delta: float) -> void:
	scale.x = player.last_direction


func _refresh() -> void:
	var item: Dictionary = ServiceLocator.get_equipment_manager().get_weapon_item_in_hand()
	visible = not item.is_empty()
	if not visible:
		return
	sprite.texture = load(TEXTURE % item.id)
	sprite.offset = Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height() + GRIP)
	_thrust = item.category in THRUST
	pivot.position = _base
	pivot.rotation_degrees = _rest_angle()


func _on_player_attacked(attacker: Node, _direction: int) -> void:
	if attacker != player or not visible:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if _thrust:
		pivot.rotation_degrees = 90.0
		pivot.position = _base - Vector2(4, 0)
		_tween.tween_property(pivot, ^"position:x", _base.x + thrust_reach, strike_time).set_ease(Tween.EASE_OUT)
	else:
		pivot.rotation_degrees = swing_from
		_tween.tween_property(pivot, ^"rotation_degrees", swing_to, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.06)
	_tween.tween_property(pivot, ^"position", _base, recover_time)
	_tween.parallel().tween_property(pivot, ^"rotation_degrees", _rest_angle(), recover_time)


func _rest_angle() -> float:
	return thrust_rest_angle if _thrust else rest_angle
