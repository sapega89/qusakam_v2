extends Node
class_name EnemyView

## 🎨 EnemyView - Відображення ворога
## Відповідає за: анімації, спрайти, візуальні ефекти
## НЕ відповідає за: AI, рух, бій, стан
## Ворог (default_enemy.tscn) — Sprite2D + AnimationPlayer з анімаціями idle / walk / attack / death.

var enemy: CharacterBody2D = null
var sprite2d: Sprite2D = null
var anim_player: AnimationPlayer = null

# Поточний стан для анімацій
var current_animation: String = "idle"
var facing_direction: int = 1  # -1 left, 1 right

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

func on_attack_started() -> void:
	anim_player.play("attack")

func on_attack_ended() -> void:
	# Повертаємося до анімації поточного стану
	if current_animation != "attack":
		anim_player.play(current_animation)

func get_facing_direction() -> int:
	return facing_direction
