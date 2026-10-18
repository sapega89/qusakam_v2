extends Node2D

## Асист компаньйона (D201, D209): забігає з краю кадру за героєм, робить фірмовий удар, тікає.
## Ушкодження — через HealthComponent ворога, як у навичок (той самий шлях, що й DamageApplier).
## Сцени: Scenes/Characters/Companions/companion_<id>.tscn; викликає CompanionManager.call_next().

enum Mode {
	FRONT,    ## охоронець: удар перед собою — усі вороги на reach, відкидання
	NEAREST,  ## Астрит: стрибок до найближчого ворога, важкий удар (відкидання зриває замах)
	COINS,    ## Уризен: смайт-монета падає на кожного ворога попереду, ушкодження + оглушення
	PET,      ## Алісия: кішка біжить до найближчого ворога й дряпає PET_HITS разів
}

const ENTER_TIME := 0.35
const LEAVE_TIME := 0.4
## Ступні героя нижче його центру: колізія 40 заввишки з зсувом 4 (Player.tscn).
const HERO_FEET := 24.0
const COIN_DROP := 140.0
const COIN_FALL_TIME := 0.25
const PET_HITS := 3
const PET_HIT_GAP := 0.2

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

@onready var sprite: AnimatedSprite2D = $Sprite
var _dir := 1
## Монети й кішка ще в дорозі — компаньйон не йде, доки вони не вдарять (бʼють від його імені).
var _pending: Array[Tween] = []


func _ready() -> void:
	add_to_group(&"companions")


## Увесь виступ: забіг → удар → відхід. [param hero] — гравець.
func start(hero: Node2D) -> void:
	var target := _nearest_enemy(hero)
	# Б'є в бік ворога, а не туди, куди дивиться герой: інакше ворог за спиною — удар у порожнечу.
	_dir = hero.last_direction if target == null else (1 if target.global_position.x >= hero.global_position.x else -1)
	var camera := get_viewport().get_camera_2d()
	var half_view: float = get_viewport_rect().size.x / camera.zoom.x / 2.0
	global_position = Vector2(camera.get_screen_center_position().x - _dir * (half_view + 40.0), hero.global_position.y + HERO_FEET)
	var stand_x: float = hero.global_position.x + _dir * 30.0
	if mode == Mode.NEAREST and target != null:
		stand_x = target.global_position.x - _dir * 30.0
	elif mode == Mode.COINS or mode == Mode.PET:
		stand_x = hero.global_position.x - _dir * 30.0
	_face(_dir)
	sprite.play(&"enter")
	var run_in := create_tween()
	run_in.tween_property(self, ^"global_position:x", stand_x, ENTER_TIME)
	await run_in.finished
	sprite.play(&"strike")
	while sprite.frame < strike_frame and sprite.is_playing():
		await sprite.frame_changed
	_strike(hero, target)
	await sprite.animation_finished
	for tween in _pending:
		if tween.is_running():
			await tween.finished
	_face(-_dir)
	sprite.play(&"leave" if sprite.sprite_frames.has_animation(&"leave") else &"enter")
	var run_out := create_tween()
	run_out.tween_property(self, ^"global_position:x", global_position.x - _dir * (half_view * 2.0 + 80.0), LEAVE_TIME)
	await run_out.finished
	queue_free()


func _strike(hero: Node2D, target: Node) -> void:
	match mode:
		Mode.FRONT:
			for enemy in _enemies_in_front(hero):
				_hit(enemy)
		Mode.NEAREST:
			if target != null and target.is_alive():
				_hit(target)
		Mode.COINS:
			for enemy in _enemies_in_front(hero):
				_drop_coin(enemy)
		Mode.PET:
			if target != null:
				_send_pet(target)


func _hit(enemy: Node) -> void:
	if not enemy.is_alive():
		return
	SkillCombatExecutor.find_health_component(enemy).apply_damage(damage, self)
	if knockback > 0.0:
		enemy.knockback(signf(enemy.global_position.x - global_position.x) * knockback)
	if stun > 0.0:
		enemy.stun(stun)


func _drop_coin(enemy: Node2D) -> void:
	var coin: Node2D = coin_scene.instantiate()
	get_parent().add_child(coin)
	var landing := enemy.global_position + Vector2(0, 16)
	coin.global_position = landing - Vector2(0, COIN_DROP)
	coin.get_node(^"Sprite").play(&"spin")
	var fall := coin.create_tween()
	_pending.append(fall)
	fall.tween_property(coin, ^"global_position", landing, COIN_FALL_TIME).set_ease(Tween.EASE_IN)
	fall.tween_callback(func() -> void:
		_hit(enemy)
		coin.queue_free())


func _send_pet(enemy: Node2D) -> void:
	var cat: Node2D = pet_scene.instantiate()
	get_parent().add_child(cat)
	cat.global_position = global_position
	var cat_sprite: AnimatedSprite2D = cat.get_node(^"Sprite")
	cat_sprite.flip_h = enemy.global_position.x < cat.global_position.x
	cat_sprite.play(&"run")
	var run := cat.create_tween()
	_pending.append(run)
	run.tween_property(cat, ^"global_position:x", enemy.global_position.x - signf(enemy.global_position.x - cat.global_position.x) * 18.0, 0.3)
	run.tween_callback(cat_sprite.play.bind(&"strike"))
	for i in PET_HITS:
		run.tween_interval(PET_HIT_GAP)
		run.tween_callback(_hit.bind(enemy))
	run.tween_callback(cat.queue_free)


func _enemies_in_front(hero: Node2D) -> Array[Node]:
	var out: Array[Node] = []
	for enemy in GameGroups.get_nodes_in_group(GameGroups.ENEMIES):
		var dx: float = (enemy.global_position.x - hero.global_position.x) * _dir
		if enemy.is_alive() and dx >= -16.0 and dx <= reach and absf(enemy.global_position.y - hero.global_position.y) < 64.0:
			out.append(enemy)
	return out


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
