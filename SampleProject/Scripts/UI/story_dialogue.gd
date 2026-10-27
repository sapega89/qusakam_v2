extends Control

## Сюжетна подача розмови (D110–D112, Figma conversation-dialog-choices 36:65) — наш шар показу поверх даних
## DialogueQuest. Затемнена сцена, назва локації вгорі ліворуч під тонкою лінією (D565: розділ = локація),
## дві картки на весь зріст — герой ліворуч, співрозмовник праворуч, світиться той, хто говорить, — вікно
## репліки впоперек нижньої середини (%Box, StoryDialogueBox.gd) і підказки клавіш унизу.
## DialogueManager.start_dialogue() віддає плеєру %Box замість звичайного вікна для розмов зі story_dialogues.gd;
## шар видно рівно тоді, коли видно %Box (його показує й ховає DialoguePlayer).
## Розкладка — у .tscn, розміри й кольори — UITokens (застосовує _ready), стилі — GameUITheme.

const StoryDialogues = preload("res://SampleProject/Scripts/Systems/story_dialogues.gd")
const DqdReader = preload("res://SampleProject/Scripts/Systems/dqd_reader.gd")
const StoryDialogueBox = preload("res://SampleProject/Scripts/UI/StoryDialogueBox.gd")

## Список відповідей (DialogueSystem.tscn): поки він видно, вікно не гортає саме (D736, D739).
@export var choice_menu: Control
@onready var box: StoryDialogueBox = %Box
@onready var _hero_card: Control = %HeroCard
@onready var _speaker_card: Control = %SpeakerCard
@onready var _hero_frame: TextureRect = %HeroFrame
@onready var _speaker_frame: TextureRect = %SpeakerFrame
## Хто зараз на правій картці (id DialogueQuest).
var speaker_on_card := ""


func _ready() -> void:
	visible = false
	%Scrim.color = UITokens.STORY_SCRIM
	var chapter: Control = %Chapter
	chapter.offset_left = UITokens.STORY_MARGIN
	chapter.offset_top = UITokens.STORY_MARGIN
	chapter.add_theme_constant_override(&"separation", UITokens.SPACE_MD)
	%ChapterTitle.add_theme_font_size_override(&"font_size", UITokens.SIZE_STORY_CHAPTER)
	%ChapterRule.custom_minimum_size.x = UITokens.STORY_CHAPTER_RULE
	%ChapterRule.color = UITokens.STORY_RULE
	box.get_node(^"%NameRule").color = UITokens.STORY_RULE
	box.get_node(^"%BobbingMarker").modulate = UITokens.ACCENT  # Figma: маленький золотий ромб «далі»
	box.choice_menu = choice_menu
	box.offset_left = -UITokens.STORY_BOX_WIDTH / 2.0
	box.offset_right = UITokens.STORY_BOX_WIDTH / 2.0
	var box_height := _box_height()
	box.offset_bottom = -UITokens.STORY_BOX_BOTTOM
	box.offset_top = box.offset_bottom - box_height
	for card: Control in [_hero_card, _speaker_card]:
		card.custom_minimum_size = UITokens.STORY_CARD_SIZE
		card.offset_top = -UITokens.STORY_BOX_BOTTOM - _box_height() - UITokens.STORY_CARD_GAP - UITokens.STORY_CARD_SIZE.y
		card.offset_bottom = card.offset_top + UITokens.STORY_CARD_SIZE.y
	_hero_card.offset_left = -UITokens.STORY_BOX_WIDTH / 2.0
	_hero_card.offset_right = _hero_card.offset_left + UITokens.STORY_CARD_SIZE.x
	_speaker_card.offset_right = UITokens.STORY_BOX_WIDTH / 2.0
	_speaker_card.offset_left = _speaker_card.offset_right - UITokens.STORY_CARD_SIZE.x
	# Підказки — спільна панель UI/Bottom Bar (без смуги, PlainPanel), лише дії: їх видно під правим краєм вікна.
	var hints: UIBottomBar = %Hints
	hints.set_default_hint("")
	hints.set_actions([
		{"action": &"dq_accept", "label": "Next line of dialogue"},
		{"action": &"dq_accept", "label": "Hold: skip to the choice"},
	])
	hints.offset_left = -UITokens.STORY_BOX_WIDTH / 2.0
	hints.offset_right = UITokens.STORY_BOX_WIDTH / 2.0
	hints.offset_bottom = -UITokens.STORY_HINTS_BOTTOM
	hints.offset_top = hints.offset_bottom - hints.custom_minimum_size.y
	box.visibility_changed.connect(func() -> void: visible = box.visible)
	box.speaker_changed.connect(_on_speaker_changed)


## Висота вікна з .tscn (найменша, B122): картки стоять над ним, хоч би як вікно росло вгору під довгу репліку.
func _box_height() -> float:
	return box.offset_bottom - box.offset_top


## Перед першою реплікою [param path]: назва локації кімнати, де стоїть герой, і картки — герой та перший
## співрозмовник розмови (щоб права картка не була порожньою на репліці героя чи оповідача).
func open(path: String, room_scene: String) -> void:
	# Ключ назви локації (англійська назва, D121): Label перекладає його сам, тож назва міняється разом із мовою.
	speaker_on_card = ""
	%ChapterTitle.text = ServiceLocator.get_game_flow().location_title(room_scene)
	_show(_hero_frame, StoryDialogues.HERO)
	for line: Dictionary in DqdReader.lines(path):
		if line.speaker != "" and line.speaker != StoryDialogues.HERO:
			_show(_speaker_frame, line.speaker)
			speaker_on_card = line.speaker
			break
	_on_speaker_changed("")


## Говорить герой — світиться ліва картка; інший — права (з його кадром); оповідач — жодна.
func _on_speaker_changed(speaker: String) -> void:
	if speaker != "" and speaker != StoryDialogues.HERO and speaker != speaker_on_card:
		_show(_speaker_frame, speaker)
		speaker_on_card = speaker
	_hero_card.modulate = Color.WHITE if speaker == StoryDialogues.HERO else UITokens.STORY_CARD_IDLE
	_speaker_card.modulate = Color.WHITE if speaker != "" and speaker == speaker_on_card else UITokens.STORY_CARD_IDLE
	_speaker_card.visible = speaker_on_card != ""


## Кадр персонажа в картці: ціле збільшення, що влазить (піксель лишається чітким, D112), ногами донизу картки.
func _show(frame: TextureRect, speaker: String) -> void:
	var texture: AtlasTexture = StoryDialogues.card(speaker)
	var room: Vector2 = UITokens.STORY_CARD_SIZE - Vector2(UITokens.SPACE_MD, UITokens.SPACE_MD) * 2.0
	var scale_up: float = floorf(minf(room.x / texture.region.size.x, room.y / texture.region.size.y))
	frame.texture = texture
	frame.custom_minimum_size = texture.region.size * scale_up
