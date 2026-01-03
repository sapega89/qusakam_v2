## Компаньйон-утиліта
## Реалізує ICompanionAssist для утилітарних дій (прискорення, телепорт тощо)
extends Node2D
class_name CompanionUtility

## Посилання на ціль (гравець)
var target: Node = null

## Тип утиліти: "speed" (прискорення), "teleport" (телепорт), "stun" (оглушення ворогів)
@export var utility_type: String = "speed"

## Тривалість ефекту
@export var effect_duration: float = 3.0

## Параметри для різних типів утиліт
@export var speed_multiplier: float = 1.5  # Для speed
@export var teleport_distance: float = 200.0  # Для teleport
@export var stun_radius: float = 150.0  # Для stun

## Затримка перед видаленням
@export var cleanup_delay: float = 0.5

## Посилання на компоненти
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Чи виконано assist
var assist_completed: bool = false

func _ready() -> void:
	# Знаходимо гравця як ціль за замовчуванням
	if not target:
		target = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	
	# Запускаємо утиліту
	_start_utility()

## Реалізація ICompanionAssist.assist()
func assist(target_node: Node) -> void:
	target = target_node
	_start_utility()

## Реалізація ICompanionAssist.get_assist_type()
func get_assist_type() -> String:
	return "utility"

## Реалізація ICompanionAssist.can_assist()
func can_assist() -> bool:
	return not assist_completed

## Запускає утиліту
func _start_utility() -> void:
	if assist_completed:
		return
	
	if not target:
		queue_free()
		return
	
	# Позиціонуємо біля цілі
	if is_instance_valid(target) and target is Node2D:
		var target_pos = (target as Node2D).global_position
		global_position = target_pos + Vector2(0, -30)
	
	# Граємо анімацію
	if animation_player:
		animation_player.play("utility")
	elif sprite:
		sprite.play("utility")
	
	# Затримка перед активацією
	await get_tree().create_timer(0.2).timeout
	
	# Застосовуємо утиліту залежно від типу
	if is_instance_valid(target):
		match utility_type:
			"speed":
				_apply_speed_boost(target)
			"teleport":
				_apply_teleport(target)
			"stun":
				_apply_stun(target)
			_:
				push_error("CompanionUtility: Невідомий тип утиліти: " + utility_type)
	
	# VFX для утиліти
	_play_utility_effect()
	
	assist_completed = true
	
	# Видаляємо компаньйона після затримки
	await get_tree().create_timer(cleanup_delay).timeout
	queue_free()

## Застосовує прискорення
func _apply_speed_boost(target_node: Node) -> void:
	if not target_node:
		return
	
	# Встановлюємо метадані для прискорення
	if not target_node.has_meta("speed_boost_active"):
		target_node.set_meta("speed_boost_active", true)
		target_node.set_meta("speed_boost_multiplier", speed_multiplier)
		target_node.set_meta("speed_boost_end_time", Time.get_ticks_msec() / 1000.0 + effect_duration)
		print("⚡ CompanionUtility: Активовано прискорення для ", target_node.name, " (x", speed_multiplier, ")")
	
	# Якщо ціль має метод для встановлення прискорення
	if target_node.has_method("set_speed_multiplier"):
		target_node.set_speed_multiplier(speed_multiplier, effect_duration)

## Застосовує телепорт
func _apply_teleport(target_node: Node) -> void:
	if not target_node or not target_node is Node2D:
		return
	
	var target_2d = target_node as Node2D
	var facing_direction = 1.0
	
	# Визначаємо напрямок гравця
	if target_node.has_method("get_facing_direction"):
		facing_direction = sign(target_node.get_facing_direction())
	elif target_node.has("facing_direction"):
		facing_direction = sign(target_node.facing_direction)
	
	# Телепортуємо в напрямку руху
	var teleport_offset = Vector2(facing_direction * teleport_distance, 0)
	var new_position = target_2d.global_position + teleport_offset
	
	# Перевіряємо, чи нова позиція валідна (не в стіні)
	# Простий перевірка: можна додати RayCast2D для перевірки колізій
	target_2d.global_position = new_position
	
	print("✨ CompanionUtility: Телепортовано ", target_node.name, " на відстань ", teleport_distance)

## Застосовує оглушення ворогів
func _apply_stun(target_node: Node) -> void:
	if not target_node or not target_node is Node2D:
		return
	
	var target_pos = (target_node as Node2D).global_position
	var stunned_count = 0
	
	# Знаходимо всіх ворогів у радіусі
	var enemies = get_tree().get_nodes_in_group(GameGroups.ENEMIES)
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		
		var enemy_pos = (enemy as Node2D).global_position
		var distance = target_pos.distance_to(enemy_pos)
		
		if distance <= stun_radius:
			# Оглушуємо ворога
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(effect_duration)
				stunned_count += 1
			elif enemy.has_meta("stunned"):
				enemy.set_meta("stunned", true)
				enemy.set_meta("stun_end_time", Time.get_ticks_msec() / 1000.0 + effect_duration)
				stunned_count += 1
	
	print("💫 CompanionUtility: Оглушено ", stunned_count, " ворогів у радіусі ", stun_radius)

## Відтворює VFX для утиліти
func _play_utility_effect() -> void:
	if not target or not is_instance_valid(target):
		return
	
	var target_pos = target.global_position if target is Node2D else Vector2.ZERO
	
	# Створюємо частинки залежно від типу утиліти
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.speed_scale = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 360.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 50)
	
	# Кольори залежно від типу
	match utility_type:
		"speed":
			particles.color = Color(1.0, 0.8, 0.2, 0.9)  # Жовтий
		"teleport":
			particles.color = Color(0.8, 0.2, 1.0, 0.9)  # Фіолетовий
		"stun":
			particles.color = Color(1.0, 0.5, 0.0, 0.9)  # Помаранчевий
		_:
			particles.color = Color(0.5, 0.5, 0.5, 0.9)  # Сірий
	
	particles.position = target_pos
	particles.z_index = 250
	
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(particles)
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(particles):
			particles.queue_free()

## Обробник завершення анімації
func _on_animation_finished() -> void:
	if assist_completed:
		queue_free()

