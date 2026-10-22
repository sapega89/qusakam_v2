extends CombatBody2D
class_name DefaultEnemy
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")
# signal hp_changed вже визначений в CombatBody2D

# === PRELOADED SCENES ===
const COIN_SCENE = preload("res://SampleProject/Scenes/Gameplay/Objects/Coin.tscn")
const DEATH_PARTICLES_SCENE = preload("res://SampleProject/Scenes/FX/DeathParticles.tscn")

## Скільки труп лежить після анімації смерті, перш ніж зблимнути й зникнути.
const DEATH_HOLD_TIME := 1.0
## Відтінок спрайта, поки ворог горить / оглушений (D207) — стан видно без тексту.
const BURN_TINT := Color(1.0, 0.62, 0.42)
const STUN_TINT := Color(0.7, 0.85, 1.0)

## Підпал (D207): burn_dps щосекунди, доки не мине burn_left. Новий підпал оновлює, не сумує.
var burn_dps := 0
var burn_left := 0.0
var _burn_tick := 0.0

# === RESOURCE-BASED CONFIGURATION ===
## EnemyStats resource для конфігурації ворога
## Якщо встановлено, параметри з resource перезапишуть дефолтні значення
@export var enemy_stats: EnemyStats

# === КОМПОНЕНТИ ===
var enemy_logic: EnemyLogic = null
var enemy_view: EnemyView = null
var health_bar: HealthBar = null  # Unified HealthBar (ЭТАП 2.2 ✅)

# === ПОСИЛАННЯ НА ВУЗЛИ ===
@onready var hitbox: Area2D = $hitbox
@onready var attack_area: Area2D = $AttackArea
# Вузли default_enemy.tscn — є завжди.
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox_collision: CollisionShape2D = $hitbox/CollisionShape2D
@onready var hitbox_damage: DamageApplier = $hitbox/DamageApplier
@onready var detection_area: Area2D = $dettection
@onready var detection_collision: CollisionShape2D = $dettection/CollisionShape2D

# === БАЗОВІ ПАРАМЕТРИ (для зворотної сумісності) ===
var speed = 70
var base_damage = 10.0
var damage = 10.0
var last_attack_time = 0.0
var attack_cooldown = 1.5
## D198: замах і тривалість удару (EnemyStats перезаписує).
var attack_windup := 0.4
var attack_active_time := 0.2
## D208: ривок під час удару (px) і броня від оглушення під час замаху.
var lunge := 0.0
var super_armor := false
var front_damage := 1.0
## Souls-lite (D264, D265): стійкість, збій героя від удару, комбо.
var poise_max := 3
var poise := 3
var stagger_time := 0.25
var combo_hits := 1
var combo_chance := 0.5
## Стійкість повертається повністю, якщо стільки секунд ворога ніхто не бив.
const POISE_RESET_TIME := 2.0
## Збій від вичерпаної стійкості й від парирування героя, с; відкидання при збої, px.
const POISE_BREAK_STAGGER := 0.6
const PARRY_STAGGER := 1.0
const STAGGER_PUSH := 30.0
var _poise_reset_left := 0.0

# === ПОКРАЩЕНИЙ AI (deprecated - використовуйте EnemyLogic) ===
enum AIState {
	IDLE,           # Очікування
	CHASE,          # Переслідування
	ATTACK,         # Атака
}

var current_state = AIState.IDLE
var state_timer = 0.0

# === ТАКТИЧНІ ПАРАМЕТРИ (deprecated - використовуйте EnemyLogic) ===
var detection_range = 300.0
var attack_range = 100.0
var chase_range = 400.0
var lost_player_timer = 0.0
var max_lost_time = 3.0

var player_in_area
var player

func _ready():
	# Викликаємо батьківський _ready() для ініціалізації CombatBody2D
	super._ready()

	# НОВОЕ: Применяем статистику из EnemyStats resource, если он установлен
	if enemy_stats:
		_apply_stats(enemy_stats)

	# Додаємо до групи ворогів
	add_to_group(GameGroups.ENEMIES)
	# Бестіарій (D290): ворог з'явився — його зустріли; загинув — ще одне вбивство.
	JournalRecords.meet_enemy(enemy_stats.enemy_type)
	entity_died.connect(func() -> void: JournalRecords.kill_enemy(enemy_stats.enemy_type))

	# D197: тіла гравця й ворога проходять одне крізь одне — ворог не стає гравцеві на голову (B58).
	# Виняток на пару тіл: зони, хітбокси й геометрія світу працюють як раніше.
	add_collision_exception_with(GameGroups.get_player())

	# Налаштовуємо невразливість для ворога (відключаємо)
	is_invulnerable = false
	invulnerability_duration = 0.0

	# Хітбокс удару (B59/D198): смуга довжиною attack_range перед ворогом, висота — зі сцени.
	# Форма local_to_scene: у кожного ворога своя довжина.
	hitbox_collision.shape.size.x = attack_range
	hitbox.monitoring = false
	hitbox.monitorable = false

	# Ініціалізуємо компоненти
	_initialize_components()

	# Початковий стан (fallback для зворотної сумісності)
	if not enemy_logic:
		change_state(AIState.IDLE)

## Применяет статистику из EnemyStats resource
func _apply_stats(stats: EnemyStats) -> void:
	if not stats:
		return

	# Движение
	speed = stats.speed

	# Боевые параметры
	base_damage = stats.base_damage
	damage = stats.base_damage
	attack_cooldown = stats.attack_cooldown
	attack_windup = stats.attack_windup
	attack_active_time = stats.attack_active_time
	lunge = stats.lunge
	super_armor = stats.super_armor
	front_damage = stats.front_damage
	poise_max = stats.poise
	poise = poise_max
	stagger_time = stats.stagger_time
	combo_hits = stats.combo_hits
	combo_chance = stats.combo_chance

	# Дальность обнаружения и атаки
	detection_range = stats.detection_range
	attack_range = stats.attack_range
	chase_range = stats.chase_range

	# Здоровье
	Max_Health = stats.max_health
	current_health = Max_Health

	DebugLogger.info("DefaultEnemy: Applied stats from EnemyStats resource (type: %s)" % stats.enemy_type, "Enemy")

func _initialize_components():
	"""Ініціалізує EnemyLogic та EnemyView"""
	# Створюємо EnemyLogic
	enemy_logic = _make_logic()
	enemy_logic.name = "EnemyLogic"
	add_child(enemy_logic)
	enemy_logic.initialize(self)

	# Підключаємо сигнали EnemyLogic
	enemy_logic.state_changed.connect(_on_logic_state_changed)
	enemy_logic.direction_changed.connect(_on_logic_direction_changed)
	enemy_logic.attack_started.connect(_on_logic_attack_started)
	enemy_logic.attack_ended.connect(_on_logic_attack_ended)
	enemy_logic.attack_telegraphed.connect(_on_logic_attack_telegraphed)

	enemy_view = EnemyView.new()
	enemy_view.name = "EnemyView"
	add_child(enemy_view)
	enemy_view.initialize(self)

	# Створюємо HP бар для ворога
	_initialize_health_bar()

	DebugLogger.info("DefaultEnemy: Components initialized", "Enemy")

	# Перевіряємо, чи гравець вже знаходиться в зоні виявлення
	call_deferred("_check_existing_player_in_detection_area")

## Логіка ворога; бос підставляє свою (BossLogic, D301/D302).
func _make_logic() -> EnemyLogic:
	return EnemyLogic.new()

func _initialize_health_bar():
	"""Создает и настраивает HP бар для врага (только если это не босс)"""
	# Проверяем, является ли враг боссом - у босса будет отдельный HP-бар на весь экран
	if is_in_group(GameGroups.BOSS) or is_in_group(GameGroups.MINIBOSS):
		DebugLogger.info("DefaultEnemy: Враг является боссом, пропускаем создание HP-бара над головой", "Enemy")
		return

	# Загружаем сцену HP бара
	var health_bar_scene = load("res://SampleProject/Scenes/UI/enemy_health_bar.tscn")
	if not health_bar_scene:
		push_error("DefaultEnemy: Не удалось загрузить сцену enemy_health_bar.tscn")
		return

	# Создаем экземпляр HP бара
	health_bar = health_bar_scene.instantiate() as HealthBar
	if not health_bar:
		push_error("DefaultEnemy: Не удалось создать HealthBar")
		return

	# Ensure it's configured as ENEMY type
	health_bar.bar_type = HealthBar.HealthBarType.ENEMY

	# Ищем UI CanvasLayer в сцене
	var scene = get_tree().current_scene
	if not scene:
		call_deferred("_initialize_health_bar")
		return

	# HP-бари ворогів живуть у Game.tscn → UICanvas.
	var canvas_layer: CanvasLayer = scene.get_node(^"UICanvas")

	# Добавляем HP бар в CanvasLayer
	canvas_layer.add_child(health_bar)

	# Настраиваем HP бар для этого врага
	# Схована до першого ушкодження (HealthBar._configure_enemy_bar)
	health_bar.setup_for_entity(self, "Enemy")

func _on_logic_state_changed(new_state: EnemyLogic.AIState):
	"""Обробляє зміну стану з EnemyLogic"""
	enemy_view.update_state(new_state)
	# Синхронізуємо для зворотної сумісності
	current_state = new_state

func _on_logic_direction_changed(direction: int):
	"""Обробляє зміну напрямку з EnemyLogic"""
	enemy_view.update_direction(direction)

func _on_logic_attack_started():
	"""Обробляє початок атаки з EnemyLogic"""
	enemy_view.on_attack_started(enemy_logic.swing_windup)

## Підказка удару (4b): відблиск на зброї, а для ривка (fast) — червона лінія на lunge + attack_range.
func _on_logic_attack_telegraphed() -> void:
	enemy_view.show_tell(PlayerCombat.PARRY_WINDOW, lunge, attack_range)

func _on_logic_attack_ended():
	"""Обробляє завершення атаки з EnemyLogic"""
	enemy_view.on_attack_ended()

func get_enemy_params() -> Dictionary:
	"""Повертає параметри ворога для EnemyLogic"""
	return {
		"speed": speed,
		"detection_range": detection_range,
		"attack_range": attack_range,
		"chase_range": chase_range,
		"base_damage": base_damage,
		# дозволяє пробігати ворогів повз (без arena-lock): ворог має leash і повертається додому
		"leash_range": max(chase_range * 1.5, 450.0),
		"return_home_speed": max(speed * 0.8, 40.0)
	}

func _physics_process(delta: float) -> void:
	# Не обрабатываем AI врага во время паузы
	if get_tree().paused:
		return

	if is_dead:
		detection_collision.disabled = true
		return

	_tick_burn(delta)
	if _poise_reset_left > 0.0:
		_poise_reset_left -= delta
		if _poise_reset_left <= 0.0:
			poise = poise_max
	if enemy_view.staggered and enemy_logic.stun_left <= 0.0:
		enemy_view.end_stagger()
	sprite.modulate = STUN_TINT if enemy_logic.stun_left > 0.0 else (BURN_TINT if burn_left > 0.0 else Color.WHITE)

	# AI — EnemyLogic (створюється в _initialize_components() завжди); тут лише X-рух.
	velocity.x = enemy_logic.process_physics(delta).x
	current_state = enemy_logic.current_state
	state_timer = enemy_logic.state_timer
	lost_player_timer = enemy_logic.lost_player_timer

	# Применяем гравитацию из project settings
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	else:
		# На полу - сбрасываем вертикальную скорость
		velocity.y = 0

	# Применяем движение с физикой
	move_and_slide()

func change_state(new_state: AIState):
	# Не змінюємо стан під час паузи або якщо ворог мертвий
	if get_tree().paused:
		return

	if is_dead:
		return

	if current_state == new_state:
		return

	var old_state = current_state
	current_state = new_state
	state_timer = 0.0

	DebugLogger.verbose("Enemy AI: State changed from %s to %s" % [AIState.keys()[old_state], AIState.keys()[new_state]], "Enemy")

	# Дії при зміні стану
	match new_state:
		AIState.IDLE:
			velocity.x = 0  # Только горизонтальное движение (сохраняем гравитацию)
			anim_player.play("idle")
		AIState.CHASE:
			anim_player.play("walk")
			speed = 70  # Звичайна швидкість
		AIState.ATTACK:
			anim_player.play("attack")

func get_health_percentage() -> float:
	return float(current_health) / float(Max_Health)

## Реалізація ICharacter.get_speed()
func get_speed() -> float:
	return float(speed)

## Реалізація ICharacter.get_damage()
func get_damage() -> float:
	return float(damage)

## Реалізація ICharacter.get_attack_area()
## Для ворога область атаки - це hitbox
func get_attack_area() -> Area2D:
	return hitbox

## Реалізація IDamageDealer.deal_damage()
func deal_damage(target: Node, damage_amount: int) -> void:
	if IDamageable.is_implemented_by(target):
		IDamageable.safe_take_damage(target, damage_amount, self)
	else:
		push_error("Target does not implement IDamageable")

## Реалізація IDamageDealer.get_base_damage()
func get_base_damage() -> int:
	return int(base_damage)

## Реалізація IDamageDealer.get_current_damage()
func get_current_damage() -> int:
	return int(damage)

# === ПЕРЕВИЗНАЧЕНІ ФУНКЦІЇ ===

func _on_dettection_body_entered(body):
	# Не обробляємо детекцію під час паузи
	if get_tree().paused:
		return

	if body.is_in_group(GameGroups.PLAYER):
		player_in_area = true
		player = body
		DebugLogger.verbose("Enemy detected player!", "Enemy")

		enemy_logic.on_player_detected(body)

func _on_dettection_body_exited(body):
	# Не обробляємо детекцію під час паузи
	if get_tree().paused:
		return

	if body.is_in_group(GameGroups.PLAYER):
		enemy_logic.on_player_lost()

func _check_existing_player_in_detection_area():
	"""Перевіряє, чи гравець вже знаходиться в зоні виявлення при спавні ворога"""
	if not is_instance_valid(self):
		return

	# Перевіряємо всі тіла в зоні виявлення
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group(GameGroups.PLAYER):
			# Гравець вже в зоні, викликаємо обробник
			_on_dettection_body_entered(body)
			break

func _award_xp_to_player() -> void:
	"""Awards XP to player — the reward is data (EnemyStats.xp_reward, D297)"""
	ServiceLocator.get_xp_manager().add_xp(enemy_stats.xp_reward)
	DebugLogger.info("Enemy died, awarded %d XP to player" % enemy_stats.xp_reward, "Enemy")

func _spawn_coin_drops() -> void:
	"""Spawns coins on enemy death"""
	var coin_count = _calculate_coin_drop()

	for i in coin_count:
		if not COIN_SCENE:
			DebugLogger.warning("Enemy: Coin scene not loaded", "Enemy")
			return

		var coin = COIN_SCENE.instantiate()
		if not coin:
			continue

		# Монета — сусід ворога в кімнаті. Додаємо відкладено: смерть приходить із body_entered хітбокса
		# героя, а Area2D монети посеред фізичного запиту не додати (помилка «flushing queries»).
		var parent: Node2D = get_parent()
		var angle = (i / float(coin_count)) * TAU + randf() * 0.5
		var distance = randf_range(15, 35)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		coin.position = parent.to_local(global_position + offset)
		parent.add_child.call_deferred(coin)

func _calculate_coin_drop() -> int:
	"""Calculates how many coins to drop based on enemy type"""
	# Different enemies drop different amounts
	match enemy_stats.enemy_type:
		"melee":
			return randi_range(2, 4)  # 2-4 coins
		"tank":
			return randi_range(4, 6)  # 4-6 coins (harder, more reward)
		"fast":
			return randi_range(1, 3)  # 1-3 coins
		"archer":
			return randi_range(1, 3)  # D386: як fast
	push_error("DefaultEnemy: unknown enemy_type '%s'" % enemy_stats.enemy_type)
	return 0

func _spawn_death_particles() -> void:
	"""Spawns explosive death particle effect"""
	if not DEATH_PARTICLES_SCENE:
		return

	var particles = DEATH_PARTICLES_SCENE.instantiate()
	if not particles:
		return

	# Add to scene root to persist after enemy is removed
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	DebugLogger.verbose("Enemy: Spawned death particles at %s" % global_position, "Enemy")

func die():
	DebugLogger.info("Enemy is dying!", "Enemy")

	# Award XP to player when enemy dies
	_award_xp_to_player()

	# Spawn coin drops
	_spawn_coin_drops()

	# Викликаємо батьківську функцію die()
	super.die()

	# Останавливаем движение
	velocity = Vector2.ZERO
	# НЕ змінюємо стан на IDLE, щоб не запускати анімацію idle
	# change_state(AIState.IDLE)

	# Зупиняємо всі анімації перед програванням смерті; помер у збої — спершу sheet назад (кадри смерті там)
	if enemy_view.staggered:
		enemy_view.end_stagger()
	anim_player.stop()
	# Мертвий одразу перестає бути тілом: не блокує героя й не бʼє (F8)
	_set_collisions_disabled(true)

	# === ENHANCED DEATH SEQUENCE ===
	# Red flash effect (3 times). Раніше шукався AnimatedSprite2D, якого в сцені нема, — спалаху не було.
	for i in 3:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout

	# Spawn explosive death particles
	_spawn_death_particles()

	# Видаляємо HP бар при смерті
	if health_bar and is_instance_valid(health_bar):
		health_bar.queue_free()
		health_bar = null

	# Анімацію смерті видно до кінця (F8: раніше ворог ховався одразу після її старту)
	anim_player.play("death")
	await anim_player.animation_finished
	await get_tree().create_timer(DEATH_HOLD_TIME).timeout

	# Проверяем, не был ли враг воскрешен во время ожидания
	if not is_dead:
		DebugLogger.info("Enemy was revived during death animation, stopping death process", "Enemy")
		return

	# Создаем эффект мигания перед исчезновением
	if sprite:
		var tween = create_tween()
		tween.set_loops(5)  # 5 миганий
		tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

		# Ждем окончания анимации мигания
		await tween.finished

	# Проверяем еще раз, не был ли враг воскрешен во время мигания
	if not is_dead:
		DebugLogger.info("Enemy was revived during death animation, stopping death process", "Enemy")
		return

	# Робимо ворога невидимим і неактивним замість видалення
	DebugLogger.info("Enemy disappearing after death animation...", "Enemy")
	visible = false
	set_process(false)
	set_physics_process(false)
	anim_player.stop()
	_set_collisions_disabled(true)

func revive(health_amount: int = -1):
	# Перевіряємо, чи ворог вже живий
	if not is_dead:
		return  # Ворог вже живий, не потрібно revival

	# Викликаємо батьківську функцію revive()
	super.revive(health_amount)

	# Прерываем все активные твины (анимации смерти)
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()

	# Повертаємо ворога до життя
	visible = true
	set_process(true)
	set_physics_process(true)

	# Відновлюємо HP бар, якщо він був видалений
	if not health_bar or not is_instance_valid(health_bar):
		_initialize_health_bar()

	# Скидаємо візуальний стан
	sprite.modulate = Color.WHITE
	_set_collisions_disabled(false)

	# Скидаємо стан AI та урон (тільки якщо не на паузі)
	if not get_tree().paused:
		change_state(AIState.IDLE)
		damage = base_damage  # Скидаємо урон до базового
		lost_player_timer = 0.0

		# Запускаємо анімацію ходьби
		anim_player.play("walk")

	DebugLogger.info("Enemy has been revived and damage reset to base: %d" % damage, "Enemy")


# === ІНШІ ФУНКЦІЇ ===

func weapon():
	pass

## Удар (D198): хітбокс перед ворогом у бік [param direction] (±1) живий, доки не end_attack().
## Ушкодження — через DamageApplier хітбокса, як у гравця.
## Удар спереду по панцирю (tank) — front_damage від шкоди. Без джерела (підпал) — повна.
func take_damage(amount: int, source: Node = null) -> void:
	var facing := enemy_logic.last_direction
	if source is Node2D and front_damage < 1.0 and facing != 0 and signf(source.global_position.x - global_position.x) == facing:
		amount = maxi(1, roundi(amount * front_damage))
	super.take_damage(amount, source)

func start_attack(direction: int) -> void:
	hitbox.position.x = direction * attack_range / 2.0
	hitbox_damage.update_damage()
	hitbox_damage.enable_damage()
	hitbox.monitoring = true
	enemy_view.on_strike()

func end_attack() -> void:
	hitbox.set_deferred(&"monitoring", false)  # збій (D264) приходить із body_entered хітбокса героя
	hitbox_damage.disable_damage()

func apply_burn(dps: int, duration: float) -> void:
	if burn_left <= 0.0:
		_burn_tick = 1.0  # перший тик — через секунду після удару
	burn_dps = dps
	burn_left = duration

func stun(duration: float) -> void:
	enemy_logic.stun(duration)

## Тики підпалу. Без джерела: це не новий удар героя, тож ефекту влучання немає, лише спалах ушкодження.
func _tick_burn(delta: float) -> void:
	if burn_left <= 0.0:
		return
	burn_left -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick += 1.0
		take_damage(burn_dps)

## Удар героя відбирає [param amount] стійкості (D265); вичерпана — ворог збитий: замах зірвано, стоїть POISE_BREAK_STAGGER.
func take_poise(amount: int, from_x: float) -> void:
	if is_dead:
		return
	_poise_reset_left = POISE_RESET_TIME
	poise -= amount
	if poise <= 0:
		poise = poise_max
		stagger(POISE_BREAK_STAGGER, from_x)

## Збій (D264): удар не відбудеться, ворог стоїть і відлітає трохи від героя. Броня tank тут не рятує.
func stagger(duration: float, from_x: float) -> void:
	enemy_logic.stagger(duration)
	if enemy_view.has_stagger_pose():
		enemy_view.play_stagger(enemy_logic.stun_left)
	enemy_logic.start_knockback(signf(global_position.x - from_x) * STAGGER_PUSH)
	EventBus.enemy_staggered.emit(self, duration)

## Герой парирував цей удар (D264).
func parried(by: Node2D) -> void:
	stagger(PARRY_STAGGER, by.global_position.x)

## Скільки збиває героя удар, що зараз іде: фінішер серії — довше (D264: «вороги інколи заморожують героя»).
func hit_stagger_time() -> float:
	return maxf(stagger_time, EnemyLogic.FINISHER_STAGGER) if enemy_logic.finisher else stagger_time

## Поштовх легкого удару (4b): [param push] px, замах не зриває.
func nudge(push: float) -> void:
	enemy_logic.start_knockback(push, false)

## Відкидання від удару (булава, D203): [param push] px, знак — напрямок.
func knockback(push: float) -> void:
	enemy_logic.start_knockback(push)

## Вмикає / вимикає всі колізії ворога: тіло, hitbox, зона виявлення.
func _set_collisions_disabled(disabled: bool) -> void:
	for shape in [body_collision, hitbox_collision, detection_collision]:
		shape.set_deferred(&"disabled", disabled)

func set_dead_state(dead: bool):
	"""Встановлює стан смерті без виклику die()/revive() для уникнення анімацій при завантаженні"""
	if dead:
		# Встановлюємо стан смерті без анімації
		current_health = 0
		is_dead = true
		# Відключаємо колізії
		_set_collisions_disabled(true)
		# Зупиняємо рух
		velocity = Vector2.ZERO
		change_state(AIState.IDLE)
	else:
		# Встановлюємо стан життя без анімації
		current_health = Max_Health
		is_dead = false
		# Включаємо колізії
		_set_collisions_disabled(false)
		# Скидаємо візуальний стан
		modulate = Color.WHITE
		scale = Vector2.ONE
		change_state(AIState.IDLE)

func _exit_tree() -> void:
	"""Відключаємося від сигналів при видаленні"""
	# Відключаємося від EnemyLogic сигналів
	if enemy_logic and is_instance_valid(enemy_logic):
		if enemy_logic.state_changed.is_connected(_on_logic_state_changed):
			enemy_logic.state_changed.disconnect(_on_logic_state_changed)
		if enemy_logic.direction_changed.is_connected(_on_logic_direction_changed):
			enemy_logic.direction_changed.disconnect(_on_logic_direction_changed)
		if enemy_logic.attack_started.is_connected(_on_logic_attack_started):
			enemy_logic.attack_started.disconnect(_on_logic_attack_started)
		if enemy_logic.attack_ended.is_connected(_on_logic_attack_ended):
			enemy_logic.attack_ended.disconnect(_on_logic_attack_ended)
	# HP-бар живе в UICanvas гри, а не в кімнаті — без цього він лишався на екрані,
	# коли кімнату вивантажували разом із живим ворогом.
	if health_bar and is_instance_valid(health_bar):
		health_bar.queue_free()
		health_bar = null
