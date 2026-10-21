extends Node2D

## 🏘️ Village Scene Manager
## States: ABDUCTION_CUTSCENE, ARRIVAL, STREET_FIGHT, OLD_MAN_OUTSIDE, OLD_MAN_HEALING, OLD_MAN_DECISION, LEAVING_VILLAGE
## D252/D261: дід лікує Кусакама, але сам лікування не просить — Длань вивчається на 2-му рівні.
## Follows Robust State-Flow Pattern

enum State {
	ABDUCTION_CUTSCENE,
	ARRIVAL,
	STREET_FIGHT,
	OLD_MAN_OUTSIDE,
	OLD_MAN_HEALING,
	OLD_MAN_DECISION,
	LEAVING_VILLAGE
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

const OLDMAN_GIFT := "oldman_gift"
const CombatTraining = preload("res://SampleProject/Scripts/Gameplay/CombatTraining.gd")

@export var current_state: State = State.ABDUCTION_CUTSCENE:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

# Enemy spawner reference
var enemy_spawner: RoomEnemySpawner = null
## Уроки бою з бандитом (BACKLOG 28, D-28a) — живуть, доки бій не скінчився.
var training: CombatTraining = null

func _ready() -> void:
	# ServiceLocator — autoload, а не Engine-синглтон: has_singleton() тут завжди
	# давав false, тож очікування не відбувалося взагалі.
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	DebugLogger.info("🏘️ Village: ServiceLocator готовий", "Village")


	# Спавнер треба знайти ДО _determine_initial_state(): той одразу виставляє
	# current_state, а STREET_FIGHT у сеттері вже викликає _spawn_enemies_for_fight().
	enemy_spawner = $EnemySpawner
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	DebugLogger.info("🏘️ Village: EnemySpawner found and connected", "Village")

	# Тільки _determine_initial_state(): присвоєння current_state саме по собі
	# запускає сеттер → _on_state_changed(). Додатковий ручний виклик стартував
	# той самий стан ДВІЧІ — другий start_dialogue() перебивав перший і
	# DialogueQuest ішов у "Auto-recovering: Dialogue was active but hidden",
	# ховаючи вікно. Гравець лишався в ABDUCTION_CUTSCENE без жодного способу
	# його завершити, а тригери ARRIVAL/OLD_MAN_OUTSIDE відсіювались по стану.
	_determine_initial_state()

func _determine_initial_state() -> void:
	"""Визначає початковий стейт на основі квестових флагів"""
	var game = Game.get_singleton()
	if game.get_quest_flag("village_left_complete"):
		current_state = State.LEAVING_VILLAGE
	elif game.get_quest_flag("village_oldman_complete") or game.get_quest_flag("village_oldman_healed"):
		current_state = State.OLD_MAN_DECISION
	elif game.get_quest_flag("village_oldman_met"):
		current_state = State.OLD_MAN_HEALING
	elif game.get_quest_flag("village_fight_complete"):
		current_state = State.OLD_MAN_OUTSIDE
	elif game.get_quest_flag("village_arrival_complete"):
		current_state = State.STREET_FIGHT
	elif game.get_quest_flag("village_abduction_complete"):
		current_state = State.ARRIVAL
	else:
		current_state = State.ABDUCTION_CUTSCENE

	DebugLogger.info("🏘️ Village: Initial state determined as %s" % State.keys()[current_state], "Village")

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🏘️ Village: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")

	_emit_state_changed_event(new_state)
	_apply_state_logic(new_state, run_id)

func _emit_state_changed_event(new_state: State) -> void:
	var state_name = State.keys()[new_state]
	# EventBus — autoload; has_singleton() тут завжди був false, тож подія про
	# зміну стану сцени не відправлялась жодного разу.
	EventBus.scene_state_changed.emit("Village", "", state_name)

func get_current_state_name() -> String:
	"""Повертає назву поточного стейту для тригерів"""
	return State.keys()[current_state]

func change_state_by_name(state_name: String) -> void:
	"""Змінює стейт за назвою (викликається тригерами)"""
	for i in range(State.size()):
		if State.keys()[i] == state_name:
			current_state = i as State
			return
	DebugLogger.warning("🏘️ Village: Стейт %s не знайдено!" % state_name, "Village")

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()

	match state:
		# УВАГА: гілки "вже пройдено" МУСЯТЬ викликати advance_state().
		# Ланцюг станів рухається тільки через нього (див. сеттер current_state),
		# тож голий return зупиняв машину назавжди: гравець говорив з дідом,
		# наступний стан бачив уже виставлений прапорець, мовчки виходив — і
		# LeavingVillage не запускався ніколи, а з ним і village_left_complete.
		State.ABDUCTION_CUTSCENE:
			if game.get_quest_flag("village_abduction_complete"):
				DebugLogger.info("🏘️ Village: Катсцена викрадення вже відбулася, пропускаємо", "Village")
				advance_state()
				return
			# Сам напад показано в Canyon (D191); тут лише відмічаємо, що гравець дійшов до села.
			game.set_quest_flag("village_abduction_complete", true)
			advance_state()
		State.ARRIVAL:
			_set_objective("Reach the village center", &"village_center")
			# Очікуємо поки гравець дійде до тригера "ArrivalToVillage"
			DebugLogger.info("🏘️ Village: Очікуємо тригера прибуття (ARRIVAL)", "Village")
			pass
		State.STREET_FIGHT:
			if game.get_quest_flag("village_fight_complete"):
				DebugLogger.info("🏘️ Village: Бій вже відбувся, пропускаємо", "Village")
				advance_state()
				return
			# Вхід у цей стан = гравець дійшов до центру села (ціль «Reach the village center»).
			# Репліку прибуття грає тригер, а не сцена, тож прапорець не ставився ніким —
			# і журнал застрягав на цій цілі.
			game.set_quest_flag("village_arrival_complete", true)
			_start_fight("FightWithBandit", run_id)
		State.OLD_MAN_OUTSIDE:
			# D140: після бою — «О ні, дім!», далі гравець сам іде до діда (тригер біля дерева).
			_set_objective("Check on the house", &"house")
			if not game.get_quest_flag("village_afterfight_complete"):
				_play_dialogue("Village_AfterFight", run_id)
		State.OLD_MAN_HEALING:
			# Кожна розмова з дідом має свій прапорець: met → healed → complete.
			if game.get_quest_flag("village_oldman_healed"):
				DebugLogger.info("🏘️ Village: Гілка діда вже завершена, пропускаємо", "Village")
				advance_state()
				return
			_set_objective("Talk to the old man", &"old_man")
			_talk_to_old_man(run_id)
		State.OLD_MAN_DECISION:
			if game.get_quest_flag("village_oldman_complete"):
				advance_state()
				return
			_set_objective("Make a decision")
			_execute_step(StepType.DIALOGUE, "OldMan_Decision", run_id)
		State.LEAVING_VILLAGE:
			if game.get_quest_flag("village_left_complete"):
				return  # останній стан, просувати нікуди
			_set_objective("Leave the village", &"canyon_bridge")
			_execute_step(StepType.DIALOGUE, "LeavingVillage", run_id)

## Тригер біля діда лише перемикає стан; розмову веде сцена, щоб діалоги йшли
## по черзі (раніше OldMan_Outside і OldMan_Healing стартували одночасно)
## і кожен ставив свій прапорець. Дід лікує Кусакама (D140) — HP до повного.
func _talk_to_old_man(run_id: int) -> void:
	if not Game.get_singleton().get_quest_flag("village_oldman_met"):
		await _play_dialogue("OldMan_Outside", run_id)
		if run_id != state_run_id: return
	await _play_dialogue("OldMan_Healing", run_id)
	if run_id != state_run_id: return
	var player: CombatBody2D = Game.get_singleton().player
	player.heal_damage(player.Max_Health)
	advance_state()

## Спершу зʼявляється бандит, потім репліки (Sapega, 2026-10-15). Поки діалог тримає гравця
## (DialogueManager), ворог вимкнений — інакше бив би нерухомого гравця, що виглядало як
## зависання. Бій закінчується лише смертю ворогів (_on_all_enemies_defeated).
## Гравець вийшов посеред бою — повертаємо тих самих ворогів без репліки (D152).
## Бандит — перший ворог гри, тож бій починається з уроків (D-28a): спершу шість рухів, потім «добий його».
## Повернувся посеред бою — уроки знову з першого (D-28d), вони короткі.
func _start_fight(dialogue_id: String, run_id: int) -> void:
	var resumed: bool = enemy_spawner.fight_in_progress()
	training = CombatTraining.new()  # до появи бандита: загальні підказки бою стають баченими
	add_child(training)
	_spawn_enemies_for_fight()
	if not resumed:
		_set_enemies_active(false)
		await _play_dialogue(dialogue_id, run_id)
		if run_id != state_run_id:
			return
		_set_enemies_active(true)
	_set_objective("Learn to fight: follow the lesson")
	training.start(enemy_spawner.spawned_enemies)
	await training.finished
	if run_id != state_run_id:
		return
	_set_objective("Defeat the bandit in the street")

## Вимкнений вузол не думає й не має фізики (disable_mode REMOVE) — ні руху, ні удару.
func _set_enemies_active(active: bool) -> void:
	for enemy in enemy_spawner.spawned_enemies:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	match type:
		StepType.DIALOGUE:
			await _play_dialogue(dialogue_id, run_id)
		StepType.COMBAT:
			await _play_dialogue(dialogue_id, run_id)
		StepType.LOOP:
			await get_tree().create_timer(1.0).timeout
		StepType.TRANSITION:
			await get_tree().create_timer(0.5).timeout

	if run_id != state_run_id: return

	# ARRIVAL/OLD_MAN_OUTSIDE чекають на тригер у сцені.
	if current_state not in [State.ARRIVAL, State.OLD_MAN_OUTSIDE]:
		advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	var dm = _get_dialogue_manager()
	if not dm: return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)

	# УВАГА: тут НЕ можна питати Engine.has_singleton("EventBus").
	# EventBus — це autoload, тобто вузол /root/EventBus, а не Engine-синглтон,
	# тож has_singleton() завжди повертав false. Через це цикл очікування не
	# виконувався жодного разу: _play_dialogue() виходив одразу після
	# start_dialogue(), _execute_step() робив advance_state(), і вся машина
	# станів Village пролітала до кінця, не програвши діалогів і не викликавши
	# _complete_quest_for_dialogue() — тому жоден village-прапорець не ставився.
	while true:
		var finished_id = await EventBus.dialogue_finished
		if finished_id == path or finished_id == dialogue_id:
			# Завершуємо квест після діалогу
			_complete_quest_for_dialogue(dialogue_id)
			break
		if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Встановлює квестові флаги для діалогів у селі"""
	var game = Game.get_singleton()

	var quest_flag = ""
	match dialogue_id:
		"ArrivalToVillage":
			quest_flag = "village_arrival_complete"
		# "FightWithBandit" тут свідомо відсутній: це репліка-насмішка ПЕРЕД боєм.
		# Ставити village_fight_complete по її завершенню означало б зарахувати
		# бій до того, як бандит зʼявився. Прапорець ставиться після перемоги.
		"OldMan_Outside":
			quest_flag = "village_oldman_met"
		"OldMan_Healing":
			quest_flag = "village_oldman_healed"
		"Village_AfterFight":
			quest_flag = "village_afterfight_complete"
		"OldMan_Decision":
			quest_flag = "village_oldman_complete"
			_give_oldman_gift()
		"LeavingVillage":
			quest_flag = "village_left_complete"

	if not quest_flag.is_empty():
		game.set_quest_flag(quest_flag, true)
		DebugLogger.info("🏘️ Village: Квест %s виконано" % quest_flag, "Village")

## Дід дає новачкові перше спорядження — один раз за гру (Sapega, 2026-10-12).
func _give_oldman_gift() -> void:
	var game := Game.get_singleton()
	var inventory: InventoryManager = ServiceLocator.get_inventory_manager()
	if game.get_quest_flag("village_oldman_gift"):
		return
	inventory.add_item("copper_sword", 1)
	inventory.add_item("leather_armor", 1)
	game.set_quest_flag("village_oldman_gift", true)
	# Висить, доки не вдягне зброю
	get_tree().get_first_node_in_group(&"tutorial_hint_display").show_hint(OLDMAN_GIFT, true, true)
	EventBus.equipment_equipped.connect(_on_gift_equipped)

func _on_gift_equipped(_character_id: String, slot_id: String, _item_id: String) -> void:
	if not slot_id in EquipmentManager.WEAPON_SLOTS:
		return
	EventBus.equipment_equipped.disconnect(_on_gift_equipped)
	var hint: TutorialHintDisplay = get_tree().get_first_node_in_group(&"tutorial_hint_display")
	if hint.current_hint == OLDMAN_GIFT:
		hint.force_hide()

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.LEAVING_VILLAGE:
		current_state = (current_state + 1) as State
	else:
		# Сцена завершена - гравець може вільно переміщатися
		# Перехід до інших сцен обробляється автоматично через MetSys room connections
		DebugLogger.info("🏘️ Village: Сцена завершена - переходи обробляються через MetSys room connections", "Scene")

func _set_objective(text: String, target: StringName = &"") -> void:
	"""Встановлює об'єктив для гравця; target — мітка ObjectiveTargets/<target>, куди вказує стрілка (D-28h)"""
	var game = Game.get_singleton()
	game.set_objective(text, target)

func _spawn_enemies_for_fight() -> void:
	"""Спавнить бандита для вуличного бою"""
	enemy_spawner.spawn_all_enemies()
	DebugLogger.info("🏘️ Village: Enemies spawning for street fight", "Village")

func _on_all_enemies_defeated() -> void:
	"""Обробник перемоги над усіма ворогами у вуличному бою"""
	# Гард по стану: сигнал прилетить з будь-якого стейту, а не лише з бою.
	if current_state != State.STREET_FIGHT:
		return

	DebugLogger.info("🏘️ Village: Бандита переможено", "Village")

	# Прапорець ставимо ДО advance_state(): той синхронно запускає сеттер
	# наступного стану, і якщо гра збережеться всередині цього ланцюга, бій має
	# бути вже зарахований. Інакше перезахід у село відкине гравця назад у
	# STREET_FIGHT і бандит відродиться.
	var game = Game.get_singleton()
	game.set_quest_flag("village_fight_complete", true)
	if training != null:
		training.queue_free()
		training = null

	advance_state()

func _get_dialogue_manager() -> Node:
	# ServiceLocator — autoload (/root/ServiceLocator), а не Engine-синглтон.
	# Engine.has_singleton() для нього завжди false, тож раніше цей метод
	# ЗАВЖДИ повертав null: _play_dialogue() виходив на `if not dm: return`,
	# _execute_step() одразу викликав advance_state(), і вся машина станів
	# пролітала до кінця без жодного діалогу і без жодного прапорця.
	return ServiceLocator.get_dialogue_manager()

## Пішов із села, не вдягнувши подарунок, — підказка йде разом із селом (її ховає лише село).
func _exit_tree() -> void:
	var hint: TutorialHintDisplay = get_tree().get_first_node_in_group(&"tutorial_hint_display")
	if hint != null and hint.current_hint == OLDMAN_GIFT:
		hint.force_hide()
