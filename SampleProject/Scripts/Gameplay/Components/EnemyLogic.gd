extends Node
class_name EnemyLogic

## 🧠 EnemyLogic - Логіка симуляції ворога
## Відповідає за: AI, рух, бій, стан
## НЕ відповідає за: анімації, спрайти, візуальні ефекти
## Дотримується принципу розділення Simulation & View
##
## Бій (D504, design/combat_critique_2026-10-23.md §B): кожен удар має підказку свого кольору (tell_kind) за TELL_LEAD с
## до удару; показана підказка — удар відбудеться, зірвати його може лише збій (вичерпана стійкість, парирування).
## Після серії — поза відновлення (вікно для відповіді героя), потім ворог відходить (back_off). Між ударами він
## тримається трохи поза досяжністю й переступає, а заходить бити, лише коли ударів одночасно менше за max_attackers().

# Посилання на ворога
var enemy: CharacterBody2D = null

# Стан руху
var velocity: Vector2 = Vector2.ZERO
var is_on_floor: bool = false

# AI стан
enum AIState {
	IDLE,
	CHASE,
	ATTACK,
	RETREAT,  # Відхід після серії (back_off); у лучника — відступ від героя
	RETURN_HOME,  # Повернення на позицію спавну (leash)
}

var current_state: AIState = AIState.IDLE
var state_timer: float = 0.0

# Тактичні параметри
var speed: float = 70.0
var detection_range: float = 300.0
var attack_range: float = 100.0
var chase_range: float = 400.0
var leash_range: float = 600.0  # Максимальна відстань від спавну по X
var return_home_speed: float = 55.0
var lost_player_timer: float = 0.0
var max_lost_time: float = 3.0

# Кулдауни
var chase_cooldown: float = 2.0  # Кулдаун перед початком переслідування
var chase_cooldown_timer: float = 0.0

# Бойові параметри
var base_damage: float = 10.0
var damage: float = 10.0
## Скільки ще секунд ігрового часу до наступного удару (0 — можна бити). Темп — EnemyStats.attack_cooldown
## ворога (D394, D494). Рахується з delta фізики, а не з годинника: стоп-кадр, сповільнення й пауза відсувають і наступний удар.
var attack_ready_in: float = 0.0
## Іде замах, удар або відновлення після серії (D198): ворог стоїть, рішень не приймає.
var is_attacking: bool = false
## Іде саме замах до підказки: ворог розвертається за героєм. Після підказки напрямок зафіксовано.
var winding_up: bool = false
## Підказку показано (D504, B134): удар відбудеться — відкидання й оглушення його вже не зривають, лише збій.
var committed: bool = false
## Поза відновлення після серії (D504): ворог стоїть у позі удару — вікно для відповіді героя.
var recovering: bool = false

## Підказка удару (D504): за TELL_LEAD с до удару, свого кольору й звуку. Парирування — як і було, блок в останні
## PlayerCombat.PARRY_WINDOW с до удару: спалах попереджає, а не є дедлайном.
const TELL_LEAD := 0.45
## Що робити з ударом: білий — блокувати, жовтий — парирувати, червоний — лише ухилитись (перекат, стрибок, відійти).
const TELL_BLOCK := &"block"
const TELL_PARRY := &"parry"
const TELL_DODGE := &"dodge"
## Підказка удару, що зараз іде (PlayerCombat.guard_against питає її через DefaultEnemy.incoming_tell).
var tell_kind: StringName = TELL_PARRY
## Скільки живе підказка цього удару: TELL_LEAD або весь замах, якщо він коротший.
var tell_time: float = TELL_LEAD

## Відкидання (D203): за KNOCKBACK_TIME ворог проїжджає задану відстань, AI чекає.
const KNOCKBACK_TIME := 0.15
var knockback_left: float = 0.0
var knockback_speed: float = 0.0
## Оглушення (D207): ворог стоїть, а замах, що вже йде, не закінчиться ударом.
var stun_left: float = 0.0
## Замах зірвано (збій, або відкидання до підказки) — удару не буде.
var attack_broken: bool = false
## Комбо (D265): наступні удари серії — з коротшим замахом (але не коротшим за підказку, D494); останній удар серії —
## фінішер, збиває героя довше.
const COMBO_WINDUP := 0.5
const FINISHER_STAGGER := 0.6
var finisher: bool = false
## Замах удару, що зараз іде (EnemyView тягне позу замаху саме на нього).
var swing_windup: float = 0.0

## Жетон удару (D504, critique §B «group rules»): замахуються одночасно не більше max_attackers() ворогів, решта чекає
## поза досяжністю. Бос жетона не бере й не займає.
const EnemyVariety = preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
static var _attackers: Array[EnemyLogic] = []

## Між ударами (D504): тримається на attack_range + WAIT_GAP від героя й переступає на ±SHUFFLE px.
const WAIT_GAP := 40.0
const SHUFFLE := 12.0
const SPACING_SPEED := 0.5
## Помічає героя (B139) лише на своєму поверсі (ноги на ±NOTICE_DY px) або коли бачить його (промінь без стін).
const NOTICE_DY := 64.0
## Крок уперед можливий (B139): без стіни на LOOK_AHEAD px за краєм тіла й з підлогою не глибше FLOOR_PROBE px під ногами.
const LOOK_AHEAD := 8.0
const FLOOR_PROBE := 16.0
## Відхід після серії триває не довше за back_off / speed + BACK_OFF_SLACK с.
const BACK_OFF_SLACK := 0.4
## Біг до бою (D713): далі за RUN_FROM × engage_range від героя ворог біжить у RUN_PACE раз швидше за крок — група
## бою приходить разом, а не по одному, поки герой добиває переднього.
const RUN_PACE := 1.8
const RUN_FROM := 2.5
## На удар (з engage_range на attack_range) ворог заходить у STEP_IN_PACE раз швидше за крок.
const STEP_IN_PACE := 1.4
## Темп ходи зараз: 1 — крок, RUN_PACE — біг (EnemyView пришвидшує анімацію walk так само).
var pace: float = 1.0
var _shuffle_t: float = 0.0
## Скільки ударів героя ворог прийняв, чекаючи перерви (provoked).
var _hits_waiting: int = 0
var _back_off_from: float = 0.0

# Посилання на гравця
var player: Node = null
var player_in_area: bool = false
var last_direction: int = 0  # Для відстеження зміни напрямку

# Позиція "дому" (спавн), щоб ворога можна було пробігати повз без arena-lock
var home_position: Vector2 = Vector2.ZERO

# Сигнали для View
signal state_changed(new_state: AIState)
signal direction_changed(direction: int)  # -1 left, 1 right, 0 none
signal attack_started()
## Підказка удару (D504): спалах кольору tell_kind за TELL_LEAD до удару — напрямок уже зафіксовано.
signal attack_telegraphed()
## Серія скінчилась, ворог у позі відновлення на [param time] с.
signal recovery_started(time: float)
signal attack_ended()
signal player_detected()
signal player_lost()

func _ready():
	"""Ініціалізація EnemyLogic"""
	DebugLogger.info("EnemyLogic: Initialized", "EnemyLogic")

func initialize(enemy_node: CharacterBody2D):
	"""Ініціалізує EnemyLogic з посиланням на ворога"""
	enemy = enemy_node

	var params: Dictionary = enemy.get_enemy_params()
	speed = params["speed"]
	detection_range = params["detection_range"]
	attack_range = params["attack_range"]
	chase_range = params["chase_range"]
	base_damage = params["base_damage"]
	damage = base_damage
	leash_range = params["leash_range"]
	return_home_speed = params["return_home_speed"]

	# Запам'ятовуємо позицію спавну
	home_position = enemy.global_position

	# Знаходимо гравця через GameGroups
	player = GameGroups.get_player()

	DebugLogger.info("EnemyLogic: Initialized with enemy: %s" % enemy.name, "EnemyLogic")

func _exit_tree() -> void:
	_release_token()

func process_physics(delta: float) -> Vector2:
	"""Обробляє фізику та повертає нову швидкість"""
	is_on_floor = enemy.is_on_floor()

	state_timer += delta
	chase_cooldown_timer += delta
	attack_ready_in = maxf(attack_ready_in - delta, 0.0)

	process_ai(delta)
	return velocity

func process_ai(delta: float):
	"""Обробляє AI ворога"""
	if enemy.is_dead:
		velocity = Vector2.ZERO
		return

	if knockback_left > 0.0:
		knockback_left -= delta
		velocity.x = knockback_speed
		return

	if stun_left > 0.0:
		stun_left -= delta
		velocity.x = 0
		return

	if not player or not is_instance_valid(player):
		player = GameGroups.get_player()

	# Атака вже почалась — доводимо її до кінця на місці
	if is_attacking:
		velocity.x = 0
		if winding_up:
			_face_player()
		return

	match current_state:
		AIState.IDLE:
			handle_idle_state(delta)
		AIState.CHASE:
			handle_chase_state(delta)
		AIState.ATTACK:
			handle_attack_state(delta)
		AIState.RETREAT:
			handle_retreat_state(delta)
		AIState.RETURN_HOME:
			handle_return_home_state(delta)

func handle_idle_state(_delta: float):
	"""Обробляє стан очікування"""
	velocity.x = 0

	# Якщо ворог з якихось причин від'їхав від спавну — повертаємо його назад
	if abs(enemy.global_position.x - home_position.x) > 10.0:
		change_state(AIState.RETURN_HOME)
		return

	if chase_cooldown_timer < chase_cooldown:
		return

	# Переслідування — за відстанню по X, і лише героя на своєму поверсі чи на виду (B139).
	if player and is_instance_valid(player):
		var distance_x = abs(player.global_position.x - enemy.global_position.x)
		if distance_x <= detection_range and can_notice(player):
			chase_cooldown_timer = 0.0
			change_state(AIState.CHASE)

func handle_chase_state(delta: float):
	"""Обробляє стан переслідування"""
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return

	var distance_to_player_x = abs(player.global_position.x - enemy.global_position.x)

	# Leash: якщо відійшли надто далеко від дому — припиняємо переслідування і йдемо назад
	if abs(enemy.global_position.x - home_position.x) > leash_range:
		_give_up()
		return

	# Герой далеко або на іншому поверсі за стіною (B139): стоїмо й чекаємо max_lost_time, потім додому.
	var noticed := can_notice(player)
	if distance_to_player_x > chase_range or not noticed:
		lost_player_timer += delta
		if lost_player_timer > max_lost_time:
			_give_up()
			return
	else:
		lost_player_timer = 0.0
	if not noticed:
		velocity.x = 0
		return

	if distance_to_player_x <= engage_range():
		change_state(AIState.ATTACK)
		return

	var direction_x: float = player.global_position.x - enemy.global_position.x
	pace = RUN_PACE if distance_to_player_x > engage_range() * RUN_FROM else 1.0
	if abs(direction_x) <= 5.0:
		velocity.x = 0
	else:
		_walk(1 if direction_x > 0 else -1, speed * pace)

func _give_up() -> void:
	change_state(AIState.RETURN_HOME)
	player_lost.emit()
	chase_cooldown_timer = 0.0
	lost_player_timer = 0.0

## Звідки ворог починає бій (стан ATTACK): трохи поза своєю досяжністю.
func engage_range() -> float:
	return attack_range + WAIT_GAP

## Бій ближнього ворога (D504): готовий і є вільний жетон — заходить на attack_range і б'є; інакше чекає поза
## досяжністю й переступає. Герой відкрився (важкий замах чи каст поруч) — б'є одразу, не чекаючи перерви.
func handle_attack_state(delta: float):
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	var adx := absf(dx)
	if adx > engage_range() * 1.2 or not can_notice(player):
		change_state(AIState.CHASE)
		return
	_face_player()
	var toward := 1 if dx > 0.0 else -1
	if (attack_ready_in <= 0.0 or _hero_opened(adx)) and token_free():
		pace = 1.0 if adx <= attack_range else STEP_IN_PACE  # D713: заходить бити швидше — не бреде під клинком героя
		if adx <= attack_range:
			attack_ready_in = enemy.attack_cooldown
			perform_attack()
		else:
			_step(toward, speed * pace)
		return
	pace = 1.0
	_hold_spacing(dx, delta)

## Тримається на engage_range від героя, переступаючи на ±SHUFFLE px: ближче — задкує, далі — підходить (повільно).
func _hold_spacing(dx: float, delta: float) -> void:
	_shuffle_t += delta
	var err: float = absf(dx) - engage_range() - sin(_shuffle_t * 2.0) * SHUFFLE
	var toward := 1 if dx > 0.0 else -1
	if err < -4.0:
		_step(-toward, speed * SPACING_SPEED)
	elif err > 4.0:
		_step(toward, speed * SPACING_SPEED)
	else:
		velocity.x = 0

## Герой відкрився поруч (critique §B): замах важкого удару чи навички (і фляга — Healing Palm, D504) або зілля
## (D713) у досяжності _punish_range().
func _hero_opened(adx: float) -> bool:
	return adx <= _punish_range() and player.combat.state in [PlayerCombat.State.HEAVY_WINDUP, PlayerCombat.State.CAST_WINDUP,
			PlayerCombat.State.DRINK]

## Звідки ворог карає відкритого героя: ближній — з півтори attack_range.
func _punish_range() -> float:
	return attack_range * 1.5

## Удар героя влучив (D713): поки ворог чекає перерви між серіями чи відходить після серії, enemy.answer_hits таких
## ударів скасовують решту перерви — він б'є у відповідь (з тим самим замахом і підказкою).
func provoked() -> void:
	if enemy.answer_hits <= 0 or is_attacking or enemy.is_dead:
		return
	_hits_waiting += 1
	if _hits_waiting >= enemy.answer_hits:
		attack_ready_in = 0.0
		if current_state == AIState.RETREAT:
			change_state(AIState.ATTACK)  # відходив після серії — розвертається й б'є

## Після серії (D504): відходить на back_off px, якщо є куди; tank (back_off 0) лишається на місці.
func _decide_after_attack() -> void:
	if current_state != AIState.ATTACK or enemy.is_dead:
		return
	if enemy.back_off > 0.0 and player and is_instance_valid(player):
		_back_off_from = enemy.global_position.x
		change_state(AIState.RETREAT)

## Відхід після серії: задкує обличчям до героя, доки не відійде на back_off, далі нема куди або час вийшов (позаду
## союзник — тіла не проходять одне крізь одне, D443).
func handle_retreat_state(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	_face_player()
	var away := -1 if player.global_position.x > enemy.global_position.x else 1
	var walked := absf(enemy.global_position.x - _back_off_from)
	if walked >= enemy.back_off or not can_step(away) or state_timer > enemy.back_off / speed + BACK_OFF_SLACK:
		velocity.x = 0
		change_state(AIState.ATTACK)
		return
	velocity.x = away * speed

func change_state(new_state: AIState):
	"""Змінює стан AI"""
	if current_state == new_state:
		return
	current_state = new_state
	pace = 1.0
	state_timer = 0.0
	state_changed.emit(new_state)

## Оглушення (D207). Не зриває замах броньованого (tank, D208) і замах, чию підказку вже показано (B134).
func stun(duration: float) -> void:
	if is_attacking and (enemy.super_armor or committed):
		return
	stun_left = maxf(stun_left, duration)

## Збій (D264): стоїть [param duration] с, замах і серія зірвані, хітбокс гасне — навіть у броні й після підказки.
func stagger(duration: float) -> void:
	stun_left = maxf(stun_left, duration)
	if is_attacking:
		attack_broken = true
		enemy.end_attack()

## Відкидання на [param push] px за [param time] с. Удар героя ([param breaks_attack]) зриває замах лише до підказки
## (B134); власний ривок ворога — ні. Ривок боса (charge) — довший за звичайне відкидання.
func start_knockback(push: float, breaks_attack: bool = true, time: float = KNOCKBACK_TIME) -> void:
	knockback_left = time
	knockback_speed = push / time
	if breaks_attack and is_attacking and not committed:
		attack_broken = true

## Підказки ударів серії, по одній на удар. Довжина серії — 1–combo_hits (D265), удари — tell ворога, фінішер —
## finisher_tell. Бос бере серію зі свого ходу (BossLogic).
func _swing_tells() -> Array[StringName]:
	var swings := 1
	while swings < enemy.combo_hits and randf() < enemy.combo_chance:
		swings += 1
	var tells: Array[StringName] = []
	for i in swings:
		tells.append(enemy.finisher_tell if swings > 1 and i == swings - 1 else enemy.tell)
	return tells

## Скільки триває поза відновлення після серії.
func _recovery_time() -> float:
	return enemy.recovery

func _interrupted() -> bool:
	return enemy.is_dead or stun_left > 0.0 or attack_broken

func perform_attack():
	"""Серія ударів (D265): замах, підказка, потім удар хітбоксом у бік погляду (D198); після серії — відновлення."""
	is_attacking = true
	_hits_waiting = 0
	attack_broken = false
	_hold_token()
	var tells := _swing_tells()
	for i in tells.size():
		if _interrupted():
			break
		var windup: float = enemy.attack_windup if i == 0 else COMBO_WINDUP
		finisher = tells.size() > 1 and i == tells.size() - 1
		tell_kind = tells[i]
		swing_windup = windup
		attack_started.emit()
		EventBus.attack_started.emit(enemy, player)
		await wind_up(windup)
		# Збили до підказки, оглушили (без броні) чи збій посеред серії — далі ударів немає (D207, D264, B134)
		if _interrupted():
			break
		# Б'є туди, куди дивився в мить підказки
		var direction := last_direction if last_direction != 0 else 1
		enemy.start_attack(direction)
		if enemy.lunge > 0.0:
			start_knockback(direction * enemy.lunge, false)  # ривок разом з ударом (fast)
		await get_tree().create_timer(enemy.attack_active_time, false).timeout
		enemy.end_attack()
		committed = false
	committed = false
	finisher = false
	tell_kind = enemy.tell
	_release_token()
	if not _interrupted():
		await _recover(_recovery_time())
	is_attacking = false
	attack_ended.emit()
	_decide_after_attack()

## Поза відновлення [param time] с (D504): ворог стоїть у позі удару; збій її обриває (і стоїть уже збитий).
func _recover(time: float) -> void:
	recovering = true
	recovery_started.emit(time)
	await get_tree().create_timer(time, false).timeout
	recovering = false

## Замах [param windup] с: спершу ворог стежить за героєм, а за TELL_LEAD до удару напрямок фіксується й спалахує
## підказка (перекат за спину саме тоді рятує, а просто відійти на крок — ні). Замах, коротший за TELL_LEAD, — підказка
## одразу. Зірваний замах (збій, оглушення) підказки не дає.
## Таймери замаху й удару стоять, поки гра на паузі (меню, вікно туторіалу D289).
func wind_up(windup: float) -> void:
	winding_up = true
	committed = false
	var track := windup - TELL_LEAD
	if track > 0.0:
		await get_tree().create_timer(track, false).timeout
	winding_up = false
	if _interrupted():
		return
	committed = true
	tell_time = minf(windup, TELL_LEAD)
	attack_telegraphed.emit()
	await get_tree().create_timer(tell_time, false).timeout

## Скільки ворогів замахуються одночасно (D642: тиск групи) — enemy_variety.json "pressure".
static func max_attackers() -> int:
	return int(EnemyVariety.data().pressure.max_attackers)

## Жетон вільний: замахуються менше за max_attackers() інших ворогів (або цей уже має жетон).
func token_free() -> bool:
	_attackers = _attackers.filter(func(l: EnemyLogic) -> bool: return is_instance_valid(l) and l.is_attacking)
	return self in _attackers or _attackers.size() < max_attackers()

## Скільки ворогів зараз тримає жетон удару (для тестів).
static func attackers() -> int:
	return _attackers.filter(func(l: EnemyLogic) -> bool: return is_instance_valid(l) and l.is_attacking).size()

func _hold_token() -> void:
	if not self in _attackers:
		_attackers.append(self)

func _release_token() -> void:
	_attackers.erase(self)

## Герой помітний (B139): на тому ж поверсі (ноги на ±NOTICE_DY px) або на виду — промінь від ворога до героя без стін.
func can_notice(hero: Node2D) -> bool:
	if absf(_feet_y(hero) - _feet_y(enemy)) <= NOTICE_DY:
		return true
	var ray := PhysicsRayQueryParameters2D.create(enemy.global_position, hero.global_position)
	ray.exclude = _bodies()
	return enemy.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

## Низ тіла (форма CollisionShape2D) у світових координатах.
static func _feet_y(body: Node2D) -> float:
	var shape: CollisionShape2D = body.get_node(^"CollisionShape2D")
	return shape.global_position.y + shape.shape.get_rect().end.y * body.global_scale.y

func _bodies() -> Array[RID]:
	var bodies: Array[RID] = []
	for body: CollisionObject2D in enemy.get_tree().get_nodes_in_group(GameGroups.ENEMIES) + [player]:
		bodies.append(body.get_rid())
	return bodies

## У бік [param dir] є куди ступити (B139): без стіни одразу за краєм тіла і з підлогою під ногами — не з уступу.
func can_step(dir: int) -> bool:
	var shape: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	var ahead_x: float = enemy.global_position.x + dir * (shape.shape.get_rect().size.x * enemy.global_scale.x / 2.0 + LOOK_AHEAD)
	var space := enemy.get_world_2d().direct_space_state
	var bodies := _bodies()
	var wall := PhysicsRayQueryParameters2D.create(enemy.global_position, Vector2(ahead_x, enemy.global_position.y))
	wall.exclude = bodies
	if not space.intersect_ray(wall).is_empty():
		return false
	var ground := PhysicsRayQueryParameters2D.create(Vector2(ahead_x, enemy.global_position.y), Vector2(ahead_x, _feet_y(enemy) + FLOOR_PROBE))
	ground.exclude = bodies
	return not space.intersect_ray(ground).is_empty()

## Іде в бік [param dir], повернувшись туди обличчям; край уступу чи стіна — стоїть.
func _walk(dir: int, walk_speed: float) -> void:
	if dir != last_direction:
		direction_changed.emit(dir)
		last_direction = dir
	_step(dir, walk_speed)

## Крок у бік [param dir], не повертаючись (задкує обличчям до героя); край уступу чи стіна — стоїть.
func _step(dir: int, walk_speed: float) -> void:
	velocity.x = dir * walk_speed if can_step(dir) else 0.0

func _face_player() -> void:
	if not player or not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	var dir := 1 if dx > 0 else -1
	if absf(dx) > 0.1 and dir != last_direction:
		direction_changed.emit(dir)
		last_direction = dir

func on_player_detected(player_node: Node):
	"""Обробляє виявлення гравця"""
	player_in_area = true
	player = player_node
	player_detected.emit()

	if current_state == AIState.IDLE:
		change_state(AIState.CHASE)

func on_player_lost():
	"""Обробляє втрату гравця"""
	player_in_area = false
	player_lost.emit()

func get_state() -> AIState:
	"""Отримує поточний стан"""
	return current_state

func get_velocity() -> Vector2:
	"""Отримує поточну швидкість"""
	return velocity

func set_velocity(new_velocity: Vector2):
	"""Встановлює швидкість"""
	velocity = new_velocity

func handle_return_home_state(_delta: float) -> void:
	"""Повертає ворога на позицію спавну по X (без примусових аренд)"""
	var dx = home_position.x - enemy.global_position.x
	if abs(dx) <= 5.0:
		velocity.x = 0
		change_state(AIState.IDLE)
		return
	var dir := 1 if dx > 0 else -1
	# Додому не пройти (відкинули за уступ чи стіну) — новий дім тут, інакше ворог застряг би в RETURN_HOME
	if not can_step(dir):
		home_position = enemy.global_position
		velocity.x = 0
		change_state(AIState.IDLE)
		return
	_walk(dir, return_home_speed)
