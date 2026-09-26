extends SceneTree

## Регресія для підсистем, «розбуджених» виправленням ServiceLocator (Phase 5.2A).
##   godot --headless --path . --script res://SampleProject/UI/verify_core_wiring.gd

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame; await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")

	print("[1] helper resolves the autoload")
	ck(ServiceLocatorHelper.get_service_locator() != null, "ServiceLocatorHelper returns the autoload")
	ck(ServiceLocatorHelper.get_service_locator() == sl, "and it is the same instance as /root/ServiceLocator")
	ck(not Engine.has_singleton("ServiceLocator"), "Engine.has_singleton is still false (the original bug)")

	print("[2] managers resolve their dependencies")
	var cm: Node = sl.get_character_manager()
	ck(cm.game_manager != null, "CharacterManager.game_manager resolved")
	ck(sl.get_equipment_manager() != null, "EquipmentManager reachable")
	var ch = cm.get_active_character()
	ck(ch != null and ch.get_equipment_stats() is Dictionary, "Character.get_equipment_stats() works")

	print("[3] save/load path (PlayerDataModule + InventoryModule)")
	var save_system: Node = root.get_node_or_null("SaveSystem")
	ck(save_system != null, "SaveSystem autoload present")
	var gm: Node = sl.get_game_manager()
	ck(gm.player_state is Dictionary and gm.player_state.size() > 0, "player_state readable (Object.has fix)")
	var pdm = save_system.player_data_module
	var snap: Dictionary = pdm.save() if pdm and pdm.has_method("save") else {}
	ck(not snap.is_empty(), "PlayerDataModule.save() returns data, not empty")
	ck(snap.has("equipment"), "saved payload includes equipment")
	# Round-trip через реальний модуль.
	var marker := {"id": "iron_sword", "name": "Iron Sword"}
	gm.player_state["equipment"]["sword"] = marker
	var again: Dictionary = pdm.save()
	ck(again.get("equipment", {}).get("sword") != null, "equipment change is visible to the save module")
	pdm.load_data(snap)
	ck(true, "PlayerDataModule.load_data() runs without error")

	print("[4] settings module")
	var sm = save_system.settings_module
	ck(sm != null, "SettingsModule instantiated")
	ck(sm.has_method("save") and sm.has_method("load_data"), "SettingsModule exposes save()/load_data()")
	ck(sm.save() is Dictionary, "SettingsModule.save() returns a Dictionary")

	print("[5] UI update manager (woken HUD paths)")
	var uum: Node = sl.get_ui_update_manager() if sl.has_method("get_ui_update_manager") else null
	ck(uum != null, "UIUpdateManager reachable")

	print("[6] no Object.has() left on the runtime save path")
	for path in ["res://SampleProject/Scripts/Systems/Save/Modules/PlayerDataModule.gd",
			"res://SampleProject/Scripts/Systems/Save/Modules/InventoryModule.gd",
			"res://SampleProject/Scripts/Managers/Gameplay/CharacterManager.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text() if f else ""
		ck(text.find('game_manager.has("') == -1, "%s has no Object.has() call" % path.get_file())

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
