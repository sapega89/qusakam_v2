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

var attack_effect_cooldown: float = 0.0
const ATTACK_EFFECT_COOLDOWN_TIME: float = 0.1  # Минимальное время между эффектами атаки
var active_attack_effects: Array[Node] = []  # Список активных эффектов атаки

const ATTACK_FRAME_COUNT: int = 8

## Кеш кадрів ефекту атаки: напрямок (1/-1) -> SpriteFrames.
## Текстури залежать ЛИШЕ від номера кадру (фаза хвилі) і напрямку, але раніше
## будувались наново на КОЖЕН удар: 8 текстур 128x32, малюються попіксельно через
## set_pixel (~230k операцій), плюс стільки ж на _flip_texture при ударі вліво.
## Фризу ніхто не бачив тільки тому, що player_attacked не емітився взагалі —
## PlayerCombat перевіряв Engine.has_singleton("EventBus"), а той для autoload'а
## завжди false. Після виправлення сигналу кеш став обовʼязковим.
var _attack_frames_cache: Dictionary = {}

func _init() -> void:
	print("🔧 VFXHooks: _init() called - VFXHooks instance created!")

func _process(delta: float) -> void:
	if landing_cooldown > 0:
		landing_cooldown -= delta
	if attack_effect_cooldown > 0:
		attack_effect_cooldown -= delta
	
	# Удаляем недействительные эффекты из списка
	active_attack_effects = active_attack_effects.filter(func(effect): return is_instance_valid(effect))

func _ready() -> void:
	print("🔧 VFXHooks: _ready() called, enabled = ", enabled)
	if not enabled:
		print("⚠️ VFXHooks: Disabled")
		return
	
	# Используем call_deferred для подключения после полной инициализации
	call_deferred("_connect_to_event_bus")

func _connect_to_event_bus() -> void:
	print("🔧 VFXHooks: _connect_to_event_bus() called")
	
	# EventBus зарегистрирован как autoload через сцену, доступен напрямую
	# Ждем несколько кадров, чтобы EventBus точно инициализировался
	for i in range(5):
		await get_tree().process_frame
	
	# Пытаемся получить EventBus через прямой доступ
	var event_bus = null
	if has_node("/root/EventBus"):
		event_bus = get_node("/root/EventBus")
		print("✅ VFXHooks: EventBus found via /root/EventBus")
	else:
		# Пробуем прямой доступ (autoload доступен как глобальная переменная)
		# В Godot 4 autoload доступен напрямую по имени
		event_bus = EventBus
		if event_bus:
			print("✅ VFXHooks: EventBus found via direct access")
	
	if not event_bus:
		print("❌ VFXHooks: EventBus not found!")
		return
	
	print("✨ VFXHooks: Connecting to EventBus signals...")
	
	# Подключаемся к сигналам
	if event_bus.has_signal("player_landed"):
		event_bus.player_landed.connect(_on_player_landed)
		print("✅ VFXHooks: Connected to player_landed signal")
	else:
		print("❌ VFXHooks: player_landed signal not found in EventBus!")
	
	if event_bus.has_signal("damage_received"):
		event_bus.damage_received.connect(_on_damage_received)
		print("✅ VFXHooks: Connected to damage_received signal")
	
	if event_bus.has_signal("damage_dealt"):
		event_bus.damage_dealt.connect(_on_damage_dealt)
		print("✅ VFXHooks: Connected to damage_dealt signal")
	
	if event_bus.has_signal("player_attacked"):
		event_bus.player_attacked.connect(_on_player_attacked)
		print("✅ VFXHooks: Connected to player_attacked signal")
	
	# Skill VFX (якщо є сигнал skill_used)
	if event_bus.has_signal("skill_used"):
		event_bus.skill_used.connect(_on_skill_used)
		print("✅ VFXHooks: Connected to skill_used signal")

	# Прогріваємо кеш кадрів удару зараз, поки сцена ще вантажиться. Інакше перший
	# у грі удар оплатив би генерацію текстур сам — єдиним, але помітним фризом.
	_get_attack_sprite_frames(1)
	_get_attack_sprite_frames(-1)

## ============================================
## ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ГЕНЕРАЦИИ ЭФФЕКТОВ
## ============================================

func _draw_green_pixel_with_glow(image: Image, x: int, y: int, _center_y: float, dist: float, max_dist: float, intensity: float = 1.0) -> void:
	"""Рисует зеленый пиксель с голубым свечением"""
	if dist <= max_dist:
		# Яркий зеленый центр
		if dist <= max_dist * 0.4:
			var pixel_intensity = 1.0 - (dist / (max_dist * 0.4)) * 0.2
			image.set_pixel(x, y, Color(0.2, 1.0, 0.3, clamp(pixel_intensity * intensity, 0.0, 1.0)))
		# Внешнее свечение (зеленое)
		else:
			var alpha = (1.0 - dist / max_dist) * 0.7 * intensity
			image.set_pixel(x, y, Color(0.15, 0.9, 0.25, clamp(alpha, 0.0, 1.0)))
	
	# Голубое свечение вокруг
	if dist <= max_dist + 1.5:
		var glow_alpha = (1.0 - dist / (max_dist + 1.5)) * 0.3 * intensity
		var existing = image.get_pixel(x, y)
		if existing.a < glow_alpha:
			image.set_pixel(x, y, Color(0.3, 0.7, 1.0, clamp(glow_alpha, 0.0, 1.0)))

func _draw_center_line(image: Image, x: int, center_y: float, height: int, intensity: float = 1.0) -> void:
	"""Рисует яркую центральную линию с голубым свечением"""
	for y in range(height):
		var dist = abs(y - center_y)
		if dist <= 1.0:
			var pixel_intensity = 1.0 - dist * 0.3
			image.set_pixel(x, y, Color(0.2, 1.0, 0.3, clamp(pixel_intensity * intensity, 0.0, 1.0)))
		elif dist <= 2.5:
			var glow_alpha = (1.0 - (dist - 1.0) / 1.5) * 0.25 * intensity
			var existing = image.get_pixel(x, y)
			if existing.a < glow_alpha:
				image.set_pixel(x, y, Color(0.3, 0.7, 1.0, clamp(glow_alpha, 0.0, 1.0)))

func _draw_triangular_peak(image: Image, x: int, peak_center: float, height: int, peak_size: float, peak_alpha: float, glow_size: float, glow_alpha: float) -> void:
	"""Рисует треугольный пик с голубым свечением"""
	if peak_center < 0 or peak_center >= height:
		return
	
	for y in range(height):
		var dist = abs(y - peak_center)
		if dist <= peak_size:
			var alpha = peak_alpha - (dist / peak_size) * (peak_alpha * 0.5)
			if alpha > 0.1:
				image.set_pixel(x, y, Color(0.3, 1.0, 0.4, clamp(alpha, 0.0, 1.0)))
		elif dist <= peak_size + glow_size:
			var glow = (1.0 - (dist - peak_size) / glow_size) * glow_alpha
			var existing = image.get_pixel(x, y)
			if existing.a < glow:
				image.set_pixel(x, y, Color(0.3, 0.7, 1.0, clamp(glow, 0.0, 1.0)))

func _draw_tail(image: Image, x: int, center_y: float, height: int, tail_progress: float) -> void:
	"""Рисует затухающий хвост эффекта"""
	for y in range(height):
		var dist = abs(y - center_y)
		if dist <= 1.0:
			var alpha = (1.0 - tail_progress) * 0.5
			image.set_pixel(x, y, Color(0.2, 1.0, 0.3, clamp(alpha, 0.0, 1.0)))
		elif dist <= 2.5:
			var glow_alpha = (1.0 - tail_progress) * 0.2 * (1.0 - (dist - 1.0) / 1.5)
			var existing = image.get_pixel(x, y)
			if existing.a < glow_alpha:
				image.set_pixel(x, y, Color(0.3, 0.7, 1.0, clamp(glow_alpha, 0.0, 1.0)))

func _draw_energy_tip(image: Image, x: int, center_y: float, height: int, tip_progress: float, tip_start_width: float, tip_end_width: float) -> void:
	"""Рисует острый наконечник энергетического эффекта"""
	var tip_width = lerp(tip_start_width, tip_end_width, tip_progress)
	for y in range(height):
		var dist = abs(y - center_y)
		_draw_green_pixel_with_glow(image, x, y, center_y, dist, tip_width, 1.0)

func _draw_animated_peaks(image: Image, x: int, center_y: float, height: int, phase_offset: float) -> void:
	"""Рисует анимированные треугольные пики с разными частотами"""
	# Пик 1 - быстрая частота, малая амплитуда
	var triangle1 = abs(fmod(x * 0.25 + phase_offset * 2.0, 8.0) - 4.0) - 2.0
	var peak1_height = abs(triangle1) * 2.5
	_draw_triangular_peak(image, x, center_y - peak1_height, height, 1.5, 0.9, 1.5, 0.2)
	_draw_triangular_peak(image, x, center_y + peak1_height, height, 1.5, 0.9, 1.5, 0.2)
	
	# Пик 2 - средняя частота, средняя амплитуда
	var triangle2 = abs(fmod(x * 0.15 + 2.0 + phase_offset * 1.5, 12.0) - 6.0) - 3.0
	var peak2_height = abs(triangle2) * 3.5
	_draw_triangular_peak(image, x, center_y - peak2_height, height, 1.2, 0.7, 1.6, 0.18)
	_draw_triangular_peak(image, x, center_y + peak2_height, height, 1.2, 0.7, 1.6, 0.18)
	
	# Пик 3 - медленная частота, большая амплитуда
	var triangle3 = abs(fmod(x * 0.08 + 4.0 + phase_offset * 1.0, 20.0) - 10.0) - 5.0
	var peak3_height = abs(triangle3) * 4.5
	_draw_triangular_peak(image, x, center_y - peak3_height, height, 1.0, 0.6, 1.5, 0.15)
	_draw_triangular_peak(image, x, center_y + peak3_height, height, 1.0, 0.6, 1.5, 0.15)

func _flip_texture(texture: Texture2D) -> Texture2D:
	"""Отзеркаливает текстуру по горизонтали"""
	if texture is ImageTexture:
		var img = texture.get_image()
		if img:
			var flipped_img = Image.create(img.get_width(), img.get_height(), false, img.get_format())
			for x in range(img.get_width()):
				for y in range(img.get_height()):
					flipped_img.set_pixel(x, y, img.get_pixel(img.get_width() - 1 - x, y))
			var flipped_texture = ImageTexture.create_from_image(flipped_img)
			flipped_texture.update(flipped_img)
			return flipped_texture
	return texture

func _create_energy_wave_texture(width: int, height: int, center_y: float, phase_offset: float = 0.0, tip_start: float = 0.15, tip_end: float = 0.85) -> ImageTexture:
	"""Создает текстуру энергетической волны с треугольными пиками
	
	Args:
		width: Ширина текстуры
		height: Высота текстуры
		center_y: Центр по Y
		phase_offset: Смещение фазы для анимации
		tip_start: Начало наконечника (0.0-1.0)
		tip_end: Конец основной части (0.0-1.0)
	"""
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(width):
		var progress = float(x) / float(width)
		
		# Острый наконечник
		if progress < tip_start:
			var tip_progress = progress / tip_start
			_draw_energy_tip(image, x, center_y, height, tip_progress, 6.0, 1.0)
		
		# Основная часть - треугольные пики
		elif progress >= tip_start and progress < tip_end:
			_draw_center_line(image, x, center_y, height, 1.0)
			_draw_animated_peaks(image, x, center_y, height, phase_offset)
		
		# Хвост - затухание
		else:
			var tail_progress = (progress - tip_end) / (1.0 - tip_end)
			_draw_tail(image, x, center_y, height, tail_progress)
	
	var texture = ImageTexture.create_from_image(image)
	texture.update(image)
	return texture

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

func _on_damage_received(target: Node, source: Node, _amount: int) -> void:
	if not target or not source:
		return
	# Only show slash when player hits an enemy
	if source.is_in_group(GameGroups.PLAYER) and target.is_in_group(GameGroups.ENEMIES):
		_spawn_slash(target.global_position)

func _on_player_attacked(player: Node, direction: int) -> void:
	"""Обработчик сигнала player_attacked - когда игрок начинает атаку"""
	if not player or not is_instance_valid(player):
		return
	
	# Проверяем кулдаун, чтобы не создавать эффекты слишком часто
	if attack_effect_cooldown > 0:
		return
	
	# Получаем направление напрямую из персонажа - используем velocity.x для точности
	var player_direction: int = direction  # По умолчанию используем переданное направление
	
	# Пытаемся получить направление из velocity персонажа (самое точное)
	if "velocity" in player and player.velocity is Vector2:
		var vel = player.velocity as Vector2
		if absf(vel.x) > 1:
			# Если персонаж движется - используем направление движения
			player_direction = sign(vel.x)
		elif "last_direction" in player:
			# Если стоит - используем последнее направление
			player_direction = player.last_direction
	elif "last_direction" in player:
		# Если velocity недоступен - используем last_direction
		player_direction = player.last_direction
	
	# Создаем VFX эффект атаки (стремительный удар копьем) на кончике оружия
	var attack_pos: Vector2
	if player is Node2D:
		# Позиция эффекта - дальше впереди игрока в направлении атаки (кончик копья)
		# Увеличиваем смещение для более заметного эффекта
		var offset = Vector2(40, -8) if player_direction > 0 else Vector2(-40, -8)
		attack_pos = player.global_position + offset
	else:
		return
	
	# Устанавливаем кулдаун
	attack_effect_cooldown = ATTACK_EFFECT_COOLDOWN_TIME
	
	# Создаем эффект стремительного удара копьем с точным направлением движения персонажа
	_spawn_attack_effect(attack_pos, player_direction)

func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	"""Обработчик сигнала damage_dealt - когда игрок наносит урон врагу"""
	if not target or not source:
		return
	
	# Показываем эффект удара только когда игрок бьет врага
	if source.is_in_group(GameGroups.PLAYER) and target.is_in_group(GameGroups.ENEMIES):
		var hit_pos: Vector2
		if target is Node2D:
			hit_pos = target.global_position
		else:
			return
		
		# Создаем эффект удара (искры/вспышка)
		_spawn_hit_effect(hit_pos)

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

func _spawn_slash(pos: Vector2) -> void:
	# Cheap placeholder slash: a quick polygon flash
	var poly := Polygon2D.new()
	poly.color = Color(1.0, 1.0, 1.0, 0.9)
	poly.z_index = 300
	poly.position = pos
	poly.polygon = PackedVector2Array([
		Vector2(-18, -4),
		Vector2(18, -10),
		Vector2(10, 6),
		Vector2(-10, 10),
	])
	get_tree().current_scene.add_child(poly)
	var t := get_tree().create_timer(0.08)
	await t.timeout
	if is_instance_valid(poly):
		poly.queue_free()

func _get_attack_sprite_frames(direction: int) -> SpriteFrames:
	"""Повертає (і за потреби будує) кадри ефекту атаки для напрямку"""
	var key: int = -1 if direction < 0 else 1
	if _attack_frames_cache.has(key):
		return _attack_frames_cache[key]

	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("attack_effect")
	sprite_frames.set_animation_speed("attack_effect", 12.0)  # 12 кадров в секунду
	sprite_frames.set_animation_loop("attack_effect", true)

	for frame_num in ATTACK_FRAME_COUNT:
		var phase_offset := float(frame_num) / float(ATTACK_FRAME_COUNT) * TAU
		var texture: Texture2D = _create_energy_wave_texture(128, 32, 15.5, phase_offset)
		if key < 0:
			texture = _flip_texture(texture)
		# duration в секундах, 1/12 для 12 FPS
		sprite_frames.add_frame("attack_effect", texture, 1.0 / 12.0)

	_attack_frames_cache[key] = sprite_frames
	return sprite_frames

func _spawn_attack_effect(pos: Vector2, direction: int) -> void:
	"""Создает эффект стремительного удара копьем - энергетический след с анимацией"""
	# Используем AnimatedSprite2D для анимации.
	# SpriteFrames — ресурс, спільний для всіх ударів у цьому напрямку (див. кеш).
	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.sprite_frames = _get_attack_sprite_frames(direction)
	animated_sprite.play("attack_effect")
	animated_sprite.z_index = 300
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	animated_sprite.scale = Vector2(1.5, 1.5)
	
	# Добавляем пульсацию свечения (ограниченное количество циклов)
	var tween_glow = create_tween()
	tween_glow.set_loops(5)  # 5 циклов за время жизни эффекта (~1 секунда)
	tween_glow.tween_property(animated_sprite, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.3)
	tween_glow.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	
	# Добавляем в список активных эффектов
	active_attack_effects.append(animated_sprite)
	
	var scene = get_tree().current_scene
	if not scene:
		return
	
	# Позиция эффекта
	animated_sprite.global_position = pos
	scene.add_child(animated_sprite)
	
	# Анимация движения вперед
	var target_pos = pos + Vector2(250.0 * direction, 0)
	var tween_move = create_tween()
	tween_move.set_parallel(true)
	tween_move.tween_property(animated_sprite, "global_position", target_pos, 1.0)
	tween_move.tween_property(animated_sprite, "modulate:a", 0.0, 1.0)  # Затухание
	
	# Ждем завершения движения
	await get_tree().create_timer(1.0).timeout
	
	# Создаем эффект волн, разлетающихся в разные стороны
	if is_instance_valid(animated_sprite):
		_spawn_energy_waves(target_pos)
	
	# Удаляем анимированный спрайт
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(animated_sprite):
		active_attack_effects.erase(animated_sprite)
		animated_sprite.queue_free()

func _spawn_energy_waves(pos: Vector2) -> void:
	"""Создает эффект волн энергии, разлетающихся в разные стороны"""
	var scene = get_tree().current_scene
	if not scene:
		return
	
	# Создаем контейнер для всех эффектов волн
	var waves_container = Node2D.new()
	waves_container.global_position = pos
	waves_container.z_index = 350
	scene.add_child(waves_container)
	
	# Количество волн в разных направлениях
	var wave_count = 8
	var wave_duration = 0.6
	
	# Создаем волны, расходящиеся в разные стороны
	for i in range(wave_count):
		var angle = (TAU / wave_count) * i
		var direction = Vector2(cos(angle), sin(angle))
		
		# Создаем текстуру волны используя переиспользуемый метод
		var wave_texture = _create_energy_wave_texture(64, 16, 7.5, 0.0, 0.2, 0.8)
		
		# Создаем спрайт для волны
		var wave_sprite = Sprite2D.new()
		wave_sprite.texture = wave_texture
		wave_sprite.z_index = 351
		wave_sprite.scale = Vector2(1.5, 1.5)
		wave_sprite.rotation = angle  # Поворачиваем в направлении движения
		waves_container.add_child(wave_sprite)
		
		# Анимация волны - разлетается от центра
		var wave_distance = 150.0
		var target_pos = direction * wave_distance
		var wave_tween = create_tween()
		wave_tween.set_parallel(true)
		wave_tween.tween_property(wave_sprite, "position", target_pos, wave_duration)
		wave_tween.tween_property(wave_sprite, "modulate:a", 0.0, wave_duration)
		wave_tween.tween_property(wave_sprite, "scale", Vector2(2.5, 2.5), wave_duration)  # Увеличивается при удалении
	
	# Удаляем контейнер после завершения эффекта
	await get_tree().create_timer(wave_duration + 0.1).timeout
	if is_instance_valid(waves_container):
		waves_container.queue_free()

func _spawn_hit_effect(pos: Vector2) -> void:
	"""Создает эффект удара - искры и вспышка при попадании"""
	# Создаем текстуру для искр (маленький желтый/оранжевый круг)
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(2, 2)
	var radius = 1.5
	for x in range(4):
		for y in range(4):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, Color(1.0, 0.8, 0.3, 0.9))  # Желто-оранжевый
	
	var texture = ImageTexture.create_from_image(image)
	
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 15
	particles.lifetime = 0.3
	particles.speed_scale = 1.0
	particles.direction = Vector2(0, 0)  # Разлетаются во все стороны
	particles.spread = 360.0  # Полный круг
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 50)  # Легкая гравитация
	particles.color = Color(1.0, 0.7, 0.2, 0.9)  # Оранжево-желтый
	particles.z_index = 300
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	
	var scene = get_tree().current_scene
	if not scene:
		return
	
	particles.global_position = pos
	scene.add_child(particles)
	
	# Ждем и удаляем
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(particles):
		particles.queue_free()

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

## VFX для компаньйонів

## Відтворює VFX для лікування
func play_heal_effect(target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var target_pos = target.global_position if target is Node2D else Vector2.ZERO
	_spawn_heal_particles(target_pos)

## Відтворює VFX для щита
func play_shield_effect(target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var target_pos = target.global_position if target is Node2D else Vector2.ZERO
	_spawn_shield_particles(target_pos)

## Відтворює VFX для вогню
func play_fire_effect(target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var target_pos = target.global_position if target is Node2D else Vector2.ZERO
	_spawn_fire_particles(target_pos)

## Створює частинки для лікування
func _spawn_heal_particles(pos: Vector2) -> void:
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
	particles.gravity = Vector2(0, -50)  # Вгору
	particles.color = Color(0.2, 1.0, 0.3, 0.9)  # Зелений
	particles.position = pos
	particles.z_index = 250
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Створює частинки для щита
func _spawn_shield_particles(pos: Vector2) -> void:
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
	particles.gravity = Vector2(0, -20)  # Легко вгору
	particles.color = Color(0.3, 0.6, 1.0, 0.8)  # Синій
	particles.position = pos
	particles.z_index = 250
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Створює частинки для вогню
func _spawn_fire_particles(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 35
	particles.lifetime = 0.5
	particles.speed_scale = 1.5
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2(0, 100)
	particles.color = Color(1.0, 0.4, 0.1, 0.9)  # Помаранчево-червоний
	particles.position = pos
	particles.z_index = 250
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(0.6).timeout
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
