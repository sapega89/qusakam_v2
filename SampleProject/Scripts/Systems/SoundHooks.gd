extends Node

## Події гри → звуки (D276, design/audio_plan.md). Дочірній вузол AudioManager; грає лише через AudioManager.play.
## Рух героя (кроки, стрибок, ривок, драбина) озвучує PlayerMover — там видно кожен крок.


func _ready() -> void:
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.player_heavy_windup.connect(func(_player: Node, _direction: int) -> void: AudioManager.play(&"heavy_windup"))
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
	var heavy: bool = player.combat.state == PlayerCombat.State.HEAVY_STRIKE
	AudioManager.play(&"swing_heavy" if heavy else &"swing")


## Замах ворога чути: половина підказки «зараз ударить» (D215).
func _on_attack_started(attacker: Node, _target: Node) -> void:
	if attacker.is_in_group(GameGroups.ENEMIES):
		AudioManager.play(&"enemy_windup")


func _on_damage_received(target: Node, _source: Node, _amount: int) -> void:
	if target.is_in_group(GameGroups.PLAYER):
		AudioManager.play(&"hero_hurt")


## damage_dealt приходить лише з реального ушкодження (B60) — промах звуку влучання не дає.
func _on_damage_dealt(source: Node, target: Node, _amount: int) -> void:
	if VFXHooks.is_hero_side_hit(source, target):
		AudioManager.play(&"hit_heavy" if VFXHooks.is_heavy_hit(source) else &"hit")


func _on_parried(_attacker: Node) -> void:
	AudioManager.play(&"parry")
	AudioManager.play(&"hit_heavy")


## Зброя з'являється в руці на початку бою і зникає після (D268); голі руки — без звуку.
func _on_combat_state_changed(in_combat: bool) -> void:
	if GameGroups.get_player().combat.grip == &"bare":
		return
	AudioManager.play(&"draw" if in_combat else &"sheathe")
