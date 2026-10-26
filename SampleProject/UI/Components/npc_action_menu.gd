extends VBoxContainer
class_name NpcActionMenu

## Меню дій NPC. Figma: npc-interaction-menu у npc-menu-merchant 164:1302 /
## npc-menu-blacksmith 176:1357; рядки — UI/Menu Item 248:62 (активний: SemiBold + шеврон).
## Працює й під паузою; ui_cancel закриває. Лише клавіатура/геймпад (D155); миша ігнорується.
## D735 (критик раунду 13): меню зʼявляється саме (D454), фокус на першому пункті, герой ще біжить повз (A/D, стік,
## стрибок пробілом / A). Перша ж клавіша меню — W/S, стрілки вгору/вниз, хрестовина (MenuNavKeys) — бере меню:
## фокус іде на сусідній пункт, і відтоді, доки пункт не вибрано (interact — E / Y, Enter, пробіл, A) чи меню не
## закрито (ui_cancel — Esc / B), герой не ходить, не стрибає й не бʼє (сигнал engaged, NpcBase заморожує героя).

signal chosen(id: StringName)
signal cancelled
## Гравець узяв меню клавішею навігації (D735) — героя заморожено до вибору чи закриття.
signal engaged

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const POINTER := preload("res://SampleProject/Assets/UI/Icons/chevron.svg")
## Основний квест у списку Quest (D161): золотий ромбик праворуч у рядку.
const DIAMOND := preload("res://SampleProject/Assets/UI/Icons/diamond_sm.svg")
const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")
const MenuNavKeys := preload("res://SampleProject/UI/Components/menu_nav_keys.gd")

## Меню взяте клавішею навігації (D735); open() скидає.
var is_engaged := false


func _ready() -> void:
	if theme == null:
		theme = load(THEME_PATH)
	theme_type_variation = &"NpcMenuList"
	custom_minimum_size.x = UITokens.NPC_MENU_WIDTH
	process_mode = Node.PROCESS_MODE_ALWAYS


## [param entries] — масив {id, label, main?}. Показуються лише передані пункти; main — рядок із ромбиком.
func setup(entries: Array) -> void:
	for child in get_children():
		# remove_child одразу: інакше open() віддасть фокус старій кнопці, що ось-ось зникне.
		remove_child(child)
		child.queue_free()
	for entry in entries:
		var b := Button.new()
		b.name = String(entry.id)
		b.text = entry.label
		b.icon = POINTER
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.theme_type_variation = &"NpcMenuItem"
		b.focus_neighbor_left = ^"."
		b.focus_neighbor_right = ^"."
		b.focus_entered.connect(func(): b.theme_type_variation = &"NpcMenuItemOn")
		b.focus_exited.connect(func(): b.theme_type_variation = &"NpcMenuItem")
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): chosen.emit(entry.id))
		if entry.get("main", false):
			var diamond := TextureRect.new()
			diamond.name = "Diamond"
			diamond.texture = DIAMOND
			diamond.modulate = UITokens.ACCENT
			diamond.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(diamond)
			diamond.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, UITokens.SPACE_SM)
		add_child(b)


func open() -> void:
	scale = WORLD_UI.screen_scale(self)  # екранний розмір під збільшеною камерою (D170)
	is_engaged = false
	visible = true
	for child in get_children():
		if child is Button:
			child.grab_focus.call_deferred()
			return


## Стік у Godot теж веде ui_up/ui_down; тут він лише для руху героя (D155).
## Навігацію (W/S, стрілки, хрестовина) ведемо самі тут, до GUI: перша бере меню (D735).
## Пробіл і геймпад A — і ui_accept, і стрибок: поки меню не взяте, герой біжить повз (D454), тож вони
## стрибають, а не вибирають; у взятому меню — вибирають, як Enter.
## Input-опитування (PlayerMover) бачить подію й після set_input_as_handled — героя тримає engaged (Player.event).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var by := MenuNavKeys.step(event)
	if by != 0:
		get_viewport().set_input_as_handled()
		engage()
		MenuNavKeys.move_focus(self, by)
	elif event is InputEventJoypadMotion or (not is_engaged and event.is_action(&"ui_accept") and event.is_action(&"jump")):
		get_viewport().set_input_as_handled()


## Меню бере гравець: героя заморожено, доки меню відкрите (D735).
func engage() -> void:
	if is_engaged:
		return
	is_engaged = true
	engaged.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
	elif event.is_action_pressed(&"interact"):
		# ui_accept не має кнопки геймпада; вибираємо тією ж дією, що відкрила меню.
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused.get_parent() == self:
			get_viewport().set_input_as_handled()
			(focused as Button).pressed.emit()
