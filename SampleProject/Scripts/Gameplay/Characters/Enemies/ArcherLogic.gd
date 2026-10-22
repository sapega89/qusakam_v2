extends EnemyLogic

## Логіка лучника (D386, design/ranged_plan.md): тримається на відстані. Далі за attack_range — підходить (CHASE
## базової логіки); ближче за keep_away — відступає (RETREAT), доки є куди: не за межу leash, не в стіну й не з краю
## уступу; між ними — стоїть і стріляє (perform_attack базової логіки: натяг із відблиском, потім стріла), лише коли
## герой на його висоті.

## Скільки px перед собою лучник перевіряє стіну й підлогу, коли відступає.
const LOOK_BEHIND := 24.0
const FLOOR_PROBE := 48.0


func handle_attack_state(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	if absf(dx) > attack_range * 1.2:
		change_state(AIState.CHASE)
		return
	velocity.x = 0
	_face_player()
	if absf(dx) < enemy.keep_away and _can_back_away(-1 if dx > 0.0 else 1):
		change_state(AIState.RETREAT)
		return
	if absf(player.global_position.y - enemy.global_position.y) > enemy.same_height:
		return
	# Темп — EnemyStats.attack_cooldown (2.2 с), як у всіх ворогів (D394)
	if attack_ready_in <= 0.0:
		attack_ready_in = enemy.attack_cooldown
		perform_attack()


## Відступ (не за HP, як у базовій логіці): спиною до героя, доки не відійде на keep_away або далі нема куди.
func handle_retreat_state(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	var away: int = -1 if dx > 0.0 else 1
	if absf(dx) >= enemy.keep_away or not _can_back_away(away):
		velocity.x = 0
		change_state(AIState.ATTACK)
		return
	velocity.x = away * speed
	if away != last_direction:
		direction_changed.emit(away)
		last_direction = away


## Після пострілу лучник лишається в бою на місці (базова логіка вирішувала б за HP — тікати чи гнатися).
func _decide_after_attack() -> void:
	pass


## Позаду ([param away]) є куди ступити: не далі leash від дому, без стіни і з підлогою під ногами.
func _can_back_away(away: int) -> bool:
	var ahead_x: float = enemy.global_position.x + away * LOOK_BEHIND
	if absf(ahead_x - home_position.x) > leash_range:
		return false
	var space := enemy.get_world_2d().direct_space_state
	var bodies: Array[RID] = []
	for body: CollisionObject2D in enemy.get_tree().get_nodes_in_group(GameGroups.ENEMIES) + [player]:
		bodies.append(body.get_rid())
	var wall := PhysicsRayQueryParameters2D.create(enemy.global_position, Vector2(ahead_x, enemy.global_position.y))
	wall.exclude = bodies
	if not space.intersect_ray(wall).is_empty():
		return false
	var foot := Vector2(ahead_x, enemy.global_position.y)
	var ground := PhysicsRayQueryParameters2D.create(foot, foot + Vector2(0, FLOOR_PROBE))
	ground.exclude = bodies
	return not space.intersect_ray(ground).is_empty()
