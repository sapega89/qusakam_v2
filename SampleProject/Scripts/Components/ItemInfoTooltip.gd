extends PanelContainer
class_name ItemInfoTooltip

## 📋 ItemInfoTooltip - Базовий компонент для відображення інформації про предмет
## Може використовуватися в магазині, інвентарі, екіпіровці, кузні тощо

# Посилання на вузли
@onready var item_name_label: Label = $VBoxContainer/ItemName
@onready var item_description_label: RichTextLabel = $VBoxContainer/ItemDescription
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var phys_def_label: Label = $VBoxContainer/StatsContainer/PhysDefLabel
@onready var elem_def_label: Label = $VBoxContainer/StatsContainer/ElemDefLabel
@onready var attack_label: Label = $VBoxContainer/StatsContainer/AttackLabel
@onready var magic_label: Label = $VBoxContainer/StatsContainer/MagicLabel
@onready var price_container: HBoxContainer = $VBoxContainer/PriceContainer
@onready var buy_price_label: Label = $VBoxContainer/PriceContainer/BuyPriceLabel
@onready var sell_price_label: Label = $VBoxContainer/PriceContainer/SellPriceLabel

# Посилання на ItemDatabase
var item_database: Node = null

func _ready():
	# Отримуємо ItemDatabase через ServiceLocator
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_item_database"):
			item_database = service_locator.get_item_database()
	if not item_database:
		push_warning("⚠️ ItemInfoTooltip: ItemDatabase not found!")

## Оновлює інформацію про предмет
## item_id: ID предмета
## show_price: чи показувати ціни (для магазину)
func update_item_info(item_id: String, show_price: bool = false) -> void:
	if not item_database:
		return
	
	var item = item_database.get_item(item_id)
	if item.is_empty():
		hide()
		return
	
	# Назва предмета
	if item_name_label:
		var item_name = item_database.get_item_name(item_id, "en")
		item_name_label.text = item_name
	
	# Опис предмета
	if item_description_label:
		var item_desc = item_database.get_item_description(item_id, "en")
		item_description_label.text = "[color=white]" + item_desc + "[/color]"
	
	# Характеристики
	_update_stats(item)
	
	# Ціни (якщо потрібно)
	if show_price:
		_update_prices(item)
		if price_container:
			price_container.visible = true
	else:
		if price_container:
			price_container.visible = false
	
	# Показуємо tooltip
	visible = true

## Оновлює характеристики предмета
func _update_stats(item: Dictionary) -> void:
	if not stats_container:
		return
	
	var has_stats = false
	
	# Phys. Def.
	var phys_def: int = 0
	if item.has("stats") and item.stats.has("defense"):
		phys_def = int(item.stats.defense)
	elif item.has("phys_def"):
		phys_def = int(item.phys_def)
	
	if phys_def_label:
		if phys_def > 0:
			phys_def_label.text = "Phys. Def. +%d" % phys_def
			phys_def_label.visible = true
			has_stats = true
		else:
			phys_def_label.visible = false
	
	# Elem. Def.
	var elem_def: int = 0
	if item.has("stats") and item.stats.has("magic_defense"):
		elem_def = int(item.stats.magic_defense)
	elif item.has("elem_def"):
		elem_def = int(item.elem_def)
	
	if elem_def_label:
		if elem_def > 0:
			elem_def_label.text = "Elem. Def. +%d" % elem_def
			elem_def_label.visible = true
			has_stats = true
		else:
			elem_def_label.visible = false
	
	# Attack
	var attack: int = 0
	if item.has("stats") and item.stats.has("attack"):
		attack = int(item.stats.attack)
	
	if attack_label:
		if attack > 0:
			attack_label.text = "Attack +%d" % attack
			attack_label.visible = true
			has_stats = true
		else:
			attack_label.visible = false
	
	# Magic
	var magic: int = 0
	if item.has("stats") and item.stats.has("magic"):
		magic = int(item.stats.magic)
	
	if magic_label:
		if magic > 0:
			magic_label.text = "Magic +%d" % magic
			magic_label.visible = true
			has_stats = true
		else:
			magic_label.visible = false
	
	# Показуємо контейнер характеристик, якщо є хоча б одна
	stats_container.visible = has_stats

## Оновлює ціни предмета
func _update_prices(item: Dictionary) -> void:
	var buy_price: int = 0
	var sell_price: int = 0
	
	if item.has("buy_price"):
		buy_price = int(item.buy_price)
	if item.has("sell_price"):
		sell_price = int(item.sell_price)
	
	if buy_price_label:
		buy_price_label.text = "Buy: %d" % buy_price
	
	if sell_price_label:
		sell_price_label.text = "Sell: %d" % sell_price

## Ховає tooltip
func hide_tooltip() -> void:
	visible = false

