extends CombatBody2D
class_name DefaultEnemy
# signal hp_changed вже визначений в CombatBody2D

# === PRELOADED SCENES ===
const COIN_SCENE = preload("res://SampleProject/Scenes/Gameplay/Objects/Coin.tscn")
const HIT_IMPACT_SCENE = preload("res://SampleProject/Scenes/FX/HitImpact.tscn")
const DEATH_PARTICLES_SCENE = preload("res://SampleProject/Scenes/FX/DeathParticles.tscn")

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

# === БАЗОВІ ПАРАМЕТРИ (для зворотної сумісності) ===
var speed = 70
var base_damage = 10.0
var damage = 10.0
var last_attack_time = 0.0
var attack_cooldown = 1.5

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

	# Налаштовуємо невразливість для ворога (відключаємо)
	is_invulnerable = false
	invulnerability_duration = 0.0

	# Скрываем hit area по умолчанию
	if hitbox:
		hitbox.visible = false
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
	enemy_logic = EnemyLogic.new()
	enemy_logic.name = "EnemyLogic"
	add_child(enemy_logic)
	enemy_logic.initialize(self)
	
	# Підключаємо сигнали EnemyLogic
	enemy_logic.state_changed.connect(_on_logic_state_changed)
	enemy_logic.direction_changed.connect(_on_logic_direction_changed)
	enemy_logic.attack_started.connect(_on_logic_attack_started)
	enemy_logic.attack_ended.connect(_on_logic_attack_ended)
	enemy_logic.player_detected.connect(_on_logic_player_detected)
	enemy_logic.player_lost.connect(_on_logic_player_lost)
	
	# Створюємо EnemyView (опционально, так как анимации управляются через AnimationPlayer)
	enemy_view = EnemyView.new()
	enemy_view.name = "EnemyView"
	add_child(enemy_view)
	# Передаем null, так как используем Sprite2D + AnimationPlayer вместо AnimatedSprite2D
	enemy_view.initialize(self, null)
	
	# Створюємо HP бар для ворога
	_initialize_health_bar()

	DebugLogger.info("DefaultEnemy: Components initialized", "Enemy")
	
	# Перевіряємо, чи гравець вже знаходиться в зоні виявлення
	call_deferred("_check_existing_player_in_detection_area")

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
	
	# Ищем UI CanvasLayer (может быть "UI" или "UICanvas")
	var canvas_layer = scene.get_node_or_null("UICanvas")
	if not canvas_layer:
		canvas_layer = scene.get_node_or_null("UI")
	if not canvas_layer:
		# Создаем CanvasLayer если его нет
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "UICanvas"
		scene.add_child(canvas_layer)
	
	# Добавляем HP бар в CanvasLayer
	canvas_layer.add_child(health_bar)
	
	# Настраиваем HP бар для этого врага
	health_bar.setup_for_entity(self, "Enemy")
	
	# HP бар изначально скрыт (появится при получении урона)
	health_bar.visible = true  # Для тестирования - видим сразу
	health_bar.hp_bar_visible = true

func _on_logic_state_changed(new_state: EnemyLogic.AIState):
	"""Обробляє зміну стану з EnemyLogic"""
	if enemy_view:
		enemy_view.update_state(new_state)
	# Синхронізуємо для зворотної сумісності
	current_state = new_state

func _on_logic_direction_changed(direction: int):
	"""Обробляє зміну напрямку з EnemyLogic"""
	if enemy_view:
		enemy_view.update_direction(direction)

func _on_logic_attack_started():
	"""Обробляє початок атаки з EnemyLogic"""
	if enemy_view:
		enemy_view.on_attack_started()

func _on_logic_attack_ended():
	"""Обробляє завершення атаки з EnemyLogic"""
	if enemy_view:
		enemy_view.on_attack_ended()

func _on_logic_player_detected():
	"""Обробляє виявлення гравця з EnemyLogic"""
	if enemy_view:
		enemy_view.on_player_detected()

func _on_logic_player_lost():
	"""Обробляє втрату гравця з EnemyLogic"""
	if enemy_view:
		enemy_view.on_player_lost()

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
		var detection = get_node_or_null("dettection")
		if detection:
			var collision = detection.get_node_or_null("CollisionShape2D")
			if collision:
				collision.disabled = true
		return
	
	# Використовуємо EnemyLogic для обробки фізики
	if enemy_logic:
		# Обробляємо фізику через EnemyLogic (получаем только X компонент)
		var logic_velocity = enemy_logic.process_physics(delta)
		velocity.x = logic_velocity.x  # Только горизонтальное движение
		# velocity.y сохраняется для гравитации (устанавливается ниже)

		# Синхронізуємо стан для зворотної сумісності
		current_state = enemy_logic.current_state
		state_timer = enemy_logic.state_timer
		lost_player_timer = enemy_logic.lost_player_timer
	else:
		# Fallback на стару логіку, якщо EnemyLogic не ініціалізовано
		# Оновлюємо таймери
		state_timer += delta
		lost_player_timer += delta
		
		# Основний AI цикл
		match current_state:
			AIState.IDLE:
				handle_idle_state(delta)
			AIState.CHASE:
				handle_chase_state(delta)
			AIState.ATTACK:
				handle_attack_state(delta)
	
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
	var sprite = get_node_or_null("AnimatedSprite2D")
	var anim_player = get_node_or_null("AnimationPlayer")
	match new_state:
		AIState.IDLE:
			velocity.x = 0  # Только горизонтальное движение (сохраняем гравитацию)
			if anim_player and anim_player.has_animation("idle"):
				anim_player.play("idle")
			elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
		AIState.CHASE:
			if anim_player and anim_player.has_animation("walk"):
				anim_player.play("walk")
			elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
			speed = 70  # Звичайна швидкість
		AIState.ATTACK:
			if anim_player and anim_player.has_animation("attack"):
				anim_player.play("attack")
			elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
				sprite.play("attack")

func handle_idle_state(_delta: float):
	# Перевіряємо, чи є гравець поблизу
	if player and global_position.distance_to(player.global_position) <= detection_range:
		change_state(AIState.CHASE)
		return

func handle_chase_state(delta: float):
	if not player:
		change_state(AIState.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Якщо гравець занадто далеко, втрачаємо його
	if distance_to_player > chase_range:
		lost_player_timer += delta
		if lost_player_timer > max_lost_time:
			change_state(AIState.IDLE)
			return
	else:
		lost_player_timer = 0.0
	
	# Перевіряємо, чи можемо атакувати
	if distance_to_player <= attack_range:
		change_state(AIState.ATTACK)
		return
	
	# Переслідуємо гравця (только по горизонтали, сохраняя гравитацию)
	var direction_x = sign(player.global_position.x - global_position.x)
	velocity.x = direction_x * speed
	# velocity.y сохраняется из гравитации (применяется в _physics_process)

func handle_attack_state(_delta: float):
	if not player:
		change_state(AIState.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Якщо гравець занадто далеко, переслідуємо
	if distance_to_player > attack_range * 1.2:
		change_state(AIState.CHASE)
		return
	
	# Атакуємо
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= attack_cooldown:
		perform_attack()
		last_attack_time = current_time
		
		# Після атаки переходимо до переслідування
		change_state(AIState.CHASE)

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

func perform_attack():
	# Не атакуємо під час паузи
	if get_tree().paused:
		return

	DebugLogger.verbose("Enemy performing attack! Damage: %d" % damage, "Enemy")
	
	var sprite = get_node_or_null("AnimatedSprite2D")
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation("attack"):
		anim_player.play("attack")
	elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	start_attack()
	
	# Альтернативный способ нанесения урона - напрямую
	if player and global_position.distance_to(player.global_position) <= attack_range * 1.2:
		if player.has_method("take_damage"):
			player.take_damage(damage)
			DebugLogger.verbose("Enemy hit player for %d damage! Player health: %d" % [damage, player.current_health], "Enemy")
	
	await get_tree().create_timer(0.3).timeout
	end_attack()

# === ПЕРЕВИЗНАЧЕНІ ФУНКЦІЇ ===

func _on_dettection_body_entered(body):
	# Не обробляємо детекцію під час паузи
	if get_tree().paused:
		return
		
	if body.is_in_group(GameGroups.PLAYER):
		player_in_area = true
		player = body
		DebugLogger.verbose("Enemy detected player!", "Enemy")
		
		# Повідомляємо EnemyLogic про виявлення гравця
		if enemy_logic:
			enemy_logic.on_player_detected(body)
		else:
			# Fallback на стару логіку
			# Переходимо до переслідування
			if current_state == AIState.IDLE:
				change_state(AIState.CHASE)

func _on_dettection_body_exited(body):
	# Не обробляємо детекцію під час паузи
	if get_tree().paused:
		return
		
	if body.is_in_group(GameGroups.PLAYER):
		# Використовуємо EnemyLogic для обробки втрати гравця
		if enemy_logic:
			enemy_logic.on_player_lost()
		else:
			# Fallback на стару логіку
			player_in_area = false
			DebugLogger.verbose("Player left enemy detection area", "Enemy")
			lost_player_timer = 0.0

func _check_existing_player_in_detection_area():
	"""Перевіряє, чи гравець вже знаходиться в зоні виявлення при спавні ворога"""
	if not is_instance_valid(self):
		return
	
	var detection_area = get_node_or_null("dettection")
	if not detection_area:
		return
	
	# Перевіряємо всі тіла в зоні виявлення
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group(GameGroups.PLAYER):
			# Гравець вже в зоні, викликаємо обробник
			_on_dettection_body_entered(body)
			break

func take_damage(damage_amount: int, source: Node = null) -> void:
	# Викликаємо батьківську функцію
	super.take_damage(damage_amount, source)

	# Apply hit VFX
	_apply_hit_flash()
	_spawn_hit_impact()

	# Не змінюємо стан під час паузи
	if get_tree().paused:
		return

func _apply_hit_flash() -> void:
	"""Applies white flash effect when enemy is hit"""
	# Try multiple sprite node names (different enemy setups)
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return

	# Store original modulate
	var original_modulate = sprite.modulate

	# Flash white
	sprite.modulate = Color.WHITE

	# Restore original color after 1 frame (0.05s)
	await get_tree().create_timer(0.05).timeout

	# Check if sprite still exists before restoring
	if is_instance_valid(sprite):
		sprite.modulate = original_modulate

func _spawn_hit_impact() -> void:
	"""Spawns particle burst at hit position"""
	if not HIT_IMPACT_SCENE:
		return

	var impact = HIT_IMPACT_SCENE.instantiate()
	if not impact:
		return

	# Add to scene root to persist after enemy may be removed
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(impact)
		impact.global_position = global_position
	else:
		# Fallback to parent
		var parent = get_parent()
		if parent:
			parent.add_child(impact)
			impact.global_position = global_position

func _award_xp_to_player() -> void:
	"""Awards XP to player based on enemy type"""
	var xp_manager = ServiceLocator.get_xp_manager()
	if not xp_manager:
		DebugLogger.warning("Enemy: XPManager not found, cannot award XP", "Enemy")
		return

	var xp_amount = _calculate_xp_reward()
	xp_manager.add_xp(xp_amount)
	DebugLogger.info("Enemy died, awarded %d XP to player" % xp_amount, "Enemy")

func _calculate_xp_reward() -> int:
	"""Calculates XP reward based on enemy type"""
	# If using EnemyStats resource, calculate based on enemy type
	if enemy_stats:
		match enemy_stats.enemy_type:
			"melee":
				return 25  # Standard melee enemy
			"tank":
				return 40  # Tanky enemy - more XP for tougher fight
			"fast":
				return 20  # Fast enemy - slightly less XP
			_:
				return 25  # Default

	# Fallback: Calculate based on max health
	# 1 XP per 4 HP (100 HP = 25 XP, 200 HP = 50 XP, etc.)
	return max(int(Max_Health / 4), 10)  # Minimum 10 XP

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

		# Add coin to parent (scene root)
		var parent = get_parent()
		if parent:
			parent.add_child(coin)

			# Randomize spawn position slightly around enemy
			var angle = (i / float(coin_count)) * TAU + randf() * 0.5
			var distance = randf_range(15, 35)
			var offset = Vector2(cos(angle), sin(angle)) * distance

			coin.global_position = global_position + offset

			DebugLogger.verbose("Enemy: Spawned coin %d/%d at %s" % [i+1, coin_count, coin.global_position], "Enemy")

func _calculate_coin_drop() -> int:
	"""Calculates how many coins to drop based on enemy type"""
	# Different enemies drop different amounts
	if enemy_stats:
		match enemy_stats.enemy_type:
			"melee":
				return randi_range(2, 4)  # 2-4 coins
			"tank":
				return randi_range(4, 6)  # 4-6 coins (harder, more reward)
			"fast":
				return randi_range(1, 3)  # 1-3 coins
			_:
				return 2

	# Fallback: 2 coins
	return 2

func _spawn_death_particles() -> void:
	"""Spawns explosive death particle effect"""
	if not DEATH_PARTICLES_SCENE:
		return

	var particles = DEATH_PARTICLES_SCENE.instantiate()
	if not particles:
		return

	# Add to scene root to persist after enemy is removed
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(particles)
		particles.global_position = global_position
	else:
		# Fallback to parent
		var parent = get_parent()
		if parent:
			parent.add_child(particles)
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

	# Зупиняємо всі анімації перед програванням смерті
	var sprite = get_node_or_null("AnimatedSprite2D")
	var anim_player = get_node_or_null("AnimationPlayer")
	if sprite:
		sprite.stop()
	if anim_player:
		anim_player.stop()

	# === ENHANCED DEATH SEQUENCE ===
	# Red flash effect (3 times)
	if sprite:
		for i in 3:
			sprite.modulate = Color.RED
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(sprite):
				sprite.modulate = Color.WHITE
			await get_tree().create_timer(0.1).timeout

	# Spawn explosive death particles
	_spawn_death_particles()
	
	# Проигрываем анимацию смерти
	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
	elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	
	# Отключаем коллизии (використовуємо call_deferred для безпеки)
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.call_deferred("set", "disabled", true)
	if hitbox:
		var hitbox_collision = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_collision:
			hitbox_collision.call_deferred("set", "disabled", true)
	var detection = get_node_or_null("dettection")
	if detection:
		var detection_collision = detection.get_node_or_null("CollisionShape2D")
		if detection_collision:
			detection_collision.call_deferred("set", "disabled", true)
	
	# Робимо ворога невидимим одразу після смерті
	visible = false
	DebugLogger.info("Enemy made invisible immediately after death", "Enemy")
	
	# Зберігаємо стан ворога одразу після смерті
	save_enemy_death_state()
	
	# Видаляємо HP бар при смерті
	if health_bar and is_instance_valid(health_bar):
		health_bar.queue_free()
		health_bar = null
	
	# Ждем 3 секунды, затем исчезаем с миганием
	await get_tree().create_timer(3.0).timeout
	
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
	# Зупиняємо анімацію
	if sprite:
		sprite.stop()
	# Відключаємо всі колізії
	if collision:
		collision.call_deferred("set", "disabled", true)
	if hitbox:
		var hitbox_collision = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_collision:
			hitbox_collision.call_deferred("set", "disabled", true)
	if detection:
		var detection_collision = detection.get_node_or_null("CollisionShape2D")
		if detection_collision:
			detection_collision.call_deferred("set", "disabled", true)

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
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color.WHITE  # Повертаємо повну прозорість
	
	# Включаємо колізії (використовуємо call_deferred для безпеки)
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.call_deferred("set", "disabled", false)
	if hitbox:
		var hitbox_collision = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_collision:
			hitbox_collision.call_deferred("set", "disabled", false)
	var detection = get_node_or_null("dettection")
	if detection:
		var detection_collision = detection.get_node_or_null("CollisionShape2D")
		if detection_collision:
			detection_collision.call_deferred("set", "disabled", false)
	
	# Скидаємо стан AI та урон (тільки якщо не на паузі)
	if not get_tree().paused:
		change_state(AIState.IDLE)
		damage = base_damage  # Скидаємо урон до базового
		lost_player_timer = 0.0
		
		# Запускаємо анімацію ходьби
		var anim_player = get_node_or_null("AnimationPlayer")
		if anim_player and anim_player.has_animation("walk"):
			anim_player.play("walk")
		elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")

	DebugLogger.info("Enemy has been revived and damage reset to base: %d" % damage, "Enemy")
	
	# Зберігаємо стан відновлення ворога
	save_enemy_revival_state()

# === ІНШІ ФУНКЦІЇ ===

func weapon():
	pass

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group(GameGroups.PLAYER) and not is_dead:
		# Наносим урон игроку при попадании в hit area
		if body.has_method("take_damage"):
			body.take_damage(damage)
			var health = body.current_health if "current_health" in body else 0
			DebugLogger.verbose("Enemy hit player for %d damage! Player health: %d" % [damage, health], "Enemy")

func start_attack():
	if hitbox:
		hitbox.visible = true          # Показуємо в редакторі (для дебага)
		hitbox.monitoring = true       # Починаємо ловити колізії
		hitbox.monitorable = true

func end_attack():
	if hitbox:
		hitbox.visible = false         # Ховаємо
		hitbox.monitoring = false      # Не ловимо колізії
		hitbox.monitorable = false

func attack():
	# Ця функція тепер замінена на perform_attack()
	perform_attack()

func set_dead_state(dead: bool):
	"""Встановлює стан смерті без виклику die()/revive() для уникнення анімацій при завантаженні"""
	if dead:
		# Встановлюємо стан смерті без анімації
		current_health = 0
		is_dead = true
		# Відключаємо колізії
		var collision = get_node_or_null("CollisionShape2D")
		if collision:
			collision.disabled = true
		if hitbox:
			var hitbox_collision = hitbox.get_node_or_null("CollisionShape2D")
			if hitbox_collision:
				hitbox_collision.disabled = true
		var detection = get_node_or_null("dettection")
		if detection:
			var detection_collision = detection.get_node_or_null("CollisionShape2D")
			if detection_collision:
				detection_collision.disabled = true
		# Зупиняємо рух
		velocity = Vector2.ZERO
		change_state(AIState.IDLE)
	else:
		# Встановлюємо стан життя без анімації
		current_health = Max_Health
		is_dead = false
		# Включаємо колізії
		var collision = get_node_or_null("CollisionShape2D")
		if collision:
			collision.disabled = false
		if hitbox:
			var hitbox_collision = hitbox.get_node_or_null("CollisionShape2D")
			if hitbox_collision:
				hitbox_collision.disabled = false
		var detection = get_node_or_null("dettection")
		if detection:
			var detection_collision = detection.get_node_or_null("CollisionShape2D")
			if detection_collision:
				detection_collision.disabled = false
		# Скидаємо візуальний стан
		modulate = Color.WHITE
		scale = Vector2.ONE
		change_state(AIState.IDLE)

func save_enemy_death_state():
	"""Зберігає стан смерті ворога в EnemyStateManager одразу після смерті"""
	if Engine.has_singleton("ServiceLocator"):
		var enemy_state_manager = null
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_enemy_state_manager"):
				enemy_state_manager = service_locator.get_enemy_state_manager()
		if enemy_state_manager:
			var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename() if get_tree().current_scene else "Unknown"
			var enemy_name = name
			DebugLogger.info("Enemy: Saving death state immediately - Scene: %s, Enemy: %s" % [scene_name, enemy_name], "Enemy")
			enemy_state_manager.save_enemy_state(scene_name, enemy_name, true)
			# Також зберігаємо в локальне сховище
			enemy_state_manager.save_enemy_states_to_storage()
		else:
			DebugLogger.warning("Enemy: EnemyStateManager not found, cannot save death state", "Enemy")
	else:
		DebugLogger.warning("Enemy: ServiceLocator not found, cannot save death state", "Enemy")

func save_enemy_revival_state():
	"""Зберігає стан відновлення ворога в EnemyStateManager одразу після відновлення"""
	# Перевіряємо, чи ворог дійсно був мертвим перед revival
	if not is_dead:
		return  # Ворог вже живий, не потрібно зберігати
	
	if Engine.has_singleton("ServiceLocator"):
		var enemy_state_manager = null
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_enemy_state_manager"):
				enemy_state_manager = service_locator.get_enemy_state_manager()
		if enemy_state_manager:
			var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename() if get_tree().current_scene else "Unknown"
			var enemy_name = name
			enemy_state_manager.save_enemy_state(scene_name, enemy_name, false)
			enemy_state_manager.save_enemy_states_to_storage()
		else:
			DebugLogger.warning("Enemy: EnemyStateManager not found, cannot save revival state", "Enemy")
	else:
		DebugLogger.warning("Enemy: ServiceLocator not found, cannot save revival state", "Enemy")

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
		if enemy_logic.player_detected.is_connected(_on_logic_player_detected):
			enemy_logic.player_detected.disconnect(_on_logic_player_detected)
		if enemy_logic.player_lost.is_connected(_on_logic_player_lost):
			enemy_logic.player_lost.disconnect(_on_logic_player_lost)
