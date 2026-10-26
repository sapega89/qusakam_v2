extends Area2D
class_name NpcBase

## Спільна поведінка NPC з меню дій (Merchant, Blacksmith).
## Figma: npc-menu-merchant 164:1302, npc-menu-blacksmith 176:1357.
##   поруч → NpcActionMenu відкривається саме, без підказки [E] (D454) → interact → дія.
## Меню без паузи: світ живе, гравець біжить і стрибає; відійшов від NPC — меню закрилось (D155).
## D735: перша клавіша меню (W/S, вгору/вниз) бере його — герой стоїть без руху й дій, доки пункт не вибрано чи меню не закрито.
## Є що дати — знак над головою (D442, D452) і репліка мимохідь, коли герой пробігає поруч.
##
## Нащадки перевизначають menu_entries(), quest_marker() і _on_npc_choice(). Показуються лише пункти
## з реальним наповненням; якщо пунктів немає — немає й меню.

## load(), не preload: сервіс тягне Game, а тест-скрипти компілюють NpcBase ще до автолоадів.
const TASKS_PATH := "res://SampleProject/Scripts/Tasks/task_service.gd"
const GAME_PATH := "res://SampleProject/Scripts/Game.gd"
const NpcActivity := preload("res://SampleProject/Scripts/Gameplay/NPCs/NpcActivity.gd")
const QuestMarker := preload("res://SampleProject/UI/Components/quest_marker.gd")
const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")

## DQD-діалог для пункту Talk. Порожньо — пункту Talk немає (без вигаданого вмісту).
@export var talk_dialogue: String = ""
## Хто цей NPC у quests.json (giver). Є відкрите завдання — є пункт Quest (D161, D175).
@export var task_giver: String = ""
## BACKLOG 35 (Q48): .dqd з репліками, які NPC каже мимохідь, коли герой підходить, — облачко над ним,
## не вікно. Раз за появу NPC у кімнаті. Порожньо — NPC мовчить (реплік мимохідь ще ніхто не написав).
@export var chatter_dialogue: String = ""
## D452: .dqd, яким NPC гукає героя мимохідь, поки має що дати (є знак над головою); замість chatter_dialogue.
@export var quest_bark_dialogue: String = ""
## Хто це в DialogueQuest (character_id) — його голос вітає героя, коли той сам заговорив (D277).
@export var character_id: String = ""

## Поза розмови (talk) на аркуші дивиться ліворуч — інакше праворуч; NPC повертається нею до героя (D243).
@export var profile_faces_left: bool = false

## Стоїть у мапі лише з цим прапорцем (порожньо — завжди) і зникає з другим (порожньо — ніколи):
## торговець каравану — на дорозі до бою біля брами, у місті після нього (D311).
@export var shown_with_flag: String = ""
@export var gone_with_flag: String = ""

@onready var interactable: InteractableComponent = $Interactable
## Що NPC робить сам (BACKLOG 5, D295) і поза розмови — поки відкрите його меню, екран чи розмова поруч.
@onready var activity: NpcActivity = $Activity
@onready var sprite: Sprite2D = $Sprite2D

## Куди NPC дивиться у сцені, коли ні з ким не говорить.
var _rest_flip: bool = false

var npc_menu: NpcActionMenu = null
## Знак над головою: що в NPC є взяти (D442, D452).
var marker: QuestMarker = null
## Репліку мимохідь уже сказано в цій кімнаті.
var _chatted: bool = false
## Привітання голосом уже звучало в цій кімнаті (D277: раз, коли герой уперше підійшов до меню).
var _greeted: bool = false
## Гравець закрив меню (ui_cancel) — саме воно не відкривається, поки герой не відійде; E відкриває знову.
var _dismissed: bool = false
## Меню взяте (D735) — героя тримаємо ми, ми ж і відпускаємо.
var _hero_held: bool = false


func _ready() -> void:
	if not _here():
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
		return
	_rest_flip = sprite.flip_h
	if not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	npc_menu = NpcActionMenu.new()
	npc_menu.name = "NpcMenu"
	npc_menu.visible = false
	npc_menu.z_index = 20
	npc_menu.position = UITokens.NPC_MENU_OFFSET
	add_child(npc_menu)
	npc_menu.chosen.connect(_on_menu_chosen)
	npc_menu.cancelled.connect(_dismiss_npc_menu)
	npc_menu.engaged.connect(_hold_hero)
	interactable.player_exited.connect(_on_player_left)
	interactable.player_entered.connect(_on_player_came)
	interactable.show_prompt = false  # D454: меню відкривається саме — підказки [E] немає
	marker = QuestMarker.new()
	marker.name = "QuestMarker"
	marker.z_index = 20
	add_child(marker)
	marker.position = chatter_anchor() - Vector2(0, UITokens.QUEST_MARK_GAP) * WORLD_UI.screen_scale(self)
	if task_giver != "":
		# Завдання взяли (прапорець task_<id>_taken) — знак зникає одразу.
		load(GAME_PATH).get_singleton().quest_flag_changed.connect(func(_id: String, _value: Variant) -> void: refresh_availability())
	refresh_availability()


## Чи стоїть NPC у мапі за прапорцями shown_with_flag / gone_with_flag.
func _here() -> bool:
	if shown_with_flag == "" and gone_with_flag == "":
		return true  # Game не питаємо: тести ставлять NPC і без гри
	var game: Node = load(GAME_PATH).get_singleton()  # load(): Game тягне NpcBase — preload замкнув би коло
	return (shown_with_flag == "" or game.get_quest_flag(shown_with_flag)) and not (gone_with_flag != "" and game.get_quest_flag(gone_with_flag))


func _process(_delta: float) -> void:
	if npc_menu.visible and not _menu_allowed():
		_close_npc_menu()  # поверх стала розмова чи модалка — меню повернеться (і з фокусом), коли вони скінчаться
	elif _wants_menu():
		_open_menu()
	# Облачко репліки мимохідь стоїть там само, де знак, — поки NPC говорить, знак чекає.
	marker.visible = marker.kind != &"" and ServiceLocatorHelper.get_service_locator().get_dialogue_manager().chatter_bubble(self) == null
	var now := is_talking()
	if now == activity.talking:
		return
	activity.talking = now
	if now:
		var hero := get_tree().get_first_node_in_group(GameGroups.PLAYER) as Node2D
		sprite.flip_h = (hero.global_position.x < global_position.x) != profile_faces_left
	else:
		sprite.flip_h = _rest_flip


## D454: герой у зоні, меню закрите й не відкинуте, NPC є що запропонувати і ніщо інше не говорить —
## меню відкривається саме: щойно підійшов, після розмови, після екрана магазину чи кузні.
func _wants_menu() -> bool:
	if not interactable.player_nearby or npc_menu.visible or _dismissed or not interactable.enabled:
		return false
	return _menu_allowed()


func _menu_allowed() -> bool:
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	return _can_open_menu() and not sl.get_dialogue_manager().is_dialogue_active() \
			and sl.get_ui_manager().is_gameplay_input_allowed()


## Говорить: відкрите його меню чи екран (магазин, кузня) або йде розмова, а герой поруч.
func is_talking() -> bool:
	if npc_menu.visible or not _can_open_menu():
		return true
	return interactable.player_nearby and ServiceLocatorHelper.get_service_locator().get_dialogue_manager().is_dialogue_active()


## Пункти меню: масив {id, label}. База дає лише Talk.
func menu_entries() -> Array:
	var entries: Array = []
	if talk_dialogue != "":
		entries.append({"id": &"talk", "label": "Talk"})
	if not quest_rows().is_empty():
		entries.append({"id": &"task", "label": "Quest"})
	return entries


## Рядки списку Quest (D161): {id, label, main}. База — відкриті завдання NPC (D175), id «task:<id>», підпис —
## назва завдання; StoryNpc ставить перед ними основний квест (main — золотий ромбик).
func quest_rows() -> Array:
	var rows: Array = []
	if task_giver == "":
		return rows
	for task: Dictionary in load(TASKS_PATH).open_tasks(task_giver):
		rows.append({"id": StringName("task:" + task.id), "label": task.title, "main": false})
	return rows


## Знак над головою (D442, D452): &"story" — жовтий «!», &"side" — синій «!», &"oath" — герб, &"" — нічого.
## База: побічне завдання NPC (quests.json), якого ще не взяли. Нащадки додають сюжет і клятву.
func quest_marker() -> StringName:
	if task_giver == "":
		return &""
	var TASKS: GDScript = load(TASKS_PATH)
	for task: Dictionary in TASKS.open_tasks(task_giver):
		if TASKS.status(task) == "":
			return &"side"
	return &""


## Вимикає меню, якщо NPC нічого не може запропонувати; оновлює знак над головою.
func refresh_availability() -> void:
	interactable.enabled = not menu_entries().is_empty()
	marker.kind = quest_marker()


## Interact (E) поруч із NPC, чиє меню закрите: відкриває його знову, навіть відкинуте ui_cancel.
func _on_interacted() -> void:
	_dismissed = false
	_open_menu()


func _open_menu() -> void:
	# Під час розмови меню не відкривається поверх неї.
	if npc_menu.visible or not _menu_allowed():
		return
	var entries := menu_entries()
	if entries.is_empty():
		return
	interactable.enabled = false
	npc_menu.setup(entries)
	npc_menu.open()
	# Герой підійшов — меню і є початок розмови (D454); привітання голосом раз за кімнату, не на кожен підхід.
	if not _greeted:
		_greeted = true
		get_node(^"/root/AudioManager").hooks.greet(character_id)  # не ідентифікатор: тести компілюють NpcBase до автолоадів


## Нащадок може заборонити меню (напр. поки відкритий магазин).
func _can_open_menu() -> bool:
	return true


func _close_npc_menu() -> void:
	npc_menu.visible = false
	_release_hero()
	refresh_availability()


## D735: поки меню взяте, герой не ходить, не стрибає й не бʼє (той самий замок, що й у діалозі).
func _hold_hero() -> void:
	_hero_held = true
	get_tree().call_group(GameGroups.PLAYER, "set_movement_enabled", false)


## Відпускає, лише якщо тримали ми; поверх уже йде розмова — її замок лишається (DialogueManager відпустить сам).
func _release_hero() -> void:
	if not _hero_held:
		return
	_hero_held = false
	if not ServiceLocatorHelper.get_service_locator().get_dialogue_manager().is_dialogue_active():
		get_tree().call_group(GameGroups.PLAYER, "set_movement_enabled", true)


## ui_cancel: меню геть, доки герой не відійде (або не натисне E).
func _dismiss_npc_menu() -> void:
	_dismissed = true
	_close_npc_menu()


## Герой підійшов — NPC каже своє мимохідь (якщо зараз ніхто не говорить; інакше спробує наступного разу),
## і поруч з облачком одразу відкривається меню (D454).
func _on_player_came() -> void:
	_say_in_passing()
	_open_menu()


## Має що дати — гукає героя (D452), інакше звичайна репліка мимохідь (D338). Раз за кімнату.
func _say_in_passing() -> void:
	var lines := quest_bark_dialogue if quest_bark_dialogue != "" and quest_marker() != &"" else chatter_dialogue
	if lines == "" or _chatted:
		return
	_chatted = ServiceLocatorHelper.get_service_locator().get_dialogue_manager().say_in_passing(
			self, lines, chatter_anchor())


## Вістря хвоста облачка — над верхнім краєм спрайта NPC, посередині.
func chatter_anchor() -> Vector2:
	var rect: Rect2 = sprite.get_rect()
	return sprite.transform * Vector2(rect.get_center().x, rect.position.y)


## Кімната змінилась, поки меню було взяте, — героя не лишаємо замороженим.
func _exit_tree() -> void:
	_release_hero()


func _on_player_left() -> void:
	_dismissed = false
	if npc_menu.visible:
		_close_npc_menu()


func _on_menu_chosen(id: StringName) -> void:
	_close_npc_menu()
	# Герой вибрав дію — заговорив по-справжньому: репліка мимохідь зникає.
	ServiceLocatorHelper.get_service_locator().get_dialogue_manager().end_chatter(self)
	if id == &"talk":
		ServiceLocatorHelper.get_service_locator().get_dialogue_manager().start_dialogue(talk_dialogue)
		return
	if id == &"task":
		_on_quest_chosen()
		return
	_run_quest_row(id)


## Quest (D161): один рядок — одразу його розмова; кілька — список у тому самому меню, основний квест першим.
func _on_quest_chosen() -> void:
	var rows := quest_rows()
	if rows.size() == 1:
		_run_quest_row(rows[0].id)
		return
	interactable.enabled = false
	npc_menu.setup(rows)
	npc_menu.open()
	npc_menu.engage()  # список квестів гравець відкрив сам — меню вже його (D735)


## Рядок «task:<id>» — завдання NPC; будь-який інший id — дія нащадка (основний квест StoryNpc, Craft, Buy…).
func _run_quest_row(id: StringName) -> void:
	if String(id).begins_with("task:"):
		_on_task_chosen(String(id).trim_prefix("task:"))
	else:
		_on_npc_choice(id)


## Завдання [param task_id]: видати → нагадати його з ціллю → здати, коли умову виконано.
func _on_task_chosen(task_id: String) -> void:
	var dm: Node = ServiceLocatorHelper.get_service_locator().get_dialogue_manager()
	var TASKS: GDScript = load(TASKS_PATH)
	var task: Dictionary = TASKS.open_tasks(task_giver).filter(func(t: Dictionary) -> bool: return t.id == task_id)[0]
	if TASKS.status(task) != TASKS.ACTIVE:
		TASKS.take(task)
		dm.start_dialogue(_dqd(task.give_dialogue))
	elif TASKS.can_turn_in(task):
		TASKS.turn_in(task)
		dm.start_dialogue(_dqd(task.done_dialogue))
	else:
		var tail: Array[Dictionary] = [{"speaker": "", "text": tr("Current task: %s") % tr(task.objective)}]
		dm.replay(_dqd(task.give_dialogue), tail)


func _dqd(id: String) -> String:
	return "res://dialogue_quest/%s.dqd" % id


func _on_npc_choice(_id: StringName) -> void:
	pass
