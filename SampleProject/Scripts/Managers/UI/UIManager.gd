extends ManagerBase
class_name UIManager

const UI_ROOT_SCENE = preload("res://SampleProject/Scenes/UI/ui_root.tscn")
const STATE_SCENES = {
	"GameMenuState": "res://SampleProject/Scenes/UI/States/game_menu_state.tscn",
	"SaveGameState": "res://SampleProject/Scenes/UI/States/save_game_state.tscn",
	"NullState": "res://SampleProject/Scenes/UI/States/null_state.tscn"
}

## 🎨 UIManager - Централізований доступ до UI елементів
## Замінює прямі виклики get_tree().get_first_node_in_group()
## Дотримується принципу Single Responsibility

# Кешовані посилання на UI елементи

var ui_root: Node = null
var state_machine: Node = null
var state_root: Control = null
var modal_layer: Node = null
var current_state: Node = null
var current_state_name: String = ""

## Речі, які герою дали (BACKLOG 33) і ще не показані: {item_id: amount} на кожен дарунок, по черзі.
var _obtained_queue: Array[Dictionary] = []

# Сигнали для оновлення UI
signal ui_refresh_requested()

func _initialize():
	_ensure_ui_root()
	"""Ініціалізація UIManager"""
	LocalizationManager.language_changed.connect(_on_language_changed)
	print("🎨 UIManager: Initialized")
	# Очищаємо кеш при зміні сцени
	# Підписуємося на події зміни сцени через EventBus (Godot 4 не має current_scene_changed)
	EventBus.scene_loaded.connect(_on_scene_changed)
	EventBus.scene_transition_completed.connect(_on_scene_changed)
	print("🎨 UIManager: Connected to EventBus signals")
	# НЕ використовуємо tree_changed, щоб уникнути рекурсії при русі

func _on_scene_changed(scene_name: String = ""):
	"""Перебудовує UI root і локалізацію при зміні сцени"""
	print("🎨 UIManager: Scene changed: ", scene_name)
	_ensure_ui_root()
func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла (запобігання витоків пам'яті)"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів EventBus для запобігання витоків пам'яті"""

	# Перевіряємо та відписуємося від сигналів сцен
	if EventBus.scene_loaded.is_connected(_on_scene_changed):
		EventBus.scene_loaded.disconnect(_on_scene_changed)
	if EventBus.scene_transition_completed.is_connected(_on_scene_changed):
		EventBus.scene_transition_completed.disconnect(_on_scene_changed)

	print("🎨 UIManager: Disconnected from all EventBus signals")


# ============================================
# UI ROOT / FSM
# ============================================

func _ensure_ui_root() -> void:
	# UIRoot — завжди нащадок UIManager; створюється один раз.
	if ui_root:
		return

	ui_root = UI_ROOT_SCENE.instantiate()
	ui_root.name = "UIRoot"
	add_child(ui_root)
	print("UIManager: UIRoot created for scene=%s" % (get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null"))
	_initialize_ui_references()

func _initialize_ui_references() -> void:
	state_machine = ui_root.get_state_machine()
	state_root = ui_root.get_state_root()
	modal_layer = ui_root.get_modal_layer()

	if state_machine:
		var state = state_machine.get("state")
		if state:
			current_state = state
			current_state_name = str(state.name)

## UIRoot будується й у головному меню (B54): Load → Delete там теж показує модалку.
func get_state_root() -> Control:
	_ensure_ui_root()
	return state_root

func get_modal_layer() -> Node:
	_ensure_ui_root()
	return modal_layer

func change_state(state_name: String, payload: Dictionary = {}, return_state_name: String = "", return_payload: Dictionary = {}) -> void:
	_ensure_ui_root()
	print("UIManager: change_state requested=%s current_scene=%s ui_root=%s" % [
		state_name,
		get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null",
		ui_root != null
	])
	var scene_path = STATE_SCENES.get(state_name, "")
	if scene_path.is_empty():
		push_error("UIManager: Unknown state: %s" % state_name)
		return
	var packed = load(scene_path)
	if not packed:
		push_error("UIManager: Failed to load state scene: %s" % scene_path)
		return
	var new_state = packed.instantiate()
	if not new_state:
		push_error("UIManager: Failed to instantiate state scene: %s" % scene_path)
		return
	state_machine.add_child(new_state)
	new_state.setup(self, payload, return_state_name, return_payload)
	new_state.finished.connect(_on_state_finished.bind(new_state), CONNECT_ONE_SHOT)
	var previous_state = null
	if state_machine:
		previous_state = state_machine.get("state")
	state_machine._change_state(new_state)
	if previous_state and is_instance_valid(previous_state):
		previous_state.queue_free()
	current_state = new_state
	current_state_name = state_name

func close_state() -> void:
	if current_state_name == "NullState":
		return
	change_state("NullState")

func _on_state_finished(payload: Dictionary, state_node: Node) -> void:
	var target = ""
	var return_payload = {}
	if state_node:
		var value = state_node.get("return_state")
		if value is String:
			target = value
		var payload_value = state_node.get("return_payload")
		if payload_value is Dictionary:
			return_payload = payload_value
	if not target.is_empty():
		# Повертаємось у стан, з якого прийшли, з його початковим payload
		change_state(target, return_payload)
	else:
		close_state()

func open_game_menu() -> void:
	print("UIManager: open_game_menu current_scene=%s" % (get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null"))
	if not can_open_pause_menu():
		return
	change_state("GameMenuState")

func close_game_menu() -> void:
	if current_state_name == "GameMenuState":
		close_state()

func toggle_game_menu() -> void:
	if current_state_name == "GameMenuState":
		close_game_menu()
	else:
		open_game_menu()

func open_save_game() -> void:
	change_state("SaveGameState", {}, current_state_name)

func show_modal(data: Dictionary) -> void:
	_ensure_ui_root()
	modal_layer.show_modal(data)

## Модалка «You obtained:» для речей, які герою ДАЛИ (BACKLOG 33): дарунок діда (D129), нагорода й видача завдання,
## трофеї зали мера. Речі вже в інвентарі; модалка — та сама, що й у підібраних (ItemPickup, D71). Дарунок приходить
## посеред розмови чи кат-сцени, тож модалка чекає, доки гра вільна: ні діалогу, ні кат-сцени (героя тримають),
## ні меню, ні паузи, ні іншої модалки — і йде по одній на дарунок.
func show_obtained(items: Dictionary) -> void:
	assert(not items.is_empty(), "UIManager.show_obtained: nothing given")
	_obtained_queue.append(items)
	if not get_tree().process_frame.is_connected(_flush_obtained):
		get_tree().process_frame.connect(_flush_obtained)


func has_pending_obtained() -> bool:
	return not _obtained_queue.is_empty()


func _flush_obtained() -> void:
	if not _can_show_obtained():
		return
	var items: Dictionary = _obtained_queue.pop_front()
	var database: Node = ServiceLocator.get_item_database()
	var lines: Array[String] = []
	for item_id: String in items:
		lines.append("%s × %d" % [database.get_item_name(item_id), int(items[item_id])])
	show_modal(ModalTemplates.items_obtained(lines))
	if _obtained_queue.is_empty():
		get_tree().process_frame.disconnect(_flush_obtained)


func _can_show_obtained() -> bool:
	var game: Game = Game.get_singleton()
	if game == null or game.player == null or game.player.get(&"event"):  # героя тримає діалог / кат-сцена (Player.event)
		return false
	var dialogue: Node = ServiceLocator.get_dialogue_manager()
	return not get_tree().paused and not is_ui_active() and modal_layer != null and modal_layer.active_modal == null \
			and not dialogue.is_dialogue_active() and not dialogue.is_bubble_playing()


## "" — UI ще не відкривався, "NullState" — вже закрився. Обидва = UI неактивний.
func is_ui_active() -> bool:
	return current_state_name != "" and current_state_name != "NullState"

func is_gameplay_input_allowed() -> bool:
	if is_ui_active():
		return false
	if modal_layer and modal_layer.get("active_modal"):
		return false
	return true

## Під час діалогу меню не відкривається (B16, D136): діалог живе на шарі 100 і не стає на паузу,
## тож меню опинялось під ним, а Enter/клік у меню гортав розмову.
func can_open_pause_menu() -> bool:
	return not ServiceLocator.get_dialogue_manager().is_dialogue_active()

func _on_language_changed(_language: String) -> void:
	ui_refresh_requested.emit()
