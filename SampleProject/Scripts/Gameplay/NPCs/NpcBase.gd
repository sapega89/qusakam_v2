extends Area2D
class_name NpcBase

## Спільна поведінка NPC з меню дій (Merchant, Blacksmith).
## Figma: npc-menu-merchant 164:1302, npc-menu-blacksmith 176:1357.
##   поруч → UI/Interaction/Prompt → interact → NpcActionMenu → дія.
## Меню без паузи: світ живе, гравець ходить; відійшов від NPC — меню закрилось (D155).
##
## Нащадки перевизначають menu_entries() і _on_npc_choice(). Показуються лише пункти
## з реальним наповненням; якщо пунктів немає — немає й підказки.

## load(), не preload: сервіс тягне Game, а тест-скрипти компілюють NpcBase ще до автолоадів.
const TASKS_PATH := "res://SampleProject/Scripts/Tasks/task_service.gd"
const NpcActivity := preload("res://SampleProject/Scripts/Gameplay/NPCs/NpcActivity.gd")

## DQD-діалог для пункту Talk. Порожньо — пункту Talk немає (без вигаданого вмісту).
@export var talk_dialogue: String = ""
## Хто цей NPC у quests.json (giver). Є відкрите завдання — є пункт Quest (D161, D175).
@export var task_giver: String = ""
## Хто це в DialogueQuest (character_id) — його голос вітає героя, коли той сам заговорив (D277).
@export var character_id: String = ""

## Поза розмови (talk) на аркуші дивиться ліворуч — інакше праворуч; NPC повертається нею до героя (D243).
@export var profile_faces_left: bool = false

@onready var interactable: InteractableComponent = $Interactable
## Що NPC робить сам (BACKLOG 5, D295) і поза розмови — поки відкрите його меню, екран чи розмова поруч.
@onready var activity: NpcActivity = $Activity
@onready var sprite: Sprite2D = $Sprite2D

## Куди NPC дивиться у сцені, коли ні з ким не говорить.
var _rest_flip: bool = false

var npc_menu: NpcActionMenu = null


func _ready() -> void:
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
	npc_menu.cancelled.connect(_close_npc_menu)
	interactable.player_exited.connect(_on_player_left)
	refresh_availability()


func _process(_delta: float) -> void:
	var now := is_talking()
	if now == activity.talking:
		return
	activity.talking = now
	if now:
		var hero := get_tree().get_first_node_in_group(GameGroups.PLAYER) as Node2D
		sprite.flip_h = (hero.global_position.x < global_position.x) != profile_faces_left
	else:
		sprite.flip_h = _rest_flip


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
	if task_giver != "" and not load(TASKS_PATH).open_tasks(task_giver).is_empty():
		entries.append({"id": &"task", "label": "Quest"})
	return entries


## Вимикає підказку, якщо NPC нічого не може запропонувати.
func refresh_availability() -> void:
	interactable.enabled = not menu_entries().is_empty()


func _on_interacted() -> void:
	# Під час розмови E не відкриває меню поверх неї.
	var dialogue_running: bool = ServiceLocatorHelper.get_service_locator().get_dialogue_manager().is_dialogue_active()
	if npc_menu.visible or not _can_open_menu() or dialogue_running:
		return
	var entries := menu_entries()
	if entries.is_empty():
		return
	interactable.enabled = false
	npc_menu.setup(entries)
	npc_menu.open()
	# Герой сам підійшов і заговорив — привітання. Катсцену першої зустрічі запускає кімната, не цей шлях.
	get_node(^"/root/AudioManager").hooks.greet(character_id)  # не ідентифікатор: тести компілюють NpcBase до автолоадів


## Нащадок може заборонити меню (напр. поки відкритий магазин).
func _can_open_menu() -> bool:
	return true


func _close_npc_menu() -> void:
	npc_menu.visible = false
	refresh_availability()


func _on_player_left() -> void:
	if npc_menu.visible:
		_close_npc_menu()


func _on_menu_chosen(id: StringName) -> void:
	_close_npc_menu()
	if id == &"talk":
		ServiceLocatorHelper.get_service_locator().get_dialogue_manager().start_dialogue(talk_dialogue)
		return
	if id == &"task":
		_on_task_chosen()
		return
	_on_npc_choice(id)


## Quest: видати завдання → нагадати його з ціллю → здати, коли умову виконано.
## ponytail: завдання NPC іде по одному (after) — список із ромбиком (D161) тоді, коли їх стане кілька.
func _on_task_chosen() -> void:
	var dm: Node = ServiceLocatorHelper.get_service_locator().get_dialogue_manager()
	var TASKS: GDScript = load(TASKS_PATH)
	var task: Dictionary = TASKS.open_tasks(task_giver)[0]
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
