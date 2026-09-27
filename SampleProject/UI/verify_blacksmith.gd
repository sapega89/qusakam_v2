extends SceneTree

## Самоперевірка slice 3: Blacksmith NPC (D69) без розміщення на мапі (D81).
##   godot --headless --path . --script res://SampleProject/UI/verify_blacksmith.gd
##
## Figma: npc-menu-blacksmith 176:1357, npc/blacksmith 141:1458.

const SCENE := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn"
const STUB_PATH := "user://verify_crafting_stub.tscn"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


## Тимчасова сцена крафту поза репозиторієм — лише щоб перевірити маршрут Craft.
func _make_stub() -> String:
	var script := GDScript.new()
	script.source_code = "extends Control\nsignal closed\n"
	script.reload()
	var node := Control.new()
	node.name = "CraftingStub"
	node.set_script(script)
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed, STUB_PATH)
	node.free()
	return STUB_PATH


func _labels(b: Node) -> Array:
	return b.menu_entries().map(func(e): return e.label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := CharacterBody2D.new()
	player.add_to_group(GameGroups.PLAYER)
	root.add_child(player)

	print("[1] Separate NPC with Figma art (D69)")
	var txt := FileAccess.open(SCENE, FileAccess.READ).get_as_text()
	ck(txt.find("theme_override") == -1 and txt.find("StyleBox") == -1, "no local styles in blacksmith.tscn")
	var b: Blacksmith = load(SCENE).instantiate()
	world.add_child(b)
	await process_frame
	ck(b is NpcBase, "shares NpcBase with the Merchant")
	ck((b.get_node("Sprite2D") as Sprite2D).texture.resource_path.ends_with("npc_blacksmith.png"), "sprite from Figma npc/blacksmith")
	var shop_src := FileAccess.open("res://SampleProject/Scripts/Shop/shop_ui.gd", FileAccess.READ).get_as_text()
	ck(shop_src.find("blacksmith") == -1 and shop_src.find("\"equipment\"") == -1, "Blacksmith is not a shop mode any more (Q9)")

	print("[2] Only backed entries; nothing to offer → no prompt")
	b.crafting_scene_path = "res://does/not/exist.tscn"
	b.refresh_availability()
	ck(_labels(b).is_empty(), "no crafting screen, no dialogue → no entries")
	b.interactable._on_body_entered(player)
	ck(not b.interactable.get_prompt().visible, "no prompt when there is nothing to do")
	b.interactable.interacted.emit()
	await process_frame
	ck(not b.npc_menu.visible and not paused, "interact does nothing")
	b.interactable._on_body_exited(player)
	b.talk_dialogue = "res://dialogue_quest/any.dqd"
	b.refresh_availability()
	ck(_labels(b) == ["Talk"], "Talk appears with a dialogue")
	ck(not _labels(b).has("Enchant") and not _labels(b).has("Quest"), "Enchant (D82) and Quest (D56) stay hidden")
	b.talk_dialogue = ""

	print("[3] Craft routes to the crafting screen")
	b.crafting_scene_path = _make_stub()
	b.refresh_availability()
	ck(_labels(b) == ["Craft"], "Craft appears once a crafting screen exists")
	b.interactable._on_body_entered(player)
	ck(b.interactable.get_prompt().visible and b.interactable.get_prompt().action_text == "Craft", "prompt \"Craft\"")
	b.interactable.interacted.emit()
	await process_frame
	ck(b.npc_menu.visible and paused, "NPC menu opens under pause")
	b.npc_menu.chosen.emit(&"craft")
	await process_frame
	ck(b.is_crafting_open and b.crafting_instance != null and paused, "Craft opens the crafting screen")
	ck(not b.interactable.get_prompt().visible, "prompt hidden while crafting")
	b.interactable.interacted.emit()
	await process_frame
	ck(not b.npc_menu.visible, "menu cannot reopen over the crafting screen")
	b.crafting_instance.closed.emit()
	await process_frame
	ck(not b.is_crafting_open and not paused, "closing crafting resumes the game")
	ck(b.interactable.get_prompt().visible, "prompt returns")

	DirAccess.remove_absolute(STUB_PATH)
	_done()


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("    : " + f)
	quit(0 if fails.is_empty() else 1)
