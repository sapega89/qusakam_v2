extends BaseMenuComponent

## 🎓 SkillsComponent — екран Skills (BACKLOG 43 + 44, design/skill_screen_rework_plan.md).
## Figma: menu-skills (58:453) — свідомо відходить від двох пласких списків до дерева (D333, рішення Sapega).
##
## Повністю data-driven: у сцені по одному шаблону кожного рядка (D117) — %Tier з вузлом навички в кожній
## смузі, %TreeTab, %Slot1, %Fact, %AttributeRow; решту дають копії через RowFill (ui_rows.gd), стилі — з теми.
## Ряди дерева — рівні, на яких є навички
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
const SkillSlotInput = preload("res://SampleProject/Scripts/UI/skill_slot_input.gd")
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const SkillTooltip = preload("res://SampleProject/Scripts/Systems/SkillTooltip.gd")
## Скільки місць у ряду одного дерева (D333): у даних 1–2 навички на рівень; більше — вузли вужчають, а не ламають вікно.
const NODES_PER_LANE := 2

## Стан вузла (D332).
enum NodeState { LEARNED, PICKED, CAN_LEARN, LOCKED }

@onready var _char_name: Label = %CharName
@onready var _char_class: Label = %CharClass
@onready var _jp_value: Label = %JPValue
@onready var _columns: HBoxContainer = %Columns
@onready var _empty_label: Label = %EmptyLabel
@onready var _tree_tabs: HBoxContainer = %TreeTabs
@onready var _tree_tab: Button = %TreeTab
@onready var _tree_status: Label = %TreeStatus
@onready var _trunk_title: Label = %TrunkTitle
@onready var _tree_stage: Control = %TreeStage
@onready var _tiers: VBoxContainer = %Tiers
@onready var _links: Control = %Links
@onready var _tier: HBoxContainer = %Tier
@onready var _detail_name: Label = %DetailName
@onready var _detail_kind: Label = %DetailKind
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_grid: GridContainer = %DetailGrid
@onready var _fact: Label = %Fact
@onready var _detail_state: Label = %DetailState
@onready var _pick_button: Button = %PickButton
@onready var _undo_button: Button = %UndoButton
@onready var _hotbar_box: VBoxContainer = %HotbarBox
@onready var _hotbar_slots: GridContainer = %HotbarSlots
@onready var _slot_template: Button = %Slot1
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
## Вузли дерева, вже під'єднані (duplicate() копіює meta, тож не за meta-прапорцем); id — у meta skill_id.
var _wired: Dictionary = {}

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
	var oath_ids: Array = _skill_database.oaths.keys()
	var tabs := RowFill.fill(_tree_tabs, _tree_tab, oath_ids.size())
	_rename(tabs, oath_ids)
	for i in tabs.size():
		var tab: Button = tabs[i]
		tab.text = String(_skill_database.get_oath(oath_ids[i]).name)
		tab.button_group = _tab_group
		tab.pressed.connect(show_tree.bind(oath_ids[i]))


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
			_: assert(false, "SkillsComponent: no text for attribute stat %s" % stat)
	return " · ".join(parts)


func _percent(fraction: float) -> String:
	return String.num(fraction * 100.0, 1).trim_suffix(".0")


## Слоти хотбара (D331, вісім — D549): кнопка ставить вибрану вивчену активну навичку в слот.
func _build_slot_buttons() -> void:
	var buttons := RowFill.fill(_hotbar_slots, _slot_template, SkillManager.SLOT_COUNT)
	_rename(buttons, range(1, buttons.size() + 1).map(func(n: int) -> String: return "Slot%d" % n))
	for slot in buttons.size():
		var button: Button = buttons[slot]
		button.pressed.connect(assign_to_slot.bind(slot))
		_slot_buttons.append(button)


## Імена рядків з даних. Спершу тимчасові — щоб нове ім'я не зіткнулося зі старим іменем сусіда
## (інакше Godot мовчки дописує до нього число).
func _rename(rows: Array, names: Array) -> void:
	for i in rows.size():
		rows[i].name = "_%d" % i
	for i in rows.size():
		rows[i].name = String(names[i])


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


	_char_class.text = _skill_manager.class_title()  # D280: Holy Warrior → назва клятви
	# Скільки лишиться після позначеного (D330); без позначок — просто очки героя.
	_jp_value.text = tr("%d JP") % plan.jp_left()


func _trunk() -> Array:
	var character = game_manager.get_active_character() if game_manager else null
	var class_id := String(character.class_id) if character else ""
	return _skill_database.get_all_skills().filter(
			func(d): return d.oath == "" and (d.class_id == "" or d.class_id == class_id))


func _oath_tree() -> Array:
	return _skill_database.get_all_skills().filter(func(d): return d.oath == _shown_oath)


func _rebuild_tree() -> void:
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
	var tiers := RowFill.fill(_tiers, _tier, levels.size())
	_rename(tiers, levels.map(func(level: int) -> String: return "Tier%d" % level))
	for i in tiers.size():
		var level: int = levels[i]
		var tier: HBoxContainer = tiers[i]
		tier.get_node(^"Caption").text = tr("Lv %d") % level
		_fill_lane(tier.get_node(^"TrunkLane"), trunk.filter(func(d): return d.required_level == level))
		_fill_lane(tier.get_node(^"OathLane"), tree.filter(func(d): return d.required_level == level))


## Смуга ряду: вузли (Nodes) і порожнє місце (Pad) на решту з NODES_PER_LANE місць —
## воно тримає стовпці рівними, лінії йдуть прямо вниз.
func _fill_lane(lane: HBoxContainer, definitions: Array) -> void:
	var nodes_box: HBoxContainer = lane.get_node(^"Nodes")
	var pad: Control = lane.get_node(^"Pad")
	var count := definitions.size()
	nodes_box.visible = count > 0
	nodes_box.size_flags_stretch_ratio = maxf(count, 1)
	pad.visible = count < NODES_PER_LANE
	pad.size_flags_stretch_ratio = NODES_PER_LANE - count
	var nodes := RowFill.fill(nodes_box, nodes_box.get_child(0), count)
	_rename(nodes, definitions.map(func(d: SkillDefinition) -> String: return d.id))
	for i in nodes.size():
		_set_node(nodes[i], definitions[i])


func _set_node(node: Button, definition: SkillDefinition) -> void:
	node.set_meta(&"skill_id", definition.id)
	node.button_group = _row_group
	node.tooltip_text = definition.description
	node.get_node(^"Row/SkillName").text = definition.name if not definition.name.is_empty() else definition.id
	_rows[definition.id] = node
	if _wired.has(node):
		return
	_wired[node] = true
	node.pressed.connect(func() -> void: _on_row_selected(node.get_meta(&"skill_id")))
	node.focus_entered.connect(func() -> void: _on_row_selected(node.get_meta(&"skill_id")))
	# gui_input приходить раніше, ніж Button сам «з'їдає» ui_accept: Enter / A на вузлі — позначити (D331).
	node.gui_input.connect(func(event: InputEvent) -> void: _on_row_input(event, node.get_meta(&"skill_id")))


## Стан правого дерева (D280): клятви ще немає / це клятва героя / чужа клятва.
func _tree_status_text() -> String:
	var oath: Dictionary = _skill_database.get_oath(_shown_oath)
	var sworn: String = _skill_manager.get_oath()
	if sworn.is_empty():
		return tr("%s · Swear an oath in the City (level %d)") % [tr(String(oath.tree)), int(oath.level)]
	return "%s · %s" % [tr(String(oath.tree)), tr("Your oath") if sworn == _shown_oath else tr("Sworn to another oath")]


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
			return tr("R%d +%d") % [rank, picks] if picks > 0 else tr("R%d") % rank
		NodeState.PICKED:
			return tr("Picked") if picks == 1 else tr("Picked +%d") % (picks - 1)
		NodeState.CAN_LEARN:
			return _cost_text(definition.jp_cost)
	match plan.can_pick(definition.id):
		SkillManager.Result.LEVEL_TOO_LOW:
			return tr("Lv %d") % definition.required_level
		SkillManager.Result.NO_OATH:
			return tr("Oath")
		SkillManager.Result.OTHER_OATH:
			return tr("Other oath")
		SkillManager.Result.NOT_ENOUGH_JP:
			return _cost_text(definition.jp_cost)
		SkillManager.Result.BASE_TREE_GATE:
			return tr("%d JP") % _skill_manager.base_jp_missing(definition.id, plan.planned_unlocked(), plan.planned_ranks())
		SkillManager.Result.TREE_CAP:
			return tr("Cap")
		SkillManager.Result.PLANNED:
			return tr("Later")
		_:
			return tr("Locked")


func _cost_text(jp: int) -> String:
	return tr("Free") if jp == 0 else tr("%d JP") % jp


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
	var art: TextureRect = node.get_node(^"Row/Art")
	art.texture = load(definition.icon)  # D604: іконка-силует, тон за видом (D602), закрите — приглушене
	art.self_modulate = definition.icon_tint()
	art.modulate.a = 0.45 if state == NodeState.LOCKED else 1.0

	if selected:
		name_label.theme_type_variation = &"SkillNameSelected"
	elif state == NodeState.LOCKED:
		name_label.theme_type_variation = &"SkillNameLocked"
	else:
		name_label.theme_type_variation = &"SkillName"

	note.text = _node_note(definition)
	# Figma малює акцентний текст на акцентній заливці — нечитабельно; на вибраному — контрастний (D26).
	var note_type := &"SkillCostLocked"
	match state:
		NodeState.LEARNED:
			marker.texture = ICON_CHECK
			marker.modulate = UITokens.ACCENT
			note_type = &"SkillCostLearned"
		NodeState.PICKED:
			marker.texture = ICON_PICKED
			marker.modulate = UITokens.ACCENT
			note_type = &"SkillCost"
		NodeState.CAN_LEARN:
			marker.texture = null  # D332: на тому, що можна вчити, замка немає
			note_type = &"SkillCost"
		NodeState.LOCKED:
			marker.texture = ICON_LOCK
			marker.modulate = UITokens.TEXT_MUTED
	note.theme_type_variation = &"SkillCostSelected" if selected else note_type
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
	var definition: SkillDefinition = _skill_database.get_skill(_selected_id) if _rows.has(_selected_id) else null
	_pick_button.disabled = definition == null or plan.can_pick(definition.id) != SkillManager.Result.OK
	_undo_button.disabled = definition == null or plan.skill_picks(definition.id) == 0
	if definition == null:
		_detail_name.text = PLACEHOLDER
		_detail_kind.text = ""
		_detail_description.text = ""
		_detail_state.text = ""
		_hotbar_box.visible = false
		_show_facts([])
		return

	_detail_name.text = definition.name if not definition.name.is_empty() else definition.id
	var tree: String = tr(_skill_database.class_name_trunk if definition.oath == "" else String(_skill_database.get_oath(definition.oath).name))
	_detail_kind.text = tr("%s skill · %s") % [tr("Active") if definition.is_active() else tr("Passive"), tree]
	_detail_description.text = definition.description
	var facts: Array[String] = []
	_add_fact(facts, tr("Cost"), _cost_text(definition.jp_cost))
	_add_fact(facts, tr("Level"), tr("Lv %d") % definition.required_level)
	if definition.is_active():
		_add_fact(facts, "SP", tr("%d SP") % definition.sp_cost if definition.sp_cost > 0 else PLACEHOLDER)
		_add_fact(facts, tr("Cooldown"), tr("%s s") % String.num(definition.cooldown, 1) if definition.cooldown > 0.0 else PLACEHOLDER)
	var rank := _skill_manager.get_rank(definition.id)
	if rank > 0:
		_add_fact(facts, tr("Rank"), "%d / %d" % [rank, SkillManager.MAX_RANK])
	if not definition.prerequisites.is_empty():
		_add_fact(facts, tr("Requires"), ", ".join(definition.prerequisites.map(func(id): return tr(String(_skill_database.get_skill(id).name)))))
	if not definition.required_weapons.is_empty():
		_add_fact(facts, tr("Weapon"), ", ".join(definition.required_weapons))
	var effect := _effect_text(definition)
	if not effect.is_empty():
		_add_fact(facts, tr("Effect"), effect)
	_show_facts(facts)
	_detail_state.text = _reason_text(definition.id)
	_refresh_hotbar(definition)


func _add_fact(facts: Array[String], caption: String, value: String) -> void:
	facts.append(caption)
	facts.append(value)


## Сітка фактів — пари «підпис, значення» з одного шаблону %Fact: парні — StatLabel, непарні — StatValue.
func _show_facts(facts: Array[String]) -> void:
	var labels := RowFill.fill(_detail_grid, _fact, facts.size())
	for i in labels.size():
		labels[i].text = facts[i]
		labels[i].theme_type_variation = &"StatValue" if i % 2 == 1 else &"StatLabel"


## Що робить навичка — з полів визначення, на поточному ранзі (D150), з атакою героя (B137), Wisdom (D335) і синергіями (D496);
## не вивчена — як на першому ранзі. Текст спільний з підказкою (SkillTooltip).
func _effect_text(definition: SkillDefinition) -> String:
	return SkillTooltip.effect_text(_skill_manager, definition, _skill_manager.get_rank(definition.id))


## Пояснення бере вердикт SkillManager (через план) — правила тут не дублюються.
func _reason_text(skill_id: String) -> String:
	var definition: SkillDefinition = _skill_database.get_skill(skill_id)
	var picks := plan.skill_picks(skill_id)
	var verdict := plan.can_pick(skill_id)
	if _skill_manager.is_unlocked(skill_id):
		var rank := _skill_manager.get_rank(skill_id)
		var head := tr("Learned, rank %d/%d") % [rank, SkillManager.MAX_RANK]
		if picks > 0:
			head += tr(" → %d after Accept") % (rank + picks)
		match verdict:
			SkillManager.Result.OK:
				return tr("%s. Pick to rank up (+10%%, %d JP).") % [head, SkillManager.UPGRADE_COST]
			SkillManager.Result.MAX_RANK:
				return tr("%s. Max rank.") % head
			SkillManager.Result.TREE_CAP:
				return tr("%s. This tree's JP cap is reached.") % head
			_:
				return tr("%s. Not enough JP to rank up.") % head
	if picks > 0:
		return tr("Picked: Accept to learn it.") if picks == 1 else tr("Picked: Accept to learn it at rank %d.") % picks
	match verdict:
		SkillManager.Result.OK:
			return tr("Can learn now: Pick, then Accept.")
		SkillManager.Result.NOT_ENOUGH_JP:
			return tr("Not enough JP (%d needed).") % definition.jp_cost
		SkillManager.Result.LEVEL_TOO_LOW:
			return tr("Level too low: needs level %d.") % definition.required_level
		SkillManager.Result.MISSING_PREREQUISITE:
			var missing: Array = definition.prerequisites.filter(func(id): return not id in plan.planned_unlocked())
			return tr("Needs %s first.") % ", ".join(missing.map(func(id): return tr(String(_skill_database.get_skill(id).name))))
		SkillManager.Result.NO_OATH:
			return tr("Swear an oath in the City (level %d).") % int(_skill_database.get_oath(definition.oath).level)
		SkillManager.Result.OTHER_OATH:
			return tr("Sworn to another oath.")
		SkillManager.Result.BASE_TREE_GATE:
			return tr("Needs %d more JP spent in the %s tree.") % [_skill_manager.base_jp_missing(skill_id, plan.planned_unlocked(),
					plan.planned_ranks()), tr(_skill_database.class_name_trunk)]
		SkillManager.Result.TREE_CAP:
			return tr("This tree's JP cap is reached (%d JP).") % _skill_database.tree_cap(definition.oath)
		SkillManager.Result.PLANNED:
			return tr("Coming later: this skill is not built yet.")
		_:
			return ""


## Слоти хотбара — лише для вивченої активної навички (D331).
func _refresh_hotbar(definition: SkillDefinition) -> void:
	_hotbar_box.visible = definition.is_active() and _skill_manager.is_unlocked(definition.id)
	for slot in _slot_buttons.size():
		var held := _skill_manager.get_equipped_skill(slot)
		var held_name := tr(String(_skill_database.get_skill(held).name)) if held != "" else tr("empty")
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
		_pending_label.text = tr("Nothing picked")
		return
	var parts: Array[String] = []
	if plan.has_skill_picks():
		parts.append(tr("%d JP") % plan.jp_cost())
	var attribute_points := _attributes.get_unspent() - plan.attribute_points_left()
	if attribute_points > 0:
		parts.append(tr("attribute points: %d") % attribute_points)
	_pending_label.text = tr("To spend: ") + ", ".join(parts)


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
		# Слот за подією (D549): RT — слот 1, з затиснутим LT — слот 5.
		var slot := SkillSlotInput.slot_for(event)
		if slot >= 0 and not _selected_id.is_empty():
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
	parts.append(tr(definition.name) if not definition.name.is_empty() else definition.id)
	parts.append(tr("Active") if definition.is_active() else tr("Passive"))
	if definition.jp_cost > 0:
		parts.append(tr("%d JP") % definition.jp_cost)
	if definition.sp_cost > 0:
		parts.append(tr("%d SP") % definition.sp_cost)
	if definition.required_level > 1:
		parts.append(tr("Lv.%d") % definition.required_level)
	parts.append(_reason_text(definition.id))
	parts.append(InputGlyphs.resolve(tr("{ui_accept} Pick · {skills_unpick} Undo · {skills_accept} Accept · {ui_cancel} Cancel")))
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
