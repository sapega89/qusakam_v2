extends Control

## Смужка витривалості ворога (D824, EnemyStamina). Тонка, під шкалою стійкості (D777), окремим кольором — щоб їх не
## плутати: стійкість набирається від ударів героя (жовта), витривалість тане від ударів самого ворога (колір ST героя).
## Вичерпана — червона, доки ворог не набере сили бити знову (видихнувся — вікно героя). Над звичайним ворогом вона —
## дитина його шкали стійкості (DefaultEnemy._add_poise_bar) і видна лише поки ворог у бою; у смужці боса — рядок під
## стійкістю (boss_health_bar.tscn, [member floating] = false). Вигляд — типи теми EnemyStaminaBar / EnemyStaminaBarSpent
## (UITokens.ENEMY_STAMINA_*), розкладка — enemy_stamina_bar.tscn.

## Під шкалою стійкості над ворогом (true) чи рядком смужки боса (false).
@export var floating := true

@onready var _bar: ProgressBar = $Bar

var _enemy: Node = null


func _ready() -> void:
	if floating:
		custom_minimum_size = Vector2(UITokens.POISE_BAR_WIDTH, UITokens.ENEMY_STAMINA_HEIGHT)
		size = custom_minimum_size
		position = Vector2(0.0, UITokens.POISE_BAR_HEIGHT + UITokens.ENEMY_STAMINA_GAP)
	else:
		custom_minimum_size.y = UITokens.BOSS_STAMINA_HEIGHT


func track(enemy: Node) -> void:
	_enemy = enemy
	var stamina: Node = enemy.stamina
	_on_changed(stamina.current, stamina.max_stamina, stamina.exhausted)
	stamina.changed.connect(_on_changed)
	enemy.entity_died.connect(hide)


func _on_changed(current: float, maximum: float, exhausted: bool) -> void:
	_bar.max_value = maximum
	_bar.value = current
	_bar.theme_type_variation = &"EnemyStaminaBarSpent" if exhausted else &"EnemyStaminaBar"


func _process(_delta: float) -> void:
	if floating and _enemy != null:
		visible = _enemy.is_engaged()
