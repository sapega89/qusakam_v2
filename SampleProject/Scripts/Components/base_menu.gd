extends Control
class_name BaseMenu

## Базовий клас для всіх меню (SOLID: Open/Closed Principle)
## Надає базову функціональність для наслідування

## Сигнали
signal menu_opened()
signal menu_closed()

## Віртуальні методи для перевизначення в дочірніх класах
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_initialize_menu()

## Ініціалізація меню (перевизначається в дочірніх класах)
func _initialize_menu() -> void:
	pass

## Відкриття меню (перевизначається в дочірніх класах)
func open_menu() -> void:
	visible = true
	menu_opened.emit()

## Закриття меню (перевизначається в дочірніх класах)
func close_menu() -> void:
	visible = false
	menu_closed.emit()

## Обробка вводу (перевизначається в дочірніх класах)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

## Методи для налаштування UI (для використання сцени як бази)
## Встановлює текст заголовка меню
func set_menu_title(title: String) -> void:
	var title_label = get_node_or_null("Menu name")
	if title_label:
		title_label.text = title

## Встановлює текст опису (футер)
func set_menu_description(description: String) -> void:
	var desc_label = get_node_or_null("description")
	if desc_label:
		desc_label.text = description

## Отримує контейнер для лівого меню (для додавання кнопок/елементів)
func get_left_panel() -> VBoxContainer:
	return get_node_or_null("HBoxContainer/CentralPanel/Panel/ContentContainer/VBoxContainer") as VBoxContainer

## Отримує контейнер для центрального контенту (для додавання основного контенту)
func get_content_container() -> Control:
	return get_node_or_null("HBoxContainer/CentralPanel/Panel/ContentContainer") as Control

## Отримує праву панель (для налаштування HUD/статистики)
func get_right_panel() -> PanelContainer:
	return get_node_or_null("HBoxContainer/RightPanel") as PanelContainer

## Отримує контейнер для статистики персонажа
func get_character_stats() -> VBoxContainer:
	return get_node_or_null("HBoxContainer/RightPanel/VBoxContainer/CharacterStats") as VBoxContainer

## Отримує AnimatedSprite2D персонажа
func get_character_sprite() -> AnimatedSprite2D:
	return get_node_or_null("HBoxContainer/RightPanel/VBoxContainer/CharacterSprite") as AnimatedSprite2D

## Оновлює відображення кількості золота в правому HUD
func update_gold(value: int) -> void:
	var gold_label: Label = get_node_or_null("HBoxContainer/RightPanel/VBoxContainer/TopHUD/GoldDisplay/GoldValue")
	if gold_label:
		gold_label.text = str(value)

## Оновлює золото, отримуючи його з GameManager (через ServiceLocator)
func update_gold_display() -> void:
	var game_manager = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_game_manager"):
			game_manager = service_locator.get_game_manager()
	if game_manager and game_manager.has_method("get_player_gold"):
		update_gold(game_manager.get_player_gold())

