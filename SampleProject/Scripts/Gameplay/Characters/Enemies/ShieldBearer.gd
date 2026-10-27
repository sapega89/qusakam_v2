extends DefaultEnemy

## Щитоносець (D495, D560): бандит зі щитом. Щит тримає перед собою — удар спереду щит приймає (без шкоди й без
## втрати стійкості, іскри й дзвін); удар у спину (після перекату крізь нього, D443) б'є як звичайно. Важкий удар
## героя (VFXHooks.hit_strength 2: важкий, рипост, заряджена стріла) спереду розбиває щит: щит відлітає, бандит
## стоїть у позі збою guard_break_stagger с (кадри stagger.png бандита) і далі б'ється без щита.
## Сцена — enemy_shield.tscn; щит — вузол Sprite2D/Shield (тимчасовий, доки немає аркуша щитоносця).

const SHIELD_FLY_TIME := 0.6
const SHIELD_FLY := Vector2(46.0, -40.0)

@onready var shield: Node2D = $Sprite2D/Shield

var shield_up := true
## Удар щойно прийняв щит: стійкість за нього не знімається (PlayerCombat._hit_effects іде одразу після take_damage).
var _blocked_hit := false


## Удар спереду — у щит; важкий — розбиває щит. Без джерела (підпал) — повз щит.
func take_damage(amount: int, source: Node = null, critical: bool = false) -> void:
	_blocked_hit = shield_up and _from_front(source)
	if not _blocked_hit:
		super.take_damage(amount, source, critical)
		return
	if VFXHooks.hit_strength(source) >= 2:
		break_shield(source.global_position.x)
	else:
		EventBus.enemy_shield_blocked.emit(self, shield.global_position)


func take_poise(amount: float, from_x: float, source: StringName = &"light") -> void:
	if _blocked_hit:
		_blocked_hit = false
		return
	super.take_poise(amount, from_x, source)


func _from_front(source: Node) -> bool:
	var facing := enemy_logic.last_direction
	return source is Node2D and facing != 0 and signf(source.global_position.x - global_position.x) == facing


## Щит розбито: відлітає від героя ([param from_x]) і гасне, бандит у збої (D560).
func break_shield(from_x: float) -> void:
	shield_up = false
	EventBus.enemy_shield_broken.emit(self, shield.global_position)
	var away := signf(global_position.x - from_x)
	var start := shield.global_position
	shield.reparent(get_parent())
	shield.global_position = start
	var fly := shield.create_tween().set_parallel()
	fly.tween_property(shield, ^"position", shield.position + Vector2(SHIELD_FLY.x * away, SHIELD_FLY.y), SHIELD_FLY_TIME * 0.4).set_ease(Tween.EASE_OUT)
	fly.tween_property(shield, ^"position:y", shield.position.y + SHIELD_FLY.y * -0.5, SHIELD_FLY_TIME * 0.6).set_delay(SHIELD_FLY_TIME * 0.4).set_ease(Tween.EASE_IN)
	fly.tween_property(shield, ^"rotation", TAU * 0.75 * away, SHIELD_FLY_TIME)
	fly.tween_property(shield, ^"modulate:a", 0.0, SHIELD_FLY_TIME * 0.5).set_delay(SHIELD_FLY_TIME * 0.5)
	fly.chain().tween_callback(shield.queue_free)
	stagger(EnemyVariety.shield().guard_break_stagger, from_x)


## Щит — перед бандитом, за поглядом (кадри дзеркалить flip_h, щит — scale.x).
func _face_shapes(direction: int) -> void:
	super._face_shapes(direction)
	if direction != 0 and shield_up:
		shield.scale.x = absf(shield.scale.x) * direction
