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

## Випад (D739, EnemyStats.lunge_*): ривок з ударом за LUNGE_TIME с; не частіше, ніж раз на LUNGE_REST с; кинув кубик
## і не вийшло — наступний кидок за LUNGE_REROLL с. Ривок спиняється за LUNGE_SHORT px до місця, де стояв герой
## (тіло героя спинить і раніше, D443), а хітбокс живий увесь ривок.
const LUNGE_TIME := 0.2
const LUNGE_REST := 2.5
const LUNGE_REROLL := 0.8
const LUNGE_SHORT := 10.0
## Випад лише по героєві на своїй підлозі (ноги на ±LUNGE_DY px).
const LUNGE_DY := 24.0
var _lunge_rest: float = 0.0
## Іде випад (замах, ривок, відновлення).
var lunging: bool = false
## Стрибок шакала (D740): висота дуги спрайта, px; учепився — LATCH_BITE_AT с до укусу (стоп-кадр LATCH_HITSTOP с),
## LATCH_TIME с усього, тоді герой відштовхує його (SHOVE_TIME с пози) на SHOVE_PUSH px, шакал падає й LATCH_STUN с
## оговтується. Укус — LATCH_BITE шкоди удару. Учепитись може лише один шакал.
const POUNCE_HOP := 34.0
const LATCH_BITE_AT := 0.35
const LATCH_HITSTOP := 0.09
const LATCH_TIME := 0.9
const LATCH_BITE := 1.3
const SHOVE_TIME := 0.25
const SHOVE_PUSH := 160.0
const LATCH_STUN := 0.6
static var _latched: EnemyLogic = null

## Обхід (D741, Tails of Iron): група не стоїть у черзі з одного боку героя. Ворог, що чекає позаду іншого, а з того
## боку героя нікого, проходить крізь героя (тіла пропускають одне одного лише на цей прохід, як перекат героя, D443)
## швидким кроком FLANK_PACE на свою дистанцію з того боку. Один обхідник на раз; кожен — не частіше за FLANK_REST с
## (перший — через випадкові 0–FLANK_REST с після початку бою); прохід — не довше FLANK_TIME с.
const FLANK_PACE := 2.2
const FLANK_REST := 3.0
const FLANK_TIME := 1.6
## Хто з союзників рахується в бою: на своїй підлозі, ближче за FLANK_NEAR px до героя.
const FLANK_NEAR := 320.0
static var _flanker: EnemyLogic = null
var _flank_rest: float = -1.0
## Куди йде обхід: -1 / 1 — бік героя, на який ворог переходить; 0 — не обходить.
var flank_side: int = 0
var _flank_left: float = 0.0
## Розум бою (D764, Sapega 26.10: «щоб вони хотіли вбити персонажа, а не просто бачили, рухались і били по повітрю»).
## Удар починається, лише коли дістане героя в мить удару: де герой буде за замах — з його швидкості (не далі
## PREDICT_MAX px), мінус скільки ворог підступить за стеження замаху (WINDUP_CREEP своєї швидкості, до підказки).
const PREDICT_MAX := 90.0
const WINDUP_CREEP := 0.6
const REACH_MARGIN := 4.0
## Перерва між серіями — attack_cooldown × RHYTHM_MIN…RHYTHM_MAX (не метроном).
const RHYTHM_MIN := 0.7
const RHYTHM_MAX := 1.3
## Герой приземлився — відкритий LAND_OPEN с; щитоносець відповідає на удар героя, що скінчився, COUNTER_OPEN с.
const LAND_OPEN := 0.35
const COUNTER_OPEN := 0.4
## Ухил легкого виду (answer_swing "evade") від важкого героя: з шансом EVADE_CHANCE на замах, за EVADE_REACT с
## реакції — відскок на EVADE_DIST px за EVADE_TIME с (спрайт підстрибує на EVADE_HOP px). Досяжність важкого —
## PlayerCombat.strike_reach + півтіла ворога + HEAVY_SLACK.
const EVADE_CHANCE := 0.7
const EVADE_REACT := 0.1
const EVADE_DIST := 70.0
const EVADE_TIME := 0.22
const EVADE_HOP := 10.0
const HEAVY_SLACK := 12.0
## Фінт еліти: раз на FEINT_EVERY_MIN…FEINT_EVERY_MAX серій перший замах — поза замаху FEINT_TIME с без підказки, що
## обривається (показана підказка не бреше, D504), FEINT_PAUSE с — і справжній замах з підказкою.
const FEINT_EVERY_MIN := 2
const FEINT_EVERY_MAX := 4
const FEINT_TIME := 0.3
const FEINT_PAUSE := 0.2
## Герой утік (перекат, стрибок, відхід) — ворог біжить за ним (RUN_PACE), щойно той віддаляється швидше за AWAY_SPEED px/с.
const AWAY_SPEED := 60.0
## Навчальний бій (CombatTraining, D-28): ворог б'є й у блок і не відскакує з-під важкого — урокам захисту й важкого
## удару потрібен удар, що прийде, і ціль, що встоїть (D764).
var in_training := false
## Що ворог щойно вирішив (D764): close_in, punish, evade, guard, wait_block, space_out, feint, follow, press, kite,
## reposition, lead — для тестів (verify_masher) і журналу.
signal tactic(name: StringName)
## Де ворог бачив героя востаннє: загубив з очей — іде туди, а не стоїть (D764).
var _last_seen_x := 0.0
var _has_seen := false
var _hero_was_air := false
var _land_left := 0.0
var _counter_left := 0.0
var _hero_state: int = -1
## Рішення щодо поточного замаху важкого героя: ухилитись (кубик EVADE_CHANCE) і за скільки с.
var _evade_planned := false
var _evade_wait := 0.0
var _dash_left := 0.0
var _dash_speed := 0.0
var _guarding := false
## Цей замах уже підступав за героєм (close_in — раз на замах).
var _crept := false
## Скільки ще серій до фінту еліти (-1 — ще не кинуто).
var _feint_in := -1
## Найдовший крок ворога на удар, px (_strike_step).
const STRIKE_STEP := 24.0
## Скільки ще триває стеження замаху (до підказки), с.
var _track_left := 0.0
## Замах обривається, лише коли герой іде геть і буде далі за досяжність щонайменше на ABANDON_SLACK px.
const ABANDON_SLACK := 16.0
var _waiting_block := false
## Скільки с ворог чекає, поки герой опустить блок; довше за BLOCK_PATIENCE — б'є в блок.
var _block_wait := 0.0
const BLOCK_PATIENCE := 1.2

## Шакал, що зараз учепився в героя (для тестів і HUD).
static func latched() -> EnemyLogic:
	return _latched if is_instance_valid(_latched) else null

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
	if _flanker == self:
		_flanker = null
	if _latched == self:
		_latched = null

func process_physics(delta: float) -> Vector2:
	"""Обробляє фізику та повертає нову швидкість"""
	is_on_floor = enemy.is_on_floor()

	state_timer += delta
	chase_cooldown_timer += delta
	attack_ready_in = maxf(attack_ready_in - delta, 0.0)
	_lunge_rest = maxf(_lunge_rest - delta, 0.0)
	if _flank_rest < 0.0:
		_flank_rest = randf() * FLANK_REST
	_flank_rest = maxf(_flank_rest - delta, 0.0)

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
	_read_hero(delta)

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = _dash_speed if can_step(signi(int(signf(_dash_speed)))) else 0.0
		return

	# Атака вже почалась — доводимо її до кінця; до підказки ворог стежить за героєм і підступає, щоб удар дістав (D764)
	if is_attacking:
		velocity.x = 0
		if winding_up:
			_face_player()
			if _abandon_due():
				attack_broken = true  # до підказки: герой утік з-під удару — не б'є в повітря, а йде за ним (D764)
				tactic.emit(&"follow")
				return
			if _creeps() and absf(_predicted_dx(TELL_LEAD)) > strike_reach() - REACH_MARGIN:
				_step(last_direction, speed * WINDUP_CREEP)
				if not _crept:
					_crept = true
					tactic.emit(&"close_in")
		return

	# Читає героя (D764): легкий відскакує з-під важкого, щитоносець стає щитом до удару — і в бою, і відходячи, і в погоні
	if current_state in [AIState.CHASE, AIState.ATTACK, AIState.RETREAT] and player and is_instance_valid(player) and flank_side == 0:
		var hero_dx: float = player.global_position.x - enemy.global_position.x
		if _evade_due(absf(hero_dx)):
			_evade(-1 if hero_dx > 0.0 else 1)
			return
		if _evade_planned and _evade_wait > 0.0 and _evade_due(absf(hero_dx), true):
			velocity.x = 0  # побачив замах важкого — уже не замахується сам, за мить відскочить
			return
		if _guard_due(absf(hero_dx)):
			velocity.x = 0
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

	# Leash: якщо відійшли надто далеко від дому — припиняємо переслідування і йдемо назад; але не посеред бою, коли герой
	# ще ближче за chase_range (B164: перекотився чи відійшов — ворог іде за ним, а не додому)
	if abs(enemy.global_position.x - home_position.x) > leash_range and distance_to_player_x > chase_range:
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
	# Загубив з очей (стрибнув на уступ, за стіну, B139) — іде туди, де бачив його востаннє, і чекає там (D764); не бачив
	# узагалі (лише зона виявлення крізь стіну) — стоїть
	if not noticed:
		var to_seen := _last_seen_x - enemy.global_position.x
		pace = 1.0
		if _has_seen and absf(to_seen) > 8.0:
			_walk(1 if to_seen > 0.0 else -1, speed)
		else:
			velocity.x = 0
		return
	_last_seen_x = player.global_position.x
	_has_seen = true

	if _lunge_due(distance_to_player_x):
		if _hero_opened(distance_to_player_x):
			tactic.emit(&"punish")
		perform_lunge()
		return

	if distance_to_player_x <= engage_range():
		change_state(AIState.ATTACK)
		return

	var direction_x: float = player.global_position.x - enemy.global_position.x
	var away := _hero_moving_away()
	pace = RUN_PACE if distance_to_player_x > engage_range() * RUN_FROM or away else 1.0
	if away and state_timer < delta * 1.5:
		tactic.emit(&"press")  # тисне героя, що відходить: біжить за ним
	if abs(direction_x) <= 5.0:
		velocity.x = 0
	else:
		_walk(1 if direction_x > 0 else -1, speed * pace)

func _give_up() -> void:
	_has_seen = false
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
	if flank_side != 0:
		_flank_step(delta)
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	var adx := absf(dx)
	if adx > engage_range() * 1.2 or not can_notice(player):
		tactic.emit(&"follow")  # герой відійшов чи перекотився геть — одразу за ним (D764)
		change_state(AIState.CHASE)
		return
	_last_seen_x = player.global_position.x
	_has_seen = true
	_face_player()
	var toward := 1 if dx > 0.0 else -1
	var opened := _hero_opened(adx)
	var due := attack_ready_in <= 0.0 or opened
	# Герой блокує обличчям до ворога, а удар можна заблокувати — не лізе в блок: обходить чи чекає вікна (D764); стоїть
	# у блоці довше за BLOCK_PATIENCE — б'є в блок (блок їсть витривалість, D504)
	_block_wait = _block_wait + delta if due and _blocked_out() else 0.0
	if due and _blocked_out() and _block_wait <= BLOCK_PATIENCE:
		if not _waiting_block:
			_waiting_block = true
			tactic.emit(&"wait_block")
		pace = 1.0
		if _flank_rest <= 0.0 and not is_instance_valid(_flanker) and not enemy.flying and _side_open(toward):
			_start_flank(toward)
			return
		_hold_spacing(dx, delta)
		return
	_waiting_block = false
	if _lunge_due(adx):
		if opened:
			tactic.emit(&"punish")
		perform_lunge()
		return
	if due and token_free():
		if swing_fits(enemy.attack_windup):
			pace = 1.0
			if opened:
				tactic.emit(&"punish")
			_rest_after_swing()
			perform_attack()
		else:
			pace = STEP_IN_PACE  # D713: заходить бити швидше — не бреде під клинком героя
			_step(toward, speed * pace)
		return
	pace = 1.0
	if _flank_due(toward):
		_start_flank(toward)
		return
	# У досяжності, а бити ще рано (перерва, жетон): відходить з-під удару; нема куди — б'є (D764: не стоїть перед героєм)
	if adx <= strike_reach() and not can_step(-toward) and token_free() and swing_fits(enemy.attack_windup):
		_rest_after_swing()
		perform_attack()
		return
	_hold_spacing(dx, delta)

## Час обходу (D741): ворог чекає, з його боку героя є ще хтось ближчий до героя, з іншого — нікого, і той бік
## вільний (підлога, без стіни).
func _flank_due(toward: int) -> bool:
	if _flank_rest > 0.0 or enemy.flying or (is_instance_valid(_flanker) and _flanker != self):
		return false
	var hero_x: float = player.global_position.x
	var my_gap := absf(hero_x - enemy.global_position.x)
	var nearer_here := false
	for body: Node in get_tree().get_nodes_in_group(GameGroups.ENEMIES):
		if body == enemy or not body is DefaultEnemy or body.is_dead or body.flying:
			continue
		var gap: float = body.global_position.x - hero_x
		if absf(gap) > FLANK_NEAR or absf(_feet_y(body) - _feet_y(enemy)) > LUNGE_DY:
			continue
		if signf(gap) == float(toward):
			return false  # з того боку вже хтось є
		if absf(gap) < my_gap:
			nearer_here = true
	if not nearer_here:
		return false
	return _side_open(toward)

## За героєм у бік [param dir] є куди стати: без стіни між героєм і тим місцем і з підлогою там.
func _side_open(dir: int) -> bool:
	var hero: Node2D = player
	var to := Vector2(hero.global_position.x + dir * engage_range(), enemy.global_position.y)
	var space := enemy.get_world_2d().direct_space_state
	var wall := PhysicsRayQueryParameters2D.create(Vector2(hero.global_position.x, enemy.global_position.y), to)
	wall.exclude = _bodies()
	if not space.intersect_ray(wall).is_empty():
		return false
	var ground := PhysicsRayQueryParameters2D.create(to, Vector2(to.x, _feet_y(enemy) + FLOOR_PROBE))
	ground.exclude = _bodies()
	return not space.intersect_ray(ground).is_empty()

func _start_flank(toward: int) -> void:
	_flanker = self
	flank_side = toward
	_flank_left = FLANK_TIME
	enemy.add_collision_exception_with(player)
	player.add_collision_exception_with(enemy)

## Прохід крізь героя на його інший бік (D741); дійшов (на engage_range з того боку), уперся чи вийшов час — кінець.
func _flank_step(delta: float) -> void:
	_flank_left -= delta
	var target_x: float = player.global_position.x + flank_side * engage_range()
	var left := target_x - enemy.global_position.x
	pace = FLANK_PACE
	if _flank_left <= 0.0 or absf(left) <= 8.0 or not can_step(signi(int(signf(left)))):
		_end_flank()
		return
	_walk(1 if left > 0.0 else -1, speed * FLANK_PACE)

func _end_flank() -> void:
	flank_side = 0
	pace = 1.0
	velocity.x = 0.0
	_flank_rest = FLANK_REST
	if _flanker == self:
		_flanker = null
	_face_player()
	_release_hero_pass()

## Виняток тіл знімається, щойно ворог уже не в героєві (інакше фізика розштовхувала б їх).
func _release_hero_pass() -> void:
	if not is_instance_valid(player):
		return
	if enemy.body_rect().intersects(player.body_rect()):
		get_tree().create_timer(0.1, false).timeout.connect(_release_hero_pass)
		return
	enemy.remove_collision_exception_with(player)
	player.remove_collision_exception_with(enemy)

## Тримається на engage_range від героя, переступаючи на ±SHUFFLE px: ближче — задкує, далі — підходить (повільно);
## у досяжності удару героя чи далеко від своєї відстані — повним кроком (D764: не стоїть під клинком, тисне того, хто відходить).
func _hold_spacing(dx: float, delta: float) -> void:
	_shuffle_t += delta
	var err: float = absf(dx) - engage_range() - sin(_shuffle_t * 2.0) * SHUFFLE
	var toward := 1 if dx > 0.0 else -1
	var pace_now := SPACING_SPEED if absf(err) < WAIT_GAP * 0.5 and absf(dx) > strike_reach() else 1.0
	if err < -4.0:
		_step(-toward, speed * pace_now)
	elif err > 4.0:
		_step(toward, speed * pace_now)
	else:
		velocity.x = 0

## Герой відкрився поруч (critique §B, D764) у досяжності _punish_range(): замах важкого удару чи навички, фляга
## (Healing Palm, D504) або зілля (D713), відновлення після важкого, кінець своєї серії, щойно приземлився; щитоносцеві —
## щойно скінчився удар, що він прийняв на щит.
func _hero_opened(adx: float) -> bool:
	# Вікно карає один: хтось уже б'є — решта чекає свого ритму (D764, гурт не налітає всім гуртом на кожне вікно)
	if adx > _punish_range() or _attackers.any(func(l: EnemyLogic) -> bool: return l != self and is_instance_valid(l) and l.is_attacking):
		return false
	var combat: PlayerCombat = player.combat
	if combat.state in [PlayerCombat.State.HEAVY_RECOVERY, PlayerCombat.State.CAST_WINDUP, PlayerCombat.State.DRINK]:
		return true
	# Замах важкого карає лише той, хто його приймає (trade); легкий відскакує, щитоносець стає щитом (D764)
	if combat.state == PlayerCombat.State.HEAVY_WINDUP:
		return enemy.enemy_stats.answer_swing == "trade"
	if _punishes_combo_end() and combat.state == PlayerCombat.State.READY and combat.grip != &"bow" \
			and combat.attack_cooldown > enemy.attack_windup - TELL_LEAD:
		return true  # серія скінчилась — герой у відновленні фінішера й побачить підказку, ще не маючи чим відповісти
	return _land_left > 0.0 or _counter_left > 0.0

## Чи карає вид кінець серії героя (бос — лише великі вікна: відновлення важкого, флягу, каст, приземлення).
func _punishes_combo_end() -> bool:
	return true

## Стежить за героєм кожен кадр: приземлення, новий замах важкого (кубик ухилу), кінець удару, прийнятого на щит.
func _read_hero(delta: float) -> void:
	_land_left = maxf(_land_left - delta, 0.0)
	_counter_left = maxf(_counter_left - delta, 0.0)
	_evade_wait = maxf(_evade_wait - delta, 0.0)
	if not player or not is_instance_valid(player):
		return
	var air: bool = not player.is_on_floor()
	if _hero_was_air and not air:
		_land_left = LAND_OPEN
	_hero_was_air = air
	var state: int = player.combat.state
	if state != _hero_state:
		if state == PlayerCombat.State.HEAVY_WINDUP:
			_evade_planned = randf() < EVADE_CHANCE
			_evade_wait = EVADE_REACT
		if _guarding and not _hero_swinging():
			_guarding = false
			_counter_left = COUNTER_OPEN
		_hero_state = state

## Іде удар героя (легкий чи важкий, замах чи сам удар).
func _hero_swinging() -> bool:
	return player.combat.state in [PlayerCombat.State.SWING, PlayerCombat.State.HEAVY_WINDUP, PlayerCombat.State.HEAVY_STRIKE]

## Герой дивиться на ворога.
func _hero_faces_me() -> bool:
	return signf(enemy.global_position.x - player.global_position.x) == float(player.last_direction)

## Герой іде (котиться) від ворога швидше за AWAY_SPEED.
func _hero_moving_away() -> bool:
	return player.velocity.x * signf(player.global_position.x - enemy.global_position.x) > AWAY_SPEED

## Важкий героя дістане ворога: його досяжність, півтіла ворога й запас.
func _in_heavy_reach(adx: float) -> bool:
	return adx <= player.combat.strike_reach(true) + enemy.body_rect().size.x / 2.0 + HEAVY_SLACK

## Легкий вид бачить замах важкого, що його дістане, і (кубик EVADE_CHANCE, реакція EVADE_REACT) відскакує; [param reacting] —
## ще в реакції (не рахує її).
func _evade_due(adx: float, reacting: bool = false) -> bool:
	return not in_training and enemy.enemy_stats.answer_swing == "evade" and _evade_planned and (reacting or _evade_wait <= 0.0) \
			and player.combat.state == PlayerCombat.State.HEAVY_WINDUP and _hero_faces_me() and _in_heavy_reach(adx)

## Відскок назад ([param away]) з-під удару: EVADE_DIST px за EVADE_TIME с з підскоком спрайта; край уступу спиняє.
func _evade(away: int) -> void:
	_evade_planned = false
	if not can_step(away):
		return
	tactic.emit(&"evade")
	_dash_left = EVADE_TIME
	_dash_speed = away * EVADE_DIST / EVADE_TIME
	velocity.x = _dash_speed
	enemy.enemy_view.hop(EVADE_HOP, EVADE_TIME)

## Щитоносець (answer_swing "guard") на удар героя, що його дістане: стоїть щитом до героя, не лізе під удар (а коли
## удар скінчився — відповідає, _counter_left).
func _guard_due(adx: float) -> bool:
	if enemy.enemy_stats.answer_swing != "guard" or not _hero_swinging() or not _hero_faces_me():
		return false
	if adx > player.combat.strike_reach(player.combat.state != PlayerCombat.State.SWING) + enemy.body_rect().size.x / 2.0 + HEAVY_SLACK:
		return false
	if not _guarding:
		_guarding = true
		tactic.emit(&"guard")
	return true

## Герой блокує обличчям до ворога, а удар ворога блок бере (не червоний) — бити в блок марно.
func _blocked_out() -> bool:
	return not in_training and player.combat.is_blocking() and _hero_faces_me() and StringName(enemy.tell) != TELL_DODGE

## Досяжність удару ворога до краю тіла героя, px від центру ворога.
func strike_reach() -> float:
	return enemy.strike_reach() + player.body_rect().size.x / 2.0

## Де буде герой (dx від ворога) за [param time] с: з його швидкості, не далі PREDICT_MAX px.
func _predicted_dx(time: float) -> float:
	return player.global_position.x - enemy.global_position.x + clampf(player.velocity.x * time, -PREDICT_MAX, PREDICT_MAX)

## Удар із замахом [param windup] дістане героя в мить удару (D764): де герой буде (з його швидкості), мінус скільки ворог
## підступить за стеження замаху, — у досяжності; і герой не над хітбоксом (у стрибку вгору).
func swing_fits(windup: float) -> bool:
	var creep := speed * WINDUP_CREEP * maxf(windup - TELL_LEAD, 0.0) if _creeps() else 0.0
	if absf(_predicted_dx(windup)) - creep > strike_reach() - REACH_MARGIN:
		return false
	return player.is_on_floor() or player.velocity.y > 0.0 or _feet_y(player) > _feet_y(enemy) - enemy.hitbox_collision.shape.get_rect().size.y * absf(enemy.hitbox_collision.global_transform.get_scale().y)

## Де по висоті буде центр героя за [param time] с (D764): у стрибку — з його швидкості й тяжіння, не нижче за підлогу
## ворога (лучник натягує, коли герой буде на його висоті в мить пострілу, і цілить туди).
func _hero_y_at(time: float) -> float:
	if player.is_on_floor():
		return player.global_position.y
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var y: float = player.global_position.y + player.velocity.y * time + 0.5 * gravity * time * time
	return minf(y, enemy.global_position.y)

## Наступний удар серії ще дістане героя і не піде в його блок (D764). Бос б'є серію свого ходу до кінця (BossLogic).
func _series_fits(windup: float) -> bool:
	return swing_fits(windup) and not _blocked_out()

## Замах до підказки вже не дістане героя (D764): той котиться чи йде геть, і де він буде в мить удару, мінус крок
## ворога до підказки, — далі за досяжність. Випад і бос — ні (ривок і так летить туди, де герой був; візерунок боса).
func _abandon_due() -> bool:
	if lunging or not _abandons() or not (player.mover.is_rolling() or _hero_moving_away()):
		return false
	var creep := speed * WINDUP_CREEP * _track_left if _creeps() else 0.0
	return absf(_predicted_dx(_track_left + TELL_LEAD)) - creep > strike_reach() + ABANDON_SLACK

func _abandons() -> bool:
	return true

## Удар із кроком (D764, як у героя — D504: відступити на крок не рятує, рятує перекат): герой трохи далі за досяжність
## (до STRIKE_STEP px) у бік удару — ворог ступає на удар.
func _strike_step(direction: int) -> void:
	var dx: float = player.global_position.x - enemy.global_position.x
	var gap := absf(dx) - strike_reach() + REACH_MARGIN
	if not _creeps() or gap <= 0.0 or signf(dx) != float(direction) or not can_step(direction):
		return
	start_knockback(direction * minf(gap, STRIKE_STEP), false)

## Чи підступає ворог за героєм під час замаху (до підказки). Лучник і випад — ні.
func _creeps() -> bool:
	return not lunging

## Перерва до наступної серії — attack_cooldown зі змінним ритмом (D764).
func _rest_after_swing() -> void:
	attack_ready_in = enemy.attack_cooldown * randf_range(RHYTHM_MIN, RHYTHM_MAX)

## Звідки ворог карає відкритого героя: ближній — з півтори attack_range, але щонайменше зі своєї відстані бою (D764:
## заходить бити того, хто відкрився, а не чекає, поки той підійде).
func _punish_range() -> float:
	var stats: EnemyStats = enemy.enemy_stats
	return maxf(maxf(attack_range * 1.5, engage_range()), stats.lunge_to if stats.lunge_chance > 0.0 else 0.0)

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

## Після серії (D504): відходить на back_off px і щонайменше з досяжності удару героя (D764: не стоїть перед ним), якщо є куди.
func _decide_after_attack() -> void:
	if current_state != AIState.ATTACK or enemy.is_dead:
		return
	# Герой уже поза досяжністю (відкотився, відійшов) — не відходить, а йде за ним
	if player and is_instance_valid(player) and absf(player.global_position.x - enemy.global_position.x) <= _hero_reach() + WAIT_GAP:
		_back_off_from = enemy.global_position.x
		tactic.emit(&"space_out")
		change_state(AIState.RETREAT)

## Відхід після серії: задкує обличчям до героя, доки не відійде на back_off, далі нема куди або час вийшов (позаду
## союзник — тіла не проходять одне крізь одне, D443).
func handle_retreat_state(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	_face_player()
	# Герой відкрився (D764) — не відходить, а розвертається карати
	if _hero_opened(absf(player.global_position.x - enemy.global_position.x)) and token_free():
		change_state(AIState.ATTACK)
		return
	var away := -1 if player.global_position.x > enemy.global_position.x else 1
	var walked := absf(enemy.global_position.x - _back_off_from)
	var clear := absf(player.global_position.x - enemy.global_position.x) > _hero_reach()
	var limit := maxf(enemy.back_off, _hero_reach()) / speed + BACK_OFF_SLACK
	if (walked >= enemy.back_off and clear) or not can_step(away) or state_timer > limit:
		velocity.x = 0
		change_state(AIState.ATTACK)
		return
	velocity.x = away * speed

## Звідки дістає удар героя (серія з фінішером), px від центру героя до центру ворога.
func _hero_reach() -> float:
	return player.combat.strike_reach(false) + enemy.body_rect().size.x / 2.0

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
	_crept = false
	_hold_token()
	if _can_feint() and not _hero_opened(0.0):
		if _feint_in < 0:
			_feint_in = randi_range(FEINT_EVERY_MIN, FEINT_EVERY_MAX)
		_feint_in -= 1
		if _feint_in == 0:
			_feint_in = -1
			await _feint()
	var tells := _swing_tells()
	for i in tells.size():
		if _interrupted():
			break
		var windup: float = enemy.attack_windup if i == 0 else COMBO_WINDUP
		if i > 0 and not _series_fits(windup):
			break  # герой поза досяжністю наступного удару серії — не б'є в повітря (D764)
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
		else:
			_strike_step(direction)
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

## Чи вид фінтує (D764): еліти.
func _can_feint() -> bool:
	return enemy.elite

## Фінт (D764): поза замаху без підказки FEINT_TIME с, обрив, FEINT_PAUSE с — далі справжній замах. Підказка (D504) не
## показується, тож показана підказка й далі означає удар.
func _feint() -> void:
	tactic.emit(&"feint")
	swing_windup = FEINT_TIME + TELL_LEAD
	attack_started.emit()
	winding_up = true
	await get_tree().create_timer(FEINT_TIME, false).timeout
	winding_up = false
	enemy.enemy_view.on_attack_ended()
	await get_tree().create_timer(FEINT_PAUSE, false).timeout

## Час випаду (D739): ворог готовий, жетон вільний, герой на його підлозі на відстані lunge_from–lunge_to і є куди
## ступити — і кубик lunge_chance випав.
func _lunge_due(adx: float) -> bool:
	var stats: EnemyStats = enemy.enemy_stats
	if stats.lunge_chance <= 0.0 or _lunge_rest > 0.0 or not token_free():
		return false
	if attack_ready_in > 0.0 and not _hero_opened(adx) and not _hero_moving_away():
		return false  # перерва; але відкритого чи того, хто відходить, наздоганяє випадом (D764)
	if StringName(stats.lunge_tell) != TELL_DODGE and _blocked_out() and _block_wait <= BLOCK_PATIENCE:
		return false
	if adx < stats.lunge_from or adx > stats.lunge_to or absf(_feet_y(player) - _feet_y(enemy)) > LUNGE_DY:
		return false
	if not can_step(1 if player.global_position.x > enemy.global_position.x else -1):
		return false
	if randf() >= stats.lunge_chance:
		_lunge_rest = LUNGE_REROLL
		return false
	return true

## Випад (D739): короткий замах із підказкою lunge_tell, ривок з живим хітбоксом туди, де герой стояв у мить підказки,
## поза відновлення. Шакал (pounce, D740) стрибає: влучив — учепився (_latch), а не вкусив з льоту.
func perform_lunge() -> void:
	var stats: EnemyStats = enemy.enemy_stats
	is_attacking = true
	lunging = true
	_hits_waiting = 0
	attack_broken = false
	_hold_token()
	finisher = false
	tell_kind = StringName(stats.lunge_tell)
	swing_windup = stats.lunge_windup
	_face_player()
	tactic.emit(&"close_in")  # випадом іде на відстань удару (D764)
	attack_started.emit()
	EventBus.attack_started.emit(enemy, player)
	await wind_up(stats.lunge_windup)
	var latched_on := false
	if not _interrupted():
		var direction := last_direction if last_direction != 0 else 1
		var gap: float = absf(player.global_position.x - enemy.global_position.x) - LUNGE_SHORT
		enemy.start_attack(direction)
		start_knockback(direction * maxf(gap, 0.0), false, LUNGE_TIME)
		if stats.pounce:
			enemy.hitbox_damage.disable_damage()  # стрибок не кусає з льоту: учепився — кусає (_latch)
			enemy.enemy_view.hop(POUNCE_HOP, LUNGE_TIME)
			latched_on = await _pounce(direction)
		else:
			await get_tree().create_timer(LUNGE_TIME, false).timeout
		enemy.end_attack()
	committed = false
	tell_kind = enemy.tell
	_release_token()
	_rest_after_swing()
	_lunge_rest = LUNGE_REST
	if not _interrupted() and not latched_on:
		await _recover(_recovery_time())
	lunging = false
	is_attacking = false
	attack_ended.emit()
	_decide_after_attack()

## Стрибок (D740): поки летить, торкнувся героя — перекат (невразливість) крізь нього проносить; блок відбиває шакала
## назад (жовтий — парирує); інакше вчепився. Уже вчепився інший — звичайний укус з льоту. true — учепився.
func _pounce(direction: int) -> bool:
	var left := LUNGE_TIME
	while left > 0.0 and not _interrupted():
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if not _touches_hero():
			continue
		var hero: Node = player
		if hero.is_invulnerable or hero.is_dead:
			continue
		var guard: StringName = hero.combat.guard_against(enemy)
		if guard == &"parry":
			enemy.parried(hero)
			EventBus.player_parried.emit(enemy)
			return false
		if guard == &"block":
			EventBus.player_blocked.emit(enemy)
			start_knockback(-direction * SHOVE_PUSH * 0.5, false)
			return false
		if latched() != null:
			hero.take_damage(roundi(enemy.damage), enemy)
			return false
		await _latch(direction)
		return true
	return false

## Хітбокс стрибка торкнувся тіла героя (удари ворогів б'ють саме тіло, DamageApplier).
func _touches_hero() -> bool:
	return enemy.hitbox.overlaps_body(player)

## Учепився (D740): не стан, а коротка сцена бою. Герой стоїть (PlayerCombat.hold, поза Hurt), шакал висить на ньому
## в позі укусу; за LATCH_BITE_AT с — укус зі стоп-кадром; на LATCH_TIME герой відштовхує його (поза Block), шакал
## відлітає на SHOVE_PUSH px, падає й оговтується LATCH_STUN с. Збили чи вбили шакала посеред — герой вільний.
func _latch(direction: int) -> void:
	_latched = self
	var hero: Node = player
	knockback_left = 0.0
	velocity = Vector2.ZERO
	enemy.end_attack()
	hero.combat.hold(enemy, LATCH_TIME + SHOVE_TIME)
	var body_gap: float = enemy.get_node(^"CollisionShape2D").shape.get_rect().size.x * 0.5
	enemy.global_position.x = hero.global_position.x - direction * body_gap
	enemy.enemy_view.latch_pose()
	var t := 0.0
	var bitten := false
	while t < LATCH_TIME and not enemy.is_dead and stun_left <= 0.0 and not hero.is_dead:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		enemy.global_position.x = hero.global_position.x - direction * body_gap
		if not bitten and t >= LATCH_BITE_AT:
			bitten = true
			ServiceLocator.get_time_manager().hitstop(LATCH_HITSTOP)
			hero.take_damage(roundi(enemy.damage * LATCH_BITE), enemy)
	_latched = null
	if hero.is_dead:
		return
	hero.combat.shove(SHOVE_TIME)
	if not enemy.is_dead:
		start_knockback(-direction * SHOVE_PUSH, false, SHOVE_TIME)
		enemy.enemy_view.hop(POUNCE_HOP * 0.6, SHOVE_TIME)
		stun_left = maxf(stun_left, LATCH_STUN)
		if enemy.enemy_view.has_stagger_pose():
			enemy.enemy_view.play_stagger(LATCH_STUN)

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
		# Покадрово, щоб замах, який уже не дістане героя, обірвати одразу (D764, _abandon_due); таймер стоїть на паузі
		var timer := get_tree().create_timer(track, false)
		while timer.time_left > 0.0 and not _interrupted():
			_track_left = timer.time_left
			await get_tree().physics_frame
	_track_left = 0.0
	winding_up = false
	# Підказка іншого ще горить — своя чекає його удару (D764: підказки групи не накладаються, на кожну є відповідь)
	while _attackers.any(func(l: EnemyLogic) -> bool: return l != self and is_instance_valid(l) and l.committed) and not _interrupted():
		await get_tree().create_timer(0.05, false).timeout
	if _interrupted():
		return
	committed = true
	tell_time = minf(windup, TELL_LEAD)
	attack_telegraphed.emit()
	await get_tree().create_timer(tell_time, false).timeout

## Скільки ворогів замахуються одночасно (D642: тиск групи) — enemy_variety.json "pressure".
static func max_attackers() -> int:
	return int(EnemyVariety.data().pressure.max_attackers)

## Жетон вільний: замахуються менше за max_attackers() інших ворогів (або цей уже має жетон), і всі вони — з того
## самого боку героя (D741): оточений герой мусить розвертатись, але б'ють його з одного боку за раз — блок рятує.
func token_free() -> bool:
	_attackers = _attackers.filter(func(l: EnemyLogic) -> bool: return is_instance_valid(l) and l.is_attacking)
	if self in _attackers:
		return true
	if _attackers.size() >= max_attackers():
		return false
	# Підказка іншого вже горить — новий замах чекає її удару (D764: удари групи читаються по одному, а не падають разом)
	if _attackers.any(func(l: EnemyLogic) -> bool: return l.committed):
		return false
	var side := _hero_side()
	return _attackers.all(func(l: EnemyLogic) -> bool: return l._hero_side() == side)

## З якого боку героя ворог: -1 — ліворуч, 1 — праворуч.
func _hero_side() -> int:
	return 1 if enemy.global_position.x >= player.global_position.x else -1

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
	# Герой знову поруч і на виду (B162) — до бою, а не впиратись у нього дорогою додому
	if chase_cooldown_timer >= chase_cooldown and player and is_instance_valid(player) \
			and absf(player.global_position.x - enemy.global_position.x) <= detection_range and can_notice(player):
		chase_cooldown_timer = 0.0
		change_state(AIState.CHASE)
		return
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
