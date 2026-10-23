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
## px здригається тіло ворога; rumble — вібрація геймпада (слабкий мотор, сильний, с); shake — тряска камери (px, с;
## 0 — немає, D581: лише важкий удар і рипост героя та кожен удар по ньому).
## Удар героя (hit_strength): 0 легкий, 1 фінішер серії / зброя з відкиданням, 2 важкий, 3 рипост (D575).
## Завмирання росте з силою удару: легкий < важкий < рипост < удар боса по героєві (D581; числа попередні).
const HIT_FEEL: Array[Dictionary] = [
	{hitstop = 0.055, kick = 1.5, cut = 1.0, flinch = 3.0, rumble = Vector3(0.3, 0.0, 0.08), shake = Vector2.ZERO},
	{hitstop = 0.08, kick = 3.0, cut = 1.25, flinch = 5.0, rumble = Vector3(0.45, 0.3, 0.12), shake = Vector2.ZERO},
	{hitstop = 0.11, kick = 5.0, cut = 1.5, flinch = 7.0, rumble = Vector3(0.6, 0.7, 0.18), shake = Vector2(3.0, 0.15)},
	{hitstop = 0.15, kick = 6.0, cut = 1.7, flinch = 9.0, rumble = Vector3(0.8, 0.9, 0.24), shake = Vector2(5.0, 0.2)},
]
## Удар по героєві (hurt_tier): 0 звичайний, 1 важкий (tank, фінішер серії, мінібос — пробив би блок), 2 удар боса.
## vignette — сила червоних країв, fade — за скільки вони гаснуть.
const HURT_FEEL: Array[Dictionary] = [
	{hitstop = 0.09, kick = 4.0, cut = 1.3, vignette = 0.6, fade = 0.4, rumble = Vector3(0.6, 0.8, 0.22), shake = Vector2(3.0, 0.15)},
	{hitstop = 0.14, kick = 7.0, cut = 1.6, vignette = 1.0, fade = 0.6, rumble = Vector3(1.0, 1.0, 0.35), shake = Vector2(5.0, 0.25)},
	{hitstop = 0.18, kick = 8.0, cut = 1.8, vignette = 1.0, fade = 0.7, rumble = Vector3(1.0, 1.0, 0.4), shake = Vector2(7.0, 0.3)},
]
## Білий спалах героя від удару по ньому (D581): параметр flash шейдера кадрів героя (weapon_palette) з 1 до 0
## за HURT_FLASH_TIME реальних с — грає й під час завмирання.
const HURT_FLASH_TIME := 0.12
const PARRY_HITSTOP := 0.07
## Група стріл героя (Arrow.HERO_ARROWS): ім'я тут, а не клас — цей скрипт вантажиться раніше за class_name-класи.
const HERO_ARROWS := &"hero_arrows"
const PARRY_KICK := 5.0
const KICK_TIME := 0.16
## D491: ультимативна навичка трясе камеру на ULTIMATE_SHAKE px протягом ULTIMATE_SHAKE_TIME с.
const ULTIMATE_SHAKE := 9.0
const ULTIMATE_SHAKE_TIME := 0.5

var hurt_vignette: CanvasLayer

## Тряска камери почалась (strength px, seconds с); emitted навіть за Screen Shake Off — тоді камера стоїть.
signal shake_started(strength: float, seconds: float)


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
	EventBus.enemy_shield_blocked.connect(_on_shield.bind(false))
	EventBus.enemy_shield_broken.connect(_on_shield.bind(true))
	EventBus.skill_used.connect(_on_skill_used)
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
	var feel: Dictionary = HURT_FEEL[hurt_tier(source)]
	var impact := _spawn_impact(target, side)
	impact.modulate = HERO_CUT_TINT
	impact.scale = Vector2.ONE * feel.cut
	ServiceLocator.get_time_manager().hitstop(feel.hitstop)
	_kick_camera(Vector2(-side, 0.0), feel.kick)
	shake_camera(feel.shake.x, feel.shake.y)
	hurt_vignette.pulse(feel.vignette, feel.fade)
	rumble(feel.rumble)
	flash_hero(target)


## Білий спалах героя (D581): кадри героя на мить стають білими й гаснуть за HURT_FLASH_TIME.
func flash_hero(hero: Node) -> void:
	var material: ShaderMaterial = hero.get_node(^"Sprite2D").material
	material.set_shader_parameter(&"flash", 1.0)
	hero.create_tween().set_ignore_time_scale().tween_method(
			func(v: float) -> void: material.set_shader_parameter(&"flash", v), 1.0, 0.0, HURT_FLASH_TIME)


## Сила удару по героєві: 2 — бос, 1 — важкий (is_big_hurt), 0 — звичайний.
static func hurt_tier(source: Node) -> int:
	if source != null and source.is_in_group(GameGroups.BOSS):
		return 2
	return 1 if is_big_hurt(source) else 0


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
	if source.is_in_group(GameGroups.PLAYER):
		shake_camera(feel.shake.x, feel.shake.y)  # стріла — без тряски: це не удар героя (D581)
	if source.is_in_group(GameGroups.PLAYER) or source.is_in_group(HERO_ARROWS):
		rumble(feel.rumble)


## Сила удару: 3 — рипост (D575), 2 — важкий удар героя, 1 — удар із відкиданням (фінішер серії, булава D203,
## компаньйон D209), 0 — легкий. Стріла героя (D381) несе свою: швидка 0, заряджена 2.
static func hit_strength(source: Node) -> int:
	if source.is_in_group(HERO_ARROWS):
		return source.strength
	if source.is_in_group(GameGroups.PLAYER) and source.combat.state == source.combat.State.HEAVY_STRIKE:
		return 3 if source.combat.riposting else 2
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


## Щит щитоносця (D560): блок — дрібні іскри на щиті; розбитий щит — великі, завмирання й поштовх камери.
func _on_shield(enemy: Node2D, at: Vector2, broken: bool) -> void:
	var spark: CPUParticles2D = PARRY_SPARK_SCENE.instantiate()
	spark.finished.connect(spark.queue_free)
	enemy.get_parent().add_child(spark)
	spark.global_position = at
	spark.scale = Vector2.ONE * (1.0 if broken else BLOCK_SPARK_SCALE)
	spark.emitting = true
	if broken:
		ServiceLocator.get_time_manager().hitstop(PARRY_HITSTOP)
		_kick_camera(Vector2(signf(at.x - GameGroups.get_player().global_position.x), 0.0), PARRY_KICK)


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


## D491: ультимативна навичка — тряска камери й сильна вібрація.
func _on_skill_used(skill_id: String) -> void:
	if not SkillDatabase.get_skill(skill_id).ultimate:
		return
	shake_camera(ULTIMATE_SHAKE, ULTIMATE_SHAKE_TIME)
	rumble(HIT_FEEL[2].rumble)


## Тряска камери на [param strength] px, що згасає за [param seconds] (реальних с). Screen Shake Off — немає (D426).
## Кожна тряска — сигнал shake_started (перевірка verify_hit_feel), навіть коли її вимкнено.
func shake_camera(strength: float, seconds: float) -> void:
	if strength <= 0.0:
		return
	shake_started.emit(strength, seconds)
	if not SaveSystem.settings_module.screen_shake_enabled():
		return
	var camera := get_viewport().get_camera_2d()
	var tween := camera.create_tween().set_ignore_time_scale()
	var steps := roundi(seconds / 0.05)
	for i in steps:
		var fade := 1.0 - float(i) / steps
		tween.tween_property(camera, ^"offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade, 0.05)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, 0.05)


## Поштовх камери в бік [param dir] на [param strength] px і згасання туди-сюди за KICK_TIME (реальних с — грає й
## під час завмирання, тож удар читається одразу). Settings → Screen Shake Off — поштовху немає (D426); вібрація
## геймпада — не тряска екрана, вона лишається.
func _kick_camera(dir: Vector2, strength: float) -> void:
	if not SaveSystem.settings_module.screen_shake_enabled():
		return
	var camera := get_viewport().get_camera_2d()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var tween := camera.create_tween().set_ignore_time_scale()
	var step := KICK_TIME / 4.0
	tween.tween_property(camera, ^"offset", dir * strength, step * 0.5)
	tween.tween_property(camera, ^"offset", -dir * strength * 0.5, step)
	tween.tween_property(camera, ^"offset", dir * strength * 0.25, step)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, step * 1.5)
