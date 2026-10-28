extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## D864: небо жовте всюди, доки герой не вийде з Лабораторії; після виходу — синє (лор 2026-10-28: старші боги
## втекли, сонця немає; синє небо — експеримент магів летючого міста). Одне місце на всю гру: спільний матеріал
## sky_tint.tres перефарбовує площини неба, хмарам — кремовий відтінок. Прапорець виходу з Лабораторії
## (lab_outside_complete, D437 — його ставить сам вихід у двір) вимикає обидва: лишається намальоване синє небо.
## Площини неба: Plan5 обох задників (матеріал стоїть у їхніх .tscn) і в кімнатах ROOM_SKIES — їм матеріал дає apply().

const MATERIAL: ShaderMaterial = preload("res://SampleProject/Resources/Materials/sky_tint.tres")
const LAB_EXIT_FLAG := "lab_outside_complete"
## Небо, намальоване в самих кімнатах (Maps/*.tscn): Back/Sky — Polygon2D гірських і міських кімнат, HighSky —
## градієнт над Каньйоном і двором Лабораторії.
const ROOM_SKIES: Array[NodePath] = [^"Back/Sky", ^"HighSky"]
## Хмари — за текстурою: у них свій матеріал (depth_blur), тож відтінок іде через self_modulate.
const CLOUD_DIR := "res://SampleProject/Assets/Backgrounds/Clouds/"
const CLOUD_BANK := "res://SampleProject/Assets/Backgrounds/Canyon/gen_clouds.png"


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
	MATERIAL.set_shader_parameter(&"yellow", 0.0 if after_lab else 1.0)
	MATERIAL.set_shader_parameter(&"sky_deep", UITokens.SKY_DUST_DEEP)
	MATERIAL.set_shader_parameter(&"sky_pale", UITokens.SKY_DUST_PALE)
	for path in ROOM_SKIES:
		var sky := room.get_node_or_null(path) as CanvasItem
		if sky != null:
			sky.material = MATERIAL
	var cloud_tint: Color = Color.WHITE if after_lab else UITokens.SKY_CLOUD_CREAM
	for node in room.find_children("*", "Sprite2D", true, false):
		var texture: Texture2D = (node as Sprite2D).texture
		if texture != null and (texture.resource_path.begins_with(CLOUD_DIR) or texture.resource_path == CLOUD_BANK):
			(node as Sprite2D).self_modulate = cloud_tint


## Чи небо зараз жовте (для перевірок).
static func is_yellow() -> bool:
	return MATERIAL.get_shader_parameter(&"yellow") == 1.0
