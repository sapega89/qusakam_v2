extends Area2D
class_name NpcBase

## Спільна поведінка NPC з меню дій (Merchant, Blacksmith).
## Figma: npc-menu-merchant 164:1302, npc-menu-blacksmith 176:1357.
##   поруч → UI/Interaction/Prompt → interact → NpcActionMenu (під паузою) → дія.
##
## Нащадки перевизначають menu_entries() і _on_npc_choice(). Показуються лише пункти
## з реальним наповненням; якщо пунктів немає — немає й підказки.

## DQD-діалог для пункту Talk. Порожньо — пункту Talk немає (без вигаданого вмісту).
@export var talk_dialogue: String = ""

@onready var interactable: InteractableComponent = $Interactable

var npc_menu: NpcActionMenu = null


func _ready() -> void:
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
	refresh_availability()


## Пункти меню: масив {id, label}. База дає лише Talk.
func menu_entries() -> Array:
	var entries: Array = []
	if talk_dialogue != "":
		entries.append({"id": &"talk", "label": "Talk"})
	return entries


## Вимикає підказку, якщо NPC нічого не може запропонувати.
func refresh_availability() -> void:
	interactable.enabled = not menu_entries().is_empty()


func _on_interacted() -> void:
	if npc_menu.visible or not _can_open_menu():
		return
	var entries := menu_entries()
	if entries.is_empty():
		return
	interactable.enabled = false
	npc_menu.setup(entries)
	npc_menu.open()
	get_tree().paused = true


## Нащадок може заборонити меню (напр. поки відкритий магазин).
func _can_open_menu() -> bool:
	return true


func _close_npc_menu() -> void:
	npc_menu.visible = false
	get_tree().paused = false
	refresh_availability()


func _on_menu_chosen(id: StringName) -> void:
	_close_npc_menu()
	if id == &"talk":
		var dm = ServiceLocatorHelper.get_manager("get_dialogue_manager")
		if dm and dm.has_method("start_dialogue"):
			dm.start_dialogue(talk_dialogue)
		return
	_on_npc_choice(id)


func _on_npc_choice(_id: StringName) -> void:
	pass
