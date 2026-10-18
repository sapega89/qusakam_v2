extends ManagerBase
class_name MenuManager

## 📋 MenuManager — вхід у Game Menu з гри (дія game_menu: Esc / Start, D156).
## Стан меню живе в UIManager; тут лише точка входу для Game.gd і game_menu.gd.

signal menu_closed()

func _initialize():
	pass

func toggle_game_menu() -> void:
	ServiceLocator.get_ui_manager().toggle_game_menu()

func close_game_menu() -> void:
	ServiceLocator.get_ui_manager().close_game_menu()
	menu_closed.emit()

func is_menu_open() -> bool:
	return ServiceLocator.get_ui_manager().current_state_name == "GameMenuState"
