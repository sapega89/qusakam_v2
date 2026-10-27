extends BaseMenuComponent

## 📔 JournalComponent — журнал завдань.
## Figma: journal-main-story (192:1529) — з нього взято лише візуальну мову
## (титульний блок, дві колонки, нижня панель). Контент кадру — персонажний
## кодекс із вигаданими іменами — визнано застарілим (рішення D52).
##
## Дані: етапи сюжету з GameFlow.journal_entries() (D120). Пункт журналу —
## підетап (зона); зліва заголовок етапу і пункти, справа — текст обраного
## пункту: його хроніка (D122). Під підетапом — його цілі-підпункти (D125).
## Береться щоразу, коли вкладку показано. Рядки — шаблони зі сцени (D117).
## set_entries() лишається входом і для тестових фікстур.

## Рядки з шаблону сцени (D117). preload, а не class_name: редактор бачить
## новий class_name лише після перескану, і скрипт до того не парсився.
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")
const EMPTY_TEXT := "No journal entries yet."
## load(), не preload: сервіс тягне Game (як у NpcBase).
const TASKS_PATH := "res://SampleProject/Scripts/Tasks/task_service.gd"

## Розділи журналу (BACKLOG 13, D290; Notes — Q87): вкладки над списком, ті самі колонки «список + текст».
## [id, заголовок сторінки, підпис списку, порожній стан]
const SECTIONS := {
	"quests": ["Quests", "", "No journal entries yet."],
	"characters": ["Characters", "PEOPLE MET", "You have not met anyone yet."],
	"bestiary": ["Bestiary", "ENEMIES MET", "No enemies met yet."],
	"notes": ["Notes", "NOTES FOUND", "No notes found yet."],
}
const PLACEHOLDER := "—"
## Ідентифікатор підпункту поточної цілі з HUD під поточним підетапом (BACKLOG 37).
const LIVE_OBJECTIVE := "live_objective"
## Герби шляхів (D725): вузол у %PathEmblems → шлях OathLeanings і навичка шляху, чия іконка — герб.
const PATH_EMBLEMS := {"Samal": ["samal", "radiant_smite"], "Contract": ["contract", "blood_pact"],
	"NoGod": ["none", "balanced_strike"]}

## Мінімальний контракт запису. Реальні дані згодом мапимо сюди,
## не перебудовуючи сцену.
const FIELDS := ["id", "title", "state", "objectives", "description", "group", "parent"]

## Позначка стану підетапу в списку. Закритий підетап не відкривається.
const ZONE_MARKS := {"done": "✓", "current": "●", "locked": "○"}

@onready var _eyebrow: Label = %Eyebrow
@onready var _heading: Label = %Heading
@onready var _objective_panel: PanelContainer = %Objective
@onready var _objective_text: Label = %ObjectiveText
@onready var _columns: HBoxContainer = %Columns
@onready var _entry_list: VBoxContainer = %EntryList
@onready var _detail: VBoxContainer = %Detail
@onready var _detail_title: Label = %DetailTitle
## Портрет зустрінутої людини (D321 — ті самі портрети, що у вікні діалогу); у кого портрета нема — без рамки.
@onready var _portrait_frame: PanelContainer = %PortraitBackground
@onready var _portrait: TextureRect = %Portrait
@onready var _detail_state: Label = %DetailState
@onready var _detail_description: Label = %DetailDescription
@onready var _objectives_caption: Label = %ObjectivesCaption
@onready var _objective_list: VBoxContainer = %ObjectiveList
@onready var _entry_row: Button = %EntryRow
@onready var _list_header: Label = %ListHeader
@onready var _objective_line: Label = %ObjectiveLine
@onready var _empty_state: Label = %EmptyState
@onready var _tabs: Dictionary = {"quests": %QuestsTab, "characters": %CharactersTab, "bestiary": %BestiaryTab,
	"notes": %NotesTab}
## Characters — картка персонажа (D486, Figma 192:1754): зліва пергамент зі світлом над місцем зустрічі,
## справа ілюстрація (поки — портрет D321, nearest), під нею епітет та ім'я. ←/→ — інша людина, A / Enter — опис.
@onready var _card: HBoxContainer = %PersonCard
@onready var _map_view: Control = %MapView
@onready var _parchment: TextureRect = %Parchment
@onready var _light: ColorRect = %Light
@onready var _place: Label = %PlaceLabel
@onready var _pager: Label = %Pager
@onready var _about_panel: PanelContainer = %AboutPanel
@onready var _about_text: Label = %AboutText
@onready var _illustration: TextureRect = %Illustration
@onready var _epithet: Label = %Epithet
@onready var _card_name: Label = %CardName
@onready var _path_emblems: HBoxContainer = %PathEmblems

var entries: Array = []
var selected_id: String = ""
var section: String = "quests"

var _game: Node = null
var _wired: Dictionary = {}  # рядки списку, вже під'єднані до сигналів


func _initialize_component() -> void:
	add_to_group(&"journal_screen")
	for id: String in _tabs:
		(_tabs[id] as Button).pressed.connect(select_section.bind(id))
	_connect_objective()
	(_tabs["characters"] as Button).focus_neighbor_bottom = _card.get_path()
	_about_panel.custom_minimum_size.x = UITokens.CARD_DESCRIPTION_WIDTH
	var light := _light.material as ShaderMaterial
	light.set_shader_parameter(&"shade_color", UITokens.CARD_SHADE)
	light.set_shader_parameter(&"radius", UITokens.CARD_LIGHT_RADIUS)
	light.set_shader_parameter(&"softness", UITokens.CARD_LIGHT_SOFTNESS)
	%PrevButton.pressed.connect(show_next_person.bind(-1))
	%NextButton.pressed.connect(show_next_person.bind(1))
	_card.gui_input.connect(_on_card_input)
	_map_view.resized.connect(_place_parchment)
	for node_name: String in PATH_EMBLEMS:
		var icon: TextureRect = _path_emblems.get_node(node_name + "/Icon")
		var skill: SkillDefinition = SkillDatabase.get_skill(PATH_EMBLEMS[node_name][1])
		icon.texture = load(skill.icon)
		icon.self_modulate = skill.icon_tint()
		icon.custom_minimum_size = UITokens.PATH_EMBLEM_SIZE
	select_section("quests")


## Вкладка розділу: мишею, Enter / A на вкладці, Q / E або LB / RB звідусіль на екрані.
func select_section(id: String) -> void:
	section = id
	selected_id = ""
	for tab_id: String in _tabs:
		(_tabs[tab_id] as Button).set_pressed_no_signal(tab_id == id)
	_heading.text = SECTIONS[id][0]
	_empty_state.text = SECTIONS[id][2]
	_load()


func _load() -> void:
	match section:
		"quests":
			_load_story()
		"characters":
			set_entries(JournalRecords.people().map(func(p: Dictionary) -> Dictionary:
				return {"id": p.id, "title": p.name, "group": p.title, "description": p.text, "portrait": p.portrait,
					"place": p.place}))
		"bestiary":
			set_entries(JournalRecords.enemies().map(func(e: Dictionary) -> Dictionary:
				return {"id": e.kind, "title": e.name, "description": e.text,
					"group": tr("Defeated: %d") % e.kills if e.kills > 0 else tr("Not yet defeated")}))
		"notes":  # знайдені шматки історії (D622, Q87): назви в порядку знахідок, справа — повний текст
			set_entries(JournalRecords.stories().map(func(s: Dictionary) -> Dictionary:
				return {"id": s.id, "title": s.title, "description": s.text}))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var step := 0
	if event.is_action_pressed(&"menu_prev_tab"):
		step = -1
	elif event.is_action_pressed(&"menu_next_tab"):
		step = 1
	if step == 0:
		return
	var ids: Array = SECTIONS.keys()
	select_section(ids[posmod(ids.find(section) + step, ids.size())])
	get_viewport().set_input_as_handled()


## Поточна ціль — реальний сигнал Game, без опитування щокадру.
func _connect_objective() -> void:
	_game = Game.get_singleton()
	if not _game.objective_updated.is_connected(_on_objective_updated):
		_game.objective_updated.connect(_on_objective_updated)


func _on_objective_updated(_text: String) -> void:
	if is_node_ready():
		_refresh_objective()
		if is_visible_in_tree() and section == "quests":
			_load_story()


## Етапи сюжету з GameFlow → пункти журналу (по одному на підетап).
## Без GameFlow (сцена без гри) — порожній журнал.
func _load_story() -> void:
	var stages: Array = ServiceLocator.get_game_flow().journal_entries()
	var items: Array = []
	var current_id := ""
	for stage in stages:
		for zone in stage.zones:
			# Абзаци склеюються — кожен перекладаємо до склеювання (ключ — абзац, BACKLOG 31).
			var description := "\n\n".join(zone.get("chronicle", []).map(func(c: String) -> String: return tr(c)))
			items.append({"id": zone.id, "title": zone.title, "state": zone.state,
				"group": stage.title, "description": description})
			# Цілі — підпункти під своїм підетапом; справа показують текст підетапу (D125).
			var objectives: Array = zone.get("objectives", [])
			for i in objectives.size():
				items.append({"id": "%s/%d" % [zone.id, i], "title": objectives[i].text,
					"state": objectives[i].state, "group": stage.title, "parent": zone.id})
			if zone.state == "current":
				current_id = zone.id
				_append_live_objective(items, zone, objectives, stage.title)
	# Завдання NPC (quests.json, D293): кожне взяте — пункт із ціллю; здане — з позначкою.
	var TASKS: GDScript = load(TASKS_PATH)
	for task: Dictionary in TASKS.tasks():
		var status: String = TASKS.status(task)
		if status != "":
			items.append({"id": "task/" + task.id, "title": tr(task.title), "group": "Tasks",
				"state": "done" if status == TASKS.DONE else "current",
				"description": "%s\n\n%s" % [tr(task.description), tr("Goal: %s") % tr(task.objective)]})
	# Обраний пункт лишається, поки він доступний; інакше — поточний підетап.
	var keep := false
	for item in items:
		keep = keep or (item.id == selected_id and item.state != "locked")
	if not keep:
		selected_id = current_id
	set_entries(items)


## Поточна ціль з HUD (Game.current_objective, напр. «Return to the village», Q39 → BACKLOG 37) — ще й підпунктом
## поточного підетапу в списку, якщо серед його цілей зі story.json такого тексту немає.
func _append_live_objective(items: Array, zone: Dictionary, objectives: Array, group: String) -> void:
	var text: String = String(_game.current_objective).strip_edges()
	if text.is_empty() or objectives.any(func(o: Dictionary) -> bool: return String(o.text) == text):
		return
	items.append({"id": "%s/%s" % [zone.id, LIVE_OBJECTIVE], "title": text, "state": "current", "group": group,
		"parent": zone.id})


# ── Data API ────────────────────────────────────────────────────────────────

## Єдина точка входу для даних. Продакшн викличе її, коли з'являться реальні
## завдання; тести — із синтетичними фікстурами. .tscn при цьому не змінюється.
func set_entries(new_entries: Array) -> void:
	entries = []
	for raw in new_entries:
		if raw is Dictionary:
			entries.append(_normalize(raw))
	if not _has_entry(selected_id):
		selected_id = String(entries[0].id) if not entries.is_empty() else ""
	if is_node_ready():
		update_display()


func clear_entries() -> void:
	set_entries([])


## Назви, групи й описи — ключі з даних (англійською): перекладаємо тут, бо список склеює їх зі значками
## й переводить у верхній регістр (BACKLOG 31). Уже перекладений чи складений текст tr() не змінює.
func _normalize(raw: Dictionary) -> Dictionary:
	return {
		"id": String(raw.get("id", "")),
		"title": tr(String(raw.get("title", PLACEHOLDER))),
		"state": String(raw.get("state", "")),
		"objectives": Array(raw.get("objectives", [])),
		"description": tr(String(raw.get("description", ""))),
		"group": tr(String(raw.get("group", ""))),
		"parent": String(raw.get("parent", "")),
		"portrait": raw.get("portrait") as Texture2D,
		"place": Dictionary(raw.get("place", {})),
	}


func _has_entry(id: String) -> bool:
	for entry in entries:
		if entry.id == id:
			return true
	return false


func _entry(id: String) -> Dictionary:
	for entry in entries:
		if entry.id == id:
			return entry
	return {}


# ── Display ─────────────────────────────────────────────────────────────────

func update_display() -> void:
	if not is_node_ready():
		return
	_refresh_objective()
	_rebuild_rows()
	var has_entries: bool = not entries.is_empty()
	var as_card := section == "characters"
	_path_emblems.visible = as_card
	if as_card:
		_refresh_emblems()
	_columns.visible = has_entries and not as_card
	_card.visible = has_entries and as_card
	_empty_state.visible = not has_entries
	if not has_entries:
		_detail.visible = false
	elif as_card:
		_about_panel.visible = false
		_show_person(selected_id)
	else:
		_show_detail(selected_id)
	_set_hint()


## Показуємо ціль, тільки якщо вона реально є. Порожній рядок — ховаємо панель,
## а не малюємо прочерк, який виглядав би як дані.
func _refresh_objective() -> void:
	var text: String = ""
	if section == "quests":  # ціль — лише на сторінці завдань
		text = String(_game.current_objective)
	_objective_panel.visible = not text.strip_edges().is_empty()
	_objective_text.text = text


func _rebuild_rows() -> void:
	# ponytail: один заголовок — етап першого пункту; коли з'явиться другий етап,
	# заголовки треба вставляти рядками між групами.
	var group: String = (entries[0].group if not entries.is_empty() else "") if section == "quests" else SECTIONS[section][1]
	_list_header.text = group.to_upper()
	_list_header.visible = not group.is_empty()
	var rows := RowFill.fill(_entry_list, _entry_row, entries.size())
	for i in rows.size():
		var row: Button = rows[i]
		var entry: Dictionary = entries[i]
		row.name = "Entry_%s" % entry.id
		var mark: String = ZONE_MARKS.get(entry.state, "")
		row.text = "%s  %s" % [mark, entry.title] if mark != "" else entry.title
		row.theme_type_variation = &"ListSubRow" if entry.parent != "" else &"ListRow"
		row.disabled = entry.state == "locked"
		row.focus_mode = Control.FOCUS_NONE if row.disabled else Control.FOCUS_ALL
		row.set_meta(&"entry_id", entry.id)
		row.set_pressed_no_signal(entry.id == selected_id)
		# Не через meta: duplicate() копіює meta з шаблону, і копії лишалися б без сигналів.
		if not _wired.has(row):
			_wired[row] = true
			row.pressed.connect(_on_row_pressed.bind(row))
			# Стрілки ↑/↓ по списку одразу показують текст пункту справа.
			row.focus_entered.connect(_on_row_focused.bind(row))
	_link_tab_and_list(rows)


## ↑ з першого рядка — на вкладку цього розділу, ↓ з неї — на перший рядок (а не на найближчу кнопку за геометрією).
## Characters веде вниз на картку (D486).
func _link_tab_and_list(rows: Array) -> void:
	var focusable: Array = rows.filter(func(r: Button) -> bool: return r.focus_mode == Control.FOCUS_ALL)
	for row: Button in rows:
		row.focus_neighbor_top = NodePath()
	for id: String in _tabs:
		if id != "characters":
			(_tabs[id] as Button).focus_neighbor_bottom = NodePath()
	if section == "characters":
		return
	var tab: Button = _tabs[section]
	if focusable.is_empty():
		return
	var first: Button = focusable[0]
	first.focus_neighbor_top = first.get_path_to(tab)
	tab.focus_neighbor_bottom = tab.get_path_to(first)


func _on_row_pressed(row: Button) -> void:
	_open_entry(row)


func _on_row_focused(row: Button) -> void:
	if not row.button_pressed:
		row.set_pressed_no_signal(true)
		_open_entry(row)


func _open_entry(row: Button) -> void:
	selected_id = row.get_meta(&"entry_id")
	for other in _entry_list.get_children():
		if other != row:
			other.set_pressed_no_signal(false)
	_show_detail(selected_id)
	_set_hint()


func _show_detail(id: String) -> void:
	var entry: Dictionary = _entry(id)
	# Ціль показує текст свого підетапу — справа нічого не змінюється.
	if entry.get("parent", "") != "":
		entry = _entry(entry.parent)
	if entry.is_empty():
		_detail.visible = false
		return
	_detail.visible = true
	_portrait.texture = entry.portrait
	_portrait_frame.visible = entry.portrait != null
	_detail_title.text = entry.title
	# Над назвою пункту — етап («PROLOGUE»); у записів без етапу — їхній стан.
	_detail_state.text = (entry.group if entry.group != "" else entry.state).to_upper()
	_detail_state.visible = not _detail_state.text.is_empty()
	_detail_description.text = entry.description
	_detail_description.visible = not entry.description.is_empty()

	var objectives: Array = entry.objectives
	_objectives_caption.visible = not objectives.is_empty()
	var lines := RowFill.fill(_objective_list, _objective_line, objectives.size())
	for i in lines.size():
		lines[i].text = "◇  %s" % String(objectives[i])


# ── Characters: картка персонажа (D486) ───────────────────────────────────────

## Яскравість гербів — частка кожного нахилу від найсильнішого (OathLeanings.shares); чисел гравець не бачить.
func _refresh_emblems() -> void:
	var shares: Dictionary = ServiceLocator.get_skill_manager().leanings.shares()
	for node_name: String in PATH_EMBLEMS:
		var bright := lerpf(UITokens.PATH_EMBLEM_DIM, 1.0, shares[PATH_EMBLEMS[node_name][0]])
		(_path_emblems.get_node(node_name) as Control).modulate = Color(bright, bright, bright, bright)


## Яскравість герба шляху [param path] (0..1) — для тестів і знімків.
func emblem_brightness(path: String) -> float:
	for node_name: String in PATH_EMBLEMS:
		if PATH_EMBLEMS[node_name][0] == path:
			return (_path_emblems.get_node(node_name) as Control).modulate.a
	assert(false, "JournalComponent: no emblem for %s" % path)
	return 0.0


func _show_person(id: String) -> void:
	var entry: Dictionary = _entry(id)
	_pager.text = "%d / %d" % [entries.find(entry) + 1, entries.size()]
	_illustration.texture = entry.portrait
	_epithet.text = entry.group
	_card_name.text = entry.title
	_about_text.text = entry.description
	_place.text = tr(String(entry.place.title))
	_place_parchment()


## Пергамент більший за свою половину (CARD_MAP_ZOOM): точка зустрічі якомога ближче до центру, краї не видно;
## світло — коло навколо неї.
func _place_parchment() -> void:
	var entry: Dictionary = _entry(selected_id)
	if entry.is_empty() or section != "characters":
		return
	var view := _map_view.size
	var tex := _parchment.texture.get_size()
	var map_size := tex * maxf(view.x / tex.x, view.y / tex.y) * UITokens.CARD_MAP_ZOOM
	var point: Vector2 = entry.place.map * map_size
	var pos := (view / 2.0 - point).clamp(view - map_size, Vector2.ZERO)
	_parchment.position = pos
	_parchment.size = map_size
	var light := _light.material as ShaderMaterial
	light.set_shader_parameter(&"center", (pos + point) / view)
	light.set_shader_parameter(&"aspect", view.x / view.y)


## ←/→ — попередня / наступна людина (по колу); кнопки ‹ › — те саме мишею.
func show_next_person(step: int) -> void:
	if entries.is_empty():
		return
	selected_id = entries[posmod(entries.find(_entry(selected_id)) + step, entries.size())].id
	_about_panel.visible = false
	_show_person(selected_id)
	_set_hint()


## A / Enter або клік — опис людини поверх пергаменту й назад.
func toggle_description() -> void:
	_about_panel.visible = not _about_panel.visible


func _on_card_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		show_next_person(-1)
	elif event.is_action_pressed(&"ui_right"):
		show_next_person(1)
	elif event.is_action_pressed(&"ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		toggle_description()
	else:
		return
	_card.accept_event()


## Меню ставить свою типову підказку вже після перемикання вкладки,
## тож нашу виставляємо відкладено, інакше її перетирають.
func _set_hint() -> void:
	_apply_hint.call_deferred()


func _apply_hint() -> void:
	# Нижня панель спільна: прихована вкладка не має права її перезаписувати.
	if not is_visible_in_tree():
		return
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	# Підказка описує лише те, що екран реально вміє.
	if entries.is_empty():
		bar.set_context_hint("Journal entries appear here as you progress.")
	elif section == "characters":
		bar.set_context_hint("Left / Right: another person. Confirm: read about them.")
	else:
		var entry: Dictionary = _entry(selected_id)
		bar.set_context_hint(String(entry.get("title", "Select an entry to read it.")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and is_visible_in_tree():
		_load()
