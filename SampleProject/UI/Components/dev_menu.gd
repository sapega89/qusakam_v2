extends Control

## Режим розробника (D943, [[dev_menu_plan]] slice 1): F10 у будь-якій збірці — золото, безсмертя, повне HP.
## Відкрите меню ставить гру на паузу; F10 чи Esc — закрити. Безсмертя — Player.dev_god, не is_invulnerable
## (той вмикає й вимикає перекат). Рядок консолі виконує будь-який вираз GDScript (Expression): автозавантаження за
## іменем (ServiceLocator, GameManager, EventBus…), а ще player і game — напр. ServiceLocator.get_xp_manager().add_xp(500).

## D943: перед публічним релізом — false.
const ENABLED := true

@onready var _god: Button = %God


func _ready() -> void:
	hide()
	%Gold100.pressed.connect(_add_gold.bind(100))
	%Gold1000.pressed.connect(_add_gold.bind(1000))
	_god.pressed.connect(_toggle_god)
	%FullHp.pressed.connect(_full_hp)
	%Console.placeholder_text = "ServiceLocator.get_xp_manager().add_xp(500)  ⏎"
	%Console.text_submitted.connect(run)


func _unhandled_input(ev: InputEvent) -> void:
	if not ENABLED:
		return
	var f10: bool = ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F10
	if f10 or (visible and ev.is_action_pressed(&"ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_refresh()
		%Gold100.grab_focus()


func _add_gold(amount: int) -> void:
	ServiceLocator.get_inventory_manager().add_coins(amount)


func _toggle_god() -> void:
	var hero = GameGroups.get_player()  # Player.gd: dev_god, restore_health
	hero.dev_god = not hero.dev_god
	_refresh()


func _full_hp() -> void:
	var hero = GameGroups.get_player()  # Player.gd: dev_god, restore_health
	hero.restore_health(hero.Max_Health)


func _refresh() -> void:
	_god.text = tr("God mode: ON") if GameGroups.get_player().dev_god else tr("God mode: OFF")


## Виконує [param text] як вираз GDScript і пише результат (або помилку) під рядком. Повертає результат.
func run(text: String) -> Variant:
	var names := PackedStringArray()
	var values: Array = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop.name
		if key.begins_with("autoload/"):
			var autoload := key.trim_prefix("autoload/")
			names.append(autoload)
			values.append(get_node("/root/" + autoload))
	names.append_array(["player", "game"])
	values.append_array([GameGroups.get_player(), Game.get_singleton()])
	var expression := Expression.new()
	var result: Variant = null
	if expression.parse(text, names) != OK:
		%ConsoleOut.text = expression.get_error_text()
	else:
		result = expression.execute(values, self)
		%ConsoleOut.text = expression.get_error_text() if expression.has_execute_failed() else str(result)
	return result
