## Крок катсцени з відео
## Відтворює відео файл
extends CutsceneStep
class_name CutsceneVideoStep

## Шлях до відео файлу (.ogv)
@export var video_path: String = ""

## Чи автоматично переходити до наступного кроку після відео
@export var auto_advance: bool = true

## Посилання на VideoStreamPlayer
var video_player: VideoStreamPlayer = null

func _ready() -> void:
	super._ready()
	step_name = "VideoStep"

## Кастомна логіка виконання
func _on_execute() -> void:
	if video_path == "":
		push_warning("CutsceneVideoStep: video_path is empty")
		complete()
		return
	
	# Перевіряємо, чи файл існує
	if not ResourceLoader.exists(video_path):
		push_error("CutsceneVideoStep: Video file not found: ", video_path)
		complete()
		return
	
	# Створюємо або знаходимо VideoStreamPlayer
	_find_or_create_video_player()
	
	if not video_player:
		push_error("CutsceneVideoStep: Failed to create VideoStreamPlayer")
		complete()
		return
	
	# Завантажуємо відео
	var video_stream = load(video_path) as VideoStream
	if not video_stream:
		push_error("CutsceneVideoStep: Failed to load video: ", video_path)
		complete()
		return
	
	video_player.stream = video_stream
	video_player.visible = true
	
	# Відтворюємо відео
	video_player.play()
	
	# Чекаємо на завершення відео
	await video_player.finished
	
	# Ховаємо відео
	video_player.visible = false
	
	complete()

## Знаходить або створює VideoStreamPlayer
func _find_or_create_video_player() -> void:
	var scene_root = get_tree().current_scene
	if scene_root:
		video_player = scene_root.get_node_or_null("VideoPlayer") as VideoStreamPlayer
		if not video_player:
			# Створюємо новий
			video_player = VideoStreamPlayer.new()
			video_player.name = "VideoPlayer"
			video_player.size = Vector2(1920, 1080)  # Повноекранний режим
			video_player.anchors_preset = Control.PRESET_FULL_RECT
			video_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			video_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
			video_player.z_index = 1000  # Найвищий z-index
			video_player.visible = false
			
			# Додаємо до UICanvas або створюємо CanvasLayer
			var ui_canvas = scene_root.get_node_or_null("UICanvas")
			if ui_canvas:
				ui_canvas.add_child(video_player)
			else:
				var canvas = CanvasLayer.new()
				canvas.name = "VideoCanvas"
				canvas.layer = 1000
				canvas.add_child(video_player)
				scene_root.add_child(canvas)

## Скидає крок
func reset() -> void:
	super.reset()
	if video_player:
		video_player.stop()
		video_player.visible = false

