extends Node

## Три приховані нахили героя до шляхів (D725, oath_affinity_plan): Самаль (захисник), контракт (ціна), без бога
## (танцюрист). Числа лежать у player_state.leanings (зберігаються з грою), гравцеві їх не видно — лише яскравість
## гербів у Журналі. Годують їх стиль бою (події, які бій уже шле) і кілька вчинків першого акту (вибір у розмові:
## `signal|leaning|<шлях>` у .dqd). Бій додає потроху і не більше FIGHT_CAP на шлях — один прийом не вирішує все.
## Перепис біля брами (CensusScribe) радить шлях за цими числами разом із відповідями писареві.

## Шляхи в порядку показу; клятва кожного (skills.json → oaths).
const PATHS: Array[String] = ["samal", "contract", "none"]
const OATH_OF := {"samal": "paladin", "contract": "dark_knight", "none": "warden"}

## Очки за подію бою. Числа тимчасові (D725: «вчинки і стиль бою»), Sapega бачить їх у звіті oath-census.
const PARRY := 2.0
const BLOCK := 1.0
## Удар, завданий, коли в героя менше третини здоров'я.
const LOW_HP_HIT := 1.0
const LOW_HP_SHARE := 1.0 / 3.0
## Розмін: герой ударив і дістав удар (чи навпаки) у межах TRADE_WINDOW с.
const TRADE := 1.0
const TRADE_WINDOW := 0.6
## Перекат крізь замах ворога; той самий ворог рахується знову не раніше, ніж за DODGE_REPEAT с (хітбокс б'є кадрами).
const DODGE := 1.0
const DODGE_REPEAT := 0.5
## Бій виграно, жодного разу не діставши.
const UNTOUCHED := 3.0
## Найбільше, що один бій додає одному шляху.
const FIGHT_CAP := 5.0
## Вчинок (вибір у розмові).
const DEED := 3.0
## У пораді писаря найсильніший нахил важить стільки, решта — пропорційно (shares); відповіді — CensusScribe.ANSWER.
const ADVICE_WEIGHT := 6.0

var _state_source: Callable
var _fight: Dictionary = {}
var _in_fight := false
var _hit_taken := false
var _kills := 0
var _last_taken := -INF
var _last_dealt := -INF
var _dodged: Dictionary = {}


## [param state_source] повертає живий player_state (SkillManager._state).
func _init(state_source: Callable) -> void:
	_state_source = state_source
	name = "OathLeanings"


func _ready() -> void:
	EventBus.combat_state_changed.connect(_on_combat_state_changed)
	EventBus.player_parried.connect(func(_attacker: Node) -> void: _score("samal", PARRY))
	EventBus.player_blocked.connect(func(_attacker: Node) -> void: _score("samal", BLOCK))
	EventBus.player_dodged_through.connect(_on_dodged_through)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.damage_received.connect(_on_damage_received)
	EventBus.enemy_died.connect(func(_id: String, _at: Vector2) -> void:
		if _in_fight:
			_kills += 1)
	# Менеджери постають у _ready GameManager — раніше, ніж автолоад DialogueQuest; тести компілюють скрипт до автолоадів.
	(func() -> void: _dq().Signals.dialogue_signal.connect(_on_dialogue_signal)).call_deferred()


## Нахили зараз: шлях → очки.
func values() -> Dictionary:
	var stored: Dictionary = _state_source.call().get("leanings", {})
	var out := {}
	for path in PATHS:
		out[path] = float(stored.get(path, 0.0))
	return out


## Частка кожного шляху від найсильнішого, 0..1 (яскравість гербів). Усі нулі — усі 0.
func shares() -> Dictionary:
	var now := values()
	var top: float = now.values().max()
	var out := {}
	for path in PATHS:
		out[path] = now[path] / top if top > 0.0 else 0.0
	return out


## Порада писаря: нахили (частки × ADVICE_WEIGHT) плюс [param extra] (відповіді писареві); нічия — за порядком PATHS.
func strongest(extra: Dictionary = {}) -> String:
	var share := shares()
	var score := func(path: String) -> float: return share[path] * ADVICE_WEIGHT + float(extra.get(path, 0.0))
	var best := PATHS[0]
	for path in PATHS:
		if score.call(path) > score.call(best):
			best = path
	return best


func add(path: String, amount: float) -> void:
	assert(path in PATHS, "OathLeanings: unknown path %s" % path)
	var state: Dictionary = _state_source.call()
	var stored: Dictionary = state.get("leanings", {})
	var now := values()
	now[path] += amount
	stored.merge(now, true)
	state["leanings"] = stored
	EventBus.leanings_changed.emit()


func _score(path: String, amount: float) -> void:
	if _in_fight:
		_fight[path] = float(_fight.get(path, 0.0)) + amount


func _on_combat_state_changed(in_combat: bool) -> void:
	if in_combat:
		_in_fight = true
		_fight = {}
		_hit_taken = false
		_kills = 0
		_dodged = {}
		return
	if not _in_fight:
		return
	_in_fight = false
	var hero := get_tree().get_first_node_in_group(GameGroups.PLAYER)
	if hero == null or hero.is_dead:
		return  # поразка нічого не дає
	if _kills > 0 and not _hit_taken:
		_fight["none"] = float(_fight.get("none", 0.0)) + UNTOUCHED
	for path: String in _fight:
		add(path, minf(FIGHT_CAP, _fight[path]))
	_fight = {}


func _on_dodged_through(attacker: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var id := attacker.get_instance_id()
	if now - float(_dodged.get(id, -INF)) < DODGE_REPEAT:
		return
	_dodged[id] = now
	_score("none", DODGE)


func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if not (source.is_in_group(GameGroups.PLAYER) or source.is_in_group(VFXHooks.HERO_ARROWS)) \
			or not target.is_in_group(GameGroups.ENEMIES):
		return
	var now := Time.get_ticks_msec() / 1000.0
	_last_dealt = now
	var hero := get_tree().get_first_node_in_group(GameGroups.PLAYER)
	if hero.current_health <= hero.Max_Health * LOW_HP_SHARE:
		_score("contract", LOW_HP_HIT)
	if now - _last_taken <= TRADE_WINDOW:
		_score("contract", TRADE)


func _on_damage_received(target: Node, source: Node, _amount: int, _critical: bool) -> void:
	if not target.is_in_group(GameGroups.PLAYER):
		return
	_hit_taken = _hit_taken or _in_fight
	if source == null:
		return  # пастка чи падіння — не розмін
	var now := Time.get_ticks_msec() / 1000.0
	_last_taken = now
	if now - _last_dealt <= TRADE_WINDOW:
		_score("contract", TRADE)


## Вчинок у розмові: `signal|leaning|samal` (contract / none).
func _on_dialogue_signal(params: Array) -> void:
	if params.size() == 2 and String(params[0]) == "leaning":
		add(String(params[1]), DEED)


func _dq() -> Node:
	return get_node(^"/root/DialogueQuest")
