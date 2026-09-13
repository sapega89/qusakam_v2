extends SceneStateManager
class_name CanyonStateManager

## 🏜️ CanyonStateManager - Компонент для управління стейтами сцени Canyon
## Використовується в сцені Canyon.tscn як компонент
## Дотримується принципу Component-Based Architecture

enum State {
	INTRO,
	MONOLOGUE,
	EXPLORATION,
	CUTSCENE_ABDUCTION,
	TO_VILLAGE,
	RELIC_PICKUP,
	EXIT_CUTSCENE,
	TO_DESERT_ROAD
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

# Назва сцени
@export var _scene_name: String = "Canyon"

# Словник маппінгу діалогів до квестів
var dialogue_to_quest: Dictionary = {
	"Canyon_StartMonologue": "canyon_intro_complete",
	"Canyon_Exploration": "canyon_exploration_complete",
	"Canyon_AbductionCutscene": "canyon_abduction_complete",
	"RoadToVillage": "canyon_abduction_complete",
	"Canyon_MeditationAtRelic": "canyon_relic_meditation_complete",
	"Canyon_ExitCutscene": "canyon_exit_complete"
}

var _initial_state_logic_pending: bool = false
var _initial_state_determined: bool = false  # Защита от повторного вызова _determine_initial_state
var _ready_called: bool = false  # Защита от повторного вызова _ready()

# Статический флаг для отслеживания показанных предупреждений (на уровне класса)
static var _metSys_warning_shown: bool = false

func _ready() -> void:
	# Защита от повторного вызова _ready()
	if _ready_called:
		DebugLogger.warning("🏜️ CanyonStateManager: ⚠️ _ready() вже викликано (instance_id=%d, name=%s), пропускаємо повторну ініціалізацію" % [get_instance_id(), name], "CanyonStateManager")
		print_stack()  # Показываем стек вызовов для отладки
		return
	
	_ready_called = true
	DebugLogger.info("🏜️ CanyonStateManager: ✅ _ready() викликано вперше (instance_id=%d, name=%s)" % [get_instance_id(), name], "CanyonStateManager")
	scene_name = _scene_name
	super._ready()
	# Після встановлення початкового стейту запускаємо його логіку
	# Використовуємо call_deferred щоб гарантувати, що всі системи ініціалізовані
	if current_state != null:
		_initial_state_logic_pending = true
		_try_apply_initial_state_logic()

func _enter_tree() -> void:
	"""Вызывается когда узел добавляется в дерево сцены"""
	# Если логика состояния еще не была запущена, запускаем ее
	if _initial_state_logic_pending and current_state != null:
		_try_apply_initial_state_logic()

func _try_apply_initial_state_logic() -> void:
	"""Пытается запустить логику начального состояния"""
	var tree = get_tree()
	if tree and current_state != null:
		call_deferred("_apply_state_logic", current_state, 0)
		_initial_state_logic_pending = false
		DebugLogger.info("🏜️ CanyonStateManager: Логіка початкового стейту запланована до запуску", "CanyonStateManager")
	else:
		# В тестах дерево может быть недоступно - это нормально
		# Логика состояния будет запущена позже, когда узел будет добавлен в дерево
		DebugLogger.info("🏜️ CanyonStateManager: Дерево сцени недоступно, логіка стейту буде запущена пізніше", "CanyonStateManager")

func _initialize_state_mapping() -> void:
	"""Ініціалізує маппінг назв стейтів до значень enum"""
	state_name_to_value.clear()
	
	for state_name in State.keys():
		state_name_to_value[state_name] = State[state_name]

func _determine_initial_state() -> void:
	"""Визначає початковий стейт на основі квестових флагів"""
	# Защита от повторного вызова
	if _initial_state_determined:
		DebugLogger.info("🏜️ CanyonStateManager: _determine_initial_state() вже викликано, пропускаємо", "CanyonStateManager")
		return
	
	_initial_state_determined = true
	DebugLogger.info("🏜️ CanyonStateManager: Визначаємо початковий стейт...", "CanyonStateManager")
	
	# MetSys is an autoload singleton
	if not MetSys:
		DebugLogger.warning("🏜️ CanyonStateManager: ❌ MetSys singleton not found, використовуємо INTRO за замовчуванням", "CanyonStateManager")
		_set_initial_state(State.INTRO)
		return
	
	# Отримуємо назву поточної кімнати
	var room_name = ""
	if MetSys.has_method("get_current_room_name"):
		room_name = MetSys.get_current_room_name()
	
	if room_name.is_empty():
		# Це нормально при першому запуску - використовуємо INTRO за замовчуванням
		# Не показуємо попередження, оскільки це очікувана поведінка
		_set_initial_state(State.INTRO)
		return
	
	DebugLogger.info("🏜️ CanyonStateManager: ✅ Current room_name: %s" % room_name, "CanyonStateManager")
	
	# Перевіряємо квестові флаги
	var game = Game.get_singleton()
	if game:
		if game.get_quest_flag("village_left_complete"):
			_set_initial_state(State.RELIC_PICKUP)
			DebugLogger.info("🏜️ CanyonStateManager: ✅ Прогрес виявлено (village_left), стейт = RELIC_PICKUP", "CanyonStateManager")
			return
		
		if game.get_quest_flag("canyon_abduction_complete", false):
			_set_initial_state(State.TO_VILLAGE)
			DebugLogger.info("🏜️ CanyonStateManager: ✅ Abduction finished, setting state to TO_VILLAGE", "CanyonStateManager")
			return
		
		if game.get_quest_flag("canyon_exploration_complete", false):
			_set_initial_state(State.CUTSCENE_ABDUCTION)
			DebugLogger.info("🏜️ CanyonStateManager: ✅ Exploration finished, setting state to CUTSCENE_ABDUCTION", "CanyonStateManager")
			return
		
		if game.get_quest_flag("canyon_intro_complete", false):
			_set_initial_state(State.EXPLORATION)
			DebugLogger.info("🏜️ CanyonStateManager: ✅ Intro finished, setting state to EXPLORATION", "CanyonStateManager")
			return
	
	# За замовчуванням - INTRO
	DebugLogger.info("🏜️ CanyonStateManager: ✅ Starting scene detected, setting state to INTRO", "CanyonStateManager")
	_set_initial_state(State.INTRO)

func _apply_state_logic(state: Variant, run_id: int) -> void:
	"""Застосовує логіку для конкретного стейту"""
	# Приводим Variant к State для совместимости с базовым классом
	if not state is State:
		DebugLogger.warning("🏜️ CanyonStateManager: _apply_state_logic получил неверный тип состояния: %s" % typeof(state), "CanyonStateManager")
		return
	
	var canyon_state = state as State
	DebugLogger.info("🏜️ CanyonStateManager: >>> STATE CHANGED TO: %s (RunID: %d)" % [State.keys()[canyon_state], run_id], "CanyonStateManager")
	
	# Оновлюємо ворота
	_update_gates_for_state(canyon_state)
	
	match canyon_state:
		State.INTRO:
			_on_intro_state(run_id)
		State.MONOLOGUE:
			_on_monologue_state(run_id)
		State.EXPLORATION:
			_on_exploration_state(run_id)
		State.CUTSCENE_ABDUCTION:
			_on_abduction_cutscene_state(run_id)
		State.TO_VILLAGE:
			_on_to_village_state(run_id)
		State.RELIC_PICKUP:
			_on_relic_pickup_state(run_id)
		State.EXIT_CUTSCENE:
			_on_exit_cutscene_state(run_id)
		State.TO_DESERT_ROAD:
			_on_to_desert_road_state(run_id)

func _on_dialogue_finished(dialogue_id: String) -> void:
	"""Обробник завершення діалогу"""
	# Завершуємо квест на основі діалогу
	_complete_quest_for_dialogue(dialogue_id)
	
	# Перевіряємо, чи потрібно змінити стейт
	_check_state_transition_after_dialogue(dialogue_id)

func _check_state_transition_after_dialogue(dialogue_id: String) -> void:
	"""Перевіряє, чи потрібно змінити стейт після діалогу"""
	match dialogue_id:
		"Canyon_Intro":
			if current_state == State.INTRO:
				_set_state(State.MONOLOGUE)
		"Canyon_StartMonologue":
			if current_state == State.MONOLOGUE:
				_set_state(State.EXPLORATION)
		"Canyon_Exploration":
			if current_state == State.EXPLORATION:
				# Стейт залишається EXPLORATION, чекаємо тригера катсцени
				pass
		"Canyon_AbductionCutscene":
			if current_state == State.CUTSCENE_ABDUCTION:
				_set_state(State.TO_VILLAGE)
		_:
			pass

# ============================================================================
# State Handlers - Конкретні дії для кожного стейту
# ============================================================================

func _on_intro_state(run_id: int) -> void:
	"""Обробка стейту INTRO - початок гри"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ INTRO ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	
	# Запускаємо вступний діалог через DialogueStateTrigger або напряму
	# Якщо діалог запускається через тригер, цей метод просто встановлює об'єктив
	var game = Game.get_singleton()
	if game and game.has_method("set_objective"):
		game.set_objective("Explore the Canyon")

func _on_monologue_state(run_id: int) -> void:
	"""Обробка стейту MONOLOGUE - монолог про діда та шамана"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ MONOLOGUE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	# Монолог запускається через DialogueStateTrigger

func _on_exploration_state(run_id: int) -> void:
	"""Обробка стейту EXPLORATION - дослідження каньону"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ EXPLORATION ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	
	# Діалог дослідження запускається через DialogueStateTrigger
	var game = Game.get_singleton()
	if game and game.has_method("set_objective"):
		game.set_objective("Find a way forward")

func _on_abduction_cutscene_state(run_id: int) -> void:
	"""Обробка стейту CUTSCENE_ABDUCTION - катсцена викрадення"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ CUTSCENE_ABDUCTION ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	
	# Катсцена запускається через DialogueStateTrigger
	var game = Game.get_singleton()
	if game and game.has_method("set_objective"):
		game.set_objective("Pursue the kidnappers")

func _on_to_village_state(run_id: int) -> void:
	"""Обробка стейту TO_VILLAGE - перехід до села"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ TO_VILLAGE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	
	# Якщо ми вже були в селі, не показуємо монолог знову
	var game = Game.get_singleton()
	if game and game.get_quest_flag("village_abduction_complete"):
		DebugLogger.info("🏜️ CanyonStateManager: Гравець вже відвідував село, пропускаємо монолог RoadToVillage", "CanyonStateManager")
		return
	
	# Монолог запускається через DialogueStateTrigger

func _on_relic_pickup_state(run_id: int) -> void:
	"""Обробка стейту RELIC_PICKUP - медитація біля реліквій"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ RELIC_PICKUP ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	# Очікуємо активації реліквії гравцем через тригер

func _on_exit_cutscene_state(run_id: int) -> void:
	"""Обробка стейту EXIT_CUTSCENE - катсцена спуску з каньону"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ EXIT_CUTSCENE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	# Очікуємо входу в зону виходу для фінальної катсцени

func _on_to_desert_road_state(run_id: int) -> void:
	"""Обробка стейту TO_DESERT_ROAD - перехід до пустельної дороги"""
	DebugLogger.info("🏜️ CanyonStateManager: ========== СТЕЙТ TO_DESERT_ROAD ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "CanyonStateManager")
	
	# НЕ викликаємо ручний перехід - MetSys обробить перехід автоматично через room connections
	# Гравець йде до межі кімнати, MetSys виявляє room connection і завантажує DesertRoad
	DebugLogger.info("🏜️ CanyonStateManager: Перехід до DesertRoad обробляється автоматично через MetSys room connections", "CanyonStateManager")

# ============================================================================
# Helper Functions - Допоміжні функції
# ============================================================================

func _update_gates_for_state(state: State) -> void:
	"""Централізоване керування воротами на основі стану сцени"""
	# В тестах или при инициализации дерево сцены может быть недоступно
	# Проверяем, что узел находится в дереве сцены перед использованием get_tree()
	if not is_inside_tree():
		DebugLogger.info("🏜️ CanyonStateManager: Вузол не в дереві сцени, пропускаємо оновлення воріт", "CanyonStateManager")
		return
	
	# Проверяем, что дерево сцены доступно
	var tree = get_tree()
	if not tree:
		DebugLogger.info("🏜️ CanyonStateManager: Дерево сцени недоступно, пропускаємо оновлення воріт", "CanyonStateManager")
		return
	
	var gate_exit = _find_gate_controller("Gate")
	var gate_inner = _find_gate_controller("Gate2")
	
	match state:
		State.INTRO, State.MONOLOGUE:
			if gate_exit: gate_exit.close_gate()
			if gate_inner: gate_inner.close_gate()
		State.EXPLORATION:
			if gate_exit: gate_exit.close_gate()
			if gate_inner: gate_inner.open_gate()
		State.CUTSCENE_ABDUCTION:
			if gate_exit: gate_exit.open_gate()
			if gate_inner: gate_inner.open_gate()
		State.TO_VILLAGE:
			# Після діалогу пора вирушати в село - відкриваємо тільки Gate2, Gate1 залишаються закритими
			if gate_exit: gate_exit.close_gate()
			if gate_inner: gate_inner.open_gate()
		State.RELIC_PICKUP, State.EXIT_CUTSCENE:
			if gate_exit: gate_exit.open_gate()
			if gate_inner: gate_inner.open_gate()
	
	# Логируем только если ворота найдены
	if gate_exit or gate_inner:
		DebugLogger.info("🏜️ CanyonStateManager: Ворота синхронізовано зі станом %s" % State.keys()[state], "CanyonStateManager")
	else:
		DebugLogger.info("🏜️ CanyonStateManager: Ворота не знайдено (може бути нормально в тестах або при ініціалізації)", "CanyonStateManager")

func _find_gate_controller(gate_name: String) -> Node:
	"""Знаходить GateController для брами"""
	# Сначала ищем в дочерних узлах
	for child in get_children():
		if child.has_method("open_gate") and child.get("gate_layer_name") == gate_name:
			return child
	
	# Проверяем, что узел находится в дереве сцены перед использованием get_tree()
	if not is_inside_tree():
		# В тестах или при инициализации узел может быть не в дереве
		return null
	
	# Проверяем, что дерево сцены доступно
	var tree = get_tree()
	if not tree:
		# В тестах или при инициализации дерево может быть недоступно
		return null
	
	var scene = tree.current_scene
	if not scene:
		return null
	
	# Ищем в сцене
	for child in scene.get_children():
		if child.has_method("open_gate") and child.get("gate_layer_name") == gate_name:
			return child
		for grandchild in child.get_children():
			if grandchild.has_method("open_gate") and grandchild.get("gate_layer_name") == gate_name:
				return grandchild
	
	return null

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Завершує квест на основі діалогу"""
	var quest_id = dialogue_to_quest.get(dialogue_id, "")
	
	if quest_id.is_empty():
		DebugLogger.info("🏜️ CanyonStateManager: Діалог %s не пов'язаний з квестами" % dialogue_id, "CanyonStateManager")
		return
	
	_complete_quest(quest_id)

func _complete_quest(quest_id: String) -> void:
	"""Завершує квест і встановлює флаг"""
	var game = Game.get_singleton()
	if game and game.has_method("set_quest_flag"):
		game.set_quest_flag(quest_id, true)
		DebugLogger.info("🏜️ CanyonStateManager: Квест %s завершено" % quest_id, "CanyonStateManager")
	else:
		DebugLogger.warning("🏜️ CanyonStateManager: Game.get_singleton() не доступний або не має методу set_quest_flag", "CanyonStateManager")

# DEPRECATED: _transition_to_room() видалено
# MetSys обробляє переходи автоматично через room connections
# НЕ викликайте Game.load_room() вручну - це конфліктує з автоматичними переходами MetSys
# Якщо потрібен спеціальний перехід (телепорт, катсцена), використовуйте Portal.gd або інші механізми
