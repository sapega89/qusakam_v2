extends "res://SampleProject/Scripts/Gameplay/Characters/Enemies/ShieldBearer.gd"

## Вартовий з баштовим щитом (D652, D693): великий щитоносець, еліта за видом (D681). Поведінка щитоносця: удар
## спереду — у щит, у спину — по тілу. Щит намальовано в кадрах; важкий удар спереду розбиває його (D843, B200):
## щит розлітається скалками (ShieldBreak.tscn), вартовий у збої guard_break_stagger с на кадрі hurt і далі б'ється
## аркушем без щита (noshield_sheet) — щит більше не повертається. Вузол Sprite2D/Shield — точка щита в кадрах
## (іскри блоку), за поглядом. Сцена — enemy_tower_shield_guard.tscn.

const HitAreas = preload("res://SampleProject/Scripts/Combat/HitAreas.gd")
const SHIELD_BREAK_SCENE := preload("res://SampleProject/Scenes/FX/ShieldBreak.tscn")

## Той самий аркуш без щита (shield_tower/sheet_noshield.png, ті самі кадри). Ставить корінь: анімації вартового
## ключують лише Sprite2D:frame, тож текстуру ніщо не скидає.
@export var noshield_sheet: Texture2D


## Щит розбито назавжди (D843): аркуш без щита, зони з нового малюнка, скалки, збій.
func break_shield(from_x: float) -> void:
	shield_up = false
	EventBus.enemy_shield_broken.emit(self, shield.global_position)
	var still := enemy_view.rest_sprite()
	_drop_shield(still)
	_burst(still)
	still.free()
	stagger(EnemyVariety.shield().guard_break_stagger, from_x)


## Аркуш без щита; тіло, зона-ціль і хітбокс — з нового малюнка (B128), як їх міряє verify_hit_areas, на спрайті
## в спокої [param still]. Удар без щита сягає менше — на стільки ж ближче вартовий його й починає (attack_range).
func _drop_shield(still: Sprite2D) -> void:
	var reach := HitAreas.strike_rect(still, anim_player, attack_active_time).end.x
	enemy_view.swap_sheet(noshield_sheet)
	still.texture = noshield_sheet
	var body := HitAreas.body_rect(still, anim_player)
	var strike := HitAreas.strike_rect(still, anim_player, attack_active_time)
	_fit(hurt_collision, body)
	_fit(hitbox_collision, Rect2(0.0, strike.position.y, strike.end.x, strike.size.y))
	(body_collision.shape as RectangleShape2D).size.x = body.end.x * 2.0  # переднім краєм — сам вартовий
	_hurt_x = hurt_collision.position.x
	_strike_x = hitbox_collision.position.x
	attack_range -= reach - strike.end.x
	enemy_logic.attack_range = attack_range
	_face_shapes(enemy_logic.last_direction)


## Скалки щита: кадри — клітинка аркуша вартового (центр щита в (48, 40)), тож стоять там, де спрайт у спокої
## [param still] (масштаб сцени й еліти), за поглядом; лишаються на місці, коли вартовий рушить.
func _burst(still: Sprite2D) -> void:
	var burst: AnimatedSprite2D = SHIELD_BREAK_SCENE.instantiate()
	burst.animation_finished.connect(burst.queue_free)
	get_parent().add_child(burst)
	burst.global_transform = global_transform * Transform2D(0.0, still.scale, 0.0, still.position)
	burst.offset = still.offset
	burst.flip_h = sprite.flip_h
	burst.play()


## Форма [param shape] — прямокутник [param rect] у координатах вартового, обличчям праворуч.
func _fit(shape: CollisionShape2D, rect: Rect2) -> void:
	(shape.shape as RectangleShape2D).size = rect.size
	shape.position = rect.get_center() - (shape.get_parent() as Node2D).position


## Точка щита — перед вартовим, за поглядом (кадри дзеркалить flip_h).
func _face_shapes(direction: int) -> void:
	super._face_shapes(direction)
	if direction != 0:
		shield.position.x = absf(shield.position.x) * direction
