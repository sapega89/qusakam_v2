extends Control

## Підменю Miscellaneous. Figma: menu-miscellaneous 58:1246 → misc-sub-menu 84:589.
##
## Це НЕ окрема система модалок: сцена показується через
## ModalLayer.show_custom_modal(), а закривається сигналом cancelled/chosen,
## як і будь-яка інша модалка проєкту.
##
## Поведінка успадкована без змін — чотири сигнали, ті самі призначення.
## Фаза суто візуальна: розкладка й стилі з Figma, навігація не змінена.

signal settings_selected
signal tutorial_selected
signal exit_main_menu_selected
signal exit_game_selected
## ModalLayer слухає саме ці два, щоб прибрати модалку і зняти active_modal.
signal cancelled
signal chosen(result: String)

## Figma: вибраний рядок має префікс «←» і світлішу заливку.
const SELECTED_PREFIX := "←  "

@onready var settings_button: Button = %SettingsButton
@onready var tutorial_button: Button = %TutorialButton
@onready var exit_main_menu_button: Button = %ExitMainMenuButton
@onready var exit_game_button: Button = %ExitGameButton
@onready var _buttons: VBoxContainer = %Buttons

var _labels: Dictionary = {}


func _ready() -> void:
	add_to_group(&"misc_menu_modal")
	for button in _buttons.get_children():
		if button is Button:
			_labels[button] = (button as Button).text
			button.focus_entered.connect(_on_row_focused.bind(button))
			button.mouse_entered.connect(button.grab_focus)
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if tutorial_button and not tutorial_button.pressed.is_connected(_on_tutorial_pressed):
		tutorial_button.pressed.connect(_on_tutorial_pressed)
	if exit_main_menu_button and not exit_main_menu_button.pressed.is_connected(_on_exit_main_menu_pressed):
		exit_main_menu_button.pressed.connect(_on_exit_main_menu_pressed)
	if exit_game_button and not exit_game_button.pressed.is_connected(_on_exit_game_pressed):
		exit_game_button.pressed.connect(_on_exit_game_pressed)
	# Клавіатура й геймпад мають одразу мати на чому стояти.
	settings_button.grab_focus.call_deferred()


## Стрілка й світліший стиль ідуть за фокусом — окремого стану не тримаємо.
func _on_row_focused(focused: Button) -> void:
	for button in _labels:
		if not is_instance_valid(button):
			continue
		var active: bool = button == focused
		button.theme_type_variation = &"MiscRowOn" if active else &"MiscRow"
		button.text = (SELECTED_PREFIX if active else "") + String(_labels[button])


func _gui_input(event: InputEvent) -> void:
	_handle_cancel(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_cancel(event)


## ui_cancel, а не сирий KEY_ESCAPE — щоб працювали ремапінг і кнопка B.
func _handle_cancel(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		get_viewport().set_input_as_handled()
		cancelled.emit()


## Спершу закриваємо себе, потім віддаємо дію. Інакше пункт «Settings» відкривав
## би екран налаштувань ПІД відкритою модалкою, а підтвердження виходу — те саме
## вікно, яке ця модалка потім зносила б.
func _choose(result: String, action: Signal) -> void:
	chosen.emit(result)
	action.emit()


func _on_settings_pressed() -> void:
	_choose("settings", settings_selected)


func _on_tutorial_pressed() -> void:
	_choose("tutorial", tutorial_selected)


func _on_exit_main_menu_pressed() -> void:
	_choose("exit_main_menu", exit_main_menu_selected)


func _on_exit_game_pressed() -> void:
	_choose("exit_game", exit_game_selected)
