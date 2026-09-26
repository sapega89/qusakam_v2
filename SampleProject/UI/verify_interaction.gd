extends SceneTree

## Самоперевірка slice 1a: Interaction Prompt + Item Pickup.
##   godot --headless --path . --script res://SampleProject/UI/verify_interaction.gd
##
## Figma: UI/Interaction/Prompt 461:6479 (покращений варіант D84),
## UI/Modal/ItemPickup 222:4880. Рішення: D71, D74, D84, D86.

const PROMPT_SCENE := "res://SampleProject/UI/Components/interaction_prompt.tscn"
const PICKUP_SCENE := "res://SampleProject/Objects/ItemPickup.tscn"
const MERCHANT_SCENE := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/merchant.tscn"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _press(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _player() -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.add_to_group(GameGroups.PLAYER)
	root.add_child(p)
	return p


func _initialize() -> void:
	await process_frame
	await process_frame
	var tokens = load("res://SampleProject/UI/Tokens/UITokens.gd")
	var theme: Theme = load("res://SampleProject/UI/Themes/GameUITheme.tres")

	print("[1] Shared theme carries the prompt styles")
	for t in ["InteractionPrompt", "InteractionPromptFocused", "InteractionPromptDisabled"]:
		ck(theme.has_stylebox("panel", t), "%s stylebox in GameUITheme" % t)
	var focused: StyleBoxFlat = theme.get_stylebox("panel", "InteractionPromptFocused")
	ck(focused.border_color == tokens.ACCENT and focused.border_width_left == tokens.BORDER_WIDTH,
			"Focused state has the 1px accent border")
	ck(theme.get_stylebox("panel", "InteractionPrompt").bg_color == tokens.PROMPT_BG,
			"Default background from tokens")
	var scene_text := FileAccess.open(PROMPT_SCENE, FileAccess.READ).get_as_text()
	ck(scene_text.find("theme_override") == -1, "no overrides in the prompt scene")
	ck(scene_text.find("StyleBox") == -1, "no local styleboxes in the prompt scene")

	print("[2] Prompt: text, hug width, typography, states")
	var prompt: InteractionPrompt = load(PROMPT_SCENE).instantiate()
	root.add_child(prompt)
	prompt.action_text = "Pick up"
	await process_frame
	var label: Label = prompt.get_node("%ActionLabel")
	ck(label.text == "Pick up", "label shows the action text")
	var fsize := label.get_theme_font_size("font_size")
	ck(fsize >= 14 and fsize <= 16, "text is 14–16 px (%d, D84)" % fsize)
	ck(prompt.size.x < 200.0, "width hugs the content (%dpx < Figma's fixed 200)" % int(prompt.size.x))
	var short_w := prompt.size.x
	prompt.action_text = "Examine the relic"
	await process_frame
	ck(prompt.size.x > short_w, "longer text widens the prompt")
	ck(prompt.get_node("%Badge").custom_minimum_size == Vector2(tokens.PROMPT_BADGE, tokens.PROMPT_BADGE),
			"badge is 28×28")
	prompt.state = InteractionPrompt.State.FOCUSED
	ck(prompt.theme_type_variation == &"InteractionPromptFocused", "Focused state variation")
	prompt.state = InteractionPrompt.State.DISABLED
	ck(prompt.theme_type_variation == &"InteractionPromptDisabled", "Disabled state variation")
	ck(is_equal_approx(label.modulate.a, tokens.PROMPT_DISABLED_CONTENT_ALPHA), "Disabled content fades")
	prompt.state = InteractionPrompt.State.DEFAULT
	ck(is_equal_approx(label.modulate.a, 1.0), "Default content is opaque")

	print("[3] Badge follows the last input device (Q12 default)")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	prompt._input(joy)
	ck(prompt.get_node("%Badge").texture == InteractionPrompt.BADGE_GAMEPAD, "gamepad input → A badge")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	prompt._input(key)
	ck(prompt.get_node("%Badge").texture == InteractionPrompt.BADGE_KEYBOARD, "keyboard input → E badge")
	prompt.queue_free()

	print("[4] `interact` input action (no hard-coded keys)")
	ck(InputMap.has_action(&"interact"), "interact action exists")
	var has_e := false
	var has_a := false
	for ev in InputMap.action_get_events(&"interact"):
		if ev is InputEventKey and ev.physical_keycode == KEY_E: has_e = true
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A: has_a = true
	ck(has_e, "bound to keyboard E")
	ck(has_a, "bound to gamepad A")

	print("[5] InteractableComponent shows the prompt only near the player")
	var area := Area2D.new()
	var comp := InteractableComponent.new()
	comp.action_text = "Talk"
	area.add_child(comp)
	root.add_child(area)
	await process_frame
	var player := _player()
	var cprompt := comp.get_prompt()
	ck(cprompt != null and not cprompt.visible, "prompt hidden until the player arrives")
	comp._on_body_entered(player)
	await process_frame
	ck(cprompt.visible, "prompt shown when the player enters")
	ck(cprompt.action_text == "Talk", "prompt uses the component's action text")
	ck(cprompt.position.y < 0.0, "prompt sits above the object")
	var hits := [0]
	comp.interacted.connect(func(): hits[0] += 1)
	comp._unhandled_input(_press(&"interact"))
	ck(hits[0] == 1, "interact action fires `interacted`")
	comp._unhandled_input(_press(&"ui_accept"))
	ck(hits[0] == 1, "ui_accept (Space/Enter) no longer interacts")
	comp.enabled = false
	ck(not cprompt.visible, "disabled component hides the prompt")
	comp._unhandled_input(_press(&"interact"))
	ck(hits[0] == 1, "disabled component ignores interact")
	comp.enabled = true
	comp._on_body_exited(player)
	ck(not cprompt.visible, "prompt hidden when the player leaves")
	comp._unhandled_input(_press(&"interact"))
	ck(hits[0] == 1, "no interaction once the player has left")
	var stranger := Node2D.new()
	root.add_child(stranger)
	comp._on_body_entered(stranger)
	ck(not cprompt.visible, "non-player bodies do not trigger the prompt")
	area.queue_free()

	print("[6] Item Pickup: prompt → inventory → confirmation modal (D71)")
	var sl: Node = root.get_node("ServiceLocator")
	var db = sl.get_item_database()
	var inv = sl.get_inventory_manager()
	var ui = sl.get_ui_manager()
	ck(not db.get_item("potion").is_empty(), "test item 'potion' is real ItemDatabase data")
	var before: int = inv.get_item_count("potion")
	var pickup: ItemPickup = load(PICKUP_SCENE).instantiate()
	pickup.item_id = "potion"
	pickup.amount = 2
	root.add_child(pickup)
	await process_frame
	var picked := [""]
	pickup.picked_up.connect(func(id, _n): picked[0] = id)
	var pcomp: InteractableComponent = pickup.get_node("Interactable")
	ck(pcomp.action_text == "Pick up", "prompt reads \"Pick up\"")
	ck(pickup.get_node("Sprite2D").texture != null, "sprite uses the ItemDatabase icon")
	pcomp._on_body_entered(player)
	pcomp._unhandled_input(_press(&"interact"))
	await process_frame
	await process_frame
	ck(inv.get_item_count("potion") == before + 2, "2 potions added via InventoryManager (%d → %d)" % [before, inv.get_item_count("potion")])
	ck(picked[0] == "potion", "picked_up signal emitted")
	var layer = ui.get_modal_layer()
	var modal = layer.active_modal if layer else null
	ck(modal != null, "confirmation modal opened")
	if modal:
		ck(modal.title_label.text == "You obtained:", "modal title matches Figma (%s)" % modal.title_label.text)
		ck(modal.description_label.text == "%s × 2" % db.get_item_name("potion"),
				"modal shows item × amount (%s)" % modal.description_label.text)
		var focus = modal.get_viewport().gui_get_focus_owner()
		ck(focus is Button and focus.text == "OK", "OK button focused for keyboard/gamepad (%s)" % str(focus))
		ck(not ui.is_gameplay_input_allowed(), "gameplay input blocked while the modal is open")
		focus.pressed.emit()
		await process_frame
		ck(layer.active_modal == null, "OK closes the modal")
	ck(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "picked item leaves the world")

	print("[7] Unknown items are never invented")
	var bogus: ItemPickup = load(PICKUP_SCENE).instantiate()
	bogus.item_id = "does_not_exist"
	root.add_child(bogus)
	await process_frame
	var bcomp: InteractableComponent = bogus.get_node("Interactable")
	ck(not bcomp.enabled, "unknown item_id disables the pickup")
	bogus.queue_free()

	print("[8] Merchant uses the shared prompt")
	var merchant: Node = load(MERCHANT_SCENE).instantiate()
	root.add_child(merchant)
	await process_frame
	ck(merchant.get_node_or_null("InteractionLabel") == null, "old hard-coded label removed")
	var mcomp := merchant.get_node_or_null("Interactable") as InteractableComponent
	ck(mcomp != null and mcomp.action_text == "Shop", "Interactable with \"Shop\"")
	ck(mcomp != null and mcomp.interacted.is_connected(merchant._on_interacted), "interact opens the shop")
	var msrc := FileAccess.open("res://SampleProject/Scripts/Gameplay/NPCs/Merchant.gd", FileAccess.READ).get_as_text()
	ck(msrc.find("KEY_E") == -1, "no hard-coded KEY_E in Merchant.gd")
	merchant.queue_free()

	print("[9] RelicArmor uses the shared prompt")
	var relic := RelicArmor.new()
	root.add_child(relic)
	await process_frame
	ck(relic.interactable != null and relic.interactable.action_text == "Examine", "Interactable with \"Examine\"")
	var rsrc := FileAccess.open("res://SampleProject/Scripts/Gameplay/RelicArmor.gd", FileAccess.READ).get_as_text()
	ck(rsrc.find("KEY_E") == -1, "no hard-coded KEY_E in RelicArmor.gd")
	relic.queue_free()

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
