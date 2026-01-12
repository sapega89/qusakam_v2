extends Control

signal settings_selected
signal tutorial_selected
signal exit_main_menu_selected
signal exit_game_selected

@onready var settings_button: Button = $Panel/VBox/Buttons/SettingsButton
@onready var tutorial_button: Button = $Panel/VBox/Buttons/TutorialButton
@onready var exit_main_menu_button: Button = $Panel/VBox/Buttons/ExitMainMenuButton
@onready var exit_game_button: Button = $Panel/VBox/Buttons/ExitGameButton

func _ready() -> void:
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if tutorial_button and not tutorial_button.pressed.is_connected(_on_tutorial_pressed):
		tutorial_button.pressed.connect(_on_tutorial_pressed)
	if exit_main_menu_button and not exit_main_menu_button.pressed.is_connected(_on_exit_main_menu_pressed):
		exit_main_menu_button.pressed.connect(_on_exit_main_menu_pressed)
	if exit_game_button and not exit_game_button.pressed.is_connected(_on_exit_game_pressed):
		exit_game_button.pressed.connect(_on_exit_game_pressed)

func _on_settings_pressed() -> void:
	settings_selected.emit()

func _on_tutorial_pressed() -> void:
	tutorial_selected.emit()

func _on_exit_main_menu_pressed() -> void:
	exit_main_menu_selected.emit()

func _on_exit_game_pressed() -> void:
	exit_game_selected.emit()
