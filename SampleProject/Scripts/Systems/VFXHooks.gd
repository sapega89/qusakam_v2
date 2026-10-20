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

## Бойові ефекти (6a): ефект влучання в точці контакту, спалах ушкодження (шлейф замаху — WeaponView, D224).
## Кожне влучання — коротке завмирання (D224); важкий удар (відкидання, D203) — довше, більший ефект і тремтіння камери.
const HIT_IMPACT_SCENE := preload("res://SampleProject/Scenes/FX/HitImpact.tscn")
const HURT_FLASH := Color(2.4, 2.4, 2.4)  # self_modulate > 1 — спрайт висвітлюється
const HURT_FLASH_TIME := 0.08
const HEAVY_SCALE := 1.6
const HIT_HITSTOP := 0.035
const HEAVY_HITSTOP := 0.07
const HEAVY_SHAKE := 5.0
const HEAVY_SHAKE_TIME := 0.15
## Звуки бою (D217) з CC0-паків Kenney (SampleProject/Assets/Audio/SFX, README там): на кожну подію кілька варіантів, грає випадковий.
const SFX_SWING := ["res://SampleProject/Assets/Audio/SFX/knifeSlice.ogg", "res://SampleProject/Assets/Audio/SFX/knifeSlice2.ogg"]
const SFX_WINDUP := ["res://SampleProject/Assets/Audio/SFX/drawKnife1.ogg", "res://SampleProject/Assets/Audio/SFX/drawKnife2.ogg", "res://SampleProject/Assets/Audio/SFX/drawKnife3.ogg"]
const SFX_HIT := ["res://SampleProject/Assets/Audio/SFX/impactPunch_medium_000.ogg", "res://SampleProject/Assets/Audio/SFX/impactPunch_medium_001.ogg", "res://SampleProject/Assets/Audio/SFX/impactPunch_medium_002.ogg"]
const SFX_HEAVY_HIT := ["res://SampleProject/Assets/Audio/SFX/impactPunch_heavy_000.ogg", "res://SampleProject/Assets/Audio/SFX/impactPunch_heavy_001.ogg", "res://SampleProject/Assets/Audio/SFX/impactPunch_heavy_002.ogg"]
const SFX_HURT := ["res://SampleProject/Assets/Audio/SFX/impactSoft_heavy_000.ogg", "res://SampleProject/Assets/Audio/SFX/impactSoft_heavy_001.ogg", "res://SampleProject/Assets/Audio/SFX/impactSoft_heavy_002.ogg"]

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
	EventBus.attack_started.connect(_on_attack_started)
	EventBus.skill_used.connect(_on_skill_used)


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

## Звук замаху (шлейф малює WeaponView — він знає зброю й вид удару, D224).
func _on_player_attacked(_player: Node, _direction: int) -> void:
	AudioManager.play_sfx_path(SFX_SWING.pick_random())


## Замах ворога чути: половина підказки «зараз ударить» (D215).
func _on_attack_started(attacker: Node, _target: Node) -> void:
	if attacker.is_in_group(GameGroups.ENEMIES):
		AudioManager.play_sfx_path(SFX_WINDUP.pick_random())


## Спалах ушкодження — у кожного, хто справді отримав удар (і ворог, і герой).
func _on_damage_received(target: Node, _source: Node, _amount: int) -> void:
	var sprite: CanvasItem = target.get_node(^"Sprite2D")
	sprite.self_modulate = HURT_FLASH
	target.create_tween().tween_property(sprite, ^"self_modulate", Color.WHITE, HURT_FLASH_TIME)
	if target.is_in_group(GameGroups.PLAYER):
		AudioManager.play_sfx_path(SFX_HURT.pick_random())


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
	AudioManager.play_sfx_path((SFX_HEAVY_HIT if heavy else SFX_HIT).pick_random())
	ServiceLocator.get_time_manager().hitstop(HEAVY_HITSTOP if heavy else HIT_HITSTOP)
	if heavy:
		impact.scale = Vector2.ONE * HEAVY_SCALE
		_shake_camera(HEAVY_SHAKE, HEAVY_SHAKE_TIME)


func _shake_camera(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var tween := camera.create_tween()
	var steps := 5
	for i in steps:
		var fade := 1.0 - float(i) / steps
		tween.tween_property(camera, ^"offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade, duration / steps)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, duration / steps)


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
