extends Control
class_name YesNoDialog

## Универсальное окно подтверждения в стиле стандартного UI
## Показывает текст и две кнопки: Да / Нет

signal confirmed
signal canceled

@export var title: String = "Подтверждение"
@export_multiline var message: String = "Вы уверены?"
@export var yes_text: String = "Да"
@export var no_text: String = "Нет"

@onready var _title_label: Label = %Title
@onready var _message_label: Label = %Message
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton


func _ready() -> void:
	# Применяем тексты
	if _title_label:
		_title_label.text = title
	if _message_label:
		_message_label.text = message
	if _yes_button:
		_yes_button.text = yes_text
	if _no_button:
		_no_button.text = no_text
	
	# Подключаем сигналы кнопок
	if _yes_button and not _yes_button.pressed.is_connected(_on_yes_pressed):
		_yes_button.pressed.connect(_on_yes_pressed)
	if _no_button and not _no_button.pressed.is_connected(_on_no_pressed):
		_no_button.pressed.connect(_on_no_pressed)
	
	# Фокус на кнопке подтверждения
	if _yes_button:
		_yes_button.grab_focus()


func _on_yes_pressed() -> void:
	confirmed.emit()
	queue_free()


func _on_no_pressed() -> void:
	canceled.emit()
	queue_free()


## Вспомогательный метод для быстрого показа окна из кода
static func show_yes_no(
	parent: Node,
	title_text: String,
	message_text: String,
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> YesNoDialog:
	var scene: PackedScene = load("res://SampleProject/Scenes/UI/yes_no_dialog.tscn")
	var dialog: YesNoDialog = scene.instantiate() as YesNoDialog
	dialog.title = title_text
	dialog.message = message_text
	
	if on_confirm.is_valid():
		dialog.confirmed.connect(on_confirm, CONNECT_ONE_SHOT)
	if on_cancel.is_valid():
		dialog.canceled.connect(on_cancel, CONNECT_ONE_SHOT)
	
	if parent:
		parent.add_child(dialog)
	
	return dialog


