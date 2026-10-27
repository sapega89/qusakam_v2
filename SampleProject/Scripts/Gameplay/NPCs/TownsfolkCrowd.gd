extends Node2D

## Жителі кімнати (D740): вузол-батько для Townsfolk. Коли житель проходить повз героя, час від часу каже одну
## репліку мимохідь (DialogueManager.say_line_in_passing — те саме облачко, що й у інших NPC). Не під час бою,
## розмови, меню чи облачка; між репліками — пауза, і одна й та сама не повторюється, доки не прозвучать усі.

signal barked(walker: Node2D, line: String)

## Репліки — ключі .po (англійський текст).
@export var lines: PackedStringArray = PackedStringArray()
## Житель ближче до героя за це (px) — може заговорити.
@export var bark_radius: float = 110.0
## Пауза між репліками натовпу, секунд (випадково між).
@export var bark_gap_min: float = 8.0
@export var bark_gap_max: float = 16.0
## Натовп є лише з цим прапорцем квесту (порожньо — завжди): черга біля брами — після бою (у бій жителі не лізуть).
@export var with_flag: String = ""

## Скільки секунд до наступної можливої репліки.
var _gap := 0.0
var _deck: Array[String] = []


func _ready() -> void:
	assert(not lines.is_empty(), "TownsfolkCrowd: no lines (%s)" % get_path())
	_gap = randf_range(0.0, bark_gap_min)
	if with_flag != "":
		var game := Game.get_singleton()
		_show(bool(game.get_quest_flag(with_flag)))
		game.quest_flag_changed.connect(_on_quest_flag_changed)


func _process(delta: float) -> void:
	_gap -= delta
	if _gap > 0.0 or not _may_bark():
		return
	var walker := _nearest_walker()
	if walker == null:
		return
	var line := _next_line()
	if ServiceLocator.get_dialogue_manager().say_line_in_passing(walker, tr(line), walker.call(&"chatter_anchor")):
		_gap = randf_range(bark_gap_min, bark_gap_max)
		barked.emit(walker, line)


func walkers() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child: Node in get_children():
		out.append(child as Node2D)
	return out


func _may_bark() -> bool:
	if not visible:
		return false
	var dm := ServiceLocator.get_dialogue_manager()
	if dm.is_dialogue_active() or dm.is_bubble_playing():
		return false
	if not ServiceLocator.get_ui_manager().is_gameplay_input_allowed():
		return false
	return not Game.get_singleton().player.combat.in_combat()


## Найближчий до героя житель на вулиці в межах bark_radius, або null — нікого поруч.
func _nearest_walker() -> Node2D:
	var hero := Game.get_singleton().player
	var best: Node2D = null
	var best_distance := bark_radius
	for walker: Node2D in walkers():
		var distance := walker.global_position.distance_to(hero.global_position)
		if walker.call(&"is_out") and distance < best_distance:
			best = walker
			best_distance = distance
	return best


func _next_line() -> String:
	if _deck.is_empty():
		_deck.assign(lines)
		_deck.shuffle()
	return _deck.pop_back()


func _on_quest_flag_changed(flag: String, value: Variant) -> void:
	if flag == with_flag:
		_show(bool(value))


func _show(on: bool) -> void:
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
