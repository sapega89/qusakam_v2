extends EnemyLogic

## Летючий ворог (D445, D558, design/flying_enemies_plan.md): той самий EnemyLogic (підказка, жетон удару, збій,
## відкидання), але без гравітації й без перевірок уступу — тримає висоту, патрулює й переслідує в повітрі.
## Спосіб удару — EnemyStats.flight_attack:
## - dive (гриф): кружляє над героєм поза досяжністю (hover_height над його ногами). Замах — відлітає назад і вгору,
##   за TELL_LEAD до піке спалахує підказка, і лінія фіксується: пікірує прямо туди, де герой був у мить підказки,
##   пролітає низько далі (GLIDE_TIME), стоїть у позі відновлення й набирає висоту. Бити його можна лише низько: з
##   початку піке, доки не піднявся на LOW_BAND px над дном (low).
## - bite (кажан): летить до героя хвилею на висоті голови, кусає ривком (lunge) туди, де герой був у мить підказки,
##   і відлітає назад і вгору (back_off). Бити можна завжди.
## Новий летючий вид (мухи Ктулху, D589) — лише свій аркуш і EnemyStats з flying і flight_attack.

const DIVE := &"dive"
const BITE := &"bite"
const HitAreas = preload("res://SampleProject/Scripts/Combat/HitAreas.gd")
## Патруль біля дому: пливе на ±PATROL px з частотою PATROL_RATE, похитуючись на ±BOB px.
const PATROL := 60.0
const PATROL_RATE := 0.7
const BOB := 6.0
## Наближення до точки: швидкість падає, коли до неї ближче за speed / ARRIVE px (без тремтіння на місці).
const ARRIVE := 4.0
## Кружляння грифа над героєм: ±ORBIT_X px по X, ±ORBIT_Y по висоті, з частотою ORBIT_RATE.
const ORBIT_X := 110.0
const ORBIT_Y := 14.0
const ORBIT_RATE := 1.1
## Гриф пікірує, лише коли він ближче за ORBIT_READY px до своєї точки кружляння.
const ORBIT_READY := 48.0
## Замах піке: гриф відлітає від героя й угору (px/с; x — назад від героя).
const WINDUP_DRIFT := Vector2(-40.0, -45.0)
## Після дна піке летить низько далі GLIDE_TIME с на GLIDE_SPEED від швидкості піке (хітбокс ще живий).
const GLIDE_TIME := 0.3
const GLIDE_SPEED := 0.6
## У позі відновлення гриф ковзає низько на RECOVER_DRIFT від своєї швидкості.
const RECOVER_DRIFT := 0.3
## Гриф низько, доки не піднявся на LOW_BAND px над дном піке.
const LOW_BAND := 60.0
## Хвиля кажана: ±WAVE px по висоті з частотою WAVE_RATE.
const WAVE := 18.0
const WAVE_RATE := 5.0
## Додому не долетіти за HOME_TIMEOUT с (стіна між ним і домом) — новий дім тут.
const HOME_TIMEOUT := 6.0

enum Phase { NONE, WINDUP, DIVE, GLIDE, RECOVER, BITE }
var phase := Phase.NONE
var style: StringName = DIVE
var hover_height := 0.0
var dive_speed := 0.0
## Гриф низько — його можна бити (кажана — завжди, reachable()).
var low := false
## Найнижча точка поточного піке (найбільший y).
var _bottom_y := 0.0
var _t := 0.0
## Куди б'є (центр героя в мить підказки) і напрямок піке чи ривка.
var _target := Vector2.ZERO
var _lunge_dir := Vector2.ZERO
## Куди кажан відлітає після укусу.
var _away := Vector2.ZERO
## На скільки px намальоване дно виросло з арт (D766, meta «grown» спрайта — у скільки разів): на стільки вище
## його висота біля героя й дно піке чи укусу, бо тіло (і з ним шлях) лишилось колишнім.
var _lift := 0.0


func initialize(enemy_node: CharacterBody2D) -> void:
	super.initialize(enemy_node)
	style = StringName(enemy.flight_attack)
	hover_height = enemy.hover_height
	dive_speed = enemy.dive_speed
	_lift = _art_growth()


## Приріст намальованого дна (px вниз від центру): кадри польоту й удару — ті, що на екрані біля героя.
func _art_growth() -> float:
	var sprite: Sprite2D = enemy.sprite
	var grown: float = sprite.get_meta(&"grown", 1.0)
	var drawn := HitAreas.body_rect(sprite, enemy.anim_player).merge(
			HitAreas.strike_rect(sprite, enemy.anim_player, enemy.attack_active_time))
	return maxf(drawn.end.y - sprite.position.y, 0.0) * (1.0 - 1.0 / grown)


## Чи дістане його удар героя: кажана — завжди, грифа — лише низько.
func reachable() -> bool:
	return style == BITE or low


func process_ai(delta: float) -> void:
	_t += delta
	if enemy.is_dead:
		velocity = Vector2.ZERO
		return
	_track_low()
	if knockback_left > 0.0:
		knockback_left -= delta
		velocity = Vector2(knockback_speed, 0.0)
		return
	if stun_left > 0.0:
		stun_left -= delta
		velocity = Vector2.ZERO
		return
	if not player or not is_instance_valid(player):
		player = GameGroups.get_player()
	if is_attacking:
		velocity = Vector2.ZERO if attack_broken else _attack_velocity()
		return
	match current_state:
		AIState.IDLE:
			_patrol()
		AIState.CHASE, AIState.ATTACK:
			_chase(delta)
		AIState.RETREAT:
			_retreat()
		AIState.RETURN_HOME:
			_home()


## Дно піке й підйом: низько, доки не піднявся на LOW_BAND над найнижчою точкою.
func _track_low() -> void:
	if not low:
		return
	if phase in [Phase.DIVE, Phase.GLIDE, Phase.RECOVER]:
		_bottom_y = maxf(_bottom_y, enemy.global_position.y)
	elif enemy.global_position.y < _bottom_y - LOW_BAND:
		low = false


func _patrol() -> void:
	if chase_cooldown_timer >= chase_cooldown and _hero_noticed(detection_range):
		chase_cooldown_timer = 0.0
		change_state(AIState.CHASE)
		return
	_fly_to(home_position + Vector2(sin(_t * PATROL_RATE) * PATROL, sin(_t * 2.0) * BOB), speed * 0.5, true)


func _hero_noticed(within: float) -> bool:
	return player and is_instance_valid(player) and absf(player.global_position.x - enemy.global_position.x) <= within and can_notice(player)


func _chase(delta: float) -> void:
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	if absf(enemy.global_position.x - home_position.x) > leash_range:
		_give_up()
		return
	var noticed := can_notice(player)
	if absf(player.global_position.x - enemy.global_position.x) > chase_range or not noticed:
		lost_player_timer += delta
		if lost_player_timer > max_lost_time:
			_give_up()
			return
	else:
		lost_player_timer = 0.0
	var can_strike: bool = attack_ready_in <= 0.0 and token_free() and enemy.stamina.can_afford(&"swing")  # D824
	var station := _station(can_strike)
	_fly_to(station, speed, false)
	_face_player()
	if noticed and can_strike and _in_reach(station):
		attack_ready_in = enemy.attack_cooldown
		perform_attack()


## Де ворог тримається біля героя: гриф кружляє над ним на hover_height; кажан — збоку на висоті голови, хвилею, на
## відстані удару, коли готовий, і трохи далі (WAIT_GAP), поки чекає.
func _station(can_strike: bool) -> Vector2:
	var hero: Node2D = player
	var height := _feet_y(hero) - hover_height - _lift
	if style == DIVE:
		return Vector2(hero.global_position.x + cos(_t * ORBIT_RATE) * ORBIT_X, height + sin(_t * ORBIT_RATE * 2.0) * ORBIT_Y)
	var side := -1.0 if hero.global_position.x > enemy.global_position.x else 1.0
	var gap := attack_range * 0.75 if can_strike else attack_range + WAIT_GAP
	return Vector2(hero.global_position.x + side * gap, height + sin(_t * WAVE_RATE) * WAVE)


func _in_reach(station: Vector2) -> bool:
	var dx := absf(player.global_position.x - enemy.global_position.x)
	if style == DIVE:
		return dx <= attack_range and enemy.global_position.distance_to(station) <= ORBIT_READY
	return dx <= attack_range and absf(enemy.global_position.y - (_feet_y(player) - hover_height - _lift)) <= WAVE + 12.0


## Летить до [param point] зі швидкістю [param fly_speed], біля самої точки — повільніше. [param face_travel] —
## дивиться, куди летить (патруль, дорога додому); інакше погляд веде _face_player.
func _fly_to(point: Vector2, fly_speed: float, face_travel: bool) -> void:
	var to := point - enemy.global_position
	velocity = to.normalized() * minf(fly_speed, to.length() * ARRIVE)
	if face_travel and absf(velocity.x) > 5.0:
		_face(1 if velocity.x > 0.0 else -1)


func _face(dir: int) -> void:
	if dir != last_direction:
		direction_changed.emit(dir)
		last_direction = dir


## Відхід кажана після укусу — назад і вгору, обличчям до героя.
func _retreat() -> void:
	_fly_to(_away, speed, false)
	_face_player()
	if enemy.global_position.distance_to(_away) <= 8.0 or state_timer > enemy.back_off / speed + BACK_OFF_SLACK:
		change_state(AIState.CHASE)


func _home() -> void:
	if enemy.global_position.distance_to(home_position) <= 5.0 or state_timer > HOME_TIMEOUT:
		home_position = enemy.global_position
		change_state(AIState.IDLE)
		return
	_fly_to(home_position, return_home_speed, true)


## Куди б'є: центр героя, вище на приріст арту (_lift).
func _hero_centre() -> Vector2:
	return (player as Node2D).global_position - Vector2(0.0, _lift)


## Рух під час удару. Поки йде замах до підказки — ціль іде за героєм; після підказки вона зафіксована.
func _attack_velocity() -> Vector2:
	if phase == Phase.WINDUP and winding_up and player and is_instance_valid(player):
		_target = _hero_centre()
		_face_player()
	match phase:
		Phase.WINDUP:
			return Vector2(WINDUP_DRIFT.x * last_direction, WINDUP_DRIFT.y) if style == DIVE else Vector2.ZERO
		Phase.DIVE:
			return _lunge_dir * dive_speed
		Phase.GLIDE:
			return Vector2(signf(_lunge_dir.x) * dive_speed * GLIDE_SPEED, 0.0)
		Phase.RECOVER:
			return Vector2(last_direction * speed * RECOVER_DRIFT, 0.0) if style == DIVE else Vector2.ZERO
		Phase.BITE:
			return _lunge_dir * (enemy.lunge / enemy.attack_active_time)
	return Vector2.ZERO


## Один удар (піке чи укус): замах із підказкою (EnemyLogic.wind_up), удар уздовж зафіксованої лінії, поза відновлення.
func perform_attack() -> void:
	is_attacking = true
	attack_broken = false
	_hold_token()
	finisher = false
	tell_kind = enemy.tell
	swing_windup = enemy.attack_windup
	_target = _hero_centre()
	phase = Phase.WINDUP
	attack_started.emit()
	EventBus.attack_started.emit(enemy, player)
	await wind_up(enemy.attack_windup)
	if not _interrupted():
		_lunge_dir = (_target - enemy.global_position).normalized()
		var direction := 1 if _lunge_dir.x >= 0.0 else -1
		_face(direction)
		enemy.start_attack(direction)
		enemy.stamina.spend(&"swing")  # D824: піке чи укус
		if style == DIVE:
			await _dive()
		else:
			phase = Phase.BITE
			await get_tree().create_timer(enemy.attack_active_time, false).timeout
		enemy.end_attack()
	committed = false
	_release_token()
	if not _interrupted():
		phase = Phase.RECOVER
		await _recover(_recovery_time())
	phase = Phase.NONE
	is_attacking = false
	enemy.stamina.take_winded()  # D824: вичерпав — зависає, видихнувшись
	attack_ended.emit()
	if style == BITE and not enemy.is_dead:
		var toward := 1.0 if player.global_position.x > enemy.global_position.x else -1.0
		_away = enemy.global_position + Vector2(-toward, -0.5) * enemy.back_off
		change_state(AIState.RETREAT)


## Піке до цілі, потім низький проліт далі; гриф низько з першої миті піке.
func _dive() -> void:
	low = true
	_bottom_y = enemy.global_position.y
	phase = Phase.DIVE
	await get_tree().create_timer(enemy.global_position.distance_to(_target) / dive_speed, false).timeout
	if _interrupted():
		return
	phase = Phase.GLIDE
	await get_tree().create_timer(GLIDE_TIME, false).timeout
