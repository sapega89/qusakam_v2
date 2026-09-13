extends Node2D
class_name GateController

## 🚪 GateController - Управління брамами на основі квестів
## Прив'язується до TileMapLayer з брамою та відчиняє/зачиняє її на основі стану сцени або квестів

@export_group("Gate Settings")
@export var gate_layer_name: String = "Gate"
@export var required_quest_id: String = ""
@export var quest_completion_flag: String = "" # Якщо порожньо, використовується required_quest_id
@export var open_by_default: bool = false

var gate_layer: TileMapLayer = null
var is_open: bool = false
var _is_initialized: bool = false
var _pending_open_state: Variant = null # null = немає відкладеної команди

func _ready() -> void:
	"""Ініціалізація контролера брами"""
	# Чекаємо кілька кадрів, щоб переконатися, що TileMap повністю завантажено
	await get_tree().process_frame
	await get_tree().process_frame
	
	_is_initialized = true
	
	# Знаходимо TileMapLayer
	var target_tilemap = _find_tilemap()
	if not target_tilemap:
		DebugLogger.warning("GateController: ❌ TileMap не знайдено для брами '%s'!" % gate_layer_name, "GateController")
		return
	
	gate_layer = _find_gate_layer(target_tilemap)
	if not gate_layer:
		DebugLogger.warning("GateController: ❌ TileMapLayer '%s' не знайдено в TileMap!" % gate_layer_name, "GateController")
		return
	
	DebugLogger.info("GateController: ✅ Знайдено TileMapLayer '%s' для брами" % gate_layer_name, "GateController")
	
	# Встановлюємо початковий стан
	if _pending_open_state != null:
		is_open = _pending_open_state
		_pending_open_state = null
	else:
		is_open = open_by_default
		# НЕ перевіряємо квести автоматично - ворота керуються тільки через явні виклики open_gate()/close_gate()
		# _check_quest_status() викликається тільки для встановлення open_by_default при створенні контролера
	
	# Оновлюємо візуальний стан
	_update_gate_visibility()
	
	# НЕ підключаємося до подій змінення квестів для автоматичного управління
	# Ворота керуються тільки через явні виклики з Scene Manager
	# _connect_quest_events()  # Закоментовано - ворота не реагують автоматично на зміни quest flags

func _find_tilemap() -> Node2D:
	"""Шукає TileMap у сцені"""
	# 1. Спробуємо знайти в батьківському вузлі (найбільш ймовірно)
	var parent = get_parent()
	while parent:
		var tm = parent.get_node_or_null("TileMap")
		if tm: 
			DebugLogger.info("GateController: ✅ TileMap знайдено в батьківському вузлі: %s" % parent.name, "GateController")
			return tm
		parent = parent.get_parent()
	
	# 2. Спробуємо через current_scene
	var scene = get_tree().current_scene
	if scene:
		var tm = scene.get_node_or_null("TileMap")
		if tm: 
			DebugLogger.info("GateController: ✅ TileMap знайдено в current_scene", "GateController")
			return tm
		var found = scene.find_child("TileMap", true, false)
		if found:
			DebugLogger.info("GateController: ✅ TileMap знайдено через find_child", "GateController")
			return found
	
	DebugLogger.warning("GateController: ❌ TileMap не знайдено в сцені!", "GateController")
	return null

func _find_gate_layer(tilemap: Node2D) -> TileMapLayer:
	"""Шукає шар з назвою gate_layer_name"""
	# Перевіряємо всі дочірні вузли TileMap
	for child in tilemap.get_children():
		if child is TileMapLayer:
			var child_name_lower = child.name.to_lower()
			var target_name_lower = gate_layer_name.to_lower()
			if child_name_lower == target_name_lower:
				DebugLogger.info("GateController: ✅ Знайдено TileMapLayer '%s' (шукали '%s')" % [child.name, gate_layer_name], "GateController")
				return child
	
	# Якщо не знайшли, виводимо список доступних шарів для діагностики
	var available_layers = []
	for child in tilemap.get_children():
		if child is TileMapLayer:
			available_layers.append(child.name)
	
	DebugLogger.warning("GateController: ❌ TileMapLayer '%s' не знайдено! Доступні шари: %s" % [
		gate_layer_name, str(available_layers)
	], "GateController")
	
	return null

# Закоментовано - ворота не реагують автоматично на зміни quest flags
# func _connect_quest_events() -> void:
# 	"""Підписується на події квестів"""
# 	var game = Game.get_singleton()
# 	if game:
# 		if not game.quest_flag_changed.is_connected(_on_quest_flag_changed):
# 			game.quest_flag_changed.connect(_on_quest_flag_changed)

func _check_quest_status() -> void:
	"""Перевіряє квестовий флаг тільки для встановлення open_by_default при створенні контролера.
	НЕ використовується для автоматичного управління воротами після ініціалізації."""
	if required_quest_id.is_empty(): 
		return
	
	var quest_flag = quest_completion_flag if not quest_completion_flag.is_empty() else required_quest_id
	var game = Game.get_singleton()
	if game and game.has_method("get_quest_flag"):
		var quest_completed = game.get_quest_flag(quest_flag, false)
		
		# Додаткова перевірка: якщо гравець повернувся з Village, всі ворота відкриті
		var village_left_complete = game.get_quest_flag("village_left_complete", false)
		if village_left_complete:
			quest_completed = true
		
		# Встановлюємо open_by_default на основі quest flag, але НЕ відкриваємо ворота автоматично
		# Ворота будуть відкриті/закриті на основі open_by_default при ініціалізації
		# але після ініціалізації керуються тільки через явні виклики open_gate()/close_gate()
		if quest_completed:
			open_by_default = true
		else:
			open_by_default = false

# Закоментовано - ворота не реагують автоматично на зміни quest flags
# func _on_quest_flag_changed(quest_id: String, _value: Variant) -> void:
# 	if quest_id == required_quest_id or quest_id == quest_completion_flag:
# 		_check_quest_status()

func open_gate() -> void:
	"""Відчиняє браму"""
	if not _is_initialized:
		_pending_open_state = true
		return
	
	is_open = true
	_update_gate_visibility()
	DebugLogger.info("GateController: Брама '%s' ВІДЧИНЕНА" % gate_layer_name, "GateController")

func close_gate() -> void:
	"""Зачиняє браму"""
	if not _is_initialized:
		_pending_open_state = false
		return
	
	is_open = false
	_update_gate_visibility()
	DebugLogger.info("GateController: Брама '%s' ЗАЧИНЕНА" % gate_layer_name, "GateController")

func _update_gate_visibility() -> void:
	"""Оновлює стан шару в TileMap"""
	if not gate_layer:
		DebugLogger.warning("GateController: Не можу оновити видимість - gate_layer не знайдено для '%s'" % gate_layer_name, "GateController")
		return
	
	# Зачинені ворота видно, і вони блокують прохід; відчинені — зникають.
	# Раніше логіка була перевернута: закриті ворота ставали невидимими, але
	# лишали колізію (гравець упирався в порожнечу), а відкриті лишались
	# намальованими, хоч крізь них можна було пройти наскрізь.
	if is_open:
		gate_layer.enabled = false  # прохід вільний
		gate_layer.visible = false  # ворота зникли
	else:
		gate_layer.enabled = true   # блокують прохід
		gate_layer.visible = true   # і їх видно, щоб блокування було зрозумілим
		gate_layer.modulate = Color.WHITE
	
	DebugLogger.info("GateController: Шар '%s' оновлено (is_open=%s, enabled=%s, visible=%s)" % [
		gate_layer_name, is_open, gate_layer.enabled, gate_layer.visible
	], "GateController")
