extends BaseMenuComponent

## 🎓 SkillsComponent — вікно навичок Dragon Nest (D674, Figma 533:6472, design/shots/figma_skills_dragon_nest.png).
##
## Зверху — вкладки чотирьох дерев; дві панелі дерев поруч: ліворуч базове (Holy Warrior), праворуч клятва героя,
## а до клятви — та, чию вкладку вибрано (D280). Клітинки лежать за SkillDefinition.slot: навичка просто під своєю
## передумовою, лінія золота, коли передумову вивчено або позначено. На клітинці — іконка (тон D605), ранг під нею,
## бейдж рівня на невивченій (червоний, поки герой нижче), «+», коли можна взяти ще ранг.
## Праворуч — деталі (D334): назва, вид, ранг зараз і далі, ефект зараз і на наступному ранзі, SP, перезарядка,
## рівень, Learn +1 і Reset. Унизу — очки навичок, бюджети дерев (D497), скільки очок атрибутів чекає у Status
## (D741: атрибути вкладаються там), Cancel / Accept плану і Reset all (платне скидання на місці медитації, D628/D629).
##
## Нічого не витрачається одним натисканням (D330): Learn +1 позначає ранг у SkillPlan, витрачає лише Accept.
## UI НЕ редагує player_state і НЕ дублює правила: чому навичка недоступна — завжди вердикт SkillManager
## (через SkillPlan.can_pick). Розкладка — у сцені (один шаблон клітинки %Cell, вкладки %TreeTab, факту %Fact,
## слота %Slot1); копії дає RowFill (ui_rows.gd), стилі — тема (UITokens, D674).
##
## SP героя тут свідомо НЕ показується (рішення D27): це бойовий ресурс, його місце — бойовий HUD.

const PLACEHOLDER := "—"
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const SkillSlotInput = preload("res://SampleProject/Scripts/UI/skill_slot_input.gd")
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const SkillTooltip = preload("res://SampleProject/Scripts/Systems/SkillTooltip.gd")
const ModalTemplates = preload("res://SampleProject/Scripts/UI/modal_templates.gd")

## Стан клітинки (D332).
enum NodeState { LEARNED, PICKED, CAN_LEARN, LOCKED }

@onready var _hero_line: Label = %HeroLine
@onready var _jp_value: Label = %JPValue
@onready var _budgets: Label = %Budgets
@onready var _columns: HBoxContainer = %Columns
@onready var _empty_label: Label = %EmptyLabel
@onready var _tree_tabs: HBoxContainer = %TreeTabs
@onready var _tree_tab: Button = %TreeTab
@onready var _left_panel: PanelContainer = %LeftPanel
@onready var _right_panel: PanelContainer = %RightPanel
@onready var _cell: VBoxContainer = %Cell
@onready var _detail: VBoxContainer = %Detail
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_name: Label = %DetailName
@onready var _detail_kind: Label = %DetailKind
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_grid: GridContainer = %DetailGrid
@onready var _fact: Label = %Fact
@onready var _next_caption: Label = %NextCaption
@onready var _next_text: Label = %NextText
@onready var _detail_state: Label = %DetailState
@onready var _learn_button: Button = %LearnButton
@onready var _reset_button: Button = %ResetButton
@onready var _hotbar_box: VBoxContainer = %HotbarBox
@onready var _hotbar_slots: GridContainer = %HotbarSlots
@onready var _slot_template: Button = %Slot1
@onready var _pending_label: Label = %PendingLabel
@onready var _cancel_button: Button = %CancelButton
@onready var _accept_button: Button = %AcceptButton
@onready var _attr_points_hint: Label = %AttrPointsHint
@onready var _reset_all_button: Button = %ResetAllButton

## Що позначено, але ще не прийнято (D330).
var plan: SkillPlan
var _selected_id: String = ""
var _slot_group := ButtonGroup.new()
var _rows: Dictionary = {}  # skill_id -> Button (клітинка навички)
var _shown_oath: String = ""
var _slot_buttons: Array[Button] = []
## Клітинки, яким уже під'єднано сигнали (RowFill перевикористовує їх між перебудовами).
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
	_build_slot_buttons()
	_learn_button.pressed.connect(pick_selected)
	_reset_button.pressed.connect(reset_selected)
	_cancel_button.pressed.connect(cancel_plan)
	_accept_button.pressed.connect(accept_plan)
	_reset_all_button.pressed.connect(ask_reset_all)
	for panel: PanelContainer in [_left_panel, _right_panel]:
		var grid: GridContainer = _grid(panel)
		grid.sort_children.connect(_links(panel).queue_redraw)
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
	_refresh()


func _on_oath_sworn(oath_id: String) -> void:
	_shown_oath = oath_id
	update_display()


func _on_skills_reset(_refunded: int) -> void:
	plan.clear()
	update_display()


func _on_loadout_changed(_loadout: Array) -> void:
	_refresh_detail()


## Вкладки — базове дерево і клятви з даних (skills.json → oaths), у порядку файлу (D674).
func _build_tabs() -> void:
	var tree_ids: Array = [""] + _skill_database.oaths.keys()
	var tabs := RowFill.fill(_tree_tabs, _tree_tab, tree_ids.size())
	_rename(tabs, tree_ids.map(func(id: String) -> String: return "Base" if id == "" else id))
	for i in tabs.size():
		var tab: Button = tabs[i]
		tab.text = _tree_name(tree_ids[i])
		tab.pressed.connect(show_tree.bind(tree_ids[i]))


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


## Вкладка (клавіатура, геймпад, миша): базове дерево — фокус у ліву панель; клятва — показати її праворуч
## (після клятви інші клятви закриті, D489) і фокус туди.
func show_tree(tree_id: String) -> void:
	assert(tree_id == "" or tree_id == _skill_manager.get_oath(), "SkillsComponent: only the chosen path's tree is shown (D728)")
	update_display()
	var cells := _cells_of(tree_id)
	if not cells.is_empty() and is_visible_in_tree():
		_rows[cells[0]].grab_focus()


func _tree_name(tree_id: String) -> String:
	return tr(_skill_database.class_name_trunk) if tree_id == "" else tr(String(_skill_database.get_oath(tree_id).name))


# ── Побудова ────────────────────────────────────────────────────────────────

func update_display() -> void:
	if not is_node_ready() or _skill_manager == null:
		return
	# D728: базове дерево і лише дерево обраного шляху; інших двох не видно зовсім (ні вкладок, ні панелі).
	_shown_oath = _skill_manager.get_oath()
	for tab: Button in _tree_tabs.get_children():
		var tree_id := "" if tab.name == "Base" else String(tab.name)
		tab.visible = tree_id == "" or tree_id == _shown_oath
		tab.set_pressed_no_signal(tab.visible)
	_right_panel.visible = _shown_oath != ""
	# Перебудова звільняє клітинки — фокус клавіатури/геймпада повертаємо на вибрану.
	var focused := get_viewport().gui_get_focus_owner()
	var had_row_focus := focused != null and focused in _rows.values()
	_rebuild_trees()
	_link_focus()
	if not _rows.has(_selected_id) and not _rows.is_empty():
		_selected_id = _cells_of("")[0] if not _cells_of("").is_empty() else _rows.keys()[0]
	if had_row_focus and _rows.has(_selected_id):
		_rows[_selected_id].grab_focus()
	_refresh()


## Усе, що залежить від плану й очок, без перебудови дерев.
func _refresh() -> void:
	if not is_node_ready() or _skill_manager == null:
		return
	_refresh_header()
	_refresh_cells()
	_refresh_links()
	_refresh_detail()
	_refresh_bottom_bar()
	_publish_details(_selected_id)


func _refresh_header() -> void:
	var character = game_manager.get_active_character() if game_manager else null
	var hero := tr(String(character.name)) if character else PLACEHOLDER
	_hero_line.text = tr("Lv %d · %s") % [_hero_level(), hero]


func _hero_level() -> int:
	return ServiceLocatorHelper.get_service_locator().get_xp_manager().get_level()


func _tree_skills(tree_id: String) -> Array:
	var character = game_manager.get_active_character() if game_manager else null
	var class_id := String(character.class_id) if character else ""
	return _skill_database.get_all_skills().filter(
			func(d: SkillDefinition) -> bool: return d.oath == tree_id and (d.class_id == "" or d.class_id == class_id))


## Id навичок дерева в порядку клітинок (ряд за рядом) — для фокуса вкладки.
func _cells_of(tree_id: String) -> Array:
	var skills := _tree_skills(tree_id)
	skills.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
			return a.slot.y < b.slot.y or (a.slot.y == b.slot.y and a.slot.x < b.slot.x))
	return skills.map(func(d: SkillDefinition) -> String: return d.id)


func _grid(panel: PanelContainer) -> GridContainer:
	return panel.get_node(^"Tree/Stage/Grid")


func _links(panel: PanelContainer) -> Control:
	return panel.get_node(^"Tree/Stage/Links")


func _rebuild_trees() -> void:
	_rows.clear()
	var trunk := _tree_skills("")
	var oath := _tree_skills(_shown_oath) if _shown_oath != "" else []
	# Чесний порожній стан: немає жодної навички для цього героя.
	var has_any := not trunk.is_empty() or not oath.is_empty()
	_columns.visible = has_any
	_empty_label.visible = not has_any
	if not has_any:
		return
	_fill_panel(_left_panel, "", trunk)
	if _shown_oath != "":
		_fill_panel(_right_panel, _shown_oath, oath)


## Панель дерева: заголовок, стан клятви і сітка SKILL_GRID_COLUMNS × SKILL_GRID_ROWS з клітинок за slot.
func _fill_panel(panel: PanelContainer, tree_id: String, definitions: Array) -> void:
	var heading: Label = panel.get_node(^"Tree/Heading")
	var status: Label = panel.get_node(^"Tree/Status")
	if tree_id == "":
		heading.text = _tree_name("")
		status.text = ""
	else:
		heading.text = "%s · %s" % [_tree_name(tree_id), tr(String(_skill_database.get_oath(tree_id).tree))]
		var opens := int(_skill_database.get_oath(tree_id).level)
		status.text = tr("Opens at level %d") % opens if _hero_level() < opens else ""
	status.visible = not status.text.is_empty()
	var by_cell := {}
	for definition: SkillDefinition in definitions:
		var at := definition.slot.y * UITokens.SKILL_GRID_COLUMNS + definition.slot.x
		assert(not by_cell.has(at), "SkillsComponent: two skills in one cell (%s)" % definition.id)
		by_cell[at] = definition
	var cells := RowFill.fill(_grid(panel), _cell, UITokens.SKILL_GRID_COLUMNS * UITokens.SKILL_GRID_ROWS)
	_rename(cells, range(cells.size()).map(func(at: int) -> String: return by_cell[at].id if by_cell.has(at) else "Empty%d" % at))
	for at in cells.size():
		var cell: VBoxContainer = cells[at]
		var definition: SkillDefinition = by_cell.get(at)
		var slot: Button = cell.get_node(^"Slot")
		# Порожнє місце тримає сітку: клітинка є, але її не видно і на неї не стати фокусом.
		cell.modulate.a = 1.0 if definition else 0.0
		slot.focus_mode = Control.FOCUS_ALL if definition else Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if definition else Control.MOUSE_FILTER_IGNORE
		if definition:
			_set_cell(slot, definition)
		else:
			slot.get_node(^"LevelBadge/Label").text = ""
			cell.get_node(^"Rank").text = ""


func _set_cell(slot: Button, definition: SkillDefinition) -> void:
	slot.set_meta(&"skill_id", definition.id)
	slot.button_group = _slot_group
	slot.tooltip_text = "%s\n%s" % [tr(definition.name), tr(definition.description)]
	var art: TextureRect = slot.get_node(^"Art")
	art.texture = load(definition.icon)  # D604: іконка-силует, тон за видом (D602, D605)
	art.self_modulate = definition.icon_tint()
	_rows[definition.id] = slot
	if _wired.has(slot):
		return
	_wired[slot] = true
	slot.pressed.connect(func() -> void: _on_row_selected(slot.get_meta(&"skill_id")))
	slot.focus_entered.connect(func() -> void: _on_row_selected(slot.get_meta(&"skill_id")))
	# gui_input приходить раніше, ніж Button сам «з'їдає» ui_accept: Enter / A на клітинці — Learn +1 (D331).
	slot.gui_input.connect(func(event: InputEvent) -> void: _on_row_input(event, slot.get_meta(&"skill_id")))


## Клавіатура / геймпад уздовж ряду (D674): ліворуч / праворуч — найближча навичка цього ряду, через порожні клітинки
## і з панелі в панель (Godot сам інколи стрибає на вкладки). Вгору / вниз — пошук Godot: у сітці він точний.
func _link_focus() -> void:
	var rows := {}  # ряд → [[x у вікні, клітинка], ...]
	for skill_id: String in _rows:
		var slot: Button = _rows[skill_id]
		var definition: SkillDefinition = _skill_database.get_skill(skill_id)
		var right_panel := slot.get_parent().get_parent() == _grid(_right_panel)
		var x := definition.slot.x + (UITokens.SKILL_GRID_COLUMNS if right_panel else 0)
		rows.get_or_add(definition.slot.y, []).append([x, slot])
	for row: Array in rows.values():
		row.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in row.size():
			var slot: Button = row[i][1]
			slot.focus_neighbor_left = slot.get_path_to(row[i - 1][1]) if i > 0 else NodePath()
			slot.focus_neighbor_right = slot.get_path_to(row[i + 1][1]) if i < row.size() - 1 else NodePath()


# ── Стани клітинок (D332) ───────────────────────────────────────────────────

func node_state(skill_id: String) -> NodeState:
	if _skill_manager.is_unlocked(skill_id):
		return NodeState.LEARNED
	if plan.skill_picks(skill_id) > 0:
		return NodeState.PICKED
	return NodeState.CAN_LEARN if plan.can_pick(skill_id) == SkillManager.Result.OK else NodeState.LOCKED


## «2 / 3» під клітинкою — ранг після Accept з найвищим рангом навички (D674).
func rank_text(skill_id: String) -> String:
	return "%d / %d" % [plan.planned_rank(skill_id), _skill_database.get_skill(skill_id).max_rank]


func _refresh_cells() -> void:
	for skill_id: String in _rows:
		_apply_cell_state(_skill_database.get_skill(skill_id), _rows[skill_id])


## Стан клітинки визначає SkillManager (через план) — UI лише малює його вердикт.
func _apply_cell_state(definition: SkillDefinition, slot: Button) -> void:
	var state := node_state(definition.id)
	var owned := state == NodeState.LEARNED or state == NodeState.PICKED
	slot.theme_type_variation = &"SkillSlotLearned" if owned else &"SkillSlot"
	slot.set_pressed_no_signal(definition.id == _selected_id)
	var art: TextureRect = slot.get_node(^"Art")
	art.modulate.a = UITokens.SKILL_LOCKED_ICON_ALPHA if state == NodeState.LOCKED else 1.0
	var badge: PanelContainer = slot.get_node(^"LevelBadge")
	badge.visible = not owned
	var badge_label: Label = badge.get_node(^"Label")
	badge_label.text = tr("Lv %d") % definition.required_level
	badge_label.theme_type_variation = &"SkillLevelBadgeLow" if _hero_level() < definition.required_level \
			else &"SkillLevelBadgeLabel"
	# «+» — на вивченій (чи позначеній) навичці, що бере ще ранг (Figma); невивчену видно з яскравої іконки.
	slot.get_node(^"Plus").visible = owned and plan.can_pick(definition.id) == SkillManager.Result.OK
	var rank: Label = slot.get_parent().get_node(^"Rank")
	rank.text = rank_text(definition.id)
	rank.theme_type_variation = &"SkillRankPlanned" if plan.skill_picks(definition.id) > 0 else &"SkillRank"


func _refresh_links() -> void:
	var planned := plan.planned_unlocked()
	for panel: PanelContainer in [_left_panel, _right_panel]:
		var grid := _grid(panel)
		var links: Array = []
		for skill_id: String in _rows:
			var slot: Button = _rows[skill_id]
			if slot.get_parent().get_parent() != grid:
				continue
			for prerequisite: String in _skill_database.get_skill(skill_id).prerequisites:
				# Передумова з іншого дерева (Bulwark ← Shield Block) — без лінії: вона в сусідній панелі.
				if _rows.has(prerequisite) and _rows[prerequisite].get_parent().get_parent() == grid:
					# Від клітинки передумови разом з підписом рангу — лінія не перекреслює «1 / 3».
					links.append([_rows[prerequisite].get_parent(), slot, prerequisite in planned])
		_links(panel).set_links(links)


# ── Панель деталей (D334, D674) ─────────────────────────────────────────────

func _refresh_detail() -> void:
	var definition: SkillDefinition = _skill_database.get_skill(_selected_id) if _rows.has(_selected_id) else null
	_learn_button.disabled = definition == null or plan.can_pick(definition.id) != SkillManager.Result.OK
	_reset_button.disabled = definition == null or plan.skill_picks(definition.id) == 0
	if definition == null:
		_detail_icon.texture = null
		_detail_name.text = PLACEHOLDER
		_detail_kind.text = ""
		_detail_description.text = ""
		_next_text.text = ""
		_detail_state.text = ""
		_hotbar_box.visible = false
		_show_facts([])
		return

	_detail_icon.texture = load(definition.icon)
	_detail_icon.self_modulate = definition.icon_tint()
	_detail_name.text = tr(definition.name) if not definition.name.is_empty() else definition.id
	var kind := tr("Active") if definition.is_active() else tr("Passive")
	var rank := plan.planned_rank(definition.id)
	_detail_kind.text = "%s · %s · %s" % [kind, _tree_name(definition.oath), tr("Rank %d / %d") % [rank, definition.max_rank]]
	_detail_description.text = tr(definition.description)

	var now := SkillTooltip.values(_skill_manager, definition, rank) if rank > 0 else {}
	var at_max := rank >= definition.max_rank
	var next := SkillTooltip.values(_skill_manager, definition, rank + 1) if not at_max else {}
	var facts: Array[String] = []
	for row: Array in [["damage", tr("Damage")], ["heal", tr("Heal")], ["burn_dps", tr("Burn per second")]]:
		if int(SkillTooltip.values(_skill_manager, definition, 1)[row[0]]) > 0:
			_add_fact(facts, row[1], _now_next(str(now.get(row[0], PLACEHOLDER)), str(next.get(row[0], ""))))
	if not definition.is_active():
		var effect_now := SkillTooltip.effect_text(_skill_manager, definition, rank) if rank > 0 else PLACEHOLDER
		var effect_next := SkillTooltip.effect_text(_skill_manager, definition, rank + 1) if not at_max else ""
		_add_fact(facts, tr("Effect"), _now_next(effect_now, effect_next))
	if definition.is_active():
		_add_fact(facts, tr("SP cost"), str(_skill_manager.sp_cost(definition)) if definition.sp_cost > 0 else PLACEHOLDER)
		# Перезарядка лише в ультимейтів (D504) — рядок «—» в інших нічого не каже, а місця на 19 навичок мало.
		if definition.cooldown > 0.0:
			_add_fact(facts, tr("Cooldown"), tr("%s s") % String.num(definition.cooldown, 1))
	_add_fact(facts, tr("Required level"), str(definition.required_level))
	_add_fact(facts, tr("Rank cost"), tr("%d JP") % (definition.jp_cost if rank == 0 else definition.rank_jp))
	if not definition.required_weapons.is_empty():
		_add_fact(facts, tr("Weapon"), ", ".join(definition.required_weapons))
	_show_facts(facts)

	_next_caption.visible = not at_max
	_next_text.visible = not at_max
	_next_text.text = _next_rank_text(definition, rank)
	_detail_state.text = _reason_text(definition.id)
	_refresh_hotbar(definition)


## «104 → 126»; на найвищому ранзі — лише теперішнє.
func _now_next(now: String, next: String) -> String:
	return now if next.is_empty() else "%s  →  %s" % [now, next]


## Що дасть наступний ранг одним рядком (Figma: «+22 damage, …»); невивчена — ефект першого рангу.
func _next_rank_text(definition: SkillDefinition, rank: int) -> String:
	if rank >= definition.max_rank:
		return ""
	if rank == 0:
		return SkillTooltip.effect_text(_skill_manager, definition, 1)
	var now := SkillTooltip.values(_skill_manager, definition, rank)
	var next := SkillTooltip.values(_skill_manager, definition, rank + 1)
	var parts: Array[String] = []
	if int(next.damage) > int(now.damage):
		parts.append(tr("+%d damage") % (int(next.damage) - int(now.damage)))
	if int(next.heal) > int(now.heal):
		parts.append(tr("+%d healing") % (int(next.heal) - int(now.heal)))
	if int(next.burn_dps) > int(now.burn_dps):
		parts.append(tr("+%d burn per second") % (int(next.burn_dps) - int(now.burn_dps)))
	if not definition.is_active():
		parts.append(SkillTooltip.effect_text(_skill_manager, definition, rank + 1))
	return ", ".join(parts)


func _add_fact(facts: Array[String], caption: String, value: String) -> void:
	facts.append(caption)
	facts.append(value)


## Сітка фактів — пари «підпис, значення» з одного шаблону %Fact: підпис ліворуч, значення праворуч.
func _show_facts(facts: Array[String]) -> void:
	var labels := RowFill.fill(_detail_grid, _fact, facts.size())
	for i in labels.size():
		var label: Label = labels[i]
		label.text = facts[i]
		label.theme_type_variation = &"SkillFactValue" if i % 2 == 1 else &"SkillFactLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i % 2 == 1 else HORIZONTAL_ALIGNMENT_LEFT


## Пояснення бере вердикт SkillManager (через план) — правила тут не дублюються.
func _reason_text(skill_id: String) -> String:
	var definition: SkillDefinition = _skill_database.get_skill(skill_id)
	var picks := plan.skill_picks(skill_id)
	var verdict := plan.can_pick(skill_id)
	if picks > 0:
		return tr("Picked: Accept to learn it.") if not _skill_manager.is_unlocked(skill_id) and picks == 1 \
				else tr("Rank %d after Accept.") % plan.planned_rank(skill_id)
	match verdict:
		SkillManager.Result.OK:
			return tr("Learn +1 marks it; Accept spends the JP.")
		SkillManager.Result.MAX_RANK:
			return tr("Max rank.")
		SkillManager.Result.NOT_ENOUGH_JP:
			return tr("Not enough JP (%d needed).") % (definition.rank_jp if _skill_manager.is_unlocked(skill_id) else definition.jp_cost)
		SkillManager.Result.LEVEL_TOO_LOW:
			return tr("Level too low: needs level %d.") % definition.required_level
		SkillManager.Result.MISSING_PREREQUISITE:
			var missing: Array = definition.prerequisites.filter(func(id: String) -> bool: return not id in plan.planned_unlocked())
			return tr("Needs %s first.") % ", ".join(missing.map(func(id: String) -> String: return tr(String(_skill_database.get_skill(id).name))))
		SkillManager.Result.NO_OATH:
			return tr("Choose your path at the census by the City Gate.")
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
		var held_skill: SkillDefinition = _skill_database.get_skill(held) if held != "" else null
		var button := _slot_buttons[slot]
		# Вісім слотів в один ряд, як хотбар у бою: іконка навички, номер клавіші в кутку, назва — у підказці.
		button.tooltip_text = "%d · %s" % [slot + 1, tr(String(held_skill.name)) if held_skill else tr("empty")]
		var art: TextureRect = button.get_node(^"Art")
		art.texture = load(held_skill.icon) if held_skill else null
		art.self_modulate = held_skill.icon_tint() if held_skill else Color.WHITE
		button.get_node(^"Key/Label").text = str(slot + 1)
		button.set_pressed_no_signal(held == definition.id)


# ── Нижня смуга ─────────────────────────────────────────────────────────────

## Очки навичок після плану, бюджети дерев (D497: «Holy Warrior 9 / 14 · Paladin 12 / 12»), план, Reset all.
func _refresh_bottom_bar() -> void:
	_jp_value.text = str(plan.jp_left())
	var unlocked := plan.planned_unlocked()
	var ranks := plan.planned_ranks()
	var parts: Array[String] = []
	for tree_id: String in [""] + ([_skill_manager.get_oath()] if _skill_manager.get_oath() != "" else []):
		parts.append("%s %d / %d" % [_tree_name(tree_id), _skill_manager.tree_spent(tree_id, unlocked, ranks),
				_skill_database.tree_cap(tree_id)])
	_budgets.text = "  ·  ".join(parts)
	# D741: атрибути вкладаються у Status — тут лише скільки їх там чекає.
	_attr_points_hint.visible = _attributes.get_unspent() > 0
	_attr_points_hint.text = tr("Attribute points: %d · in Status") % _attributes.get_unspent()

	_cancel_button.visible = not plan.is_empty()
	_accept_button.visible = not plan.is_empty()
	_pending_label.visible = not plan.is_empty()
	if not plan.is_empty():
		_pending_label.text = tr("To spend: ") + tr("%d JP") % plan.jp_cost()

	# D629: Reset all — платне скидання (D628), лише на місці медитації.
	var verdict := _skill_manager.can_respec()
	_reset_all_button.disabled = verdict != SkillManager.Result.OK
	match verdict:
		SkillManager.Result.NOT_MEDITATING:
			_reset_all_button.tooltip_text = tr("Reset at a meditation spot")
		SkillManager.Result.NOT_ENOUGH_COINS:
			_reset_all_button.tooltip_text = tr("Not enough coins (%d needed)") % _skill_manager.respec_price()
		SkillManager.Result.NOTHING_TO_RESET:
			_reset_all_button.tooltip_text = ""
		_:
			_reset_all_button.tooltip_text = tr("Forget every skill and attribute point for %d coins") % _skill_manager.respec_price()


# ── Вибір, позначки, Accept ─────────────────────────────────────────────────

func _on_row_selected(skill_id: String) -> void:
	if _selected_id == skill_id:
		return
	_selected_id = skill_id
	_refresh_cells()
	_refresh_detail()
	_publish_details(skill_id)


## Learn +1 (кнопка, Enter / A на клітинці): позначити ще один ранг. Повертає вердикт SkillManager.
func pick_selected() -> SkillManager.Result:
	if _selected_id.is_empty():
		return SkillManager.Result.UNKNOWN_SKILL
	return plan.pick(_selected_id)


## Зняти останню позначку вибраної навички (правий клік, X / Backspace).
func unpick_selected() -> bool:
	return not _selected_id.is_empty() and plan.unpick(_selected_id)


## Reset у деталях: зняти всі позначки вибраної навички (вивчене не чіпає — це Reset all, D628).
func reset_selected() -> void:
	while unpick_selected():
		pass


## Accept (кнопка, Y / F): витратити все позначене.
func accept_plan() -> void:
	if plan.is_empty():
		return
	plan.accept()


## Cancel (кнопка, Esc / B): відкинути позначене.
func cancel_plan() -> void:
	plan.clear()


## Reset all: питає підтвердження, бо скидання коштує монет (D628).
func ask_reset_all() -> void:
	if _skill_manager.can_respec() != SkillManager.Result.OK:
		return
	var ui_manager: Node = ServiceLocatorHelper.get_service_locator().get_ui_manager()
	ui_manager.get_modal_layer().modal_closed.connect(_on_reset_all_closed, CONNECT_ONE_SHOT)
	ui_manager.show_modal(ModalTemplates.confirm_respec(_skill_manager.respec_price()))


func _on_reset_all_closed(result: String) -> void:
	if result == "confirm":
		_skill_manager.respec()


## Поставити вибрану вивчену активну навичку в слот хотбара (кнопка слота або клавіша / кнопка слота).
func assign_to_slot(slot: int) -> SkillManager.Result:
	var verdict: SkillManager.Result = _skill_manager.equip_skill(_selected_id, slot) if not _selected_id.is_empty() \
			else SkillManager.Result.UNKNOWN_SKILL
	_refresh_detail()  # натиснута кнопка мусить показати, що в слоті насправді
	return verdict


## Enter / геймпад A на клітинці — Learn +1; X / Backspace / правий клік — зняти позначку (D331).
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


## Один рядок для нижньої панелі: назва, ранг, вердикт, кнопки.
func _describe(definition: SkillDefinition) -> String:
	var parts: Array[String] = []
	parts.append(tr(definition.name) if not definition.name.is_empty() else definition.id)
	parts.append(rank_text(definition.id))
	if plan.planned_rank(definition.id) < definition.max_rank:
		parts.append(tr("%d JP") % (definition.rank_jp if plan.planned_rank(definition.id) > 0 else definition.jp_cost))
	if definition.sp_cost > 0:
		parts.append(tr("%d SP") % _skill_manager.sp_cost(definition))
	parts.append(_reason_text(definition.id))
	parts.append(InputGlyphs.resolve(tr("{ui_accept} Learn +1 · {skills_unpick} Undo · {skills_accept} Accept · {ui_cancel} Cancel")))
	return "  ·  ".join(parts)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		var shown := is_visible_in_tree()
		if shown:
			update_display()
		elif plan != null:
			plan.clear()  # D330: з екрана пішли — позначене не витрачається і не зберігається
