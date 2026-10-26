extends Node2D

## 🏠 Дім діда (ElderHouse): тут Кусакам після бою в селі знаходить діда (D438, Sapega 2026-10-26: «дід мав бути в
## своєму домі і там мав відбутись діалог Кусакама»). Розмова — OldMan_Outside → OldMan_Healing → OldMan_Decision,
## прапорці ті самі, що були в Village (village_oldman_met → _healed → _complete), тож старі сейви йдуть далі.
## States: BEFORE_FIGHT, OLD_MAN_WAITING, OLD_MAN_HEALING, OLD_MAN_DECISION, DONE
## D252/D261: дід лікує Кусакама, але сам лікування не просить — Длань вивчається на 2-му рівні.
## Follows Robust State-Flow Pattern (як Village.gd)

enum State {
	BEFORE_FIGHT,
	OLD_MAN_WAITING,
	OLD_MAN_HEALING,
	OLD_MAN_DECISION,
	DONE
}

const OLDMAN_GIFT := "oldman_gift"
## D437: дідове лікування видно, а не розказано — те саме світло, що й у Healing Palm (D271).
const HEALING_LIGHT := preload("res://SampleProject/Scenes/FX/Skills/HealingPalm.tscn")

@export var current_state: State = State.BEFORE_FIGHT:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

func _ready() -> void:
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	# Лише присвоєння: сеттер сам запускає стан (див. Village._ready).
	_determine_initial_state()

## Поки бій на вулиці не виграно, дід просто тут; далі — чекає героя біля себе (тригер), а пройдене не повторюється.
func _determine_initial_state() -> void:
	var game = Game.get_singleton()
	if game.get_quest_flag("village_oldman_complete"):
		current_state = State.DONE
	elif game.get_quest_flag("village_oldman_healed"):
		current_state = State.OLD_MAN_DECISION
	elif game.get_quest_flag("village_fight_complete"):
		current_state = State.OLD_MAN_WAITING
	else:
		current_state = State.BEFORE_FIGHT
	DebugLogger.info("🏠 ElderHouse: Initial state determined as %s" % State.keys()[current_state], "ElderHouse")

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🏠 ElderHouse: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	EventBus.scene_state_changed.emit("ElderHouse", "", State.keys()[new_state])
	_apply_state_logic(new_state, run_id)

func get_current_state_name() -> String:
	"""Повертає назву поточного стейту для тригерів"""
	return State.keys()[current_state]

func change_state_by_name(state_name: String) -> void:
	"""Змінює стейт за назвою (викликається тригерами)"""
	for i in range(State.size()):
		if State.keys()[i] == state_name:
			current_state = i as State
			return
	DebugLogger.warning("🏠 ElderHouse: Стейт %s не знайдено!" % state_name, "ElderHouse")

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.BEFORE_FIGHT, State.DONE:
			# До бою й після розмови дім нічого не запускає і ціль не чіпає (пізніше тут лише горище).
			pass
		State.OLD_MAN_WAITING:
			# D140: «О ні, дім!» — герой заходить і йде до діда; розмову починає тригер біля нього.
			_set_objective("Talk to the old man", &"old_man")
		State.OLD_MAN_HEALING:
			if game.get_quest_flag("village_oldman_healed"):
				advance_state()
				return
			_set_objective("Talk to the old man", &"old_man")
			_talk_to_old_man(run_id)
		State.OLD_MAN_DECISION:
			if game.get_quest_flag("village_oldman_complete"):
				advance_state()
				return
			_set_objective("Make a decision")
			_decide(run_id)

## Тригер біля діда лише перемикає стан; розмову веде сцена, щоб діалоги йшли
## по черзі і кожен ставив свій прапорець. Дід лікує Кусакама (D140) — HP до повного.
func _talk_to_old_man(run_id: int) -> void:
	if not Game.get_singleton().get_quest_flag("village_oldman_met"):
		await _play_dialogue("OldMan_Outside", run_id)
		if run_id != state_run_id: return
	await _play_dialogue("OldMan_Healing", run_id)
	if run_id != state_run_id: return
	var player: CombatBody2D = Game.get_singleton().player
	player.heal_damage(player.Max_Health)
	_show_healing_light(player)
	advance_state()

## Рішення діда: спорядження й ключ дає кінець OldMan_Decision. Далі — з села (LeavingVillage грає Village, щойно
## герой вийде дверима); стрілка веде до виходу з дому (мітка canyon_bridge тут — ExitDoor).
func _decide(run_id: int) -> void:
	await _play_dialogue("OldMan_Decision", run_id)
	if run_id != state_run_id: return
	_set_objective("Leave the village", &"canyon_bridge")
	advance_state()

## Репліку «Тепле світло огортає Кусакама» прибрано (D437): світло огортає героя на екрані й гасне саме.
func _show_healing_light(player: Node2D) -> void:
	var light: Node2D = HEALING_LIGHT.instantiate()
	player.add_child(light)
	(light.get_node(^"AnimationPlayer") as AnimationPlayer).animation_finished.connect(
			func(_charge: StringName) -> void: light.release(), CONNECT_ONE_SHOT)

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	# DialogueManager шле dialogue_finished сам (EventBus — autoload, див. Village._play_dialogue).
	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	ServiceLocator.get_dialogue_manager().start_dialogue(path)
	while true:
		var finished_id = await EventBus.dialogue_finished
		if finished_id == path or finished_id == dialogue_id:
			_complete_quest_for_dialogue(dialogue_id)
			break
		if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Встановлює квестові флаги для розмов з дідом (імена з часів Village — їх читають сейви, gates.json, журнал)"""
	var game = Game.get_singleton()
	var quest_flag = ""
	match dialogue_id:
		"OldMan_Outside":
			quest_flag = "village_oldman_met"
		"OldMan_Healing":
			quest_flag = "village_oldman_healed"
		"OldMan_Decision":
			quest_flag = "village_oldman_complete"
			_give_oldman_gift()
			_give_grandfather_key()
	if not quest_flag.is_empty():
		game.set_quest_flag(quest_flag, true)
		DebugLogger.info("🏠 ElderHouse: Квест %s виконано" % quest_flag, "ElderHouse")

## D643: старий ключ діда відмикає родинне святилище в Печері ящурів (gates.json → lizard_shrine). Один раз за гру;
## окремо від спорядження, бо сейви, де спорядження вже дали, ключа ще не мають.
func _give_grandfather_key() -> void:
	var game := Game.get_singleton()
	if game.get_quest_flag("village_grandfather_key"):
		return
	ServiceLocator.get_inventory_manager().add_item("grandfather_key", 1)
	game.set_quest_flag("village_grandfather_key", true)

## Дід дає новачкові перше спорядження — один раз за гру (Sapega, 2026-10-12).
func _give_oldman_gift() -> void:
	var game := Game.get_singleton()
	var inventory: InventoryManager = ServiceLocator.get_inventory_manager()
	if game.get_quest_flag("village_oldman_gift"):
		return
	inventory.add_item("copper_sword", 1)
	inventory.add_item("leather_armor", 1)
	game.set_quest_flag("village_oldman_gift", true)
	ServiceLocator.get_ui_manager().show_obtained({"copper_sword": 1, "leather_armor": 1})  # BACKLOG 33
	# «?» чекає, доки не вдягне зброю (D744)
	get_tree().get_first_node_in_group(&"tip_tray").show_tip(OLDMAN_GIFT)
	EventBus.equipment_equipped.connect(_on_gift_equipped)

func _on_gift_equipped(_character_id: String, slot_id: String, _item_id: String) -> void:
	if not slot_id in EquipmentManager.WEAPON_SLOTS:
		return
	EventBus.equipment_equipped.disconnect(_on_gift_equipped)
	get_tree().get_first_node_in_group(&"tip_tray").retire(OLDMAN_GIFT)

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.DONE:
		current_state = (current_state + 1) as State

func _set_objective(text: String, target: StringName = &"") -> void:
	"""Встановлює об'єктив для гравця; target — мітка ObjectiveTargets/<target>, куди вказує стрілка (D-28h)"""
	Game.get_singleton().set_objective(text, target)

