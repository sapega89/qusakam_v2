extends Node2D

## Знак над головою NPC, у якого є що взяти (D442, D452): жовтий «!» — сюжетний квест, синій «!» — побічний,
## срібний герб — клятва (професія). Піксельний, малюється кодом за візерунком нижче, кольори з UITokens.
## Розмір екранний (world_ui.gd): камера збільшує світ, знак — ні. Низ знака — у точці вузла, по центру.

const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")

## Візерунки: «o» — обвідка, «x» — колір знака, «.» — порожньо.
const EXCLAIM: PackedStringArray = [
	"oooo",
	"oxxo",
	"oxxo",
	"oxxo",
	"oxxo",
	"oxxo",
	"oooo",
	"oxxo",
	"oxxo",
	"oooo",
]
## Щит із хрестом — герб хранителя клятви.
const CREST: PackedStringArray = [
	"ooooooo",
	"oxxoxxo",
	"oxxoxxo",
	"ooooooo",
	"oxxoxxo",
	".oxoxo.",
	".oxoxo.",
	"..ooo..",
	"...o...",
]

const COLORS := {
	&"story": UITokens.QUEST_MARK_STORY,
	&"side": UITokens.QUEST_MARK_SIDE,
	&"oath": UITokens.QUEST_MARK_OATH,
}

## &"story", &"side", &"oath" або &"" — знака немає.
var kind: StringName = &"":
	set(value):
		kind = value
		visible = kind != &""
		queue_redraw()


func _ready() -> void:
	scale = WORLD_UI.screen_scale(self)
	visible = kind != &""


## Візерунок поточного знака.
func pattern() -> PackedStringArray:
	return CREST if kind == &"oath" else EXCLAIM


func _draw() -> void:
	if kind == &"":
		return
	var rows := pattern()
	var px := float(UITokens.QUEST_MARK_PIXEL)
	var origin := Vector2(-rows[0].length() * px * 0.5, -rows.size() * px)
	for y in rows.size():
		for x in rows[y].length():
			var cell := rows[y][x]
			if cell == ".":
				continue
			var color: Color = UITokens.QUEST_MARK_OUTLINE if cell == "o" else COLORS[kind]
			draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), color)
