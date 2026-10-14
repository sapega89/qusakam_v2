extends Node
class_name GameDialogueManager

## 💬 GameDialogueManager - Менеджер диалогов через DialogueQuest
## Интегрирует DialogueQuest с игровой системой

# Ссылка на DialogueQuest singleton

# Текущий активный диалог (DialoguePlayer)
var current_dialogue_player: DQDialoguePlayer = null

# DialogueBox для очистки placeholder текста
var current_dialogue_box: DQDialogueBox = null

# DialoguePlayer с настроенными компонентами
var dialogue_player_instance: Node = null

# Діалоги, запрошені, поки йшов інший: грають по черзі (див. start_dialogue).
var _queue: Array[String] = []

# Сигналы
signal dialogue_started(timeline_name: String)
signal dialogue_finished(timeline_name: String)
signal dialogue_choice_selected(choice_index: int)

func _ready():
	"""Проверяет доступность DialogueQuest"""
	# НЕ создаём компоненты автоматически - они должны быть в .tscn сценах

## DialogueSystem живе в Game.tscn (не в кімнаті й не в меню) — підключає його компоненти.
func _find_dialogue_system_in_scene() -> bool:
	var dialogue_system: CanvasLayer = Game.get_singleton().get_node(^"DialogueSystem")
	dialogue_system.layer = 100
	dialogue_system.visible = true
	dialogue_system.process_mode = Node.PROCESS_MODE_ALWAYS
	current_dialogue_player = dialogue_system.get_node(^"DialoguePlayer")
	current_dialogue_box = dialogue_system.get_node(^"DialogueBox")
	current_dialogue_player.dialogue_box = current_dialogue_box
	current_dialogue_player.choice_menu = dialogue_system.get_node(^"ChoiceMenu")
	current_dialogue_box.visible = false
	current_dialogue_box.set_text("")
	current_dialogue_box.set_name_text("")
	current_dialogue_box.set_portrait_image(null)
	_connect_dialogue_quest_signals()
	return true

func _connect_dialogue_quest_signals():
	"""Подключает сигналы DialogueQuest"""
	# DialogueQuest — autoload (/root/DialogueQuest), а не Engine-синглтон.
	# Раніше тут стояв Engine.has_singleton() БЕЗ фолбеку (на відміну від
	# _check_dialogue_quest_availability_deferred), тож жоден із трьох сигналів
	# не підключався ніколи. Наслідки: гравець міг ходити під час діалогу
	# (_on_dialogue_quest_started не блокував ввід), а dialogue_finished не
	# емітився взагалі — Village назавжди зависав в await.
	var signals = DialogueQuest.Signals

	if not signals.dialogue_started.is_connected(_on_dialogue_quest_started):
		signals.dialogue_started.connect(_on_dialogue_quest_started)
	if not signals.dialogue_ended.is_connected(_on_dialogue_quest_ended):
		signals.dialogue_ended.connect(_on_dialogue_quest_ended)
	if not signals.dialogue_signal.is_connected(_on_dialogue_quest_signal):
		signals.dialogue_signal.connect(_on_dialogue_quest_signal)
	DebugLogger.info("💬 DialogueManager: ✅ Сигнали DialogueQuest підключено", "DialogueManager")

func start_dialogue(timeline_name: String) -> bool:
	"""Запускає діалог за повним шляхом res://dialogue_quest/<id>.dqd.
	Якщо інший діалог ще йде — ставить у чергу: одночасні запити (тригер, що міняє стан І грає
	свій діалог, а стан теж запускає діалог) грають по черзі. Раніше другий запит губився, а
	перед відмовою ще й ховав і скидав ЖИВЕ вікно першого: гравець бачив порожнечу, лишався
	заблокованим, а діалог висів. Активний діалог не перебиваємо й не «відновлюємо» силоміць (D131)."""
	if is_dialogue_active():
		if not _queue.has(timeline_name):
			_queue.append(timeline_name)
		return true
	_find_dialogue_system_in_scene()
	current_dialogue_box.set_text("")
	current_dialogue_box.set_name_text("")
	current_dialogue_box.set_portrait_image(null)
	current_dialogue_box.visible = true
	# dialogue_started шле _on_dialogue_quest_started (колбек DialogueQuest).
	current_dialogue_player.play(timeline_name)
	return true

func _on_dialogue_quest_started(dialogue_id: String):
	"""Обработчик начала диалога из DialogueQuest"""
	dialogue_started.emit(dialogue_id)
	print("💬 DialogueManager: DialogueQuest начал диалог '", dialogue_id, "'")

	# Ставим гравця на паузу під час діалогу
	_pause_player_for_dialogue()

func _pause_player_for_dialogue():
	"""Призупиняє управління гравцем під час діалогу"""
	DebugLogger.info("💬 DialogueManager: Блокування вводу гравця...", "DialogueManager")

	# Використовуємо call_group для надійності (викличе метод у всіх вузлів в групі PLAYER)
	get_tree().call_group(GameGroups.PLAYER, "set_movement_enabled", false)

func _on_dialogue_quest_ended(dialogue_id: String):
	"""Обработчик завершения диалога из DialogueQuest"""
	# Скрываем DialogueBox после завершения диалога
	if current_dialogue_box and is_instance_valid(current_dialogue_box):
		current_dialogue_box.visible = false
		current_dialogue_box.set_text("")
		current_dialogue_box.set_name_text("")
		current_dialogue_box.set_portrait_image(null)
		print("💬 DialogueManager: DialogueBox скрыт после завершения диалога '", dialogue_id, "'")

	# DialogueQuest шле dialogue_ended ДО того, як звільнить плеєр (current_dialogue, _lock).
	# Слухачі часто одразу запускають наступну розмову (Village: Outside → Healing), тож
	# «кінець» віддаємо наприкінці кадру, коли плеєр уже вільний. Раніше це «лагодив»
	# auto-recovering у start_dialogue(): скидав _lock силоміць.
	dialogue_finished.emit.call_deferred(dialogue_id)
	print("💬 DialogueManager: DialogueQuest завершил диалог '", dialogue_id, "'")

	# Відновлюємо управління гравцем після діалогу
	_unpause_player_after_dialogue()

	# Отправляем сигнал через EventBus (autoload, не Engine-синглтон —
	# has_singleton() тут теж завжди був false)
	EventBus.dialogue_finished.emit.call_deferred(dialogue_id)
	# Після слухачів «кінця» (вони можуть самі запустити наступну розмову) — наступний із черги.
	_start_next_queued.call_deferred()

func _start_next_queued() -> void:
	if _queue.is_empty() or is_dialogue_active():
		return
	start_dialogue(_queue.pop_front())

func _unpause_player_after_dialogue():
	"""Відновлює управління гравцем після діалогу"""
	DebugLogger.info("💬 DialogueManager: Відновлення управління гравцем...", "DialogueManager")

	# Використовуємо call_group для надійності
	get_tree().call_group(GameGroups.PLAYER, "set_movement_enabled", true)


func _on_dialogue_quest_signal(params: Array):
	"""Обработчик сигналов из DialogueQuest"""
	# params[0] - имя сигнала, params[1..] - аргументы
	if params.size() > 0:
		var signal_name = params[0] as String
		match signal_name:
			"choice_selected":
				if params.size() > 1:
					var choice_index = params[1] as int
					dialogue_choice_selected.emit(choice_index)
			_:
				# Другие сигналы можно обработать здесь
				pass

func is_dialogue_active() -> bool:
	"""Проверяет, активен ли диалог"""
	if current_dialogue_player and is_instance_valid(current_dialogue_player):
		return current_dialogue_player.current_dialogue != ""
	return false
