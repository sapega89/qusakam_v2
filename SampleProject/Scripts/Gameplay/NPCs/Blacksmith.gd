extends NpcBase
class_name Blacksmith

## ⚒️ Blacksmith — окремий NPC (D69), не режим магазину.
## Figma npc-menu-blacksmith 176:1357: Talk / Quest / Craft / Enchant.
##   Craft   → екран крафту (slice 4); показується, лише коли екран існує.
##   Enchant → екран зачарування (D94, D115, design/enchanting_plan.md); так само за наявності.
##   Quest   → приховано: квестовий рушій неактивний (D56).
##   Talk    → лише з заданим DQD-діалогом (NpcBase).

const CRAFTING_SCENE := "res://SampleProject/Scenes/Crafting/crafting_menu.tscn"
const ENCHANTING_SCENE := "res://SampleProject/Scenes/Enchanting/enchanting_menu.tscn"

## Сцени екранів. Змінні — щоб тести могли підставити свої.
var crafting_scene_path: String = CRAFTING_SCENE
var enchanting_scene_path: String = ENCHANTING_SCENE

## Відкритий екран коваля (крафт або зачарування) — одночасно лише один.
var is_screen_open := false
var screen_instance: Control = null
var _screen_layer: CanvasLayer = null


func _ready() -> void:
	super._ready()
	add_to_group(&"blacksmith")


func crafting_available() -> bool:
	return _exists(crafting_scene_path)


func enchanting_available() -> bool:
	return _exists(enchanting_scene_path)


func _exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


func menu_entries() -> Array:
	var entries := super.menu_entries()
	if crafting_available():
		entries.append({"id": &"craft", "label": "Craft"})
	if enchanting_available():
		entries.append({"id": &"enchant", "label": "Enchant"})
	return entries


func _can_open_menu() -> bool:
	return not is_screen_open


func _on_npc_choice(id: StringName) -> void:
	match id:
		&"craft":
			open_screen(crafting_scene_path)
		&"enchant":
			open_screen(enchanting_scene_path)


## Відкриває екран коваля в окремому CanvasLayer під паузою — як магазин у Merchant.
func open_screen(path: String) -> void:
	if is_screen_open or not _exists(path):
		return
	var scene: PackedScene = load(path)
	var host := get_tree().current_scene
	if scene == null or host == null:
		push_error("Blacksmith: cannot open %s" % path)
		return
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = 13
	_screen_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(_screen_layer)
	screen_instance = scene.instantiate()
	_screen_layer.add_child(screen_instance)
	screen_instance.closed.connect(close_screen, CONNECT_ONE_SHOT)
	is_screen_open = true
	interactable.enabled = false
	get_tree().paused = true


func close_screen() -> void:
	if not is_screen_open:
		return
	is_screen_open = false
	if _screen_layer and is_instance_valid(_screen_layer):
		_screen_layer.queue_free()
	_screen_layer = null
	screen_instance = null
	get_tree().paused = false
	refresh_availability()
