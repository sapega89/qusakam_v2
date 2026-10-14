extends Button
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

@onready var _icon: TextureRect = %Icon
@onready var _icon_bg: Panel = %IconBg
@onready var _name_label: Label = %NameLabel
@onready var _sub_label: Label = %SubLabel
@onready var _count_label: Label = %CountLabel

var index: int = -1

## Рамка іконки зникає, коли рядок виділений (Figma: у виділеного рядка
## в іконки немає border).
var _icon_box_normal: StyleBoxFlat
var _icon_box_selected: StyleBoxFlat


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	_build_icon_styles()
	_apply_icon_style()
	pressed.connect(_on_pressed)
	focus_entered.connect(_on_focus_entered)
	toggled.connect(func(_on: bool) -> void: _apply_icon_style())


func _build_icon_styles() -> void:
	_icon_box_normal = StyleBoxFlat.new()
	_icon_box_normal.bg_color = UITokens.ICON_SLOT_BG
	_icon_box_normal.set_corner_radius_all(UITokens.RADIUS)
	_icon_box_normal.set_border_width_all(UITokens.BORDER_WIDTH)
	_icon_box_normal.border_color = UITokens.BORDER

	_icon_box_selected = StyleBoxFlat.new()
	_icon_box_selected.bg_color = UITokens.ICON_SLOT_BG
	_icon_box_selected.set_corner_radius_all(UITokens.RADIUS)


func _apply_icon_style() -> void:
	if _icon_bg:
		_icon_bg.add_theme_stylebox_override("panel",
				_icon_box_selected if button_pressed else _icon_box_normal)


## [code]item[/code] — словник із _load_inventory_items(): id, name, desc, icon, count.
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
