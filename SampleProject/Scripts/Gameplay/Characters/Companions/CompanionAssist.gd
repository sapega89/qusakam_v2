extends Node2D

## Асист компаньйона (D201, D209, D515): повний виступ — вихід (забіг з краю кадру або стрибок згори), замах зі
## світінням, фірмова дія з ефектами, пауза-поза й відхід; разом ~2,5–3,5 с. Поки він на полі, іншого не покличеш
## (CompanionManager стежить за tree_exiting).
## Ушкодження — через HealthComponent ворога, як у навичок (той самий шлях, що й DamageApplier).
## Кожен закриває свою потребу (D464), числа — умовні, до плейтесту; ефекти — D465 (Scenes/FX/Companions).
## Сцени: Scenes/Characters/Companions/companion_<id>.tscn; викликає CompanionManager.call_next().

enum Mode {
	FRONT,   ## охоронець: удар списом перед собою — усі вороги на reach, відкидання; вітрова дуга
	POUNCE,  ## Астрит: наскок на найближчого ворога, удар шипастим щитом — відкидання й оглушення (D207 stun)
	CHAIN,   ## Уризен: монета-смайт падає на найближчого ворога попереду й перескакує далі (D207 chain), до chain_count
	RANGED,  ## Алісия: постріл здалеку в найдальшого ворога попереду; кішка поруч — для краси
}

## Вихід (D515): забігає з-за краю кадру або падає згори просто на своє місце.
enum Entrance { RUN, DROP }
## Відхід: тікає, згасаючи, або злітає вгору й тане (Уризен).
enum Exit { RUN, RISE }

## Звідки падає компаньйон, що стрибає згори, і як високо злітає той, хто відходить угору, px.
const DROP_HEIGHT := 260.0
const RISE_HEIGHT := 200.0
## Скільки пробігає той, хто тікає, поки згасає, px (не до краю кадру: на такій швидкості це був би ривок).
const EXIT_RUN := 320.0
## Присідання при приземленні: масштаб і час повернення.
const LAND_SQUASH := Vector2(1.18, 0.82)
const LAND_SQUASH_TIME := 0.14
## Рядок ступнів героя нижче його центру — низ його колізії: малюнок героя стоїть на ньому (hero-feet, verify_hero_feet);
## зсув (-32, -58) компаньйонів ставить їхній рядок ступнів (58) так само на початок вузла.
const HERO_FEET := 24.0
## Де компаньйон стає: позаду героя (монети, кішка) і перед ворогом (наскок) — не на них.
const STAND_BEHIND := 70.0
const STAND_BEFORE_TARGET := 55.0
const STAND_FRONT := 30.0
## Кішка з'являється позаду Алісиї й стає перед нею.
const PET_SPAWN_BEHIND := 20.0
const PET_STAND_FRONT := 26.0
const COIN_DROP := 140.0
const COIN_FALL_TIME := 0.3
## Монета перескакує дугою: час стрибка й висота дуги.
const COIN_HOP_TIME := 0.3
const COIN_HOP_HEIGHT := 46.0
## Стріла Алісиї: звідки вилітає (від ступнів, у бік удару) і швидкість, px/с.
const ARROW_FROM := Vector2(24.0, -44.0)
const ARROW_SPEED := 1100.0
## Зірки оглушення — над верхом колізії ворога.
const STARS_ABOVE := 10.0

const SHIELD_SLAM := preload("res://SampleProject/Scenes/FX/Companions/shield_slam.tscn")
const STUN_STARS := preload("res://SampleProject/Scenes/FX/Companions/stun_stars.tscn")
const ARROW := preload("res://SampleProject/Scenes/FX/Companions/arrow_streak.tscn")
const HIT_SPARK := preload("res://SampleProject/Scenes/FX/Companions/hit_spark.tscn")
const GOLD_BURST := preload("res://SampleProject/Scenes/FX/Companions/gold_burst.tscn")
const WIND_ARC := preload("res://SampleProject/Scenes/FX/Companions/wind_arc.tscn")
const KNOCKBACK_PUFF := preload("res://SampleProject/Scenes/FX/Companions/knockback_puff.tscn")
const LANDING_DUST := preload("res://SampleProject/Scenes/FX/Companions/landing_dust.tscn")
const CHARGE_GLOW := preload("res://SampleProject/Scenes/FX/Companions/charge_glow.tscn")

signal _landed
## Фаза виступу змінилась (для тестів і знімків): &"enter", &"windup", &"strike", &"hold", &"exit".
signal phase_changed(phase: StringName)

@export var mode: Mode = Mode.FRONT
## Кадр анімації strike, на якому удар влучає.
@export var strike_frame := 6
@export var damage := 10
@export var knockback := 0.0
@export var stun := 0.0
## Як далеко від героя компаньйон шукає ворогів, px.
@export var reach := 300.0
@export var coin_scene: PackedScene
@export var pet_scene: PackedScene
## Уризен: скільки ворогів зачіпає монета і як далеко вона перескакує від попереднього, px.
@export var chain_count := 3
@export var chain_radius := 200.0
@export_group("Sequence (D515)")
@export var entrance: Entrance = Entrance.RUN
@export var entrance_time := 0.7
## Падіння (Entrance.DROP) грає анімацію enter: в Астрит це її стрибок згори (A14, 12 кадрів). Без нього падає,
## застигши на першому кадрі enter (Уризен: його enter — не стрибок).
@export var animate_drop := false
## Замах перед дією: перший кадр strike стоїть, компаньйон світиться своїм кольором.
@export var windup_time := 0.35
## Швидкість анімації strike (< 1 — повільніший, вагоміший удар).
@export var strike_speed := 0.8
## Поза після дії, перш ніж піти.
@export var hold_time := 0.45
@export var exit: Exit = Exit.RUN
@export var exit_time := 0.6
## Колір світіння замаху (charge_glow).
@export var tint := Color(1, 1, 1)

@onready var sprite: AnimatedSprite2D = $Sprite
var _dir := 1
## Монета чи стріла ще в дорозі — компаньйон не йде, доки вона не вдарить (бʼє від його імені).
var _in_flight := 0
## Кішка Алісиї, що стоїть поруч (тікає разом з нею).
var _pet: Node2D
## Поточна фаза виступу (phase_changed).
var phase: StringName = &""


func _ready() -> void:
	add_to_group(&"companions")


## Увесь виступ (D515): вихід → замах → дія → поза → відхід. [param hero] — гравець.
func start(hero: Node2D) -> void:
	var target := _nearest_enemy(hero)
	# Б'є в бік ворога, а не туди, куди дивиться герой: інакше ворог за спиною — удар у порожнечу.
	_dir = hero.last_direction if target == null else (1 if target.global_position.x >= hero.global_position.x else -1)
	if mode == Mode.RANGED:
		target = _farthest_in_front(hero)
	elif mode == Mode.CHAIN:
		target = _nearest_in_front(hero)
	var feet_y: float = hero.global_position.y + HERO_FEET
	var stand_x: float = hero.global_position.x + _dir * STAND_FRONT
	if mode == Mode.POUNCE and target != null:
		stand_x = target.global_position.x - _dir * STAND_BEFORE_TARGET
	elif mode == Mode.CHAIN or mode == Mode.RANGED:
		stand_x = hero.global_position.x - _dir * STAND_BEHIND
	_face(_dir)
	await _enter(Vector2(stand_x, feet_y))
	_set_phase(&"windup")
	sprite.play(&"strike")
	sprite.pause()
	var glow: Node2D = CHARGE_GLOW.instantiate()
	glow.modulate = tint
	add_child(glow)
	var flare := create_tween()
	var bright := tint.lightened(0.5) * 1.4
	bright.a = 1.0
	flare.tween_property(sprite, ^"modulate", bright, windup_time * 0.7).set_ease(Tween.EASE_OUT)
	flare.tween_property(sprite, ^"modulate", Color.WHITE, windup_time * 0.3)
	await get_tree().create_timer(windup_time, false).timeout
	_set_phase(&"strike")
	sprite.speed_scale = strike_speed
	sprite.play()
	while sprite.frame < strike_frame and sprite.is_playing():
		await sprite.frame_changed
	_strike(hero, target)
	await sprite.animation_finished
	while _in_flight > 0:
		await _landed
	_set_phase(&"hold")
	await get_tree().create_timer(hold_time, false).timeout
	_set_phase(&"exit")
	sprite.speed_scale = 1.0
	await _leave()
	queue_free()


func _set_phase(next: StringName) -> void:
	phase = next
	phase_changed.emit(next)


## Вихід: забіг з-за краю кадру, що гальмує біля місця (пил з-під ніг), або падіння згори з присіданням і пилом.
func _enter(stand: Vector2) -> void:
	_set_phase(&"enter")
	sprite.play(&"enter")
	var move := create_tween()
	if entrance == Entrance.RUN:
		var camera := get_viewport().get_camera_2d()
		var half_view: float = get_viewport_rect().size.x / camera.zoom.x / 2.0
		global_position = Vector2(camera.get_screen_center_position().x - _dir * (half_view + 40.0), stand.y)
		move.tween_property(self, ^"global_position:x", stand.x, entrance_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		global_position = stand - Vector2(0.0, DROP_HEIGHT)
		if not animate_drop:
			sprite.pause()
		modulate.a = 0.0
		move.set_parallel()
		move.tween_property(self, ^"global_position:y", stand.y, entrance_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		move.tween_property(self, ^"modulate:a", 1.0, entrance_time * 0.3)
	await move.finished
	_spawn_fx(LANDING_DUST, global_position, _dir)
	if entrance == Entrance.DROP:
		var rest := sprite.scale
		sprite.scale = rest * LAND_SQUASH
		var squash := create_tween()
		squash.tween_property(sprite, ^"scale", rest, LAND_SQUASH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await squash.finished


## Відхід: тікає назад, згасаючи (кішка Алісиї — з нею), або злітає вгору й тане.
func _leave() -> void:
	var move := create_tween().set_parallel()
	if exit == Exit.RUN:
		_face(-_dir)
		if _pet != null:
			var pet_sprite: AnimatedSprite2D = _pet.get_node(^"Sprite")
			pet_sprite.flip_h = _dir > 0
			pet_sprite.play(&"run")
		sprite.play(&"leave" if sprite.sprite_frames.has_animation(&"leave") else &"enter")
		move.tween_property(self, ^"global_position:x", -_dir * EXIT_RUN, exit_time).as_relative().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		var glow: Node2D = CHARGE_GLOW.instantiate()
		glow.modulate = tint
		add_child(glow)
		move.tween_property(self, ^"global_position:y", -RISE_HEIGHT, exit_time).as_relative().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	move.tween_property(self, ^"modulate:a", 0.0, exit_time * 0.6).set_delay(exit_time * 0.4)
	await move.finished


func _strike(hero: Node2D, target: Node2D) -> void:
	match mode:
		Mode.FRONT:
			_spawn_fx(WIND_ARC, global_position + Vector2(_dir * 30.0, 0.0), _dir)
			for enemy in _enemies_in_front(hero):
				_hit(enemy)
				var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")  # пил — під ногами ворога, на низу його тіла
				_spawn_fx(KNOCKBACK_PUFF, Vector2(enemy.global_position.x - _dir * 10.0,
						body.global_position.y + body.shape.get_rect().end.y * enemy.global_scale.y), _dir)
		Mode.POUNCE:
			if target != null and target.is_alive():
				_hit(target)
				_spawn_fx(SHIELD_SLAM, Vector2(target.global_position.x - _dir * 18.0, global_position.y), _dir)
		Mode.CHAIN:
			if target != null:
				_smite_chain(target)
		Mode.RANGED:
			_send_pet()
			if target != null:
				_shoot(target)


## Удар від імені компаньйона; оглушення — із зірками над головою (D465).
func _hit(enemy: Node2D) -> void:
	if not enemy.is_alive():
		return
	SkillCombatExecutor.find_health_component(enemy).apply_damage(damage, self)
	if knockback > 0.0:
		enemy.knockback(signf(enemy.global_position.x - global_position.x) * knockback)
	if stun > 0.0:
		enemy.stun(stun)
		_show_stun_stars(enemy)


func _show_stun_stars(enemy: Node2D) -> void:
	var existing := enemy.get_node_or_null(^"StunStars")
	if existing != null:
		existing.extend(stun)
		return
	var stars: Node2D = STUN_STARS.instantiate()
	stars.duration = stun
	var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	enemy.add_child(stars)
	var lift: float = (enemy.get_node(^"Sprite2D") as Node2D).position.y * enemy.global_scale.y  # малюнок над колізією (hero-feet)
	stars.global_position = body.global_position - Vector2(0.0, body.shape.get_rect().size.y * enemy.global_scale.y / 2.0 + STARS_ABOVE - lift)


## Ефект у кімнаті (не на компаньйоні: він тікає раніше, ніж ефект догасне), дзеркалений у бік удару.
func _spawn_fx(scene: PackedScene, at: Vector2, direction: int) -> Node2D:
	var fx: Node2D = scene.instantiate()
	fx.scale.x = direction
	get_parent().add_child(fx)
	fx.global_position = at
	return fx


## Середина тіла ворога — куди летить стріла.
func _body_center(enemy: Node2D) -> Vector2:
	return (enemy.get_node(^"CollisionShape2D") as CollisionShape2D).global_position


## Уризен (D464): монета падає на першого, потім дугою перескакує до найближчого ще не враженого в chain_radius.
func _smite_chain(first: Node2D) -> void:
	var coin: Node2D = coin_scene.instantiate()
	get_parent().add_child(coin)
	var landing := first.global_position + Vector2(0, 16)
	coin.global_position = landing - Vector2(0, COIN_DROP)
	coin.get_node(^"Sprite").play(&"spin")
	_in_flight += 1
	var fall := coin.create_tween()
	fall.tween_property(coin, ^"global_position", landing, COIN_FALL_TIME).set_ease(Tween.EASE_IN)
	await fall.finished
	var struck: Array[Node] = []
	var enemy: Node2D = first
	while enemy != null:
		_hit(enemy)
		_spawn_fx(GOLD_BURST, coin.global_position, _dir)
		struck.append(enemy)
		enemy = null if struck.size() >= chain_count else SkillTargeting.chain_target(struck[-1], struck, chain_radius)
		if enemy != null:
			await _hop(coin, enemy.global_position + Vector2(0, 16))
			if not is_instance_valid(enemy):  # за час стрибка ворога добили й прибрали
				break
	coin.queue_free()
	_in_flight -= 1
	_landed.emit()


## Стрибок монети дугою від місця, де вона зараз, до [param to].
func _hop(coin: Node2D, to: Vector2) -> void:
	var from := coin.global_position
	var hop := coin.create_tween()
	hop.tween_method(func(t: float) -> void:
		coin.global_position = from.lerp(to, t) - Vector2(0.0, sin(t * PI) * COIN_HOP_HEIGHT), 0.0, 1.0, COIN_HOP_TIME)
	await hop.finished


## Алісия (D464): стріла зі смугою летить до середини тіла цілі; влучання — іскра.
func _shoot(target: Node2D) -> void:
	var arrow: Node2D = ARROW.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector2(ARROW_FROM.x * _dir, ARROW_FROM.y)
	var aim := _body_center(target)
	arrow.rotation = (aim - arrow.global_position).angle()
	_in_flight += 1
	var flight := arrow.create_tween()
	flight.tween_property(arrow, ^"global_position", aim, arrow.global_position.distance_to(aim) / ARROW_SPEED)
	await flight.finished
	if is_instance_valid(target):  # за час польоту ворога могли добити й прибрати
		_hit(target)
		_spawn_fx(HIT_SPARK, aim, _dir)
	arrow.queue_free()
	_in_flight -= 1
	_landed.emit()


## Кішка Алісиї — для краси (D464): вибігає з-за неї, стає попереду й замахується лапою; іде разом з нею.
func _send_pet() -> void:
	var cat: Node2D = pet_scene.instantiate()
	_pet = cat
	add_child(cat)
	move_child(cat, 0)  # під Алісиєю
	cat.position = Vector2(-_dir * PET_SPAWN_BEHIND, 0)
	var cat_sprite: AnimatedSprite2D = cat.get_node(^"Sprite")
	cat_sprite.flip_h = _dir < 0
	cat_sprite.play(&"run")
	var run := cat.create_tween()
	run.tween_property(cat, ^"position:x", _dir * PET_STAND_FRONT, 0.25)
	await run.finished
	cat_sprite.play(&"strike")


func _enemies_in_front(hero: Node2D) -> Array[Node]:
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		var dx: float = (enemy.global_position.x - hero.global_position.x) * _dir
		if enemy.is_alive() and dx >= -16.0 and dx <= reach and absf(enemy.global_position.y - hero.global_position.y) < 64.0:
			out.append(enemy)
	return out


## Найближчий і найдальший від героя з тих, що попереду (_enemies_in_front), або null.
func _nearest_in_front(hero: Node2D) -> Node2D:
	return _by_distance(hero, _enemies_in_front(hero), false)


func _farthest_in_front(hero: Node2D) -> Node2D:
	return _by_distance(hero, _enemies_in_front(hero), true)


func _by_distance(hero: Node2D, enemies: Array[Node], farthest: bool) -> Node2D:
	var best: Node2D = null
	for enemy: Node2D in enemies:
		var dx := absf(enemy.global_position.x - hero.global_position.x)
		if best == null or (dx > absf(best.global_position.x - hero.global_position.x)) == farthest:
			best = enemy
	return best


func _nearest_enemy(hero: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := reach
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		var distance: float = hero.global_position.distance_to(enemy.global_position)
		if enemy.is_alive() and distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Спрайти намальовані обличчям праворуч.
func _face(direction: int) -> void:
	sprite.flip_h = direction < 0
