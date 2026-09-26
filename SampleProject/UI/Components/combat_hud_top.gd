extends Control
class_name UICombatHudTop

## Верхній ряд бойового HUD: квест + валюта + кнопка меню.
## Figma: Game Scene / Combat HUD → Quest Info Panel (434:6580)
## та Currency & Settings (434:6586).
##
## Нових механік немає — прив'язки ті самі, що у віджетів, які цей ряд замінює:
## ObjectiveHUD (Game.objective_updated) і CoinCounter (EventBus.coins_changed).

@onready var _quest_panel: PanelContainer = %QuestPanel
@onready var _quest_title: Label = %QuestTitle
@onready var _currency_value: Label = %CurrencyValue
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	add_to_group(&"combat_hud_top")
	_menu_button.pressed.connect(_on_menu_pressed)

	if not EventBus.coins_changed.is_connected(_on_coins_changed):
		EventBus.coins_changed.connect(_on_coins_changed)
	_connect_objective.call_deferred()
	_refresh_currency()


## Той самий сигнал, що слухав ObjectiveHUD.
func _connect_objective() -> void:
	var game = Game.get_singleton()
	if game == null:
		return
	if not game.objective_updated.is_connected(_on_objective_updated):
		game.objective_updated.connect(_on_objective_updated)
	_on_objective_updated(game.current_objective)


func _on_objective_updated(text: String) -> void:
	_quest_title.text = text
	# Порожній квест — ховаємо панель, як робив ObjectiveHUD.
	_quest_panel.visible = not text.strip_edges().is_empty()


func _on_coins_changed(_amount: int) -> void:
	_refresh_currency()


func _refresh_currency() -> void:
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	if sl == null:
		return
	var inventory = sl.get_inventory_manager()
	if inventory == null:
		return
	# CoinCounter рахував монети як предмет "coin" — джерело лишаємо те саме.
	_currency_value.text = _thousands(inventory.get_item_count("coin"))


func _on_menu_pressed() -> void:
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	if sl == null:
		return
	var menu_manager = sl.get_menu_manager()
	if menu_manager and menu_manager.has_method("toggle_game_menu"):
		menu_manager.toggle_game_menu()


func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out
