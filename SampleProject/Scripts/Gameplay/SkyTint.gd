extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## D864: небо жовте всюди, доки герой не вийде з Лабораторії; після виходу — синє (лор 2026-10-28: старші боги
## втекли, сонця немає; синє небо — експеримент магів летючого міста). Одне місце на всю гру: спільні матеріали
## неба (sky_tint*.tres) і хмар (sky_clouds*.tres), їхні параметри ставить лише apply(). Прапорець виходу з
## Лабораторії (lab_outside_complete, D437 — його ставить сам вихід у двір) вимикає перефарбування: лишається
## намальоване синє небо й білі хмари.
## Матеріали стоять у спільних сценах (Plan5 і хмари обох задників, drifting_clouds.tscn); небу й хмарам, намальованим
## у самих кімнатах (Maps/*.tscn), apply() дає їх на вході в кімнату.

const SKY: ShaderMaterial = preload("res://SampleProject/Resources/Materials/sky_tint.tres")
## Той самий шейдер, але перефарбовує лише блакитне світле небо всередині картинки (скелі довкола не чіпає).
const SKY_KEYED: ShaderMaterial = preload("res://SampleProject/Resources/Materials/sky_tint_keyed.tres")
## Хмари з розмиттям глибини (задники) і без нього (високе небо кімнат).
const CLOUDS_FAR: ShaderMaterial = preload("res://SampleProject/Resources/Materials/sky_clouds_far.tres")
const CLOUDS: ShaderMaterial = preload("res://SampleProject/Resources/Materials/sky_clouds.tres")
const LAB_EXIT_FLAG := "lab_outside_complete"
## Небо, намальоване в самих кімнатах: Back/Sky — Polygon2D гірських і міських кімнат, HighSky — градієнт над
## Каньйоном і двором Лабораторії.
const ROOM_SKIES: Array[NodePath] = [^"Back/Sky", ^"HighSky"]
## Хмари в кімнатах — за текстурою (HighClouds Каньйону й двору Лабораторії).
const CLOUD_BANK := "res://SampleProject/Assets/Backgrounds/Canyon/gen_clouds.png"
## Текстури з небом, запеченим у саму картинку: каньйон за печерою (печери під мостом, ящірок, дно каньйону…) і
## дюни табору бандитів.
const BAKED_SKY: Array[String] = [
	"res://SampleProject/Assets/Backgrounds/LizardCave/gen_far.png",
	"res://SampleProject/Assets/Backgrounds/BanditCamp/gen_far.png",
	"res://SampleProject/Assets/Backgrounds/BridgeCave/gen_wall.png",  # D872: печера під мостом, небо в пащі вгорі ліворуч
]


func _initialize() -> void:
	game.room_loaded.connect(_on_room_loaded)
	(game as Game).quest_flag_changed.connect(_on_quest_flag_changed)


func _on_room_loaded() -> void:
	apply(game.map, (game as Game).get_quest_flag(LAB_EXIT_FLAG) == true)


## Двір Лабораторії ставить прапорець уже в кімнаті — небо синіє одразу, а не з наступною кімнатою.
func _on_quest_flag_changed(quest_id: String, value: Variant) -> void:
	if quest_id == LAB_EXIT_FLAG and game.map != null:
		apply(game.map, value == true)


## Небо [param room]: жовте, або синє як намальоване, якщо [param after_lab].
static func apply(room: Node, after_lab: bool) -> void:
	var amount: float = 0.0 if after_lab else 1.0
	for sky: ShaderMaterial in [SKY, SKY_KEYED]:
		sky.set_shader_parameter(&"yellow", amount)
		sky.set_shader_parameter(&"sky_deep", UITokens.SKY_DUST_DEEP)
		sky.set_shader_parameter(&"sky_pale", UITokens.SKY_DUST_PALE)
	for clouds: ShaderMaterial in [CLOUDS_FAR, CLOUDS]:
		clouds.set_shader_parameter(&"cream", amount)
		clouds.set_shader_parameter(&"cream_light", UITokens.SKY_CLOUD_CREAM)
		clouds.set_shader_parameter(&"cream_shade", UITokens.SKY_CLOUD_SHADE)
	for path in ROOM_SKIES:
		var sky := room.get_node_or_null(path) as CanvasItem
		if sky != null:
			sky.material = SKY
	for node in room.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null:
			continue
		if sprite.texture.resource_path == CLOUD_BANK and sprite.material == null:
			sprite.material = CLOUDS
		elif sprite.texture.resource_path in BAKED_SKY:
			sprite.material = SKY_KEYED


## Чи небо зараз жовте (для перевірок).
static func is_yellow() -> bool:
	return SKY.get_shader_parameter(&"yellow") == 1.0
