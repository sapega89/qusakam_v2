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
	bar.hide()  # смужка з'являється, коли бос побачив героя
	enemy_logic.player_detected.connect(bar.show)


## Стан ATTACK у боса — це очікування між ходами, а не удар: замість анімації attack (фальшивий замах) — спокій.
## Удари грають свої пози (telegraph, strike, combo); поза удару тримається, доки бос відновлюється (move.recovery).
func _on_logic_state_changed(new_state: EnemyLogic.AIState) -> void:
	super._on_logic_state_changed(new_state)
	if new_state == EnemyLogic.AIState.ATTACK:
		anim_player.play(&"idle")


func _on_logic_attack_ended() -> void:
	super._on_logic_attack_ended()
	if not is_dead and enemy_logic.current_state == EnemyLogic.AIState.ATTACK:
		anim_player.play(&"idle")


func _make_logic() -> EnemyLogic:
	return BOSS_LOGIC.new()


func start_attack(direction: int) -> void:
	hitbox.position.x = direction * melee_reach / 2.0
	hitbox_damage.update_damage()
	hitbox_damage.enable_damage()
	hitbox.monitoring = true
	enemy_view.on_strike()


## Замах ходу видно: у сцені боса на кожен свій kind (не combo) дві анімації — "<kind>" (замах) і "<kind>_strike" (удар).
func telegraph(move: Dictionary) -> void:
	_pose(move.kind)


func strike(move: Dictionary) -> void:
	_pose(move.kind + "_strike")


## Поза ходу — одразу: стоп-кадр удару (Engine.time_scale = 0) інакше лишав на екрані позу замаху, бо ключ
## на 0 с застосовується лише з першим ненульовим кроком анімації.
func _pose(anim: String) -> void:
	anim_player.speed_scale = 1.0  # хід боса — у темпі своєї анімації, не розтягнутого замаху (EnemyView)
	anim_player.play(anim)
	anim_player.advance(0.0)


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
