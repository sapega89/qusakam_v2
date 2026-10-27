extends Node

## Витривалість героя (D537, повернута Sapega 2026-10-27, D776). Її витрачають легкий і важкий удари, постріли,
## перекат, блок (підняти щит — BLOCK_RAISE, кожен прийнятий удар — COST_BLOCK) . Відновлюється швидко, коли герой
## REGEN_DELAY с нічого не витрачав: REGEN за секунду (вага обладунку змінює темп), а поки блок тримають — лише
## BLOCK_REGEN цього. Дійшла до нуля — герой виснажений: ні удару, ні пострілу,
## ні перекату, доки шкала не набере RECOVER_AT; спроба — спалах шкали й звук (EventBus.player_stamina_refused), а не
## тиша. Блок на порожній шкалі слабкий (Player.take_damage). Числа — design/cloud_reports/stamina-poise.md.

const ArmourWeight := preload("res://SampleProject/Scripts/Systems/ArmourWeight.gd")
const Charms := preload("res://SampleProject/Scripts/Systems/Charms.gd")

const MAX := 100.0
const COST_LIGHT := 18.0
const COST_HEAVY := 30.0
const COST_SHOT := 10.0
const COST_CHARGED := 25.0
const COST_ROLL := 22.0
const COST_BLOCK := 10.0
## Підняти блок; поки його тримають, шкала набирається лише з цією часткою темпу.
const BLOCK_RAISE := 5.0
const BLOCK_REGEN := 0.5
const REGEN := 100.0
const REGEN_DELAY := 0.4
## Виснажений герой знову діє, щойно шкала набрала стільки.
const RECOVER_AT := 30.0

var current: float = MAX
## Шкала дійшла до нуля й ще не набрала RECOVER_AT.
var exhausted: bool = false
## Скільки ще чекати, поки витривалість почне відновлюватись.
var _delay: float = 0.0

@onready var player: CharacterBody2D = get_parent()


## Дія вартістю [param cost]: true — можна (і списано); false — герой виснажений, дію відмовлено зі спалахом і звуком.
func try_spend(cost: float) -> bool:
	if exhausted:
		EventBus.player_stamina_refused.emit()
		return false
	spend(cost)
	return true


## Чи можна почати дію (без списання) — для дій, що платять пізніше (натяг лука платить на пострілі).
func can_act() -> bool:
	if exhausted:
		EventBus.player_stamina_refused.emit()
	return not exhausted


## [param pause] — відкласти відновлення на REGEN_DELAY (усе, крім підняття блоку: його ціна відновлення не спиняє, інакше
## блок на кожну підказку тримав би шкалу порожньою).
func spend(cost: float, pause: bool = true) -> void:
	current = maxf(0.0, current - cost)
	if pause:
		_delay = REGEN_DELAY
	if current <= 0.0:
		exhausted = true
	_emit()


func is_empty() -> bool:
	return current <= 0.0


## Ціна перекату: вага обладунку (D592) і оберіг Sand Runner's Ring.
func roll_cost() -> float:
	var mover: Node = player.mover
	return COST_ROLL * maxf(0.0, 1.0 + ArmourWeight.roll_stamina_of(mover.worn_armour()) + Charms.effect(&"roll_stamina"))


## Повна (воскресіння, нова кімната після поразки).
func refill() -> void:
	current = MAX
	exhausted = false
	_delay = 0.0
	_emit()


func _physics_process(delta: float) -> void:
	var combat: PlayerCombat = player.combat
	if player.mover.is_rolling() or combat.state not in [PlayerCombat.State.READY, PlayerCombat.State.BLOCK]:
		_delay = REGEN_DELAY
		return
	if _delay > 0.0:
		_delay -= delta
		return
	if current >= MAX:
		return
	var rate: float = REGEN * (1.0 + ArmourWeight.stamina_regen_of(player.mover.worn_armour())) \
			* (BLOCK_REGEN if combat.is_blocking() else 1.0)
	current = minf(MAX, current + rate * delta)
	if exhausted and current >= RECOVER_AT:
		exhausted = false
	_emit()


func _emit() -> void:
	EventBus.player_stamina_changed.emit(current, MAX, exhausted)
