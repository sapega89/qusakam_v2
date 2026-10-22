extends Node

## 🖥️ DisplayManager - Управление настройками отображения
## Отвечает за fullscreen, vsync и другие настройки дисплея
## Используется SaveSystem и BaseOptionsComponent

signal display_mode_changed(mode: String)
signal vsync_changed(enabled: bool)
signal resolution_changed(size: Vector2i)
signal fps_limit_changed(fps: int)

## Settings plan slice 1 (D66): Windowed / Fullscreen / Borderless — значення ключа "display_mode".
## Fullscreen — ексклюзивний повноекранний режим; Borderless — вікно без рамки на весь екран
## (у Godot це WINDOW_MODE_FULLSCREEN). Обидва йдуть у рідній роздільності екрана.
const DISPLAY_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
const _WINDOW_MODES: Dictionary = {
	"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
	"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
}

## BACKLOG 41 (settings_plan.md "Resolution / Frame Rate Limit", Sapega: дати ці налаштування).
## Ключ налаштування — рядок "ШxВ": словник налаштувань пишеться в JSON слота, Vector2i там не живе.
const RESOLUTIONS: Array[String] = ["1280x720", "1600x900", "1920x1080", "2560x1440"]
## 0 = без обмеження (Engine.max_fps = 0).
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 0]

## Останні застосовані значення. Headless-драйвер ігнорує режим і розмір вікна — тест читає ці поля.
var display_mode: String = "windowed"
var resolution: Vector2i = Vector2i.ZERO

## Режим вікна зі списку DISPLAY_MODES.
func set_display_mode(mode: String) -> void:
	if not DISPLAY_MODES.has(mode):
		push_error("DisplayManager: unknown display mode '%s'" % mode)
		return
	display_mode = mode
	DisplayServer.window_set_mode(_WINDOW_MODES[mode])
	display_mode_changed.emit(mode)
	print("🖥️ DisplayManager: display mode ", mode)

## Windowed — єдиний режим, де діє Resolution.
func is_windowed() -> bool:
	return display_mode == "windowed"

## Установить VSync
func set_vsync(enabled: bool):
	"""Устанавливает VSync"""
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vsync_changed.emit(enabled)
	print("🖥️ DisplayManager: VSync ", "enabled" if enabled else "disabled")

## Получить текущее состояние VSync
func is_vsync_enabled() -> bool:
	"""Возвращает true, если включен VSync"""
	return DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

## "1920x1080" → Vector2i(1920, 1080). Лише значення зі списку RESOLUTIONS
## (assert зникає в релізній збірці — тому push_error і Vector2i.ZERO).
static func parse_resolution(value: String) -> Vector2i:
	if not RESOLUTIONS.has(value):
		push_error("DisplayManager: unknown resolution '%s'" % value)
		return Vector2i.ZERO
	var parts: PackedStringArray = value.split("x")
	return Vector2i(int(parts[0]), int(parts[1]))


## Розмір вікна у режимі Windowed. Повноекранний режим завжди йде в рідній роздільності екрана
## (stretch canvas_items масштабує 1920×1080 вʼюпорт), тож там значення лише зберігається
## і стає розміром вікна, щойно гравець повернеться у Windowed.
func set_resolution(value: String) -> void:
	var size: Vector2i = parse_resolution(value)
	if size == Vector2i.ZERO:
		return
	resolution = size
	if is_windowed():
		DisplayServer.window_set_size(resolution)
		var screen: int = DisplayServer.window_get_current_screen()
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(usable.position + (usable.size - resolution) / 2)
	resolution_changed.emit(resolution)


## 0 — без обмеження.
func set_fps_limit(fps: int) -> void:
	if not FPS_LIMITS.has(fps):
		push_error("DisplayManager: unknown FPS limit %d" % fps)
		return
	Engine.max_fps = fps
	fps_limit_changed.emit(fps)


## Применить настройки отображения из словаря
## Усі ключі є в SettingsModule.default_settings (load_data зливає їх з файлом) — без запасних значень.
## Порядок важливий: спершу режим вікна, потім його розмір.
func apply_display_settings(settings: Dictionary) -> void:
	set_display_mode(String(settings["display_mode"]))
	set_vsync(bool(settings["vsync"]))
	set_resolution(String(settings["resolution"]))
	set_fps_limit(int(settings["fps_limit"]))

