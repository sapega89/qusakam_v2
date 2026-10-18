extends Node2D

## Драбина (D225): вертикальна смуга, по якій герой лізе (PlayerMover). Початок вузла — верх драбини,
## [member height] — довжина вниз, px. Верх ставлять на рівні підлоги поверху над нею (там односторонній
## місток), низ — на підлогу поверху під нею. Розмітка — Ladder.tscn.

## Ширина смуги, в якій герой «на драбині», px.
const WIDTH := 24.0
## Вище за верх драбини ще стільки px — щоб герой, що стоїть на містку, міг почати спуск.
const TOP_REACH := 32.0

@export var height := 480.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(GameGroups.LADDERS)
	sprite.region_rect = Rect2(0, 0, sprite.texture.get_width(), height / sprite.scale.y)


## Точка [param point] (центр героя) на драбині?
func contains(point: Vector2) -> bool:
	var local := point - global_position
	return absf(local.x) <= WIDTH / 2.0 and local.y >= -TOP_REACH and local.y <= height
