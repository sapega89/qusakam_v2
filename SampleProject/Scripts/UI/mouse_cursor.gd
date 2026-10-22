extends Node

## Курсор у грі (D157 → D417, gamepad_plan slice 1b). Дитина Game: живе лише в грі; PROCESS_MODE_ALWAYS
## у .tscn — меню ставить гру на паузу, і курсор має зʼявитися й тоді.
## - У грі курсор схований; Alt (дія toggle_mouse) показує / ховає його.
## - Game Menu, кожне меню, що ставить гру на паузу, стан UIManager і модалка завжди мають курсор;
##   після їх закриття повертається стан Alt.
## - Поки курсор схований, події миші не доходять до GUI (ні клік, ні наведення — mouse_entered,
##   на якому деякі UI-скрипти беруть фокус), але лишаються необробленими: ЛКМ і далі б'є
##   (Player._unhandled_input). Сцена — mouse_cursor.tscn.

## Стан Alt у грі: true — гравець показав курсор.
var shown_by_player: bool = false
## Курсор зараз видно. Headless-драйвер ігнорує Input.mouse_mode — тест читає це поле.
var cursor_visible: bool = true

## Екран над усім HUD (шар 128, MOUSE_FILTER_PASS): поки курсор схований, наведення й кліки GUI
## дістаються йому, а не кнопкам під ним; PASS не позначає подію обробленою — вона йде далі в
## _unhandled_input. Позицію миші GUI бере ще до _input, тож фільтрувати події в _input замало.
@onready var _shield: Control = $Shield/Blocker


func _ready() -> void:
	_apply(_wanted())


func _exit_tree() -> void:
	# Головне меню та інші екрани поза грою — з курсором.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var wanted: bool = _wanted()
	if wanted != cursor_visible:
		_apply(wanted)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_mouse") and not event.is_echo():
		# Поки меню чи модалка тримають курсор, Alt не міняє стан гри.
		if not _forced():
			shown_by_player = not shown_by_player
			_sync()
		return
	if event is InputEventMouse:
		_sync()  # меню могло відкритися в цьому ж кадрі — тоді подія вже належить йому


## Меню, пауза чи модалка — курсор потрібен незалежно від Alt.
func _forced() -> bool:
	var ui: Node = ServiceLocator.get_ui_manager()
	return get_tree().paused or ui.is_ui_active() or ui.get_modal_layer().active_modal != null


func _wanted() -> bool:
	return shown_by_player or _forced()


func _apply(visible_now: bool) -> void:
	cursor_visible = visible_now
	_shield.visible = not visible_now
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible_now else Input.MOUSE_MODE_HIDDEN
