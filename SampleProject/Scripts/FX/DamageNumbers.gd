extends Node

## Цифри урону (D66; Sapega 2026-10-22 «цифри урону по мені і ворогу»). Одне місце, де урон приземлився:
## EventBus.damage_received (CombatBody2D.register_damage) — цифра над героєм або ворогом; EventBus.player_evaded —
## слово «Evade» над героєм (D393). Герой — UITokens.DAMAGE_NUMBER_HERO, ворог — DAMAGE_NUMBER_ENEMY, крит — більший
## DAMAGE_NUMBER_CRIT. Settings → Game → Damage Numbers (settings.damage_numbers) вимикає все. Створює GameManager.

const DAMAGE_NUMBER_SCENE := preload("res://SampleProject/Scenes/FX/DamageNumber.tscn")

## Номер наступного зсуву з UITokens.DAMAGE_NUMBER_SPREAD.
var _spread: int = 0


func _ready() -> void:
	# GameManager — autoload раніше за EventBus (як VFXHooks)
	call_deferred(&"_connect_to_event_bus")


func _connect_to_event_bus() -> void:
	EventBus.damage_received.connect(_on_damage_received)
	EventBus.player_evaded.connect(_on_player_evaded)


func _on_damage_received(target: Node, _source: Node, amount: int, critical: bool) -> void:
	var hero: bool = target.is_in_group(GameGroups.PLAYER)
	if not hero and not target.is_in_group(GameGroups.ENEMIES):
		return
	var color: Color = UITokens.DAMAGE_NUMBER_HERO if hero else (UITokens.DAMAGE_NUMBER_CRIT if critical else UITokens.DAMAGE_NUMBER_ENEMY)
	spawn(target, str(amount), color, UITokens.DAMAGE_NUMBER_CRIT_SIZE if critical else UITokens.DAMAGE_NUMBER_SIZE, critical)


func _on_player_evaded(_attacker: Node) -> void:
	spawn(GameGroups.get_player(), tr("Evade"), UITokens.DAMAGE_NUMBER_EVADED, UITokens.DAMAGE_NUMBER_WORD_SIZE, false)


## Цифра над верхом тіла [param target] (його CollisionShape2D), у кімнаті, а не в тілі: тіло йде далі, цифра — ні.
## null — налаштування вимкнено.
func spawn(target: Node2D, text: String, color: Color, font_size: int, critical: bool) -> Node2D:
	if not SaveSystem.settings_module.settings.damage_numbers:
		return null
	var body: CollisionShape2D = target.get_node(^"CollisionShape2D")
	var top: float = body.global_position.y - body.shape.get_rect().size.y * absf(target.global_scale.y) / 2.0
	top += (target.get_node(^"Sprite2D") as Node2D).position.y * absf(target.global_scale.y)  # малюнок піднято над колізією (hero-feet)
	var number: Node2D = DAMAGE_NUMBER_SCENE.instantiate()
	target.get_parent().add_child(number)
	number.global_position = Vector2(body.global_position.x + UITokens.DAMAGE_NUMBER_SPREAD[_spread], top - UITokens.DAMAGE_NUMBER_GAP)
	_spread = (_spread + 1) % UITokens.DAMAGE_NUMBER_SPREAD.size()
	number.pop(text, color, font_size, critical)
	return number
