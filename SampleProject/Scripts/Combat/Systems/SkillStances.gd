extends Node

## Стійки й баффи героя (skills v2 зріз 5, D876): Counter Stance, Mirror Stance, Centered Breath, Battle Cry, Aegis,
## Blood Price, Rally. Дитина SkillManager: він кличе begin() з cast_skill і use() з use_skill; герой питає answer_blow()
## і soak() у Player.take_damage, а hit_factor() — у PlayerCombat.hit_damage; асист — rally() у CompanionManager._send.
## Числа — skills.json → buff (SkillDefinition), сила росте з рангом, Wisdom і синергіями, як лікування (час — ні).
## Кожен бафф, що триває, показує значок своєї навички в рядку стану героя (HUD, status_row) — сигнал changed.

## Бафф [param skill_id] увімкнено / вимкнено (HUD: значок навички в рядку стану героя).
signal changed(skill_id: String, on: bool)
## Counter Stance відповіла ворогові [param attacker] (для звуку й тестів).
signal countered(skill_id: String, attacker: Node)

## Відповідь Counter Stance: поза удару героя, с.
const COUNTER_POSE := &"HeavyStrike"
const COUNTER_TIME := 0.3

var manager: SkillManager

## Стійка, що зараз іде (id навички, "" — немає), і скільки їй лишилось, с.
var _stance: SkillDefinition
var _stance_left := 0.0
## Battle Cry: бонус до сили ударів і скільки йому лишилось, с.
var _attack_bonus := 0.0
var _attack_left := 0.0
## Aegis: скільки шкоди ще поглине бар'єр і скільки йому лишилось, с.
var _absorb_left := 0
var _aegis_left := 0.0
## Blood Price: скільки влучань ще посилено і на скільки.
var _blood_hits := 0
var _blood_bonus := 0.0
## Rally: наступний асист — [шкода, тривалість] понад звичайні; порожньо — Rally немає.
var _rally: Array[float] = []


func _init(owner_manager: SkillManager) -> void:
	manager = owner_manager


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.player_respawned.connect(clear)


## Перевірки перед кастом (SkillManager.cast_skill): Rally — лише з компаньйоном у загоні; Centered Breath — лише в бою;
## Blood Price — якщо після ціни лишиться HP. Далі звичайний каст героя.
func begin(definition: SkillDefinition) -> SkillManager.Result:
	var hero: Node = manager._default_source()
	match definition.buff_kind:
		"rally":
			if ServiceLocator.get_companion_manager().get_next_in_queue() == "":
				return manager._fail(definition.id, SkillManager.Result.NO_TARGET)
		"breath":
			if not hero.combat.in_combat():
				return manager._fail(definition.id, SkillManager.Result.NO_TARGET)
		"blood_price":
			if hero.current_health <= hp_price(definition, hero):
				return manager._fail(definition.id, SkillManager.Result.EFFECT_FAILED)
	if not hero.combat.begin_cast(definition):
		return manager._fail(definition.id, SkillManager.Result.BUSY)
	return SkillManager.Result.OK


## Вивільнення касту (SkillManager.use_skill): стійка починається, бафф вмикається, SP списано.
func use(definition: SkillDefinition, hero: Node) -> SkillManager.Result:
	var factor: float = manager._skill_factor(definition.id, -1)
	match definition.buff_kind:
		"counter", "mirror":
			_stance = definition
			_stance_left = definition.buff_time
			changed.emit(definition.id, true)
		"breath":
			manager.combat_executor.heal(definition, hero, manager.skill_heal(definition.id))
			manager.restore_sp(roundi(definition.sp_restore * factor))
		"battle_cry":
			_attack_bonus = definition.attack_bonus * factor
			_attack_left = definition.buff_time
			_flinch(definition, hero)
			changed.emit(definition.id, true)
		"aegis":
			_absorb_left = roundi(manager._scaled_power(definition.absorb, 0.0, definition.absorb_elem) * factor)
			_aegis_left = definition.buff_time
			changed.emit(definition.id, true)
		"blood_price":
			if hero.current_health <= hp_price(definition, hero):
				return manager._fail(definition.id, SkillManager.Result.EFFECT_FAILED)
			_pay_hp(hero, hp_price(definition, hero))
			_blood_hits = definition.buff_hits
			_blood_bonus = definition.hit_bonus * factor
			changed.emit(definition.id, true)
		"rally":
			_rally = [definition.assist_damage * factor, definition.assist_duration]
			changed.emit(definition.id, true)
		_:
			assert(false, "SkillStances: unknown buff kind %s on %s" % [definition.buff_kind, definition.id])
	return manager._buff_used(definition)


## Ціна Blood Price у HP: частка Max HP, щонайменше 1.
func hp_price(definition: SkillDefinition, hero: Node) -> int:
	return maxi(1, roundi(hero.Max_Health * definition.hp_cost))


func _process(delta: float) -> void:
	if _stance != null:
		_stance_left -= delta
		# Стійка — це вивільнення касту: збій (червоний удар) чи кінець пози — і її немає
		if _stance_left <= 0.0 or manager._default_source().combat.state != PlayerCombat.State.CAST_RELEASE:
			_end_stance()
	if _attack_left > 0.0:
		_attack_left -= delta
		if _attack_left <= 0.0:
			_attack_bonus = 0.0
			changed.emit("battle_cry", false)
	if _aegis_left > 0.0:
		_aegis_left -= delta
		if _aegis_left <= 0.0:
			_end_aegis()


# ── Удари по героєві (Player.take_damage) ───────────────────────────────────

## Стійка відповідає на удар [param source]: true — удар не влучив. Counter Stance: перший удар ворога з будь-якого боку
## заблоковано й відповідено шкодою навички, стрілу заблоковано; Mirror Stance: стріла летить назад. Червоний удар
## (TELL_DODGE) влучає й ламає стійку; куля боса (B133) і пастки стійкою не відбиваються.
func answer_blow(source: Node) -> bool:
	if _stance == null or not (source is DefaultEnemy or source is Arrow):
		return false
	var tell: StringName = source.tell if source is Arrow else source.incoming_tell()
	if tell == EnemyLogic.TELL_DODGE:
		return false
	var hero: Node = manager._default_source()
	if _stance.buff_kind == "mirror":
		if not source is Arrow:
			return false
		source.damage = roundi(source.damage * _stance.reflect_ratio * manager._skill_factor(_stance.id, -1))
		source.parried(hero)
		EventBus.player_blocked.emit(source)
		return true
	EventBus.player_blocked.emit(source)
	if source is Arrow:
		return true  # стрілу заблоковано, стійка чекає удару
	var counter := _stance
	manager._skill_effect_running = true  # удар навички SP не дає
	manager.combat_executor.execute(counter, hero, source, manager.skill_damage(counter.id))
	manager._skill_effect_running = false
	_end_stance()
	hero.combat.answer_stance(COUNTER_POSE, COUNTER_TIME)
	countered.emit(counter.id, source)
	return true


## Aegis поглинає [param dealt] (уже після захисту): повертає, що пройшло крізь бар'єр. Порожній — бар'єра немає.
func soak(dealt: int) -> int:
	if _absorb_left <= 0:
		return dealt
	var soaked := mini(dealt, _absorb_left)
	_absorb_left -= soaked
	if _absorb_left <= 0:
		_end_aegis()
	return dealt - soaked


# ── Удари героя ─────────────────────────────────────────────────────────────

## Множник сили удару героя (PlayerCombat.hit_damage): Battle Cry і заряди Blood Price.
func hit_factor() -> float:
	return (1.0 + _attack_bonus) * (1.0 + (_blood_bonus if _blood_hits > 0 else 0.0))


## Влучання героя чи його стріли у ворога витрачає заряд Blood Price; удари навичок — ні.
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if _blood_hits <= 0 or manager.is_skill_hitting():
		return
	if (source.is_in_group(GameGroups.PLAYER) or source.is_in_group(VFXHooks.HERO_ARROWS)) and target.is_in_group(GameGroups.ENEMIES):
		_blood_hits -= 1
		if _blood_hits == 0:
			_blood_bonus = 0.0
			changed.emit("blood_price", false)


# ── Компаньйони ─────────────────────────────────────────────────────────────

## Rally: асист [param actor] (CompanionAssist, ще не вийшов) б'є сильніше, оглушує й стоїть довше. Rally витрачено.
func rally(actor: Node) -> void:
	if _rally.is_empty():
		return
	actor.damage = roundi(actor.damage * (1.0 + _rally[0]))
	actor.stun *= 1.0 + _rally[1]
	actor.hold_time *= 1.0 + _rally[1]
	_rally.clear()
	changed.emit("rally", false)


# ── Стан ────────────────────────────────────────────────────────────────────

func stance() -> String:
	return "" if _stance == null else _stance.id


func is_on(skill_id: String) -> bool:
	match skill_id:
		"battle_cry":
			return _attack_left > 0.0
		"aegis":
			return _absorb_left > 0
		"blood_price":
			return _blood_hits > 0
		"rally":
			return not _rally.is_empty()
	return stance() == skill_id


func absorb_left() -> int:
	return _absorb_left


func blood_hits() -> int:
	return _blood_hits


## Щит-закляття (ShieldSpell) стоїть над героєм: Counter Stance (блок) і бар'єр Aegis.
func shows_shield() -> bool:
	return (_stance != null and _stance.buff_kind == "counter") or _absorb_left > 0


## Смерть і новий забіг (player_respawned): жоден бафф не переходить.
func clear() -> void:
	for skill_id: String in ["counter_stance", "mirror_stance", "battle_cry", "aegis", "blood_price", "rally"]:
		if is_on(skill_id):
			changed.emit(skill_id, false)
	_stance = null
	_stance_left = 0.0
	_attack_bonus = 0.0
	_attack_left = 0.0
	_absorb_left = 0
	_aegis_left = 0.0
	_blood_hits = 0
	_blood_bonus = 0.0
	_rally.clear()


func _end_stance() -> void:
	var skill_id := _stance.id
	_stance = null
	_stance_left = 0.0
	changed.emit(skill_id, false)


func _end_aegis() -> void:
	_absorb_left = 0
	_aegis_left = 0.0
	changed.emit("aegis", false)


## Battle Cry: звичайні вороги (не еліта, не бос) у flinch_radius px від героя здригаються — короткий збій.
func _flinch(definition: SkillDefinition, hero: Node) -> void:
	for enemy: Node in SkillTargeting.enemies_around(hero, definition.flinch_radius):
		if not enemy.elite and not enemy.is_in_group(GameGroups.BOSS):
			enemy.stagger(definition.flinch_time, hero.global_position.x)


## Blood Price: HP героя зменшується на [param amount] — без удару, збою й невразливості.
func _pay_hp(hero: Node, amount: int) -> void:
	hero.current_health -= amount
	hero.health_changed.emit(hero.current_health, hero.Max_Health, true)
	EventBus.player_health_changed.emit(hero.current_health, hero.Max_Health)
