extends Button
class_name ShopRow

## Рядок товару магазину. Figma: рядки списку в shop-buy 153:1289 / shop-sell 153:1523.
## [іконка · назва] [кількість 120] [ціна 150]. Вибраний (фокус/наведення) — заливка accent
## з темним текстом (правило D26: Figma малює accent на accent, текст невидимий).

signal row_focused(data: Dictionary)
signal row_activated(data: Dictionary)

var data: Dictionary = {}
var sellable := true

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %NameLabel
@onready var _count: Label = %CountLabel
@onready var _price: Label = %PriceLabel


func _ready() -> void:
	custom_minimum_size.y = UITokens.SHOP_ROW_HEIGHT
	_icon.custom_minimum_size = Vector2(UITokens.SHOP_ROW_ICON, UITokens.SHOP_ROW_ICON)
	_count.custom_minimum_size.x = UITokens.SHOP_COL_COUNT
	_price.custom_minimum_size.x = UITokens.SHOP_COL_PRICE
	focus_entered.connect(_on_focus.bind(true))
	focus_exited.connect(_on_focus.bind(false))
	mouse_entered.connect(func(): if focus_mode != FOCUS_NONE: grab_focus())
	pressed.connect(func(): row_activated.emit(data))
	_apply_style(false)


## [param price_enabled] = false — ціни немає (не продається): рядок видно, але вимкнено.
func setup(row: Dictionary, price_enabled: bool = true) -> void:
	data = row
	sellable = price_enabled
	_icon.texture = row.get("icon")
	_name.text = str(row.get("name", ""))
	_count.text = str(row.get("count", 0))
	_price.text = ShopService.format_price(int(row.get("price", 0))) if price_enabled else "—"
	disabled = not price_enabled
	focus_mode = FOCUS_ALL if price_enabled else FOCUS_NONE
	_apply_style(has_focus())


func _on_focus(focused: bool) -> void:
	_apply_style(focused)
	if focused:
		row_focused.emit(data)


func _apply_style(on: bool) -> void:
	if not sellable:
		_name.theme_type_variation = &"ShopRowDisabled"
		_count.theme_type_variation = &"ShopRowCount"
		_price.theme_type_variation = &"ShopRowCount"
		return
	_name.theme_type_variation = &"ShopRowNameOn" if on else &"ShopRowName"
	_count.theme_type_variation = &"ShopRowCountOn" if on else &"ShopRowCount"
	_price.theme_type_variation = &"ShopRowPriceOn" if on else &"ShopRowPrice"
