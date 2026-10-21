extends Control

## Список тем туторіалу — центральна частина Game Menu (Figma menu-tutorial 130:1172,
## D126). Відкривається з Misc → Tutorial. Обрана тема відкривається на весь
## екран у вікні tutorial_menu.tscn (Figma 135:1260); Esc закриває його назад сюди.
## Теми — TutorialTopics: загальні + підказки, які гравець уже бачив (D289). Рядки — шаблон %TopicRow зі сцени (D117).

## Рядки з шаблону сцени (D117). preload, а не class_name: редактор бачить
## новий class_name лише після перескану, і скрипт до того не парсився.
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const TopicWindow = preload("res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn")

@onready var _list: VBoxContainer = %TopicList
@onready var _row: Button = %TopicRow

var topics: Array = []
var _wired: Dictionary = {}  # рядки, вже під'єднані до сигналу (duplicate() копіює meta)


## Список перебудовується щоразу, як його показали: тема нової підказки вже в ньому.
func _fill() -> void:
	topics = TutorialTopics.available()
	var rows := RowFill.fill(_list, _row, topics.size())
	for i in rows.size():
		var row: Button = rows[i]
		row.text = topics[i].get("title", "")
		if not _wired.has(row):
			_wired[row] = true
			row.pressed.connect(open_topic.bind(i))


## Тема на весь екран поверх меню.
func open_topic(i: int) -> void:
	var layer = ServiceLocator.get_ui_manager().get_modal_layer()
	layer.show_custom_modal(TopicWindow)
	layer.active_modal.show_topic(i)


func _notification(what: int) -> void:
	# Показали список — фокус на першу тему, щоб стрілки й Enter працювали одразу.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and is_visible_in_tree():
		_fill()
		(_list.get_child(0) as Button).grab_focus.call_deferred()
		var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
		bar.set_context_hint("Select a tutorial topic.")  # Figma 130:1172
