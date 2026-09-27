extends NpcBase
class_name Blacksmith

## ⚒️ Blacksmith — окремий NPC (D69), не режим магазину.
## Figma npc-menu-blacksmith 176:1357: Talk / Quest / Craft / Enchant.
##   Craft   → екран крафту (slice 4); показується, лише коли екран існує.
##   Enchant → приховано: Enchanting поза поточним обсягом (D82, Q8).
##   Quest   → приховано: квестовий рушій неактивний (D56).
##   Talk    → лише з заданим DQD-діалогом (NpcBase).

const CRAFTING_SCENE := "res://SampleProject/Scenes/Crafting/crafting_menu.tscn"
const ENCHANT_ENABLED := false

## Сцена екрана крафту. Змінна — щоб тести могли підставити свою.
var crafting_scene_path: String = CRAFTING_SCENE

var is_crafting_open := false
var crafting_instance: Control = null
var _crafting_layer: CanvasLayer = null


func _ready() -> void:
	super._ready()
	add_to_group(&"blacksmith")


func crafting_available() -> bool:
	return crafting_scene_path != "" and ResourceLoader.exists(crafting_scene_path)


func menu_entries() -> Array:
	var entries := super.menu_entries()
	if crafting_available():
		entries.append({"id": &"craft", "label": "Craft"})
	if ENCHANT_ENABLED:
		entries.append({"id": &"enchant", "label": "Enchant"})
	return entries


func _can_open_menu() -> bool:
	return not is_crafting_open


func _on_npc_choice(id: StringName) -> void:
	if id == &"craft":
		open_crafting()


## Відкриває екран крафту в окремому CanvasLayer під паузою — як магазин у Merchant.
func open_crafting() -> void:
	if is_crafting_open or not crafting_available():
		return
	var scene: PackedScene = load(crafting_scene_path)
	var host := get_tree().current_scene
	if scene == null or host == null:
		push_error("Blacksmith: cannot open crafting (%s)" % crafting_scene_path)
		return
	_crafting_layer = CanvasLayer.new()
	_crafting_layer.layer = 13
	_crafting_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(_crafting_layer)
	crafting_instance = scene.instantiate()
	_crafting_layer.add_child(crafting_instance)
	if crafting_instance.has_signal("closed"):
		crafting_instance.closed.connect(close_crafting, CONNECT_ONE_SHOT)
	is_crafting_open = true
	interactable.enabled = false
	get_tree().paused = true


func close_crafting() -> void:
	if not is_crafting_open:
		return
	is_crafting_open = false
	if _crafting_layer and is_instance_valid(_crafting_layer):
		_crafting_layer.queue_free()
	_crafting_layer = null
	crafting_instance = null
	get_tree().paused = false
	refresh_availability()
