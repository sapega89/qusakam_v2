@tool
extends Sprite2D

## Намальований вхід у кімнату (M12, room_art_audit): двері, печера, ворота частоколу, прохід у скелі Мези, двері
## палацу, залізні двері лабораторії — один кадр із Decor/<name>/<name>_sheet.png у масштабі гри 1.5. Початок вузла —
## низ посередині арту: його ставлять на підлогу під дверима (RoomDoor), а RoomDoor — у отвір ([method opening_rect]).
## Розмітка — room_entrance.tscn; яку арку малювати, каже [member texture].

## Отвір кожного арту в px кадру (темний прохід / стулки дверей): x, y, ширина, висота.
const OPENINGS := {
	"door_elder": Rect2(14, 7, 22, 56),
	"cave_mouth": Rect2(34, 38, 30, 52),
	"palisade_gate": Rect2(69, 26, 20, 56),
	"mesa_cleft": Rect2(39, 30, 23, 49),
	"palace_door": Rect2(32, 11, 36, 74),
	"lab_door": Rect2(14, 6, 33, 65),
}
## Масштаб кожного арту: двері 112 px арту = 168 px світу (D814, B192, prop-sizes) — висота кадру × масштаб у межах
## ±1.5 px. mesa_cleft перерізано до 112 рядків, тож лишається 1.5.
const SCALES := {
	"door_elder": 2.21,
	"cave_mouth": 1.68,
	"palisade_gate": 1.93,
	"mesa_cleft": 1.5,
	"palace_door": 1.615,
	"lab_door": 1.91,
}


func _ready() -> void:
	centered = false
	scale = Vector2.ONE * float(SCALES[art_name()])
	offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())


## Назва арту — тека в Decor (door_elder, cave_mouth, ...).
func art_name() -> String:
	return texture.resource_path.get_base_dir().get_file()


## Отвір у глобальних координатах.
func opening_rect() -> Rect2:
	var r: Rect2 = OPENINGS[art_name()]
	return global_transform * Rect2(r.position + offset, r.size)

