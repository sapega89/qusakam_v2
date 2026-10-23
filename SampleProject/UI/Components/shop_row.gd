extends Button
class_name ShopRow

## Рядок товару магазину. Figma: рядки списку в shop-buy 153:1289 / shop-sell 153:1523.
## [іконка · назва] [кількість 120] [ціна 150]. Вибраний (фокус/наведення) — заливка accent
## з темним текстом (правило D26: Figma малює accent на accent, текст невидимий).

signal row_focused(data: Dictionary)
signal row_activated(data: Dictionary)

var data: Dictionary = {}
var sellable := true
## Не вистачає золота (D105): рядок сірий, але фокус лишається — опис видно, купити не можна.
var affordable := true
## Рядок, по якому відкрито модалку: вибраний вигляд лишається, хоч фокус і пішов (B24).
var _held := false

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %NameLabel
@onready var _detail: Label = %DetailLabel
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
	pressed.connect(func(): if affordable: row_activated.emit(data))
	_apply_style(false)


## [param price_enabled] = false — ціни немає (не продається): рядок видно, але вимкнено.
func setup(row: Dictionary, price_enabled: bool = true, can_afford: bool = true) -> void:
	data = row
	sellable = price_enabled
	affordable = can_afford
	_icon.texture = row.get("icon")
	_name.text = str(row.get("name", ""))
	# Рецепт крафту: другий рядок "Requires: …" і вищий рядок; у магазині його немає.
	_detail.text = str(row.get("detail", ""))
	_detail.visible = not _detail.text.is_empty()
	custom_minimum_size.y = UITokens.CRAFT_ROW_HEIGHT if _detail.visible else UITokens.SHOP_ROW_HEIGHT
	_count.text = str(row.get("count", 0))
	_price.text = ShopService.format_price(int(row.get("price", 0))) if price_enabled else "—"
	disabled = not price_enabled
	focus_mode = FOCUS_ALL if price_enabled else FOCUS_NONE
	_apply_style(has_focus())


## Модалка забирає фокус; рядок лишається вибраним, доки список не перебудують.
func hold_selected() -> void:
	_held = true
	theme_type_variation = &"ShopRowOn"
	_apply_style(true)


func _on_focus(focused: bool) -> void:
	_apply_style(focused or _held)
	if focused:
		row_focused.emit(data)


func _apply_style(on: bool) -> void:
	_detail.theme_type_variation = &"ShopRowDetailOn" if on else &"ShopRowDetail"
	_count.theme_type_variation = &"ShopRowCountOn" if on else &"ShopRowCount"
	if not sellable or not affordable:
		# D433: сіра й ціна — саме через неї рядок недоступний; на заливці accent — свій сірий.
		_name.theme_type_variation = &"ShopRowDisabledOn" if on else &"ShopRowDisabled"
		_price.theme_type_variation = &"ShopRowPriceDisabledOn" if on else &"ShopRowPriceDisabled"
		return
	_name.theme_type_variation = &"ShopRowNameOn" if on else &"ShopRowName"
	_price.theme_type_variation = &"ShopRowPriceOn" if on else &"ShopRowPrice"
