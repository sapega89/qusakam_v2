extends RefCounted
class_name SkillTargeting

## Кого зачіпає навичка (D142). Зона — та сама, що в звичайної атаки: хітбокс гравця
## (Player.tscn → Hitbox), зсунутий у бік погляду так само, як у PlayerCombat._set_hitbox_active.
##   удар      — усі живі вороги в цій зоні перед героєм;
##   лікування — союзник поруч (група "allies", та сама зона в обидва боки), інакше сам герой.

const ALLIES_GROUP := &"allies"


## Прямокутник хітбокса атаки в світових координатах, у бік [param direction] (±1).
static func attack_area(player: Node2D, direction: int) -> Rect2:
	var hitbox: Area2D = player.get_node(^"Hitbox")
	var shape: RectangleShape2D = hitbox.get_node(^"CollisionShape2D").shape
	var offset := Vector2(shape.size.x / 2.0 * direction, hitbox.position.y)  # як PlayerCombat._set_hitbox_active (D203, B128)
	return Rect2(player.global_position + offset - shape.size / 2.0, shape.size)


## Живі вороги, чия зона-ціль (Hurtbox, B128 — намальоване тіло) перетинає зону удару перед героєм.
static func enemies_in_front(player: Node2D) -> Array[Node]:
	var area := attack_area(player, player.last_direction)
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		if enemy.is_alive() and area.intersects(enemy.hurt_rect()):
			out.append(enemy)
	return out


## Ланцюг (D207): найближчий живий ворог у [param radius] від [param from], крім уже вражених.
static func chain_target(from: Node2D, exclude: Array[Node], radius: float) -> Node:
	var best: Node = null
	var best_distance := radius
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		if enemy in exclude or not enemy.is_alive():
			continue
		var distance: float = from.global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Союзник поруч (з будь-якого боку) або сам герой. По висоті — усе тіло героя, а не лише
## смужка хітбокса атаки: стоячи на землі, герой на ~23 px нижче за діда, і вузька зона
## (±16) лікувала самого героя замість діда.
static func heal_target(player: Node2D) -> Node:
	var reach := attack_area(player, 1).merge(attack_area(player, -1)).merge(_body_rect(player))
	for ally in player.get_tree().get_nodes_in_group(ALLIES_GROUP):
		if reach.intersects(_ally_rect(ally)):
			return ally
	return player


## Союзник-спрайт (дід) — його намальований прямокутник; інший вузол — лише точка позиції.
static func _ally_rect(ally: Node2D) -> Rect2:
	if ally is Sprite2D:
		var rect: Rect2 = ally.get_rect()
		return Rect2(ally.to_global(rect.position), rect.size * ally.global_scale)
	return Rect2(ally.global_position, Vector2.ZERO)


## Габарит тіла (ворога чи героя) з його CollisionShape2D (прямокутник або капсула).
static func _body_rect(body: Node2D) -> Rect2:
	var collision: CollisionShape2D = body.get_node(^"CollisionShape2D")
	var size: Vector2 = collision.shape.get_rect().size * body.global_scale
	return Rect2(collision.global_position - size / 2.0, size)
