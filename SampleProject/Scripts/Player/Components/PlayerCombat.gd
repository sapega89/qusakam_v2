extends Node
class_name PlayerCombat

## Component handling player combat logic extracted from Player.gd
## Following SRP: This class only cares about attacking and damage state.
## Стан бою souls-lite (D264): серія легких ударів, важкий удар, блок і парирування, збій від ворожого удару.
## Таймери — у _physics_process, а не await анімації.

const SkillCastFX := preload("res://SampleProject/Scripts/FX/SkillCastFX.gd")

enum State { READY, SWING, HEAVY_WINDUP, HEAVY_STRIKE, BLOCK, STAGGER, CAST_WINDUP, CAST_RELEASE }

# External references
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var hitbox: Area2D
@export var damage_applier: DamageApplier

# Combat parameters. Голі руки: кулдаун тут, хітбокс — Player.tscn (Hitbox 40×32); зброя в руці
# перезаписує обидва своїм weapon_profile з items.json (D203).
## Відновлення після фінішера серії (у зброї — weapon_profile.cooldown, D203).
@export var attack_cooldown_time: float = 0.5
## Тривалість одного удару — довжина анімації Attack у Player.tscn.
@export var swing_time: float = 0.3
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
		return state in [State.SWING, State.HEAVY_WINDUP, State.HEAVY_STRIKE]

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
	else:
		var profile: Dictionary = item.weapon_profile
		_hitbox_shape().size = Vector2(profile.reach, profile.height)
		attack_cooldown_time = profile.cooldown
		_weapon_knockback = profile.knockback
	knockback = _weapon_knockback

func _hitbox_shape() -> RectangleShape2D:
	return hitbox.get_node(^"CollisionShape2D").shape

## Влучання: відкидання і стійкість ворога (D265).
## Стійкість — першою: її збій штовхає ворога на 30 px, а відкидання удару (булава, фінішер, важкий) — далі й перекриває.
func _on_damage_applied(target: Node, damage: int) -> void:
	var skills: SkillManager = ServiceLocator.get_skill_manager()
	target.take_poise(roundi(_poise * (1.0 + skills.passive_value("poise"))), player.global_position.x)  # D284
	var drained := roundi(damage * skills.passive_value("lifesteal"))  # D284: Blood Pact
	if drained > 0:
		player.heal_damage(drained)
	if knockback > 0.0:
		target.knockback(signf(target.global_position.x - player.global_position.x) * knockback)

## Сила удару = Phys. Atk. з меню (D199): сила, зброя, бонус рівня. Береться на кожен удар,
## тож зміна спорядження чи рівня діє одразу, без підписок.
func hit_damage() -> int:
	return ServiceLocator.get_game_manager().calculate_physical_damage()

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
		elif _queued:
			# Наступний удар серії — кадром пізніше: хітбокс мусить хоч кадр побути вимкненим,
			# інакше ворог, що стоїть у ньому, не «увійде» вдруге й не отримає удару.
			_queued = false
			perform_attack(_direction)
		return
	_state_left -= delta
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

func in_combat() -> bool:
	return _in_combat

func _track_combat(delta: float) -> void:
	if state not in [State.READY, State.BLOCK] or _enemy_engaged():
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
	block_held = false
	casting_skill = ""  # каст не зірвано ударом — нічого не списано

## Анімацію героя зараз веде бій, а не рух (Player._physics_process її не перемикає).
func owns_animation() -> bool:
	return state != State.READY

## Рух вимкнено: збій, важкий удар, блок, каст навички (герой стоїть). Легкі удари рух не гальмують (D223).
func locks_movement() -> bool:
	return state in [State.STAGGER, State.HEAVY_WINDUP, State.HEAVY_STRIKE, State.BLOCK, State.CAST_WINDUP, State.CAST_RELEASE]

func is_staggered() -> bool:
	return state == State.STAGGER

func is_blocking() -> bool:
	return state == State.BLOCK

## Легкий удар (D264): перший серії або наступний, якщо попередній щойно скінчився; натиснутий посеред удару — у черзі.
func perform_attack(last_direction: int) -> void:
	if state == State.SWING:
		_queued = combo_step < combo_length() - 1
		return
	if state != State.READY or attack_cooldown > 0:
		return
	combo_step = combo_step + 1 if _chain_left > 0.0 else 0
	_chain_left = 0.0
	var finisher := combo_step == combo_length() - 1
	state = State.SWING
	_state_left = swing_time * (DUAL_SWING_SPEED if grip == &"dual" else 1.0)
	_direction = last_direction
	knockback = maxf(_weapon_knockback, finisher_knockback) if finisher else _weapon_knockback
	_poise = _poise_of(POISE_FINISHER if finisher else POISE_LIGHT)
	if finisher:
		attack_cooldown = attack_cooldown_time  # відновлення після серії
	damage_applier.current_damage = roundi(hit_damage() * _combo_damage()[combo_step])

	# flip_h більше не чіпаємо: єдине джерело — Player._update_facing().
	var body: StringName = SWING_ANIMATIONS.get(_category, &"Attack")
	animation_player.play(body, -1, swing_time / _state_left)  # дві зброї — швидше
	player.animation = body

	# Signals — без цього VFXHooks._on_player_attacked() не спрацьовував жодного разу
	EventBus.player_attacked.emit(player, last_direction)
	_set_hitbox_active(true, last_direction)

## Важкий удар (D264): замах heavy_windup (удар по героєві його зриває), потім удар ×heavy_damage з відкиданням.
func heavy_attack(last_direction: int) -> void:
	if state != State.READY or attack_cooldown > 0:
		return
	state = State.HEAVY_WINDUP
	_state_left = heavy_windup
	_direction = last_direction
	_chain_left = 0.0
	combo_step = 0
	animation_player.play(&"HeavyWindup")
	player.animation = &"HeavyWindup"
	EventBus.player_heavy_windup.emit(player, last_direction)

func _strike_heavy() -> void:
	state = State.HEAVY_STRIKE
	_state_left = heavy_strike_time
	knockback = maxf(_weapon_knockback, heavy_knockback)
	_poise = _poise_of(POISE_HEAVY)
	damage_applier.current_damage = roundi(hit_damage() * heavy_damage)
	animation_player.play(&"HeavyStrike")
	player.animation = &"HeavyStrike"
	EventBus.player_attacked.emit(player, _direction)
	_set_hitbox_active(true, _direction)

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

func _play(animation: StringName) -> void:
	animation_player.play(animation)
	player.animation = animation

func _start_block() -> void:
	state = State.BLOCK
	_block_time = 0.0
	_chain_left = 0.0
	animation_player.play(&"Block")
	player.animation = &"Block"

## Удар по героєві в блоці (D264): &"parry" — у перші PARRY_WINDOW с, &"block" — спереду, &"" — не захищено
## (не в блоці, удар ззаду, не ворог).
func guard_against(source: Node) -> StringName:
	if state != State.BLOCK or not source is DefaultEnemy:
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
	_chain_left = 0.0
	animation_player.play(&"Hurt")
	player.animation = &"Hurt"
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
