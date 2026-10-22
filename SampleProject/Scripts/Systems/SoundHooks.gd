extends Node

## Події гри → звуки (D276, design/audio_plan.md). Дочірній вузол AudioManager; грає лише через AudioManager.play.
## Рух героя (кроки, стрибок, ривок, драбина) озвучує PlayerMover — там видно кожен крок.


func _ready() -> void:
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.player_heavy_windup.connect(func(_player: Node, _direction: int) -> void:
		AudioManager.play(&"heavy_windup")
		AudioManager.play(&"hero_effort"))
	EventBus.attack_started.connect(_on_attack_started)
	EventBus.damage_received.connect(_on_damage_received)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.player_blocked.connect(func(_attacker: Node) -> void: AudioManager.play(&"block"))
	EventBus.player_parried.connect(_on_parried)
	EventBus.enemy_staggered.connect(func(_enemy: Node, _duration: float) -> void: AudioManager.play(&"stagger"))
	EventBus.combat_state_changed.connect(_on_combat_state_changed)
	EventBus.skill_cast_started.connect(_on_cast_started)
	EventBus.skill_used.connect(_on_skill_used)
	EventBus.skill_interrupted.connect(func(_id: String) -> void:
		_casting = ""
		AudioManager.play(&"cast_interrupt"))
	EventBus.player_landed.connect(func(_height: float) -> void: AudioManager.play(&"land"))
	EventBus.item_added.connect(func(id: String, _amount: int) -> void: AudioManager.play(&"coin" if id == "coin" else &"pickup"))
	EventBus.player_leveled_up.connect(func(_level: int, _old: int) -> void: AudioManager.play(&"level_up"))
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.player_died.connect(func() -> void: AudioManager.play(&"hero_death"))
	EventBus.assist_called.connect(func(id: String) -> void: AudioManager.play(StringName("call_" + id)))


## Навичка, чий замах звучить: її вивільнення — свій звук (пасивні й навички без касту — без звуку).
var _casting: String = ""


func _on_cast_started(id: String) -> void:
	_casting = id
	AudioManager.play(StringName("cast_%s_windup" % id))


func _on_skill_used(id: String) -> void:
	if id == _casting:
		_casting = ""
		AudioManager.play(StringName("cast_%s_release" % id))


## Кожен замах чути — і влучний, і промах (D276); важкий — нижчий.
func _on_player_attacked(player: Node, _direction: int) -> void:
	var combat: PlayerCombat = player.combat
	var heavy: bool = combat.state == PlayerCombat.State.HEAVY_STRIKE
	AudioManager.play(&"swing_heavy" if heavy else &"swing")
	if not heavy and combat.combo_step == combat.combo_length() - 1:
		AudioManager.play(&"hero_effort")  # фінішер серії — з вигуком


## Замах ворога чути: половина підказки «зараз ударить» (D215).
## Голос: бос реве на першому замаху й кричить на кожному другому (D278), решта ворогів гарчить на кожному третьому.
func _on_attack_started(attacker: Node, _target: Node) -> void:
	if not attacker.is_in_group(GameGroups.ENEMIES):
		return
	AudioManager.play(&"enemy_windup")
	var swings: int = attacker.get_meta(&"voiced_swings", 0)
	attacker.set_meta(&"voiced_swings", swings + 1)
	if _is_boss(attacker):
		if swings == 0:
			AudioManager.play(&"boss_roar")
		elif swings % 2 == 0:
			AudioManager.play(&"boss_shout")
	elif swings % 3 == 2:
		AudioManager.play(&"enemy_grunt", _enemy_pitch(attacker))


func _is_boss(enemy: Node) -> bool:
	return enemy.is_in_group(GameGroups.BOSS) or enemy.is_in_group(GameGroups.MINIBOSS)


func _enemy_pitch(enemy: Node) -> float:
	return AudioManager.enemy_voice_pitch[enemy.enemy_stats.enemy_type]


## Удар і голос: біль, а останній удар — смерть (damage_received приходить, коли HP вже 0, перед die()).
func _on_damage_received(target: Node, source: Node, _amount: int) -> void:
	var alive: bool = target.current_health > 0
	if target.is_in_group(GameGroups.PLAYER):
		AudioManager.play(&"hero_hurt")
		AudioManager.play(&"hit_heavy" if VFXHooks.is_big_hurt(source) else &"hit")  # 4b: удар чути, не лише стогін
		if alive:
			AudioManager.play(&"hero_hurt_voice")  # смерть озвучує player_died
	elif target.is_in_group(GameGroups.ENEMIES):
		if _is_boss(target):
			if not alive:
				AudioManager.play(&"boss_death")
		else:
			AudioManager.play(&"enemy_grunt" if alive else &"enemy_death", _enemy_pitch(target))


## damage_dealt приходить лише з реального ушкодження (B60) — промах звуку влучання не дає (свист замаху — так).
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if VFXHooks.is_hero_side_hit(source, target):
		AudioManager.play(&"hit_heavy" if VFXHooks.hit_strength(source) > 0 else &"hit")
		# 4b: шар матеріалу під ударом — панцир (tank, front_damage < 1) дзвенить, решта — плоть
		AudioManager.play(&"hit_armour" if target.front_damage < 1.0 else &"hit_flesh")


func _on_parried(_attacker: Node) -> void:
	AudioManager.play(&"parry")
	AudioManager.play(&"hit_heavy")


## Зброя з'являється в руці на початку бою і зникає після (D268); голі руки — без звуку.
func _on_combat_state_changed(in_combat: bool) -> void:
	if GameGroups.get_player().combat.grip == &"bare":
		return
	AudioManager.play(&"draw" if in_combat else &"sheathe")


# ── Кімната: петля атмосфери й двері (D276) ────────────────────────────────────

## Петля атмосфери поточної кімнати (дочірня Game — іде разом із грою, напр. вихід у меню) і її подія.
var ambience: AudioStreamPlayer = null
var _ambience_event: StringName = &""
var _room: String = ""


## Атмосфера кімнати; та сама петля в сусідній кімнаті грає далі без розриву.
## Двері — коли перехід веде в приміщення або з нього (MayorHall, Laboratory).
func _on_room_entered(room_name: String) -> void:
	var entry: Dictionary = AudioManager.room(room_name)
	if not is_instance_valid(ambience):
		_room = ""  # гра почалась заново (петля пішла разом зі старою Game)
	elif AudioManager.room(_room).interior != entry.interior:
		AudioManager.play(&"door")
	_room = room_name
	var event := StringName(entry.ambience)
	if is_instance_valid(ambience):
		if _ambience_event == event:
			return
		ambience.queue_free()
	ambience = AudioManager.play_loop(event, Game.get_singleton())
	ambience.name = "Ambience"
	_ambience_event = event


# ── Голоси персонажів (D277) ──────────────────────────────────────────────────

var _letters: int = 0


## Набрано літеру [param letter] репліки персонажа [param character_id]: склад його голосом на кожну другу літеру.
## Пробіли й розділові знаки мовчать; оповідь без мовця ("") — теж.
func letter(character_id: String, letter_typed: String) -> void:
	if character_id == "" or letter_typed.to_upper() == letter_typed.to_lower():
		return
	_letters += 1
	if _letters % 2 == 0:
		AudioManager.play(StringName("babble_" + _voice(character_id)))


## Привітання NPC, коли герой сам заговорив до нього (NpcBase). Катсцени першої зустрічі запускають кімнати, не NpcBase.
## Мовою гри (BACKLOG 31): англійські — Kokoro (D277), українські — greet_<голос>_uk (Piper, make_voices_uk.py).
func greet(character_id: String) -> void:
	AudioManager.play(greet_event(character_id))


func greet_event(character_id: String) -> StringName:
	var event := "greet_" + _voice(character_id)
	return StringName(event + "_uk" if TranslationServer.get_locale() == "uk" else event)


## Мовець вікна діалогу за ім'ям, яке показує вікно (DialogueQuest не каже id мовця).
func speaker_from_name(character_name: String) -> String:
	if character_name == "":
		return ""
	var registry: Dictionary = DialogueQuest.CharacterDB.get_character_registry()
	for id: String in registry:
		if registry[id].character_name == character_name:
			return id
	assert(false, "SoundHooks: no DialogueQuest character is named %s" % character_name)
	return ""


func _voice(character_id: String) -> String:
	assert(AudioManager.voices.has(character_id), "SoundHooks: character %s has no voice in sound_events.json → voices" % character_id)
	return AudioManager.voices[character_id]
