extends DefaultEnemy
class_name EnemyWithCollectibleDrop

## Враг, который при смерти спавнит синий шарик (Collectible)

@export var collectible_scene_path: String = "res://SampleProject/Objects/Collectible.tscn"
@export var collectible_node_path: NodePath = NodePath("../EnemyCollectible")

# Посилання на DamageApplier
var damage_applier: DamageApplier = null
var collectible: Node2D = null

func _ready():
	# Вызываем родительский _ready()
	super._ready()
	
	# Находим DamageApplier
	damage_applier = get_node_or_null("hitbox/DamageApplier")
	if damage_applier:
		print("💎 EnemyWithCollectibleDrop: DamageApplier найден")
	else:
		print("⚠️ EnemyWithCollectibleDrop: DamageApplier не найден, урон будет через прямые вызовы")
	
	# Находим Collectible в сцене
	if collectible_node_path and not collectible_node_path.is_empty():
		collectible = get_node_or_null(collectible_node_path)
		if collectible:
			print("💎 EnemyWithCollectibleDrop: Collectible найден в сцене")
		else:
			print("⚠️ EnemyWithCollectibleDrop: Collectible не найден по пути: ", collectible_node_path)
	else:
		# Пытаемся найти по имени
		var parent = get_parent()
		if parent:
			collectible = parent.get_node_or_null("EnemyCollectible")
			if collectible:
				print("💎 EnemyWithCollectibleDrop: Collectible найден по имени")

func start_attack():
	# Вызываем родительский метод
	super.start_attack()
	
	# Активируем DamageApplier, если он есть
	if damage_applier:
		damage_applier.enable_damage()
		print("💎 EnemyWithCollectibleDrop: DamageApplier активирован")

func end_attack():
	# Деактивируем DamageApplier, если он есть
	if damage_applier:
		damage_applier.disable_damage()
		print("💎 EnemyWithCollectibleDrop: DamageApplier деактивирован")
	
	# Вызываем родительский метод
	super.end_attack()

func die():
	# Вызываем родительский метод die()
	super.die()
	
	# Спавним Collectible на позиции врага
	spawn_collectible()

func spawn_collectible():
	"""Показывает синий шарик на позиции врага (если он есть в сцене)"""
	# Используем call_deferred для безопасности
	call_deferred("_show_collectible_deferred")

func _show_collectible_deferred():
	"""Отложенное отображение Collectible с анимацией выпадения"""
	if collectible and is_instance_valid(collectible):
		# Сохраняем финальную позицию
		var final_position = global_position
		
		# Устанавливаем начальную позицию (немного выше врага для эффекта выпадения)
		var start_position = final_position + Vector2(0, -30)
		collectible.global_position = start_position
		collectible.visible = true
		
		# Анимация выпадения: падение вниз с небольшим вращением
		var tween = collectible.create_tween()
		tween.set_parallel(true)
		
		# Движение вниз до финальной позиции
		tween.tween_property(collectible, "global_position:y", final_position.y, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		
		# Вращение при падении
		collectible.rotation = 0.0
		tween.tween_property(collectible, "rotation", TAU * 0.5, 0.4)
		
		# Небольшое покачивание влево-вправо при падении
		var bounce_offset_x = randf_range(-8, 8)
		tween.tween_property(collectible, "global_position:x", final_position.x + bounce_offset_x, 0.2)
		tween.tween_property(collectible, "global_position:x", final_position.x, 0.2).set_delay(0.2)
		
		print("💎 EnemyWithCollectibleDrop: Показан синий шарик с анимацией выпадения на позиции ", final_position)
	else:
		# Fallback: если Collectible не найден в сцене, создаем динамически
		push_warning("⚠️ EnemyWithCollectibleDrop: Collectible не найден в сцене, создаем динамически")
		var collectible_scene = load(collectible_scene_path)
		if not collectible_scene:
			push_error("❌ EnemyWithCollectibleDrop: Не удалось загрузить сцену Collectible: " + collectible_scene_path)
			return
		
		var new_collectible = collectible_scene.instantiate()
		if not new_collectible:
			push_error("❌ EnemyWithCollectibleDrop: Не удалось создать экземпляр Collectible")
			return
		
		var parent_node = get_parent()
		if not parent_node:
			parent_node = get_tree().current_scene
		
		if parent_node:
			parent_node.add_child(new_collectible)
			new_collectible.global_position = global_position
			
			# Для динамически созданных Collectible устанавливаем уникальный ID
			var unique_id = "enemy_drop_" + str(get_instance_id()) + "_" + str(Time.get_ticks_msec())
			new_collectible.set_meta("object_id", unique_id)
			
			# Подключаем сигнал для сбора
			if not new_collectible.body_entered.is_connected(new_collectible.collect):
				new_collectible.body_entered.connect(new_collectible.collect)
			
			print("💎 EnemyWithCollectibleDrop: Создан синий шарик динамически на позиции ", global_position)
		else:
			push_error("❌ EnemyWithCollectibleDrop: Не найден родительский узел для спавна Collectible")
			new_collectible.queue_free()
