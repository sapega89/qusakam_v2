extends Area2D

## Річ у місті, яку можна тикнути (D740, Sapega 2026-10-26 «щоб можна було щось кудись тикнути»): поруч — підказка
## InteractableComponent, interact — дія за [member kind]. Власного арту в цих речей ще немає: у світі — блиск (D446)
## над тим, що намальовано на фоні.
##   NOTICE_BOARD — оголошення (модалка misc_popup): [member title] і [member lines];
##   WELL — ковток лікує, як [member item_id] (items.json effect.value), раз за візит у кімнату;
##   FRUIT_STALL — купити [member item_id] за його buy_price (монети → інвентар);
##   CAT — погладити: мурчання в облачку й серце над котом;
##   CRATE — обшукати раз за гру: [member coins] монет (стан кімнати, як у Chest);
##   SHRINE — подивитись: одна репліка в облачку.

signal used(kind: Kind)

const EMOTE := preload("res://SampleProject/Scenes/FX/Emote.tscn")

enum Kind { NOTICE_BOARD, WELL, FRUIT_STALL, CAT, CRATE, SHRINE }

@export var kind: Kind = Kind.NOTICE_BOARD
## Заголовок модалки (ключ .po) — дошка оголошень.
@export var title: String = ""
## Тексти (ключі .po): оголошення дошки; репліка криниці / прилавка (і «бракує монет») / кота / ящика / вівтаря.
@export var lines: PackedStringArray = PackedStringArray()
## Предмет криниці (скільки лікує) і прилавка (що продає).
@export var item_id: String = ""
## Монети в ящику.
@export var coins: int = 0
## Облачко й серце — над цією точкою (координати речі).
@export var bubble_anchor: Vector2 = Vector2(0, -72)

## Вже використано: криниця — до наступного візиту, ящик — назавжди.
var spent := false

@onready var _interactable: InteractableComponent = $Interactable
@onready var _glint: Sprite2D = $Sprite2D


func _ready() -> void:
	assert(not lines.is_empty(), "TownProp: no lines (%s)" % get_path())
	if kind in [Kind.WELL, Kind.FRUIT_STALL]:
		assert(not ItemDatabase.get_item(item_id).is_empty(), "TownProp: unknown item '%s' (%s)" % [item_id, get_path()])
	if kind == Kind.CRATE:
		assert(coins > 0, "TownProp: a crate without coins (%s)" % get_path())
		if Game.get_singleton().get_room_state(_room(), _state_key(), false):
			_spend()
	_interactable.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	match kind:
		Kind.NOTICE_BOARD:
			var texts: Array[String] = []
			for line: String in lines:
				texts.append(tr(line))
			ServiceLocator.get_ui_manager().show_modal(ModalTemplates.misc_popup(tr(title), "\n\n".join(texts)))
		Kind.WELL:
			Game.get_singleton().player.heal_damage(int(ItemDatabase.get_item(item_id).effect.value))
			AudioManager.play(&"potion")
			_say(lines[0])
			_spend()
		Kind.FRUIT_STALL:
			_buy()
		Kind.CAT:
			_say(lines[0])
			var emote: Node2D = EMOTE.instantiate()
			add_child(emote)
			emote.position = bubble_anchor - Vector2(0, UITokens.EMOTE_GAP)
			emote.call(&"pop", &"love")
		Kind.CRATE:
			ServiceLocator.get_inventory_manager().add_coins(coins)
			AudioManager.play(&"coin")
			Game.get_singleton().set_room_state(_room(), _state_key(), true)
			_say(lines[0])
			_spend()
			ServiceLocator.get_ui_manager().show_modal(ModalTemplates.items_obtained(
					["%s × %d" % [ItemDatabase.get_item_name("coin"), coins]] as Array[String]))
		Kind.SHRINE:
			_say(lines[0])
	used.emit(kind)


## Ціна — buy_price предмета (items.json); бракує монет — продавець каже про це (lines[1]).
func _buy() -> void:
	var inventory := ServiceLocator.get_inventory_manager()
	if not inventory.spend_coins(int(ItemDatabase.get_item(item_id).buy_price)):
		_say(lines[1])
		return
	inventory.add_item(item_id, 1)
	AudioManager.play(&"coin")
	_say(lines[0])


func _say(line: String) -> void:
	var dm := ServiceLocator.get_dialogue_manager()
	dm.end_chatter(self)  # нове натискання — нова репліка, а не тиша, доки догорить стара
	dm.say_line_in_passing(self, tr(line), bubble_anchor)


func _spend() -> void:
	spent = true
	_interactable.enabled = false
	_glint.visible = false


func _room() -> String:
	return get_node(^"/root/MetSys").map_data.get_room_from_scene_path(owner.scene_file_path, false)


func _state_key() -> String:
	return "searched_%s" % name
