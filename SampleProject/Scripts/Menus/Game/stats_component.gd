extends BaseMenuComponent

## 📊 StatsComponent — екран Status.
## Figma: menu-status (58:719).
##
## Формул тут немає — усе рахують наявні власники:
##   ім'я/клас       — CharacterManager (game_manager.get_active_character())
##   дані класу      — game_manager.get_class_data() → CharacterManager → JSON
##   похідні стати   — game_manager.calculate_*() → StatCalculator
##   рівень і досвід — XPManager
##
## Кадр Figma має праву колонку-портрет 640 замість панелі партії, тому на час
## показу Status панель партії ховається (див. _set_party_panel_visible).

const PLACEHOLDER := "—"
## Рядки й картки — шаблони зі сцени (D117): %WeaponBox, %PointAttr, %AttrRow (обидві колонки), %ActionCard,
## %CompanionCard. Стилі — з теми (AvatarFrame, AttrRow, IconSlot, AccentTick, BoxPanel, ActionCard).
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")

@onready var _avatar: Panel = %Avatar
## Стиль AvatarFrame з теми — заливка підміняється кольором персонажа в копії.
@onready var _avatar_box: StyleBoxFlat = _avatar.get_theme_stylebox(&"panel").duplicate()
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _next_level_value: Label = %NextLevelValue
@onready var _jp_value: Label = %JPValue
@onready var _attr_points_value: Label = %AttrPointsValue
@onready var _point_attrs: HBoxContainer = %PointAttrs
@onready var _point_attr: HBoxContainer = %PointAttr
@onready var _primary_job: Label = %PrimaryJobName
@onready var _secondary_job: Label = %SecondaryJobName
@onready var _weapon_slots: HBoxContainer = %WeaponSlots
@onready var _weapon_box: PanelContainer = %WeaponBox
@onready var _hp_meter: Control = %HPMeter
@onready var _sp_meter: Control = %SPMeter
@onready var _left_attrs: VBoxContainer = %LeftAttrs
@onready var _right_attrs: VBoxContainer = %RightAttrs
## Один шаблон на обидві колонки: права заповнюється його копіями.
@onready var _attr_row: PanelContainer = %AttrRow
@onready var _actions_row: HBoxContainer = %ActionsRow
@onready var _action_card: PanelContainer = %ActionCard
@onready var _companions: VBoxContainer = %CompanionsSection
@onready var _companion_cards: HBoxContainer = %CompanionCards
@onready var _companion_card: PanelContainer = %CompanionCard
## Кнопки карток, вже під'єднані (duplicate() копіює meta, тож не за meta-прапорцем).
var _wired: Dictionary = {}

## Рядки атрибутів з кадру: (підпис, метод GameManager, чи це частка 0..1).
const LEFT_ROWS: Array[Array] = [
	["Phys. Atk.", "calculate_physical_damage", false],
	["Phys. Def.", "calculate_physical_defense", false],
	["Accuracy", "calculate_accuracy", true],
	["Critical", "calculate_critical_chance", true],
]
const RIGHT_ROWS: Array[Array] = [
	["Elem. Atk.", "calculate_magic_damage", false],
	["Elem. Def.", "calculate_magic_defense", false],
	["Speed", "calculate_attack_speed", true],
	["Evasion", "calculate_dodge_chance", true],
]


func _initialize_component() -> void:
	_connect_live_sources()
	update_display()


## Підписка напряму на власників даних, а не на ретрансляцію через GameManager.
func _connect_live_sources() -> void:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator == null:
		return
	var character_manager: CharacterManager = service_locator.get_character_manager()
	if character_manager and not character_manager.character_changed.is_connected(_on_character_changed):
		character_manager.character_changed.connect(_on_character_changed)
	var xp_manager: XPManager = service_locator.get_xp_manager()
	if xp_manager and not xp_manager.level_up.is_connected(_on_level_up):
		xp_manager.level_up.connect(_on_level_up)
	# JP нараховуються вже після level_up, тож слухаємо самі JP; так само очки атрибутів (D335).
	if not EventBus.job_points_changed.is_connected(_on_job_points_changed):
		EventBus.job_points_changed.connect(_on_job_points_changed)
	if not EventBus.attribute_points_changed.is_connected(_on_job_points_changed):
		EventBus.attribute_points_changed.connect(_on_job_points_changed)
	if not EventBus.attributes_changed.is_connected(update_display):
		EventBus.attributes_changed.connect(update_display)
	if not EventBus.companion_party_changed.is_connected(_update_companions):
		EventBus.companion_party_changed.connect(_update_companions)


func _on_character_changed(_character_id: String) -> void:
	update_display()


func _on_level_up(_new_level: int, _old_level: int) -> void:
	update_display()


func _on_job_points_changed(_current: int, _previous: int) -> void:
	update_display()


func update_display() -> void:
	if not is_node_ready() or game_manager == null:
		return
	_update_header()
	_update_jobs()
	_update_attributes()
	_update_actions()
	_update_companions()


# ── Шапка ───────────────────────────────────────────────────────────────────

func _update_header() -> void:
	var character = game_manager.get_active_character()
	_name_label.text = String(character.name) if character else PLACEHOLDER

	_avatar_box.bg_color = character.avatar_color if character else UITokens.ICON_SLOT_BG
	_avatar.add_theme_stylebox_override(&"panel", _avatar_box)

	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	var xp_manager: XPManager = service_locator.get_xp_manager() if service_locator else null
	if xp_manager:
		_level_label.text = tr("Lv.%d") % xp_manager.get_level()
		_next_level_value.text = tr("%d EXP") % maxi(0, xp_manager.xp_for_next_level - xp_manager.current_xp)
	else:
		_level_label.text = PLACEHOLDER
		_next_level_value.text = PLACEHOLDER

	# JP (D149) — той самий формат, що й на вкладці Skills.
	_jp_value.text = tr("%d JP") % ServiceLocator.get_skill_manager().get_job_points()
	_attr_points_value.text = str(ServiceLocator.get_attribute_manager().get_unspent())  # D335: ще не вкладені


# ── Робота / зброя ──────────────────────────────────────────────────────────

func _update_jobs() -> void:
	var character = game_manager.get_active_character()
	if character == null:
		_primary_job.text = PLACEHOLDER
		_secondary_job.text = PLACEHOLDER
		return

	var class_data: Dictionary = game_manager.get_class_data(
			String(character.class_id), String(character.subclass_id))
	# Файл класів існує як інфраструктура, але назви поки не заповнені —
	# порожній рядок показуємо як прочерк, а не як порожнє місце.
	_primary_job.text = _or_placeholder(String(class_data.get("name", "")))
	var subclass: Dictionary = class_data.get("subclass", {})
	_secondary_job.text = _or_placeholder(String(subclass.get("name", "")))

	_update_weapon_slots(character)


## Типи зброї беремо з реально екіпірованих слотів.
func _or_placeholder(value: String) -> String:
	return value if not value.strip_edges().is_empty() else PLACEHOLDER


func _update_weapon_slots(character) -> void:
	var equipped: Dictionary = character.equipment if character else {}
	var names: Array[String] = []
	for slot_id in ["sword", "polearm", "dagger", "axe", "mace", "bow", "staff"]:
		var item = equipped.get(slot_id)
		if item != null:
			names.append(ServiceLocator.get_item_database().get_item_name(String(item.id)))
	# Без зброї — одна порожня клітинка з прочерком.
	var boxes := RowFill.fill(_weapon_slots, _weapon_box, maxi(names.size(), 1))
	for i in boxes.size():
		var item_name: String = names[i] if i < names.size() else ""
		boxes[i].get_node(^"Letter").text = item_name.substr(0, 1).to_upper() if item_name != "" else PLACEHOLDER


# ── Атрибути ────────────────────────────────────────────────────────────────

func _update_attributes() -> void:
	_fill_meter(_hp_meter, "Max. HP", _current_hp(), game_manager.calculate_max_health())
	var sm: SkillManager = ServiceLocator.get_skill_manager()
	_fill_meter(_sp_meter, "Max. SP", sm.get_current_sp(), sm.get_max_sp())
	_fill_rows(_left_attrs, LEFT_ROWS)
	_fill_rows(_right_attrs, RIGHT_ROWS)
	_fill_point_attrs()


## Вкладені очки атрибутів (D335) — назва й число, з даних attributes.json; що вони дають, уже в рядках нижче.
func _fill_point_attrs() -> void:
	var attributes: AttributeManager = ServiceLocator.get_attribute_manager()
	var ids := attributes.attribute_ids()
	var pairs := RowFill.fill(_point_attrs, _point_attr, ids.size())
	for i in pairs.size():
		var attribute_id: String = ids[i]
		pairs[i].name = attribute_id
		pairs[i].get_node(^"Caption").text = String(attributes.get_definition(attribute_id).name)
		pairs[i].get_node(^"Value").text = str(attributes.get_points(attribute_id))


func _fill_rows(container: VBoxContainer, rows: Array[Array]) -> void:
	var lines := RowFill.fill(container, _attr_row, rows.size())
	for i in lines.size():
		var value := float(game_manager.call(String(rows[i][1])))
		if bool(rows[i][2]):
			value *= 100.0
		lines[i].get_node(^"Row/Name").text = String(rows[i][0])
		lines[i].get_node(^"Row/Value").text = str(roundi(value))


## current < 0 ⇒ даних немає: "—" і порожня смуга.
func _fill_meter(meter: Control, caption: String, current: int, maximum: int) -> void:
	var caption_label: Label = meter.get_node(^"Head/Caption")
	var value_label: Label = meter.get_node(^"Head/Value")
	var max_label: Label = meter.get_node(^"Head/Max")
	var bar: ProgressBar = meter.get_node(^"Bar")

	caption_label.text = caption
	if current < 0 or maximum <= 0:
		value_label.text = PLACEHOLDER
		max_label.text = ""
		bar.max_value = 1.0
		bar.value = 0.0
		return
	value_label.text = _format_thousands(current)
	max_label.text = " / %s" % _format_thousands(maximum)
	bar.max_value = float(maximum)
	bar.value = float(current)


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


func _current_hp() -> int:
	# Поточне HP — у самого гравця (CombatBody2D.current_health). Раніше читалось з дочірнього
	# HealthComponent, якого в гравця нема, тож завжди показувалось максимальне HP.
	return int(game_manager.get_current_player().current_health)


# ── Унікальні дії та таланти ────────────────────────────────────────────────

## Системи Path Action / Talent у проєкті немає. Лишаємо структуру з Figma,
## але без вигаданого контенту.
func _update_actions() -> void:
	var captions: Array[String] = ["Path Action", "Talent"]
	var cards := RowFill.fill(_actions_row, _action_card, captions.size())
	for i in cards.size():
		cards[i].get_node(^"Col/Head/Caption").text = captions[i].to_upper()


# ── Компаньйони (D220) ──────────────────────────────────────────────────────

## Відкриті компаньйони; натискання бере в загін (у кінець черги асисту) або лишає в таборі.
## Номер — місце в черзі кнопки асисту. Повний загін приглушує решту карток.
func _update_companions() -> void:
	var cm: CompanionManager = ServiceLocator.get_companion_manager()
	var ids := cm.get_unlocked()
	_companions.visible = not ids.is_empty()
	var party: Array = cm.get_party()
	var cards := RowFill.fill(_companion_cards, _companion_card, ids.size())
	for i in cards.size():
		var card: Control = cards[i]
		var id: String = ids[i]
		var slot := party.find(id)
		card.set_meta(&"companion_id", id)
		card.get_node(^"Row/Portrait").texture = load(CompanionManager.PORTRAIT_PATH % id)
		card.get_node(^"Row/Info/Name").text = cm.NAMES[id]
		card.get_node(^"Row/Info/Order").text = tr("IN PARTY · %d") % (slot + 1) if slot >= 0 else tr("IN CAMP")
		card.modulate.a = 1.0 if slot >= 0 or party.size() < CompanionManager.PARTY_SIZE else UITokens.MENU_INACTIVE_ALPHA
		var select: Button = card.get_node(^"Select")
		if not _wired.has(select):
			_wired[select] = true
			select.pressed.connect(func() -> void: cm.toggle_party(card.get_meta(&"companion_id")))


# ── Панель партії ───────────────────────────────────────────────────────────

## Figma menu-status має праву колонку-портрет 640 замість панелі партії.
## Ховаємо її на час показу; прибереться на етапі спільного шелу.
func _set_party_panel_visible(value: bool) -> void:
	var panel: Node = get_tree().get_first_node_in_group(&"ui_party_column")
	if panel:
		panel.visible = value


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		# game_menu ховає панель-предка, а не сам компонент, тому власний
		# visible лишається true — питаємо саме про видимість у дереві.
		var shown := is_visible_in_tree()
		_set_party_panel_visible(not shown)
		if shown:
			update_display()
