extends Node

## Навчальний бій (BACKLOG 28, D-28a…D-28d, design/onboarding_plan.md): перший ворог гри вчить по одному руху —
## удар, серія, ривок крізь удар, блок, парирування на червоний відблиск, важкий удар. Кожен урок чекає, доки
## гравець зробить рух; урок — тема туторіалу lesson_* (уперше вікно з картинкою, далі плашка до виконання, D289).
## Поки йдуть уроки, ні ворог, ні герой не гинуть (D-28c): здоровʼя не падає нижче 1 (min_health), а нижче
## SAFE_FRACTION — назад до повного.
## Village додає вузол перед появою бандита й викликає start(), коли бандит ожив; finished — уроки пройдено.

signal finished
signal lesson_done(id: String)

const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const LESSONS: Array[String] = ["lesson_attack", "lesson_combo", "lesson_dodge", "lesson_block", "lesson_parry", "lesson_heavy"]
## Загальні підказки бою, які уроки замінюють, — бачені, щоб не вискакували посеред навчання.
const REPLACED_HINTS: Array[String] = ["attack", "block", "heavy_attack"]
const SAFE_FRACTION := 0.4
## Ривок зараховано, якщо в цей момент удар ворога живий не далі за стільки пікселів.
const DODGE_RANGE := 160.0
## Пауза між уроками, щоб гравець побачив, що урок зараховано.
const NEXT_DELAY := 0.8

var lesson := -1
var enemies: Array[Node] = []
var _player: CombatBody2D
var _combat: PlayerCombat
var _mover: PlayerMover
## Усі підʼєднання уроків: [сигнал, callable] — _stop() знімає їх саме цими callable (bind дає новий обʼєкт).
var _links: Array = []


func _ready() -> void:
	for id in REPLACED_HINTS:
		TutorialTopics.mark_seen(id)


func start(fight_enemies: Array[Node]) -> void:
	enemies = fight_enemies
	_player = Game.get_singleton().player
	_combat = _player.combat
	_mover = _player.mover
	_link(_combat.damage_applier.damage_applied, _on_hit)
	_link(EventBus.player_blocked, _on_guard.bind(false))
	_link(EventBus.player_parried, _on_guard.bind(true))
	for body: CombatBody2D in _bodies():
		body.min_health = 1
		_link(body.health_changed, _keep_alive.bind(body))
	_begin(0)


func _link(sig: Signal, call: Callable) -> void:
	sig.connect(call)
	_links.append([sig, call])


func current_id() -> String:
	return LESSONS[lesson] if lesson >= 0 and lesson < LESSONS.size() else ""


func _begin(i: int) -> void:
	lesson = i
	_display().show_hint(LESSONS[i], true, true)


func _complete(i: int) -> void:
	if i != lesson:
		return
	var id := LESSONS[i]
	_hide_banner()
	lesson = i + 1  # поки йде пауза, жоден рух не зараховується двічі
	lesson_done.emit(id)
	AudioManager.play(&"coin")
	if lesson == LESSONS.size():
		_stop()
		finished.emit()
		return
	lesson = -1
	await get_tree().create_timer(NEXT_DELAY, false).timeout
	_begin(i + 1)


func _on_hit(target: Node, _damage: int) -> void:
	if not target in enemies:
		return
	match lesson:
		0:
			if _combat.state == PlayerCombat.State.SWING:
				_complete(0)
		1:
			if _combat.state == PlayerCombat.State.SWING and _combat.combo_step == _combat.combo_length() - 1:
				_complete(1)
		5:
			if _combat.state == PlayerCombat.State.HEAVY_STRIKE:
				_complete(5)


## Парирування — теж блок (ідеальний), тож зараховує й урок блоку.
func _on_guard(_attacker: Node, parry: bool) -> void:
	if lesson == 3 or (lesson == 4 and parry):
		_complete(lesson)


## Ривок крізь удар: герой посеред ривка, а удар ворога поруч живий (хітбокс увімкнено на час удару).
func _physics_process(_delta: float) -> void:
	if lesson != 2 or not _mover.is_rolling():
		return
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.hitbox.monitoring \
				and enemy.global_position.distance_to(_player.global_position) <= DODGE_RANGE:
			_complete(2)
			return


func _keep_alive(health: int, max_health: int, _animate: bool, body: CombatBody2D) -> void:
	if health > 0 and health < max_health * SAFE_FRACTION:
		body.heal_damage(max_health)


func _bodies() -> Array[CombatBody2D]:
	var out: Array[CombatBody2D] = []
	if is_instance_valid(_player):
		out.append(_player)
	for enemy in enemies:
		if is_instance_valid(enemy):
			out.append(enemy)
	return out


func _stop() -> void:
	set_physics_process(false)
	for body: CombatBody2D in _bodies():
		body.min_health = 0
	for link: Array in _links:
		var sig: Signal = link[0]
		if not sig.is_null():
			sig.disconnect(link[1])
	_links.clear()


func _display() -> TutorialHintDisplay:
	return get_tree().get_first_node_in_group(&"tutorial_hint_display")


func _hide_banner() -> void:
	var display := _display()
	if display != null and display.current_hint in LESSONS:
		display.force_hide()


## Пішов із села посеред уроків — плашка йде разом із ним.
func _exit_tree() -> void:
	_hide_banner()
	_stop()
