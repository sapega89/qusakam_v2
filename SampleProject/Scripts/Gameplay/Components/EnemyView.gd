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
## Поза збою (D264, remaining_work Art 4): анімація «stagger» сцени ворога ставить Sprite2D свій stagger.png (дві
## клітинки того ж розміру й якоря, що й sheet) і грає на весь збій; після нього вертається sheet ворога.
const STAGGER := &"stagger"

var enemy: CharacterBody2D = null
var sprite2d: Sprite2D = null
var anim_player: AnimationPlayer = null

# Поточний стан для анімацій
var current_animation: String = "idle"
var facing_direction: int = 1  # -1 left, 1 right
var _base_scale := Vector2.ONE
## Грає поза збою — інші анімації її не перебивають, доки DefaultEnemy не закінчить збій (end_stagger).
var staggered := false
var _sheet: Texture2D
var _hframes := 1
var _vframes := 1

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
	_sheet = sprite2d.texture
	_hframes = sprite2d.hframes
	_vframes = sprite2d.vframes

func update_state(new_state: EnemyLogic.AIState) -> void:
	"""Оновлює анімацію на основі стану"""
	var animation_name: String = STATE_ANIMATIONS[new_state]
	if animation_name == current_animation:
		return
	current_animation = animation_name
	if staggered:
		return  # зіграє після збою
	anim_player.play(animation_name)

## Біг (D713, EnemyLogic.pace): кадри ходи — у темпі руху.
func walk_pace(pace: float) -> void:
	if not staggered and anim_player.current_animation == &"walk":
		anim_player.speed_scale = pace

func update_direction(direction: int) -> void:
	"""Оновлює напрямок спрайта"""
	facing_direction = direction
	if direction != 0:
		sprite2d.flip_h = (direction < 0)

## [param anim] — поза замаху (бос: друга ланка серії має свою, BossEnemy.finisher_animation).
func on_attack_started(windup: float, anim: StringName = &"attack") -> void:
	anim_player.play(anim)
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

## Відблиск кольору [param kind] (EnemyLogic.TELL_*) на зброї й лінія ривка (EnemyLogic.attack_telegraphed) — на
## [param life] с, до самого удару.
func show_tell(life: float, lunge: float, reach: float, kind: StringName) -> void:
	var tell := EnemyTell.new()
	tell.setup(life, kind)
	tell.glint_at = weapon_point(facing_direction)
	var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	tell.feet = body.position + Vector2(0, body.shape.get_rect().end.y)
	tell.direction = facing_direction
	tell.line_length = lunge + reach if lunge > 0.0 else 0.0
	enemy.add_child(tell)

## Де на кадрі замаху зброя (лезо, зуби, жало, наконечник стріли — звідси й летить стріла лучника, D386), px від
## центру ворога для погляду [param direction]: meta «tell_at» Sprite2D у сцені ворога — px текстури від центру кадру
## для погляду праворуч. Ворог із кількома позами замаху (бос: charge, slam, fireball, pillar) дає на кожну свою
## meta «tell_at_<анімація>» — береться та, що грає зараз.
func weapon_point(direction: int) -> Vector2:
	var pose_key := StringName("tell_at_" + anim_player.assigned_animation)
	var at: Vector2 = sprite2d.get_meta(pose_key) if sprite2d.has_meta(pose_key) else sprite2d.get_meta(&"tell_at")
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

## Поза відновлення (D504): кадр удару застигає, доки серія не скінчиться (on_attack_ended) — героєві видно вікно.
func hold_recovery() -> void:
	if not staggered:
		anim_player.speed_scale = 0.0

func on_attack_ended() -> void:
	_offset_to(0.0, 0.06)
	if staggered:
		return  # серію зірвав збій — поза збою грає далі
	anim_player.speed_scale = 1.0
	# Повертаємося до анімації поточного стану
	if current_animation != "attack":
		anim_player.play(current_animation)

## Чи є в ворога поза збою (кадри є не в усіх: лучник — ні, тоді лишається тінь STUN_TINT).
func has_stagger_pose() -> bool:
	return anim_player.has_animation(STAGGER)

## Збій на [param duration] с: 2 кадри stagger.png розтягнуті на весь збій (кадр 1 «приголомшений» — з 30 %).
func play_stagger(duration: float) -> void:
	staggered = true
	anim_player.speed_scale = anim_player.get_animation(STAGGER).length / duration
	anim_player.play(STAGGER)
	anim_player.seek(0.0, true)

## Збій скінчився (або ворог помер): sheet назад, анімація стану (між ударами серії — idle).
func end_stagger() -> void:
	staggered = false
	sprite2d.texture = _sheet
	sprite2d.hframes = _hframes
	sprite2d.vframes = _vframes
	anim_player.speed_scale = 1.0
	anim_player.play(&"idle" if current_animation == "attack" else StringName(current_animation))
	anim_player.advance(0.0)

func get_facing_direction() -> int:
	return facing_direction
