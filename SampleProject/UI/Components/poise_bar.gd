extends Control

## Шкала стійкості ворога (D777; Sapega 2026-10-27: «шкала стану має бути в усіх»). Тонка смуга, що набирається з
## кожним ударом героя (DefaultEnemy.take_poise), спадає, коли ворога не б'ють, і порожніє, коли повна збила ворога.
## Один компонент на всіх: над звичайним ворогом (DefaultEnemy._add_poise_bar) — видно, лише поки він у бою чи шкала
## не спала; у смужці боса — під HP (boss_health_bar.tscn, там видимість веде сама смужка боса, [member floating] = false).
## Вигляд — тип теми PoiseBar (UITokens.POISE_*), розкладка — poise_bar.tscn.
## Над шкалою — значки стану ворога (D599, status_row.tscn): підпал (DefaultEnemy.burn_left, D207), оглушення
## (EnemyLogic.stun_left: оглушення навички і збій), прокляття (проклятий вид — той, що має піну, kinds.<id>.foam, D653).
## Кровотечі в грі ще немає — її значок чекає системи. У смужці боса рядок схований (там над шкалою стоїть HP).

const EnemyVariety = preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")

## Над ворогом (true) чи в рядку смужки боса (false).
@export var floating := true

@onready var _bar: ProgressBar = $Bar
@onready var _states: HBoxContainer = %StatusRow

var _enemy: Node = null


func _ready() -> void:
	if floating:
		custom_minimum_size = Vector2(UITokens.POISE_BAR_WIDTH, UITokens.POISE_BAR_HEIGHT)
		size = custom_minimum_size
	else:
		custom_minimum_size.y = UITokens.BOSS_POISE_HEIGHT


func track(enemy: Node) -> void:
	_enemy = enemy
	_bar.max_value = enemy.poise_max
	_bar.value = enemy.poise_max - enemy.poise
	enemy.poise_changed.connect(_on_poise_changed)
	enemy.entity_died.connect(hide)
	_states.visible = floating
	if floating:
		_states.set_state(&"Cursed", EnemyVariety.kind(enemy.enemy_stats.enemy_type).has("foam"))
		_follow()


func _on_poise_changed(filled: float, maximum: float) -> void:
	_bar.max_value = maximum
	_bar.value = filled


func _process(_delta: float) -> void:
	if not floating or _enemy == null:
		return
	_states.set_state(&"Burning", _enemy.burn_left > 0.0)
	_states.set_state(&"Stunned", _enemy.enemy_logic.stun_left > 0.0)
	visible = _enemy.is_alive() and (_enemy.is_engaged() or _bar.value > 0.0 or _states.is_on(&"Burning"))
	if visible:
		_follow()


## Над головою: верхній край зони влучання (вона облягає намальоване тіло, B128, і росте з розміром, D560), по центру тіла.
func _follow() -> void:
	var hurt: CollisionShape2D = _enemy.hurt_collision
	var top: float = hurt.global_position.y - hurt.shape.get_rect().size.y * absf(hurt.global_scale.y) / 2.0
	global_position = Vector2(_enemy.body_collision.global_position.x - size.x / 2.0, top - UITokens.POISE_BAR_GAP - size.y)
