extends Control

## Save Slot Selection — спільна логіка для LOAD і SAVE (D75, D80).
## Figma: load-game-screen 150:1278 (LOAD), save-game-screen 17:5 (SAVE),
## overwrite 258:5162. Дві сцени станів (load_game_state / save_game_state)
## інстансують цей екран і задають режим.
##
## LOAD: порожні слоти видимі, але вимкнені й без фокусу (D77); зайнятий слот
##       завантажується одразу, без підтвердження (D78).
## SAVE: зайнятий слот → "Overwrite Save?"; успіх → "Game Saved" (D76) → закрити;
##       помилка → "Save Failed" (D79), екран лишається.

signal menu_closed(action: String)

const SLOT_CARD_SCENE := preload("res://SampleProject/UI/Components/save_slot_card.tscn")
const MODAL_TEMPLATES := preload("res://SampleProject/Scripts/UI/modal_templates.gd")
const MAIN_MENU_PATH := "res://SampleProject/MainMenu.tscn"
const DELETE_ACTION := &"save_delete"

var mode: String = "load"
var use_state_navigation: bool = false
## Сцена, яку відкриває LOAD. Порожній рядок — лише сигнал (для тестів).
var load_target_scene: String = "res://SampleProject/Game.tscn"
## Як виконати збереження: Callable без аргументів → bool. За замовчуванням — Game.save_game().
var save_handler: Callable

var save_slots: Array[Dictionary] = []
var _cards: Array[SaveSlotCard] = []
var _last_focus_slot: int = 1

@onready var _title: Label = %TitleLabel
@onready var _slots: VBoxContainer = %Slots
@onready var _bottom_bar: UIBottomBar = %BottomBar


func set_use_state_navigation(value: bool) -> void:
	use_state_navigation = value


func set_mode(new_mode: String) -> void:
	mode = new_mode
	if is_node_ready():
		_apply_mode()
		refresh()


func _ready() -> void:
	add_to_group(&"save_slot_menu")
	if not save_handler.is_valid():
		save_handler = _save_via_game
	%Overlay.color = UITokens.SAVE_OVERLAY
	%TopPad.custom_minimum_size.y = UITokens.SAVE_TOP_PAD_BOTTOM - UITokens.SAVE_TOP_GAP
	for line in [$Content/Column/TopSection/TitleRow/Ornament/LineLeft,
			$Content/Column/TopSection/TitleRow/Ornament/LineRight]:
		line.custom_minimum_size.x = UITokens.SAVE_ORNAMENT_LINE
	for i in _slot_count():
		var card: SaveSlotCard = SLOT_CARD_SCENE.instantiate()
		_slots.add_child(card)
		card.activated.connect(_on_slot_activated)
		card.card.focus_entered.connect(func(): _last_focus_slot = card.slot)
		_cards.append(card)
	_apply_mode()
	refresh()


func _apply_mode() -> void:
	var saving := mode == "save"
	_title.text = tr("Save Game") if saving else tr("Load Game")
	# Figma LOAD-кадр помилково каже "to save" — беремо правильне дієслово.
	_bottom_bar.set_default_hint(tr("Select a slot to save your game.") if saving
			else tr("Select a slot to load your game."))
	_bottom_bar.set_actions([
		{"key": "LS", "label": tr("Select")},
		{"key": "A", "label": tr("Confirm")},
		{"key": "Y", "label": tr("Delete")},
		{"key": "B", "label": tr("Return")},
	])


## Перечитує слоти з SaveSystem і оновлює картки.
func refresh() -> void:
	save_slots.clear()
	var save_system = _save_system()
	for i in _slot_count():
		var slot := i + 1
		var summary: Dictionary = save_system.get_slot_summary(slot) if save_system \
				else {"slot": slot, "exists": false}
		save_slots.append(summary)
		if i < _cards.size():
			var selectable := mode == "save" or bool(summary.get("exists", false))
			_cards[i].setup(summary, selectable)
	_restore_focus.call_deferred()


func _restore_focus() -> void:
	if not is_inside_tree() or _modal_open():
		return
	var preferred := _last_focus_slot - 1
	if preferred >= 0 and preferred < _cards.size() and _cards[preferred].is_selectable():
		_cards[preferred].card.grab_focus()
		return
	for card in _cards:
		if card.is_selectable():
			card.card.grab_focus()
			return
	# Усі слоти порожні в LOAD: фокусувати нічого — лишається лише "назад".
	var owner_focus := get_viewport().gui_get_focus_owner()
	if owner_focus:
		owner_focus.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _modal_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
	elif event.is_action_pressed(DELETE_ACTION):
		get_viewport().set_input_as_handled()
		_request_delete(_last_focus_slot)


func _on_slot_activated(slot: int) -> void:
	_last_focus_slot = slot
	var summary := save_slots[slot - 1]
	var exists := bool(summary.get("exists", false))
	if mode == "save":
		if exists:
			_show_modal(MODAL_TEMPLATES.overwrite_save(), func(result: String):
				if result == "confirm":
					_save_to_slot(slot))
		else:
			_save_to_slot(slot)
	elif exists:
		_load_slot(slot)


func _load_slot(slot: int) -> void:
	var save_system = _save_system()
	if save_system:
		save_system.set_current_slot(slot)
	get_tree().set_meta("save_file_path", save_slots[slot - 1].get("file_path", ""))
	get_tree().set_meta("start_new_game", false)
	DebugLogger.info("LoadGameMenu: loading slot %d" % slot, "SaveLoad")
	menu_closed.emit("load")
	if not load_target_scene.is_empty():
		get_tree().change_scene_to_file(load_target_scene)


func _save_to_slot(slot: int) -> void:
	var save_system = _save_system()
	if save_system:
		save_system.set_current_slot(slot)
	var ok: bool = save_handler.call() if save_handler.is_valid() else false
	if ok:
		refresh()
		_show_modal(MODAL_TEMPLATES.game_saved(), func(_result: String):
			menu_closed.emit("save"))
	else:
		refresh()
		_show_modal(MODAL_TEMPLATES.save_failed(), func(_result: String):
			_restore_focus())


func _save_via_game() -> bool:
	var game = Game.get_singleton()
	return game != null and game.save_game()


## Видалення слота лишається (Q7), у тій самій родині модалок.
func _request_delete(slot: int) -> void:
	if slot < 1 or slot > save_slots.size() or not save_slots[slot - 1].get("exists", false):
		return
	_show_modal(MODAL_TEMPLATES.delete_save(), func(result: String):
		if result == "confirm":
			var save_system = _save_system()
			if save_system:
				save_system.delete_slot(slot)
		refresh())


func _on_back() -> void:
	menu_closed.emit("back")
	if not use_state_navigation and ResourceLoader.exists(MAIN_MENU_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _show_modal(data: Dictionary, on_closed: Callable) -> void:
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	if ui == null:
		on_closed.call("confirm")
		return
	var layer = ui.get_modal_layer() if ui.has_method("get_modal_layer") else null
	ui.show_modal(data)
	if layer:
		layer.modal_closed.connect(on_closed, CONNECT_ONE_SHOT)
	else:
		on_closed.call("confirm")


func _modal_open() -> bool:
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	var layer = ui.get_modal_layer() if ui and ui.has_method("get_modal_layer") else null
	return layer != null and layer.get("active_modal") != null


func _save_system() -> Node:
	return ServiceLocatorHelper.get_manager("get_save_system")


func _slot_count() -> int:
	var save_system = _save_system()
	return save_system.get_slot_count() if save_system else 4
