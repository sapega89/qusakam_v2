extends Node2D

## Зброя героя (D223, D224, D232, D267, D268): спрайт тієї, що в руці (Assets/Weapons/<id>.png, малює
## Scripts/Tools/draw_weapons.py), дзеркалиться за поглядом героя й тримається в його кулаці.
## Поза боєм (PlayerCombat.in_combat) зброї не видно зовсім (D268, Sapega 2026-10-21), у бою — в руці;
## перший удар дістає її одразу.
## Кожен тип зброї має свій удар (D268), за кроком серії PlayerCombat:
##   меч / сокира — дуга згори вниз, знизу вгору, фінішер — широка дуга з-за голови;
##   булава — удар згори (тіло AttackSmash); кинджал — швидкі уколи, фінішер — дуга;
##   алебарда (дворучна) — уколи, другий удар — низький мах, фінішер — довгий випад;
##   дві зброї — удари чергують руки (непарні — друга рука), фінішер — обидві;
##   важкий удар — зброя над головою на замаху, удар згори донизу; голі руки — кулак з «вибухом».
## Пози тіла без удару (блок, збій, замах важкого) ставить _process за станом бою.
## Розмітка — Player.tscn → WeaponMount (Pivot / OffPivot).
## Тип зброї зі своїми кадрами героя (BACKLOG 42, бібліотека анімацій Player.tscn з іменем категорії: sword, dagger,
## mace, polearm; дві зброї — dual_<у руці>_<друга>, зараз dual_sword_dagger): зброя намальована в кадрі, цей спрайт
## схований, поки грає анімація з тієї бібліотеки. Метал у тих кадрах — ключ палітри: шейдер спрайта героя
## (Shaders/weapon_palette.gdshader) фарбує його в палітру предмета (items.json → palette, weapon_palettes.json).

const TEXTURE := "res://SampleProject/Assets/Weapons/%s.png"
const PALETTES := "res://SampleProject/Resources/Data/weapon_palettes.json"
## Параметри шейдера: ключ кадрів і кольори палітри (світлий, середній, темний).
const KEY_PARAMS: Array[StringName] = [&"key_light", &"key_mid", &"key_dark"]
const PALETTE_PARAMS: Array[StringName] = [&"to_light", &"to_mid", &"to_dark"]
const SLASH_TRAIL_SCENE := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
## Точка хвату — стільки пікселів текстури від низу (як GRIP у draw_weapons.py).
const GRIP := 3
## Колючу зброю виносять уперед, решту — замахом (категорії items.json).
const THRUST := ["polearm", "dagger"]
## Зброя без накладного спрайта: її малюють лише кадри героя (лук, D385) — поза ними (стрибок, перекат) її не видно.
const DRAWN_ONLY := ["bow"]
## Де кулак героя в кадрах (px світу від центру героя, обличчям праворуч), виміряно по кулаку:
## хода 1 — стійка, біг 4 — замах, біг 2 — удар; Heavy/1 — кулаки над головою, Heavy/2 — внизу перед собою,
## Block/1 — передній кулак біля підборіддя (A9), Hurt/1 — рука відкинута.
const HAND_REST := Vector2(13, 21)
const HAND_WINDUP := Vector2(20, 14)
const HAND_STRIKE := Vector2(30, 6)
const HAND_OVERHEAD := Vector2(16, -32)
const HAND_LOW := Vector2(24, 27)
const HAND_GUARD := Vector2(23, 0)
const HAND_HURT := Vector2(28, -10)
## Каст навички (D271): кулак і кут зброї в кадрах Cast*/1–2; Cast-анімації без запису (долоня) — зброї не видно.
const CAST_POSES := {
	"CastFireWindup": [Vector2(21, 9), 230.0],  # лезо відведене низько назад
	"CastFireRelease": [Vector2(36, -3), 60.0],  # кінець висхідного розтину
	"CastStormWindup": [Vector2(-7, -33), 0.0],  # вістрям у небо
	"CastStormRelease": [Vector2(35, 1), 90.0],  # уперед, куди б'є блискавка
	# навички руху (H3, D812): кулак кадрів LungeCut / ShieldCharge / LeapSlam 1–3, Sprites/Player/README.md
	"LungeCutWindup": [Vector2(30, 10.5), 230.0],  # лезо низько позаду
	"LungeCutMove": [Vector2(31.5, 4.5), 230.0],
	"LungeCutStrike": [Vector2(33, 1.5), 90.0],  # розтин уперед
	"ShieldChargeWindup": [Vector2(30, -1.5), 20.0],  # як guard_angle
	"ShieldChargeMove": [Vector2(33, 3), 20.0],
	"ShieldChargeStrike": [Vector2(33, -1.5), 60.0],
	"LeapSlamWindup": [Vector2(18, 13.5), 230.0],
	"LeapSlamMove": [Vector2(12, -28.5), -20.0],  # між кулаками над головою, як smash_from
	"LeapSlamStrike": [Vector2(30, 30), 165.0],  # у землю, як smash_to
}
## Друга рука (дві зброї) — дальня, трохи позаду.
const OFF_REST := Vector2(7, 21)
## Центр дуги шлейфу — на рівні плеча; «вибух» кулака — трохи перед рукавицею.
const SMEAR_CENTER := Vector2(8, 0)
const PUNCH_AT := Vector2(40, 6)
const HOOK_LIFT := 12.0
## Зовнішній радіус дуги шлейфу в текстурі (R у draw_hero_attack.py) і довжина смуги уколу.
const SMEAR_RADIUS := 32.0
const SMEAR_LENGTH := 72.0
## Дуга й «вибух» кулака — на стільки більші за довжину зброї (Sapega 2026-10-21: «аури удару досить маленькі»).
## Хітбокс удару = drawn_swing_rect() (B128), перевіряє verify_hit_areas.
const SMEAR_SCALE := 1.3

## Кути, градуси: 0 — вістрям угору, більше — вперед за поглядом.
@export var rest_angle := 135.0
@export var thrust_rest_angle := 80.0
@export var swing_from := -45.0
@export var swing_to := 115.0
## Широка дуга фінішера (з-за голови) і удар згори (булава, важкий).
@export var finisher_from := -100.0
@export var smash_from := -20.0
@export var smash_to := 165.0
@export var guard_angle := 20.0
@export var hurt_angle := 110.0
## Випад: на скільки px уперед виходить колюча зброя (фінішер алебарди — удвічі).
@export var thrust_reach := 14.0
## Збігається з кадрами тіла в анімації Attack (Player.tscn): замах 0.05, удар до 0.13, повернення.
@export var windup_time := 0.05
@export var strike_time := 0.08
@export var hold_time := 0.05
@export var recover_time := 0.12

@onready var player: Node2D = get_parent()
@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Weapon
@onready var off_pivot: Node2D = $OffPivot
@onready var off_sprite: Sprite2D = $OffPivot/OffWeapon
## Матеріал спрайта героя (Player.tscn → Sprite2D, weapon_palette.gdshader).
@onready var _body_material: ShaderMaterial = player.get_node(^"Sprite2D").material
var _category: String = ""
var _off_category: String = ""
## Палітра металу предмета в руці (weapon_palettes.json → palettes) і ключ кадрів.
var palette: String = ""
var _palettes: Dictionary = {}
var _grip: StringName = &"bare"
var _dual: bool = false
var _tween: Tween
## Зброю сховано — не видно (поза боєм, D268).
var sheathed: bool = true


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PALETTES))
	_palettes = data.palettes
	for i in 3:
		_body_material.set_shader_parameter(KEY_PARAMS[i], Color(data.key[i]))
	EventBus.weapon_in_hand_changed.connect(func(_slot: String) -> void: _refresh())
	EventBus.equipment_equipped.connect(func(_c: String, _s: String, _i: String) -> void: _refresh())
	EventBus.equipment_unequipped.connect(func(_c: String, _s: String) -> void: _refresh())
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.combat_state_changed.connect(_on_combat_state_changed)
	EventBus.player_heavy_windup.connect(func(attacker: Node, _d: int) -> void:
		if attacker == player:
			sheathed = false  # замах важкого теж дістає зброю
			if _tween:
				_tween.kill())
	# Після героя: його PlayerCombat (поза в _hold_pose) готовий лише в його _ready — інакше зброя в руці
	# зі сейву (завантаження) падала на player.combat == null.
	player.ready.connect(_refresh, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	scale.x = player.last_direction
	# Поза боєм зброї не видно; у перекаті-ривку герой згорнутий у клубок — зброя з нього не стирчить; мертвий (H1) — без неї
	var in_frame: bool = _drawn_in_frame()
	pivot.visible = not sheathed and not player.is_dead and not player.mover.is_rolling() and not _open_palm() and not in_frame and _category not in DRAWN_ONLY
	if _body_material.get_shader_parameter(&"active") != in_frame:
		_body_material.set_shader_parameter(&"active", in_frame)
	off_pivot.visible = _dual and pivot.visible
	if _tween and _tween.is_running():
		return
	_hold_pose()


## Каст, де рука відкрита (Healing Palm), — зброю не тримає.
func _open_palm() -> bool:
	return String(player.animation).begins_with("Cast") and not CAST_POSES.has(player.animation)


## Бібліотека кадрів героя для зброї в руці (BACKLOG 42): ім'я категорії (дві зброї — dual_<у руці>_<друга>), коли
## зброя дістана (бій або удар) і в AnimationPlayer героя є така бібліотека; інакше &"" — базові кадри й цей спрайт.
func body_library() -> StringName:
	if not visible or (sheathed and not player.combat.is_attacking):
		return &""
	var library := StringName("dual_%s_%s" % [_category, _off_category] if _dual else _category)
	return library if player.get_node(^"AnimationPlayer").has_animation_library(library) else &""


## На екрані кадр з анімації зброї — зброя вже намальована в кадрі. assigned_animation, а не current_animation:
## коротка поза без циклу (Block 0.1 с, Hurt) скінчилась, але її кадр лишається, доки не почнеться наступна.
func _drawn_in_frame() -> bool:
	var library: StringName = body_library()
	return library != &"" and String(player.get_node(^"AnimationPlayer").assigned_animation).begins_with(String(library) + "/")


func _refresh() -> void:
	var equipment := ServiceLocator.get_equipment_manager()
	var item: Dictionary = equipment.get_weapon_item_in_hand()
	_grip = equipment.get_grip()
	visible = not item.is_empty()
	if not visible:
		return
	_category = item.category
	# Лук (D385) без палітри: iron = ключ, кадри лука не перефарбовуються
	_set_palette(item.get("palette", "iron"))
	if _category in DRAWN_ONLY:
		_dual = false
		_off_category = ""
		return
	_set_texture(sprite, item.id)
	var off: Dictionary = equipment.get_off_hand_item()
	_dual = not off.is_empty()
	off_pivot.visible = _dual
	_off_category = String(off.category) if _dual else ""
	if _dual:
		_set_texture(off_sprite, off.id)
	_hold_pose()


## Метал у кадрах зброї — у кольори палітри предмета (у двох зброй — палітра тієї, що в руці).
func _set_palette(id: String) -> void:
	palette = id
	var entry: Dictionary = _palettes[id]
	for i in 3:
		_body_material.set_shader_parameter(PALETTE_PARAMS[i], Color(entry.colors[i]))
	_body_material.set_shader_parameter(&"shimmer", entry.shimmer)
	_body_material.set_shader_parameter(&"glow", entry.glow)
	if entry.has("glow_color"):
		_body_material.set_shader_parameter(&"glow_color", Color(entry.glow_color))


## Спрайт — від базового предмета: у зачарованого («iron_sword+1», D94) свого файла немає (B142).
func _set_texture(target: Sprite2D, id: String) -> void:
	target.texture = load(TEXTURE % ItemDatabase.base_id(id))
	target.offset = Vector2(-target.texture.get_width() / 2.0, -target.texture.get_height() + GRIP)


func _thrust() -> bool:
	return _category in THRUST


func _rest_angle() -> float:
	return thrust_rest_angle if _thrust() else rest_angle


## Поза без удару — за станом PlayerCombat (блок, збій, замах важкого) або стійка.
func _hold_pose() -> void:
	var combat: PlayerCombat = player.combat
	match combat.state:
		PlayerCombat.State.BLOCK:
			_pose(pivot, HAND_GUARD, guard_angle)
		PlayerCombat.State.STAGGER:
			_pose(pivot, HAND_HURT, hurt_angle)
		PlayerCombat.State.HEAVY_WINDUP:
			_pose(pivot, HAND_OVERHEAD, smash_from)
		PlayerCombat.State.CAST_WINDUP, PlayerCombat.State.CAST_MOVE, PlayerCombat.State.CAST_RELEASE:
			var cast: Array = CAST_POSES.get(player.animation, [HAND_REST, _rest_angle()])
			_pose(pivot, cast[0], cast[1])
		_:
			_pose(pivot, HAND_REST, _rest_angle())
	_pose(off_pivot, OFF_REST, _rest_angle())


func _pose(target: Node2D, at: Vector2, angle: float) -> void:
	target.position = at
	target.rotation_degrees = angle


## Бій почався — зброя в руці, скінчився — зникає.
func _on_combat_state_changed(in_combat: bool) -> void:
	sheathed = not in_combat


func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()


func _on_player_attacked(attacker: Node, _direction: int) -> void:
	if attacker != player:
		return
	sheathed = false  # удар дістає зброю одразу (D268)
	var combat: PlayerCombat = player.combat
	var step: int = combat.combo_step
	var finisher: bool = step == combat.combo_length() - 1
	var heavy: bool = combat.state == PlayerCombat.State.HEAVY_STRIKE
	_restart_tween()
	if not visible:
		# Голі руки: рукавиця героя вилітає вперед у кадрі удару — біля неї спалах; парні удари — вище, як хук
		_tween.tween_interval(windup_time)
		_tween.tween_callback(_spawn_smear.bind(&"punch", step % 2 == 1 or finisher, 1.0))
		return
	if heavy or (_category == "mace"):
		_smash(pivot, heavy or finisher)
	elif _dual and step % 2 == 1:
		_slash(off_pivot, true, false)  # друга рука
	elif _thrust() and not (_category == "polearm" and step == 1) and not (_category == "dagger" and finisher):
		_stab(pivot, finisher)
	else:
		_slash(pivot, step % 2 == 1 and not finisher, finisher)
	if _dual and finisher:
		_slash_parallel(off_pivot)
	_tween.tween_callback(_hold_pose)


## Мах: зброя в кулаці біля пояса, відведена; удар — кулак уперед, лезо дугою. [param upward] — знизу вгору.
func _slash(target: Node2D, upward: bool, finisher: bool) -> void:
	var from: float = finisher_from if finisher else swing_from
	target.position = HAND_WINDUP
	target.rotation_degrees = 180.0 - from if upward else from
	_tween.tween_interval(windup_time)
	_tween.tween_callback(_spawn_smear.bind(&"arc", upward, 1.25 if finisher else 1.0))
	_tween.tween_property(target, ^"position", HAND_STRIKE, strike_time).set_ease(Tween.EASE_OUT)
	var to: float = 180.0 - swing_to if upward else swing_to
	_tween.parallel().tween_property(target, ^"rotation_degrees", to, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_recover(target)


## Фінішер двох зброй: друга рука б'є одночасно з першою.
func _slash_parallel(target: Node2D) -> void:
	target.position = HAND_WINDUP
	target.rotation_degrees = swing_from
	var side := create_tween()
	side.tween_interval(windup_time)
	side.tween_property(target, ^"position", HAND_STRIKE, strike_time).set_ease(Tween.EASE_OUT)
	side.parallel().tween_property(target, ^"rotation_degrees", swing_to, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	side.tween_interval(hold_time)
	side.tween_property(target, ^"position", OFF_REST, recover_time)
	side.parallel().tween_property(target, ^"rotation_degrees", _rest_angle(), recover_time)


## Укол: зброя вістрям уперед виходить на thrust_reach (фінішер — удвічі).
func _stab(target: Node2D, finisher: bool) -> void:
	var reach: float = thrust_reach * (2.0 if finisher else 1.0)
	target.position = HAND_WINDUP
	target.rotation_degrees = 90.0
	_tween.tween_interval(windup_time)
	_tween.tween_callback(_spawn_smear.bind(&"thrust", false, (_reach() + reach) / SMEAR_LENGTH))
	_tween.tween_property(target, ^"position", HAND_STRIKE + Vector2(reach, 0), strike_time).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_recover(target)


## Удар згори (булава, важкий удар): зброя з-над голови донизу перед собою, кулак — у кадрі Heavy/2.
func _smash(target: Node2D, big: bool) -> void:
	target.position = HAND_OVERHEAD
	target.rotation_degrees = smash_from
	_tween.tween_interval(windup_time)
	_tween.tween_callback(_spawn_smear.bind(&"arc", false, 1.4 if big else 1.0))
	_tween.tween_property(target, ^"position", HAND_LOW, strike_time).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(target, ^"rotation_degrees", smash_to, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_interval(hold_time * 2.0)
	_recover(target)


func _recover(target: Node2D) -> void:
	_tween.tween_property(target, ^"position", OFF_REST if target == off_pivot else HAND_REST, recover_time)
	_tween.parallel().tween_property(target, ^"rotation_degrees", _rest_angle(), recover_time)


## Шлейф — дитина героя (не WeaponMount: той схований з голими руками), за поглядом героя.
## [param size] — для дуги множник до довжини зброї, для уколу — масштаб смуги, для кулака — множник пікселя героя.
func _spawn_smear(kind: StringName, upward: bool, size: float) -> void:
	var trail: Node2D = SLASH_TRAIL_SCENE.instantiate()
	player.add_child(trail)
	var at := _smear_at(kind, upward)
	var scale_by := _smear_scale(kind, size, 0.0 if kind == &"punch" else _reach())  # голі руки — спрайта зброї немає
	trail.position = position + Vector2(at.x * scale.x, at.y)  # від малюнка героя (WeaponMount стоїть, де він)
	trail.scale = Vector2(scale_by * scale.x, scale_by)
	trail.play(kind, upward and kind == &"arc")


## Точка шлейфа [param kind] від центру героя, обличчям праворуч.
func _smear_at(kind: StringName, upward: bool) -> Vector2:
	match kind:
		&"arc":
			return SMEAR_CENTER
		&"thrust":
			return HAND_STRIKE
	return PUNCH_AT - Vector2(0, HOOK_LIFT if upward else 0.0)


## Масштаб шлейфа [param kind] (див. _spawn_smear); [param length] — довжина зброї, px світу.
func _smear_scale(kind: StringName, size: float, length: float) -> float:
	match kind:
		&"arc":
			return length / SMEAR_RADIUS * size * SMEAR_SCALE
		&"thrust":
			return size
	return 1.5 * size * SMEAR_SCALE  # піксель героя


## Що намальовано звичайним ударом зброї [param item] ({} — голі руки): непрозорі межі шлейфа, px від центру героя
## обличчям праворуч (B128). Хітбокс удару (PlayerCombat) — від центру героя до краю цього шлейфа, на його висоту.
## Висота — від малюнка героя: WeaponMount стоїть там, де Sprite2D (ноги на низу колізії).
func drawn_swing_rect(item: Dictionary) -> Rect2:
	var kind := &"punch"
	var size := 1.0
	var length := 0.0
	if not item.is_empty():
		length = load(TEXTURE % ItemDatabase.base_id(item.id)).get_height() * sprite.scale.y
		kind = &"thrust" if String(item.category) in THRUST else &"arc"
		if kind == &"thrust":
			size = (length + thrust_reach) / SMEAR_LENGTH  # як _stab без фінішера
	var scale_by := _smear_scale(kind, size, length)
	var frames := _trail_rect(kind)
	return Rect2(position + _smear_at(kind, false) + frames.position * scale_by, frames.size * scale_by)


## Непрозорі межі кадрів шлейфа [param kind] у px SlashTrail (до масштабу), як їх ставить SlashTrail.play.
static func _trail_rect(kind: StringName) -> Rect2:
	if _trail_rects.has(kind):
		return _trail_rects[kind]
	var trail: Node2D = SLASH_TRAIL_SCENE.instantiate()
	var frames: SpriteFrames = trail.get_node(^"Sprite").sprite_frames
	trail.free()
	var out := Rect2()
	for i in frames.get_frame_count(kind):
		var image: Image = frames.get_frame_texture(kind, i).get_image()
		var used := Rect2(image.get_used_rect())
		used.position += Vector2(0, -image.get_height() / 2.0) if kind == &"thrust" else -Vector2(image.get_size()) / 2.0
		out = used if i == 0 else out.merge(used)
	_trail_rects[kind] = out
	return out


static var _trail_rects: Dictionary = {}


## Довжина зброї в руці, px світу (спрайт ×1.5 — як герой).
func _reach() -> float:
	return sprite.texture.get_height() * sprite.scale.y
