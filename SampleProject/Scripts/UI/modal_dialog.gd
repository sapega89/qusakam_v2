extends Control

signal confirmed
signal cancelled
signal chosen(result: String)

@onready var icon_rect: TextureRect = $Panel/VBox/Icon
@onready var title_label: Label = $Panel/VBox/Title
@onready var description_label: Label = $Panel/VBox/Description
@onready var buttons_container: HBoxContainer = $Panel/VBox/Buttons
@onready var confirm_button: Button = $Panel/VBox/Buttons/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Buttons/CancelButton

var _custom_buttons: Array[Button] = []

func setup(data: Dictionary) -> void:
	_apply_icon(data.get("icon", null))

	if title_label:
		title_label.text = str(data.get("title", ""))
	if description_label:
		description_label.text = str(data.get("description", ""))

	var buttons = data.get("buttons", [])
	if buttons is Array and not buttons.is_empty():
		_build_custom_buttons(buttons)
		return
	if confirm_button:
		confirm_button.text = str(data.get("confirm_text", "OK"))
	if cancel_button:
		cancel_button.text = str(data.get("cancel_text", "Cancel"))
		cancel_button.visible = bool(data.get("allow_cancel", true))

func _ready() -> void:
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirmed):
		confirm_button.pressed.connect(_on_confirmed)
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancelled):
		cancel_button.pressed.connect(_on_cancelled)

func _apply_icon(icon_value: Variant) -> void:
	if not icon_rect:
		return
	if icon_value is Texture2D:
		icon_rect.texture = icon_value
		icon_rect.visible = true
	else:
		icon_rect.texture = null
		icon_rect.visible = false

func _build_custom_buttons(buttons: Array) -> void:
	_clear_custom_buttons()
	if not buttons_container:
		return

	for entry in buttons:
		if not (entry is Dictionary):
			continue
		var text = str(entry.get("text", "OK"))
		var id = str(entry.get("id", ""))
		var is_cancel = bool(entry.get("is_cancel", false))
		var is_default = bool(entry.get("is_default", false))

		var button = Button.new()
		button.text = text
		buttons_container.add_child(button)
		button.pressed.connect(_on_button_pressed.bind(id, is_cancel))
		_custom_buttons.append(button)
		if is_default:
			button.call_deferred("grab_focus")

	if confirm_button:
		confirm_button.visible = false
	if cancel_button:
		cancel_button.visible = false

func _clear_custom_buttons() -> void:
	if not buttons_container:
		return
	for child in buttons_container.get_children():
		if child == confirm_button or child == cancel_button:
			continue
		child.queue_free()
	_custom_buttons.clear()

func _on_confirmed() -> void:
	chosen.emit("confirm")
	confirmed.emit()

func _on_cancelled() -> void:
	chosen.emit("cancel")
	cancelled.emit()

func _on_button_pressed(button_id: String, is_cancel: bool) -> void:
	var result = button_id
	if result.is_empty():
		result = "cancel" if is_cancel else "confirm"
	chosen.emit(result)
	if result == "confirm":
		confirmed.emit()
	elif result == "cancel" or is_cancel:
		cancelled.emit()
