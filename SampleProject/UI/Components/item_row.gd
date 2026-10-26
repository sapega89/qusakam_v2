extends "res://SampleProject/UI/Components/list_row.gd"
class_name UIItemRow

## Рядок списку предметів.
## Figma: UI/ListRow у кадрі menu-inventory (I355:6423;250:4983 / ;250:4988).
##
## Рядок — Button, тому фокус, hover, клавіатурна активація і робота з
## ButtonGroup дістаються безкоштовно. Вигляд задає варіація теми "ListRow".

## Один клік / переміщення фокуса — показати деталі.
signal row_selected(index: int)
## Подвійний клік або Enter — активувати (вдягнути / використати).
signal row_activated(index: int)

## Шляхи, а не %-імена: рядок — шаблон у сцені списку, і його копії (RowFill, D117) не несуть
## власника вкладеної сцени, тож %-імена в них не знаходяться.
@onready var _icon: TextureRect = $Row/IconBg/Icon
@onready var _icon_bg: Panel = $Row/IconBg
@onready var _name_label: Label = $Row/Text/NameLabel
@onready var _sub_label: Label = $Row/Text/SubLabel
@onready var _count_label: Label = $Row/CountLabel
## B152, D720: вдягнений предмет має знак «Equipped» (UI/Badge 222:4746 — LevelBadge з теми) перед кількістю.
@onready var _equipped_badge: Control = $Row/EquippedBadge

var index: int = -1



func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	_apply_icon_style()
	pressed.connect(_on_pressed)
	focus_entered.connect(_on_focus_entered)
	toggled.connect(func(_on: bool) -> void: _apply_icon_style())


## Рамка іконки зникає, коли рядок виділений (Figma: у виділеного рядка
## в іконки немає border). Обидва стилі — з теми: IconSlotFramed / IconSlot.
func _apply_icon_style() -> void:
	if _icon_bg:
		_icon_bg.theme_type_variation = &"IconSlot" if button_pressed else &"IconSlotFramed"


## [code]item[/code] — словник із _load_inventory_items(): id, name, desc, icon, count, equipped_slot ("" — не вдягнений).
func set_item(item: Dictionary, row_index: int) -> void:
	index = row_index
	_name_label.text = String(item.get("name", ""))
	_count_label.text = "×%d" % int(item.get("count", 0))
	var icon: Texture2D = item.get("icon")
	_icon.texture = icon
	_icon.visible = icon != null
	# Другий рядок у Figma порожній — лишаємо під майбутній підзаголовок.
	_sub_label.text = String(item.get("subtitle", ""))
	_sub_label.visible = not _sub_label.text.is_empty()
	_equipped_badge.visible = String(item.get("equipped_slot", "")) != ""


func is_equipped_shown() -> bool:
	return _equipped_badge.visible


func _on_pressed() -> void:
	row_selected.emit(index)


func _on_focus_entered() -> void:
	# Навігація стрілками теж має оновлювати панель деталей.
	row_selected.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			row_activated.emit(index)
			accept_event()
	elif event.is_action_pressed("ui_accept") and has_focus():
		row_activated.emit(index)
		accept_event()
