extends Area2D
class_name Arrow

## Стріла (BACKLOG 40, design/ranged_plan.md): летить по прямій уздовж [member direction], б'є ціль своєї сторони
## й застрягає в стіні. Стріла героя (D381) б'є ворогів: шкода, стійкість, відкидання — PlayerCombat.on_arrow_hit,
## відчуття удару — VFXHooks (група hero_arrows, [member strength]); заряджена прошиває ворогів (кожного раз).
## Стріла лучника (D386) б'є героя через Player.take_damage зі стрілою як джерелом: блок ламає її, парирування
## відбиває назад стрілою героя (D384), перекат пропускає крізь героя, стрибок — над нею.
## Сцени: Scenes/Combat/arrow.tscn, arrow_charged.tscn (швидкість, прошивання, сила — там).

## Стріла летить не далі за RANGE px; у стіні стирчить STICK_TIME с і за FADE_TIME зникає.
const RANGE := 720.0
const STICK_TIME := 0.6
const FADE_TIME := 0.2
const HERO_ARROWS := &"hero_arrows"

@export var speed: float = 900.0
## Заряджена стріла героя йде крізь ворогів (кожного влучає раз) і зупиняється лише об стіну.
@export var pierce: bool = false
## Сила влучання для VFXHooks.HIT_FEEL: 0 — легкий, 2 — важкий (заряджений постріл).
@export var strength: int = 0

var direction: int = 1
## true — стріла героя (б'є ворогів), false — лучника (б'є героя).
var hero_side: bool = true
var damage: int = 0
var poise: int = 1
var knockback: float = 0.0
## Скільки збиває героя влучання стріли лучника (його EnemyStats.stagger_time), с.
var stagger_time: float = 0.0
## Хто стріляв: герой (його PlayerCombat рахує стійкість і пасивки) або лучник.
var shooter: Node2D
var _flown: float = 0.0
var _hit: Array[Node] = []
var _stuck: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_face()
	if hero_side:
		add_to_group(HERO_ARROWS)


func _face() -> void:
	$Sprite2D.flip_h = direction < 0
	$CollisionShape2D.position.x = absf($CollisionShape2D.position.x) * direction


func _physics_process(delta: float) -> void:
	if _stuck:
		return
	position.x += direction * speed * delta
	_flown += speed * delta
	if _flown >= RANGE:
		_fade(0.0)


## Скільки збиває героя це влучання (Player.take_damage, D264: збій і пробиття блоку питають джерело).
func hit_stagger_time() -> float:
	return stagger_time


## Герой парирував стрілу (D384): вона розвертається й летить назад стрілою героя — легкою, з тією ж шкодою.
func parried(by: Node2D) -> void:
	hero_side = true
	add_to_group(HERO_ARROWS)
	direction = -direction
	shooter = by
	poise = PlayerCombat.POISE_LIGHT
	strength = 0
	_flown = 0.0
	_hit.clear()
	_face()


func _on_body_entered(body: Node2D) -> void:
	if _stuck or body in _hit:
		return
	var target := GameGroups.ENEMIES if hero_side else GameGroups.PLAYER
	if body.is_in_group(target):
		_strike(body)
	elif not body is CharacterBody2D:
		_stick()  # стіна, підлога, скеля; герой, NPC і чужі вороги стрілу не зупиняють


func _strike(body: Node2D) -> void:
	if hero_side:
		_hit.append(body)
		body.take_damage(damage, self)
		shooter.combat.on_arrow_hit(body, damage, poise, knockback, global_position.x - direction)
		if not pierce:
			queue_free()
		return
	# Перекат (невразливість) — стріла пролітає крізь героя
	if body.is_invulnerable:
		return
	_hit.append(body)
	body.take_damage(damage, self)
	if not hero_side:
		queue_free()  # влучила чи зламалась об блок; парирована — уже стріла героя й летить назад


func _stick() -> void:
	_stuck = true
	set_deferred(&"monitoring", false)
	AudioManager.play(&"arrow_wall")
	_fade(STICK_TIME)


func _fade(delay: float) -> void:
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, ^"modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
