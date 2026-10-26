extends BaseMenuComponent

## 📊 StatsComponent — екран Status.
## Figma: menu-status (58:719).
##
## Формул тут немає — усе рахують наявні власники:
##   ім'я            — CharacterManager (game_manager.get_active_character())
##   клас і клятва   — SkillDatabase (skills.json → class, oaths) і SkillManager.get_oath() (B130)
##   похідні стати   — game_manager.calculate_*() → StatCalculator
##   рівень і досвід — XPManager
##
## Кадр Figma має праву колонку-портрет 640 замість панелі партії, тому на час
## показу Status панель партії ховається (game_menu.tscn: metadata/hide_party_column, B151).
##
## Очки атрибутів (D335) вкладаються тут, поруч зі статами, які вони міняють (D722, Sapega: «атрибути треба
## в статусі виставляти»). Рядки %AttributeRow і їхня логіка перенесені з вікна навичок; правила ті самі (D330):
## + позначає очко в SkillPlan, − / X / Backspace знімає, витрачає лише Accept (кнопка, Y / F), Esc / B з
## позначеним — скидає позначене, інша вкладка — теж. Скидання вкладеного — Reset all на вкладці Skills (D628).

const PLACEHOLDER := "—"
## Рядки й картки — шаблони зі сцени (D117): %WeaponBox, %PointAttr, %AttrRow (обидві колонки), %CompanionCard.
## Стилі — з теми (AvatarFrame, AttrRow, IconSlot, AccentTick, BoxPanel, ActionCard).
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")

@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _next_level_value: Label = %NextLevelValue
@onready var _jp_value: Label = %JPValue
@onready var _attr_points_value: Label = %AttrPointsValue
@onready var _attr_rows_box: GridContainer = %AttrRows
@onready var _attr_row_template: HBoxContainer = %AttributeRow
@onready var _pending_label: Label = %AttrPendingLabel
@onready var _cancel_button: Button = %AttrCancelButton
@onready var _accept_button: Button = %AttrAcceptButton
@onready var _primary_job: Label = %PrimaryJobName
@onready var _secondary_job: Label = %SecondaryJobName
@onready var _secondary_job_column: VBoxContainer = %SecondaryJob
@onready var _weapon_slots: HBoxContainer = %WeaponSlots
@onready var _weapon_box: PanelContainer = %WeaponBox
@onready var _hp_meter: Control = %HPMeter
@onready var _sp_meter: Control = %SPMeter
@onready var _left_attrs: VBoxContainer = %LeftAttrs
@onready var _right_attrs: VBoxContainer = %RightAttrs
## Один шаблон на обидві колонки: права заповнюється його копіями.
@onready var _attr_row: PanelContainer = %AttrRow
@onready var _actions_row: HBoxContainer = %ActionsRow
@onready var _companions: VBoxContainer = %CompanionsSection
@onready var _companion_cards: HBoxContainer = %CompanionCards
@onready var _companion_card: PanelContainer = %CompanionCard
## Кнопки карток, вже під'єднані (duplicate() копіює meta, тож не за meta-прапорцем).
var _wired: Dictionary = {}
## Позначені, ще не прийняті очки атрибутів (D330). Навичок тут не позначають.
var plan: SkillPlan
var _attributes: AttributeManager = null
var _attribute_rows: Dictionary = {}  # attribute_id -> HBoxContainer

## Рядки атрибутів з кадру: (підпис, метод GameManager, чи це частка 0..1).
const LEFT_ROWS: Array[Array] = [
	["Phys. Atk.", "calculate_physical_damage", false],
	["Phys. Def.", "calculate_physical_defense", false],
	["Accuracy", "calculate_accuracy", true],
	["Critical", "calculate_critical_chance", true],
]
## Іконки типів зброї (B130) — у порядку EquipmentManager.WEAPON_SLOTS.
const WEAPON_ICONS: Dictionary[String, Texture2D] = {
	"sword": preload("res://SampleProject/Assets/UI/Icons/weapon_sword.svg"),
	"polearm": preload("res://SampleProject/Assets/UI/Icons/weapon_polearm.svg"),
	"dagger": preload("res://SampleProject/Assets/UI/Icons/weapon_dagger.svg"),
	"axe": preload("res://SampleProject/Assets/UI/Icons/weapon_axe.svg"),
	"mace": preload("res://SampleProject/Assets/UI/Icons/weapon_mace.svg"),
	"bow": preload("res://SampleProject/Assets/UI/Icons/weapon_bow.svg"),
	"staff": preload("res://SampleProject/Assets/UI/Icons/weapon_staff.svg"),
}
## Підпис типу зброї для підказки — ті самі ключі, що й у рядках Equipment.
const WEAPON_NAMES: Dictionary[String, String] = {
	"sword": "SWORDS", "polearm": "POLEARMS", "dagger": "DAGGERS", "axe": "AXES",
	"mace": "MACES", "bow": "BOWS", "staff": "STAVES",
}
const RIGHT_ROWS: Array[Array] = [
	["Elem. Atk.", "calculate_magic_damage", false],
	["Elem. Def.", "calculate_magic_defense", false],
	["Speed", "calculate_attack_speed", true],
	["Evasion", "calculate_dodge_chance", true],
]


func _initialize_component() -> void:
	# Гліфи рядків і типів зброї — акцентом, як у Figma 58:719 (шаблони, тож копії успадкують).
	(_attr_row.get_node(^"Row/Icon") as TextureRect).self_modulate = UITokens.ACCENT
	(_weapon_box.get_node(^"Icon") as TextureRect).self_modulate = UITokens.ACCENT
	_attributes = ServiceLocator.get_attribute_manager()
	plan = SkillPlan.new(ServiceLocator.get_skill_manager(), _attributes)
	plan.changed.connect(update_display)
	_build_attribute_rows()
	_cancel_button.pressed.connect(cancel_plan)
	_accept_button.pressed.connect(accept_plan)
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
	if not EventBus.oath_sworn.is_connected(_on_oath_sworn):
		EventBus.oath_sworn.connect(_on_oath_sworn)
	if not EventBus.companion_party_changed.is_connected(_update_companions):
		EventBus.companion_party_changed.connect(_update_companions)


func _on_character_changed(_character_id: String) -> void:
	update_display()


func _on_oath_sworn(_oath_id: String) -> void:
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
	_update_companions()


# ── Шапка ───────────────────────────────────────────────────────────────────

func _update_header() -> void:
	var character = game_manager.get_active_character()
	_name_label.text = String(character.name) if character else PLACEHOLDER


	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	var xp_manager: XPManager = service_locator.get_xp_manager() if service_locator else null
	if xp_manager:
		_level_label.text = tr("Lv.%d") % xp_manager.get_level()
		# D488: на найвищому рівні — MAX замість досвіду до наступного.
		_next_level_value.text = tr("MAX") if xp_manager.is_max_level() \
				else tr("%d EXP") % maxi(0, xp_manager.xp_for_next_level - xp_manager.current_xp)
	else:
		_level_label.text = PLACEHOLDER
		_next_level_value.text = PLACEHOLDER

	# JP (D149) — той самий формат, що й на вкладці Skills.
	_jp_value.text = tr("%d JP") % ServiceLocator.get_skill_manager().get_job_points()
	_attr_points_value.text = str(plan.attribute_points_left())  # D335: ще не вкладені, без позначених


# ── Робота / зброя ──────────────────────────────────────────────────────────

func _update_jobs() -> void:
	# B130: основна робота — клас (Holy Warrior, D260), друга — складена клятва (D280); до клятви її немає.
	var skill_manager: SkillManager = ServiceLocator.get_skill_manager()
	_primary_job.text = tr(SkillDatabase.class_name_trunk)
	var oath_id := skill_manager.get_oath()
	# Колонка тримає своє місце (поле основної роботи не розтягується), порожня до клятви.
	for child in _secondary_job_column.get_children():
		child.visible = oath_id != ""
	if oath_id != "":
		_secondary_job.text = tr(String(SkillDatabase.get_oath(oath_id).name))
	_update_weapon_slots()


## Типи зброї, якими володіє герой: усі слоти зброї Equipment (EquipmentManager.WEAPON_SLOTS).
func _update_weapon_slots() -> void:
	var boxes := RowFill.fill(_weapon_slots, _weapon_box, EquipmentManager.WEAPON_SLOTS.size())
	for i in boxes.size():
		var slot_id: String = EquipmentManager.WEAPON_SLOTS[i]
		boxes[i].name = slot_id
		boxes[i].tooltip_text = tr(WEAPON_NAMES[slot_id])
		(boxes[i].get_node(^"Icon") as TextureRect).texture = WEAPON_ICONS[slot_id]


# ── Атрибути ────────────────────────────────────────────────────────────────

func _update_attributes() -> void:
	_fill_meter(_hp_meter, "Max. HP", _current_hp(), game_manager.calculate_max_health())
	var sm: SkillManager = ServiceLocator.get_skill_manager()
	_fill_meter(_sp_meter, "Max. SP", sm.get_current_sp(), sm.get_max_sp())
	_fill_rows(_left_attrs, LEFT_ROWS)
	_fill_rows(_right_attrs, RIGHT_ROWS)
	_refresh_attributes()


# ── Очки атрибутів (D335, D722; перенесено з вікна навичок) ────────────────

## Рядки атрибутів — з attributes.json (D335): назва, що дає очко, вкладено (+ позначено), − / +.
func _build_attribute_rows() -> void:
	var ids: Array = _attributes.attribute_ids()
	var rows := RowFill.fill(_attr_rows_box, _attr_row_template, ids.size())
	_rename(rows, ids)
	for i in rows.size():
		var attribute_id: String = ids[i]
		var definition: Dictionary = _attributes.get_definition(attribute_id)
		var row: HBoxContainer = rows[i]
		row.get_node(^"Name").text = String(definition.name)
		row.get_node(^"Gives").text = _gives_text(_attributes.preview(attribute_id, 1))
		row.tooltip_text = String(definition.description)
		var minus: Button = row.get_node(^"Minus")
		var plus: Button = row.get_node(^"Plus")
		minus.pressed.connect(_unpick_attribute.bind(attribute_id))
		plus.pressed.connect(_pick_attribute.bind(attribute_id))
		for button in [minus, plus]:
			button.gui_input.connect(_on_attribute_input.bind(attribute_id))
		_attribute_rows[attribute_id] = row


## Імена рядків з даних. Спершу тимчасові — щоб нове ім'я не зіткнулося зі старим іменем сусіда
## (інакше Godot мовчки дописує до нього число).
func _rename(rows: Array, names: Array) -> void:
	for i in rows.size():
		rows[i].name = "_%d" % i
	for i in rows.size():
		rows[i].name = String(names[i])


## Що дає одне очко — коротко, з даних: «+1 atk», «+4 HP», «+2 SP · +1% power · …».
func _gives_text(gives: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: String in gives:
		var value: float = gives[stat]
		match stat:
			"attack": parts.append(tr("+%d atk") % roundi(value))
			"max_health": parts.append(tr("+%d HP") % roundi(value))
			"max_sp": parts.append(tr("+%d SP") % roundi(value))
			"crit_chance": parts.append(tr("+%s%% crit") % _percent(value))
			"dodge_chance": parts.append(tr("+%s%% evade") % _percent(value))
			"attack_speed": parts.append(tr("+%s%% speed") % _percent(value))
			"skill_power": parts.append(tr("+%s%% power") % _percent(value))
			"sp_per_hit": parts.append(tr("+%s SP per hit") % String.num(value, 2))
			_: assert(false, "StatsComponent: no text for attribute stat %s" % stat)
	return " · ".join(parts)


func _percent(fraction: float) -> String:
	return String.num(fraction * 100.0, 1).trim_suffix(".0")


func _refresh_attributes() -> void:
	for attribute_id: String in _attribute_rows:
		var row: HBoxContainer = _attribute_rows[attribute_id]
		var picked := plan.attribute_points(attribute_id)
		var spent := _attributes.get_points(attribute_id)
		row.get_node(^"Value").text = "%d +%d" % [spent, picked] if picked > 0 else str(spent)
		row.get_node(^"Minus").disabled = picked == 0
		row.get_node(^"Plus").disabled = plan.attribute_points_left() <= 0
	_cancel_button.visible = not plan.is_empty()
	_accept_button.visible = not plan.is_empty()
	_pending_label.visible = not plan.is_empty()
	if not plan.is_empty():
		_pending_label.text = tr("To spend: ") + tr("attribute points: %d") % (_attributes.get_unspent() - plan.attribute_points_left())


func _pick_attribute(attribute_id: String) -> void:
	plan.pick_attribute(attribute_id)


func _unpick_attribute(attribute_id: String) -> void:
	plan.unpick_attribute(attribute_id)


## Accept (кнопка, Y / F): витратити позначене.
func accept_plan() -> void:
	if plan.is_empty():
		return
	plan.accept()


## Cancel (кнопка, Esc / B): відкинути позначене.
func cancel_plan() -> void:
	plan.clear()


func _on_attribute_input(event: InputEvent, attribute_id: String) -> void:
	if event.is_action_pressed(&"skills_unpick"):
		_unpick_attribute(attribute_id)
		accept_event()


## Esc / B з позначеним лише скидає позначене (D330), друге Esc — як завжди (FocusRouter, game_menu).
## _shortcut_input іде раніше за їхній _unhandled_input; модалка поверх меню забирає фокус — тоді не чіпаємо.
func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or plan.is_empty() or not event.is_action_pressed(&"ui_cancel"):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and not is_ancestor_of(focused):
		return
	cancel_plan()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"skills_accept") and not plan.is_empty():
		accept_plan()
		get_viewport().set_input_as_handled()


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

## Системи Path Action / Talent у проєкті немає: секція ActionsSection прихована в сцені (B130),
## доки герой не має жодної. Шаблон %ActionCard лишається в сцені для майбутньої системи.


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


## Туторіал вибору компаньйонів (D463): фокус на першій картці, секція — у полі зору прокрутки Status.
func focus_companions() -> void:
	_update_companions()
	var first: Control = _companion_cards.get_children().filter(func(c: Control) -> bool: return c.visible)[0]
	(first.get_node(^"Select") as Button).grab_focus()
	(get_parent() as ScrollContainer).ensure_control_visible(_companions)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		# game_menu ховає панель-предка, а не сам компонент, тому власний
		# visible лишається true — питаємо саме про видимість у дереві.
		var shown := is_visible_in_tree()
		if shown:
			update_display()
		elif plan != null:
			plan.clear()  # D330: з екрана пішли — позначене не витрачається
