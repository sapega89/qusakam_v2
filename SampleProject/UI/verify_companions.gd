extends SceneTree

## Асисти компаньйонів, зріз 1 ([[companion_assist_plan]], D209): хто відкритий, одна кнопка викликає
## наступного готового, кулдаун у кожного свій, загін переживає сейв. Сцени асистів — зрізи 2–3.
##   godot --headless --path . --script res://SampleProject/UI/verify_companions.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var cm: Node = sl.get_companion_manager()
	var state: Dictionary = sl.get_game_manager().player_state
	var called: Array = []
	var ready_again: Array = []
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: called.append(id))
	root.get_node("EventBus").assist_ready.connect(func(id: String) -> void: ready_again.append(id))

	print("[1] Nobody unlocked → the button does nothing")
	state.companions = []
	ck(cm.call_next() == "" and called.is_empty(), "no companions, no assist")

	print("[2] One button, the next ready companion in roster order")
	cm.unlock("astrit")
	cm.unlock("alisia")
	ck(cm.get_unlocked() == ["alisia", "astrit"], "roster order, not unlock order (%s)" % [cm.get_unlocked()])
	ck(cm.call_next() == "alisia", "first press: Алісия")
	ck(cm.call_next() == "astrit", "second press: Астрит")
	ck(cm.call_next() == "", "both on cooldown → nobody")
	ck(called == ["alisia", "astrit"], "assist_called for each (%s)" % [called])

	print("[3] Each has its own 15 s cooldown")
	ck(is_equal_approx(cm.get_remaining_cooldown("alisia"), cm.COOLDOWN), "cooldown starts at %.0f s" % cm.COOLDOWN)
	cm._process(cm.COOLDOWN + 0.1)
	ck(ready_again == ["alisia", "astrit"] and cm.is_ready("alisia"), "assist_ready after the cooldown (%s)" % [ready_again])
	ck(cm.call_next() == "alisia", "the queue goes on after the last called: Алісия again")

	print("[4] The roster survives a save")
	var module: Node = root.get_node("SaveSystem").player_data_module
	var data: Dictionary = module.save()
	state.companions = []
	module.load_data(data)
	ck(cm.get_unlocked() == ["alisia", "astrit"], "loaded roster (%s)" % [cm.get_unlocked()])
	state.companions = []
	cm.clear_cooldowns()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
