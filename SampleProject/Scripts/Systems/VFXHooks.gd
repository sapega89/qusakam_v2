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
const HIT_IMPACT_SCENE := preload("res://SampleProject/Scenes/FX/HitImpact.tscn")
## Іскри парирування / блоку (D264): скриптові частинки між героєм і ворогом; блок — дрібніші.
const PARRY_SPARK_SCENE := preload("res://SampleProject/Scenes/FX/ParrySpark.tscn")
const HURT_VIGNETTE_SCENE := preload("res://SampleProject/Scenes/FX/HurtVignette.tscn")
const InputGlyphs := preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const BLOCK_SPARK_SCALE := 0.5
## Розтин по героєві — червонуватий, щоб не плутати з його власними ударами.
const HERO_CUT_TINT := Color(1.0, 0.45, 0.4)

## Відчуття удару (4b; Sapega «мало відчуття удару», «і відчуття, що тебе вдарили»). Лише справжнє влучання —
## промах нічого не дає. Без спалахів екрана й круглих вибухів (D268).
## hitstop — завмирання, с; kick — поштовх камери в бік удару, px; cut — розмір розтину (D273); flinch — на скільки
## px здригається тіло ворога; rumble — вібрація геймпада (слабкий мотор, сильний, с).
## Удар героя: 0 легкий, 1 фінішер серії / зброя з відкиданням, 2 важкий.
const HIT_FEEL: Array[Dictionary] = [
	{hitstop = 0.055, kick = 1.5, cut = 1.0, flinch = 3.0, rumble = Vector3(0.3, 0.0, 0.08)},
	{hitstop = 0.08, kick = 3.0, cut = 1.25, flinch = 5.0, rumble = Vector3(0.45, 0.3, 0.12)},
	{hitstop = 0.11, kick = 5.0, cut = 1.5, flinch = 7.0, rumble = Vector3(0.6, 0.7, 0.18)},
]
## Удар по героєві: 0 звичайний, 1 важкий (tank, фінішер серії, бос — is_big_hurt). vignette — сила червоних країв,
## fade — за скільки вони гаснуть.
const HURT_FEEL: Array[Dictionary] = [
	{hitstop = 0.09, kick = 4.0, cut = 1.3, vignette = 0.6, fade = 0.4, rumble = Vector3(0.6, 0.8, 0.22)},
	{hitstop = 0.14, kick = 7.0, cut = 1.6, vignette = 1.0, fade = 0.6, rumble = Vector3(1.0, 1.0, 0.35)},
]
const PARRY_HITSTOP := 0.07
## Група стріл героя (Arrow.HERO_ARROWS): ім'я тут, а не клас — цей скрипт вантажиться раніше за class_name-класи.
const HERO_ARROWS := &"hero_arrows"
const PARRY_KICK := 5.0
const KICK_TIME := 0.16

var hurt_vignette: CanvasLayer


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
	hurt_vignette = HURT_VIGNETTE_SCENE.instantiate()
	add_child(hurt_vignette)


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

## Удар по героєві (4b): розтин з боку удару (D268) — більший, завмирання довше, ніж від його власних ударів,
## поштовх камери від ворога, червоні краї екрана, сильна вібрація. Важкий удар (is_big_hurt) — ще сильніше.
## Поза Hurt і відкидання — PlayerCombat.stagger (D264); рядок HP трясеться сам (player_vitals_panel).
func _on_damage_received(target: Node, source: Node, _amount: int, _critical: bool) -> void:
	if not target.is_in_group(GameGroups.PLAYER):
		return
	# Без джерела (пастка, падіння) — розтин по центру тіла
	var side: float = 0.0 if source == null else signf(source.global_position.x - target.global_position.x)
	var feel: Dictionary = HURT_FEEL[1 if is_big_hurt(source) else 0]
	var impact := _spawn_impact(target, side)
	impact.modulate = HERO_CUT_TINT
	impact.scale = Vector2.ONE * feel.cut
	ServiceLocator.get_time_manager().hitstop(feel.hitstop)
	_kick_camera(Vector2(-side, 0.0), feel.kick)
	hurt_vignette.pulse(feel.vignette, feel.fade)
	rumble(feel.rumble)


## Важкий удар по героєві: той, що пробив би блок (tank, фінішер серії, D264), або удар боса.
## Типи PlayerCombat / DefaultEnemy тут не згадуємо: GameManager (autoload) вантажить цей скрипт раніше за ServiceLocator.
static func is_big_hurt(source: Node) -> bool:
	return source != null and source.is_in_group(GameGroups.ENEMIES) and (
			source.hit_stagger_time() >= GameGroups.get_player().combat.GUARD_BREAK
			or source.is_in_group(GameGroups.BOSS) or source.is_in_group(GameGroups.MINIBOSS))


## Розтин влучання на краю тіла [param target] з боку [param side] (-1 / 1, 0 — центр).
func _spawn_impact(target: Node2D, side: float) -> HitImpact:
	var body: CollisionShape2D = target.get_node(^"CollisionShape2D")
	var half_width: float = body.shape.get_rect().size.x * target.global_scale.x / 2.0
	var impact: HitImpact = HIT_IMPACT_SCENE.instantiate()
	target.get_parent().add_child(impact)
	impact.global_position = body.global_position + Vector2(side * half_width, 0)
	impact.set_direction(-int(side))
	return impact


## Влучання героя у ворога (4b): розтин за силою удару, завмирання, поштовх камери в бік удару, здригання ворога,
## вібрація. damage_dealt приходить лише з реального ушкодження (B60) — промах і удар у невразливого нічого не дають.
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if not is_hero_side_hit(source, target):
		return
	var side: float = signf(source.global_position.x - target.global_position.x)
	var feel: Dictionary = HIT_FEEL[hit_strength(source)]
	_spawn_impact(target, side).scale = Vector2.ONE * feel.cut
	ServiceLocator.get_time_manager().hitstop(feel.hitstop)
	_kick_camera(Vector2(-side, 0.0), feel.kick)
	target.enemy_view.flinch(side, feel.flinch)
	if source.is_in_group(GameGroups.PLAYER) or source.is_in_group(HERO_ARROWS):
		rumble(feel.rumble)


## Сила удару: 2 — важкий удар героя, 1 — удар із відкиданням (фінішер серії, булава D203, компаньйон D209), 0 — легкий.
## Стріла героя (D381) несе свою: швидка 0, заряджена 2.
static func hit_strength(source: Node) -> int:
	if source.is_in_group(HERO_ARROWS):
		return source.strength
	if source.is_in_group(GameGroups.PLAYER) and source.combat.state == source.combat.State.HEAVY_STRIKE:
		return 2
	return 1 if is_heavy_hit(source) else 0


## Вібрація геймпада, якщо грають на ньому (останній ввід — кнопка чи стік, D289): x — слабкий мотор, y — сильний, z — с.
static func rumble(v: Vector3) -> void:
	if InputGlyphs.using_gamepad:
		Input.start_joy_vibration(InputGlyphs.pad_device, v.x, v.y, v.z)


## Герой, його стріла (D381) чи компаньйон влучив у ворога (ефект і звук влучання — SoundHooks теж питає тут).
static func is_hero_side_hit(source: Node, target: Node) -> bool:
	return (source.is_in_group(GameGroups.PLAYER) or source.is_in_group(HERO_ARROWS) or source.is_in_group(&"companions")) and target.is_in_group(GameGroups.ENEMIES)


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
		ServiceLocator.get_time_manager().hitstop(PARRY_HITSTOP)
		_kick_camera(Vector2(signf(attacker.global_position.x - hero.global_position.x), 0.0), PARRY_KICK)
		rumble(HIT_FEEL[2].rumble)


## Поштовх камери в бік [param dir] на [param strength] px і згасання туди-сюди за KICK_TIME (реальних с — грає й
## під час завмирання, тож удар читається одразу).
func _kick_camera(dir: Vector2, strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var tween := camera.create_tween().set_ignore_time_scale()
	var step := KICK_TIME / 4.0
	tween.tween_property(camera, ^"offset", dir * strength, step * 0.5)
	tween.tween_property(camera, ^"offset", -dir * strength * 0.5, step)
	tween.tween_property(camera, ^"offset", dir * strength * 0.25, step)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, step * 1.5)


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
