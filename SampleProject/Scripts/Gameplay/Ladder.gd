extends Node2D

## Драбина (D225): вертикальна смуга, по якій герой лізе (PlayerMover). Початок вузла — верх драбини,
## [member height] — довжина вниз, px. Верх ставлять на рівні підлоги поверху над нею (там односторонній
## місток), низ — на підлогу поверху під нею. Розмітка — Ladder.tscn.
## Вигляд — у стилі тла (A14, Sapega 2026-10-26: «драбини мають бути в стилі гри»): один період щаблів арту
## Decor/ladder_<art> повторюється вниз на всю висоту, у масштабі гри 1.5.
## Над верхом драбина ще трохи стирчить (B201, Sapega 2026-10-28: «обрізаної підлоги не має бути»): підлога над нею
## ціла, без дірки, а драбина стоїть за нею й виходить вище — поручні не обрізані. Тільки вигляд: смуга contains() та сама.

## Ширина смуги, в якій герой «на драбині», px.
const WIDTH := 24.0
## Вище за верх драбини ще стільки px — щоб герой, що стоїть на містку, міг почати спуск.
const TOP_REACH := 32.0
const SCALE := 1.5
## Матеріал за кімнатою: дерево надворі й у хатах, залізні скоби в камені — у лабораторії й підвалі.
## period — рядки кадру, що повторюються без шва (один щабель); rise — скільки щаблів видно над верхом.
const ART := {
	"wood": {"texture": preload("res://SampleProject/Assets/Backgrounds/Decor/ladder_wood/ladder_wood_sheet.png"), "period": Rect2(0, 51, 26, 9), "rise": 3},
	"iron": {"texture": preload("res://SampleProject/Assets/Backgrounds/Decor/ladder_iron/ladder_iron_sheet.png"), "period": Rect2(0, 83, 26, 20), "rise": 1},
}

@export var height := 480.0
@export_enum("wood", "iron") var art: String = "wood"


func _ready() -> void:
	add_to_group(GameGroups.LADDERS)
	queue_redraw()


func _draw() -> void:
	var texture: Texture2D = ART[art].texture
	var period: Rect2 = ART[art].period
	var step: float = period.size.y * SCALE
	var y: float = -step * ART[art].rise
	while y < height:
		var h: float = minf(step, height - y)
		draw_texture_rect_region(texture, Rect2(-period.size.x * SCALE / 2.0, y, period.size.x * SCALE, h),
				Rect2(period.position, Vector2(period.size.x, h / SCALE)))
		y += step


## Точка [param point] (центр героя) на драбині?
func contains(point: Vector2) -> bool:
	var local := point - global_position
	return absf(local.x) <= WIDTH / 2.0 and local.y >= -TOP_REACH and local.y <= height
