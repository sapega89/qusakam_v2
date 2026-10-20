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
## Картки — шаблон %Card зі сцени (D117).
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")

@onready var _playtime_value: Label = %PlaytimeValue
@onready var _gold_value: Label = %GoldValue
@onready var _cards: VBoxContainer = %Cards
@onready var _card: PanelContainer = %Card

var _inventory_manager: Node = null


func _ready() -> void:
	# Екрани з власною правою колонкою (Status) ховають панель через групу.
	add_to_group(&"ui_party_panel")
	custom_minimum_size.x = UITokens.PARTY_PANEL_WIDTH
	_inventory_manager = ServiceLocator.get_inventory_manager()
	if not _inventory_manager.inventory_changed.is_connected(refresh):
		_inventory_manager.inventory_changed.connect(refresh)
	# Час гри йде, поки меню відкрите, — оновлюємо раз на секунду (дерево на паузі, панель — ні).
	var clock := Timer.new()
	clock.wait_time = 1.0
	clock.autostart = true
	clock.timeout.connect(_refresh_playtime)
	add_child(clock)
	refresh()


func refresh() -> void:
	_refresh_gold()
	_refresh_cards()
	_refresh_playtime()


## Реальний час гри слота. Раніше мітка лишалась зі сцени, "00:00:00", бо set_playtime()
## ніхто не викликав.
func _refresh_playtime() -> void:
	var seconds := int(SaveSystem.get_current_playtime_sec())
	_playtime_value.text = "%02d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]


func _on_health_changed(_hp: int, _max: int, _animate: bool) -> void:
	if is_inside_tree():
		_refresh_cards()


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
	var character_manager: CharacterManager = ServiceLocator.get_character_manager()
	var characters: Dictionary = character_manager.get_all_characters()
	var active_id: String = character_manager.get_active_character_id()

	# Активний персонаж першим — у нього єдиного є реальні HP/SP.
	var ids: Array = characters.keys()
	ids.sort()
	if active_id in ids:
		ids.erase(active_id)
		ids.push_front(active_id)
	ids = ids.slice(0, MAX_CARDS)

	var level: int = ServiceLocator.get_xp_manager().get_level()

	var cards := RowFill.fill(_cards, _card, ids.size())
	for i in cards.size():
		_fill_card(cards[i], ids[i], characters[ids[i]], ids[i] == active_id, level)


func _fill_card(card: Control, id: String, character: Object, is_active: bool, level: int) -> void:
	card.set_meta(&"character_id", id)
	card.get_node(^"Row/Info/Head/Name").text = String(character.get("name"))
	card.get_node(^"Row/Info/Head/LevelBadge/Level").text = "Lv.%d" % level
	# Портрет: справжнього арту ще немає, показуємо avatar_color персонажа.
	var color = character.get("avatar_color")
	card.get_node(^"Row/PortraitFrame/Portrait").color = color if color else UITokens.ICON_SLOT_BG
	# HP і SP (D146, один пул у player_state) — лише в активного (D18).
	var hp := _active_hp() if is_active else Vector2i(-1, -1)
	_fill_stat(card.get_node(^"Row/Info/Bars/Hp"), hp.x, hp.y)
	var sm: SkillManager = ServiceLocator.get_skill_manager()
	if is_active:
		_fill_stat(card.get_node(^"Row/Info/Bars/Sp"), sm.get_current_sp(), sm.get_max_sp())
	else:
		_fill_stat(card.get_node(^"Row/Info/Bars/Sp"), -1, -1)


## current < 0 ⇒ даних немає: показуємо "—/—" і порожню смугу.
func _fill_stat(row: Control, current: int, maximum: int) -> void:
	row.get_node(^"Head/Value").text = "—/—" if current < 0 else "%d/%d" % [current, maximum]
	var bar: ProgressBar = row.get_node(^"Bar")
	bar.max_value = maxf(1.0, float(maximum))
	bar.value = 0.0 if current < 0 else float(current)


## HP активного персонажа — з гравця (CombatBody2D). HealthComponent власного
## current_health не має, і картка раніше показувала максимум.
func _active_hp() -> Vector2i:
	var player = ServiceLocator.get_game_manager().get_current_player()
	# Картка показує HP — то й оновлюється від зміни HP (зілля, удар, рівень),
	# а не лише від зміни інвентаря (B45).
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	return Vector2i(player.get_current_health(), player.get_max_health())
