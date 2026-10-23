extends Area2D

## Шматок історії у світі (D583, D606): записка, папери, малюнок на стіні — у світі блиск, як предмет (D446).
## Поруч — "Read"; interact показує текст (модалка misc_popup) і пише знахідку в журнал
## (JournalRecords.find_story → player_state.journal.stories, у сейві).
## Текст — Resources/Data/journal_stories.json за [member story_id]. Читати можна знову.

signal read(story_id: String)

const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")

@export var story_id: String = ""

@onready var _interactable: InteractableComponent = $Interactable


func _ready() -> void:
	JournalRecords.story(story_id)  # невідомий id — помилка даних одразу, а не при читанні
	_interactable.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var entry: Dictionary = JournalRecords.story(story_id)
	JournalRecords.find_story(story_id)
	ServiceLocator.get_ui_manager().show_modal(ModalTemplates.misc_popup(tr(entry.title), tr(entry.text)))
	read.emit(story_id)
