extends Control
class_name UISkillHotbar

## Бойова панель навичок v2: вісім слотів, дві четвірки навколо ромба (D453, D476, D549).
## Figma: UI/HUD/Hotbar v2 (497:6587). Виміри й стани: design/combat_hud_mapping.md → HUD v2 hotbar.
## Розкладка — у skill_hotbar.tscn і hotbar_slot.tscn; тут лише стан слотів. Зілля (Q) і асист (F) — чипи під
## панеллю героя (player_vitals_panel), не тут.
##
## Панель НІЧОГО не рахує: ні шкоду, ні вартість SP, ні перезарядку, ні правила
## доступності. Вона показує стан із SkillManager і просить його застосувати
## навичку. Другого таймера перезарядки в HUD немає — час береться з менеджера.

const SkillSlotInput = preload("res://SampleProject/Scripts/UI/skill_slot_input.gd")
## Недоступний слот (немає SP, не та зброя) — уся група слота тьмяніє (Figma 434:6628, Bind 4).
const UNAVAILABLE_ALPHA := 0.4

@onready var _slots_root: Control = %Slots

var _skill_manager: Node = null
var _slots: Array[Control] = []


func _ready() -> void:
	add_to_group(&"skill_hotbar")
	_skill_manager = ServiceLocator.get_skill_manager()
	for child in _slots_root.get_children():
		_slots.append(child)
	assert(_slots.size() == SkillManager.SLOT_COUNT, "skill_hotbar.tscn: %d slots, SkillManager has %d" % [_slots.size(), SkillManager.SLOT_COUNT])
	for bind in _slots:
		# Плейсхолдер іконки, доки немає мальованих (D28, D550) — той самий квадрат, що й раніше.
		bind.get_node(^"Icon").add_theme_stylebox_override("panel", _icon_box())
	_refresh_keys()
	_connect_live_sources()
	refresh()


func _connect_live_sources() -> void:
	for pair in [
		[EventBus.equipped_skills_changed, _on_loadout_changed],
		[EventBus.sp_changed, _on_sp_changed],
		[EventBus.skill_used, _on_skill_used],
		[EventBus.weapon_in_hand_changed, _on_weapon_changed],
		[EventBus.input_device_changed, _on_input_device_changed],
	]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])


func _on_loadout_changed(_loadout: Array) -> void:
	refresh()


func _on_sp_changed(_current: int, _max: int) -> void:
	refresh()


func _on_skill_used(_skill_id: String) -> void:
	refresh()


func _on_weapon_changed(_slot: String) -> void:
	refresh()  # Fire / Electric Strike залежать від зброї в руці (D202)


## Перезарядка тікає в SkillManager; тут лише перемальовуємо залишок.
func _process(_delta: float) -> void:
	for i in _slots.size():
		var skill_id := String(_skill_manager.get_equipped_skill(i))
		if not skill_id.is_empty() and _skill_manager.is_skill_on_cooldown(skill_id):
			_update_slot(i)


## Бейдж — кнопка з InputMap на пристрої, яким грали останнім (BACKLOG 24); на геймпаді 5–8 — «LT+…» (D549).
func _refresh_keys() -> void:
	for i in _slots.size():
		_slots[i].get_node(^"Badge/Key").text = SkillSlotInput.badge(i)


func _on_input_device_changed(_pad: bool) -> void:
	_refresh_keys()


func refresh() -> void:
	for i in _slots.size():
		_update_slot(i)


## Малює один слот за вердиктом SkillManager. Жодних власних правил.
## Порожній — сам шестикутник; готовий — золоте кільце й світіння; перезарядка — темний шар і секунди.
func _update_slot(index: int) -> void:
	var bind: Control = _slots[index]
	var skill_id := String(_skill_manager.get_equipped_skill(index))
	var empty := skill_id.is_empty()
	var on_cooldown: bool = (not empty) and _skill_manager.is_skill_on_cooldown(skill_id)
	var usable: bool = (not empty) and _skill_manager.can_use_skill(skill_id) == SkillManager.Result.OK

	bind.get_node(^"Icon").visible = not empty
	var cost: int = 0 if empty else SkillDatabase.get_skill(skill_id).sp_cost
	bind.get_node(^"Gem").visible = cost > 0
	bind.get_node(^"Gem/Cost").text = str(cost)

	# Перезарядка: залишок бере менеджер, HUD власного таймера не має.
	var overlay: Control = bind.get_node(^"Cooldown")
	overlay.visible = on_cooldown
	if on_cooldown:
		overlay.get_node(^"Seconds").text = tr("%ds") % ceili(_skill_manager.get_remaining_cooldown(skill_id))

	bind.get_node(^"Ready").visible = usable
	bind.get_node(^"Glow").visible = usable
	bind.modulate.a = 1.0 if (empty or usable or on_cooldown) else UNAVAILABLE_ALPHA


func _icon_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UITokens.ICON_SLOT_BG
	box.set_corner_radius_all(UITokens.RADIUS)
	return box


## Вхід зі слота: розв'язати слот → попросити SkillManager про каст героя (замах, D271). Нічого не рахуємо.
## Слот за подією — SkillSlotInput (клавіші 1–8; на геймпаді LT зсуває на 5–8, D549).
func _unhandled_input(event: InputEvent) -> void:
	var slot := SkillSlotInput.slot_for(event)
	if slot < 0:
		return
	_skill_manager.cast_slot(slot)
	get_viewport().set_input_as_handled()
