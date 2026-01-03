extends DefaultEnemy
class_name EnemyRanged

## Враг дальнего боя - стреляет на расстоянии, медленнее двигается

var projectile_scene: PackedScene = null
var projectile_spawn_point: Node2D = null

func _ready():
	super._ready()
	
	# Параметры для дальнего боя
	speed = 50  # Медленнее обычного
	base_damage = 12.0
	damage = 12.0
	attack_cooldown = 2.0  # Медленнее атакует (зарядка)
	
	# Тактические параметры
	detection_range = 400.0
	attack_range = 250.0  # Дальний бой
	chase_range = 300.0  # Держится на расстоянии
	
	# Баланс здоров'я для дальнього бою (менше, бо на відстані)
	Max_Health = 50
	current_health = Max_Health
	
	# Ищем точку спавна снарядов
	projectile_spawn_point = get_node_or_null("ProjectileSpawnPoint")
	if not projectile_spawn_point:
		# Создаем точку спавна если её нет
		projectile_spawn_point = Node2D.new()
		projectile_spawn_point.name = "ProjectileSpawnPoint"
		projectile_spawn_point.position = Vector2(0, -20)
		add_child(projectile_spawn_point)
	
	print("🏹 EnemyRanged: Инициализирован враг дальнего боя")

func perform_attack():
	# Не атакуем під час паузи
	if get_tree().paused:
		return
	
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > attack_range * 1.2:
		return
	
	print("EnemyRanged performing ranged attack!")
	
	$AnimatedSprite2D.play("attack")
	start_attack()
	
	# Для дальнего боя можно добавить логику стрельбы снарядами
	# Пока используем обычную атаку, но на расстоянии
	if projectile_scene and projectile_spawn_point:
		# TODO: Реализовать стрельбу снарядами
		pass
	else:
		# Fallback: обычная атака
		if player and global_position.distance_to(player.global_position) <= attack_range * 1.2:
			player.take_damage(damage)
			print("EnemyRanged hit player for ", damage, " damage!")
	
	await get_tree().create_timer(0.5).timeout
	end_attack()

