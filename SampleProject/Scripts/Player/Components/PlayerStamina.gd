extends Node

## Витривалість героя (D504, як у Salt and Sanctuary): її витрачають удари, перекат і удар, прийнятий на блок.
## Відновлюється, коли герой перестав діяти: через REGEN_DELAY с після останньої дії, REGEN за секунду (у блоці —
## частка BLOCK_REGEN). Порожня — перекату немає, блок слабкий (Player.take_damage). Числа попередні.

const MAX := 100.0
const COST_LIGHT := 12.0
const COST_HEAVY := 25.0
const COST_SHOT := 8.0
const COST_ROLL := 20.0
const COST_BLOCK := 15.0
const REGEN := 60.0
const REGEN_DELAY := 0.5
const BLOCK_REGEN := 0.3

var current: float = MAX
## Скільки ще чекати, поки витривалість почне відновлюватись.
var _delay: float = 0.0

@onready var player: CharacterBody2D = get_parent()


func spend(cost: float) -> void:
	current = maxf(0.0, current - cost)
	_delay = REGEN_DELAY
	_emit()


func is_empty() -> bool:
	return current <= 0.0


## Повна (воскресіння, нова кімната після поразки).
func refill() -> void:
	current = MAX
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
	current = minf(MAX, current + REGEN * delta * (BLOCK_REGEN if combat.is_blocking() else 1.0))
	_emit()


func _emit() -> void:
	EventBus.player_stamina_changed.emit(roundi(current), roundi(MAX))
