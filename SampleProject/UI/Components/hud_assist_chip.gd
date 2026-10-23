extends Control

## Чип F під панеллю героя — асист компаньйона (D209, D515, D525; HUD v2, Figma 501:6611). Був слотом хотбара,
## тепер чип («QF прибери з панелі», D549). Три стани:
##   готовий — портрет того, хто вийде, золотий бейдж;
##   на полі — портрет того, хто виступає, світіння чипа пульсує (ASSIST_PULSE_TIME), бейдж згаслий;
##   кулдаун — наступний у черзі тьмяно (ASSIST_COOLDOWN_DIM), із залишком секунд.
## Відмова кнопки — портрет і секунди тремтять (ASSIST_SHAKE_*; звук — SoundHooks). Нікого в загоні — чипа немає.
## Стан бере CompanionManager; чип лише показує.

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

@onready var _glow: Control = $Glow
@onready var _portrait: TextureRect = $Mask/Portrait
@onready var _cooldown: Label = $Cooldown
@onready var _badge: TextureRect = $Badge
@onready var _key: Label = $Badge/Key

## Що зараз намальовано ("id:стан").
var _shown := ""
var _pulse: Tween
var _shake: Tween
## Місця портрета й секунд у сцені — трус вертається сюди.
var _portrait_home := 0.0
var _seconds_home := 0.0


func _ready() -> void:
	EventBus.assist_denied.connect(_on_assist_denied)
	EventBus.input_device_changed.connect(func(_pad: bool) -> void: _key.text = InputGlyphs.badge(&"assist"))
	_key.text = InputGlyphs.badge(&"assist")
	_portrait_home = _portrait.position.x
	_seconds_home = _cooldown.position.x


## Зсув портрета від його місця — тест тремтіння.
func shake_offset() -> float:
	return _portrait.position.x - _portrait_home


## Лише з _process: хто відкритий — це прапорці Game, а HUD готовий раніше за Game (він його дитина).
func _process(_delta: float) -> void:
	var cm := ServiceLocator.get_companion_manager()
	var state: CompanionManager.State = cm.get_state()
	visible = state != CompanionManager.State.NONE
	if not visible:
		return
	_cooldown.text = tr("%ds") % ceili(cm.get_remaining_cooldown())
	var id: String = cm.get_active() if state == CompanionManager.State.ACTIVE else cm.get_next_in_queue()
	# Портрет і стани — лише коли змінився хто / стан, не щокадру.
	var shown := "%s:%d" % [id, state]
	if shown == _shown:
		return
	_shown = shown
	var active := state == CompanionManager.State.ACTIVE
	var cooldown := state == CompanionManager.State.COOLDOWN
	_portrait.texture = load(CompanionManager.PORTRAIT_PATH % id)
	var dim := UITokens.ASSIST_COOLDOWN_DIM
	_portrait.modulate = Color(dim, dim, dim) if cooldown else Color.WHITE
	_cooldown.visible = cooldown
	var neutral := UITokens.HUD_BADGE_NEUTRAL
	_badge.modulate = Color.WHITE if state == CompanionManager.State.READY else Color(neutral, neutral, neutral)
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	_glow.visible = active
	if active:
		_glow.modulate.a = 0.0
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_glow, ^"modulate:a", 1.0, UITokens.ASSIST_PULSE_TIME / 2.0).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_glow, ^"modulate:a", 0.0, UITokens.ASSIST_PULSE_TIME / 2.0).set_trans(Tween.TRANS_SINE)


## Стан для тестів і захоплень: "ready" / "active" / "cooldown" / "none".
func shown_state() -> String:
	if not visible:
		return "none"
	if _pulse != null and _pulse.is_running():
		return "active"
	if _cooldown.visible and _portrait.modulate.r < 1.0:
		return "cooldown"
	return "ready" if _badge.modulate == Color.WHITE else "?"


## Кнопку натиснули, поки компаньйон на полі чи йде кулдаун (D515): портрет і залишок тремтять.
func _on_assist_denied(_id: String) -> void:
	if _shake != null:
		_shake.kill()
	var shake_px := UITokens.ASSIST_SHAKE_PX
	var step := UITokens.ASSIST_SHAKE_TIME / 4.0
	_shake = create_tween()
	for x: float in [shake_px, -shake_px, shake_px / 2.0, 0.0]:
		_shake.tween_property(_portrait, ^"position:x", _portrait_home + x, step)
		_shake.parallel().tween_property(_cooldown, ^"position:x", _seconds_home + x, step)
