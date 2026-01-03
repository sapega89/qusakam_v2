extends DefaultEnemy
class_name DemoBoss

## Бос лабораторії - сильний ворог з фазами

# Фази боса (MVP: 2 фази)
enum BossPhase {
	PHASE_1,
	PHASE_2
}

var current_phase: BossPhase = BossPhase.PHASE_1
var _intro_line_played: bool = false

# Спеціальні атаки
var special_attack_cooldown: float = 0.0
var special_attack_interval: float = 5.0  # Кожні 5 секунд можлива спеціальна атака
var last_special_attack_time: float = 0.0

# Типи спеціальних атак
enum SpecialAttackType {
	NONE,
	SWEEP,      # Атака з розмахом
	CHARGE      # Зарядка
}

var next_special_attack: SpecialAttackType = SpecialAttackType.NONE

func _ready():
	super._ready()
	
	# Параметри для боса
	speed = 60
	base_damage = 30.0
	damage = 30.0
	attack_cooldown = 1.5
	
	# Тактичні параметри
	detection_range = 500.0
	attack_range = 120.0
	chase_range = 600.0
	
	# Більше здоров'я для боса
	Max_Health = 300
	current_health = Max_Health
	
	# Додаємо до групи босів
	add_to_group(GameGroups.BOSS)
	
	print("👑 DemoBoss: Ініціалізовано боса лабораторії")
	_play_intro_line()

func _process(delta):
	super._process(delta)
	
	# Оновлюємо cooldown спеціальних атак
	if special_attack_cooldown > 0.0:
		special_attack_cooldown -= delta
	
	# Перевіряємо фази боса
	var health_percent = float(current_health) / float(Max_Health) if Max_Health > 0 else 0.0
	if current_phase == BossPhase.PHASE_1 and health_percent <= 0.5:
		current_phase = BossPhase.PHASE_2
		_enter_phase_2()
	
	# Перевіряємо, чи можна виконати спеціальну атаку
	_check_special_attack_opportunity()

func _enter_phase_2():
	"""Вхід у другу фазу"""
	print("👑 DemoBoss: Фаза 2 - стає швидшим та агресивнішим")
	speed = 90
	damage = 45.0
	attack_cooldown = 1.1
	detection_range = 600.0
	special_attack_interval = 3.5  # Частіші спеціальні атаки в фазі 2

func _play_intro_line() -> void:
	if _intro_line_played:
		return
	_intro_line_played = true
	# MVP: просто в консоль (пізніше підв'яжемо до DialogueSystem)
	print("BOSS DIALOGUE: віддавай свій плащ, Кусакам")

## Перевіряє можливість спеціальної атаки
func _check_special_attack_opportunity() -> void:
	if not player or is_dead:
		return
	
	if special_attack_cooldown > 0.0:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_special_attack_time < special_attack_interval:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Визначаємо тип спеціальної атаки залежно від відстані та фази
	if distance_to_player <= attack_range * 1.5:
		# Близько - атака з розмахом
		next_special_attack = SpecialAttackType.SWEEP
		_perform_special_attack(SpecialAttackType.SWEEP)
	elif distance_to_player > attack_range * 2.0 and distance_to_player < chase_range:
		# Середня відстань - зарядка
		next_special_attack = SpecialAttackType.CHARGE
		_perform_special_attack(SpecialAttackType.CHARGE)

## Виконує спеціальну атаку
func _perform_special_attack(attack_type: SpecialAttackType) -> void:
	if special_attack_cooldown > 0.0:
		return
	
	if not player or is_dead:
		return
	
	match attack_type:
		SpecialAttackType.SWEEP:
			_perform_sweep_attack()
		SpecialAttackType.CHARGE:
			_perform_charge_attack()
		_:
			return
	
	special_attack_cooldown = special_attack_interval
	last_special_attack_time = Time.get_ticks_msec() / 1000.0

## Атака з розмахом - урон по площі
func _perform_sweep_attack() -> void:
	print("👑 DemoBoss: Виконує атаку з розмахом!")
	
	# VFX для атаки з розмахом через VFXHooks
	var vfx_hooks = _get_vfx_hooks()
	if vfx_hooks:
		vfx_hooks.play_boss_attack_effect(self, "sweep")
	else:
		_play_sweep_vfx()
	
	# Знаходимо всіх ворогів/гравця в радіусі
	var sweep_radius = attack_range * 1.5
	var sweep_area = get_tree().get_nodes_in_group(GameGroups.PLAYER)
	
	for target in sweep_area:
		if not target or not is_instance_valid(target):
			continue
		
		if not target is Node2D:
			continue
		
		var target_pos = (target as Node2D).global_position
		var distance = global_position.distance_to(target_pos)
		
		if distance <= sweep_radius:
			# Наносимо урон (трохи менший за звичайну атаку, але по площі)
			var sweep_damage = damage * 0.8
			if IDamageable.is_implemented_by(target):
				IDamageable.safe_take_damage(target, int(sweep_damage), self)
				print("👑 DemoBoss: Sweep attack hit ", target.name, " for ", int(sweep_damage), " damage")
	
	# Анімація атаки
	if has_node("AnimatedSprite2D"):
		var sprite = get_node("AnimatedSprite2D")
		if sprite.has_animation("sweep_attack"):
			sprite.play("sweep_attack")
		else:
			sprite.play("attack")

## Зарядка - швидка атака з великим уроном
func _perform_charge_attack() -> void:
	if not player or not is_instance_valid(player):
		return
	
	print("👑 DemoBoss: Виконує зарядку!")
	
	# VFX для зарядки через VFXHooks
	var vfx_hooks = _get_vfx_hooks()
	if vfx_hooks:
		vfx_hooks.play_boss_attack_effect(self, "charge")
	else:
		_play_charge_vfx()
	
	# Зберігаємо початкову швидкість
	var original_speed = speed
	var charge_speed = speed * 2.5
	var charge_damage = damage * 1.5
	
	# Швидко рухаємося до гравця
	var direction = (player.global_position - global_position).normalized()
	var charge_distance = global_position.distance_to(player.global_position)
	var charge_duration = charge_distance / charge_speed
	
	# Анімація зарядки
	if has_node("AnimatedSprite2D"):
		var sprite = get_node("AnimatedSprite2D")
		if sprite.has_animation("charge"):
			sprite.play("charge")
		else:
			sprite.play("walk")
	
	# Зарядка
	speed = charge_speed
	velocity = direction * charge_speed
	
	# Чекаємо поки досягнемо гравця або пройдемо максимальну відстань
	await get_tree().create_timer(min(charge_duration, 1.0)).timeout
	
	# Перевіряємо, чи досягли гравця
	var final_distance = global_position.distance_to(player.global_position)
	if final_distance <= attack_range * 1.2:
		# Наносимо урон зарядки
		if IDamageable.is_implemented_by(player):
			IDamageable.safe_take_damage(player, int(charge_damage), self)
			print("👑 DemoBoss: Charge attack hit player for ", int(charge_damage), " damage")
	
	# Повертаємо нормальну швидкість
	speed = original_speed
	velocity = Vector2.ZERO

## Знаходить VFXHooks в сцені
func _get_vfx_hooks() -> VFXHooks:
	var scene_root = get_tree().current_scene
	if scene_root:
		var vfx = scene_root.get_node_or_null("VFXHooks")
		if vfx and vfx is VFXHooks:
			return vfx
		for child in scene_root.get_children():
			if child is VFXHooks:
				return child
	return null

## VFX для атаки з розмахом
func _play_sweep_vfx() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 0.4
	particles.speed_scale = 1.5
	particles.direction = Vector2(0, 0)
	particles.spread = 180.0  # Півколо
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 50)
	particles.color = Color(1.0, 0.3, 0.1, 0.9)  # Червоно-помаранчевий
	particles.position = global_position
	particles.z_index = 250
	
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(particles)
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(particles):
			particles.queue_free()

## VFX для зарядки
func _play_charge_vfx() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = false
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.3
	particles.speed_scale = 2.0
	particles.direction = Vector2(0, -1)
	particles.spread = 20.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 0)
	particles.color = Color(0.8, 0.8, 1.0, 0.8)  # Світло-синій
	particles.position = global_position
	particles.z_index = 200
	
	add_child(particles)
	
	# Видаляємо після зарядки
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Перевизначаємо perform_attack для додавання логіки спеціальних атак
func perform_attack():
	# Не атакуємо під час паузи
	if get_tree().paused:
		return
	
	# Якщо є можливість спеціальної атаки, виконуємо її
	if next_special_attack != SpecialAttackType.NONE and special_attack_cooldown <= 0.0:
		_perform_special_attack(next_special_attack)
		next_special_attack = SpecialAttackType.NONE
		return
	
	# Інакше виконуємо звичайну атаку (викликаємо батьківський метод DefaultEnemy)
	if not player:
		return
	
	print("👑 DemoBoss: Виконує звичайну атаку! Урон: ", damage)
	
	if has_node("AnimatedSprite2D"):
		get_node("AnimatedSprite2D").play("attack")
	
	if hitbox:
		hitbox.visible = true
		hitbox.monitoring = true
		hitbox.monitorable = true
	
	# Наносимо урон гравцю
	if player and global_position.distance_to(player.global_position) <= attack_range * 1.2:
		if IDamageable.is_implemented_by(player):
			IDamageable.safe_take_damage(player, int(damage), self)
			print("👑 DemoBoss: Hit player for ", damage, " damage! Player health: ", player.current_health if player.has("current_health") else "unknown")
	
	await get_tree().create_timer(0.3).timeout
	
	if hitbox:
		hitbox.visible = false
		hitbox.monitoring = false
		hitbox.monitorable = false
