extends CanvasLayer
class_name ModalLayer

signal modal_closed(result: String)

@export var modal_scene: PackedScene

var active_modal: Control = null

@onready var blocker: Control = $Blocker
@onready var container: Control = $Container

func _ready() -> void:
	visible = false
	if blocker:
		blocker.visible = false
		blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if container:
		container.visible = false

func show_modal(data: Dictionary) -> void:
	_clear_modal()

	if not modal_scene:
		push_error("ModalLayer: modal_scene not assigned")
		return

	active_modal = modal_scene.instantiate() as Control
	if not active_modal:
		push_error("ModalLayer: Failed to instantiate modal dialog")
		return

	container.add_child(active_modal)
	active_modal.setup(data)

	_connect_modal(active_modal)

	visible = true
	blocker.visible = true
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	container.visible = true

func show_custom_modal(packed_scene: PackedScene) -> void:
	_clear_modal()
	if not packed_scene:
		push_error("ModalLayer: modal scene not assigned")
		return
	active_modal = packed_scene.instantiate() as Control
	if not active_modal:
		push_error("ModalLayer: Failed to instantiate modal scene")
		return
	container.add_child(active_modal)

	# Те саме підключення, що й у show_modal: інакше кастомна модалка не могла
	# закрити себе і лишалась зареєстрованою як active_modal назавжди.
	_connect_modal(active_modal)

	# visible = true бракувало: шар лишався прихованим, тож кастомна модалка
	# існувала в дереві, але нічого не малювала.
	visible = true
	blocker.visible = true
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	container.visible = true

## Кнопка модалки випромінює і chosen, і confirmed/cancelled. Раніше шар закривався
## двічі й двічі слав modal_closed — друге закриття знищувало модалку, відкриту з
## обробника першого (напр. "Overwrite Save?" → "Game Saved"). Тепер кожен сигнал
## прив'язаний до своєї модалки, а сигнали вже закритої ігноруються.
func _connect_modal(modal: Control) -> void:
	if modal.has_signal("confirmed"):
		modal.confirmed.connect(_on_confirmed.bind(modal))
	if modal.has_signal("cancelled"):
		modal.cancelled.connect(_on_cancelled.bind(modal))
	if modal.has_signal("chosen"):
		modal.chosen.connect(_on_chosen.bind(modal))

func _on_confirmed(modal: Control) -> void:
	_close_with_result("confirm", modal)

func _on_cancelled(modal: Control) -> void:
	_close_with_result("cancel", modal)

func _on_chosen(result: String, modal: Control) -> void:
	_close_with_result(result, modal)

func _close_with_result(result: String, modal: Control = null) -> void:
	if modal != null and modal != active_modal:
		return
	_clear_modal()
	modal_closed.emit(result)

func _clear_modal() -> void:
	if active_modal and is_instance_valid(active_modal):
		active_modal.queue_free()
	active_modal = null
	if blocker:
		blocker.visible = false
		blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if container:
		container.visible = false
	visible = false
