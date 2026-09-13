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
	
	# Показуємо екран з анімацією
	visible = true
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
	
	# Перехід до головного меню
	return_to_menu.emit()
	_transition_to_main_menu()

func _transition_to_main_menu() -> void:
	"""Перехід до головного меню"""
	# Отримуємо шлях до головного меню
	var main_menu_path = "res://SampleProject/MainMenu.tscn"
	
	# Переходимо до головного меню
	get_tree().change_scene_to_file(main_menu_path)
	
	DebugLogger.info("🎬 DemoEndScreen: Перехід до головного меню виконано", "DemoEndScreen")

func _set_player_input_enabled(enabled: bool) -> void:
	"""Блокує/розблоковує ввід гравця"""
	var player = GameGroups.get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(enabled)
