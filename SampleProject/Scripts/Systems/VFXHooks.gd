extends Node
class_name VFXHooks

## Minimal VFX hooks for MVP:
## - Dust puff on landing (LandingDust.tscn)
## - Slash pop on hit (placeholder)

@export var enabled: bool = true

var landing_cooldown: float = 0.0
const LANDING_COOLDOWN_TIME: float = 0.5  # Минимальное время между эффектами приземления
const MIN_FALL_HEIGHT: float = 20.0  # Минимальная высота падения для показа эффекта (в пикселях)
const LANDING_DUST_SCENE := preload("res://SampleProject/Scenes/FX/LandingDust.tscn")

## Бойові ефекти (6a): розтин влучання в точці контакту (шлейф замаху — WeaponView, D224; без спалахів, D268).
## Кожне влучання — коротке завмирання (D224); важкий удар (відкидання, D203) — довше, більший ефект і тремтіння камери.
const HIT_IMPACT_SCENE := preload("res://SampleProject/Scenes/FX/HitImpact.tscn")
## Іскри парирування / блоку (D264): скриптові частинки між героєм і ворогом; блок — дрібніші.
const PARRY_SPARK_SCENE := preload("res://SampleProject/Scenes/FX/ParrySpark.tscn")
const BLOCK_SPARK_SCALE := 0.5
const HEAVY_SCALE := 1.3
## Розтин по героєві — червонуватий, щоб не плутати з його власними ударами.
const HERO_CUT_TINT := Color(1.0, 0.45, 0.4)
const HIT_HITSTOP := 0.035
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
	EventBus.player_parried.connect(_on_guard.bind(true))
	EventBus.player_blocked.connect(_on_guard.bind(false))


## ============================================
## ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ГЕНЕРАЦИИ ЭФФЕКТОВ
## ============================================

func _on_player_landed(fall_height: float) -> void:
	if landing_cooldown > 0 or fall_height < MIN_FALL_HEIGHT:
		return
	landing_cooldown = LANDING_COOLDOWN_TIME
	# Пил під ногами (feedback 20, Ender Lilies): кілька дрібних клаптів в обидва боки, ~0.3 с, розмітка — LandingDust.tscn
	var dust: CPUParticles2D = LANDING_DUST_SCENE.instantiate()
	dust.finished.connect(dust.queue_free)
	get_tree().current_scene.add_child(dust)
	dust.global_position += GameGroups.get_player().global_position  # зсув до ніг — у сцені
	dust.emitting = true
	dust.get_node(^"Left").emitting = true

## Удар по героєві: розтин з боку удару (D268, Sapega 2026-10-21: без спалахів — розтин, завмирання, відкидання).
func _on_damage_received(target: Node, source: Node, _amount: int) -> void:
	if target.is_in_group(GameGroups.PLAYER):
		# Без джерела (пастка, падіння) — розтин по центру тіла
		var side: float = 0.0 if source == null else signf(source.global_position.x - target.global_position.x)
		_spawn_impact(target, side).modulate = HERO_CUT_TINT


## Розтин влучання на краю тіла [param target] з боку [param side] (-1 / 1, 0 — центр).
func _spawn_impact(target: Node2D, side: float) -> HitImpact:
	var body: CollisionShape2D = target.get_node(^"CollisionShape2D")
	var half_width: float = body.shape.get_rect().size.x * target.global_scale.x / 2.0
	var impact: HitImpact = HIT_IMPACT_SCENE.instantiate()
	target.get_parent().add_child(impact)
	impact.global_position = body.global_position + Vector2(side * half_width, 0)
	impact.set_direction(-int(side))
	return impact


## Влучання героя у ворога: ефект на краю тіла цілі з боку удару. damage_dealt приходить лише
## з реального ушкодження (B60) — промах і удар у невразливого ефекту не дають.
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if not is_hero_side_hit(source, target):
		return
	var heavy := is_heavy_hit(source)
	var impact := _spawn_impact(target, signf(source.global_position.x - target.global_position.x))
	ServiceLocator.get_time_manager().hitstop(HEAVY_HITSTOP if heavy else HIT_HITSTOP)
	if heavy:
		impact.scale = Vector2.ONE * HEAVY_SCALE
		_shake_camera(HEAVY_SHAKE, HEAVY_SHAKE_TIME)


## Герой чи компаньйон влучив у ворога (ефект і звук влучання — SoundHooks теж питає тут).
static func is_hero_side_hit(source: Node, target: Node) -> bool:
	return (source.is_in_group(GameGroups.PLAYER) or source.is_in_group(&"companions")) and target.is_in_group(GameGroups.ENEMIES)


## Важкий — удар із відкиданням: зброя героя (D203) чи компаньйон (D209).
static func is_heavy_hit(source: Node) -> bool:
	return (source.combat.knockback if source.is_in_group(GameGroups.PLAYER) else source.knockback) > 0.0


## Парирування: великі іскри, завмирання й тремтіння; блок — дрібні іскри (дзвін — SoundHooks).
func _on_guard(attacker: Node2D, parry: bool) -> void:
	var hero: Node2D = GameGroups.get_player()
	var spark: CPUParticles2D = PARRY_SPARK_SCENE.instantiate()
	spark.finished.connect(spark.queue_free)
	hero.get_parent().add_child(spark)
	spark.global_position = hero.global_position.lerp(attacker.global_position, 0.4)
	spark.scale = Vector2.ONE * (1.0 if parry else BLOCK_SPARK_SCALE)
	spark.emitting = true
	if parry:
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
