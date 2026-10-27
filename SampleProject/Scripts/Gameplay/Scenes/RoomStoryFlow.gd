extends Node2D

## 🎬 Спільна машина станів сюжетної кімнати (code_review §3.1, MASTER_PLAN S3). Кімната (Village, CityGates, …)
## пише `extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"` і тримає лише своє:
##   - `enum State { … }` у сюжетному порядку (StateChangeTrigger порівнює номери як прогрес);
##   - `_initial_state()` — стан при вході, за квестовими прапорцями (стан кімнати не зберігається, лише прапорці —
##     тож старі сейви заходять у той самий стан);
##   - `_apply_state_logic(state, run_id)` — що робить кожен стан;
##   - `_dialogue_flags()` — який прапорець ставить кінець якого діалогу; кат-сцени й бої.
## Тут — решта: сеттер current_state → _on_state_changed, state_run_id (стара асинхронна гілка бачить, що стан
## змінився, і виходить), advance_state, імена станів для StateChangeTrigger, діалог → прапорець, діалог → далі,
## «вже пройдено» → далі (B66), перемога в бою → прапорець → далі.

signal state_complete(state: int)

## Значення enum State кімнати. Присвоєння запускає стан; початкове значення сеттер не викликає.
var current_state: int = 0:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0


func _ready() -> void:
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	_prepare()
	# Лише присвоєння: сеттер сам запускає стан. Другий ручний _on_state_changed() стартував той самий стан ДВІЧІ —
	# другий start_dialogue() перебивав перший (стара бага Village).
	current_state = _initial_state()


## До першого стану: знайти спавнер, підписатися на сигнали кімнати. Спавнер — ДО стану: бойовий стан у сеттері
## вже кличе спавн.
func _prepare() -> void:
	pass


## Стан при вході — за квестовими прапорцями.
func _initial_state() -> int:
	return 0


func _apply_state_logic(_state: int, _run_id: int) -> void:
	assert(false, "%s: _apply_state_logic() is not overridden" % room_id())


## Діалог (id без шляху) → прапорець, що ставить його кінець.
func _dialogue_flags() -> Dictionary:
	return {}


## Що робити, коли пройдено останній стан (переходи між кімнатами веде MetSys).
func _on_story_end() -> void:
	pass


## Ім'я кімнати (Village, CityGates, …) — для логів і EventBus.scene_state_changed.
func room_id() -> String:
	return scene_file_path.get_file().get_basename()


func _states() -> Dictionary:
	return (get_script() as Script).get_script_constant_map()["State"]


func _on_state_changed(new_state: int) -> void:
	state_run_id += 1
	var run_id := state_run_id
	DebugLogger.info("%s: Entering state %s (RunID: %d)" % [room_id(), _states().keys()[new_state], run_id], "Scene")
	_announce_state(new_state)
	_apply_state_logic(new_state, run_id)


func _announce_state(new_state: int) -> void:
	EventBus.scene_state_changed.emit(room_id(), "", _states().keys()[new_state])


## Для StateChangeTrigger (require_state).
func get_current_state_name() -> String:
	return _states().keys()[current_state]


## Для StateChangeTrigger (target_state). Імена в кімнатах звірені з enum State кожної.
func change_state_by_name(state_name: String) -> void:
	assert(_states().has(state_name), "%s: no state %s" % [room_id(), state_name])
	current_state = _states()[state_name]


## Ланцюг станів рухається тільки через advance_state() (сеттер current_state).
func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < _states().size() - 1:
		current_state += 1
	else:
		_on_story_end()


## УВАГА (B66): гілка «вже пройдено» МУСИТЬ вести далі. Голий return зупиняв машину назавжди: наступний стан бачив
## уже виставлений прапорець, мовчки виходив — і далі не йшло нічого. Повертає, чи пропущено.
func _skip_done(flag: String) -> bool:
	if not Game.get_singleton().get_quest_flag(flag):
		return false
	DebugLogger.info("%s: %s вже пройдено, далі" % [room_id(), flag], "Scene")
	advance_state()
	return true


## Діалог і кінець — далі, якщо стан за цей час не змінився.
func _dialogue_then_advance(dialogue_id: String, run_id: int) -> void:
	await _play_dialogue(dialogue_id, run_id)
	if run_id != state_run_id:
		return
	advance_state()


## Програє res://dialogue_quest/<dialogue_id>.dqd і чекає його кінця (DialogueManager шле dialogue_finished сам;
## EventBus — autoload). Кінець ставить прапорець діалогу. Стан змінився, поки чекали чужого кінця, — виходимо.
## Повертає, чи діалог дограно до кінця.
func _play_dialogue(dialogue_id: String, run_id: int, in_cloud: bool = false) -> bool:
	var path := "res://dialogue_quest/" + dialogue_id + ".dqd"
	ServiceLocator.get_dialogue_manager().start_dialogue(path, in_cloud)
	while true:
		var finished_id: String = await EventBus.dialogue_finished
		if finished_id == path or finished_id == dialogue_id:
			_complete_quest_for_dialogue(dialogue_id)
			return true
		if run_id != state_run_id:
			return false
	return false


func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	var flags := _dialogue_flags()
	if not flags.has(dialogue_id):
		return
	Game.get_singleton().set_quest_flag(flags[dialogue_id], true)
	DebugLogger.info("%s: Квест %s виконано" % [room_id(), flags[dialogue_id]], "Scene")


## Бій стану [param fight_state] виграно. Прапорець — ДО advance_state(): той синхронно запускає наступний стан, і
## сейв посеред цього ланцюга вже бачить бій зарахованим (інакше перезахід відроджував ворогів).
## Сигнал спавнера прилітає з будь-якого стану — тому перевірка стану.
func _fight_won(fight_state: int, flag: String) -> void:
	if current_state != fight_state:
		return
	Game.get_singleton().set_quest_flag(flag, true)
	advance_state()


## target — мітка ObjectiveTargets/<target>, куди вказує стрілка (D-28h).
func _set_objective(text: String, target: StringName = &"") -> void:
	Game.get_singleton().set_objective(text, target)
