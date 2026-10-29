extends Control

## Режим розробника (D943, [[dev_menu_plan]] slice 1): F10 у будь-якій збірці — золото, безсмертя, повне HP.
## Відкрите меню ставить гру на паузу; F10 чи Esc — закрити. Безсмертя — Player.dev_god, не is_invulnerable
## (той вмикає й вимикає перекат).

## D943: перед публічним релізом — false.
const ENABLED := true

@onready var _god: Button = %God


func _ready() -> void:
	hide()
	%Gold100.pressed.connect(_add_gold.bind(100))
	%Gold1000.pressed.connect(_add_gold.bind(1000))
	_god.pressed.connect(_toggle_god)
	%FullHp.pressed.connect(_full_hp)


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
