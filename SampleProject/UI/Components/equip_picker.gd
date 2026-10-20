extends Control

## Вибір предмета для слота екіпіровки (BACKLOG 11, D288). Відкривається через
## ModalLayer.show_custom_modal(), дані — show_slot(). Закривається сигналом chosen:
## id предмета, "unequip" або "cancel" (B / Esc, кнопка Cancel).
## Рядки — спільний UIItemRow; клік, Enter / A або подвійний клік обирають.

signal chosen(result: String)

const ITEM_ROW_SCENE := preload("res://SampleProject/UI/Components/item_row.tscn")

@onready var _title: Label = %Title
@onready var _empty: Label = %Empty
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _unequip: Button = %UnequipButton
@onready var _cancel: Button = %CancelButton

var _ids: Array[String] = []


func _ready() -> void:
	_unequip.pressed.connect(chosen.emit.bind("unequip"))
	_cancel.pressed.connect(chosen.emit.bind("cancel"))


## [param items] — записи {id, name, icon, count, subtitle}; [param can_unequip] — у слоті щось є.
func show_slot(title: String, items: Array, can_unequip: bool) -> void:
	_title.text = title
	_empty.visible = items.is_empty()
	_scroll.visible = not items.is_empty()
	_unequip.visible = can_unequip
	for i in items.size():
		var row: UIItemRow = ITEM_ROW_SCENE.instantiate()
		_list.add_child(row)
		row.set_item(items[i], i)
		_ids.append(String(items[i].id))
		row.pressed.connect(_pick.bind(i))
		row.row_activated.connect(_pick)
	var first: Control = _list.get_child(0) if not items.is_empty() else _cancel
	first.grab_focus.call_deferred()


func _pick(index: int) -> void:
	chosen.emit(_ids[index])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit("cancel")
