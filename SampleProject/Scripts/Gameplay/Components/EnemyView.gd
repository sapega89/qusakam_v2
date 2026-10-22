extends Node
class_name EnemyView

## 🎨 EnemyView - Відображення ворога
## Відповідає за: анімації, спрайти, візуальні ефекти
## НЕ відповідає за: AI, рух, бій, стан
## Ворог (default_enemy.tscn) — Sprite2D + AnimationPlayer з анімаціями idle / walk / attack / death.

const EnemyTell := preload("res://SampleProject/Scripts/FX/EnemyTell.gd")
## Замах (4b): поза замаху тягнеться на весь замах — кадр удару анімації attack (час у meta
## AnimationPlayer «attack_strike_time», по сцені ворога) припадає рівно на удар; тіло відхиляється назад на WINDUP_LEAN px.
const WINDUP_LEAN := 4.0
## Здригання від удару героя (4b «мало відчуття удару»): тіло стискається й відхиляється, за FLINCH_TIME вертається.
const FLINCH_TIME := 0.16

var enemy: CharacterBody2D = null
var sprite2d: Sprite2D = null
var anim_player: AnimationPlayer = null

# Поточний стан для анімацій
var current_animation: String = "idle"
var facing_direction: int = 1  # -1 left, 1 right
var _base_scale := Vector2.ONE

const STATE_ANIMATIONS := {
	EnemyLogic.AIState.IDLE: "idle",
	EnemyLogic.AIState.CHASE: "walk",
	EnemyLogic.AIState.ATTACK: "attack",
	EnemyLogic.AIState.RETREAT: "walk",
	EnemyLogic.AIState.RETURN_HOME: "walk",
}

func initialize(enemy_node: CharacterBody2D) -> void:
	enemy = enemy_node
	sprite2d = enemy.get_node(^"Sprite2D")
	anim_player = enemy.get_node(^"AnimationPlayer")
	_base_scale = sprite2d.scale

func update_state(new_state: EnemyLogic.AIState) -> void:
	"""Оновлює анімацію на основі стану"""
	var animation_name: String = STATE_ANIMATIONS[new_state]
	if animation_name == current_animation:
		return
	current_animation = animation_name
	anim_player.play(animation_name)

func update_direction(direction: int) -> void:
	"""Оновлює напрямок спрайта"""
	facing_direction = direction
	if direction != 0:
		sprite2d.flip_h = (direction < 0)

func on_attack_started(windup: float) -> void:
	anim_player.play("attack")
	anim_player.seek(0.0, true)  # наступний удар серії — поза замаху знову з початку
	anim_player.speed_scale = anim_player.get_meta(&"attack_strike_time") / windup
	_offset_to(-facing_direction * WINDUP_LEAN, windup)

## Удар пішов: поза знову в темпі анімації, тіло — вперед.
func on_strike() -> void:
	anim_player.speed_scale = 1.0
	_offset_to(0.0, 0.06)

var _lean: Tween

func _offset_to(px: float, time: float) -> void:
	if _lean:
		_lean.kill()
	_lean = create_tween()
	_lean.tween_property(sprite2d, ^"offset:x", px / _base_scale.x, time).set_ease(Tween.EASE_OUT)

## Відблиск на зброї й лінія ривка (EnemyLogic.attack_telegraphed) — на [param life] с, до самого удару.
func show_tell(life: float, lunge: float, reach: float) -> void:
	var tell := EnemyTell.new()
	tell.setup(life)
	tell.glint_at = weapon_point(facing_direction)
	var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	tell.feet = body.position + Vector2(0, body.shape.get_rect().end.y)
	tell.direction = facing_direction
	tell.line_length = lunge + reach if lunge > 0.0 else 0.0
	enemy.add_child(tell)

## Де на кадрі замаху зброя (лезо, зуби, жало, наконечник стріли — звідси й летить стріла лучника, D386), px від
## центру ворога для погляду [param direction]: meta «tell_at» Sprite2D у сцені ворога — px текстури від центру кадру
## для погляду праворуч.
func weapon_point(direction: int) -> Vector2:
	var at: Vector2 = sprite2d.get_meta(&"tell_at")
	return sprite2d.position + (sprite2d.offset + Vector2(at.x * direction, at.y)) * _base_scale

## Удар героя влучив: тіло стискається, відхиляється від удару на [param push] px і вертається.
func flinch(from_side: float, push: float) -> void:
	if _lean:
		_lean.kill()
	sprite2d.scale = Vector2(_base_scale.x * 1.15, _base_scale.y * 0.85)
	sprite2d.offset.x = -from_side * push / _base_scale.x
	_lean = create_tween().set_parallel()
	_lean.tween_property(sprite2d, ^"scale", _base_scale, FLINCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lean.tween_property(sprite2d, ^"offset:x", 0.0, FLINCH_TIME)

func on_attack_ended() -> void:
	anim_player.speed_scale = 1.0
	_offset_to(0.0, 0.06)
	# Повертаємося до анімації поточного стану
	if current_animation != "attack":
		anim_player.play(current_animation)

func get_facing_direction() -> int:
	return facing_direction
