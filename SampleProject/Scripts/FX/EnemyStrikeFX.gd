extends Node

## Ефекти ударів ворогів і босів (A17; Sapega 2026-10-26: «анімації у всіх мають бути анімешними, не тільки у мене»,
## «анімації удару я мав на увазі, а не анімації персонажів»). Та сама родина, що в героя (D224, D273), з параметрами
## виду: шлейф SlashTrail (дуга, укол, вибух), пил LandingDust, іскри ParrySpark — колір, розмір і дуга з WEAPONS.
## На кадрі удару (EventBus.enemy_struck) шлейф іде по зоні удару — від центру тіла до краю хітбокса:
## - arc — шабля, сокира, булава: дуга; club — важка дуга й пил по землі там, куди впав кийок;
## - bite — клацання щелеп (дві дуги назустріч і спалах); sting — укол жалом уперед;
## - dive — смуга піке за летючим; ривок (lunge, charge) — ще й лінії швидкості позаду й пил з-під ніг на старті;
## - slam боса — важка дуга вниз і пил в обидва боки.
## Стріла лучника несе смугу сама (Arrow.Streak); куди вона влучила — дрібні іскри (EventBus.arrow_landed).
## Влучання по героєві, блок і парирування — VFXHooks (розтин, завмирання, тряска, спалах, іскри).
## Вузли створені раз (пул по колу, POOL_*), удар нічого не виділяє. Якість Low (D554) — без пилу й іскор, одна лінія
## швидкості. Живе дитиною VFXHooks; вузли — Node2D поза світом, тож координати — світові.

const SLASH_TRAIL_SCENE := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
const LANDING_DUST_SCENE := preload("res://SampleProject/Scenes/FX/LandingDust.tscn")
const PARRY_SPARK_SCENE := preload("res://SampleProject/Scenes/FX/ParrySpark.tscn")
const EnemyTell := preload("res://SampleProject/Scripts/FX/EnemyTell.gd")

const POOL_TRAILS := 16
const POOL_DUST := 6
const POOL_SPARKS := 6

## Зброя виду (enemy_type): smear — шлейф звичайного удару, color — відтінок, size — множник поверх зони удару.
const WEAPONS := {
	"melee": {smear = &"arc", color = UITokens.ENEMY_SMEAR_STEEL, size = 1.0},
	"shield": {smear = &"arc", color = UITokens.ENEMY_SMEAR_STEEL, size = 1.0},
	"tower_shield_guard": {smear = &"arc", color = UITokens.ENEMY_SMEAR_STEEL, size = 1.0},
	"bandit_brute": {smear = &"club", color = UITokens.ENEMY_SMEAR_DUST, size = 1.15},
	"tank": {smear = &"sting", color = UITokens.ENEMY_SMEAR_VENOM, size = 1.0},
	"armoured_scorpion": {smear = &"sting", color = UITokens.ENEMY_SMEAR_VENOM, size = 1.2},
	"fast": {smear = &"bite", color = UITokens.ENEMY_SMEAR_FANG, size = 1.0},
	"jackal_cursed": {smear = &"bite", color = UITokens.ENEMY_SMEAR_CURSE, size = 1.0},
	"jackal_pack_leader": {smear = &"bite", color = UITokens.ENEMY_SMEAR_FANG, size = 1.2},
	"bat": {smear = &"bite", color = UITokens.ENEMY_SMEAR_CURSE, size = 0.8},
	"fly": {smear = &"bite", color = UITokens.ENEMY_SMEAR_CURSE, size = 0.8},
	"vulture": {smear = &"dive", color = UITokens.ENEMY_SMEAR_FEATHER, size = 1.0},
	"old_vulture": {smear = &"dive", color = UITokens.ENEMY_SMEAR_FEATHER, size = 1.2},
	"archer": {smear = &"shot", color = UITokens.ENEMY_SMEAR_STEEL, size = 1.0},
	"heavy_archer": {smear = &"shot", color = UITokens.ENEMY_SMEAR_STEEL, size = 1.0},
	"lab_boss": {smear = &"arc", color = UITokens.ENEMY_SMEAR_MERC, size = 1.2},
	"scorpicore_warrior": {smear = &"arc", color = UITokens.ENEMY_SMEAR_VENOM, size = 1.3},
	"brass_collector": {smear = &"club", color = UITokens.ENEMY_SMEAR_BRASS, size = 1.2},
	"fire_djinn": {smear = &"arc", color = UITokens.ENEMY_SMEAR_DJINN, size = 1.2},
}

## Радіус дуги й довжина уколу в кадрах Assets/FX/Smear, px (як WeaponView.SMEAR_RADIUS / SMEAR_LENGTH).
const ARC_RADIUS := 32.0
const THRUST_LENGTH := 72.0
## Щелепи: дуги на висоту зони удару × JAW; лінії швидкості — LINES штук, LINE_LENGTH довжин уколу, розкид по висоті тіла.
const JAW := 0.5
const LINES := 3
const LINE_LENGTH := 1.1
const LINE_SPREAD := 0.35
## Пил: кийок ×CLUB_DUST, удар боса об землю ×SLAM_DUST; дуга slam — ×SLAM_ARC зони удару.
const CLUB_DUST := 1.4
const SLAM_DUST := 2.2
const SLAM_ARC := 1.3
## Іскри стріли — ×ARROW_SPARK від іскор парирування.
const ARROW_SPARK := 0.35

## Показано частину ефекту удару [param enemy]: &"arc", &"club", &"bite", &"sting", &"dive", &"shot", &"slam",
## &"speed_lines", &"dust" (verify_enemy_fx).
signal smear_shown(enemy: Node2D, part: StringName)
## Іскри стріли лучника (verify_enemy_fx).
signal arrow_spark_shown(at: Vector2)

var _trails: Array[SlashTrail] = []
var _dust: Array[CPUParticles2D] = []
var _sparks: Array[CPUParticles2D] = []
var _next_trail := 0
var _next_dust := 0
var _next_spark := 0
## Дуги серії чергуються: згори вниз, знизу вгору (як у героя).
var _upward := false


func _ready() -> void:
	for i in POOL_TRAILS:
		var trail: SlashTrail = SLASH_TRAIL_SCENE.instantiate()
		trail.pooled = true
		trail.name = "EnemyTrail%d" % i
		trail.visible = false
		add_child(trail)
		_trails.append(trail)
	for i in POOL_DUST:
		var dust: CPUParticles2D = LANDING_DUST_SCENE.instantiate()
		dust.name = "EnemyDust%d" % i  # не LandingDust: verify_hero_motion лічить пил приземлення героя за назвою
		dust.emitting = false
		dust.get_node(^"Left").emitting = false
		add_child(dust)
		_dust.append(dust)
	for i in POOL_SPARKS:
		var spark: CPUParticles2D = PARRY_SPARK_SCENE.instantiate()
		spark.name = "ArrowSpark%d" % i
		add_child(spark)
		_sparks.append(spark)
	EventBus.enemy_struck.connect(_on_enemy_struck)
	EventBus.arrow_landed.connect(_on_arrow_landed)


static func weapon_of(enemy: Node2D) -> Dictionary:
	var type: String = enemy.enemy_stats.enemy_type
	assert(WEAPONS.has(type), "EnemyStrikeFX: no smear for enemy_type %s" % type)
	return WEAPONS[type]


func _on_enemy_struck(enemy: Node2D, move: StringName, direction: Vector2) -> void:
	var weapon := weapon_of(enemy)
	var tint: Color = weapon.color
	var color := Color(tint, UITokens.ENEMY_SMEAR_ALPHA)
	var size: float = weapon.size
	var smear: StringName = weapon.smear
	match move:
		&"shot":
			smear_shown.emit(enemy, &"shot")  # смуга — на самій стрілі (Arrow.Streak)
			return
		&"dive":
			_dive(enemy, color, size)
			return
		&"bite":
			smear = &"bite"
		&"slam":
			_slam(enemy, direction.x, color, size)
			return
	match smear:
		&"club":
			_arc(enemy, direction.x, color, size)
			smear_shown.emit(enemy, &"club")
			_spawn_dust(enemy, _feet(enemy) + Vector2(_reach(enemy) * signf(direction.x), 0.0), CLUB_DUST)
		&"sting":
			_sting(enemy, direction.x, color, size)
		&"bite":
			_bite(enemy, direction.x, color, size)
		_:
			_arc(enemy, direction.x, color, size)
			smear_shown.emit(enemy, &"arc")
	if move == &"lunge" or move == &"charge" or (move == &"bite" and enemy.lunge > 0.0):
		_speed_lines(enemy, Vector2(direction.x, 0.0), color, size)


## Зона удару ворога у світі: хітбокс (DefaultEnemy._face_shapes уже повернув його в бік удару).
static func _strike_rect(enemy: Node2D) -> Rect2:
	var shape: CollisionShape2D = enemy.hitbox_collision
	var size: Vector2 = shape.shape.get_rect().size * shape.global_scale.abs()
	return Rect2(shape.global_position - size / 2.0, size)


static func _center(enemy: Node2D) -> Vector2:
	return enemy.body_collision.global_position


## Від центру тіла до дальнього краю зони удару, px.
static func _reach(enemy: Node2D) -> float:
	var rect := _strike_rect(enemy)
	var x := _center(enemy).x
	return maxf(absf(rect.position.x - x), absf(rect.end.x - x))


static func _feet(enemy: Node2D) -> Vector2:
	var body: CollisionShape2D = enemy.body_collision
	return Vector2(body.global_position.x, body.global_position.y + body.shape.get_rect().end.y * body.global_scale.y)


func _arc(enemy: Node2D, side: float, color: Color, size: float) -> void:
	var s := _reach(enemy) / ARC_RADIUS * size
	_upward = not _upward
	_play(&"arc", _upward, Vector2(_center(enemy).x, _strike_rect(enemy).get_center().y), Vector2(s * side, s), 0.0, color)


func _sting(enemy: Node2D, side: float, color: Color, size: float) -> void:
	var at := Vector2(_center(enemy).x, _strike_rect(enemy).get_center().y)
	_play(&"thrust", false, at, Vector2(_reach(enemy) / THRUST_LENGTH * size * side, size), 0.0, color)
	smear_shown.emit(enemy, &"sting")


## Клацання щелеп: верхня дуга донизу й нижня догори сходяться на краю зони удару, між ними — спалах.
func _bite(enemy: Node2D, side: float, color: Color, size: float) -> void:
	var rect := _strike_rect(enemy)
	var mouth := Vector2(_center(enemy).x + (_reach(enemy) - rect.size.x * 0.25) * side, rect.get_center().y)
	var s := maxf(rect.size.y, 16.0) / ARC_RADIUS * JAW * size
	_play(&"arc", false, mouth, Vector2(s * side, s), 0.0, color)
	_play(&"arc", true, mouth, Vector2(s * side, s), 0.0, color)
	_play(&"punch", false, mouth, Vector2(side, 1.0) * size, 0.0, color)
	smear_shown.emit(enemy, &"bite")


## Піке: смуга від тіла назад уздовж польоту — до героя, куди FlyingLogic і пікірує.
func _dive(enemy: Node2D, color: Color, size: float) -> void:
	var along: Vector2 = ((GameGroups.get_player() as Node2D).global_position - enemy.global_position).normalized()
	_play(&"thrust", false, _center(enemy), Vector2(LINE_LENGTH * 1.3, 1.0) * size, (-along).angle(), color)
	smear_shown.emit(enemy, &"dive")


## Лінії швидкості позаду й пил з-під ніг на старті ривка.
func _speed_lines(enemy: Node2D, direction: Vector2, color: Color, size: float) -> void:
	var height: float = enemy.body_collision.shape.get_rect().size.y * enemy.body_collision.global_scale.y
	var count := 1 if _low() else LINES
	for i in count:
		var dy := 0.0 if count == 1 else lerpf(-LINE_SPREAD, LINE_SPREAD, float(i) / (count - 1)) * height
		_play(&"thrust", false, _center(enemy) + Vector2(0.0, dy), Vector2(-direction.x * LINE_LENGTH * size, 0.5), 0.0, color)
	smear_shown.emit(enemy, &"speed_lines")
	_spawn_dust(enemy, _feet(enemy) - Vector2(direction.x * 8.0, 0.0), 1.0)


func _slam(enemy: Node2D, side: float, color: Color, size: float) -> void:
	var s := _reach(enemy) / ARC_RADIUS * size * SLAM_ARC
	_play(&"arc", false, _center(enemy), Vector2(s * side, s), 0.0, color)
	smear_shown.emit(enemy, &"slam")
	_spawn_dust(enemy, _feet(enemy), SLAM_DUST)


func _play(kind: StringName, upward: bool, at: Vector2, scale_by: Vector2, angle: float, color: Color) -> void:
	var trail := _trails[_next_trail]
	_next_trail = (_next_trail + 1) % POOL_TRAILS
	trail.global_position = at
	trail.rotation = angle
	trail.scale = scale_by
	trail.modulate = color
	trail.play(kind, upward)


## Пил в обидва боки (LandingDust: корінь і Left) у [param at] — ноги, світові px. Low — без пилу.
func _spawn_dust(enemy: Node2D, at: Vector2, scale_by: float) -> void:
	if _low():
		return
	var dust := _dust[_next_dust]
	_next_dust = (_next_dust + 1) % POOL_DUST
	dust.global_position = at
	dust.scale = Vector2.ONE * scale_by
	dust.restart()
	dust.get_node(^"Left").restart()
	smear_shown.emit(enemy, &"dust")


func _on_arrow_landed(at: Vector2, tell: StringName) -> void:
	if _low():
		return
	var spark := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % POOL_SPARKS
	spark.global_position = at
	spark.scale = Vector2.ONE * ARROW_SPARK
	spark.modulate = EnemyTell.GLINT_OUTER[tell]
	spark.restart()
	arrow_spark_shown.emit(at)


func _low() -> bool:
	return DisplayManager.graphics_quality.is_low()
