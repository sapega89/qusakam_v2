extends Control

## GameMenu — одна сцена (D116, design/game_menu_single_scene_plan.md).
## Усі вікна та їхній початковий стан задані в game_menu.tscn. Скрипт нічого
## не шукає й не ховає на старті — лише перемикає панель, коли натиснуто вкладку.
## Кожна кнопка вкладки несе metadata/tab (ім'я) і metadata/panel (шлях до панелі).

const MiscMenuModalScene = preload("res://SampleProject/Scenes/Menus/Game/misc_menu_modal.tscn")
const MODAL_TEMPLATES = preload("res://SampleProject/Scripts/UI/modal_templates.gd")
const ICON_LOCK := preload("res://SampleProject/Assets/UI/Icons/lock.svg")

@onready var _tabs: ButtonGroup = (%InventoryButton as Button).button_group
@onready var misc_button: Button = %MiscButton
@onready var focus_router: FocusRouter = $FocusRouter

var current_tab_name: String = ""
var _pending_exit_action: String = ""


func _ready() -> void:
	add_to_group("game_menu")
	_lock_tabs()
	current_tab_name = _tabs.get_pressed_button().get_meta("tab")
	_tabs.pressed.connect(_on_tab_pressed)
	misc_button.pressed.connect(_onmisc_button_pressed)
	for button in _tabs.get_buttons():
		if button.disabled:
			continue
		# Як у головному меню: наведення мишею = фокус, а вказівник іде за фокусом.
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_update_pointer)
		button.focus_exited.connect(_update_pointer, CONNECT_DEFERRED)
	_connect_ui_refresh()
	_apply_localized_labels()
	focus_router.set_active_tab(current_tab_name)
	focus_router.focus_tabs()


## Вкладки відкриває сюжет: metadata/unlock_flag — прапорець квесту, без якого
## кнопка сіра із замком і не натискається. Меню створюється заново при кожному
## відкритті, тож достатньо перевірити прапорці тут. Якщо вкладку за замовчуванням
## (Inventory) ще закрито — меню відкривається на Misc, вона доступна завжди,
## але з порожнім центром: налаштування — лише після Misc → Settings.
func _lock_tabs() -> void:
	var game := Game.get_singleton()
	for button in _tabs.get_buttons():
		if button.has_meta("unlock_flag") and not game.get_quest_flag(button.get_meta("unlock_flag")):
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			button.icon = ICON_LOCK
	if _tabs.get_pressed_button().disabled:
		for button in _tabs.get_buttons():
			button.set_pressed_no_signal(button == misc_button)
		for panel in %ContentRoot.get_children():
			panel.visible = false


func _on_tab_pressed(button: BaseButton) -> void:
	# Misc лише відкриває список пунктів (_onmisc_button_pressed); налаштування
	# з'являються тільки після вибору Settings. Тож вкладка лишається попередньою.
	if button == misc_button:
		if current_tab_name != "Misc":
			switch_to_tab(current_tab_name)
		return
	switch_to_tab(button.get_meta("tab"))


## Вказівник ▶ (D118): на вкладці у фокусі / під мишею; коли фокус пішов
## у вміст — повертається на натиснуту. Завжди рівно один.
func _update_pointer() -> void:
	var owner: Control = get_viewport().gui_get_focus_owner()
	var buttons: Array[BaseButton] = _tabs.get_buttons()
	var target: BaseButton = owner as BaseButton if owner in buttons else _tabs.get_pressed_button()
	for button in buttons:
		button.theme_type_variation = &"SidebarTabOn" if button == target else &"SidebarTab"


## Показує панель вкладки [param tab_name], ховає решту. Викликається і з
## натискання кнопки, і ззовні (Misc → Settings, тести), тож кнопка теж
## має стати натиснутою.
func switch_to_tab(tab_name: String) -> void:
	var buttons: Array[BaseButton] = _tabs.get_buttons()
	# Невідоме ім'я сховало б усі панелі — меню лишилося б порожнім.
	if not buttons.any(func(b: BaseButton) -> bool: return b.get_meta("tab") == tab_name):
		push_warning("GameMenu: unknown tab '%s'" % tab_name)
		return
	var focus_in_tabs: bool = get_viewport().gui_get_focus_owner() in buttons
	for button in buttons:
		var on: bool = button.get_meta("tab") == tab_name
		button.set_pressed_no_signal(on)
		if on:
			_show_only(button.get_node(button.get_meta("panel")))
			# Перемикання з коду: фокус іде за вкладкою, інакше світяться дві (B7).
			if focus_in_tabs:
				button.grab_focus()
	current_tab_name = tab_name
	focus_router.set_active_tab(tab_name)
	_update_pointer()


## Видима рівно одна панель ContentRoot — і та, що не має своєї кнопки (Tutorial).
func _show_only(panel: Node) -> void:
	for child in panel.get_parent().get_children():
		child.visible = child == panel


func _connect_ui_refresh() -> void:
	_get_ui_manager().ui_refresh_requested.connect(_apply_localized_labels)


func _apply_localized_labels() -> void:
	for button in _tabs.get_buttons():
		button.text = tr(button.get_meta("tab"))


func _get_ui_manager() -> Node:
	return ServiceLocator.get_ui_manager()


func _onmisc_button_pressed() -> void:
	var modal_layer = _get_ui_manager().get_modal_layer()
	modal_layer.show_custom_modal(MiscMenuModalScene)
	# Повертаємо фокус на кнопку Misc, коли модалка зникає.
	modal_layer.modal_closed.connect(_on_misc_modal_closed, CONNECT_ONE_SHOT)
	var modal = modal_layer.active_modal
	modal.settings_selected.connect(_on_misc_settings_selected, CONNECT_ONE_SHOT)
	modal.tutorial_selected.connect(_on_misc_tutorial_selected, CONNECT_ONE_SHOT)
	modal.controls_selected.connect(_on_misc_controls_selected, CONNECT_ONE_SHOT)
	modal.exit_main_menu_selected.connect(_on_misc_exit_main_menu_selected, CONNECT_ONE_SHOT)
	modal.exit_game_selected.connect(_on_misc_exit_game_selected, CONNECT_ONE_SHOT)


func _on_misc_modal_closed(_result: String) -> void:
	# Тільки якщо меню ще відкрите — на виході з гри фокусувати нема що.
	if is_inside_tree() and misc_button.is_visible_in_tree():
		misc_button.grab_focus.call_deferred()


func _on_misc_settings_selected() -> void:
	# Налаштування живуть у вкладці Misc цього меню. change_scene_to_file()
	# вивантажив би запущену гру разом із паузою.
	switch_to_tab("Misc")


## Список тем — у центрі меню під вкладкою Misc; тема відкривається на весь екран
## (D126). change_scene_to_file() вивантажував запущену гру і лишав гравця на
## заглушці без виходу (B2).
func _on_misc_tutorial_selected() -> void:
	switch_to_tab("Misc")
	_show_only(%TutorialComponent)


## Усі дії з клавішами й кнопками геймпада (D-28f) — у центрі меню, як список тем.
func _on_misc_controls_selected() -> void:
	switch_to_tab("Misc")
	_show_only(%ControlsComponent)


func _on_misc_exit_main_menu_selected() -> void:
	request_exit_to_main_menu()


## Вихід у головне меню з підтвердженням — з Misc і з кнопки на вкладці Settings (B64).
func request_exit_to_main_menu() -> void:
	_pending_exit_action = "exit_main_menu"
	_show_exit_confirm()


func _on_misc_exit_game_selected() -> void:
	_pending_exit_action = "exit_game"
	_show_exit_confirm()


func _show_exit_confirm() -> void:
	var ui_manager = _get_ui_manager()
	ui_manager.get_modal_layer().modal_closed.connect(_on_exit_confirm_closed, CONNECT_ONE_SHOT)
	var data = MODAL_TEMPLATES.confirm_exit_to_main_menu() if _pending_exit_action == "exit_main_menu" \
		else MODAL_TEMPLATES.confirm_exit_game_unsaved()
	ui_manager.show_modal(data)


func _on_exit_confirm_closed(result: String) -> void:
	if result == "confirm":
		if _pending_exit_action == "exit_main_menu":
			# UIManager живе в autoload GameManager і переживає зміну сцени —
			# без цього Game Menu лишався відкритим поверх титульного екрана.
			_get_ui_manager().close_state()
			get_tree().set_meta("show_title_screen", true)
			get_tree().change_scene_to_file("res://SampleProject/MainMenu.tscn")
		elif _pending_exit_action == "exit_game":
			get_tree().quit()
	_pending_exit_action = ""


func close_menu() -> void:
	ServiceLocator.get_menu_manager().close_game_menu()


## _unhandled_input, а не _input: Esc спершу отримує відкрита модалка (Misc,
## підтвердження) і закриває себе; меню закривається, лише коли Esc нікому не потрібен.
func _unhandled_input(event: InputEvent) -> void:
	# Через InputMap, а не сирий KEY_ESCAPE: щоб працювали ремапінг і геймпад. B (ui_cancel) і Start (game_menu).
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"game_menu"):
		close_menu()
		get_viewport().set_input_as_handled()
