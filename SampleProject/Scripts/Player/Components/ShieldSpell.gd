extends Node2D

## Щит-закляття над позою Block (H2, S19: «щит — закляття блоку, не спорядження»; Sapega 2026-10-27). Малюнок —
## `Assets/FX/Shield/` поверх наявного Block/1, без нових кадрів героя; розкладка (Magic 32×96, Glass 64×64, ×1.5, перед
## героєм) — ShieldSpell.tscn за Assets/FX/README.md, погляд ліворуч — дзеркало всього вузла (scale.x = −1).
## Магічний (Shield Block): падає з неба, поки блок тримають — мерехтить, відпущено — гасне. Скляний: з'являється,
## тріскає від прийнятих ударів (Player.take_damage → take_blow), на GLASS_HITS-му, від удару, що пробив блок, чи від блоку
## без витривалості (D776) — розбивається, і уламки б'ють того, хто вдарив: SHARD_SHARE удару, що розбив.

## Скільки прийнятих ударів витримує скляний щит: дві тріщини (crack_1, crack_2), третій розбиває.
const GLASS_HITS := 3
## Уламки повертають нападникові цю частку удару, що розбив щит (дзеркало WEAK_BLOCK_DAMAGE, D776).
const SHARD_SHARE := 0.5

@onready var _player: CharacterBody2D = get_parent()
@onready var _magic: AnimatedSprite2D = $Magic
@onready var _glass: AnimatedSprite2D = $Glass

## Закляття піднятого блоку: &"magic", &"glass" або &"" (навички немає — голий блок).
var spell: StringName = &""
var _raised := false
var _cracks := 0
var _shattered := false


func _ready() -> void:
	_magic.animation_finished.connect(_on_magic_finished)
	_glass.animation_finished.connect(_on_glass_finished)
	_magic.hide()
	_glass.hide()


func _process(_delta: float) -> void:
	var blocking: bool = _player.combat.is_blocking() or ServiceLocator.get_skill_manager().stances.shows_shield()
	if blocking and not _raised:
		raise(_pick_spell())
	elif _raised and not blocking:
		lower()
	scale.x = _player.last_direction


## Яке закляття дає блок: Shield Block — магічний щит (H2); без неї щита немає.
func _pick_spell() -> StringName:
	if uses_glass_shield():
		return &"glass"
	if ServiceLocator.get_skill_manager().stances.shows_shield():
		return &"magic"  # Counter Stance, Aegis (D876) — магічний щит і без Shield Block
	return &"magic" if ServiceLocator.get_skill_manager().is_unlocked("shield_block") else &""


## Скляний щит (H2): жодна навичка skills.json його ще не дає — skills_audit (S19) називає «скляний блок» другим видом
## щита, але не навичкою. Відкрите питання до Sapega (звіт wire-art); доти скляний не піднімається сам.
func uses_glass_shield() -> bool:
	return false


## Підняти щит [param kind] (&"" — нічого): магічний падає з неба, скляний з'являється.
func raise(kind: StringName) -> void:
	_raised = true
	spell = kind
	_cracks = 0
	_shattered = false
	_magic.visible = kind == &"magic"
	_glass.visible = kind == &"glass"
	if kind == &"magic":
		_magic.play(&"drop")
	elif kind == &"glass":
		_glass.play(&"appear")


## Блок відпущено: магічний гасне, цілий скляний зникає (appear назад), розбитий долітає уламками.
func lower() -> void:
	_raised = false
	if spell == &"magic":
		_magic.play(&"fade")
	elif spell == &"glass" and not _shattered:
		_glass.play_backwards(&"appear")


## Прийнятий блоком удар [param damage] від [param attacker] (Player.take_damage). [param breaks] — удар пробив блок
## (GUARD_BREAK) або блок без витривалості: скляний розбивається одразу.
func take_blow(attacker: Node, damage: int, breaks: bool) -> void:
	if spell != &"glass" or _shattered:
		return
	_cracks += 1
	if breaks or _cracks >= GLASS_HITS:
		_shatter(attacker, damage)
	else:
		_glass.play(StringName("crack_%d" % _cracks))


## Скляний щит розбито: уламки летять уперед і ранять ворога, що вдарив (стріла лучника — без нападника поруч).
func _shatter(attacker: Node, damage: int) -> void:
	_shattered = true
	_glass.play(&"shatter")
	if attacker is DefaultEnemy and attacker.is_alive():
		attacker.take_damage(shard_damage(damage), _player)


func shard_damage(blow: int) -> int:
	return maxi(1, roundi(blow * SHARD_SHARE))


func is_shattered() -> bool:
	return _shattered


func _on_magic_finished() -> void:
	if _magic.animation == &"drop":
		_magic.play(&"hold")
	elif _magic.animation == &"fade":
		_magic.hide()


func _on_glass_finished() -> void:
	if _glass.animation == &"appear" and _raised:
		_glass.play(&"hold")
	elif _glass.animation in [&"appear", &"shatter"]:
		_glass.hide()
