extends Control
class_name UICombatHudTop

## Верхній ряд бойового HUD: квест + валюта + кнопка меню.
## Figma: Game Scene / Combat HUD → Quest Info Panel (434:6580)
## та Currency & Settings (434:6586).
##
## Нових механік немає — прив'язки ті самі, що у віджетів, які цей ряд замінює:
## ObjectiveHUD (Game.objective_updated) і CoinCounter (EventBus.coins_changed).
##
## Плашка цілі (BACKLOG 37, Q39) не висить постійно: з'являється, коли ціль з'явилась чи змінилась, тримається
## OBJECTIVE_PLAQUE_HOLD с і гасне. Знову показується, коли гравець виходить із будь-якого меню: Game Menu, магазин,
## кузня, вікно підказки ставлять дерево на паузу — край «пауза → гра» (SceneTree.process_frame іде й під паузою);
## діалог паузи не ставить — EventBus.dialogue_finished.

@onready var _quest_panel: PanelContainer = %QuestPanel
@onready var _quest_title: Label = %QuestTitle
## Куди йти (BACKLOG 28, D-28h): стрілка на мітку цілі в цій кімнаті (Game.objective_marker()).
@onready var _direction: Label = %Direction
@onready var _currency_value: Label = %CurrencyValue
@onready var _menu_button: Button = %MenuButton

var _plaque_tween: Tween = null
var _was_paused: bool = false


func _ready() -> void:
	add_to_group(&"combat_hud_top")
	_menu_button.pressed.connect(_on_menu_pressed)
	_was_paused = get_tree().paused
	EventBus.dialogue_finished.connect(_on_dialogue_finished)

	if not EventBus.coins_changed.is_connected(_on_coins_changed):
		EventBus.coins_changed.connect(_on_coins_changed)
	_connect_objective.call_deferred()
	_refresh_currency()


## Кадр дерева — лише поки HUD у дереві: при зміні сцени (Resume з Game Over, вихід у меню) вузол уже вийнято,
## а process_frame ще приходив — get_tree() == null, SCRIPT ERROR.
func _enter_tree() -> void:
	get_tree().process_frame.connect(_on_frame)


func _exit_tree() -> void:
	get_tree().process_frame.disconnect(_on_frame)


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
	show_plaque()


## Плашка з'являється, тримається OBJECTIVE_PLAQUE_HOLD с і гасне (modulate), якщо ціль є.
func show_plaque() -> void:
	if _plaque_tween:
		_plaque_tween.kill()
	if not _quest_panel.visible:
		return
	_plaque_tween = create_tween()  # під паузою (меню) стоїть разом із HUD
	_plaque_tween.tween_property(_quest_panel, ^"modulate:a", 1.0, UITokens.OBJECTIVE_PLAQUE_FADE)
	_plaque_tween.tween_interval(UITokens.OBJECTIVE_PLAQUE_HOLD)
	_plaque_tween.tween_property(_quest_panel, ^"modulate:a", 0.0, UITokens.OBJECTIVE_PLAQUE_FADE)


func is_plaque_shown() -> bool:
	return _quest_panel.visible and _quest_panel.modulate.a > 0.0


func _on_frame() -> void:
	var paused: bool = get_tree().paused
	if _was_paused and not paused:
		show_plaque()  # вийшли з меню
	_was_paused = paused


func _on_dialogue_finished(_dialogue_id: String) -> void:
	show_plaque()


## Ближче за стільки px — ціль тут, стрілка ховається.
const ARRIVED_DISTANCE := 96.0
const ARROWS := {Vector2i.RIGHT: "→", Vector2i.LEFT: "←", Vector2i.UP: "↑", Vector2i.DOWN: "↓"}


func _process(_delta: float) -> void:
	var game := Game.get_singleton()
	var marker: Node2D = game.objective_marker() if game != null else null
	var arrow := direction_to(marker, game.player if game != null else null)
	_direction.visible = arrow != ""
	_direction.text = arrow


## Стрілка від героя до [param marker] за переважною віссю; "" — мітки немає або герой уже там.
static func direction_to(marker: Node2D, hero: Node2D) -> String:
	if marker == null or hero == null:
		return ""
	var offset: Vector2 = marker.global_position - hero.global_position
	if offset.length() <= ARRIVED_DISTANCE:
		return ""
	if absf(offset.x) >= absf(offset.y):
		return ARROWS[Vector2i.RIGHT if offset.x > 0.0 else Vector2i.LEFT]
	return ARROWS[Vector2i.DOWN if offset.y > 0.0 else Vector2i.UP]


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
	ServiceLocator.get_menu_manager().toggle_game_menu()


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
