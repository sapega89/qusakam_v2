extends Node2D

## Вартовий брами (D209): спрайт і NpcActivity без меню й підказки [E] — з ним не говорять самі.
## D571: каже своє мимохідь, коли герой проходить повз, — облачко D263, як у NpcBase (D338). Раз за появу в кімнаті.
## Порожній chatter_dialogue — мовчить (у Місті вартовим Ратуші гукає City.gd).

const GAME_PATH := "res://SampleProject/Scripts/Game.gd"

## .dqd з репліками мимохідь. Порожньо — вартовий мовчить.
@export var chatter_dialogue: String = ""
## Каже лише з цим прапорцем гри (порожньо — завжди): біля брами — коли бій і розмова після нього позаду.
@export var chatter_with_flag: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var chatter_zone: Area2D = $ChatterZone

## Репліку мимохідь уже сказано в цій кімнаті.
var _chatted: bool = false


func _ready() -> void:
	chatter_zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if chatter_dialogue == "" or _chatted or not body.is_in_group(GameGroups.PLAYER):
		return
	if chatter_with_flag != "" and not load(GAME_PATH).get_singleton().get_quest_flag(chatter_with_flag):
		return
	_chatted = ServiceLocatorHelper.get_service_locator().get_dialogue_manager().say_in_passing(
			self, chatter_dialogue, chatter_anchor())


## Вістря хвоста облачка — над верхнім краєм спрайта, посередині (як NpcBase.chatter_anchor).
func chatter_anchor() -> Vector2:
	var rect: Rect2 = sprite.get_rect()
	return sprite.transform * Vector2(rect.get_center().x, rect.position.y)
