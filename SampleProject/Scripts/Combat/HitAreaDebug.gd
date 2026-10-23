extends Node2D

## Налагодження зон удару (B128): F9 у debug-збірці малює поверх світу тіло (біле), зону-ціль (жовта) і хітбокс
## (червоний; суцільний, поки живий) героя й кожного ворога — щоб звіряти з кадрами. Вузол — Game.tscn → HitAreaDebug.
## Кольори — налагоджувальні, не інтерфейс: в UITokens їх немає навмисно.

const BODY := Color(1, 1, 1, 0.8)
const HURT := Color(1, 0.85, 0.1, 0.9)
const HIT := Color(1, 0.15, 0.1, 0.9)
const HIT_LIVE := Color(1, 0.15, 0.1, 0.35)

static var enabled := false


func _unhandled_input(ev: InputEvent) -> void:
	if OS.is_debug_build() and ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F9:
		enabled = not enabled
		queue_redraw()


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for enemy in get_tree().get_nodes_in_group(GameGroups.ENEMIES):
		if enemy.is_alive():
			draw_rect(enemy.body_rect(), BODY, false, 1.0)
			draw_rect(enemy.hurt_rect(), HURT, false, 1.0)
			_draw_hitbox(enemy.hitbox)
	var hero: CombatBody2D = GameGroups.get_player()
	draw_rect(hero.body_rect(), BODY, false, 1.0)
	_draw_hitbox(hero.get_node(^"Hitbox"))


func _draw_hitbox(area: Area2D) -> void:
	var shape: CollisionShape2D = area.get_node(^"CollisionShape2D")
	var size: Vector2 = shape.shape.get_rect().size
	var rect := Rect2(shape.global_position - size / 2.0, size)
	if area.monitoring:
		draw_rect(rect, HIT_LIVE, true)
	draw_rect(rect, HIT, false, 1.0)
