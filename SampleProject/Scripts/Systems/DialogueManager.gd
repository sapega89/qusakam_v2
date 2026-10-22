extends Node
class_name GameDialogueManager
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")

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
	if not current_dialogue_box.text_shown.is_connected(_on_letter_shown):
		current_dialogue_box.text_shown.connect(_on_letter_shown)
		current_dialogue_box.all_text_shown.connect(_on_line_shown)
	_connect_dialogue_quest_signals()
	return true


## Літера репліки з'явилась у вікні — бурмотіння голосом мовця (D277). Мовця вікно знає лише за ім'ям.
func _on_letter_shown(count: int) -> void:
	var text: String = current_dialogue_box.get_text()
	if count < 1 or count > text.length():
		return  # візуальні символи без літери тексту (BBCode)
	var hooks: Node = AudioManager.hooks
	hooks.letter(hooks.speaker_from_name(current_dialogue_box.get_name_text()), text[count - 1])


## Репліку показано повністю — хто її сказав, того зустріли (журнал → Characters, D290).
func _on_line_shown() -> void:
	var speaker: String = AudioManager.hooks.speaker_from_name(current_dialogue_box.get_name_text())
	if speaker != "":
		JournalRecords.meet_person(speaker)

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

func start_dialogue(timeline_name: String, in_cloud: bool = false) -> bool:
	"""Запускає діалог за повним шляхом res://dialogue_quest/<id>.dqd.
	Якщо інший діалог ще йде — ставить у чергу: одночасні запити (тригер, що міняє стан І грає
	свій діалог, а стан теж запускає діалог) грають по черзі. Раніше другий запит губився, а
	перед відмовою ще й ховав і скидав ЖИВЕ вікно першого: гравець бачив порожнечу, лишався
	заблокованим, а діалог висів. Активний діалог не перебиваємо й не «відновлюємо» силоміць (D131).
	[param in_cloud] — розмова кат-сцени в облачку над героєм замість вікна (D263): набирається, як у вікні,
	«далі» — dq_accept, герой стоїть і не рухається до кінця."""
	if is_dialogue_active() or _bubble_playing:
		assert(not in_cloud, "DialogueManager: a cloud talk cannot be queued (%s)" % timeline_name)
		if not _queue.has(timeline_name):
			_queue.append(timeline_name)
		return true
	# Розмова (вікно, монолог, облачко кат-сцени) перебиває репліки мимохідь (BACKLOG 35).
	_end_all_chatter()
	if in_cloud:
		_play_bubbles(timeline_name, true)
		return true
	if _is_monologue(timeline_name):
		_play_bubbles(timeline_name)
		return true
	_find_dialogue_system_in_scene()
	current_dialogue_box.set_text("")
	current_dialogue_box.set_name_text("")
	current_dialogue_box.set_portrait_image(null)
	current_dialogue_box.visible = true
	# dialogue_started шле _on_dialogue_quest_started (колбек DialogueQuest). Файл — мовою гри, а id розмови
	# лишається українським шляхом, який чекають слухачі dialogue_finished (DialoguePaths, BACKLOG 31).
	var sections: Array[DQDqdParser.DqdSection] = DQDqdParser.parse_from_file(DialoguePaths.localized(timeline_name))
	assert(not sections.is_empty(), "DialogueManager: %s has no lines" % timeline_name)
	current_dialogue_player.play_sections(sections, timeline_name)
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
	if _queue.is_empty() or is_dialogue_active() or _bubble_playing:
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

## Пропуск кат-сцени (D308): cutscene_skip_prompt кличе щокадру — репліка набирається до кінця, наступного кадру
## йде далі (вікно — accept(), облачко — як dq_accept). Між розмовами пропускати нічого.
func skip_line() -> void:
	if _bubble_playing:
		_bubble_skip = true
	elif is_dialogue_active():
		current_dialogue_box.accept()

func is_dialogue_active() -> bool:
	"""Проверяет, активен ли диалог"""
	if is_replaying() or _cloud_talk:
		return true
	if current_dialogue_player and is_instance_valid(current_dialogue_player):
		return current_dialogue_player.current_dialogue != ""
	return false


# ── Перечитати розмову (D158, D161) ──────────────────────────────────────────
# Лише показ: те саме вікно й ті самі клавіші (dq_accept), але без DialogueQuest —
# dialogue_started / dialogue_finished не шлються, і сцени, що слухають кінець розмови,
# не перемикають свої стани вдруге.

signal replay_finished

## preload, а не class_name: глобальний кеш класів редактора може ще не знати нового скрипта.
const DQD_READER := preload("res://SampleProject/Scripts/Systems/dqd_reader.gd")

var _replay_lines: Array[Dictionary] = []
var _replaying := false


func is_replaying() -> bool:
	return _replaying


## Показує репліки [param path] і потім [param tail] (напр. поточну ціль). Повертається після останньої.
func replay(path: String, tail: Array[Dictionary] = []) -> void:
	_find_dialogue_system_in_scene()
	_replay_lines = DQD_READER.lines(path) + tail
	_replaying = true
	_pause_player_for_dialogue()
	current_dialogue_box.visible = true
	DialogueQuest.Inputs.accept_pressed.connect(current_dialogue_box.accept)
	current_dialogue_box.proceed.connect(_show_next_replay_line)
	_show_next_replay_line()
	await replay_finished


func _show_next_replay_line() -> void:
	if _replay_lines.is_empty():
		_end_replay()
		return
	var line: Dictionary = _replay_lines.pop_front()
	var speaker: DQCharacter = DialogueQuest.CharacterDB.get_character_from_id(line.speaker) if line.speaker != "" else null
	current_dialogue_box.set_name_text(speaker.character_name if speaker else "")
	if speaker:
		current_dialogue_box.set_name_color(speaker.color)
	current_dialogue_box.set_text(line.text)
	current_dialogue_box.start_progressing()  # набирається, як і звичайна репліка (D254)


func _end_replay() -> void:
	DialogueQuest.Inputs.accept_pressed.disconnect(current_dialogue_box.accept)
	current_dialogue_box.proceed.disconnect(_show_next_replay_line)
	current_dialogue_box.visible = false
	current_dialogue_box.set_text("")
	current_dialogue_box.set_name_text("")
	_replaying = false
	_unpause_player_after_dialogue()
	replay_finished.emit()


# ── Монологи облачками (D178) ────────────────────────────────────────────────
# Розмова, де кожну репліку каже гравець, іде облачком над його головою: репліки міняються
# самі за часом, гравець ходить, вікно діалогу не відкривається. Для сцен це звичайний діалог:
# dialogue_started / dialogue_finished з тим самим шляхом, черга та сама.

const SPEECH_BUBBLE := preload("res://SampleProject/UI/Components/speech_bubble.gd")
## Мовець-гравець. Два id — дубль одного персонажа, який має злити D114.
const PLAYER_SPEAKERS: Array[String] = ["KUSAKAM"]

var _bubble_playing := false
## Множник часу реплік. Гра — 1.0; verify_*.gd ставлять 0, щоб не чекати секунди на кожну.
var bubble_time_scale: float = 1.0


## Enter / клік (dq_accept, як у вікні діалогу) показує наступну репліку облачка одразу —
## сцена чекає кінця монологу, тож без цього гравець стояв, доки догорять усі (Sapega, 2026-10-16).
var _bubble_skip := false
## Облачко поточного монологу. Воно дочірнє гравцеві, а цикл реплік — тут, в autoload, що
## переживає сцену: вихід у меню / нова гра / завантаження звільняли облачко посеред монологу,
## цикл кликав show_line() на звільненому вузлі, а _bubble_playing лишався true назавжди —
## кожен наступний діалог ставав у чергу й не грав.
var _bubble: Node2D = null
## Йде розмова кат-сцени в облачку (D263): для решти гри це діалог — меню, NPC, асист закриті.
var _cloud_talk := false
## Сценічна ремарка на початку репліки («[Катсцена] …») — у вікні її видно, у мовленні облачка їй не місце.
var _stage_tag := RegEx.create_from_string("^\\[[^\\]]*\\]\\s*")

func _on_bubble_gone(bubble: Node2D) -> void:
	if bubble != _bubble:
		return  # монолог закінчився штатно, вузол просто прибирається
	# Сцена пішла посеред монологу; хто чекав його кінця й діалогів у черзі — пішли з нею.
	_bubble = null
	_bubble_playing = false
	_cloud_talk = false
	_queue.clear()

func _unhandled_input(event: InputEvent) -> void:
	if _bubble_playing and not get_tree().paused and event.is_action_pressed(&"dq_accept"):
		_bubble_skip = true
		get_viewport().set_input_as_handled()


func is_bubble_playing() -> bool:
	return _bubble_playing


func _is_monologue(path: String) -> bool:
	var lines: Array[Dictionary] = DQD_READER.lines(path)
	return not lines.is_empty() and lines.all(func(line: Dictionary) -> bool: return line.speaker in PLAYER_SPEAKERS)


## [param talk] (D263): репліка набирається з тією ж швидкістю, що й у вікні (D254, не пропускається), далі —
## лише dq_accept; гравець заблокований. Інакше — монолог D178: репліки міняються за часом, гравець ходить.
func _play_bubbles(path: String, talk: bool = false) -> void:
	_bubble_playing = true
	_cloud_talk = talk
	_find_dialogue_system_in_scene()  # вікно мусить бути підключене й для наступних розмов
	if talk:
		_pause_player_for_dialogue()
	dialogue_started.emit(path)
	var bubble: Node2D = SPEECH_BUBBLE.new()
	_bubble = bubble
	bubble.tree_exiting.connect(_on_bubble_gone.bind(bubble))
	Game.get_singleton().player.add_child(bubble)
	bubble.position.y = UITokens.BUBBLE_OFFSET_Y
	var letters_per_second: float = current_dialogue_box.settings.letters_per_second
	var speaker := [""]  # мовець поточної репліки для бурмотіння (лямбда бачить масив, не локальну змінну)
	bubble.typed.connect(func(typed_text: String, count: int) -> void:
		AudioManager.hooks.letter(speaker[0], typed_text[count - 1]))
	for line in DQD_READER.lines(path):
		var text: String = _stage_tag.sub(line.text, "")
		speaker[0] = line.speaker
		await bubble.show_line(text)
		if talk:
			# Облачко висить над героєм — у такій розмові говорить лише він (або ремарка того, що він бачить).
			assert(line.speaker == "" or line.speaker in PLAYER_SPEAKERS, "DialogueManager: cloud talk %s has speaker %s" % [path, line.speaker])
			await bubble.type_out(text.length() / letters_per_second * bubble_time_scale)
			_bubble_skip = false
			while not _bubble_skip and _bubble == bubble:
				await get_tree().process_frame
			if _bubble != bubble:
				return
			continue
		# process_always = false: відкрите меню (пауза) тримає репліку.
		var timer := get_tree().create_timer(SPEECH_BUBBLE.seconds_for(line.text) * bubble_time_scale, false)
		_bubble_skip = false
		while timer.time_left > 0.0 and not _bubble_skip and _bubble == bubble:
			await get_tree().process_frame
		if _bubble != bubble:
			return  # облачко пішло разом зі сценою — _on_bubble_gone уже все скинув
	_bubble = null
	bubble.queue_free()
	_bubble_playing = false
	_cloud_talk = false
	if talk:
		_unpause_player_after_dialogue()
	dialogue_finished.emit.call_deferred(path)
	EventBus.dialogue_finished.emit.call_deferred(path)
	_start_next_queued.call_deferred()


# ── Репліки NPC мимохідь (BACKLOG 35, Q48) ───────────────────────────────────
# NPC каже щось, коли герой проходить повз: облачко D263 над NPC, не вікно діалогу. Це не діалог —
# is_dialogue_active() його не бачить, гравець, меню й NPC не блокуються, у чергу не стає.
# Розмову, яку почав гравець (Talk / Quest / сюжет), і далі веде вікно; вона закриває ці облачка.

## instance_id мовця → його облачко.
var _chatter: Dictionary = {}


## Репліки [param path] над [param speaker] (вістря хвоста — [param anchor] у координатах мовця), кожна
## на SPEECH_BUBBLE.seconds_for(); пауза тримає. false — зараз іде розмова чи цей NPC уже говорить:
## мимохідь не перебиває і не чекає.
func say_in_passing(speaker: Node2D, path: String, anchor: Vector2) -> bool:
	if is_dialogue_active() or _bubble_playing or _chatter.has(speaker.get_instance_id()):
		return false
	var lines: Array[Dictionary] = DQD_READER.lines(path)
	if lines.is_empty():
		push_error("DialogueManager: chatter %s has no lines" % path)
		return false
	var bubble: Node2D = SPEECH_BUBBLE.new()
	_chatter[speaker.get_instance_id()] = bubble
	speaker.add_child(bubble)
	bubble.position = anchor
	_run_chatter(speaker.get_instance_id(), bubble, lines)
	return true


func _run_chatter(id: int, bubble: Node2D, lines: Array[Dictionary]) -> void:
	for line in lines:
		if not is_instance_valid(bubble) or _chatter.get(id) != bubble:
			return  # мовець пішов зі сценою або розмова закрила облачко
		await bubble.show_line(_stage_tag.sub(line.text, ""))
		# process_always = false: відкрите меню (пауза) тримає репліку.
		await get_tree().create_timer(SPEECH_BUBBLE.seconds_for(line.text) * bubble_time_scale, false).timeout
	if _chatter.get(id) == bubble:
		_drop_chatter(id)


## Облачко мимохідь над [param speaker] або null.
func chatter_bubble(speaker: Node2D) -> Node2D:
	return _chatter.get(speaker.get_instance_id())


## Мовець заговорив по-справжньому (відкрив меню) — його репліка мимохідь зникає.
func end_chatter(speaker: Node2D) -> void:
	_drop_chatter(speaker.get_instance_id())


func _end_all_chatter() -> void:
	for id in _chatter.keys():
		_drop_chatter(id)


func _drop_chatter(id: int) -> void:
	var bubble: Variant = _chatter.get(id)
	_chatter.erase(id)
	if is_instance_valid(bubble):
		(bubble as Node2D).queue_free()
