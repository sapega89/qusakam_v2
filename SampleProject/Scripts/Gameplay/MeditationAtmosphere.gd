extends Node2D
class_name MeditationAtmosphere

## 🧘 MeditationAtmosphere - Атмосферные эффекты для медитации
## Создает визуальные эффекты (частицы, свет) для атмосферы священного места

@export var enabled: bool = true
@export var particle_intensity: float = 1.0  # Интенсивность частиц (0.0 - 2.0)

var particles: CPUParticles2D
var light: PointLight2D

func _ready() -> void:
	if not enabled:
		return
	
	_create_atmosphere_effects()

func _create_atmosphere_effects() -> void:
	"""Создает атмосферные эффекты для медитации"""
	
	# 1. Частицы духов/энергии (легкие, плавные)
	particles = CPUParticles2D.new()
	particles.name = "MeditationParticles"
	
	# Создаем простую текстуру для частиц (светящаяся точка)
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center = Vector2(4, 4)
	var radius = 3.0
	for x in range(8):
		for y in range(8):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = 1.0 - (dist / radius) * 0.5
				image.set_pixel(x, y, Color(0.9, 0.95, 1.0, alpha))  # Светло-голубой/белый
	
	var texture = ImageTexture.create_from_image(image)
	particles.texture = texture
	
	# Настройки частиц
	particles.emitting = true
	particles.amount = int(30 * particle_intensity)
	particles.lifetime = 3.0
	particles.speed_scale = 0.5  # Медленное движение
	particles.direction = Vector2(0, -1)  # Вверх
	particles.spread = 45.0  # Небольшой разброс
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 20.0
	particles.gravity = Vector2(0, -5)  # Легкая гравитация вверх (антигравитация)
	particles.color = Color(0.85, 0.9, 1.0, 0.6)  # Светло-голубой, полупрозрачный
	particles.z_index = 100
	
	# Размер частиц
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	
	# Плавное появление и исчезновение
	particles.scale_amount_over_velocity = 0.0
	
	add_child(particles)
	
	# 2. Легкое свечение (PointLight2D)
	light = PointLight2D.new()
	light.name = "MeditationLight"
	# Пытаемся загрузить текстуру света, если не найдена - используем null (стандартная текстура)
	if ResourceLoader.exists("res://addons/MetroidvaniaSystem/Template/Resources/light_texture.png"):
		light.texture = load("res://addons/MetroidvaniaSystem/Template/Resources/light_texture.png")
	else:
		light.texture = null  # Используется стандартная текстура Godot
	light.energy = 0.3  # Мягкое свечение
	light.color = Color(0.9, 0.95, 1.0, 0.5)  # Светло-голубой
	light.texture_scale = 2.0
	light.shadow_enabled = false
	light.z_index = 50
	
	add_child(light)
	
	# Пульсация света для атмосферы
	_start_light_pulse()

func _start_light_pulse() -> void:
	"""Создает пульсацию света для атмосферы"""
	if not light:
		return
	
	var tween = create_tween()
	tween.set_loops()  # Бесконечный цикл
	tween.tween_property(light, "energy", 0.5, 2.0)
	tween.tween_property(light, "energy", 0.3, 2.0)

func set_enabled(value: bool) -> void:
	"""Включает/выключает атмосферные эффекты"""
	enabled = value
	if particles:
		particles.emitting = enabled
	if light:
		light.enabled = enabled

func _exit_tree() -> void:
	"""Очистка при удалении"""
	if particles:
		particles.queue_free()
	if light:
		light.queue_free()
