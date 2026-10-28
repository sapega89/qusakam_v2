extends RefCounted
class_name SkillTargeting

## Кого зачіпає навичка (D142). Зона — та сама, що в звичайної атаки: хітбокс гравця
## (Player.tscn → Hitbox), зсунутий у бік погляду так само, як у PlayerCombat._set_hitbox_active.
##   удар      — усі живі вороги в цій зоні перед героєм;
##   лікування — союзник поруч (група "allies", та сама зона в обидва боки), інакше сам герой.

const ALLIES_GROUP := &"allies"


## Прямокутник хітбокса атаки в світових координатах, у бік [param direction] (±1).
static func attack_area(player: Node2D, direction: int) -> Rect2:
	var shape: RectangleShape2D = player.get_node(^"Hitbox/CollisionShape2D").shape
	var center: Vector2 = player.combat.hitbox_center
	var offset := Vector2(center.x * direction, center.y)  # як PlayerCombat._set_hitbox_active (D203, B128)
	return Rect2(player.global_position + offset - shape.size / 2.0, shape.size)


## Живі вороги, чия зона-ціль (Hurtbox, B128 — намальоване тіло) перетинає зону удару перед героєм.
static func enemies_in_front(player: Node2D) -> Array[Node]:
	var area := attack_area(player, player.last_direction)
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		if enemy.is_alive() and area.intersects(enemy.hurt_rect()):
			out.append(enemy)
	return out


## Найближчий до героя з тих, кого б'є удар перед ним (D812: ривок ріже першого ворога на шляху), або порожньо.
static func first_in_front(player: Node2D) -> Array[Node]:
	var out: Array[Node] = []
	for enemy in enemies_in_front(player):
		if out.is_empty() or absf(enemy.global_position.x - player.global_position.x) < absf(out[0].global_position.x - player.global_position.x):
			out.clear()
			out.append(enemy)
	return out


## Живі вороги, чия зона-ціль у [param reach] px по обидва боки від тіла героя (D812: удар приземлення).
static func enemies_around(player: Node2D, reach: float) -> Array[Node]:
	var body: Rect2 = player.body_rect()
	var area := body.grow_individual(reach, 0.0, reach, 0.0)
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		if enemy.is_alive() and area.intersects(enemy.hurt_rect()):
			out.append(enemy)
	return out


## Кого б'є навичка без явної цілі: навичка руху — за move_hits, решта — усі перед героєм (D142).
static func skill_targets(definition: SkillDefinition, player: Node2D) -> Array[Node]:
	if definition.control_hits != "":
		return control_targets(definition, player)
	match definition.move_hits:
		"first":
			return first_in_front(player)
		"around":
			return enemies_around(player, definition.move_reach)
	return enemies_in_front(player)


## Ціль навички контролю (D-sv2ca1) за control_hits: first — найближчий перед героєм, front — усі перед ним до
## control_reach px від тіла, around — усі в control_reach px по обидва боки.
static func control_targets(definition: SkillDefinition, player: Node2D) -> Array[Node]:
	match definition.control_hits:
		"first":
			return first_in_front(player)
		"front":
			return enemies_ahead(player, definition.control_reach)
		"around":
			return enemies_around(player, definition.control_reach)
	assert(false, "SkillTargeting.control_targets: %s has control.hits %s" % [definition.id, definition.control_hits])
	return []


## Живі вороги, чия зона-ціль перед героєм не далі [param reach] px від передньої межі його тіла (низький розмах дуги).
static func enemies_ahead(player: Node2D, reach: float) -> Array[Node]:
	var body: Rect2 = player.body_rect()
	var front: float = body.end.x if player.last_direction > 0 else body.position.x - reach
	var area := Rect2(front, body.position.y, reach, body.size.y)
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		# Вирослий ворог (B187, ~140 px завширшки) за спиною героя зачіпає й простір перед ним; перед героєм — лише той,
		# чий центр з боку погляду
		var ahead: bool = (enemy.global_position.x - player.global_position.x) * player.last_direction > 0.0
		if enemy.is_alive() and ahead and area.intersects(enemy.hurt_rect()):
			out.append(enemy)
	return out


## Живі вороги, чия зона-ціль перетинає [param area] (зона навички на землі, v2 зріз 4).
static func enemies_in(area: Rect2) -> Array[Node]:
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		if enemy.is_alive() and area.intersects(enemy.hurt_rect()):
			out.append(enemy)
	return out


## Свої в [param area]: герой [param player] (його тіло) і союзники поруч (група allies, як heal_target).
static func allies_in(player: Node2D, area: Rect2) -> Array[Node]:
	var out: Array[Node] = []
	if area.intersects(player.body_rect()):
		out.append(player)
	for ally in player.get_tree().get_nodes_in_group(ALLIES_GROUP):
		if area.intersects(_ally_rect(ally)):
			out.append(ally)
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
