extends EnemyLogic

## Логіка лучника (D386, design/ranged_plan.md): тримається на відстані. Далі за attack_range — підходить (CHASE
## базової логіки); ближче за keep_away — відступає (RETREAT), доки є куди: не за межу leash, не в стіну й не з краю
## уступу; між ними — стоїть і стріляє (perform_attack базової логіки: натяг із відблиском, потім стріла), лише коли
## герой на його висоті.

## Лучник починає стріляти з самого attack_range — без запасу ближнього бою (EnemyLogic.WAIT_GAP).
func engage_range() -> float:
	return attack_range


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
	# Темп — EnemyStats.attack_cooldown, як у всіх ворогів (D394, D494); натягують разом не більше двох (жетон, D504).
	# Герой п'є флягу чи замахується важким на виду (D754) — стріляє, не чекаючи кінця перерви.
	if (attack_ready_in <= 0.0 or _hero_opened(absf(dx))) and token_free():
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


## Лучник карає відкритого героя з усієї своєї дальності.
func _punish_range() -> float:
	return attack_range


## Після пострілу лучник лишається в бою на місці (базова логіка вирішувала б за HP — тікати чи гнатися).
func _decide_after_attack() -> void:
	pass


## Позаду ([param away]) є куди ступити: не далі leash від дому, без стіни і з підлогою під ногами (EnemyLogic.can_step).
func _can_back_away(away: int) -> bool:
	if absf(enemy.global_position.x + away * LOOK_AHEAD - home_position.x) > leash_range:
		return false
	return can_step(away)
