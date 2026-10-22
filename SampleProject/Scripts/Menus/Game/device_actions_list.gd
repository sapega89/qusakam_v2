extends "res://addons/maaacks_menus_template/base/nodes/menus/options_menu/input/input_actions_list.gd"

## Settings → Controls (D193, B19): список перепризначення maaacks, але лише одного пристрою —
## клавіатура з мишею або геймпад. Колонки — прив'язки ЦЬОГО пристрою по порядку; переназначення
## замінює чи додає лише їх, події іншого пристрою тієї ж дії лишаються. Reset — лише цей пристрій.
## Порядок подій у дії: спершу клавіатура й миша, потім геймпад.

## true — вкладка Gamepad, false — Keyboard & Mouse.
var pad: bool = false


static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## Прив'язки дії на пристрої вкладки ([param on_pad]) у порядку InputMap.
static func events_of(events: Array, on_pad: bool) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for event: InputEvent in events:
		if is_pad_event(event) == on_pad:
			out.append(event)
	return out


func device_events(action_name: StringName) -> Array[InputEvent]:
	return events_of(InputMap.action_get_events(action_name), pad)


## Перемкнути пристрій і перебудувати рядки.
func set_pad(value: bool) -> void:
	pad = value
	_build_ui_list()


## Назви кнопок миші й частини клавіш перекладає рушій («ЛКМ») — після зміни мови рядки складаються заново.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not Engine.is_editor_hint():
		_build_ui_list.call_deferred()


## Кожна дія з прив'язкою хоч на одному пристрої — рядок; комірки — лише події цього пристрою,
## тож дію без кнопки геймпада на вкладці Gamepad можна призначити з порожньої комірки.
func _build_ui_list() -> void:
	action_button_map.clear()
	button_readable_input_map.clear()
	_clear_list()
	_add_header()
	for action_name in _get_all_action_names(show_built_in_actions):
		if InputMap.action_get_events(action_name).is_empty():
			continue
		_add_action_options(action_name, _get_action_readable_name(action_name), device_events(action_name))
	_align_name_column()


## Колонка назв — за найдовшою назвою поточною мовою: рядок із назвою, ширшою за 150px шаблону,
## зсував свої комірки відносно заголовка й сусідів.
func _align_name_column() -> void:
	var labels: Array[Label] = []
	for row in %ParentBoxContainer.get_children():
		if row != %ActionBoxContainer and not row.is_queued_for_deletion():
			labels.append(row.get_child(0))
	var width: float = %ActionBoxContainer.get_child(0).custom_minimum_size.x
	for label in labels:
		width = maxf(width, label.get_minimum_size().x)
	for label in labels:
		label.custom_minimum_size.x = width


func _refresh_ui_list_button_content() -> void:
	for action_name in _get_all_action_names(show_built_in_actions):
		if InputMap.action_get_events(action_name).is_empty():
			continue
		var events := device_events(action_name)
		for group_iter in range(action_groups):
			if group_iter < events.size():
				_update_assigned_inputs_and_button(action_name, group_iter, events[group_iter])
				_update_next_button_disabled_state(action_name, group_iter)
			else:
				_clear_button(action_name, group_iter)
				_update_next_button_disabled_state(action_name, group_iter, true)


func _assign_input_event_to_action_group(input_event: InputEvent, action_name: String, action_group: int) -> void:
	_assign_input_event(input_event, action_name)
	var own := device_events(action_name)
	if action_group < own.size():
		own[action_group] = input_event
	else:
		own.append(input_event)
	_write_events(action_name, own)
	action_group = mini(action_group, own.size() - 1)
	_update_assigned_inputs_and_button(action_name, action_group, input_event)
	_update_next_button_disabled_state(action_name, action_group)


## Типові прив'язки лише цього пристрою; другий пристрій і його переназначення не чіпаються.
func reset() -> void:
	for action_name: StringName in AppSettings.default_action_events:
		_write_events(action_name, events_of(AppSettings.default_action_events[action_name], pad))
	_build_assigned_input_events()
	_refresh_ui_list_button_content()


## Дія отримує [param own] на цьому пристрої й свої поточні події другого; у InputMap і player_config.
func _write_events(action_name: StringName, own: Array[InputEvent]) -> void:
	var other := events_of(InputMap.action_get_events(action_name), not pad)
	var final: Array[InputEvent] = other + own if pad else own + other
	InputMap.action_erase_events(action_name)
	for event in final:
		InputMap.action_add_event(action_name, event)
	AppSettings.set_config_input_events(action_name, final)
