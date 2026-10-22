extends BaseMenuComponent

## 🎓 SkillsComponent — екран Skills (BACKLOG 43 + 44, design/skill_screen_rework_plan.md).
## Figma: menu-skills (58:453) — свідомо відходить від двох пласких списків до дерева (D333, рішення Sapega).
##
## Повністю data-driven: у сцені немає жодного вузла навички. Ряди дерева — рівні, на яких є навички
## (стовбур Holy Warrior ∪ показане дерево клятви), ліворуч стовбур, праворуч клятва, лінії від передумов (D333).
## Праворуч — панель деталей (D334), атрибути (D335) і Cancel / Accept.
##
## Нічого не витрачається одним натисканням (D330): вибір — у SkillPlan, витрачає лише Accept.
## UI НЕ редагує player_state і НЕ дублює правила: чому навичка недоступна — завжди вердикт SkillManager
## (через SkillPlan.can_pick, який питає SkillManager з урахуванням позначеного).
##
## SP героя тут свідомо НЕ показується (рішення D27): це бойовий ресурс, його місце — бойовий HUD.

const PLACEHOLDER := "—"
const ICON_CHECK := preload("res://SampleProject/Assets/UI/Icons/check_circle.svg")
const ICON_LOCK := preload("res://SampleProject/Assets/UI/Icons/lock.svg")
const ICON_PICKED := preload("res://SampleProject/Assets/UI/Icons/diamond_sm.svg")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
## Скільки місць у ряду одного дерева (D333): у даних 1–2 навички на рівень; більше — вузли вужчають, а не ламають вікно.
const NODES_PER_LANE := 2

## Стан вузла (D332).
enum NodeState { LEARNED, PICKED, CAN_LEARN, LOCKED }

@onready var _char_name: Label = %CharName
@onready var _char_class: Label = %CharClass
@onready var _avatar: Panel = %Avatar
@onready var _jp_value: Label = %JPValue
@onready var _columns: HBoxContainer = %Columns
@onready var _empty_label: Label = %EmptyLabel
@onready var _tree_tabs: HBoxContainer = %TreeTabs
@onready var _tree_status: Label = %TreeStatus
@onready var _trunk_title: Label = %TrunkTitle
@onready var _tree_stage: Control = %TreeStage
@onready var _tiers: VBoxContainer = %Tiers
@onready var _links: Control = %Links
@onready var _node_template: Button = %SkillNode
@onready var _detail_name: Label = %DetailName
@onready var _detail_kind: Label = %DetailKind
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_grid: GridContainer = %DetailGrid
@onready var _detail_state: Label = %DetailState
@onready var _pick_button: Button = %PickButton
@onready var _undo_button: Button = %UndoButton
@onready var _hotbar_box: VBoxContainer = %HotbarBox
@onready var _hotbar_slots: GridContainer = %HotbarSlots
@onready var _attr_rows_box: VBoxContainer = %AttrRows
@onready var _attr_row_template: HBoxContainer = %AttributeRow
@onready var _attr_points_value: Label = %AttrPointsValue
@onready var _pending_label: Label = %PendingLabel
@onready var _cancel_button: Button = %CancelButton
@onready var _accept_button: Button = %AcceptButton

## Позначене, ще не прийняте (D330).
var plan: SkillPlan
var _selected_id: String = ""
var _row_group := ButtonGroup.new()
var _rows: Dictionary = {}  # skill_id -> Button (вузол дерева)
var _tab_group := ButtonGroup.new()
## Яке дерево клятви показане праворуч (D283); "" — ще не вибрано: присягнуте або перше.
var _shown_oath: String = ""
var _attribute_rows: Dictionary = {}  # attribute_id -> HBoxContainer
var _slot_buttons: Array[Button] = []

var _skill_manager: SkillManager = null
var _attributes: AttributeManager = null
var _skill_database: Node = null


func _initialize_component() -> void:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	_skill_manager = service_locator.get_skill_manager()
	_attributes = service_locator.get_attribute_manager()
	_skill_database = get_tree().root.get_node(^"SkillDatabase")
	plan = SkillPlan.new(_skill_manager, _attributes)
	plan.changed.connect(_refresh)
	_connect_live_sources()
	_build_tabs()
	_build_attribute_rows()
	_build_slot_buttons()
	_pick_button.pressed.connect(pick_selected)
	_undo_button.pressed.connect(unpick_selected)
	_cancel_button.pressed.connect(cancel_plan)
	_accept_button.pressed.connect(accept_plan)
	_tiers.sort_children.connect(_links.queue_redraw)
	update_display()


## Підписка на реальні події, а не опитування в _process.
func _connect_live_sources() -> void:
	for pair in [
		[EventBus.job_points_changed, _on_points_changed],
		[EventBus.attribute_points_changed, _on_points_changed],
		[EventBus.skill_unlocked, _on_skill_changed],
		[EventBus.skill_upgraded, _on_skill_changed],
		[EventBus.oath_sworn, _on_oath_sworn],
		[EventBus.skills_reset, _on_skills_reset],
		[EventBus.attributes_changed, _refresh],
		[EventBus.equipped_skills_changed, _on_loadout_changed],
		[EventBus.input_device_changed, _on_input_device_changed],
	]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])


## Пристрій змінився — підказка внизу називає кнопки нового (BACKLOG 24).
func _on_input_device_changed(_pad: bool) -> void:
	if is_visible_in_tree() and _selected_id != "":
		_publish_details(_selected_id)


func _on_points_changed(_current: int, _previous: int) -> void:
	_refresh()


func _on_skill_changed(_skill_id: String, _rank: int = 0) -> void:
	update_display()


func _on_oath_sworn(oath_id: String) -> void:
	_shown_oath = oath_id
	update_display()


func _on_skills_reset(_refunded: int) -> void:
	plan.clear()
	update_display()


func _on_loadout_changed(_loadout: Array) -> void:
	_refresh_detail()


## Вкладки дерев клятв — з даних (skills.json → oaths), у порядку файлу; сидять у шапці дерева клятви (D333).
func _build_tabs() -> void:
	for oath_id in _skill_database.oaths:
		var tab := Button.new()
		tab.name = oath_id
		tab.text = String(_skill_database.get_oath(oath_id).name)
		tab.theme_type_variation = &"TabButton"
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.focus_mode = Control.FOCUS_ALL
		tab.pressed.connect(show_tree.bind(oath_id))
		_tree_tabs.add_child(tab)


## Рядки атрибутів — з attributes.json (D335): назва, що дає очко, вкладено (+ позначено), − / +.
func _build_attribute_rows() -> void:
	for attribute_id in _attributes.attribute_ids():
		var definition: Dictionary = _attributes.get_definition(attribute_id)
		var row: HBoxContainer = _attr_row_template.duplicate()
		row.unique_name_in_owner = false
		row.name = attribute_id
		row.get_node(^"Name").text = String(definition.name)
		row.get_node(^"Gives").text = _gives_text(_attributes.preview(attribute_id, 1))
		row.tooltip_text = String(definition.description)
		var minus: Button = row.get_node(^"Minus")
		var plus: Button = row.get_node(^"Plus")
		minus.pressed.connect(_unpick_attribute.bind(attribute_id))
		plus.pressed.connect(_pick_attribute.bind(attribute_id))
		for button in [minus, plus]:
			button.gui_input.connect(_on_attribute_input.bind(attribute_id))
		_attr_rows_box.add_child(row)
		_attribute_rows[attribute_id] = row


## Що дає одне очко — коротко, з даних: «+1 atk», «+4 HP», «+2 SP · +1% power · …».
func _gives_text(gives: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: String in gives:
		var value: float = gives[stat]
		match stat:
			"attack": parts.append("+%d atk" % roundi(value))
			"max_health": parts.append("+%d HP" % roundi(value))
			"max_sp": parts.append("+%d SP" % roundi(value))
			"crit_chance": parts.append("+%s%% crit" % _percent(value))
			"dodge_chance": parts.append("+%s%% evade" % _percent(value))
			"attack_speed": parts.append("+%s%% speed" % _percent(value))
			"skill_power": parts.append("+%s%% power" % _percent(value))
			"sp_regen": parts.append("+%s SP/s" % String.num(value, 2))
			_: assert(false, "SkillsComponent: no text for attribute stat %s" % stat)
	return " · ".join(parts)


func _percent(fraction: float) -> String:
	return String.num(fraction * 100.0, 1).trim_suffix(".0")


## Чотири слоти хотбара (D331): кнопка ставить вибрану вивчену активну навичку в слот.
func _build_slot_buttons() -> void:
	for slot in SkillManager.SLOT_COUNT:
		var button := Button.new()
		button.name = "Slot%d" % (slot + 1)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(assign_to_slot.bind(slot))
		_hotbar_slots.add_child(button)
		_slot_buttons.append(button)


## Показати дерево клятви праворуч (вкладка: клавіатура, геймпад, миша).
func show_tree(oath_id: String) -> void:
	_shown_oath = oath_id
	update_display()


# ── Побудова ────────────────────────────────────────────────────────────────

func update_display() -> void:
	if not is_node_ready() or _skill_manager == null:
		return
	if _shown_oath.is_empty():
		_shown_oath = _skill_manager.get_oath() if _skill_manager.get_oath() != "" else String(_skill_database.oaths.keys()[0])
	for tab in _tree_tabs.get_children():
		tab.set_pressed_no_signal(tab.name == _shown_oath)
	# Перебудова звільняє вузли — фокус клавіатури/геймпада повертаємо на вибраний вузол.
	var focused := get_viewport().gui_get_focus_owner()
	var had_row_focus := focused != null and focused in _rows.values()
	_rebuild_tree()
	if not _rows.has(_selected_id) and not _rows.is_empty():
		_selected_id = _rows.keys()[0]
	if had_row_focus and _rows.has(_selected_id):
		_rows[_selected_id].grab_focus()
	_refresh()


## Усе, що залежить від плану й очок, без перебудови дерева.
func _refresh() -> void:
	if not is_node_ready() or _skill_manager == null:
		return
	_refresh_header()
	_refresh_rows()
	_refresh_links()
	_refresh_detail()
	_refresh_attributes()
	_refresh_action_bar()
	_publish_details(_selected_id)


func _refresh_header() -> void:
	var character = game_manager.get_active_character() if game_manager else null
	_char_name.text = String(character.name) if character else PLACEHOLDER

	var box := StyleBoxFlat.new()
	box.bg_color = character.avatar_color if character else UITokens.ICON_SLOT_BG
	box.set_corner_radius_all(UITokens.RADIUS)
	box.set_border_width_all(UITokens.BORDER_WIDTH)
	box.border_color = UITokens.BORDER
	_avatar.add_theme_stylebox_override("panel", box)

	_char_class.text = _skill_manager.class_title()  # D280: Holy Warrior → назва клятви
	# Скільки лишиться після позначеного (D330); без позначок — просто очки героя.
	_jp_value.text = "%d JP" % plan.jp_left()


func _trunk() -> Array:
	var character = game_manager.get_active_character() if game_manager else null
	var class_id := String(character.class_id) if character else ""
	return _skill_database.get_all_skills().filter(
			func(d): return d.oath == "" and (d.class_id == "" or d.class_id == class_id))


func _oath_tree() -> Array:
	return _skill_database.get_all_skills().filter(func(d): return d.oath == _shown_oath)


func _rebuild_tree() -> void:
	for child in _tiers.get_children():
		_tiers.remove_child(child)
		child.queue_free()
	_rows.clear()

	var trunk := _trunk()
	var tree := _oath_tree()
	# Чесний порожній стан: немає жодної навички для цього героя.
	var has_any := not trunk.is_empty() or not tree.is_empty()
	_columns.visible = has_any
	_empty_label.visible = not has_any
	if not has_any:
		_empty_label.text = "No skills available yet."
		return

	_trunk_title.text = _skill_database.class_name_trunk if not String(_skill_database.class_name_trunk).is_empty() else PLACEHOLDER
	_tree_status.text = _tree_status_text()

	var levels: Array[int] = []
	for definition in trunk + tree:
		if not definition.required_level in levels:
			levels.append(definition.required_level)
	levels.sort()
	for level in levels:
		_tiers.add_child(_make_tier(level,
				trunk.filter(func(d): return d.required_level == level),
				tree.filter(func(d): return d.required_level == level)))


## Ряд дерева: «Lv N», клітинка стовбура, клітинка клятви.
func _make_tier(level: int, trunk_skills: Array, oath_skills: Array) -> Control:
	var row := HBoxContainer.new()
	row.name = "Tier%d" % level
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UITokens.SPACE_LG)
	var caption := Label.new()
	caption.text = "Lv %d" % level
	caption.theme_type_variation = &"MicroLabel"
	caption.custom_minimum_size.x = 56  # = TierSpacer у шапці
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	row.add_child(_make_cell(trunk_skills))
	row.add_child(_make_cell(oath_skills))
	return row


func _make_cell(definitions: Array) -> Control:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", UITokens.SPACE_SM)
	for definition in definitions:
		cell.add_child(_make_node(definition))
	# Порожнє місце тримає стовпці рівними — лінії йдуть прямо вниз.
	for i in maxi(0, NODES_PER_LANE - definitions.size()):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(spacer)
	return cell


func _make_node(definition: SkillDefinition) -> Button:
	var node: Button = _node_template.duplicate()
	node.unique_name_in_owner = false
	node.name = definition.id
	node.button_group = _row_group
	node.focus_mode = Control.FOCUS_ALL
	node.tooltip_text = definition.description
	node.get_node(^"Row/SkillName").text = definition.name if not definition.name.is_empty() else definition.id
	node.pressed.connect(_on_row_selected.bind(definition.id))
	node.focus_entered.connect(_on_row_selected.bind(definition.id))
	# gui_input приходить раніше, ніж Button сам «з'їдає» ui_accept: Enter / A на вузлі — позначити (D331).
	node.gui_input.connect(_on_row_input.bind(definition.id))
	_rows[definition.id] = node
	return node


## Стан правого дерева (D280): клятви ще немає / це клятва героя / чужа клятва.
func _tree_status_text() -> String:
	var oath: Dictionary = _skill_database.get_oath(_shown_oath)
	var sworn: String = _skill_manager.get_oath()
	if sworn.is_empty():
		return "%s · Swear an oath in the City (level %d)" % [String(oath.tree), int(oath.level)]
	return "%s · %s" % [String(oath.tree), "Your oath" if sworn == _shown_oath else "Sworn to another oath"]


# ── Стани вузлів (D332) ─────────────────────────────────────────────────────

func node_state(skill_id: String) -> NodeState:
	if _skill_manager.is_unlocked(skill_id):
		return NodeState.LEARNED
	if plan.skill_picks(skill_id) > 0:
		return NodeState.PICKED
	return NodeState.CAN_LEARN if plan.can_pick(skill_id) == SkillManager.Result.OK else NodeState.LOCKED


## Короткий підпис праворуч на вузлі; повна причина — у панелі деталей.
func _node_note(definition: SkillDefinition) -> String:
	var picks := plan.skill_picks(definition.id)
	match node_state(definition.id):
		NodeState.LEARNED:
			var rank := _skill_manager.get_rank(definition.id)
			return "R%d +%d" % [rank, picks] if picks > 0 else "R%d" % rank
		NodeState.PICKED:
			return "Picked" if picks == 1 else "Picked +%d" % (picks - 1)
		NodeState.CAN_LEARN:
			return _cost_text(definition.jp_cost)
	match plan.can_pick(definition.id):
		SkillManager.Result.LEVEL_TOO_LOW:
			return "Lv %d" % definition.required_level
		SkillManager.Result.NO_OATH:
			return "Oath"
		SkillManager.Result.OTHER_OATH:
			return "Other oath"
		SkillManager.Result.NOT_ENOUGH_JP:
			return _cost_text(definition.jp_cost)
		_:
			return "Locked"


func _cost_text(jp: int) -> String:
	return "Free" if jp == 0 else "%d JP" % jp


func _refresh_rows() -> void:
	for skill_id in _rows:
		_apply_row_state(_skill_database.get_skill(skill_id), _rows[skill_id])


## Стан вузла визначає SkillManager (через план) — UI лише малює його вердикт.
func _apply_row_state(definition: SkillDefinition, node: Button) -> void:
	var state := node_state(definition.id)
	var selected := definition.id == _selected_id
	var name_label: Label = node.get_node(^"Row/SkillName")
	var note: Label = node.get_node(^"Row/State")
	var marker: TextureRect = node.get_node(^"Row/Marker")

	if selected:
		name_label.theme_type_variation = &"SkillNameSelected"
	elif state == NodeState.LOCKED:
		name_label.theme_type_variation = &"SkillNameLocked"
	else:
		name_label.theme_type_variation = &"SkillName"

	note.text = _node_note(definition)
	# Figma малює акцентний текст на акцентній заливці — нечитабельно; на вибраному — контрастний (D26).
	var note_color: Color = UITokens.TEXT_MUTED
	match state:
		NodeState.LEARNED:
			marker.texture = ICON_CHECK
			marker.modulate = UITokens.ACCENT
			note_color = UITokens.TEXT_PRIMARY
		NodeState.PICKED:
			marker.texture = ICON_PICKED
			marker.modulate = UITokens.ACCENT
			note_color = UITokens.ACCENT
		NodeState.CAN_LEARN:
			marker.texture = null  # D332: на тому, що можна вчити, замка немає
			note_color = UITokens.ACCENT
		NodeState.LOCKED:
			marker.texture = ICON_LOCK
			marker.modulate = UITokens.TEXT_MUTED
	note.add_theme_color_override("font_color", UITokens.ON_ACCENT if selected else note_color)
	node.set_pressed_no_signal(selected)


func _refresh_links() -> void:
	var planned := plan.planned_unlocked()
	var links: Array = []
	for skill_id in _rows:
		for prerequisite in _skill_database.get_skill(skill_id).prerequisites:
			if _rows.has(prerequisite):
				links.append([_rows[prerequisite], _rows[skill_id], prerequisite in planned])
	_links.set_links(links)


# ── Панель деталей (D334) ───────────────────────────────────────────────────

func _refresh_detail() -> void:
	for child in _detail_grid.get_children():
		_detail_grid.remove_child(child)
		child.queue_free()
	var definition: SkillDefinition = _skill_database.get_skill(_selected_id) if _rows.has(_selected_id) else null
	_pick_button.disabled = definition == null or plan.can_pick(definition.id) != SkillManager.Result.OK
	_undo_button.disabled = definition == null or plan.skill_picks(definition.id) == 0
	if definition == null:
		_detail_name.text = PLACEHOLDER
		_detail_kind.text = ""
		_detail_description.text = ""
		_detail_state.text = ""
		_hotbar_box.visible = false
		return

	_detail_name.text = definition.name if not definition.name.is_empty() else definition.id
	var tree: String = _skill_database.class_name_trunk if definition.oath == "" else String(_skill_database.get_oath(definition.oath).name)
	_detail_kind.text = "%s skill · %s" % ["Active" if definition.is_active() else "Passive", tree]
	_detail_description.text = definition.description
	_add_fact("Cost", _cost_text(definition.jp_cost))
	_add_fact("Level", "Lv %d" % definition.required_level)
	if definition.is_active():
		_add_fact("SP", "%d SP" % definition.sp_cost if definition.sp_cost > 0 else PLACEHOLDER)
		_add_fact("Cooldown", "%s s" % String.num(definition.cooldown, 1) if definition.cooldown > 0.0 else PLACEHOLDER)
	var rank := _skill_manager.get_rank(definition.id)
	if rank > 0:
		_add_fact("Rank", "%d / %d" % [rank, SkillManager.MAX_RANK])
	if not definition.prerequisites.is_empty():
		_add_fact("Requires", ", ".join(definition.prerequisites.map(func(id): return String(_skill_database.get_skill(id).name))))
	if not definition.required_weapons.is_empty():
		_add_fact("Weapon", ", ".join(definition.required_weapons))
	var effect := _effect_text(definition)
	if not effect.is_empty():
		_add_fact("Effect", effect)
	_detail_state.text = _reason_text(definition.id)
	_refresh_hotbar(definition)


func _add_fact(caption: String, value: String) -> void:
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"StatLabel"
	_detail_grid.add_child(label)
	var value_label := Label.new()
	value_label.text = value
	value_label.theme_type_variation = &"StatValue"
	_detail_grid.add_child(value_label)


## Що робить навичка — з полів визначення, на поточному ранзі (D150) і з Wisdom (D335), якщо вивчена.
func _effect_text(definition: SkillDefinition) -> String:
	var learned := _skill_manager.is_unlocked(definition.id)
	var parts: Array[String] = []
	if definition.damage > 0:
		parts.append("%d dmg" % (_skill_manager.scaled(definition.id, definition.damage) if learned else definition.damage))
	if definition.heal > 0:
		parts.append("heal %d" % (_skill_manager.scaled(definition.id, definition.heal) if learned else definition.heal))
	if definition.burn_dps > 0:
		parts.append("burn %d/s" % definition.burn_dps)
	if definition.chain_radius > 0.0:
		parts.append("chain ×%s" % String.num(definition.chain_ratio, 1))
	if definition.stun > 0.0:
		parts.append("stun %s s" % String.num(definition.stun, 1))
	if not definition.is_active() and not definition.passive_stat.is_empty():
		var value := definition.passive_value * (1.0 + SkillManager.RANK_BONUS * maxi(0, _skill_manager.get_rank(definition.id) - 1))
		match definition.passive_stat:
			"max_health": parts.append("+%d max HP" % roundi(value))
			"max_sp": parts.append("+%d max SP" % roundi(value))
			"attack": parts.append("+%d attack" % roundi(value))
			"shield_block": parts.append("−%s%% damage with a shield" % _percent(value))
			"damage_reduction": parts.append("−%s%% damage taken" % _percent(value))
			"heal_power": parts.append("heals +%s%%" % _percent(value))
			"sp_regen": parts.append("+%s SP/s" % String.num(value, 2))
			"lifesteal": parts.append("hits heal %s%%" % _percent(value))
			"poise": parts.append("+%s%% poise damage" % _percent(value))
			_: assert(false, "SkillsComponent: no text for passive stat %s" % definition.passive_stat)
	return ", ".join(parts)


## Пояснення бере вердикт SkillManager (через план) — правила тут не дублюються.
func _reason_text(skill_id: String) -> String:
	var definition: SkillDefinition = _skill_database.get_skill(skill_id)
	var picks := plan.skill_picks(skill_id)
	var verdict := plan.can_pick(skill_id)
	if _skill_manager.is_unlocked(skill_id):
		var rank := _skill_manager.get_rank(skill_id)
		var head := "Learned, rank %d/%d" % [rank, SkillManager.MAX_RANK]
		if picks > 0:
			head += " → %d after Accept" % (rank + picks)
		match verdict:
			SkillManager.Result.OK:
				return "%s. Pick to rank up (+10%%, %d JP)." % [head, SkillManager.UPGRADE_COST]
			SkillManager.Result.MAX_RANK:
				return "%s. Max rank." % head
			_:
				return "%s. Not enough JP to rank up." % head
	if picks > 0:
		return "Picked: Accept to learn it." if picks == 1 else "Picked: Accept to learn it at rank %d." % picks
	match verdict:
		SkillManager.Result.OK:
			return "Can learn now: Pick, then Accept."
		SkillManager.Result.NOT_ENOUGH_JP:
			return "Not enough JP (%d needed)." % definition.jp_cost
		SkillManager.Result.LEVEL_TOO_LOW:
			return "Level too low: needs level %d." % definition.required_level
		SkillManager.Result.MISSING_PREREQUISITE:
			var missing: Array = definition.prerequisites.filter(func(id): return not id in plan.planned_unlocked())
			return "Needs %s first." % ", ".join(missing.map(func(id): return String(_skill_database.get_skill(id).name)))
		SkillManager.Result.NO_OATH:
			return "Swear an oath in the City (level %d)." % int(_skill_database.get_oath(definition.oath).level)
		SkillManager.Result.OTHER_OATH:
			return "Sworn to another oath."
		_:
			return ""


## Слоти хотбара — лише для вивченої активної навички (D331).
func _refresh_hotbar(definition: SkillDefinition) -> void:
	_hotbar_box.visible = definition.is_active() and _skill_manager.is_unlocked(definition.id)
	for slot in _slot_buttons.size():
		var held := _skill_manager.get_equipped_skill(slot)
		var held_name := String(_skill_database.get_skill(held).name) if held != "" else "empty"
		_slot_buttons[slot].text = "%d · %s" % [slot + 1, held_name]
		_slot_buttons[slot].set_pressed_no_signal(held == definition.id)


# ── Атрибути і панель дій ───────────────────────────────────────────────────

func _refresh_attributes() -> void:
	_attr_points_value.text = str(plan.attribute_points_left())
	for attribute_id in _attribute_rows:
		var row: HBoxContainer = _attribute_rows[attribute_id]
		var picked := plan.attribute_points(attribute_id)
		var spent := _attributes.get_points(attribute_id)
		row.get_node(^"Value").text = "%d +%d" % [spent, picked] if picked > 0 else str(spent)
		row.get_node(^"Minus").disabled = picked == 0
		row.get_node(^"Plus").disabled = plan.attribute_points_left() <= 0


func _refresh_action_bar() -> void:
	_cancel_button.disabled = plan.is_empty()
	_accept_button.disabled = plan.is_empty()
	if plan.is_empty():
		_pending_label.text = "Nothing picked"
		return
	var parts: Array[String] = []
	if plan.has_skill_picks():
		parts.append("%d JP" % plan.jp_cost())
	var attribute_points := _attributes.get_unspent() - plan.attribute_points_left()
	if attribute_points > 0:
		parts.append("%d attribute pt%s" % [attribute_points, "" if attribute_points == 1 else "s"])
	_pending_label.text = "To spend: " + ", ".join(parts)


# ── Вибір, позначки, Accept ─────────────────────────────────────────────────

func _on_row_selected(skill_id: String) -> void:
	if _selected_id == skill_id:
		return
	_selected_id = skill_id
	_refresh_rows()
	_refresh_detail()
	_publish_details(skill_id)


## Позначити вибрану навичку (кнопка Pick, Enter / A на вузлі). Повертає вердикт SkillManager.
func pick_selected() -> SkillManager.Result:
	if _selected_id.is_empty():
		return SkillManager.Result.UNKNOWN_SKILL
	return plan.pick(_selected_id)


## Зняти останню позначку вибраної навички (кнопка Undo, правий клік, X / Backspace).
func unpick_selected() -> bool:
	return not _selected_id.is_empty() and plan.unpick(_selected_id)


func _pick_attribute(attribute_id: String) -> void:
	plan.pick_attribute(attribute_id)


func _unpick_attribute(attribute_id: String) -> void:
	plan.unpick_attribute(attribute_id)


## Accept (кнопка, Y / F): витратити все позначене.
func accept_plan() -> void:
	if plan.is_empty():
		return
	plan.accept()


## Cancel (кнопка, Esc / B): відкинути позначене.
func cancel_plan() -> void:
	plan.clear()


## Поставити вибрану вивчену активну навичку в слот хотбара (кнопка слота або клавіша / кнопка слота).
func assign_to_slot(slot: int) -> SkillManager.Result:
	var verdict: SkillManager.Result = _skill_manager.equip_skill(_selected_id, slot) if not _selected_id.is_empty() \
			else SkillManager.Result.UNKNOWN_SKILL
	_refresh_detail()  # натиснута кнопка мусить показати, що в слоті насправді
	return verdict


## Enter / геймпад A на вузлі — позначити; X / Backspace / правий клік — зняти позначку (D331).
func _on_row_input(event: InputEvent, skill_id: String) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		_on_row_selected(skill_id)
		unpick_selected()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		_on_row_selected(skill_id)
		pick_selected()
		accept_event()
	elif event.is_action_pressed(&"skills_unpick"):
		_on_row_selected(skill_id)
		unpick_selected()
		accept_event()


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
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"skills_accept"):
		accept_plan()
	elif event.is_action_pressed(&"skills_unpick") and plan.skill_picks(_selected_id) > 0:
		unpick_selected()
	else:
		for slot in SkillManager.SLOT_COUNT:
			if event.is_action_pressed(StringName("skill_slot_%d" % (slot + 1))) and not _selected_id.is_empty():
				assign_to_slot(slot)
				get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()


## Деталі й кнопки — і в нижню панель, щоб клавіатура/геймпад бачили назви кнопок свого пристрою (D289).
func _publish_details(skill_id: String) -> void:
	var bar := get_tree().get_first_node_in_group(&"ui_bottom_bar")
	var definition: SkillDefinition = _skill_database.get_skill(skill_id) if _skill_database and skill_id != "" else null
	if definition == null:
		bar.set_context_hint("")
		return
	bar.set_context_hint(_describe(definition))


## Один рядок для нижньої панелі: назва, головні числа, вердикт, кнопки.
func _describe(definition: SkillDefinition) -> String:
	var parts: Array[String] = []
	parts.append(definition.name if not definition.name.is_empty() else definition.id)
	parts.append("Active" if definition.is_active() else "Passive")
	if definition.jp_cost > 0:
		parts.append("%d JP" % definition.jp_cost)
	if definition.sp_cost > 0:
		parts.append("%d SP" % definition.sp_cost)
	if definition.required_level > 1:
		parts.append("Lv.%d" % definition.required_level)
	parts.append(_reason_text(definition.id))
	parts.append(InputGlyphs.resolve("{ui_accept} Pick · {skills_unpick} Undo · {skills_accept} Accept · {ui_cancel} Cancel"))
	return "  ·  ".join(parts)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		var shown := is_visible_in_tree()
		var party := get_tree().get_first_node_in_group(&"ui_party_column")
		if party:
			party.visible = not shown
		if shown:
			update_display()
		elif plan != null:
			plan.clear()  # D330: з екрана пішли — позначене не витрачається і не зберігається
