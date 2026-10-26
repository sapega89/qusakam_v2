extends Node2D

## 🏙️ Місто (D488): двері до зали мера (MayorHallDoor — двері палацу між вартовими) зачинені, доки герой не дав клятву
## (player_state.oath, D280; хранителі клятв у місті — з 5-го рівня). Біля дверей двоє вартових у вигляді
## вартових воріт (D449); підійшов без клятви — правий каже в облачку, що до мера пускають лише присяглих,
## а ціль веде до хранителів клятв. Між містом і залою — двері, а не край кімнати (room_art_audit): MayorHallGate на
## східному краї — стіна, що лишається завжди.

const GUARD_LINE := "res://dialogue_quest/City_MayorHall_Guard.dqd"
const OATH_OBJECTIVE := "Swear an oath with the oath keepers"
## Ціль після клятви — та сама, що місто дає з воріт (CityGates.gd).
const AFTER_OATH_OBJECTIVE := "Find the laboratory"

@onready var door: RoomDoor = $MayorHallDoor
@onready var guard: Node2D = $GuardRight


func _ready() -> void:
	EventBus.oath_sworn.connect(_on_oath_sworn)
	$GateTalk.body_entered.connect(_on_gate_talk_entered)
	_update_gate()
	if not is_gate_open():
		Game.get_singleton().set_objective(OATH_OBJECTIVE, &"oath_keepers")


func is_gate_open() -> bool:
	return ServiceLocator.get_skill_manager().get_oath() != ""


func _update_gate() -> void:
	door.interactable.enabled = is_gate_open()


func _on_oath_sworn(_oath_id: String) -> void:
	_update_gate()
	Game.get_singleton().set_objective(AFTER_OATH_OBJECTIVE)


## Герой без клятви підійшов до дверей — вартовий каже своє мимохідь, ціль знову на хранителів клятв.
func _on_gate_talk_entered(body: Node2D) -> void:
	if not body.is_in_group(GameGroups.PLAYER) or is_gate_open():
		return
	ServiceLocator.get_dialogue_manager().say_in_passing(guard, GUARD_LINE, guard_anchor())
	Game.get_singleton().set_objective(OATH_OBJECTIVE, &"oath_keepers")


## Вістря хвоста облачка — над верхнім краєм спрайта вартового, посередині (як NpcBase.chatter_anchor).
func guard_anchor() -> Vector2:
	var sprite: Sprite2D = guard.get_node(^"Sprite2D")
	var rect: Rect2 = sprite.get_rect()
	return sprite.transform * Vector2(rect.get_center().x, rect.position.y)
