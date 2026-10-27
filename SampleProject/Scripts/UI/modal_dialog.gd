extends Control

signal confirmed
signal cancelled
signal chosen(result: String)

@onready var icon_rect: TextureRect = $Panel/VBox/Icon
@onready var title_label: Label = $Panel/VBox/Title
@onready var rule: HSeparator = $Panel/VBox/Rule
@onready var description_label: Label = $Panel/VBox/Description
@onready var buttons_container: VBoxContainer = $Panel/VBox/Buttons
@onready var confirm_button: Button = $Panel/VBox/Buttons/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Buttons/CancelButton

var _custom_buttons: Array[Button] = []
## Власна кнопка скасування (is_cancel) — її натискає B / Esc.
var _custom_cancel: Button = null
## Кнопка за замовчуванням: поки модалка відкрита, фокус без власника повертається до неї — після відповіді в розмові
## (D727) відкладене grab_focus губилось, і подарунок діда не закривався з клавіатури.
var _default_button: Button = null

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
		confirm_button.text = _label(str(data.get("confirm_text", "OK")))
	if cancel_button:
		cancel_button.text = _label(str(data.get("cancel_text", "Cancel")))
		cancel_button.visible = bool(data.get("allow_cancel", true))

func _ready() -> void:
	# Figma UI/Modal/Confirm (B119): лінія 300 px під заголовком, кнопки — колонка 300 px.
	rule.custom_minimum_size.x = UITokens.MODAL_RULE_WIDTH
	buttons_container.custom_minimum_size.x = UITokens.MODAL_BUTTON_COLUMN
	_style_button(confirm_button)
	_style_button(cancel_button)
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
		button.text = _label(text)
		button.icon = confirm_button.icon
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_style_button(button)
		buttons_container.add_child(button)
		button.pressed.connect(_on_button_pressed.bind(id, is_cancel))
		_custom_buttons.append(button)
		if is_cancel:
			_custom_cancel = button
		if is_default:
			button.call_deferred("grab_focus")
			_default_button = button

	if confirm_button:
		confirm_button.visible = false
	if cancel_button:
		cancel_button.visible = false

## UI/HexButton (B119): 260×36; вибрана (фокус, наведення) — ModalButtonOn: заливка, шеврон, темний текст.
func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(UITokens.MODAL_BUTTON_WIDTH, UITokens.MODAL_BUTTON_HEIGHT)
	button.theme_type_variation = &"ModalButtonOn" if button.has_focus() else &"ModalButton"
	button.focus_entered.connect(func() -> void: button.theme_type_variation = &"ModalButtonOn")
	button.focus_exited.connect(func() -> void: button.theme_type_variation = &"ModalButton")
	button.mouse_entered.connect(button.grab_focus)


## Figma: підписи кнопок великими літерами. Перекладаємо тут, бо авто-переклад не знайде "YES".
func _label(key: String) -> String:
	return tr(key).to_upper()


func _clear_custom_buttons() -> void:
	if not buttons_container:
		return
	for child in buttons_container.get_children():
		if child == confirm_button or child == cancel_button:
			continue
		child.queue_free()
	_custom_buttons.clear()
	_custom_cancel = null

## B / Esc (ui_cancel, D156) — як кнопка скасування модалки. Немає її — B нічого не робить, але й не
## провалюється до меню під модалкою.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _custom_cancel != null:
		_custom_cancel.pressed.emit()
	elif cancel_button.visible:
		_on_cancelled()


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


func _process(_delta: float) -> void:
	if _default_button != null and _default_button.is_visible_in_tree() and get_viewport().gui_get_focus_owner() == null:
		_default_button.grab_focus()
