extends DefaultEnemy

## Бос (D301, D302, design/lab_boss_plan.md): звичайний ворог (DefaultEnemy + EnemyStats), але ходи обирає BossLogic,
## над ним немає смужки HP — є смужка боса вгорі екрана (boss_health_bar.tscn), на половині HP — друга фаза
## (замахи коротші, швидше ходить, відкриваються ходи з phase 2). Хто бос — його сцена: кадри, moves, назва.

const BOSS_LOGIC := preload("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossLogic.gd")
const BOSS_BAR := preload("res://SampleProject/Scenes/UI/boss_health_bar.tscn")

signal phase_changed(phase: int)

## Назва на смужці боса (англійською, як решта інтерфейсу, D121).
@export var display_name := ""
## Ходи: [{kind, min_range, max_range, windup, damage, weight, phase, …}] — див. BossLogic.
@export var moves: Array[Dictionary] = []
## Довжина удару хітбоксом (combo, charge), px. attack_range боса — дальність найдальшого ходу.
@export var melee_reach := 130.0
## Друга фаза: множник замахів і швидкості.
@export var phase2_windup := 0.75
@export var phase2_speed := 1.3
## Анімація замаху кожного ходу (kind → назва в AnimationPlayer); без запису — attack.
@export var telegraph_animations: Dictionary = {}

var phase := 1
## Множник замаху ходів (1 у першій фазі).
var windup_scale := 1.0
var bar: Control


func _ready() -> void:
	add_to_group(GameGroups.BOSS)  # до super._ready(): там вирішується, чи потрібна смужка над головою
	super._ready()
	hitbox_collision.shape.size.x = melee_reach
	health_changed.connect(_on_health_changed)
	bar = BOSS_BAR.instantiate()
	get_tree().current_scene.get_node(^"UICanvas").add_child(bar)
	bar.track(self)


func _make_logic() -> EnemyLogic:
	return BOSS_LOGIC.new()


func start_attack(direction: int) -> void:
	hitbox.position.x = direction * melee_reach / 2.0
	hitbox_damage.update_damage()
	hitbox_damage.enable_damage()
	hitbox.monitoring = true


## Замах ходу видно: своя анімація, якщо є.
func telegraph(move: Dictionary) -> void:
	anim_player.play(telegraph_animations.get(move.kind, "attack"))


func _on_health_changed(health: int, max_health: int, _animate: bool) -> void:
	if phase == 1 and health > 0 and health * 2 <= max_health:
		phase = 2
		windup_scale = phase2_windup
		attack_windup *= phase2_windup
		speed *= phase2_speed
		enemy_logic.speed = speed
		phase_changed.emit(phase)


## Монет бос не сипле: нагороду за перемогу дає кімната (D300).
func _calculate_coin_drop() -> int:
	return 0


func _exit_tree() -> void:
	super._exit_tree()
	if is_instance_valid(bar):
		bar.queue_free()
