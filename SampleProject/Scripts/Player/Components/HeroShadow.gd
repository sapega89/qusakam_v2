extends Node2D

## Тінь героя, як у MK1 (hero-shadow, Sapega 2026-10-27: «коли стрибає, то на підлозі видно кружечок»).
## Темний піксельний овал на підлозі просто під тілом: стоїть — під ногами (низ колізії, лінія ходи D559);
## у стрибку й падінні лишається на підлозі, яку знаходить промінь донизу по колізії світу, і меншає та блідне
## з висотою. Немає підлоги в межах [member reach] (прірва) або герой на драбині — тінь не малюється.
## Підскок на камінь медитації (D764) рухає лише малюнок героя, тіло лишається на підлозі — тінь теж.
## Вузол — Node2D, не Sprite2D: Cutscene._body бере перший Sprite2D героя як його тіло.

@export var texture: Texture2D
## Масштаб пікселя гри (кадри героя ×1.5).
@export var pixel_scale: float = 1.5
## Низ колізії героя відносно його origin (Player.tscn CollisionShape2D: 24×40 у (0, 4)).
@export var feet_y: float = 24.0
## Висота ніг над підлогою, де тінь найменша й найблідіша: вершина стрибка (jump_velocity² / 2g ≈ 103).
@export var top_height: float = 103.0
## Глибше цього під ногами підлоги «немає»: прірва (подвійний стрибок ≈ 206 вгору).
@export var reach: float = 240.0
@export var ground_size: float = 1.0
@export var top_size: float = 0.5
@export var ground_alpha: float = 0.6
@export var top_alpha: float = 0.35

## Тіло зрушило за кадр далі, ніж бігом чи перекатом (телепорт, інша кімната): кадр без тіні, далі — заново.
const TELEPORT_STEP := 64.0
## Скільки тіл-персонажів (вороги, NPC) промінь пропускає, шукаючи підлогу під ними.
const SKIP_BODIES := 4

@onready var hero: CharacterBody2D = get_parent()
## Висота ніг над знайденою підлогою (NAN — підлоги немає); для перевірок.
var height: float = NAN
var _last_position := Vector2.INF


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reset()


## Нова кімната чи телепорт: до наступного фізичного кадру тіні немає, щоб вона не мигнула зі старим зсувом.
func reset() -> void:
	visible = false
	height = NAN
	_last_position = Vector2.INF


func _physics_process(_delta: float) -> void:
	var at := hero.global_position
	var jumped := at.distance_to(_last_position) > TELEPORT_STEP
	_last_position = at
	var feet := at.y + feet_y
	var floor_y := feet if hero.is_on_floor() else _floor_below(at.x, feet)
	height = floor_y - feet
	visible = not jumped and not hero.mover.is_climbing() and not is_nan(floor_y)
	if not visible:
		return
	position = Vector2(0.0, floor_y - at.y)
	var t := clampf(height / top_height, 0.0, 1.0)
	scale = Vector2.ONE * pixel_scale * lerpf(ground_size, top_size, t)
	modulate.a = lerpf(ground_alpha, top_alpha, t)


## Y підлоги світу під [param x] від ніг донизу на [member reach]; NAN — немає. Персонажі (CharacterBody2D) —
## не підлога: промінь іде крізь них.
func _floor_below(x: float, feet: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, feet - 1.0), Vector2(x, feet + reach), hero.collision_mask, [hero.get_rid()])
	var space := hero.get_world_2d().direct_space_state
	for i in SKIP_BODIES + 1:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return NAN
		if not hit.collider is CharacterBody2D:
			return hit.position.y
		query.exclude += [hit.rid]
	return NAN


func _draw() -> void:
	draw_texture(texture, -texture.get_size() / 2.0)
