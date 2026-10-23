extends DefaultEnemy

## Бос (D301, D302, design/lab_boss_plan.md): звичайний ворог (DefaultEnemy + EnemyStats), але ходи обирає BossLogic,
## над ним немає смужки HP — є смужка боса вгорі екрана (boss_health_bar.tscn), на половині HP — друга фаза
## (замахи коротші, швидше ходить, відкриваються ходи з phase 2). Хто бос — його сцена: кадри, moves, назва.

const BOSS_LOGIC := preload("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossLogic.gd")
const BOSS_BAR := preload("res://SampleProject/Scenes/UI/boss_health_bar.tscn")

signal phase_changed(phase: int)

## Назва на смужці боса (англійською, як решта інтерфейсу, D121).
@export var display_name := ""
## Ходи: [{kind, min_range, max_range, windup, damage, recovery, tell / tells, phase, …}] — див. BossLogic.
@export var moves: Array[Dictionary] = []
## Візерунок ходів (D504): черга kind, яку BossLogic.pick_move проходить по колу; у другій фазі — pattern_phase2.
@export var pattern: PackedStringArray = []
@export var pattern_phase2: PackedStringArray = []
## Між ходами бос тримається на цій відстані від героя, px (D504: не стоїть на місці).
@export var preferred_range := 150.0
## Докуди сягає хітбокс (combo, charge) — передній край його форми в сцені (B128, verify_hit_areas), px.
## attack_range боса — дальність найдальшого ходу.
@export var melee_reach := 130.0
## Друга фаза: множник замахів і швидкості.
@export var phase2_windup := 0.75
@export var phase2_speed := 1.3
## Поза другого удару серії combo (D564: булава навідліг); у кого її немає — та сама attack.
@export var finisher_animation: StringName = &"attack"
## Кпини посеред бою (D466) — ключі .po, по одному на кожен ковток (хід drink), по колу; на початку другої фази —
## phase2_taunt. Облачко — над головою, вістря хвоста в taunt_anchor.
@export var taunts: PackedStringArray = []
@export var phase2_taunt := ""
@export var taunt_anchor := Vector2(0, -110)

var phase := 1
## Множник замаху ходів (1 у першій фазі).
var windup_scale := 1.0
var bar: Control
var _taunt_at := 0


func _ready() -> void:
	add_to_group(GameGroups.BOSS)  # до super._ready(): там вирішується, чи потрібна смужка над головою
	super._ready()
	knockback_immune = true  # B134: удари героя боса не відкидають і замаху не зривають — лише збій
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
	if new_state == EnemyLogic.AIState.ATTACK and not enemy_view.staggered:
		anim_player.play(&"idle")


func _on_logic_attack_ended() -> void:
	super._on_logic_attack_ended()
	if not is_dead and not enemy_view.staggered and enemy_logic.current_state == EnemyLogic.AIState.ATTACK:
		anim_player.play(&"idle")


## Другий удар серії — своя поза (finisher_animation), перший — attack.
func _on_logic_attack_started():
	enemy_view.on_attack_started(enemy_logic.swing_windup, finisher_animation if enemy_logic.finisher else &"attack")


func _make_logic() -> EnemyLogic:
	return BOSS_LOGIC.new()


func start_attack(direction: int) -> void:
	_face_shapes(direction)
	hitbox_damage.update_damage()
	hitbox_damage.enable_damage()
	hitbox.monitoring = true
	enemy_view.on_strike()


## Замах ходу видно: у сцені боса на кожен свій kind (не combo) дві анімації — "<kind>" (замах) і "<kind>_strike" (удар).
func telegraph(move: Dictionary) -> void:
	_pose(move.kind)


## Підказка ходу (4b, D504): відблиск кольору підказки на зброї тієї пози, що зараз на екрані (EnemyView.weapon_point
## бере meta «tell_at_<kind>» Sprite2D боса), зі звуком; ривок (charge) ще й креслить червону лінію по землі на всю
## небезпечну смугу — distance ривка плюс melee_reach хітбокса попереду (D522).
func _on_logic_attack_telegraphed() -> void:
	var move: Dictionary = enemy_logic.last_move
	var line := float(move.distance) if move.kind == "charge" else 0.0
	enemy_view.show_tell(enemy_logic.tell_time, line, melee_reach if line > 0.0 else 0.0, enemy_logic.tell_kind)
	EventBus.enemy_tell_shown.emit(self, enemy_logic.tell_kind)


## Ковток (BossLogic, D564): поза drink і кпин в облачку.
func drink(move: Dictionary) -> void:
	_pose(move.kind)
	if not taunts.is_empty():
		taunt(taunts[_taunt_at % taunts.size()])
		_taunt_at += 1


## Репліка [param key] (.po) в облачку над головою; посеред розмови мовчить (DialogueManager.say_line_in_passing).
func taunt(key: String) -> void:
	ServiceLocator.get_dialogue_manager().say_line_in_passing(self, tr(key), taunt_anchor)


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
		if not phase2_taunt.is_empty():
			taunt(phase2_taunt)
		phase_changed.emit(phase)


## Монет бос не сипле: нагороду за перемогу дає кімната (D300).
func _calculate_coin_drop() -> int:
	return 0


func _exit_tree() -> void:
	super._exit_tree()
	if is_instance_valid(bar):
		bar.queue_free()
