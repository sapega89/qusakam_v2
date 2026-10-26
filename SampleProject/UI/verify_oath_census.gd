extends SceneTree

## Перепис біля брами й нахили до шляхів (D725–D728, oath_affinity_plan), у справжній грі:
##   [1] нахили від стилю бою: бот, що блокує й парирує, хилиться до Самаля; бот, що перекочується крізь удари й
##       не дістає, — до шляху без бога; бій додає не більше FIGHT_CAP на шлях; вчинок у розмові — signal|leaning;
##   [2] бій біля брами → писар → «Не знаю» → три питання → порада → «Та ні, краще…» → клятва; усе справжнім вводом
##       (Enter гортає репліки, стрілки й Enter вибирають відповідь), «Ще подумаю» немає (D728);
##   [3] прямa відповідь «Кому служиш?» через меню писаря (старий сейв: бій пройдено, клятви немає), на 5-му рівні
##       дерево відкривається одразу; після перепису в писаря лише розмова;
##   [4] Журнал: три герби, яскравіші з нахилом, без чисел; «?» про шляхи — тема paths;
##   [5] показ розмови (DqdReader) пропускає відповіді й розгалуження; ${contract_god} — одним ключем.
##   godot --headless --path . --script res://SampleProject/UI/verify_oath_census.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const BANDIT_STATS := "res://SampleProject/Resources/Enemies/enemy_stats_melee.tres"
const GATES := "res://SampleProject/Maps/CityGates.tscn"
const CENSUS := "res://dialogue_quest/CityGates_Census.dqd"

var fails: Array[String] = []
## Скрипти, що тягнуть автолоади, — load() під час гри: тест компілюється раніше за автолоади.
var OL: GDScript
var bus: Node
var game: Node
var sl: Node
var hero: Node
## Що показувало вікно діалогу за розмову (ім'я: текст) — щоб побачити пораду писаря.
var shown: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _choices(dm: Node) -> Array:
	return dm.current_dialogue_player.choice_menu.get_node("%ButtonsContainer").get_children().map(func(b: Button) -> String: return b.text)


func _choice_visible(dm: Node) -> bool:
	return dm.current_dialogue_player.choice_menu.visible


## Enter гортає репліки, доки не з'являться відповіді (або розмова скінчиться).
func _lines_until_choice(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active() or _choice_visible(dm):
			return
		var line: String = dm.current_dialogue_box._text.text
		if shown.is_empty() or shown[-1] != line:
			shown.append(line)
		await _key(KEY_ENTER)


## Відповідь [param index]: стрілка вниз index разів, тоді Enter — як гравець.
func _answer(dm: Node, index: int) -> String:
	for i in index:
		await _key(KEY_DOWN)
	var focused := root.gui_get_focus_owner()
	var text: String = (focused as Button).text if focused is Button else ""
	await _key(KEY_ENTER)
	return text


func _initialize() -> void:
	var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	rolls.calm()
	await process_frame
	OL = load("res://SampleProject/Scripts/Systems/OathLeanings.gd")
	bus = root.get_node("EventBus")
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: «?» лише там, де їх перевіряємо
	game = await Kit.boot(self)
	sl = root.get_node("ServiceLocator")
	hero = game.player
	await _leanings_from_fights()
	await _census_full()
	await _census_direct()
	await _journal()
	_reader()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)


# ── [1] Нахили від стилю бою ────────────────────────────────────────────────

func _reset_leanings() -> void:
	sl.get_game_manager().player_state.leanings = {"samal": 0.0, "contract": 0.0, "none": 0.0}


func _arena() -> void:
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	await Kit.frames(self, 16)
	await Kit.drain(self)
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout


## Один бандит перед героєм; [param style] — &"block" (блок і парирування) або &"dodge" (перекат крізь удар).
## Бот б'є, коли бандит не замахується; після власного удару від бандита чекає, щоб не міняти удар на удар.
func _bot_fight(style: StringName) -> void:
	var bandit: Node = load(BANDIT).instantiate()
	bandit.enemy_stats = load(BANDIT_STATS)
	bandit.position = game.map.to_local(hero.global_position + Vector2(90.0, -30.0))
	game.map.add_child(bandit)
	await Kit.frames(self, 4)
	bandit.Max_Health = 150
	bandit.current_health = 150
	var logic: Node = bandit.enemy_logic
	# Бот відповідає на кожен замах двома ударами — інакше збиває бандита раніше, ніж той замахнеться (D264)
	var counters := [0]
	logic.attack_ended.connect(func() -> void: counters[0] = 2)
	var hurt_until := [0.0]
	var on_hurt := func(target: Node, _source: Node, _amount: int, _critical: bool) -> void:
		if target == hero:
			hurt_until[0] = Time.get_ticks_msec() / 1000.0 + 0.8
	bus.damage_received.connect(on_hurt)
	var blocking := false
	var committed_for := [0.0]
	var rolls := [0]
	for frame in 60 * 40:
		await physics_frame
		if not is_instance_valid(bandit) or not bandit.is_alive():
			break
		var toward := signf(bandit.global_position.x - hero.global_position.x)
		if toward != 0.0 and not hero.mover.is_rolling():
			hero.mover.last_direction = int(toward)
		var danger: bool = logic.is_attacking and not logic.recovering
		match style:
			&"block":
				if danger and not blocking:
					_press(&"block")
					blocking = true
				elif not danger and blocking:
					_press(&"block", false)
					blocking = false
			&"dodge":
				# Перекат під самий удар (підказка горить tell_time до нього): невразливість накриває удар
				if logic.committed:
					committed_for[0] += 1.0 / Engine.physics_ticks_per_second
				else:
					committed_for[0] = 0.0
				if logic.committed and committed_for[0] >= logic.tell_time - 0.05 and not hero.mover.is_rolling():
					rolls[0] += 1
					_press(&"dodge")
					await physics_frame
					_press(&"dodge", false)
		var free_now: bool = not danger and not blocking and not hero.mover.is_rolling() and not hero.combat.owns_animation()
		if free_now and counters[0] > 0 and Time.get_ticks_msec() / 1000.0 > hurt_until[0] and absf(bandit.global_position.x - hero.global_position.x) < 80.0:
			counters[0] -= 1
			_press(&"attack")
			await physics_frame
			_press(&"attack", false)
	if blocking:
		_press(&"block", false)
	if style == &"dodge":
		print("    rolls pressed: %d, bandit alive: %s" % [rolls[0], is_instance_valid(bandit) and bandit.is_alive()])
	bus.damage_received.disconnect(on_hurt)
	# Бій кінчається, коли стихне (COMBAT_LINGER)
	for i in 60 * 6:
		await physics_frame
		if not hero.combat.in_combat():
			break


func _leanings_from_fights() -> void:
	print("[1] The fighting style feeds the leanings (D725)")
	var leanings: Node = sl.get_skill_manager().leanings
	await _arena()
	_reset_leanings()
	var blocks := [0, 0]
	var on_block := func(_a: Node) -> void: blocks[0] += 1
	var on_parry := func(_a: Node) -> void: blocks[1] += 1
	bus.player_blocked.connect(on_block)
	bus.player_parried.connect(on_parry)
	await _bot_fight(&"block")
	bus.player_blocked.disconnect(on_block)
	bus.player_parried.disconnect(on_parry)
	var after_block: Dictionary = leanings.values()
	ck(blocks[0] + blocks[1] > 0, "the blocker landed blocks / parries (%d / %d)" % blocks)
	ck(after_block.samal > after_block.none and after_block.samal > after_block.contract, "a bot that blocks and parries drifts to Samal (%s)" % after_block)
	ck(after_block.values().all(func(v: float) -> bool: return v <= OL.FIGHT_CAP), "one fight adds at most FIGHT_CAP to a path (%s)" % after_block)
	ck(leanings.strongest() == "samal", "the scribe would advise Samal")

	_reset_leanings()
	var dodges := [0]
	var on_dodge := func(_a: Node) -> void: dodges[0] += 1
	bus.player_dodged_through.connect(on_dodge)
	await _bot_fight(&"dodge")
	bus.player_dodged_through.disconnect(on_dodge)
	var after_dodge: Dictionary = leanings.values()
	ck(dodges[0] > 0, "the dodger rolled through swings (%d)" % dodges[0])
	ck(after_dodge.none > after_dodge.samal and after_dodge.none > after_dodge.contract, "a dodger drifts to no god (%s)" % after_dodge)
	ck(leanings.strongest() == "none", "the scribe would advise no god")

	_reset_leanings()
	root.get_node("DialogueQuest").Signals.dialogue_signal.emit(["leaning", "contract"])
	ck(is_equal_approx(leanings.values().contract, OL.DEED), "a deed in a talk (signal|leaning|contract) adds DEED")
	for path in ["res://dialogue_quest/OldMan_Decision.dqd", "res://dialogue_quest/Merchant_Caravan_Give.dqd", "res://dialogue_quest/Lab_Acquaintance.dqd"]:
		var uk := FileAccess.get_file_as_string(path)
		var en := FileAccess.get_file_as_string(path.replace("dialogue_quest/", "dialogue_quest/en/"))
		ck(OL.PATHS.all(func(p: String) -> bool: return uk.contains("signal|leaning|" + p) and en.contains("signal|leaning|" + p))
				and uk.contains("[ЧЕРНЕТКА] D725") and en.contains("[DRAFT] D725"), "%s: a deed choice for each path, a draft in uk and en" % path.get_file())


# ── [2] Перепис: бій → писар → «не знаю» → питання → порада → «та ні, краще…» ────────────────

func _gate_fight() -> Node:
	game.set_quest_flag("city_gates_intro_complete", true)
	await game.teleport_to_room(GATES, ^"Arrival")
	await Kit.frames(self, 20)
	await Kit.drain(self)  # CityGates_Fight
	var room: Node = game.map
	ck(room.get_current_state_name() == "FIGHT_LOOP", "the gate fight (%s)" % room.get_current_state_name())
	var scribe: Node = room.get_node("GateScribe")
	ck(scribe.menu_entries().is_empty() and scribe.quest_marker() == &"", "during the fight the scribe keeps out of it")
	await Kit.frames(self, 30)
	for enemy in room.find_children("*", "CharacterBody2D", true, false):
		if enemy.is_in_group(&"enemies") and enemy.is_alive():
			enemy.take_damage(99999, hero)
	for i in 300:
		await process_frame
		if sl.get_dialogue_manager().is_dialogue_active():
			break
	return room


func _census_full() -> void:
	print("[2] The census after the gate fight: «I don't know» → questions → advice → «No, rather…» (D727, D728)")
	var dm: Node = sl.get_dialogue_manager()
	var sm: Node = sl.get_skill_manager()
	_reset_leanings()
	sm.leanings.add("none", 5.0)  # трохи ухилень з дороги; відповіді переважать
	ck(sm.get_oath() == "", "no oath before the census")
	var room: Node = await _gate_fight()
	ck(dm.is_dialogue_active() and room.get_current_state_name() == "AFTER_FIGHT_DIALOGUE", "after the fight the census starts by itself")
	shown.clear()
	await _lines_until_choice(dm)
	ck(shown.any(func(l: String) -> bool: return l.contains("eyes aren't blue")), "the scribe checks his eyes for the curse (D587)")
	ck(shown.any(func(l: String) -> bool: return l.contains("Name? Where from?")), "asks his name and where from")
	ck(_choices(dm) == ["Samal", "the god of contracts", "Nobody. I walk on my own", "I don't know"], "«Whom do you serve?»: %s" % [_choices(dm)])
	ck(not _choices(dm).any(func(c: String) -> bool: return c.contains("think")), "no «I'll think about it» (D728)")
	ck(await _answer(dm, 3) == "I don't know", "«I don't know» chosen with Down ×3 + Enter")
	var picks := []
	for q in 3:
		await _lines_until_choice(dm)
		ck(_choices(dm).size() == 3, "question %d: three answers (%s)" % [q + 1, _choices(dm)])
		picks.append(await _answer(dm, 0))
	ck(picks == ["I stand by the weaker one", "Shield: a blow must be held", "I keep it, because I gave it"], "three this-or-that answers: %s" % [picks])
	await _lines_until_choice(dm)
	ck(shown.any(func(l: String) -> bool: return l.contains("There are three roads")), "he names the three paths")
	ck(shown.any(func(l: String) -> bool: return l.contains("My advice: Samal")), "and advises Samal (answers outweigh a little dodging)")
	ck(_choices(dm) == ["Write it: Samal", "No, rather the god of contracts", "No, rather no god"], "take it or «No, rather…»: %s" % [_choices(dm)])
	ck(await _answer(dm, 2) == "No, rather no god", "the player says «No, rather no god»")
	ck(sm.get_oath() == "warden", "the oath is the Warden's, as he picked (%s)" % sm.get_oath())
	await _lines_until_choice(dm)
	ck(shown.any(func(l: String) -> bool: return l.contains("level five")), "below level 5 the scribe says the path's strength comes at level 5")
	await Kit.drain(self)
	ck(game.get_quest_flag("city_gates_after_fight_complete"), "then the after-fight beat runs as before")
	var scribe: Node = room.get_node("GateScribe")
	ck(scribe.quest_marker() == &"" and scribe.menu_entries().map(func(e: Dictionary) -> String: return e.label) == ["Talk"], "after the census the scribe only talks")


# ── [3] Пряма відповідь через меню писаря (старий сейв без клятви) ───────────────────

func _census_direct() -> void:
	print("[3] The direct answer from the scribe's menu (an old save past the fight, no oath); level 5 opens the tree at once")
	var dm: Node = sl.get_dialogue_manager()
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	sl.get_game_manager().player_state.oath = ""  # той самий сейв до перепису
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	await game.teleport_to_room(GATES, ^"Arrival")
	await Kit.frames(self, 20)
	await Kit.drain(self)
	var scribe: Node = game.map.get_node("GateScribe")
	ck(scribe.quest_marker() == &"oath", "no oath yet: the crest over the scribe")
	hero.global_position = scribe.global_position + Vector2(-30, -10)
	await Kit.frames(self, 10)
	ck(scribe.npc_menu.visible and scribe.npc_menu.get_children().map(func(b: Button) -> String: return b.text) == ["Census"], "walking up opens his menu: Census")
	var focus_before := root.gui_get_focus_owner()
	await _key(KEY_ENTER)  # Enter на пункті у фокусі — вибрати
	await Kit.frames(self, 4)
	ck(dm.is_dialogue_active() and focus_before.text == "Census", "Enter picks Census: the census talk starts")
	shown.clear()
	await _lines_until_choice(dm)
	var menu_before: Array = _choices(dm)
	var picked: String = await _answer(dm, 1)
	ck(picked == "the god of contracts", "«Whom do you serve?» → the god of contracts (%s of %s; %s)" % [picked, menu_before, shown])
	ck(sm.get_oath() == "dark_knight", "the oath is the Dark Knight's (%s)" % sm.get_oath())
	await _lines_until_choice(dm)
	ck(not shown.any(func(l: String) -> bool: return l.contains("level five")), "at level 5 no «wait for level 5» line")
	await Kit.drain(self)
	sm.add_job_points(6)
	for id in ["toughness", "shield_block", "devotion"]:
		sm.unlock_skill(id)
	ck(sm.can_unlock("searing_hex") == 0, "already level 5: the Dark Knight tree is open at once")
	ck(sm.can_unlock("radiant_smite") != 0, "the other trees stay shut")


# ── [4] Журнал: герби ──────────────────────────────────────────────────────

func _journal() -> void:
	print("[4] The Journal's Characters page: three emblems, brighter with the leanings, no numbers")
	var sm: Node = sl.get_skill_manager()
	_reset_leanings()
	sm.leanings.add("samal", 6.0)
	sm.leanings.add("contract", 3.0)
	sl.get_ui_manager().open_game_menu()
	await Kit.frames(self, 14)
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	await Kit.frames(self, 10)
	var journal: Node = get_first_node_in_group("journal_screen")
	journal.select_section("characters")
	await Kit.frames(self, 4)
	var emblems: Control = journal.get_node("%PathEmblems")
	ck(emblems.visible and emblems.get_child_count() == 4, "the emblems show on Characters")
	ck(is_equal_approx(journal.emblem_brightness("samal"), 1.0) and journal.emblem_brightness("contract") < 1.0
			and journal.emblem_brightness("contract") > journal.emblem_brightness("none"), "brightness follows the leanings: %.2f / %.2f / %.2f"
			% [journal.emblem_brightness("samal"), journal.emblem_brightness("contract"), journal.emblem_brightness("none")])
	var texts: Array = emblems.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ck(not texts.any(func(t: String) -> bool: return t.is_valid_float()), "no numbers: %s" % [texts])
	journal.select_section("quests")
	await Kit.frames(self, 2)
	ck(not emblems.visible, "only on Characters")
	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 4)
	var topic: Array = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/tutorial.json")).topics.filter(func(t: Dictionary) -> bool: return t.id == "paths")
	ck(topic.size() == 1 and topic[0].hint_topic, "one «?» tip about the paths (tutorial.json → paths)")
	ck(FileAccess.get_file_as_string("res://SampleProject/Scripts/Managers/TutorialManager.gd").contains("show_tip(\"paths\")"), "shown through the tip tray when a leaning first grows")


# ── [5] Показ розмови і ім'я бога ────────────────────────────────────────

func _reader() -> void:
	print("[5] Replays skip the answers; the god of contracts is one key")
	var reader: GDScript = load("res://SampleProject/Scripts/Systems/dqd_reader.gd")
	var lines: Array[Dictionary] = reader.lines(CENSUS)
	ck(not lines.any(func(l: Dictionary) -> bool: return l.text.contains("Write it") or l.text.contains("My advice")), "DqdReader skips everything inside branches")
	var witch: Array[Dictionary] = reader.lines("res://dialogue_quest/City_Oath_Witch_Talk.dqd")
	ck(witch[0].text.contains("the god of contracts"), "${contract_god} solved in replays and bubbles (%s)" % witch[0].text)
	for path in [CENSUS, "res://dialogue_quest/City_Oath_Witch_Talk.dqd"]:
		for file in [path, path.replace("dialogue_quest/", "dialogue_quest/en/")]:
			var text := "\n".join(Array(FileAccess.get_file_as_string(file).split("\n")).filter(func(l: String) -> bool: return not l.begins_with("//")))
			ck(text.contains("${contract_god}") and not text.to_lower().contains("бог контрактів") and not text.to_lower().contains("god of contracts"),
					"%s names the god only through ${contract_god}" % file.trim_prefix("res://dialogue_quest/"))
	for file in ["City_Oath_Priest_Talk.dqd", "City_Oath_Witch_Talk.dqd", "City_Oath_Dervish_Talk.dqd"]:
		for dir in ["res://dialogue_quest/", "res://dialogue_quest/en/"]:
			var text := FileAccess.get_file_as_string(dir + file)
			ck(not text.contains("Небо") and not text.contains("the Sky") and not text.contains("Eclipse") and not text.contains("Затемнен"), "%s%s: no Sky / Eclipse worship (D718)" % [dir.trim_prefix("res://dialogue_quest/"), file])
