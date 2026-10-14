extends Control
class_name RecipePanel

## Панель рецепта (Figma UI/Recipe Confirmation Panel 217:2189, у кадрі 164:2326).
## Відкривається через ModalLayer.show_custom_modal: A/Enter → confirmed, B/Esc → cancelled.
## Дані — рядок CraftingService.row(): name, materials [{name, have, need}], stats [{label, value}].

signal confirmed
signal cancelled

@onready var _title: Label = %Title
@onready var _materials: VBoxContainer = %Materials
@onready var _stats_box: PanelContainer = %StatsBox
@onready var _stats: VBoxContainer = %Stats


func show_recipe(row: Dictionary) -> void:
	_title.text = tr("%s Recipe") % row.name
	for child in _materials.get_children() + _stats.get_children():
		child.queue_free()
	for m in row.materials:
		_materials.add_child(_material_line(m))
	for s in row.stats:
		_stats.add_child(_pair(str(s.label), str(s.value), &"StatValue"))
	_stats_box.visible = not row.stats.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		confirmed.emit()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()


## [✓ назва ........ треба / є] (Figma: "Iron Ore 3 / 10" при "Requires: 3 Iron Ore").
## Зелена ✓ — матеріалу вистачає; без неї рядок приглушений.
func _material_line(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var enough: bool = m.have >= m.need
	var line := _pair(str(m.name), "%d / %d" % [m.need, m.have], &"ListRowTitle" if enough else &"MutedLabel")
	var mark := Label.new()
	mark.text = "✓" if enough else "✗"
	mark.theme_type_variation = &"StatusIncrease" if enough else &"MutedLabel"
	line.add_child(mark)
	line.move_child(mark, 0)
	card.add_child(line)
	return card


func _pair(left: String, right: String, variation: StringName) -> HBoxContainer:
	var line := HBoxContainer.new()
	var a := Label.new()
	a.text = left
	a.theme_type_variation = variation
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := Label.new()
	b.text = right
	b.theme_type_variation = &"MutedLabel"
	line.add_child(a)
	line.add_child(b)
	return line
