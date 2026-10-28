extends Node2D

## Жива дрібнота на передньому плані (D774, ambient_critters_plan): сидить на місці; коли герой підходить, злітає
## вгору й геть від нього за край кадру й зникає. Повертається (одразу сидячи, без підльоту) лише коли минуло
## return_delay секунд І місце, де вона сиділа, поза кадром — не тієї миті, як герой відвернувся.
## Час відльоту — у статичному словнику за кімнатою й шляхом вузла: переживає вихід з кімнати й повернення,
## не зберігається. Нікого не чіпає й ні з чим не стикається. Розмітка — critter_bat.tscn (висить), critter_bird,
## critter_pigeon, critter_butterfly(_blue), critter_moth (сидять, грають perch), critter_mouse (наземна: замість польоту
## біжить підлогою до своєї нори, [member hole], і зникає в ній — ambient_critters_plan, D803).
## Вузол живе або під Parallax2D (FrontDark), що сам його зсуває, або в кімнаті; global_position — там, де його видно.

## Ключ «кімната::шлях» → Time.get_ticks_msec() миті відльоту.
static var left_at: Dictionary[String, int] = {}

## Герой ближче за це по горизонталі до місця, де її видно, — злітає (план: 160 px, попередньо).
@export var scare_distance := 160.0
## І не далі за це по вертикалі (стеля печери — підлога в одному кадрі).
@export var scare_height := 320.0
## Через скільки секунд після відльоту може повернутися (план: 30 с, попередньо).
@export var return_delay := 30.0
## Політ: вбік від героя й угору, за край кадру.
@export var flight := Vector2(360.0, -560.0)
@export var flight_time := 1.4
## Порожнє — висить догори дриґом на першому кадрі fly (кажан); інакше сидить і грає цю анімацію.
@export var perch_animation: StringName = &""
## Сидить обличчям ліворуч (аркуші намальовані обличчям праворуч).
@export var perch_flip := false
## Звук злету (sound_events.json); порожнє — летить безшумно (метелик, міль).
@export var flap_sound: StringName = &"critter_flap"
## Нора наземної дрібноти (миша): вузол сцени (Marker2D з темним овалом) на підлозі; задано — біжить туди, а не летить.
@export var hole: Node2D
## Біг до нори, px/с світу.
@export var run_speed := 220.0

@onready var sprite: AnimatedSprite2D = $Sprite
## Прямокутник місця, де вона сидить; лишається на місці, коли спрайт летить.
@onready var perch: VisibleOnScreenNotifier2D = $Perch

var _key := ""
var _away := false


func _ready() -> void:
	_key = owner.scene_file_path + "::" + str(owner.get_path_to(self))
	if left_at.has(_key):
		_away = true
		sprite.hide()
	else:
		_sit()


func is_away() -> bool:
	return _away


func is_flying() -> bool:
	return sprite.visible and sprite.position != Vector2.ZERO


func _physics_process(_delta: float) -> void:
	if _away:
		if (Time.get_ticks_msec() - left_at[_key]) / 1000.0 >= return_delay and not _perch_on_screen():
			left_at.erase(_key)
			_away = false
			_sit()
		return
	if is_flying():
		return
	var hero := get_tree().get_first_node_in_group(GameGroups.PLAYER) as Node2D
	if hero == null:
		return
	var d := hero.global_position - global_position
	if absf(d.x) <= scare_distance and absf(d.y) <= scare_height:
		_fly_off(-signf(d.x) if d.x != 0.0 else 1.0)


## Кажан висить униз головою на корені: перший кадр польоту, догори дриґом, нерухомо. Решта сидить і грає perch.
func _sit() -> void:
	sprite.position = Vector2.ZERO
	sprite.show()
	if perch_animation == &"":
		sprite.flip_v = true
		sprite.flip_h = false
		sprite.animation = &"fly"
		sprite.frame = 0
		sprite.stop()
		return
	sprite.flip_v = false
	sprite.flip_h = perch_flip
	sprite.play(perch_animation)


func _fly_off(dir: float) -> void:
	if hole != null:
		_run_to_hole()
		return
	sprite.flip_v = false
	sprite.flip_h = dir < 0.0
	sprite.play(&"fly")
	if flap_sound != &"":
		get_node(^"/root/AudioManager").play(flap_sound)  # не ідентифікатор: тести компілюють цей скрипт до автолоадів
	var tween := create_tween()
	tween.tween_property(sprite, "position", Vector2(flight.x * dir, flight.y), flight_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_gone)


## Миша (D803): тікає не від героя, а в нору — біжить підлогою (run) до [member hole] і зникає в ній.
func _run_to_hole() -> void:
	sprite.flip_v = false
	sprite.flip_h = hole.position.x < 0.0
	sprite.play(&"run")
	var tween := create_tween()
	tween.tween_property(sprite, "position", hole.position, absf(hole.position.x) / run_speed)
	tween.tween_callback(_gone)


func _gone() -> void:
	sprite.stop()
	sprite.hide()
	left_at[_key] = Time.get_ticks_msec()
	_away = true


## Сповіщувач рендера в headless не спрацьовує ніколи, тож його прямокутник звіряється з кадром тут.
func _perch_on_screen() -> bool:
	var on_canvas: Rect2 = perch.get_global_transform_with_canvas() * perch.rect
	return get_viewport_rect().intersects(on_canvas)
