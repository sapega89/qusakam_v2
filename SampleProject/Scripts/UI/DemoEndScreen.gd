extends Control
class_name DemoEndScreen

## 🎬 DemoEndScreen - Екран завершення демо-версії
## Показується після завершення проходження

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var return_button: Button = $VBoxContainer/ReturnButton

signal return_to_menu

func _ready() -> void:
	"""Ініціалізація екрану завершення"""
	# Налаштування тексту
	if title_label:
		title_label.text = "Дякуємо за гру!"

	if message_label:
		message_label.text = "Ви завершили демо-версію гри.\n\nСподіваємося, вам сподобалося!"

	# Налаштування кнопки
	if return_button:
		return_button.text = "Повернутися до головного меню"
		return_button.pressed.connect(_on_return_button_pressed)

	# Блокуємо ввід гравця
	_set_player_input_enabled(false)

	# Показуємо екран з анімацією; фокус на кнопку — геймпад A / Enter (BACKLOG 24)
	visible = true
	if return_button:
		return_button.grab_focus.call_deferred()
	modulate.a = 0.0

	# Анімація появи
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

	DebugLogger.info("🎬 DemoEndScreen: Екран завершення показано", "DemoEndScreen")

func _on_return_button_pressed() -> void:
	"""Обробник натискання кнопки повернення"""
	DebugLogger.info("🎬 DemoEndScreen: Повернення до головного меню", "DemoEndScreen")

	# Анімація зникнення
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished

	# Перехід до меню робить той, хто показав екран (LaboratoryOutside). Другий
	# change_scene_to_file тут падав: сцену вже вийнято з дерева, get_tree() == null.
	return_to_menu.emit()

func _set_player_input_enabled(enabled: bool) -> void:
	"""Блокує/розблоковує ввід гравця"""
	GameGroups.get_player().set_movement_enabled(enabled)
