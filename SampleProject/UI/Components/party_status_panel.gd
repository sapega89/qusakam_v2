extends PanelContainer
class_name UIPartyStatusPanel

## Права колонка ігрового меню: час гри, золото, картки партії.
## Figma: UI/Party Status Panel (104:490), UI/Party Character Card (324:6127).
##
## ⚠️ Модель даних неповна: у GameCharacter/CharacterAttributes немає HP/SP
## на персонажа, а рівень один глобальний (XPManager). Тому реальні цифри
## показуються лише для активного персонажа, решта отримує "—/—" і порожню
## смугу. Вигадані значення не підставляємо. Див. design/ui_visual_qa.md.

const MAX_CARDS := 4  # стільки карток у кадрі Figma

@onready var _playtime_value: Label = %PlaytimeValue
@onready var _gold_value: Label = %GoldValue
@onready var _cards: VBoxContainer = %Cards

var _inventory_manager: Node = null


func _ready() -> void:
	# Екрани з власною правою колонкою (Status) ховають панель через групу.
	add_to_group(&"ui_party_panel")
	custom_minimum_size.x = UITokens.PARTY_PANEL_WIDTH
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator:
		_inventory_manager = service_locator.get_inventory_manager()
	if _inventory_manager and _inventory_manager.has_signal("inventory_changed"):
		if not _inventory_manager.inventory_changed.is_connected(refresh):
			_inventory_manager.inventory_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_refresh_gold()
	_refresh_cards()


func set_playtime(text: String) -> void:
	_playtime_value.text = text


func _refresh_gold() -> void:
	if _inventory_manager == null:
		return
	# GoldDisplay рахує золото як предмет "coin" — лишаємо те саме джерело.
	_gold_value.text = "%s" % _format_thousands(_inventory_manager.get_item_count("coin"))


func _format_thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


func _refresh_cards() -> void:
	for child in _cards.get_children():
		child.queue_free()

	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator == null:
		return
	var character_manager: CharacterManager = service_locator.get_character_manager()
	if character_manager == null:
		return

	var characters: Dictionary = character_manager.get_all_characters()
	var active_id := ""
	if character_manager.has_method("get_active_character_id"):
		active_id = character_manager.get_active_character_id()

	# Активний персонаж першим — у нього єдиного є реальні HP/SP.
	var ids: Array = characters.keys()
	ids.sort()
	if active_id in ids:
		ids.erase(active_id)
		ids.push_front(active_id)

	var level := 1
	var xp_manager: XPManager = service_locator.get_xp_manager()
	if xp_manager and xp_manager.has_method("get_level"):
		level = xp_manager.get_level()

	for i in mini(ids.size(), MAX_CARDS):
		var id: String = ids[i]
		_cards.add_child(_make_card(characters[id], id == active_id, level))


func _make_card(character: Object, is_active: bool, level: int) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(UITokens.PARTY_CARD_WIDTH, 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SPACE_LG)
	card.add_child(row)

	# Портрет: справжнього арту ще немає, показуємо avatar_color персонажа.
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(UITokens.PORTRAIT_SIZE, UITokens.PORTRAIT_SIZE)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait_box := StyleBoxFlat.new()
	portrait_box.bg_color = character.get("avatar_color") if character.get("avatar_color") else UITokens.ICON_SLOT_BG
	portrait_box.set_corner_radius_all(UITokens.RADIUS)
	portrait_box.set_border_width_all(UITokens.BORDER_WIDTH)
	portrait_box.border_color = UITokens.ACCENT
	portrait.add_theme_stylebox_override("panel", portrait_box)
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = String(character.get("name"))
	name_label.theme_type_variation = &"CardName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(_level_badge(level))
	info.add_child(head)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", UITokens.SPACE_XS)
	info.add_child(bars)

	if is_active:
		var hp := _active_hp()
		bars.add_child(_stat_row("HP", hp.x, hp.y, UITokens.HP_FILL))
		# SP-моделі ще немає — показуємо порожньо, а не вигадані числа.
		bars.add_child(_stat_row("SP", -1, -1, UITokens.SP_FILL))
	else:
		bars.add_child(_stat_row("HP", -1, -1, UITokens.HP_FILL))
		bars.add_child(_stat_row("SP", -1, -1, UITokens.SP_FILL))

	return card


func _level_badge(level: int) -> Control:
	var badge := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UITokens.ACCENT
	box.set_corner_radius_all(UITokens.RADIUS)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", box)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var label := Label.new()
	label.text = "Lv.%d" % level
	label.theme_type_variation = &"MicroLabel"
	label.add_theme_color_override("font_color", UITokens.ON_ACCENT)
	badge.add_child(label)
	return badge


## current < 0 ⇒ даних немає: показуємо "—/—" і порожню смугу.
func _stat_row(label_text: String, current: int, maximum: int, fill: Color) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", UITokens.SPACE_2XS)

	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label_text
	name_label.theme_type_variation = &"StatLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)

	var value_label := Label.new()
	value_label.theme_type_variation = &"StatValue"
	value_label.text = "—/—" if current < 0 else "%d/%d" % [current, maximum]
	head.add_child(value_label)
	container.add_child(head)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(UITokens.BAR_WIDTH, UITokens.BAR_HEIGHT)
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(maximum))
	bar.value = 0.0 if current < 0 else float(current)
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = UITokens.SURFACE
	track_box.set_corner_radius_all(UITokens.RADIUS)
	bar.add_theme_stylebox_override("background", track_box)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(UITokens.RADIUS)
	bar.add_theme_stylebox_override("fill", fill_box)
	container.add_child(bar)
	return container


## HP активного персонажа беремо з наявної логіки GameManager.
func _active_hp() -> Vector2i:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator == null:
		return Vector2i(-1, -1)
	var gm: Node = service_locator.get_game_manager()
	if gm == null or not gm.has_method("calculate_max_health"):
		return Vector2i(-1, -1)
	var maximum: int = gm.calculate_max_health()
	var current := maximum
	if gm.has_method("get_current_player"):
		var player: Node = gm.get_current_player()
		if player:
			var health: Node = player.get_node_or_null("HealthComponent")
			if health and "current_health" in health:
				current = int(health.current_health)
	return Vector2i(current, maximum)
