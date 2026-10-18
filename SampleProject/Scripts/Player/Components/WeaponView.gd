extends Node2D

## Зброя в руці героя (D223, D224): спрайт тієї, що в руці (Assets/Weapons/<id>.png, малює
## Scripts/Tools/draw_weapons.py), дзеркалиться за поглядом героя. Удар — за ритмом референсу
## (assets/idle and  alter/itch light atk): коротка пауза замаху, різкий помах із шлейфом-півмісяцем,
## повернення. Другий удар підряд (у межах COMBO_WINDOW) іде знизу вгору — дуга віддзеркалена.
## Колюча зброя (алебарда, кинджал) — випад уперед з прямим шлейфом. Голі руки — зброї не видно,
## лишається короткий шлейф кулака. Розмітка — Player.tscn → WeaponMount.

const TEXTURE := "res://SampleProject/Assets/Weapons/%s.png"
const SLASH_TRAIL_SCENE := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
## Точка хвату — стільки пікселів текстури від низу (як GRIP у draw_weapons.py).
const GRIP := 3
## Колючу зброю виносять уперед, решту — замахом (категорії items.json).
const THRUST := ["polearm", "dagger"]
## Зовнішній радіус дуги шлейфу в текстурі (R у draw_hero_attack.py) і довжина смуги уколу.
const SMEAR_RADIUS := 32.0
const SMEAR_LENGTH := 72.0
## Довжина «зброї» голих рук для шлейфу кулака, px світу.
const FIST_REACH := 30.0
## Центр дуги шлейфу вище за хват — на рівні плеча, як у референсі.
const SMEAR_LIFT := 8.0
## Наступний удар раніше за стільки секунд після попереднього — другий у серії.
const COMBO_WINDOW := 0.6

## Кути, градуси: 0 — вістрям угору, більше — вперед за поглядом.
@export var rest_angle := 135.0
@export var thrust_rest_angle := 80.0
@export var swing_from := -45.0
@export var swing_to := 115.0
## Випад: на скільки px уперед виходить колюча зброя.
@export var thrust_reach := 14.0
## Збігається з кадрами тіла в анімації Attack (Player.tscn): замах 0.05, удар до 0.13, повернення.
@export var windup_time := 0.05
@export var strike_time := 0.08
@export var hold_time := 0.05
@export var recover_time := 0.12

@onready var player: Node2D = get_parent()
@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Weapon
var _base: Vector2
var _thrust := false
var _tween: Tween
var _upward := false
var _last_attack_ms := -100000


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
	_thrust = not visible  # голі руки б'ють кулаком уперед
	if not visible:
		return
	sprite.texture = load(TEXTURE % item.id)
	sprite.offset = Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height() + GRIP)
	_thrust = item.category in THRUST
	pivot.position = _base
	pivot.rotation_degrees = _rest_angle()


func _rest_angle() -> float:
	return thrust_rest_angle if _thrust else rest_angle


## Довжина зброї в руці, px світу (спрайт ×1.5 — як герой).
func _reach() -> float:
	return sprite.texture.get_height() * sprite.scale.y if visible else FIST_REACH


func _on_player_attacked(attacker: Node, _direction: int) -> void:
	if attacker != player:
		return
	var now := Time.get_ticks_msec()
	_upward = not _upward and not _thrust and now - _last_attack_ms < COMBO_WINDOW * 1000.0
	_last_attack_ms = now
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# Замах: зброя відведена, коротка пауза — тіло в кадрі присіду
	if _thrust:
		pivot.rotation_degrees = 90.0
		pivot.position = _base - Vector2(6, 0)
	else:
		pivot.position = _base
		pivot.rotation_degrees = 180.0 - swing_from if _upward else swing_from
	_tween.tween_interval(windup_time)
	_tween.tween_callback(_spawn_smear)
	if _thrust:
		_tween.tween_property(pivot, ^"position:x", _base.x + thrust_reach, strike_time).set_ease(Tween.EASE_OUT)
	else:
		var to := 180.0 - swing_to if _upward else swing_to
		_tween.tween_property(pivot, ^"rotation_degrees", to, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_property(pivot, ^"position", _base, recover_time)
	_tween.parallel().tween_property(pivot, ^"rotation_degrees", _rest_angle(), recover_time)


## Шлейф — дитина героя (не WeaponMount: той схований з голими руками), у точці хвату, за поглядом.
func _spawn_smear() -> void:
	var trail: Node2D = SLASH_TRAIL_SCENE.instantiate()
	player.add_child(trail)
	trail.position = Vector2(_base.x * scale.x, _base.y - (0.0 if _thrust else SMEAR_LIFT))
	var size := _reach() / SMEAR_RADIUS if not _thrust else (_reach() + thrust_reach) / SMEAR_LENGTH
	trail.scale = Vector2(size * scale.x, size)
	trail.play(&"thrust" if _thrust else &"arc", _upward)
