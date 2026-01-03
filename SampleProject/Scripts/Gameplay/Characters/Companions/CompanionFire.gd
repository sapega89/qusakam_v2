## Компаньйон вогню
## Реалізує ICompanionAssist для нанесення ушкоджень
extends Node2D
class_name CompanionFire

## Посилання на ціль (гравець або ворог)
var target: Node = null

## Ушкодження компаньйона
@export var damage: int = 15

## Тривалість атаки
@export var attack_duration: float = 1.0

## Cooldown перед видаленням
@export var cleanup_delay: float = 0.5

## Посилання на компоненти
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var damage_applier: DamageApplier = $Hitbox/DamageApplier

## Чи виконано assist
var assist_completed: bool = false

func _ready() -> void:
	# Знаходимо гравця як ціль за замовчуванням
	if not target:
		target = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	
	# Налаштовуємо DamageApplier
	if damage_applier:
		damage_applier.base_damage = damage
		damage_applier.owner_body = self
	
	# Запускаємо атаку
	_start_attack()

## Реалізація ICompanionAssist.assist()
func assist(target_node: Node) -> void:
	target = target_node
	_start_attack()

## Реалізація ICompanionAssist.get_assist_type()
func get_assist_type() -> String:
	return "fire"

## Реалізація ICompanionAssist.can_assist()
func can_assist() -> bool:
	return not assist_completed

## Запускає атаку
func _start_attack() -> void:
	if assist_completed:
		return
	
	# Позиціонуємо біля цілі
	if is_instance_valid(target) and target is Node2D:
		var target_pos = (target as Node2D).global_position
		global_position = target_pos + Vector2(50, -30)
	
	# Граємо анімацію атаки
	if animation_player:
		animation_player.play("attack")
	elif sprite:
		sprite.play("attack")
	
	# Увімкнути DamageApplier через невелику затримку
	await get_tree().create_timer(0.2).timeout
	
	if damage_applier:
		damage_applier.enable_damage()
	
	# Вимикаємо DamageApplier після атаки
	await get_tree().create_timer(attack_duration).timeout
	
	if damage_applier:
		damage_applier.disable_damage()
	
	# VFX для вогню
	_play_fire_effect()
	
	assist_completed = true
	
	# Видаляємо компаньйона після затримки
	await get_tree().create_timer(cleanup_delay).timeout
	queue_free()

## Відтворює VFX для вогню
func _play_fire_effect() -> void:
	if not target or not is_instance_valid(target):
		return
	
	# Використовуємо VFXHooks якщо доступний
	var vfx_hooks = _get_vfx_hooks()
	if vfx_hooks:
		vfx_hooks.play_fire_effect(target)

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
	if assist_completed:
		queue_free()

