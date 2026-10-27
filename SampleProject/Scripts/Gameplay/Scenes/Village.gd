extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"

## 🏘️ Village Scene Manager
## States: ABDUCTION_CUTSCENE, ARRIVAL, STREET_FIGHT, CHECK_HOUSE, LEAVING_VILLAGE
## Діда на вулиці немає: після бою герой іде до свого дому (ElderDoor), і вся розмова з дідом — там
## (ElderHouse.gd, D438; Sapega 2026-10-26). Село чекає на village_oldman_complete, а тоді — LeavingVillage.
## Машина станів — RoomStoryFlow.

enum State {
	ABDUCTION_CUTSCENE,
	ARRIVAL,
	STREET_FIGHT,
	CHECK_HOUSE,
	LEAVING_VILLAGE
}

# Enemy spawner reference
var enemy_spawner: RoomEnemySpawner = null

func _prepare() -> void:
	enemy_spawner = $EnemySpawner
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	DebugLogger.info("🏘️ Village: EnemySpawner found and connected", "Village")

func _initial_state() -> int:
	var game = Game.get_singleton()
	# Розмова з дідом (met → healed → complete) іде в ElderHouse; село до її кінця лише кличе до дому.
	if game.get_quest_flag("village_left_complete") or game.get_quest_flag("village_oldman_complete"):
		return State.LEAVING_VILLAGE
	if game.get_quest_flag("village_fight_complete"):
		return State.CHECK_HOUSE
	if game.get_quest_flag("village_arrival_complete"):
		return State.STREET_FIGHT
	if game.get_quest_flag("village_abduction_complete"):
		return State.ARRIVAL
	return State.ABDUCTION_CUTSCENE

## "FightWithBandit" тут свідомо відсутній: це репліка-насмішка ПЕРЕД боєм. Ставити village_fight_complete по її
## завершенню означало б зарахувати бій до того, як бандит зʼявився. Прапорець ставиться після перемоги.
## Розмови з дідом (OldMan_*) ставлять свої прапорці в ElderHouse.gd.
func _dialogue_flags() -> Dictionary:
	return {
		"ArrivalToVillage": "village_arrival_complete",
		"Village_AfterFight": "village_afterfight_complete",
		"LeavingVillage": "village_left_complete",
	}

func _apply_state_logic(state: int, run_id: int) -> void:
	var game = Game.get_singleton()

	match state:
		State.ABDUCTION_CUTSCENE:
			if _skip_done("village_abduction_complete"):
				return
			# Сам напад показано в Canyon (D191); тут лише відмічаємо, що гравець дійшов до села.
			game.set_quest_flag("village_abduction_complete", true)
			advance_state()
		State.ARRIVAL:
			# Очікуємо поки гравець дійде до тригера "ArrivalToVillage"
			_set_objective("Reach the village center", &"village_center")
		State.STREET_FIGHT:
			if _skip_done("village_fight_complete"):
				return
			# Вхід у цей стан = гравець дійшов до центру села (ціль «Reach the village center»).
			# Репліку прибуття грає тригер, а не сцена, тож прапорець не ставився ніким —
			# і журнал застрягав на цій цілі.
			game.set_quest_flag("village_arrival_complete", true)
			_start_fight("FightWithBandit", run_id)
		State.CHECK_HOUSE:
			# D140/D438: після бою — «О ні, дім!», далі гравець сам іде до свого дому: стрілка — на ElderDoor
			# (мітка house). Розмову з дідом веде ElderHouse; повернувшись після неї, герой застає LEAVING_VILLAGE.
			_set_objective("Check on the house", &"house")
			if not game.get_quest_flag("village_afterfight_complete"):
				_play_dialogue("Village_AfterFight", run_id)
		State.LEAVING_VILLAGE:
			if game.get_quest_flag("village_left_complete"):
				return  # останній стан, просувати нікуди
			_set_objective("Leave the village", &"canyon_bridge")
			_dialogue_then_advance("LeavingVillage", run_id)

## Спершу зʼявляється бандит, потім репліки (Sapega, 2026-10-15). Поки діалог тримає гравця
## (DialogueManager), ворог вимкнений — інакше бив би нерухомого гравця, що виглядало як
## зависання. Бій закінчується лише смертю ворогів (_on_all_enemies_defeated).
## Гравець вийшов посеред бою — повертаємо тих самих ворогів без репліки (D152).
## D743: звичайний бій, без тренування (Sapega, 2026-10-26: «прибрати тренування бою») — колір відблиску ворога
## пояснюють «?»-підказки (TutorialManager); прапорці training_*_done старих сейвів нічого не значать.
func _start_fight(dialogue_id: String, run_id: int) -> void:
	var resumed: bool = enemy_spawner.fight_in_progress()
	_spawn_enemies_for_fight()
	if not resumed:
		_set_enemies_active(false)
		await _play_dialogue(dialogue_id, run_id)
		if run_id != state_run_id:
			return
		_set_enemies_active(true)
	_set_objective("Defeat the bandit in the street")

## Вимкнений вузол не думає й не має фізики (disable_mode REMOVE) — ні руху, ні удару.
func _set_enemies_active(active: bool) -> void:
	for enemy in enemy_spawner.spawned_enemies:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _spawn_enemies_for_fight() -> void:
	"""Спавнить бандита для вуличного бою"""
	enemy_spawner.spawn_all_enemies()
	DebugLogger.info("🏘️ Village: Enemies spawning for street fight", "Village")

func _on_all_enemies_defeated() -> void:
	"""Обробник перемоги над усіма ворогами у вуличному бою"""
	_fight_won(State.STREET_FIGHT, "village_fight_complete")
