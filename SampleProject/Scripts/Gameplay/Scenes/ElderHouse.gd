extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"

## 🏠 Дім діда (ElderHouse): тут Кусакам після бою в селі знаходить діда (D438, Sapega 2026-10-26: «дід мав бути в
## своєму домі і там мав відбутись діалог Кусакама»). Розмова — OldMan_Outside → OldMan_Healing → OldMan_Decision,
## прапорці ті самі, що були в Village (village_oldman_met → _healed → _complete), тож старі сейви йдуть далі.
## States: BEFORE_FIGHT, OLD_MAN_WAITING, OLD_MAN_HEALING, OLD_MAN_DECISION, DONE
## D252/D261: дід лікує Кусакама, але сам лікування не просить — Длань вивчається на 2-му рівні.
## Машина станів — RoomStoryFlow.

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

## Поки бій на вулиці не виграно, дід просто тут; далі — чекає героя біля себе (тригер), а пройдене не повторюється.
func _initial_state() -> int:
	var game = Game.get_singleton()
	if game.get_quest_flag("village_oldman_complete"):
		return State.DONE
	if game.get_quest_flag("village_oldman_healed"):
		return State.OLD_MAN_DECISION
	if game.get_quest_flag("village_fight_complete"):
		return State.OLD_MAN_WAITING
	return State.BEFORE_FIGHT

## Імена прапорців — з часів Village: їх читають сейви, gates.json, журнал.
func _dialogue_flags() -> Dictionary:
	return {
		"OldMan_Outside": "village_oldman_met",
		"OldMan_Healing": "village_oldman_healed",
		"OldMan_Decision": "village_oldman_complete",
	}

func _apply_state_logic(state: int, run_id: int) -> void:
	match state:
		State.BEFORE_FIGHT, State.DONE:
			# До бою й після розмови дім нічого не запускає і ціль не чіпає (пізніше тут лише горище).
			pass
		State.OLD_MAN_WAITING:
			# D140: «О ні, дім!» — герой заходить і йде до діда; розмову починає тригер біля нього.
			_set_objective("Talk to the old man", &"old_man")
		State.OLD_MAN_HEALING:
			if _skip_done("village_oldman_healed"):
				return
			_set_objective("Talk to the old man", &"old_man")
			_talk_to_old_man(run_id)
		State.OLD_MAN_DECISION:
			if _skip_done("village_oldman_complete"):
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

## Кінець рішення діда дає спорядження й ключ — до прапорця, як і раніше.
func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	if dialogue_id == "OldMan_Decision":
		_give_oldman_gift()
		_give_grandfather_key()
	super(dialogue_id)

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
