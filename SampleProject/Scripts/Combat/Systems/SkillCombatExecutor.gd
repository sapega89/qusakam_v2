extends RefCounted
class_name SkillCombatExecutor

## Виконавчий шар навичок: єдине місце, де навичка перетворюється на бойову дію.
##
## Свого пайплайну ушкоджень тут НЕМАЄ. Використовується той самий примітив,
## що й у звичайної атаки: HealthComponent.apply_damage() → CombatBody2D.take_damage()
## → EventBus. DamageApplier не залучається, бо він працює від зіткнення з хітбоксом,
## а навичка б'є по вже відомій цілі.
##
## SkillManager нічого не знає про бій і викликає лише execute().
## Формул ушкоджень немає ні тут, ні в SkillManager: значення береться з
## SkillDefinition.damage (конфігурація), а застосування — з наявної системи.

## Наносить ушкодження цілі. Повертає true, якщо ефект справді застосовано.
## [param amount] — ушкодження з урахуванням рівня навички (D150); без нього — базове з визначення.
func execute(definition: SkillDefinition, source: Node, target: Node, amount: int = -1) -> bool:
	if definition == null or target == null:
		return false
	if definition.damage <= 0:
		# Навичка без прямого ушкодження — інші типи ефектів з'являться пізніше.
		return false
	if not is_instance_valid(target):
		return false

	var health := find_health_component(target)
	if health == null:
		return false
	if not health.is_alive():
		return false

	health.apply_damage(definition.damage if amount < 0 else amount, source)
	return true


## Стан після влучання (D207): підпал на [param burn_dps] (уже з рангом) і оглушення. Ціль — ворог.
func apply_status(definition: SkillDefinition, target: Node, burn_dps: int) -> void:
	if definition.burn_dps > 0:
		target.apply_burn(burn_dps, definition.burn_duration)
	if definition.stun > 0.0:
		target.stun(definition.stun)


## Навички руху (D812) після влучання: відкидання від героя на knockback px і lifesteal — частка [param amount]
## лікує героя (як Blood Pact у PlayerCombat._hit_effects). Ціль — ворог.
func apply_move_riders(definition: SkillDefinition, source: Node2D, target: Node2D, amount: int) -> void:
	if definition.knockback > 0.0:
		var away := signf(target.global_position.x - source.global_position.x)
		target.knockback((away if away != 0.0 else 1.0) * definition.knockback)
	var drained := roundi(amount * definition.lifesteal)
	if drained > 0:
		source.heal_damage(drained)
		EventBus.skill_drained.emit(source, target, drained)


## Контроль (D-sv2ca1) після влучання: шкода стійкості — control_poise_x важких ударів героя з пасивкою poise (D284,
## як PlayerCombat._hit_effects; повна шкала — збій, D777), підкидання, збиття з ніг. POISE_HEAVY — з героя: class_name
## PlayerCombat тут дав би цикл компіляції (PlayerCombat кличе цей клас).
func apply_control(definition: SkillDefinition, source: Node2D, target: Node2D) -> void:
	if definition.control_poise_x > 0.0:
		var poise: float = source.combat.POISE_HEAVY * definition.control_poise_x * (1.0 + ServiceLocator.get_skill_manager().passive_value("poise"))
		target.take_poise(poise, source.global_position.x, &"skill")
	if definition.control_launch > 0.0:
		target.launch(definition.control_launch)
	if definition.control_knockdown > 0.0:
		target.knock_down(definition.control_knockdown)


# ── Рух (D812) ─────────────────────────────────────────────────────────────
## Герой рухається тілом (PlayerMover.push і гравітація), тож тіла ворогів зупиняють його самі (D443): ривок
## спиняється, щойно перший ворог у досяжності удару; стрибок не летить далі за першого ворога попереду — за спину
## ніхто не потрапляє (Sapega: «за спину ми нікому не зможемо забігти»).

## Зазор між тілами героя й ворога, на якому приземляється стрибок, px: тіла вужчі за спрайти, і з меншим
## зазором герой на кадрі «стояв у» ворогові (capture_skill_moves).
const LEAP_GAP := 24.0


## Початкова швидкість угору, щоб злетіти на [param height] px.
static func leap_speed(height: float) -> float:
	return sqrt(2.0 * _gravity() * height)


## Скільки триває стрибок на [param height] px до землі на тій самій висоті, с.
static func leap_time(height: float) -> float:
	return 2.0 * leap_speed(height) / _gravity()


## Дальність стрибка героя [param player] у бік [param direction]: move_distance, але приземлення — перед першим
## живим ворогом попереду (на висоті стрибка), не за ним.
static func leap_distance(definition: SkillDefinition, player: Node2D, direction: int) -> float:
	var body: Rect2 = player.body_rect()
	var path := Rect2(body.position - Vector2(0, definition.move_height), body.size + Vector2(0, definition.move_height))
	var distance := definition.move_distance
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		if not enemy.is_alive():
			continue
		var other: Rect2 = enemy.body_rect()
		if other.end.y <= path.position.y or other.position.y >= path.end.y:
			continue
		var gap: float = other.position.x - body.end.x if direction > 0 else body.position.x - other.end.x
		if gap > -other.size.x:  # ворог попереду (або вже впритул) — далі за нього не летимо
			distance = minf(distance, maxf(0.0, gap - LEAP_GAP))
	return distance


static func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))


# ── Кидок і зона (v2 зріз 4, D-sv2r1, D-sv2r2) ────────────────────────────
## Не preload: снаряд успадковує Arrow, а Arrow бере PlayerCombat, який тягне цей скрипт, — коло компіляції.
const PROJECTILE_SCENE := "res://SampleProject/Scenes/Combat/skill_projectile.tscn"
const ZONE_SCENE := "res://SampleProject/Scenes/Combat/skill_zone.tscn"


## Пускає снаряд навички від руки героя [param source] уздовж його погляду, як стрілу лука (SkillProjectile.place_at_hand);
## [param amount] — шкода кожного влучання (уже з рангом).
func throw(definition: SkillDefinition, source: Node2D, amount: int) -> Area2D:
	var spear: Area2D = load(PROJECTILE_SCENE).instantiate()
	spear.skill = definition
	spear.direction = source.last_direction
	spear.shooter = source
	spear.damage = amount
	spear.speed = definition.projectile_speed
	spear.range_px = definition.projectile_range
	spear.pierce = definition.projectile_pierce
	Game.get_singleton().map.add_child(spear)
	spear.place_at_hand()
	return spear


## Кладе зону навички під ноги героя [param source] (низ його тіла); [param dps] / [param heal] — уже з рангом.
func place_zone(definition: SkillDefinition, source: Node2D, dps: int, heal_per_s: int) -> Node2D:
	var zone: Node2D = load(ZONE_SCENE).instantiate()
	zone.skill = definition
	zone.source = source
	zone.dps = dps
	zone.heal = heal_per_s
	var body: Rect2 = source.body_rect()
	Game.get_singleton().map.add_child(zone)
	zone.global_position = Vector2(body.get_center().x, body.end.y)
	return zone


## Удар зони на [param amount] без SkillDefinition.damage (Hallowed Circle б'є лише зоною): той самий HealthComponent.
func hurt(source: Node, target: Node, amount: int) -> void:
	var health := find_health_component(target)
	if health.is_alive():
		health.apply_damage(amount, source)


## Лікує ціль на SkillDefinition.heal. Ціль — гравець (CombatBody2D) або союзник з heal_damage().
func heal(definition: SkillDefinition, target: Node, amount: int = -1) -> bool:
	if not target.has_method(&"heal_damage"):  # тип цілі справді різний: герой або NPC-союзник
		return false
	target.heal_damage(definition.heal if amount < 0 else amount)
	return true


## Пошук HealthComponent у цілі — та сама стратегія, що й у DamageApplier
## (сам вузол → батько → CombatBody2D), винесена сюди без зміни поведінки.
static func find_health_component(target: Node) -> HealthComponent:
	if target == null:
		return null
	for child in target.get_children():
		if child is HealthComponent:
			return child
	var parent := target.get_parent()
	if parent:
		for child in parent.get_children():
			if child is HealthComponent:
				return child
	return null
