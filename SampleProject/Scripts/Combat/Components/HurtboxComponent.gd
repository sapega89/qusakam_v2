## Компонент зони отримання ушкоджень
## Висить на Hurtbox (Area2D) та обробляє попадання
## Автоматично знаходить HealthComponent та передає ушкодження
extends Node
class_name HurtboxComponent

## Посилання на Hurtbox (Area2D)
@export var hurtbox: Area2D

## Посилання на HealthComponent власника
@export var health_component: HealthComponent

## Посилання на власника (CombatBody2D)
@export var owner_body: CombatBody2D

func _ready() -> void:
	# Автоматично знаходимо Hurtbox, якщо не встановлено
	if not hurtbox:
		hurtbox = get_parent() as Area2D
		if not hurtbox:
			push_error("HurtboxComponent: Parent is not Area2D")
	
	# Автоматично знаходимо HealthComponent
	if not health_component:
		# Шукаємо у власника
		if not owner_body:
			owner_body = get_parent().get_parent() as CombatBody2D
		
		if owner_body:
			for child in owner_body.get_children():
				if child is HealthComponent:
					health_component = child
					break
	
	# Підключаємося до сигналів Hurtbox
	if hurtbox:
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)

## Обробник входження Area2D (Hitbox) в Hurtbox
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area:
		return
	
	# Шукаємо DamageApplier в Area2D
	var damage_applier = _find_damage_applier(area)
	if not damage_applier:
		return
	
	# Перевіряємо, чи DamageApplier активний
	if not damage_applier.is_active:
		return
	
	# Перевіряємо, чи власник живий
	if not health_component or not health_component.is_alive():
		return
	
	# Отримуємо ушкодження з DamageApplier
	var damage = damage_applier.current_damage
	var source = damage_applier.owner_body
	
	# Застосовуємо ушкодження через HealthComponent
	health_component.apply_damage(damage, source)

## Знаходить DamageApplier в Area2D
func _find_damage_applier(area: Area2D) -> DamageApplier:
	for child in area.get_children():
		if child is DamageApplier:
			return child
	return null

