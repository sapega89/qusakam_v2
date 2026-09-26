extends PanelContainer
class_name UISkillHotbar

## Бойова панель навичок.
## Figma: Game Scene / Combat HUD → Skill Hotbar (434:6628).
## Виміри й стани: design/combat_hud_mapping.md
##
## Панель НІЧОГО не рахує: ні шкоду, ні вартість SP, ні перезарядку, ні правила
## доступності. Вона показує стан із SkillManager і просить його застосувати
## навичку. Другого таймера перезарядки в HUD немає — час береться з менеджера.

const SLOT_SIZE := 48
const ICON_SIZE := 28

@onready var _slots_row: HBoxContainer = %SlotsRow

var _skill_manager: Node = null
var _skill_database: Node = null
var _slots: Array[Control] = []


func _ready() -> void:
	add_to_group(&"skill_hotbar")
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator:
		_skill_manager = service_locator.get_skill_manager()
	var tree := get_tree()
	_skill_database = tree.root.get_node_or_null(^"SkillDatabase") if tree else null

	_build_slots()
	_connect_live_sources()
	refresh()


func _connect_live_sources() -> void:
	for pair in [
		[EventBus.equipped_skills_changed, _on_loadout_changed],
		[EventBus.sp_changed, _on_sp_changed],
		[EventBus.skill_used, _on_skill_used],
	]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])


func _on_loadout_changed(_loadout: Array) -> void:
	refresh()


func _on_sp_changed(_current: int, _max: int) -> void:
	refresh()


func _on_skill_used(_skill_id: String) -> void:
	refresh()


## Перезарядка тікає в SkillManager; тут лише перемальовуємо залишок.
func _process(_delta: float) -> void:
	if _skill_manager == null:
		return
	for i in _slots.size():
		var skill_id := String(_skill_manager.get_equipped_skill(i))
		if skill_id.is_empty():
			continue
		if _skill_manager.is_skill_on_cooldown(skill_id):
			_update_slot(i)


func _build_slots() -> void:
	for child in _slots_row.get_children():
		_slots_row.remove_child(child)
		child.queue_free()
	_slots.clear()

	var count: int = _skill_manager.SLOT_COUNT if _skill_manager else 4
	for i in count:
		var bind := VBoxContainer.new()
		bind.name = "Bind%d" % (i + 1)
		bind.add_theme_constant_override("separation", UITokens.SPACE_XS)
		bind.alignment = BoxContainer.ALIGNMENT_CENTER

		var slot := Panel.new()
		slot.name = "Slot"
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

		# CenterContainer тримає плейсхолдер іконки по центру слота надійніше,
		# ніж ручні offset-и: слот може змінювати розмір разом із темою.
		var icon_center := CenterContainer.new()
		icon_center.name = "IconCenter"
		icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_center)

		var icon := Panel.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.add_child(icon)

		var overlay := Label.new()
		overlay.name = "Cooldown"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		overlay.theme_type_variation = &"CooldownLabel"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(overlay)
		bind.add_child(slot)

		var badge := PanelContainer.new()
		badge.name = "Badge"
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var badge_label := Label.new()
		badge_label.name = "Key"
		badge_label.text = str(i + 1)
		badge_label.theme_type_variation = &"BindBadge"
		badge.add_child(badge_label)
		bind.add_child(badge)

		_slots_row.add_child(bind)
		_slots.append(bind)


func refresh() -> void:
	for i in _slots.size():
		_update_slot(i)


## Малює один слот за вердиктом SkillManager. Жодних власних правил.
func _update_slot(index: int) -> void:
	if _skill_manager == null or index >= _slots.size():
		return
	var bind: Control = _slots[index]
	var slot: Panel = bind.get_node(^"Slot")
	var icon: Panel = slot.get_node_or_null(^"IconCenter/Icon")
	if icon == null:
		return
	var overlay: Label = slot.get_node(^"Cooldown")
	var badge: PanelContainer = bind.get_node(^"Badge")
	var badge_label: Label = badge.get_node(^"Key")

	var skill_id := String(_skill_manager.get_equipped_skill(index))
	var empty := skill_id.is_empty()
	var verdict: int = _skill_manager.can_use_skill(skill_id) if not empty else -1
	var on_cooldown: bool = (not empty) and _skill_manager.is_skill_on_cooldown(skill_id)
	var usable: bool = verdict == SkillManager.Result.OK

	# Іконки навичок ще не експортовані — показуємо плейсхолдер (D28).
	icon.add_theme_stylebox_override("panel", _icon_box(empty))

	# Перезарядка: залишок бере менеджер, HUD власного таймера не має.
	if on_cooldown:
		overlay.visible = true
		overlay.text = "%ds" % ceili(_skill_manager.get_remaining_cooldown(skill_id))
		overlay.add_theme_stylebox_override("normal", _overlay_box())
	else:
		overlay.visible = false

	slot.add_theme_stylebox_override("panel", _slot_box(usable and not empty))
	badge.add_theme_stylebox_override("panel", _badge_box(usable and not empty))
	badge_label.add_theme_color_override("font_color",
			UITokens.ON_ACCENT if (usable and not empty) else UITokens.TEXT_PRIMARY)

	# Недоступний слот (немає SP / не готовий) — 40% прозорості, як у Figma.
	bind.modulate.a = 1.0 if (empty or usable or on_cooldown) else 0.4


func _slot_box(highlighted: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UITokens.BACKGROUND
	box.set_corner_radius_all(UITokens.RADIUS)
	if highlighted:
		box.set_border_width_all(UITokens.BORDER_WIDTH_SELECTED)
		box.border_color = UITokens.ACCENT
		box.shadow_color = Color(UITokens.ACCENT, 0.3)
		box.shadow_size = 3
	else:
		box.set_border_width_all(UITokens.BORDER_WIDTH)
		box.border_color = UITokens.BORDER
	return box


func _icon_box(empty: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UITokens.ICON_SLOT_BG if not empty else Color(UITokens.ICON_SLOT_BG, 0.5)
	box.set_corner_radius_all(UITokens.RADIUS)
	return box


func _overlay_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UITokens.BACKGROUND, 0.75)
	box.set_corner_radius_all(UITokens.RADIUS)
	return box


func _badge_box(highlighted: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(UITokens.RADIUS)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	if highlighted:
		box.bg_color = UITokens.ACCENT
	else:
		box.bg_color = UITokens.ICON_SLOT_BG
		box.set_border_width_all(UITokens.BORDER_WIDTH)
		box.border_color = UITokens.BORDER
	return box


## Вхід зі слота: розв'язати слот → попросити SkillManager. Нічого не рахуємо.
func _unhandled_input(event: InputEvent) -> void:
	if _skill_manager == null:
		return
	for i in _slots.size():
		if event.is_action_pressed("skill_slot_%d" % (i + 1)):
			_skill_manager.use_slot(i, _resolve_target(), _resolve_source())
			get_viewport().set_input_as_handled()
			return


## Ціль поки не вибирається автоматично — це окреме дизайнерське рішення
## (див. design/combat_hud_mapping.md → Targeting). Евристики не вигадуємо.
func _resolve_target() -> Node:
	return null


func _resolve_source() -> Node:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator == null:
		return null
	var gm = service_locator.get_game_manager()
	return gm.get_current_player() if gm and gm.has_method("get_current_player") else null
