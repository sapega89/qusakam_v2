extends Node2D

## Зброя в руці героя (D223, D224, D232): спрайт тієї, що в руці (Assets/Weapons/<id>.png, малює
## Scripts/Tools/draw_weapons.py), дзеркалиться за поглядом героя й тримається в його кулаці: кадри
## удару — кадри художника (Player.tscn → Attack), тож хват іде за рукавицею — стегно в стійці, пояс на
## замаху, рука вперед на ударі. Удар за ритмом референсу (assets/idle and  alter/itch light atk):
## коротка пауза замаху, різкий помах із шлейфом-півмісяцем, повернення; другий удар підряд (у межах
## COMBO_WINDOW) — знизу вгору. Колюча зброя (алебарда, кинджал) — випад з прямим шлейфом.
## Голі руки — б'є сама рукавиця героя (кадр бігу з рукою вперед), біля неї — «вибух» удару; другий
## удар серії — вище, як хук. Розмітка — Player.tscn → WeaponMount.

const TEXTURE := "res://SampleProject/Assets/Weapons/%s.png"
const SLASH_TRAIL_SCENE := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
## Точка хвату — стільки пікселів текстури від низу (як GRIP у draw_weapons.py).
const GRIP := 3
## Колючу зброю виносять уперед, решту — замахом (категорії items.json).
const THRUST := ["polearm", "dagger"]
## Де кулак героя в кадрах (px світу від центру героя, обличчям праворуч), виміряно по рукавиці:
## хода 1 — стійка, біг 4 — замах, біг 2 — удар.
const HAND_REST := Vector2(13, 21)
const HAND_WINDUP := Vector2(20, 14)
const HAND_STRIKE := Vector2(30, 6)
## Центр дуги шлейфу — на рівні плеча; «вибух» кулака — трохи перед рукавицею.
const SMEAR_CENTER := Vector2(8, 0)
const PUNCH_AT := Vector2(40, 6)
const HOOK_LIFT := 12.0
## Зовнішній радіус дуги шлейфу в текстурі (R у draw_hero_attack.py) і довжина смуги уколу.
const SMEAR_RADIUS := 32.0
const SMEAR_LENGTH := 72.0
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
var _thrust := false
var _tween: Tween
var _second := false
var _last_attack_ms := -100000


func _ready() -> void:
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
	pivot.position = HAND_REST
	pivot.rotation_degrees = _rest_angle()


func _rest_angle() -> float:
	return thrust_rest_angle if _thrust else rest_angle


func _on_player_attacked(attacker: Node, _direction: int) -> void:
	if attacker != player:
		return
	var now := Time.get_ticks_msec()
	_second = not _second and not (visible and _thrust) and now - _last_attack_ms < COMBO_WINDOW * 1000.0
	_last_attack_ms = now
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if not visible:
		# Голі руки: рукавиця героя вилітає вперед у кадрі удару — біля неї спалах
		_tween.tween_interval(windup_time)
		_tween.tween_callback(_spawn_smear.bind(&"punch"))
		return
	# Замах: зброя в кулаці біля пояса, відведена; коротка пауза — тіло в кадрі замаху
	pivot.position = HAND_WINDUP
	if _thrust:
		pivot.rotation_degrees = 90.0
	else:
		pivot.rotation_degrees = 180.0 - swing_from if _second else swing_from
	_tween.tween_interval(windup_time)
	_tween.tween_callback(_spawn_smear.bind(&"thrust" if _thrust else &"arc"))
	# Удар: кулак виноситься вперед (кадр бігу з рукою вперед), зброя — помах або випад
	var strike_at := HAND_STRIKE + (Vector2(thrust_reach, 0) if _thrust else Vector2.ZERO)
	_tween.tween_property(pivot, ^"position", strike_at, strike_time).set_ease(Tween.EASE_OUT)
	if not _thrust:
		var to := 180.0 - swing_to if _second else swing_to
		_tween.parallel().tween_property(pivot, ^"rotation_degrees", to, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_property(pivot, ^"position", HAND_REST, recover_time)
	_tween.parallel().tween_property(pivot, ^"rotation_degrees", _rest_angle(), recover_time)


## Шлейф — дитина героя (не WeaponMount: той схований з голими руками), за поглядом героя.
func _spawn_smear(kind: StringName) -> void:
	var trail: Node2D = SLASH_TRAIL_SCENE.instantiate()
	player.add_child(trail)
	var at: Vector2
	var size: float
	match kind:
		&"arc":
			at = SMEAR_CENTER
			size = _reach() / SMEAR_RADIUS
		&"thrust":
			at = HAND_STRIKE
			size = (_reach() + thrust_reach) / SMEAR_LENGTH
		_:
			at = PUNCH_AT - Vector2(0, HOOK_LIFT if _second else 0.0)
			size = 1.5  # піксель героя
	trail.position = Vector2(at.x * scale.x, at.y)
	trail.scale = Vector2(size * scale.x, size)
	trail.play(kind, _second and kind == &"arc")


## Довжина зброї в руці, px світу (спрайт ×1.5 — як герой).
func _reach() -> float:
	return sprite.texture.get_height() * sprite.scale.y
