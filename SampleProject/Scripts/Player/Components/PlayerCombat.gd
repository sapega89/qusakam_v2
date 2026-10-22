extends Node
class_name PlayerCombat

## Component handling player combat logic extracted from Player.gd
## Following SRP: This class only cares about attacking and damage state.
## Стан бою souls-lite (D264): серія легких ударів, важкий удар, блок і парирування, збій від ворожого удару.
## Таймери — у _physics_process, а не await анімації.

const SkillCastFX := preload("res://SampleProject/Scripts/FX/SkillCastFX.gd")
const CombatRolls := preload("res://SampleProject/Scripts/Combat/CombatRolls.gd")

enum State { READY, SWING, HEAVY_WINDUP, HEAVY_STRIKE, BLOCK, STAGGER, CAST_WINDUP, CAST_RELEASE, SHOOT, DRAW, CHARGED }

# External references
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var hitbox: Area2D
@export var damage_applier: DamageApplier

# Combat parameters. Голі руки: кулдаун тут, хітбокс — Player.tscn (Hitbox 40×32); зброя в руці
# перезаписує обидва своїм weapon_profile з items.json (D203).
## Відновлення після фінішера серії (у зброї — weapon_profile.cooldown, D203).
@export var attack_cooldown_time: float = 0.5
## Тривалість одного удару — довжина анімації Attack у Player.tscn; швидкість атаки (D393) її скорочує.
@export var swing_time: float = 0.3
## Крит (D393): удар, що випав з шансом GameManager.calculate_critical_chance, б'є в CRIT_DAMAGE раз сильніше.
const CRIT_DAMAGE := 1.5
## Останній hit_damage() був критом — його несе удар (DamageApplier.critical) чи стріла (Arrow.critical).
var critical: bool = false
## Серія (D264): множники ушкодження ударів; наступний удар — якщо натиснуто під час удару або за chain_window після.
const COMBO_DAMAGE: Array[float] = [1.0, 1.0, 1.4]
## Дві зброї (D267): серія з чотирьох ударів, що чергують руки, кожен швидший у DUAL_SWING_SPEED раз.
const DUAL_COMBO_DAMAGE: Array[float] = [1.0, 1.0, 1.0, 1.4]
const DUAL_SWING_SPEED := 0.8
## Дворучна (D267): стійкість ворога б'є в TWO_HANDED_POISE раз сильніше.
const TWO_HANDED_POISE := 1.5
## Тіло на ударі — своя анімація для типу зброї (D268), решта — Attack.
const SWING_ANIMATIONS := {"mace": &"AttackSmash", "polearm": &"AttackThrust"}
@export var chain_window: float = 0.35
## Легкий удар без відкидання зброї штовхає ворога на стільки px (4b).
const HIT_PUSH := 8.0
## Фінішер серії відкидає ворога (px) і бʼє стійкість удвічі.
@export var finisher_knockback: float = 40.0
## Важкий удар (D264): замах (його можна збити), удар, відновлення; множник, відкидання.
@export var heavy_windup: float = 0.4
@export var heavy_strike_time: float = 0.25
@export var heavy_recovery: float = 1.0
@export var heavy_damage: float = 1.5
@export var heavy_knockback: float = 70.0
## Скільки стійкості ворога (D265) забирає удар.
const POISE_LIGHT := 1
const POISE_FINISHER := 2
const POISE_HEAVY := 3
## Блок (D264, 4b): удар спереду шкоди не завдає; парирування — удар у перші PARRY_WINDOW с блоку.
## Ворог показує відблиск рівно за PARRY_WINDOW до удару (EnemyLogic.wind_up): блок на відблиск — парирування.
const PARRY_WINDOW := 0.25
## Удар, що збив би героя на стільки секунд і довше (tank, фінішер серії), пробиває блок.
const GUARD_BREAK := 0.6
## Лук (D380–D382, design/ranged_plan.md), як у Skul: швидкий постріл — одразу на натискання удару, стріла вилітає
## через QUICK_RELEASE с (кадр Shoot/1 у bow/Attack1), поза — SHOT_TIME с; кнопку тримають далі — натяг DRAW_TIME с
## (рух стоїть, перекат зриває), потім заряджено; відпустили заряджений — заряджений постріл (поза Release).
## Відпустили раніше — лук опускається без стріли. Важкий удар з луком — одразу натяг.
const ARROW_SCENE := preload("res://SampleProject/Scenes/Combat/arrow.tscn")
const CHARGED_ARROW_SCENE := preload("res://SampleProject/Scenes/Combat/arrow_charged.tscn")
## Наконечник накладеної стріли в кадрах лука, px світу від центру героя обличчям праворуч
## (Weapons/bow/README.md: (76, 61) у клітинці 96×96, зсув (0, −16), ×1.5).
const ARROW_FROM := Vector2(42, -5)
const QUICK_SHOT_DAMAGE := 0.7
const CHARGED_SHOT_DAMAGE := 1.8
const CHARGED_KNOCKBACK := 60.0
const QUICK_RELEASE := 0.05
const SHOT_TIME := 0.22
const DRAW_TIME := 0.6
const RELEASE_TIME := 0.3
## Кнопку удару чи важкого тримають (Player._unhandled_input) — після пострілу лук натягується.
var shot_held: bool = false
## Швидкий постріл іде, а стріла ще не вилетіла.
var _arrow_due: bool = false

## Збій героя (D264): на скільки px його відносить від того, хто вдарив, і за який час.
@export var stagger_push: float = 50.0
@export var stagger_push_time: float = 0.15

## Відкидання ворога поточним ударом, px (булава D203, фінішер, важкий). VFXHooks: > 0 — важке влучання.
var knockback: float = 0.0
var _weapon_knockback: float = 0.0
var _bare_size: Vector2
## Хват і тип зброї в руці (EquipmentManager.get_grip(), items.json category).
var grip: StringName = &"bare"
var _category: String = ""
var _bare_cooldown: float
var attack_cooldown: float = 0.0

var state: State = State.READY
var _state_left: float = 0.0
var _direction: int = 1
## Крок серії, що йде або щойно скінчився (0 — перший); _chain_left — скільки ще чекати наступного.
var combo_step: int = 0
var _chain_left: float = 0.0
var _queued: bool = false
var _poise: int = POISE_LIGHT
## Кнопку блоку тримають (Player._unhandled_input); блок починається, щойно герой вільний.
var block_held: bool = false
var _block_time: float = 0.0
## Бій триває (D266, D268): ворог женеться за героєм чи б'є, або герой бив / був збитий — і ще COMBAT_LINGER с після.
## Поза боєм зброя за спиною, а в місті герой іде.
const COMBAT_LINGER := 3.0
var _combat_left: float = 0.0
var _in_combat: bool = false
## D259: навичка, чий замах зараз іде; удар зриває каст. Каст (D271): <pose>Windup → <pose>Release у Player.tscn,
## ефект — сцена skills.json → vfx (SkillCastFX) на героєві.
var casting_skill: String = ""
var _cast: SkillDefinition
var _cast_fx: SkillCastFX

var is_attacking: bool:
	get:
		return state in [State.SWING, State.HEAVY_WINDUP, State.HEAVY_STRIKE, State.SHOOT, State.DRAW, State.CHARGED]

# Parent reference (for getting direction and signals)
@onready var player = get_parent()

func _ready() -> void:
	_bare_size = _hitbox_shape().size
	_bare_cooldown = attack_cooldown_time
	_set_hitbox_active(false, 1) # Ensure hitbox is disabled on start
	EventBus.weapon_in_hand_changed.connect(func(_slot: String) -> void: apply_weapon_profile())
	# Друга зброя (D267) залежить і від того, що вдягнено, а не лише від зброї в руці
	EventBus.equipment_equipped.connect(func(_c: String, _s: String, _i: String) -> void: apply_weapon_profile())
	EventBus.equipment_unequipped.connect(func(_c: String, _s: String) -> void: apply_weapon_profile())
	damage_applier.damage_applied.connect(_on_damage_applied)
	apply_weapon_profile()

## Профіль удару зброї в руці (D202/D203): довжина й висота хітбокса, кулдаун, відкидання.
func apply_weapon_profile() -> void:
	var equipment := ServiceLocator.get_equipment_manager()
	var item: Dictionary = equipment.get_weapon_item_in_hand()
	grip = equipment.get_grip()
	_category = "" if item.is_empty() else String(item.category)
	if item.is_empty():
		_hitbox_shape().size = _bare_size
		attack_cooldown_time = _bare_cooldown
		_weapon_knockback = 0.0
	elif grip == &"bow":
		# Лук б'є стрілами (D383): хітбокс — як у голих рук (його зону б'ють навички, D142); з профілю — темп
		# пострілів і відкидання.
		_hitbox_shape().size = _bare_size
		var bow: Dictionary = item.weapon_profile
		attack_cooldown_time = bow.cooldown
		_weapon_knockback = bow.knockback
	else:
		var profile: Dictionary = item.weapon_profile
		_hitbox_shape().size = Vector2(profile.reach, profile.height)
		attack_cooldown_time = profile.cooldown
		_weapon_knockback = profile.knockback
	knockback = _weapon_knockback

func _hitbox_shape() -> RectangleShape2D:
	return hitbox.get_node(^"CollisionShape2D").shape

## Влучання: відкидання і стійкість ворога (D265).
func _on_damage_applied(target: Node, damage: int) -> void:
	_hit_effects(target, damage, _poise, knockback, player.global_position.x)

## Влучання стріли героя (D381): та сама стійкість, пасивки й відкидання, що й від удару, — від точки, звідки летіла
## стріла ([param from_x]); підстрелений ворог повертається до героя, навіть якщо ще його не бачив.
func on_arrow_hit(target: Node, damage: int, poise: int, push: float, from_x: float) -> void:
	_hit_effects(target, damage, poise, push, from_x)
	target.enemy_logic.on_player_detected(player)

## Стійкість — першою: її збій штовхає ворога на 30 px, а відкидання удару (булава, фінішер, важкий) — далі й перекриває.
func _hit_effects(target: Node, damage: int, poise: int, push: float, from_x: float) -> void:
	var skills: SkillManager = ServiceLocator.get_skill_manager()
	target.take_poise(roundi(poise * (1.0 + skills.passive_value("poise"))), from_x)  # D284
	var drained := roundi(damage * skills.passive_value("lifesteal"))  # D284: Blood Pact
	if drained > 0:
		player.heal_damage(drained)
	var away: float = signf(target.global_position.x - from_x)
	if push > 0.0:
		target.knockback(away * push)
	else:
		# Легкий удар теж штовхає (4b «мало відчуття удару»), але замаху не зриває — це робить стійкість (D265)
		target.nudge(away * HIT_PUSH)

## Сила удару = Phys. Atk. з меню (D199): сила, зброя, бонус рівня. Береться на кожен удар,
## тож зміна спорядження чи рівня діє одразу, без підписок. Крит (D393) — кидок на кожен удар, ×CRIT_DAMAGE.
func hit_damage() -> int:
	var gm := ServiceLocator.get_game_manager()
	critical = CombatRolls.roll(gm.calculate_critical_chance())
	var damage: int = gm.calculate_physical_damage()
	return roundi(damage * CRIT_DAMAGE) if critical else damage

func _combo_damage() -> Array[float]:
	return DUAL_COMBO_DAMAGE if grip == &"dual" else COMBO_DAMAGE

func combo_length() -> int:
	return _combo_damage().size()

func _poise_of(base: int) -> int:
	return roundi(base * TWO_HANDED_POISE) if grip == &"two_handed" else base

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

func _physics_process(delta: float) -> void:
	_track_combat(delta)
	if _chain_left > 0.0:
		_chain_left -= delta
	if state == State.BLOCK:
		_block_time += delta
		if not block_held:
			state = State.READY
		return
	if state == State.READY:
		if block_held:
			_start_block()
		elif _queued and attack_cooldown <= 0.0:
			# Наступний удар серії — кадром пізніше: хітбокс мусить хоч кадр побути вимкненим,
			# інакше ворог, що стоїть у ньому, не «увійде» вдруге й не отримає удару.
			# Постріл, натиснутий під час попереднього, чекає кінця темпу лука (attack_cooldown) і летить туди,
			# куди герой дивиться тепер.
			_queued = false
			perform_attack(player.last_direction if grip == &"bow" else _direction)
		return
	_state_left -= delta
	if _arrow_due and SHOT_TIME - _state_left >= QUICK_RELEASE:
		_loose(false)
	if _state_left > 0.0:
		return
	match state:
		State.SWING:
			_set_hitbox_active(false, _direction)
			state = State.READY
			if combo_step < combo_length() - 1:
				_chain_left = chain_window
		State.HEAVY_WINDUP:
			_strike_heavy()
		State.HEAVY_STRIKE:
			_set_hitbox_active(false, _direction)
			attack_cooldown = heavy_recovery
			state = State.READY
		State.STAGGER:
			state = State.READY
		State.CAST_WINDUP:
			_release_cast()
		State.CAST_RELEASE:
			state = State.READY
		State.SHOOT:
			state = State.READY
			if shot_held:
				_start_draw()
		State.DRAW:
			state = State.CHARGED
			_state_left = INF  # тримає, доки кнопку не відпустять
			_play(&"Charged")

func in_combat() -> bool:
	return _in_combat

## Кат-сцена, розмова, скриня (герой у event) чи поразка — не бій: він кінчається одразу, без COMBAT_LINGER (B116).
func _track_combat(delta: float) -> void:
	if player.event or player.is_dead:
		_combat_left = 0.0
	elif state not in [State.READY, State.BLOCK] or _enemy_engaged():
		_combat_left = COMBAT_LINGER
	else:
		_combat_left -= delta
	var now := _combat_left > 0.0
	if now != _in_combat:
		_in_combat = now
		EventBus.combat_state_changed.emit(now)

func _enemy_engaged() -> bool:
	for enemy in get_tree().get_nodes_in_group(GameGroups.ENEMIES):
		if enemy.is_alive() and (enemy.enemy_logic.is_attacking or enemy.enemy_logic.current_state in [EnemyLogic.AIState.CHASE, EnemyLogic.AIState.ATTACK]):
			return true
	return false

## Гравець вийшов з дерева посеред дії (зміна сцени, вихід у меню) — дія скінчилась, а не застигла до повернення.
func _exit_tree() -> void:
	damage_applier.disable_damage()
	state = State.READY
	_queued = false
	_arrow_due = false
	block_held = false
	shot_held = false
	casting_skill = ""  # каст не зірвано ударом — нічого не списано

## Анімацію героя зараз веде бій, а не рух (Player._physics_process її не перемикає).
func owns_animation() -> bool:
	return state != State.READY

## Рух вимкнено: збій, важкий удар, блок, каст навички, натяг лука (герой стоїть). Легкі удари й швидкі постріли
## рух не гальмують (D223, D382).
func locks_movement() -> bool:
	return state in [State.STAGGER, State.HEAVY_WINDUP, State.HEAVY_STRIKE, State.BLOCK, State.CAST_WINDUP, State.CAST_RELEASE, State.DRAW, State.CHARGED]

func is_staggered() -> bool:
	return state == State.STAGGER

func is_blocking() -> bool:
	return state == State.BLOCK

## Легкий удар (D264): перший серії або наступний, якщо попередній щойно скінчився; натиснутий посеред удару — у черзі.
## З луком — швидкий постріл (D380).
func perform_attack(last_direction: int) -> void:
	if grip == &"bow":
		_quick_shot(last_direction)
		return
	if state == State.SWING:
		_queued = combo_step < combo_length() - 1
		return
	if state != State.READY or attack_cooldown > 0:
		return
	combo_step = combo_step + 1 if _chain_left > 0.0 else 0
	_chain_left = 0.0
	var finisher := combo_step == combo_length() - 1
	state = State.SWING
	# Швидкість атаки (D393): множник 1.0–2.0 зі спритності й Agility скорочує замах
	_state_left = swing_time * (DUAL_SWING_SPEED if grip == &"dual" else 1.0) / ServiceLocator.get_game_manager().calculate_attack_speed()
	_direction = last_direction
	knockback = maxf(_weapon_knockback, finisher_knockback) if finisher else _weapon_knockback
	_poise = _poise_of(POISE_FINISHER if finisher else POISE_LIGHT)
	if finisher:
		attack_cooldown = attack_cooldown_time  # відновлення після серії
	damage_applier.current_damage = roundi(hit_damage() * _combo_damage()[combo_step])
	damage_applier.critical = critical

	# flip_h більше не чіпаємо: єдине джерело — Player._update_facing().
	var body: StringName = SWING_ANIMATIONS.get(_category, &"Attack")
	player.animation = body
	player.play_body(body, swing_time / _state_left)  # дві зброї, швидкість атаки — швидше

	# Signals — без цього VFXHooks._on_player_attacked() не спрацьовував жодного разу
	EventBus.player_attacked.emit(player, last_direction)
	_set_hitbox_active(true, last_direction)

## Важкий удар (D264): замах heavy_windup (удар по героєві його зриває), потім удар ×heavy_damage з відкиданням.
## З луком — одразу натяг на заряджений постріл (D384).
func heavy_attack(last_direction: int) -> void:
	if grip == &"bow":
		if state == State.READY:
			_direction = last_direction
			_start_draw()
		return
	if state != State.READY or attack_cooldown > 0:
		return
	state = State.HEAVY_WINDUP
	_state_left = heavy_windup
	_direction = last_direction
	_chain_left = 0.0
	combo_step = 0
	_play(&"HeavyWindup")
	EventBus.player_heavy_windup.emit(player, last_direction)

func _strike_heavy() -> void:
	state = State.HEAVY_STRIKE
	_state_left = heavy_strike_time
	knockback = maxf(_weapon_knockback, heavy_knockback)
	_poise = _poise_of(POISE_HEAVY)
	damage_applier.current_damage = roundi(hit_damage() * heavy_damage)
	damage_applier.critical = critical
	_play(&"HeavyStrike")
	EventBus.player_attacked.emit(player, _direction)
	_set_hitbox_active(true, _direction)

## Швидкий постріл (D380): натиснутий посеред пострілу чи до кінця темпу лука — один у черзі; натяг і заряджений
## лук — без змін.
func _quick_shot(last_direction: int) -> void:
	if state == State.SHOOT or (state == State.READY and attack_cooldown > 0):
		_queued = true
		return
	if state != State.READY:
		return
	state = State.SHOOT
	_state_left = SHOT_TIME
	_direction = last_direction
	_arrow_due = true
	combo_step = 0
	attack_cooldown = attack_cooldown_time
	_play(&"Attack")

## Кнопку удару чи важкого відпустили: заряджений лук стріляє, недотягнутий — опускається.
func release_shot() -> void:
	shot_held = false
	if state == State.CHARGED:
		_loose(true)
		state = State.SHOOT
		_state_left = RELEASE_TIME
		_play(&"Release")
	elif state == State.DRAW:
		state = State.READY

## Натяг (D380): рух стоїть DRAW_TIME с, далі лук заряджений.
func _start_draw() -> void:
	state = State.DRAW
	_state_left = DRAW_TIME
	_queued = false
	_play(&"Draw")
	EventBus.player_bow_drawn.emit(player)

## Перекат зриває натяг (D382) — без стріли.
func cancel_draw() -> void:
	if state in [State.DRAW, State.CHARGED]:
		state = State.READY

## Стріла з наконечника в кадрі туди, куди дивився герой на початку пострілу (D381). Летить у кімнаті, не в героєві.
func _loose(charged: bool) -> void:
	_arrow_due = false
	var arrow: Arrow = (CHARGED_ARROW_SCENE if charged else ARROW_SCENE).instantiate()
	arrow.direction = _direction
	arrow.shooter = player
	arrow.damage = roundi(hit_damage() * (CHARGED_SHOT_DAMAGE if charged else QUICK_SHOT_DAMAGE))
	arrow.critical = critical
	arrow.poise = POISE_HEAVY if charged else POISE_LIGHT
	arrow.knockback = maxf(_weapon_knockback, CHARGED_KNOCKBACK) if charged else _weapon_knockback
	Game.get_singleton().map.add_child(arrow)
	arrow.global_position = player.global_position + Vector2(ARROW_FROM.x * _direction, ARROW_FROM.y)
	EventBus.player_shot.emit(player, charged)

## Каст навички (D271): замах definition.cast_windup с — тут удар по героєві зриває каст (stagger), — потім
## вивільнення: SkillManager.use_skill застосовує ефект. false — герой зайнятий.
func begin_cast(definition: SkillDefinition) -> bool:
	if state != State.READY:
		return false
	state = State.CAST_WINDUP
	_state_left = definition.cast_windup
	_direction = player.last_direction
	_chain_left = 0.0
	combo_step = 0
	casting_skill = definition.id
	_cast = definition
	_play(StringName(definition.cast_pose + "Windup"))
	_cast_fx = load(definition.vfx).instantiate()
	_cast_fx.skill = definition
	_cast_fx.scale.x = _direction
	player.add_child(_cast_fx)
	EventBus.skill_cast_started.emit(definition.id)
	return true

func _release_cast() -> void:
	var skill_id := casting_skill
	casting_skill = ""
	state = State.CAST_RELEASE
	_state_left = _cast.cast_release
	_play(StringName(_cast.cast_pose + "Release"))
	_cast_fx.release()
	_cast_fx = null
	ServiceLocator.get_skill_manager().use_skill(skill_id, null, player)

## Анімація тіла — з кадрів зброї в руці, якщо вони є (Player.play_body, BACKLOG 42).
func _play(animation: StringName) -> void:
	player.animation = animation
	player.play_body(animation)

func _start_block() -> void:
	state = State.BLOCK
	_block_time = 0.0
	_chain_left = 0.0
	_play(&"Block")

## Удар по героєві в блоці (D264): &"parry" — у перші PARRY_WINDOW с, &"block" — спереду, &"" — не захищено
## (не в блоці, удар ззаду, не ворог і не стріла лучника — D384).
func guard_against(source: Node) -> StringName:
	if state != State.BLOCK or not (source is DefaultEnemy or source is Arrow):
		return &""
	var side: float = signf(source.global_position.x - player.global_position.x)
	if side != 0.0 and side != player.last_direction:
		return &""
	return &"parry" if _block_time <= PARRY_WINDOW else &"block"

## Удар ворога збив героя (D264): дія, що йшла, зірвана, герой відлітає від [param from_x] і [param duration] с
## не керується. «Вороги інколи заморожують героя» (D253) — довгий збій від tank і фінішера серії.
## Каст навички, що йшов, зірвано (D259): SP і кулдаун списуються, ефекту немає.
func stagger(duration: float, from_x: float) -> void:
	if state in [State.SWING, State.HEAVY_STRIKE]:
		_set_hitbox_active(false, _direction)
	if casting_skill != "":
		ServiceLocator.get_skill_manager().interrupt_cast(casting_skill)
		casting_skill = ""
		_cast_fx.cancel()
		_cast_fx = null
	state = State.STAGGER
	_state_left = duration
	_queued = false
	_arrow_due = false
	_chain_left = 0.0
	_play(&"Hurt")
	var away: float = signf(player.global_position.x - from_x)
	player.mover.push(away * stagger_push, stagger_push_time)
	EventBus.player_staggered.emit(duration)

func _set_hitbox_active(active: bool, last_direction: int) -> void:
	if active:
		# Хітбокс починається біля героя й тягнеться на довжину зброї вперед. Ту саму зону бʼють навички (D142).
		hitbox.position = Vector2(_hitbox_shape().size.x / 2.0 * signi(last_direction), 0)
	# Відкладено: збій героя приходить із body_entered хітбокса ворога, посеред фізичного запиту.
	hitbox.set_deferred(&"monitoring", active)
	hitbox.set_deferred(&"monitorable", active)

	if active:
		damage_applier.enable_damage()
	else:
		damage_applier.disable_damage()
