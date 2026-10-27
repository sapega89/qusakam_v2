extends Control
class_name UIPlayerVitalsPanel

## Панель героя v2, вгорі ліворуч (D453, D476, D485). Figma: UI/HUD/HeroPanel v2 (501:6611).
## Виміри: design/combat_hud_mapping.md → HUD v2 hero panel. Розкладка — у player_vitals_panel.tscn.
##
## Портрет у шестикутнику, ромб рівня, ім'я й клас, рядки HP, SP і ST (витривалість, D776: рядок з Figma 501:6611 ревізії
## D549, плитка 470 × 144). Виснажений герой пробує діяти — рядок ST блимає (UITokens.STAMINA_EMPTY_FLASH). XP — смуга на всю
## ширину внизу (D552, hud_xp_bar). Під плиткою — чипи F (асист, hud_assist_chip.gd) і Q (зілля з лічильником, D538).
## Значення беруться з наявних власників — вузол гравця (CombatBody2D), SkillManager і XPManager. Формул тут немає.

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const QuickPotion = preload("res://SampleProject/Scripts/Combat/QuickPotion.gd")

## Тряска рядка HP від удару по героєві (4b): px і с.
const HURT_SHAKE := 4.0
const HURT_TIME := 0.3
var _hurt: Tween
var _st_flash: Tween

@onready var _name_label: Label = %VitalsName
@onready var _level_label: Label = %LevelValue
@onready var _class_label: Label = %HeroClass
@onready var _rows: Control = %VitalsBars
@onready var _potion_chip: Control = %PotionChip

var _skill_manager: Node = null
var _xp_manager: Node = null
var _player: Node = null
var _rows_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group(&"player_vitals_panel")
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	_skill_manager = sl.get_skill_manager()
	_xp_manager = sl.get_xp_manager()
	for row in _rows.get_children():
		_rows_by_id[String(row.name)] = row
	%Portrait.texture = CharacterManager.HERO_PORTRAIT
	%PortraitMask.color = UITokens.HUD_PORTRAIT_BG
	%Rule.color = UITokens.HUD_RULE
	EventBus.oath_sworn.connect(func(_oath: String) -> void: refresh())
	# Подієво, без опитування щокадру: кожне значення має власника з сигналом.
	if not EventBus.sp_changed.is_connected(_on_sp_changed):
		EventBus.sp_changed.connect(_on_sp_changed)
	if not EventBus.player_respawned.is_connected(_on_player_respawned):
		EventBus.player_respawned.connect(_on_player_respawned)
	if not EventBus.damage_received.is_connected(_on_damage_received):
		EventBus.damage_received.connect(_on_damage_received)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.player_stamina_refused.connect(_on_stamina_refused)
	EventBus.inventory_updated.connect(_refresh_potion)
	EventBus.input_device_changed.connect(func(_pad: bool) -> void: _refresh_potion())
	if _xp_manager:
		if not _xp_manager.xp_gained.is_connected(_on_xp_gained):
			_xp_manager.xp_gained.connect(_on_xp_gained)
		if not _xp_manager.level_up.is_connected(_on_level_up):
			_xp_manager.level_up.connect(_on_level_up)
	refresh()


func _on_sp_changed(_current: int, _max: int) -> void:
	refresh()


func _on_stamina_changed(current: float, maximum: float, _exhausted: bool) -> void:
	_set_row("ST", roundi(current), roundi(maximum))


## Виснажений герой пробує ударити чи перекотитись (D776): рядок ST спалахує червоним і гасне.
func _on_stamina_refused() -> void:
	if _st_flash and _st_flash.is_running():
		return
	var row: Control = _rows_by_id["ST"]
	row.modulate = UITokens.STAMINA_EMPTY_FLASH
	_st_flash = create_tween()
	_st_flash.tween_property(row, ^"modulate", Color.WHITE, UITokens.STAMINA_FLASH_TIME)


## Чип Q (D538 → HUD v2): кнопка за пристроєм і все зілля лікування в сумці в пігулці «×3».
func _refresh_potion() -> void:
	_potion_chip.get_node(^"Badge/Key").text = InputGlyphs.badge(&"quick_potion")
	_potion_chip.get_node(^"Pill/Count").text = "×%d" % QuickPotion.count()


func _on_xp_gained(_amount: int, _new_total: int) -> void:
	refresh()


func _on_level_up(_new_level: int, _old_level: int) -> void:
	refresh()


## CombatBody2D емітує це на будь-яку зміну HP або Max_Health.
func _on_player_health_changed(_hp: int, _max_hp: int, _animate: bool) -> void:
	refresh()


## Героя вдарили (4b): рядок HP трясеться й на мить червоніє — лише цей елемент, не екран. Важкий удар — сильніше.
func _on_damage_received(target: Node, source: Node, _amount: int, _critical: bool) -> void:
	if not target.is_in_group(GameGroups.PLAYER):
		return
	var row: Control = _rows_by_id["HP"]
	var shake: float = HURT_SHAKE * (2.0 if VFXHooks.is_big_hurt(source) else 1.0)
	if _hurt:
		_hurt.kill()
	row.position.x = 0.0
	var bar: ProgressBar = row.get_node(^"Bar")
	bar.modulate = UITokens.HURT_RED
	_hurt = create_tween().set_ignore_time_scale()
	for k: float in [1.0, -0.7, 0.4, 0.0]:
		_hurt.tween_property(row, ^"position:x", shake * k, HURT_TIME / 4.0)
	_hurt.parallel().tween_property(bar, ^"modulate", Color.WHITE, HURT_TIME)


func _on_player_respawned() -> void:
	_player = null
	refresh()


## Єдине джерело правди — вузол гравця: саме його current_health/Max_Health
## обмежують урон. Копії значення тут не зберігаємо.
func _ensure_player() -> Node:
	if is_instance_valid(_player) and _player.is_inside_tree():
		return _player
	_player = null
	var tree := get_tree()
	if tree == null:
		return null
	var found: Node = tree.get_first_node_in_group(GameGroups.PLAYER)
	# HUD існує раніше за гравця (кімната ще вантажиться) — тоді ще нема кого показувати.
	if found == null:
		return null
	_player = found
	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	return _player


## Ім'я й клас складені з tr() (ім'я — верхній регістр) — при зміні мови перемальовуємо (BACKLOG 31).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	if sl == null:
		return
	var gm = sl.get_game_manager()
	var character = gm.get_active_character() if gm else null
	_name_label.text = tr(String(character.name)).to_upper() if character else "—"

	if _xp_manager == null:
		_xp_manager = sl.get_xp_manager()
	_level_label.text = str(_xp_manager.get_level() if _xp_manager else 1)
	# Клас (D532, як Status): складена клятва, до клятви — клас-стовбур (Holy Warrior).
	var oath_id: String = _skill_manager.get_oath()
	_class_label.text = tr(String(SkillDatabase.get_oath(oath_id).name)) if oath_id != "" else tr(SkillDatabase.class_name_trunk)

	var player: Node = _ensure_player()
	if player:
		_set_row("HP", int(player.current_health), int(player.Max_Health))
		_set_row("ST", roundi(player.stamina.current), roundi(player.stamina.MAX))
	else:
		# Джерело не резолвиться — показуємо це чесно, а не повний бар.
		_set_row_unknown("HP")
		_set_row_unknown("ST")
	_refresh_potion()
	if _skill_manager:
		_set_row("SP", _skill_manager.get_current_sp(), _skill_manager.get_max_sp())
	else:
		_set_row_unknown("SP")


func _set_row(id: String, current: int, maximum: int) -> void:
	var row: Control = _rows_by_id.get(id)
	if row == null:
		return
	var bar: ProgressBar = row.get_node(^"Bar")
	var value: Label = row.get_node(^"Value")
	bar.max_value = maxf(1.0, float(maximum))
	bar.value = float(clampi(current, 0, maxi(maximum, 0)))
	value.text = "%s / %s" % [_thousands(current), _thousands(maximum)]


func _set_row_unknown(id: String) -> void:
	var row: Control = _rows_by_id.get(id)
	if row == null:
		return
	var bar: ProgressBar = row.get_node(^"Bar")
	var value: Label = row.get_node(^"Value")
	bar.max_value = 1.0
	bar.value = 0.0
	value.text = "— / —"


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
