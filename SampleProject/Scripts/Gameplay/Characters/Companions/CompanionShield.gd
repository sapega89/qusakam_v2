## Компаньйон-щит
## Реалізує ICompanionAssist для надання тимчасового захисту
extends Node2D
class_name CompanionShield

## Посилання на ціль (гравець або союзник)
var target: Node = null

## Тривалість щита
@export var shield_duration: float = 5.0

## Множник зменшення ушкоджень (0.0 = повний захист, 1.0 = без захисту)
@export var damage_reduction: float = 0.5

## Затримка перед видаленням
@export var cleanup_delay: float = 0.5

## Посилання на компоненти
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Чи виконано assist
var assist_completed: bool = false

## Таймер щита
var shield_timer: float = 0.0

func _ready() -> void:
	# Знаходимо гравця як ціль за замовчуванням
	if not target:
		target = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	
	# Запускаємо щит
	_start_shield()

## Реалізація ICompanionAssist.assist()
func assist(target_node: Node) -> void:
	target = target_node
	_start_shield()

## Реалізація ICompanionAssist.get_assist_type()
func get_assist_type() -> String:
	return "shield"

## Реалізація ICompanionAssist.can_assist()
func can_assist() -> bool:
	return not assist_completed

## Запускає щит
func _start_shield() -> void:
	if assist_completed:
		return
	
	if not target:
		queue_free()
		return
	
	# Позиціонуємо біля цілі
	if is_instance_valid(target) and target is Node2D:
		var target_pos = (target as Node2D).global_position
		global_position = target_pos + Vector2(0, -30)
	
	# Граємо анімацію щита
	if animation_player:
		animation_player.play("shield")
	elif sprite:
		sprite.play("shield")
	
	# Затримка перед активацією щита
	await get_tree().create_timer(0.3).timeout
	
	# Застосовуємо щит
	if is_instance_valid(target):
		_apply_shield(target)
	
	# VFX для щита
	_play_shield_effect()
	
	assist_completed = true
	
	# Очікуємо тривалість щита
	shield_timer = shield_duration
	await get_tree().create_timer(shield_duration).timeout
	
	# Знімаємо щит
	if is_instance_valid(target):
		_remove_shield(target)
	
	# Видаляємо компаньйона
	await get_tree().create_timer(cleanup_delay).timeout
	queue_free()

## Застосовує щит до цілі
func _apply_shield(target_node: Node) -> void:
	if not target_node:
		return
	
	# Додаємо метадані для щита (тимчасовий захист)
	if not target_node.has_meta("shield_active"):
		target_node.set_meta("shield_active", true)
		target_node.set_meta("shield_damage_reduction", damage_reduction)
		print("🛡️ CompanionShield: Активовано щит для ", target_node.name, " (зменшення ушкоджень: ", (1.0 - damage_reduction) * 100, "%)")
	
	# Якщо ціль має метод для встановлення щита
	if target_node.has_method("set_shield"):
		target_node.set_shield(true, damage_reduction, shield_duration)

## Знімає щит з цілі
func _remove_shield(target_node: Node) -> void:
	if not target_node:
		return
	
	if target_node.has_meta("shield_active"):
		target_node.remove_meta("shield_active")
		target_node.remove_meta("shield_damage_reduction")
		print("🛡️ CompanionShield: Щит знято з ", target_node.name)
	
	# Якщо ціль має метод для зняття щита
	if target_node.has_method("set_shield"):
		target_node.set_shield(false, 0.0, 0.0)

## Відтворює VFX для щита
func _play_shield_effect() -> void:
	if not target or not is_instance_valid(target):
		return
	
	# Використовуємо VFXHooks якщо доступний
	var vfx_hooks = _get_vfx_hooks()
	if vfx_hooks:
		vfx_hooks.play_shield_effect(target)
	else:
		# Fallback до власного VFX
		var target_pos = target.global_position if target is Node2D else Vector2.ZERO
		var particles := CPUParticles2D.new()
		particles.one_shot = true
		particles.emitting = true
		particles.amount = 30
		particles.lifetime = 0.8
		particles.speed_scale = 0.8
		particles.direction = Vector2(0, 0)
		particles.spread = 360.0
		particles.initial_velocity_min = 20.0
		particles.initial_velocity_max = 60.0
		particles.gravity = Vector2(0, -20)
		particles.color = Color(0.3, 0.6, 1.0, 0.8)
		particles.position = target_pos
		particles.z_index = 250
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(particles)
			await get_tree().create_timer(0.9).timeout
			if is_instance_valid(particles):
				particles.queue_free()

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

## Обробник завершення анімації
func _on_animation_finished() -> void:
	# Не видаляємо одразу, очікуємо завершення щита
	pass

