extends EnemyLogic

## Логіка лучника (D386, design/ranged_plan.md): тримається на відстані. Далі за attack_range — підходить (CHASE
## базової логіки); ближче за keep_away — відступає (RETREAT), доки є куди: не за межу leash, не в стіну й не з краю
## уступу; між ними — стоїть і стріляє (perform_attack базової логіки: натяг із відблиском, потім стріла), лише коли
## герой на його висоті.

## Герой іде на лучника — той відступає вже з CLOSING_KEEP × keep_away; у куті ближче за CORNERED × keep_away — обходить.
const CLOSING_KEEP := 1.3
const CORNERED := 0.6


## Лучник не підступає під час натягу.
func _creeps() -> bool:
	return false


## Натяг не обривається: стріла летить по прямій туди, куди він цілив.
func _abandons() -> bool:
	return false


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
	var away: int = -1 if dx > 0.0 else 1
	# Герой підходить (D764): відступає раніше, коли той іде на лучника; а в куті — проходить крізь героя на інший бік
	var closing: bool = player.velocity.x * signf(-dx) > AWAY_SPEED
	if absf(dx) < enemy.keep_away * (CLOSING_KEEP if closing else 1.0):
		if _can_back_away(away):
			tactic.emit(&"kite")
			change_state(AIState.RETREAT)
			return
		if absf(dx) < enemy.keep_away * CORNERED and _flank_rest <= 0.0 and not is_instance_valid(_flanker) and _side_open(-away):
			tactic.emit(&"reposition")
			_start_flank(-away)
			change_state(AIState.RETREAT)
			return
	if absf(_hero_y_at(enemy.attack_windup) - enemy.global_position.y) > enemy.same_height:
		return
	# Темп — EnemyStats.attack_cooldown, як у всіх ворогів (D394, D494), зі змінним ритмом (D764); натягують разом не більше
	# двох (жетон, D504). Герой п'є флягу чи замахується важким на виду (D713) — стріляє, не чекаючи кінця перерви.
	if (attack_ready_in <= 0.0 or _hero_opened(absf(dx))) and token_free():
		_rest_after_swing()
		if not player.is_on_floor() or absf(player.velocity.x) > AWAY_SPEED:
			tactic.emit(&"lead")  # стріляє туди, де герой буде (ArcherEnemy._tilt_to, висота — _hero_y_at)
		perform_attack()


## Відступ (не за HP, як у базовій логіці): спиною до героя, доки не відійде на keep_away або далі нема куди.
func handle_retreat_state(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	if flank_side != 0:
		_flank_step(_delta)
		if flank_side == 0:
			change_state(AIState.ATTACK)
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
