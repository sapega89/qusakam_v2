extends BaseMenuComponent

## 📔 JournalComponent — журнал завдань.
## Figma: journal-main-story (192:1529) — з нього взято лише візуальну мову
## (титульний блок, дві колонки, нижня панель). Контент кадру — персонажний
## кодекс із вигаданими іменами — визнано застарілим (рішення D52).
##
## Це ОБОЛОНКА, керована даними. У сцені немає жодного рядка завдання.
## Продакшн-даних завдань у проєкті поки немає: Scripts/Quest існує, але
## жодного .tres не створено і жодна сцена не інстанціює SceneQuestManager
## (див. design/journal_audit.md). Тому чесний стан за замовчуванням — порожній.
##
## Єдине живе джерело — Game.current_objective: показуємо як поточну ціль,
## але НЕ видаємо її за повноцінний запис журналу.
##
## set_entries() існує для майбутніх реальних даних і для тестових фікстур.
## Фікстури — ТІЛЬКИ для візуального QA, у геймплеї вони не завантажуються.

const EMPTY_TEXT := "No journal entries yet."
const PLACEHOLDER := "—"

## Мінімальний контракт запису. Реальні дані згодом мапимо сюди,
## не перебудовуючи сцену.
const FIELDS := ["id", "title", "state", "objectives", "description"]

@onready var _eyebrow: Label = %Eyebrow
@onready var _heading: Label = %Heading
@onready var _objective_panel: PanelContainer = %Objective
@onready var _objective_text: Label = %ObjectiveText
@onready var _columns: HBoxContainer = %Columns
@onready var _entry_list: VBoxContainer = %EntryList
@onready var _detail: VBoxContainer = %Detail
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_state: Label = %DetailState
@onready var _detail_description: Label = %DetailDescription
@onready var _objectives_caption: Label = %ObjectivesCaption
@onready var _objective_list: VBoxContainer = %ObjectiveList
@onready var _empty_state: Label = %EmptyState

var entries: Array = []
var selected_id: String = ""

var _rows: Dictionary = {}
var _row_group := ButtonGroup.new()
var _game: Node = null


func _initialize_component() -> void:
	add_to_group(&"journal_screen")
	_empty_state.text = EMPTY_TEXT
	_connect_objective()
	update_display()


## Поточна ціль — реальний сигнал Game, без опитування щокадру.
func _connect_objective() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_game = tree.root.get_node_or_null(^"Game")
	if _game == null and tree.current_scene \
			and tree.current_scene.has_signal(&"objective_updated"):
		_game = tree.current_scene
	if _game and _game.has_signal(&"objective_updated") \
			and not _game.objective_updated.is_connected(_on_objective_updated):
		_game.objective_updated.connect(_on_objective_updated)


func _on_objective_updated(_text: String) -> void:
	if is_node_ready():
		_refresh_objective()


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


func _normalize(raw: Dictionary) -> Dictionary:
	return {
		"id": String(raw.get("id", "")),
		"title": String(raw.get("title", PLACEHOLDER)),
		"state": String(raw.get("state", "")),
		"objectives": Array(raw.get("objectives", [])),
		"description": String(raw.get("description", "")),
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
	_columns.visible = has_entries
	_empty_state.visible = not has_entries
	if has_entries:
		_show_detail(selected_id)
	else:
		_detail.visible = false
	_set_hint()


## Показуємо ціль, тільки якщо вона реально є. Порожній рядок — ховаємо панель,
## а не малюємо прочерк, який виглядав би як дані.
func _refresh_objective() -> void:
	var text: String = ""
	if _game and "current_objective" in _game:
		text = String(_game.current_objective)
	_objective_panel.visible = not text.strip_edges().is_empty()
	_objective_text.text = text


func _rebuild_rows() -> void:
	for child in _entry_list.get_children():
		_entry_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	for entry in entries:
		var row := Button.new()
		row.name = "Entry_%s" % entry.id
		row.text = entry.title
		row.theme_type_variation = &"ListRow"
		row.toggle_mode = true
		row.button_group = _row_group
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_ALL
		row.set_pressed_no_signal(entry.id == selected_id)
		row.pressed.connect(_on_row_pressed.bind(String(entry.id)))
		_entry_list.add_child(row)
		_rows[entry.id] = row


func _on_row_pressed(id: String) -> void:
	selected_id = id
	_show_detail(id)
	_set_hint()


func _show_detail(id: String) -> void:
	var entry: Dictionary = _entry(id)
	if entry.is_empty():
		_detail.visible = false
		return
	_detail.visible = true
	_detail_title.text = entry.title
	_detail_state.text = entry.state.to_upper()
	_detail_state.visible = not entry.state.is_empty()
	_detail_description.text = entry.description
	_detail_description.visible = not entry.description.is_empty()

	for child in _objective_list.get_children():
		_objective_list.remove_child(child)
		child.queue_free()
	var objectives: Array = entry.objectives
	_objectives_caption.visible = not objectives.is_empty()
	for item in objectives:
		var line := Label.new()
		line.text = "◇  %s" % String(item)
		line.theme_type_variation = &"CardBody"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_objective_list.add_child(line)


## Меню ставить свою типову підказку вже після перемикання вкладки,
## тож нашу виставляємо відкладено, інакше її перетирають.
func _set_hint() -> void:
	_apply_hint.call_deferred()


func _apply_hint() -> void:
	var tree := get_tree()
	var bar: Node = tree.get_first_node_in_group(&"ui_bottom_bar") if tree else null
	if bar == null or not bar.has_method("set_context_hint"):
		return
	# Підказка описує лише те, що екран реально вміє.
	if entries.is_empty():
		bar.set_context_hint("Journal entries appear here as you progress.")
	else:
		var entry: Dictionary = _entry(selected_id)
		bar.set_context_hint(String(entry.get("title", "Select an entry to read it.")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and is_visible_in_tree():
		update_display()
