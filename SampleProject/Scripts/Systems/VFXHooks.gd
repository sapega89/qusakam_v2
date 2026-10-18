extends Node
class_name VFXHooks

## Minimal VFX hooks for MVP:
## - Dust puff on landing (MapleStory-ish placeholder)
## - Slash pop on hit (placeholder)

@export var enabled: bool = true

var landing_cooldown: float = 0.0
const LANDING_COOLDOWN_TIME: float = 0.5  # Минимальное время между эффектами приземления
const MIN_FALL_HEIGHT: float = 20.0  # Минимальная высота падения для показа эффекта (в пикселях)
const MAX_FALL_HEIGHT: float = 200.0  # Высота падения для максимального эффекта (в пикселях)

## Бойові ефекти (6a): слід замаху, ефект влучання в точці контакту, спалах ушкодження.
## Важкий удар (зброя з відкиданням, D203) — більший ефект, hitstop і тремтіння камери.
const SLASH_TRAIL_SCENE := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
const HIT_IMPACT_SCENE := preload("res://SampleProject/Scenes/FX/HitImpact.tscn")
const HURT_FLASH := Color(2.4, 2.4, 2.4)  # self_modulate > 1 — спрайт висвітлюється
const HURT_FLASH_TIME := 0.08
const HEAVY_SCALE := 1.6
const HEAVY_HITSTOP := 0.07
const HEAVY_SHAKE := 5.0
const HEAVY_SHAKE_TIME := 0.15

func _init() -> void:
	print("🔧 VFXHooks: _init() called - VFXHooks instance created!")

func _process(delta: float) -> void:
	if landing_cooldown > 0:
		landing_cooldown -= delta

func _ready() -> void:
	print("🔧 VFXHooks: _ready() called, enabled = ", enabled)
	if not enabled:
		print("⚠️ VFXHooks: Disabled")
		return

	# Используем call_deferred для подключения после полной инициализации
	call_deferred("_connect_to_event_bus")

func _connect_to_event_bus() -> void:
	EventBus.player_landed.connect(_on_player_landed)
	EventBus.damage_received.connect(_on_damage_received)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.skill_used.connect(_on_skill_used)


## ============================================
## ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ГЕНЕРАЦИИ ЭФФЕКТОВ
## ============================================

func _on_player_landed(fall_height: float) -> void:
	print("✨ VFXHooks: Player landed signal received! Fall height = ", fall_height, " pixels")

	# Проверяем кулдаун, чтобы не создавать эффекты слишком часто
	if landing_cooldown > 0:
		print("⚠️ VFXHooks: Cooldown active (", landing_cooldown, "), skipping effect")
		return

	# Игнорируем очень маленькие падения
	if fall_height < MIN_FALL_HEIGHT:
		print("⚠️ VFXHooks: Fall height too small (", fall_height, " < ", MIN_FALL_HEIGHT, "), skipping effect")
		return

	print("✅ VFXHooks: Creating dust effect for fall height = ", fall_height, " pixels")
	landing_cooldown = LANDING_COOLDOWN_TIME

	var player = GameGroups.get_player()
	if not player or not is_instance_valid(player):
		return

	# Получаем позицию игрока в глобальных координатах
	var dust_pos: Vector2
	if player is Node2D:
		dust_pos = player.global_position + Vector2(0, 15)  # Немного ниже ног
	else:
		return

	# Создаем эффект с учетом высоты падения
	_spawn_dust(dust_pos, fall_height)

## Замах — один слід зброї посередині зони удару (довжина — від зброї в руці, D203).
func _on_player_attacked(player: Node, direction: int) -> void:
	var reach: float = player.combat.hitbox.get_node(^"CollisionShape2D").shape.size.x
	var trail: Node2D = SLASH_TRAIL_SCENE.instantiate()
	player.get_parent().add_child(trail)
	trail.global_position = player.global_position + Vector2(reach / 2.0 * direction, -8)
	trail.set_direction(direction)


## Спалах ушкодження — у кожного, хто справді отримав удар (і ворог, і герой).
func _on_damage_received(target: Node, _source: Node, _amount: int) -> void:
	var sprite: CanvasItem = target.get_node(^"Sprite2D")
	sprite.self_modulate = HURT_FLASH
	target.create_tween().tween_property(sprite, ^"self_modulate", Color.WHITE, HURT_FLASH_TIME)


## Влучання героя у ворога: ефект на краю тіла цілі з боку удару. damage_dealt приходить лише
## з реального ушкодження (B60) — промах і удар у невразливого ефекту не дають.
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	var by_hero: bool = source.is_in_group(GameGroups.PLAYER)
	if not ((by_hero or source.is_in_group(&"companions")) and target.is_in_group(GameGroups.ENEMIES)):
		return
	# Важкий — удар із відкиданням: зброя героя (D203) чи компаньйон (D209)
	var heavy: bool = (source.combat.knockback if by_hero else source.knockback) > 0.0
	var side := signf(source.global_position.x - target.global_position.x)
	var body: CollisionShape2D = target.get_node(^"CollisionShape2D")
	var half_width: float = body.shape.get_rect().size.x * target.global_scale.x / 2.0
	var impact: Node2D = HIT_IMPACT_SCENE.instantiate()
	target.get_parent().add_child(impact)
	impact.global_position = body.global_position + Vector2(side * half_width, 0)
	impact.set_direction(-int(side))
	if heavy:
		impact.scale = Vector2.ONE * HEAVY_SCALE
		ServiceLocator.get_time_manager().hitstop(HEAVY_HITSTOP)
		_shake_camera(HEAVY_SHAKE, HEAVY_SHAKE_TIME)


func _shake_camera(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var tween := camera.create_tween()
	var steps := 5
	for i in steps:
		var fade := 1.0 - float(i) / steps
		tween.tween_property(camera, ^"offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade, duration / steps)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, duration / steps)


func _spawn_dust(pos: Vector2, fall_height: float) -> void:
	# Вычисляем интенсивность эффекта на основе высоты падения
	# Нормализуем: MIN_FALL_HEIGHT = минимальный эффект, MAX_FALL_HEIGHT = максимальный эффект
	var intensity = clamp((fall_height - MIN_FALL_HEIGHT) / (MAX_FALL_HEIGHT - MIN_FALL_HEIGHT), 0.0, 1.0)

	# Параметры для реалистичной пыли при приземлении
	var min_amount = 5  # Еще меньше частиц
	var max_amount = 12  # Еще меньше частиц
	var min_velocity = 40.0
	var max_velocity = 120.0
	var min_scale = 3.5  # Еще крупнее частицы
	var max_scale = 7.0  # Еще крупнее частицы

	# Масштабируем параметры в зависимости от интенсивности
	var amount = int(lerp(min_amount, max_amount, intensity))
	var velocity_min = lerp(min_velocity, max_velocity, intensity)
	var velocity_max = lerp(min_velocity * 1.3, max_velocity * 1.3, intensity)
	var scale_min = lerp(min_scale, max_scale, intensity)
	var scale_max = lerp(min_scale * 1.2, max_scale * 1.2, intensity)
	var lifetime = lerp(0.4, 0.8, intensity)

	# Создаем текстуру для частиц пыли (небольшой серый круг)
	var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	# Рисуем серый круг для пыли
	var center = Vector2(3, 3)
	var radius = 2.5
	for x in range(6):
		for y in range(6):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				# Градиент от центра к краю для более мягкого вида
				var alpha = 1.0 - (dist / radius) * 0.3
				image.set_pixel(x, y, Color(0.7, 0.65, 0.6, alpha))

	var texture = ImageTexture.create_from_image(image)

	var p := CPUParticles2D.new()
	p.texture = texture
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = lifetime
	p.speed_scale = 1.0

	# Частицы разлетаются в основном в стороны (горизонтально)
	p.direction = Vector2(0, 0.05)  # Очень немного вниз, в основном горизонтально
	p.spread = 200.0  # Очень широкий разброс в стороны (больше по X, меньше по Y)

	p.initial_velocity_min = velocity_min
	p.initial_velocity_max = velocity_max
	p.gravity = Vector2(0, 100)  # Гравитация вниз для оседания пыли

	# Цвет пыли - коричневато-серый, более реалистичный
	var dust_color = Color(0.75, 0.7, 0.65, lerp(0.5, 0.8, intensity))
	p.color = dust_color
	p.z_index = 200

	# Размер частиц - небольшие для реалистичности
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max

	# Добавляем в текущую сцену
	var scene = get_tree().current_scene
	if not scene:
		return

	# Устанавливаем глобальную позицию правильно
	p.global_position = pos
	scene.add_child(p)

	# Ждем и удаляем
	await get_tree().create_timer(lifetime + 0.1).timeout
	if is_instance_valid(p):
		p.queue_free()

func _spawn_simple_dust_effect(pos: Vector2) -> void:
	"""Простой визуальный эффект пыли с помощью спрайтов"""
	print("✨ VFXHooks: Creating simple dust effect")

	# Создаем несколько простых спрайтов для эффекта пыли
	for i in range(8):
		var sprite = Sprite2D.new()

		# Создаем простую текстуру
		var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.9, 0.85, 0.7, 0.8))
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture

		# Случайная позиция вокруг точки приземления
		var angle = randf() * TAU
		var distance = randf_range(10.0, 30.0)
		sprite.global_position = pos + Vector2(cos(angle), sin(angle)) * distance
		sprite.z_index = 200
		sprite.scale = Vector2(randf_range(0.5, 1.5), randf_range(0.5, 1.5))

		var scene = get_tree().current_scene
		if scene:
			scene.add_child(sprite)

			# Анимация исчезновения
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
			tween.tween_property(sprite, "position", sprite.position + Vector2(randf_range(-20, 20), randf_range(-30, -10)), 0.3)
			tween.tween_callback(sprite.queue_free).set_delay(0.3)

func _on_skill_used(_skill_name: String, pos: Vector2 = Vector2.ZERO) -> void:
	"""Placeholder VFX для skill"""
	var player = GameGroups.get_player()
	if not player:
		return
	var skill_pos = pos if pos != Vector2.ZERO else player.global_position
	_spawn_skill_vfx(skill_pos)

func _spawn_skill_vfx(pos: Vector2) -> void:
	"""Placeholder skill VFX - енергетичний спалах"""
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.4
	particles.speed_scale = 1.5
	particles.direction = Vector2(0, -1)
	particles.spread = 360.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 100)
	particles.color = Color(0.3, 0.7, 1.0, 0.9)  # Синій енергетичний
	particles.position = pos
	particles.z_index = 250
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## VFX для бойових дій босів

## Відтворює VFX для атаки боса
func play_boss_attack_effect(boss: Node, attack_type: String = "normal") -> void:
	if not boss or not is_instance_valid(boss):
		return

	var boss_pos = boss.global_position if boss is Node2D else Vector2.ZERO

	match attack_type:
		"sweep":
			_play_boss_sweep_vfx(boss_pos)
		"charge":
			_play_boss_charge_vfx(boss_pos)
		"quick_strike":
			_play_boss_quick_strike_vfx(boss_pos)
		_:
			_play_boss_normal_attack_vfx(boss_pos)

## VFX для атаки з розмахом боса
func _play_boss_sweep_vfx(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 0.5
	particles.speed_scale = 1.8
	particles.direction = Vector2(0, 0)
	particles.spread = 180.0  # Півколо
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2(0, 60)
	particles.color = Color(1.0, 0.2, 0.1, 0.95)  # Яскраво-червоний
	particles.position = pos
	particles.z_index = 300
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## VFX для зарядки боса
func _play_boss_charge_vfx(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = false
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.4
	particles.speed_scale = 2.5
	particles.direction = Vector2(0, -1)
	particles.spread = 15.0
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 250.0
	particles.gravity = Vector2(0, -10)
	particles.color = Color(0.6, 0.8, 1.0, 0.9)  # Світло-синій
	particles.position = pos
	particles.z_index = 280
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## VFX для швидкого удару міні-боса
func _play_boss_quick_strike_vfx(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.35
	particles.speed_scale = 2.2
	particles.direction = Vector2(0, 0)
	particles.spread = 360.0
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 140.0
	particles.gravity = Vector2(0, 40)
	particles.color = Color(1.0, 0.5, 0.1, 0.9)  # Помаранчевий
	particles.position = pos
	particles.z_index = 270
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## VFX для звичайної атаки боса
func _play_boss_normal_attack_vfx(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.3
	particles.speed_scale = 1.2
	particles.direction = Vector2(0, 0)
	particles.spread = 90.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 50)
	particles.color = Color(0.9, 0.3, 0.1, 0.8)  # Темно-червоний
	particles.position = pos
	particles.z_index = 260
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(particles):
		particles.queue_free()
