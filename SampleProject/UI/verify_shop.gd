extends SceneTree

## Самоперевірка slice 2: Merchant / Shop (UI + логіка); стоїть на Desert Road (D154).
##   godot --headless --path . --script res://SampleProject/UI/verify_shop.gd
##
## Figma: shop-buy 153:1289, shop-sell 153:1523, shop-buy-confirm 153:1760,
## npc-menu-merchant 164:1302.

const SHOP_SCENE := "res://SampleProject/Scenes/Shop/shop_menu.tscn"
const MERCHANT_SCENE := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/merchant.tscn"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var inv: Node
var db: Node
var ui: Node


func _modal() -> Node:
	var layer = ui.get_modal_layer()
	return layer.active_modal if layer else null


func _press_modal(text: String) -> void:
	var m := _modal()
	if m == null:
		return
	for b in m.buttons_container.get_children():
		if b is Button and b.visible and b.text == text:
			b.pressed.emit()
			return


func _set_gold(value: int) -> void:
	var have: int = inv.get_item_count("coin")
	if have > value:
		inv.remove_item("coin", have - value)
	elif have < value:
		inv.add_item("coin", value - have)


## Чи карта інстансить сцену — читаємо SceneState, скрипти карти не запускаються.
func _placed_in(map_path: String, scene_path: String) -> bool:
	var state: SceneState = (load(map_path) as PackedScene).get_state()
	for i in state.get_node_count():
		var inst: PackedScene = state.get_node_instance(i)
		if inst and inst.resource_path == scene_path:
			return true
	return false


func _merchant_items() -> Array:
	var j := JSON.new()
	j.parse(FileAccess.open("res://SampleProject/Resources/Data/merchants.json", FileAccess.READ).get_as_text())
	return j.data.merchants.default.items


func _initialize() -> void:
	await process_frame
	await process_frame
	# Меню існує лише в запущеній грі (Game, гравець, нижня панель) — тест відкриває його там само.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var boot_game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(boot_game)
	current_scene = boot_game
	for i in 40: await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	inv = sl.get_inventory_manager()
	db = sl.get_item_database()
	ui = sl.get_ui_manager()
	var theme: Theme = load("res://SampleProject/UI/Themes/GameUITheme.tres")
	var items := _merchant_items()

	print("[1] Shared styles, Figma structure")
	for path in [SHOP_SCENE, "res://SampleProject/UI/Components/shop_row.tscn"]:
		var txt := FileAccess.open(path, FileAccess.READ).get_as_text()
		ck(txt.find("theme_override") == -1 and txt.find("StyleBox") == -1, "no local styles in %s" % path.get_file())
	ck(theme.get_stylebox("focus", "ShopRow").bg_color == UITokens.ACCENT, "selected row fills accent")
	ck(theme.get_color("font_color", "ShopRowNameOn") == UITokens.ON_ACCENT, "selected row text is dark on accent (D26)")
	ck(not ResourceLoader.exists("res://SampleProject/Scripts/Shop/item_list_display.gd"), "stub table scripts removed")
	ck(_placed_in("res://SampleProject/Maps/DesertRoad.tscn", MERCHANT_SCENE), "Merchant stands on the Desert Road (D154)")

	print("[2] ShopService: real data, buy and sell")
	var svc := ShopService.new()
	ck(svc.is_ready(), "service reaches ItemDatabase + InventoryManager")
	ck(ShopService.format_price(2400) == "₹ 2,400", "price format matches Figma (%s)" % ShopService.format_price(2400))
	var wares := svc.wares(items, &"all")
	ck(wares.size() > 0 and wares.all(func(w): return w.price == int(db.get_item(w.id).buy_price)),
			"%d wares priced from ItemDatabase" % wares.size())
	var weapons := svc.wares(items, &"weapons")
	ck(weapons.size() > 0 and weapons.all(func(w): return db.get_item(w.id).type == "weapon"), "weapons filter")
	ck(svc.wares(items, &"accessories").is_empty(), "no accessory data → empty category")
	var sword: Dictionary = weapons[0]
	_set_gold(sword.price - 1)
	var owned_before: int = inv.get_item_count(sword.id)
	ck(svc.buy(sword.id) == ShopService.Result.NOT_ENOUGH_GOLD, "cannot buy without enough gold")
	ck(inv.get_item_count(sword.id) == owned_before and svc.gold() == sword.price - 1, "failed purchase changes nothing")
	_set_gold(sword.price + 50)
	ck(svc.buy(sword.id) == ShopService.Result.OK, "buy succeeds with enough gold")
	ck(svc.gold() == 50 and inv.get_item_count(sword.id) == owned_before + 1, "gold spent, item received")
	var sell_price := int(db.get_item(sword.id).sell_price)
	ck(svc.sell(sword.id) == ShopService.Result.OK, "sell succeeds")
	ck(svc.gold() == 50 + sell_price and inv.get_item_count(sword.id) == owned_before, "item sold for sell_price")
	ck(svc.sell("iron_sword" if sword.id != "iron_sword" else "copper_sword") in [ShopService.Result.NOT_OWNED, ShopService.Result.OK],
			"selling checks ownership")

	print("[3] Shop screen: tabs, categories, rows, description")
	_set_gold(100000)
	var shop: Control = load(SHOP_SCENE).instantiate()
	root.add_child(shop)
	await process_frame
	shop.setup_shop(items)
	for i in 3: await process_frame
	var rows: Array = shop.get_rows()
	ck(rows.size() == svc.wares(items, &"all").size(), "one row per ware (%d)" % rows.size())
	ck(shop._title.text == "All Wares" and shop._price_header.text == "Selling Price", "BUY copy from Figma")
	ck(shop._categories.get_child_count() == 6, "6 category buttons (ALL + 5 icons)")
	ck(shop._category_buttons[0].theme_type_variation == &"ShopCategoryOn", "ALL active")
	var focused = shop.get_viewport().gui_get_focus_owner()
	ck(focused == rows[0], "first row focused")
	ck(rows[0]._name.theme_type_variation == &"ShopRowNameOn", "focused row uses dark-on-accent text")
	ck(shop._desc_name.text == rows[0].data.name and shop._desc_text.text == rows[0].data.description,
			"description box shows the focused item")
	var next := InputEventAction.new()
	next.action = &"menu_next_tab"
	next.pressed = true
	shop._input(next)
	await process_frame
	ck(shop._title.text == "Weapons" and shop.get_rows().size() == weapons.size(), "E / RB → Weapons")
	shop._set_category(4)
	await process_frame
	ck(shop._empty.visible and not shop._desc_box.visible and shop.get_rows().is_empty(),
			"empty category shows the empty state")
	shop._set_category(0)
	shop._switch_mode("sell")
	await process_frame
	ck(shop._title.text == "All Possessions" and shop._price_header.text == "Buying Price", "SELL copy from Figma")
	ck(shop.get_rows().all(func(r): return r.data.id != "coin"), "gold is not listed for sale")

	print("[3a] Price column right-aligned in Buy and Sell, '—' included (B25, #73)")
	inv.add_item("potion", 1)
	inv.add_item("iron_ore", 1)
	for mode in ["sell", "buy"]:
		shop._switch_mode(mode)
		await process_frame
		var prows: Array = shop.get_rows()
		if mode == "buy":
			prows[1].setup(prows[1].data, false)  # непродажний рядок показує "—"
		await process_frame
		var hdr_right: float = shop._price_header.get_global_rect().end.x
		ck(shop._price_header.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "%s: price header right-aligned" % mode)
		var ends: Array = []
		var aligned := prows.size() > 1
		for r in prows:
			ends.append(r._price.get_global_rect().end.x)
			aligned = aligned and r._price.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT 					and is_equal_approx(r._price.get_global_rect().end.x, hdr_right)
		ck(aligned, "%s: every price (%s) ends at the header's right edge %.0f (%s)"
				% [mode, ",".join(prows.map(func(r): return r._price.text)), hdr_right, str(ends)])
	ck(shop.get_rows()[1]._price.text == "—", "unsellable placeholder is in the checked set")
	for path in ["res://SampleProject/Scenes/Crafting/crafting_menu.tscn", "res://SampleProject/Scenes/Enchanting/enchanting_menu.tscn"]:
		var m: Node = load(path).instantiate()
		ck((m.get_node("%PriceHeader") as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
				"%s: cost header right-aligned like its rows" % path.get_file())
		m.free()

	print("[4] Buy confirmation (153:1760)")
	shop._switch_mode("buy")
	await process_frame
	var target: ShopRow = shop.get_rows()[0]
	var tdata: Dictionary = target.data.duplicate()  # рядки перебудовуються після модалки
	var id: String = tdata.id
	var before: int = inv.get_item_count(id)
	var gold_before: int = svc.gold()
	target.pressed.emit()
	await process_frame
	ck(_modal() != null and _modal().title_label.text == "Buy %s?" % tdata.name, "\"Buy X?\" confirmation")
	ck(_modal() != null and _modal().description_label.text == "Quantity: ◀ 1 ▶  •  Total Cost: %s" % ShopService.format_price(tdata.price),
			"quantity and total cost")
	# B26 (#74): Yes і No однакового розміру, хоч би на якій фокус; рамка панелі — токени.
	await process_frame
	var mb: Array = _modal().buttons_container.get_children().filter(func(b): return b is Button and b.visible)
	var sizes: Array = []
	for b in mb:
		b.grab_focus()
		await process_frame
		sizes.append([mb[0].size, mb[1].size])
	ck(mb.size() == 2 and sizes[0][0] == sizes[0][1] and sizes[1] == sizes[0],
			"Yes and No have identical size under either focus (%s)" % str(sizes))
	var psb: StyleBoxFlat = _modal().get_node("Panel").get_theme_stylebox("panel")
	ck(psb.border_width_left == UITokens.BORDER_WIDTH and psb.border_width_top == UITokens.BORDER_WIDTH
			and psb.border_width_right == UITokens.BORDER_WIDTH and psb.border_width_bottom == UITokens.BORDER_WIDTH
			and psb.border_color == UITokens.BORDER, "modal panel border is BORDER at BORDER_WIDTH")
	_press_modal("No")
	await process_frame
	ck(inv.get_item_count(id) == before, "No cancels the purchase")
	shop.get_rows()[0].pressed.emit()
	await process_frame
	_press_modal("Yes")
	await process_frame
	ck(inv.get_item_count(id) == before + 1 and svc.gold() == gold_before - int(tdata.price), "Yes buys it")
	ck(shop.get_rows()[0]._count.text == str(before + 1), "On Hand column refreshes")

	print("[4a] Quantity: ←/→ in the confirmation (D104)")
	_set_gold(int(tdata.price) * 3)
	shop.get_rows()[0].pressed.emit()
	await process_frame
	for key in [&"ui_right", &"ui_right", &"ui_right", &"ui_right", &"ui_left"]:
		var ev := InputEventAction.new()
		ev.action = key
		ev.pressed = true
		shop._input(ev)
	ck(shop._quantity == 2, "→ ×4 stops at what gold covers (3), ← back to 2 (%d)" % shop._quantity)
	ck(_modal().description_label.text == "Quantity: ◀ 2 ▶  •  Total Cost: %s" % ShopService.format_price(int(tdata.price) * 2),
			"total follows the quantity (%s)" % _modal().description_label.text)
	_press_modal("Yes")
	await process_frame
	ck(inv.get_item_count(id) == before + 3 and svc.gold() == int(tdata.price), "Yes buys two at once")

	print("[4b2] Unaffordable rows are grey and do nothing (D105)")
	_set_gold(0)
	shop.refresh()  # у грі золото під час магазину міняє лише купівля, а за нею refresh()
	await process_frame
	var poor: ShopRow = shop.get_rows()[0]
	ck(not poor.affordable and poor._name.theme_type_variation == &"ShopRowDisabled", "row greyed")
	ck(poor.focus_mode != Control.FOCUS_NONE, "still focusable — its description stays readable")
	poor.pressed.emit()
	await process_frame
	ck(_modal() == null, "no modal, nothing bought")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	var closed := [false]
	shop.shop_closed.connect(func(): closed[0] = true)
	shop._input(cancel)
	for i in 20: await process_frame
	ck(closed[0], "B / Esc closes the shop")

	print("[4b] Started from the Main Menu: the modal layer exists (crash 2026-10-15, B54)")
	# Справжня гра стартує з MainMenu. Магазин (і Load → Delete у меню) питав
	# get_modal_layer().active_modal і падав на null, коли UIRoot у меню не будувався.
	var menu_scene := Node.new()
	menu_scene.scene_file_path = "res://SampleProject/MainMenu.tscn"
	root.add_child(menu_scene)
	var prev_scene := current_scene
	current_scene = menu_scene
	var fresh_ui: Node = load("res://SampleProject/Scripts/Managers/UI/UIManager.gd").new()
	root.add_child(fresh_ui)
	for i in 2: await process_frame
	ck(fresh_ui.get_modal_layer() != null, "modal layer exists while the Main Menu is the scene")
	current_scene = prev_scene
	fresh_ui.queue_free()
	menu_scene.queue_free()
	await process_frame

	print("[5] Merchant NPC menu (164:1302)")
	# Вступна розмова гри ще може йти — поверх неї меню NPC не відкривається (NpcBase).
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for round in 10:  # розмови в черзі стартують одна за одною — чекаємо, поки стане тихо
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			break
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var merchant: Node = load(MERCHANT_SCENE).instantiate()
	scene_root.add_child(merchant)
	await process_frame
	merchant.interactable.interacted.emit()
	await process_frame
	ck(merchant.npc_menu.visible and not paused, "interact opens the NPC menu, world keeps running (D155)")
	var labels: Array = merchant.npc_menu.get_children().map(func(b): return b.text)
	ck(labels == ["Buy"], "only backed entries: %s (Talk needs a dialogue, Quest is dormant)" % str(labels))
	merchant.npc_menu.cancelled.emit()
	ck(not merchant.npc_menu.visible, "cancel closes the menu")
	merchant.interactable.interacted.emit()
	await process_frame
	merchant.interactable.player_exited.emit()
	ck(not merchant.npc_menu.visible, "walking away closes the menu (D155)")
	ck(merchant.npc_menu.get_children().all(func(b: Control) -> bool: return b.mouse_filter == Control.MOUSE_FILTER_IGNORE),
			"menu ignores the mouse (D155)")
	merchant.talk_dialogue = "res://dialogue_quest/any.dqd"
	ck(merchant.menu_entries().map(func(e): return e.label) == ["Talk", "Buy"], "Talk appears when a dialogue is set")
	merchant.talk_dialogue = ""
	merchant.interactable.interacted.emit()
	for i in 2: await process_frame
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	merchant.npc_menu.get_viewport().push_input(stick)
	ck(merchant.npc_menu.get_viewport().is_input_handled(), "left stick is swallowed by the menu, not navigating it (D155)")
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	merchant.npc_menu._unhandled_input(press)
	for i in 5: await process_frame
	ck(merchant.is_shop_open and merchant.shop_menu_instance != null, "interact (E / pad A) picks the focused entry → shop opens (D155)")
	if merchant.shop_menu_instance:
		ck(merchant.shop_menu_instance.get_rows().size() > 0, "merchant stock listed")
	var esc_key := InputEventKey.new()
	esc_key.keycode = KEY_ESCAPE
	esc_key.physical_keycode = KEY_ESCAPE
	esc_key.pressed = true
	root.push_input(esc_key)  # справжній шлях клавіші: каркас BaseMenu отримує її першим
	for i in 20: await process_frame
	ck(not merchant.is_shop_open and not paused, "a real Esc key closes the shop and resumes the game (freeze 2026-10-15)")
	ck(ui.current_state_name != "GameMenuState", "the same Esc does not open the Game Menu")

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
