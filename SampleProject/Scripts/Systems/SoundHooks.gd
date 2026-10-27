extends Node

## Події гри → звуки (D276, design/audio_plan.md). Дочірній вузол AudioManager; грає лише через AudioManager.play.
## Рух героя (кроки, стрибок, ривок, драбина) озвучує PlayerMover — там видно кожен крок.


func _ready() -> void:
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.player_heavy_windup.connect(func(_player: Node, _direction: int) -> void:
		AudioManager.play(&"heavy_windup")
		AudioManager.play(&"hero_effort"))
	# Лук (D380): натяг тихо скрипить, постріл свистить; заряджений — нижче й гучніше
	EventBus.player_bow_drawn.connect(func(_player: Node) -> void: AudioManager.play(&"bow_draw"))
	EventBus.player_shot.connect(func(_player: Node, charged: bool) -> void:
		AudioManager.play(&"bow_shot_charged" if charged else &"bow_shot"))
	EventBus.attack_started.connect(_on_attack_started)
	# Підказка удару (D504): білий, жовтий і червоний — кожен свій звук
	EventBus.enemy_tell_shown.connect(func(_enemy: Node, kind: StringName) -> void: AudioManager.play(StringName("tell_" + kind)))
	EventBus.damage_received.connect(_on_damage_received)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.player_blocked.connect(func(_attacker: Node) -> void: AudioManager.play(&"block"))
	# D776: виснажений герой пробує діяти — глухий видих; не частіше, ніж раз на спалах рядка ST
	EventBus.player_stamina_refused.connect(_on_stamina_refused)
	EventBus.enemy_shield_blocked.connect(func(_enemy: Node2D, _at: Vector2) -> void: AudioManager.play(&"block"))
	EventBus.enemy_shield_broken.connect(func(_enemy: Node2D, _at: Vector2) -> void:
		AudioManager.play(&"hit_heavy")
		AudioManager.play(&"hit_armour"))
	EventBus.player_parried.connect(_on_parried)
	EventBus.enemy_staggered.connect(func(_enemy: Node, _duration: float) -> void: AudioManager.play(&"stagger"))
	EventBus.combat_state_changed.connect(_on_combat_state_changed)
	EventBus.boss_fight_changed.connect(_on_boss_fight_changed)
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
	EventBus.assist_denied.connect(func(_id: String) -> void: AudioManager.play(&"assist_denied"))


var _refused_at := -1000.0


func _on_stamina_refused() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _refused_at < UITokens.STAMINA_FLASH_TIME:
		return
	_refused_at = now
	AudioManager.play(&"stamina_empty")


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
## Голос: бос реве на першому замаху й кричить на кожному другому (D278) — свої звуки в кожного боса (boss_voices,
## D310: джин на другому замаху сміється), решта ворогів гарчить на кожному третьому.
func _on_attack_started(attacker: Node, _target: Node) -> void:
	if not attacker.is_in_group(GameGroups.ENEMIES):
		return
	AudioManager.play(&"enemy_windup")
	var swings: int = attacker.get_meta(&"voiced_swings", 0)
	attacker.set_meta(&"voiced_swings", swings + 1)
	if _is_boss(attacker):
		if swings == 0:
			AudioManager.play(_boss_voice(attacker, "roar"))
		elif swings % 2 == 0:
			AudioManager.play(_boss_voice(attacker, "shout"))
	elif swings % 3 == 2:
		AudioManager.play(&"enemy_grunt", _enemy_pitch(attacker))


func _is_boss(enemy: Node) -> bool:
	return enemy.is_in_group(GameGroups.BOSS) or enemy.is_in_group(GameGroups.MINIBOSS)


func _boss_voice(boss: Node, kind: String) -> StringName:
	return AudioManager.boss_voice(boss.enemy_stats.enemy_type, kind)


func _enemy_pitch(enemy: Node) -> float:
	return AudioManager.enemy_voice_pitch[enemy.enemy_stats.enemy_type]


## Удар і голос: біль, а останній удар — смерть (damage_received приходить, коли HP вже 0, перед die()).
func _on_damage_received(target: Node, source: Node, _amount: int, _critical: bool) -> void:
	var alive: bool = target.current_health > 0
	if target.is_in_group(GameGroups.PLAYER):
		AudioManager.play(&"hero_hurt")
		AudioManager.play(&"hit_heavy" if VFXHooks.is_big_hurt(source) else &"hit")  # 4b: удар чути, не лише стогін
		if alive:
			AudioManager.play(&"hero_hurt_voice")  # смерть озвучує player_died
	elif target.is_in_group(GameGroups.ENEMIES):
		if _is_boss(target):
			if not alive:
				AudioManager.play(_boss_voice(target, "death"))
		else:
			AudioManager.play(&"enemy_grunt" if alive else &"enemy_death", _enemy_pitch(target))


## Звук влучання за силою удару (VFXHooks.hit_strength, D581): легкий, фінішер / відкидання, важкий, рипост.
## Блок і парирування мають свої (block, parry) — _ready, _on_parried.
const HIT_SOUNDS: Array[StringName] = [&"hit", &"hit_heavy", &"hit_strike", &"hit_riposte"]


## damage_dealt приходить лише з реального ушкодження (B60) — промах звуку влучання не дає (свист замаху — так).
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if VFXHooks.is_hero_side_hit(source, target):
		AudioManager.play(HIT_SOUNDS[VFXHooks.hit_strength(source)])
		# 4b: шар матеріалу під ударом — панцир (tank, front_damage < 1) дзвенить, решта — плоть
		AudioManager.play(&"hit_armour" if target.front_damage < 1.0 else &"hit_flesh")


func _on_parried(_attacker: Node) -> void:
	AudioManager.play(&"parry")
	AudioManager.play(&"hit_heavy")


## Зброя з'являється в руці на початку бою і зникає після (D268); голі руки — без звуку.
func _on_combat_state_changed(in_combat: bool) -> void:
	_in_fight = in_combat
	_update_music()
	if GameGroups.get_player().combat.grip == &"bare":
		return
	AudioManager.play(&"draw" if in_combat else &"sheathe")


# ── Музика бою (D414, music_plan slice 3) ─────────────────────────────────────

## Герой у бою (combat_state_changed) і зала боса, де йде бій (boss_fight_changed); бос перекриває бій.
var _in_fight: bool = false
var _boss_arena: Node = null
## Програвач, який дав ProjectMusicController.play_stream для бою; поки грає він — кімнатна музика відкладена.
var _music_override: AudioStreamPlayer = null
## Трек кімнати, до якого музика вертається після бою.
var _room_music: AudioStream = null


func _on_boss_fight_changed(arena: Node, active: bool) -> void:
	if active:
		_boss_arena = arena
		if not arena.tree_exiting.is_connected(_on_boss_arena_left.bind(arena)):
			arena.tree_exiting.connect(_on_boss_arena_left.bind(arena))
	elif arena == _boss_arena:
		_boss_arena = null
	_update_music()


## Зала зникла посеред бою (телепорт, вихід у меню, завантаження) — бою з босом більше немає.
## Музику вже перемикає вузол Music наступної сцени.
func _on_boss_arena_left(arena: Node) -> void:
	if arena == _boss_arena:
		_boss_arena = null


## Одна музика через maaacks ProjectMusicController: бос → його трек, бій → бойовий, інакше — трек кімнати.
## Вузол Music нової сцени контролер підхоплює сам; тоді його трек і є кімнатним.
func _update_music() -> void:
	var current: AudioStreamPlayer = ProjectMusicController.music_stream_player
	if current != _music_override:
		_music_override = null
		_room_music = current.stream if is_instance_valid(current) else null
	var track: AudioStream = null
	if _boss_arena != null:
		track = AudioManager.music["boss"]
	elif _in_fight:
		track = AudioManager.music["fight"]
	if track == null:
		if _music_override != null:
			assert(_room_music != null, "SoundHooks: fight music ended with no room Music to return to")
			_music_override = null
			ProjectMusicController.play_stream(_room_music)
		return
	if _music_override == null or _music_override.stream != track:
		_music_override = ProjectMusicController.play_stream(track)


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
		_in_fight = false  # бій старого героя пішов разом із ним
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
