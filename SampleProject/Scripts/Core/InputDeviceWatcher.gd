extends Node

## Бачить увесь ввід і повідомляє InputGlyphs про пристрій (BACKLOG 24): підказки й бейджі нижньої панелі
## називають кнопку геймпада, коли останнім був геймпад, у кожному меню, а не лише там, де є свій слухач.
## Створює GameManager; працює й на паузі (меню ставлять гру на паузу).

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	InputGlyphs.note_event(event)
