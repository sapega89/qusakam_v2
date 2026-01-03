## Компаньйон-лікар
## Реалізує ICompanionAssist для лікування
extends Node2D
class_name CompanionHealer

## Посилання на ціль (гравець або союзник)
var target: Node = null

## Кількість здоров'я для відновлення
@export var heal_amount: int = 20

## Тривалість ефекту лікування
@export var heal_duration: float = 1.0

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
	
	# Запускаємо лікування
	_start_heal()

## Реалізація ICompanionAssist.assist()
func assist(target_node: Node) -> void:
	target = target_node
	_start_heal()

## Реалізація ICompanionAssist.get_assist_type()
func get_assist_type() -> String:
	return "heal"

## Реалізація ICompanionAssist.can_assist()
func can_assist() -> bool:
	return not assist_completed

## Запускає лікування
func _start_heal() -> void:
	if assist_completed:
		return
	
	if not target:
		queue_free()
		return
	
	# Позиціонуємо біля цілі
	if is_instance_valid(target) and target is Node2D:
		var target_pos = (target as Node2D).global_position
		global_position = target_pos + Vector2(0, -30)
	
	# Граємо анімацію лікування
	if animation_player:
		animation_player.play("heal")
	elif sprite:
		sprite.play("heal")
	
	# Затримка перед лікуванням (для анімації)
	await get_tree().create_timer(0.3).timeout
	
	# Лікуємо ціль
	if is_instance_valid(target):
		_apply_heal(target)
	
	# VFX для лікування
	_play_heal_effect()
	
	assist_completed = true
	
	# Видаляємо компаньйона після затримки
	await get_tree().create_timer(cleanup_delay).timeout
	queue_free()

## Застосовує лікування до цілі
func _apply_heal(target_node: Node) -> void:
	if not target_node:
		return
	
	# Використовуємо heal_damage() якщо доступно (CombatBody2D має цей метод)
	if target_node.has_method("heal_damage"):
		target_node.heal_damage(heal_amount)
		print("💚 CompanionHealer: Відновлено ", heal_amount, " HP для ", target_node.name)
	else:
		# Fallback: якщо це IDamageable, спробуємо знайти CombatBody2D
		if IDamageable.is_implemented_by(target_node):
			# Спробуємо знайти HealthComponent та оновити здоров'я через нього
			var health_component = _find_health_component(target_node)
			if health_component and health_component.owner_body:
				health_component.owner_body.heal_damage(heal_amount)
				print("💚 CompanionHealer: Відновлено ", heal_amount, " HP через HealthComponent")
			else:
				push_warning("CompanionHealer: Ціль не має методу heal_damage()")
		else:
			push_error("CompanionHealer: Ціль не реалізує IDamageable")

## Знаходить HealthComponent у цілі
func _find_health_component(target: Node) -> Node:
	for child in target.get_children():
		if child is HealthComponent:
			return child
	return null

## Відтворює VFX для лікування
func _play_heal_effect() -> void:
	if not target or not is_instance_valid(target):
		return
	
	# Використовуємо VFXHooks якщо доступний
	var vfx_hooks = _get_vfx_hooks()
	if vfx_hooks:
		vfx_hooks.play_heal_effect(target)
	else:
		# Fallback до власного VFX
		var target_pos = target.global_position if target is Node2D else Vector2.ZERO
		var particles := CPUParticles2D.new()
		particles.one_shot = true
		particles.emitting = true
		particles.amount = 25
		particles.lifetime = 0.6
		particles.speed_scale = 1.2
		particles.direction = Vector2(0, -1)
		particles.spread = 30.0
		particles.initial_velocity_min = 30.0
		particles.initial_velocity_max = 80.0
		particles.gravity = Vector2(0, -50)
		particles.color = Color(0.2, 1.0, 0.3, 0.9)
		particles.position = target_pos
		particles.z_index = 250
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(particles)
			await get_tree().create_timer(0.7).timeout
			if is_instance_valid(particles):
				particles.queue_free()

## Знаходить VFXHooks в сцені
func _get_vfx_hooks() -> VFXHooks:
	var scene_root = get_tree().current_scene
	if scene_root:
		var vfx = scene_root.get_node_or_null("VFXHooks")
		if vfx and vfx is VFXHooks:
			return vfx
		# Шукаємо в дочірніх нодах
		for child in scene_root.get_children():
			if child is VFXHooks:
				return child
	return null

## Обробник завершення анімації
func _on_animation_finished() -> void:
	if assist_completed:
		queue_free()

