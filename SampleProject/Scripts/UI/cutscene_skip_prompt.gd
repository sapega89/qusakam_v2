extends CanvasLayer

## Пропуск кат-сцени (D308): поки йде сцена, у куті «Hold <кнопка> to skip»; утримання cutscene_skip HOLD_TIME
## секунд справжнього часу (не ігрового — пропуск сам прискорює гру) — skip_requested, і далі кожна репліка
## гортається сама до кінця сцени. Кнопка — за останнім пристроєм (InputGlyphs, D289).

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

signal skip_requested

const HOLD_TIME := 1.0

var skipping := false
var _held_since := -1

@onready var _label: Label = %SkipLabel
@onready var _fill: ProgressBar = %SkipFill


func _ready() -> void:
	_refresh_label()


func _input(event: InputEvent) -> void:
	if InputGlyphs.note_event(event):
		_refresh_label()


func _process(_delta: float) -> void:
	if skipping:
		_skip_line()
		return
	if Input.is_action_pressed(&"cutscene_skip"):
		if _held_since < 0:
			_held_since = Time.get_ticks_msec()
		var held := (Time.get_ticks_msec() - _held_since) / 1000.0
		_fill.value = minf(held / HOLD_TIME, 1.0)
		if held >= HOLD_TIME:
			skipping = true
			_label.text = tr("Skipping…")
			skip_requested.emit()
	else:
		_held_since = -1
		_fill.value = 0.0


func _refresh_label() -> void:
	if not skipping:
		_label.text = tr("Hold %s to skip") % InputGlyphs.label(&"cutscene_skip")


func _skip_line() -> void:
	ServiceLocator.get_dialogue_manager().skip_line()
