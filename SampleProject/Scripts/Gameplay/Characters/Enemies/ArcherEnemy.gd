extends DefaultEnemy
class_name ArcherEnemy

## Пустельний лучник (BACKLOG 40, D386, design/ranged_plan.md): тримає дистанцію (ArcherLogic) і стріляє.
## Натяг — звичайний замах ворога (EnemyLogic.wind_up): червоний відблиск на наконечнику за PARRY_WINDOW до пострілу
## (4b); «удар» — стріла (Scenes/Combat/arrow.tscn) з наконечника в кадрі, а не хітбокс. Сцена — enemy_archer.tscn.

const ARCHER_LOGIC := preload("res://SampleProject/Scripts/Gameplay/Characters/Enemies/ArcherLogic.gd")
const ARROW_SCENE := preload("res://SampleProject/Scenes/Combat/arrow.tscn")

## Ближче за keep_away px до героя — відступає; стріляє з keep_away до attack_range (EnemyStats).
@export var keep_away: float = 170.0
## Стріляє, лише коли герой на його висоті (±same_height px): стріли летять по прямій.
@export var same_height: float = 48.0
@export var arrow_speed: float = 420.0
## Найкрутіший нахил пострілу, px униз (угору) на px польоту: 0 — стріла летить рівно з наконечника (звичайний лучник);
## великий лучник (D652) тягне лук вище за голову героя й цілить у його тіло, не крутіше за max_tilt.
@export var max_tilt: float = 0.0


func _make_logic() -> EnemyLogic:
	return ARCHER_LOGIC.new()


## Між пострілами — спокій (кадри idle), а не поза натягу: натяг грає лише справжній замах.
func _on_logic_state_changed(new_state: EnemyLogic.AIState) -> void:
	super._on_logic_state_changed(new_state)
	if new_state == EnemyLogic.AIState.ATTACK:
		anim_player.play(&"idle")


func _on_logic_attack_ended() -> void:
	super._on_logic_attack_ended()
	if not is_dead and enemy_logic.current_state == EnemyLogic.AIState.ATTACK:
		anim_player.play(&"idle")


## Постріл замість удару хітбоксом: стріла летить з наконечника туди, куди лучник дивиться наприкінці натягу.
func start_attack(direction: int) -> void:
	enemy_view.on_strike()
	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.hero_side = false
	arrow.direction = direction
	arrow.speed = arrow_speed
	arrow.damage = int(damage)
	arrow.stagger_time = stagger_time
	arrow.tell = enemy_logic.tell_kind
	arrow.shooter = self
	var from := global_position + enemy_view.weapon_point(direction)
	arrow.fall = _tilt_to(from)
	get_parent().add_child(arrow)
	arrow.global_position = from


## Нахил стріли з [param from] у центр тіла героя (його CollisionShape2D) там, де він буде, коли стріла долетить (D742),
## обмежений max_tilt.
func _tilt_to(from: Vector2) -> float:
	if max_tilt == 0.0:
		return 0.0
	var body: Vector2 = player.get_node(^"CollisionShape2D").global_position
	# Випереджає (D742): цілить туди, де тіло героя буде, коли стріла долетить
	var flight := absf(body.x - from.x) / arrow_speed
	body += Vector2(player.velocity.x * flight, enemy_logic._hero_y_at(flight) - player.global_position.y)
	var dx := absf(body.x - from.x)
	return clampf((body.y - from.y) / maxf(dx, 1.0), -max_tilt, max_tilt)
