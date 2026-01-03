# ВАЖНО: Этот скрипт требует аддон godot_tree_table для класса Table
# Если аддон не установлен, создайте заглушку или используйте альтернативу
# 
# Для работы требуется:
# - addons/godot_tree_table/Table.gd
#
# ВАРИАНТ 1: Установите аддон godot_tree_table
# ВАРИАНТ 2: Создайте упрощенную версию без Table (требует переработки shop_ui.gd)

@tool
# extends Table  # Раскомментируйте когда установите аддон
extends PanelContainer  # Временная заглушка
class_name ItemListDisplay

# Сигналы высокого уровня для магазина
signal row_clicked(index: int)
signal row_double_clicked(index: int)

# Временные переменные для заглушки (удалите когда установите аддон)
var tableContainer: Node = null

func _ready() -> void:
	# super._ready()  # Раскомментируйте когда установите аддон
	print("🧱 ItemListDisplay: _ready, tableContainer=", tableContainer)
	
	# Таблица сама настраивает свой режим выбора и фокус
	# table_select_mode = Table.select_mode.ROW  # Раскомментируйте когда установите аддон
	# table_allow_reselect = true  # Раскомментируйте когда установите аддон
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Подключаемся напрямую к внутреннему Tree через tableContainer
	if tableContainer and tableContainer.has("tree"):
		var tree = tableContainer.tree
		if not tree.item_selected.is_connected(_on_tree_item_selected):
			tree.item_selected.connect(_on_tree_item_selected)
		if not tree.item_activated.is_connected(_on_tree_item_activated):
			tree.item_activated.connect(_on_tree_item_activated)

func _get_row_index_from_tree() -> int:
	if not tableContainer or not tableContainer.has("tree"):
		return -1
	var tree = tableContainer.tree
	var root = tree.get_root()
	if not root:
		return -1
	var selected = tree.get_selected()
	if not selected:
		return -1
	return root.get_children().find(selected)

func _on_tree_item_selected() -> void:
	var row_index = _get_row_index_from_tree()
	if row_index < 0:
		return
	print("🧱 Table(tree): row_clicked index=", row_index)
	row_clicked.emit(row_index)

func _on_tree_item_activated() -> void:
	var row_index = _get_row_index_from_tree()
	if row_index < 0:
		return
	print("🧱 Table(tree): row_double_clicked index=", row_index)
	row_double_clicked.emit(row_index)

# Временные методы для заглушки (удалите когда установите аддон)
func set_table(data: Array) -> void:
	push_warning("ItemListDisplay: set_table() требует аддон godot_tree_table. Установите аддон или создайте альтернативную реализацию.")

