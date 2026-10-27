extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"

## Тема «?»-підказки (TipTray) для охоронця (D209, D744).
const CALL_GUARD := "call_guard"
const COMPANIONS_HINT := "companions"

## 🏰 City Gates Scene Manager
## States: APPROACH, RAID_CUTSCENE, FIGHT_LOOP, AFTER_FIGHT_DIALOGUE, TO_CITY
## Кусакам іде дорогою до брами; RaidTrigger переводить APPROACH → RAID_CUTSCENE (бандити нападають на браму),
## далі бій з асистом охоронця (D209). Машина станів — RoomStoryFlow.

enum State {
	APPROACH,
	RAID_CUTSCENE,
	FIGHT_LOOP,
	AFTER_FIGHT_DIALOGUE,
	TO_CITY
}

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")

# Enemy spawner reference
var enemy_spawner: RoomEnemySpawner = null

func _prepare() -> void:
	# Находим EnemySpawner
	enemy_spawner = $EnemySpawner
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	DebugLogger.info("🏰 CityGates: EnemySpawner found and connected", "Scene")

## Стан при вході — за прапорцями. Раніше завжди стартували зі вступу, а він при
## прочитаному вступі просто виходив: повернувшись у кімнату, бій не починався ніколи.
func _initial_state() -> int:
	var game := Game.get_singleton()
	if game.get_quest_flag("city_gates_after_fight_complete"):
		return State.TO_CITY
	if game.get_quest_flag("city_gates_fight_complete"):
		return State.AFTER_FIGHT_DIALOGUE
	if game.get_quest_flag("city_gates_intro_complete"):
		return State.FIGHT_LOOP
	return State.APPROACH

func _dialogue_flags() -> Dictionary:
	return {
		"CityGates_Raid": "city_gates_intro_complete",
		"CityGates_AfterFight": "city_gates_after_fight_complete",
	}

func _apply_state_logic(state: int, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.APPROACH:
			# Нічого не запускаємо: RaidTrigger на дорозі переводить у RAID_CUTSCENE.
			_set_objective("Approach the city gates", &"city_gates")
		State.RAID_CUTSCENE:
			_raid_cutscene(run_id)
		State.FIGHT_LOOP:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("city_gates_fight_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates_Fight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Enter the city", &"city")
				return
			_set_objective("Defeat the bandits")
			_start_fight("CityGates_Fight", run_id)
		State.AFTER_FIGHT_DIALOGUE:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("city_gates_after_fight_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates_AfterFight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Find the laboratory")
				return
			_set_objective("Enter the city", &"city")
			_after_fight(run_id)
		State.TO_CITY:
			_set_objective("Find the laboratory")
			# Перехід до Laboratory обробляється автоматично через MetSys room connections
			DebugLogger.info("🏰 CityGates: Стейт TO_CITY - перехід обробляється через MetSys", "Scene")

## Репліка йде ПЕРЕД боєм: поки вона висить, гравець заблокований (DialogueManager), і ворог,
## що вже зʼявився, бив би його, а гравець не міг би поворухнутись — виглядало як зависання.
## Бій закінчується лише смертю ворогів (_on_all_enemies_defeated), а не кінцем репліки.
## Гравець вийшов посеред бою — повертаємо тих самих ворогів без репліки (D152).
func _start_fight(dialogue_id: String, run_id: int) -> void:
	if not enemy_spawner.fight_in_progress():
		await _play_dialogue(dialogue_id, run_id)
		if run_id != state_run_id:
			return
	_spawn_enemies_for_fight()

## Після бою — перепис у писаря біля брами (D727, D728: клятва обирається тут), тоді думка героя про лабораторію.
## Клятва вже є (старий сейв) — перепису немає.
func _after_fight(run_id: int) -> void:
	var scribe: Node = $GateScribe
	if scribe.census_pending():
		await scribe.start_census()
		if run_id != state_run_id:
			return
	_dialogue_then_advance("CityGates_AfterFight", run_id)

## Напад бандитів (BACKLOG feedback 18): RaidTrigger забирає керування, камера пливе до брами (D437: без слів автора),
## CityGates_Raid (варта кличе до зброї), бандити (Raid/Bandits) біжать дорогою до варти й стають на точки спавну
## бою, камера
## повертається до героя, керування — назад; далі FIGHT_LOOP (CityGates_Fight, бій, асист охоронця D209).
## Кожен діалог ставить героя в Idle і віддає керування — блокування вертається після кожного.
const RAID_PAN_TIME := 1.6
const RAID_RUN_TIME := 2.0
const RAID_STAND_HOLD := 0.8
const RAID_RETURN_TIME := 1.0

func _raid_cutscene(run_id: int) -> void:
	var cs := Cutscene.new()
	await cs.pan_to($Raid/Look.global_position, RAID_PAN_TIME)
	if run_id != state_run_id:
		return

	# Варта бачить бандитів першою; репліка — до їхнього бігу, щоб вікно діалогу не закрило їх.
	await _play_dialogue("CityGates_Raid", run_id)
	if run_id != state_run_id:
		return
	cs.hold()

	# Бандити вибігають з-за лівого краю кадру — кожен до своєї точки спавну.
	$Raid.show()
	$Raid/AnimationPlayer.play(&"run")
	var run := create_tween().set_parallel()
	var marks: Array[Node] = enemy_spawner.get_children()
	for i: int in $Raid/Bandits.get_child_count():
		run.tween_property($Raid/Bandits.get_child(i), ^"global_position:x", (marks[i] as Node2D).global_position.x, RAID_RUN_TIME)
	await run.finished
	$Raid/AnimationPlayer.play(&"stand")
	await cs.wait(RAID_STAND_HOLD)
	await cs.camera_back(RAID_RETURN_TIME)
	cs.end()
	advance_state()

func _spawn_enemies_for_fight() -> void:
	"""Спавнить врагов для боя"""
	# Бандити кат-сцени стоять на точках спавну — їх замінюють справжні вороги.
	$Raid.hide()
	enemy_spawner.spawn_all_enemies()
	DebugLogger.info("🏰 CityGates: Enemies spawning for fight", "Scene")
	# D209: охоронець — перший асист-туторіал: кнопка асисту кличе його, його удар закінчує бій
	ServiceLocator.get_companion_manager().offer_guard(true)
	_tips().show_tip(CALL_GUARD)
	if not EventBus.assist_called.is_connected(_on_assist_called):
		EventBus.assist_called.connect(_on_assist_called)

func _on_assist_called(companion_id: String) -> void:
	if companion_id == "guard":
		_tips().retire(CALL_GUARD)
		_tips().show_tip(COMPANIONS_HINT)

## Підказки — «?» (D744).
func _tips() -> Node:
	return get_tree().get_first_node_in_group(&"tip_tray")

## Пішли з воріт посеред бою (смерть, портал) — охоронця більше не пропонують.
func _exit_tree() -> void:
	ServiceLocator.get_companion_manager().offer_guard(false)


func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	ServiceLocator.get_companion_manager().offer_guard(false)
	_tips().retire(CALL_GUARD)
	DebugLogger.info("🏰 CityGates: All enemies defeated, advancing state", "Scene")
	_fight_won(State.FIGHT_LOOP, "city_gates_fight_complete")
