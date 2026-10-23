extends Node

## 🖥️ DisplayManager - Управление настройками отображения
## Отвечает за fullscreen, vsync и другие настройки дисплея
## Используется SaveSystem и BaseOptionsComponent

signal display_mode_changed(mode: String)
signal vsync_changed(enabled: bool)
signal resolution_changed(size: Vector2i)
signal fps_limit_changed(fps: int)
signal brightness_changed(value: int)

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

## D428: Screen Brightness 0–100; 50 — без змін. Крайні значення — гамма 0.5 (темніше) і 2.0 (світліше).
const BRIGHTNESS_DEFAULT := 50
const BRIGHTNESS_MAX := 100

const GraphicsQuality := preload("res://SampleProject/Scripts/Systems/GraphicsQuality.gd")

## D554: High / Low — вузол GraphicsQuality цієї сцени.
@onready var graphics_quality: GraphicsQuality = $GraphicsQuality

## Шар BrightnessLayer (127) — над HUD, меню, модалками й переходами (≤ 100), під курсором миші (128).
@onready var _brightness: ColorRect = %Brightness

## Останні застосовані значення. Headless-драйвер ігнорує режим і розмір вікна — тест читає ці поля.
var display_mode: String = "windowed"
var resolution: Vector2i = Vector2i.ZERO
var brightness: int = BRIGHTNESS_DEFAULT

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


## D418 / D429: лише ті розміри, що вміщуються в екран, на якому вікно. Headless-драйвер екрана не має
## (screen_get_size = 0×0) — тоді обрізати нема за чим, список повний.
func available_resolutions() -> Array[String]:
	var screen: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	if screen == Vector2i.ZERO:
		return RESOLUTIONS.duplicate()
	return resolutions_for_screen(screen)


## Розміри зі списку RESOLUTIONS, що вміщуються в екран [param screen]; найменший — завжди.
static func resolutions_for_screen(screen: Vector2i) -> Array[String]:
	var fits: Array[String] = []
	for value in RESOLUTIONS:
		var size: Vector2i = parse_resolution(value)
		if (size.x <= screen.x and size.y <= screen.y) or value == RESOLUTIONS[0]:
			fits.append(value)
	return fits


## D429: збережений розмір, що більший за цей екран (гру перенесли на менший монітор), — найбільший, що влазить.
## Збережене значення не переписується: на більшому екрані вікно знову стане таким, як обрав гравець.
func fitted_resolution(value: String) -> String:
	var fits: Array[String] = available_resolutions()
	return value if fits.has(value) else fits.back()


## Розмір вікна у режимі Windowed. Повноекранний режим завжди йде в рідній роздільності екрана
## (stretch canvas_items масштабує 1920×1080 вʼюпорт), тож там значення лише зберігається
## і стає розміром вікна, щойно гравець повернеться у Windowed.
func set_resolution(value: String) -> void:
	if parse_resolution(value) == Vector2i.ZERO:
		return
	resolution = parse_resolution(fitted_resolution(value))
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


## D428: один механізм в одному місці — гамма-шейдер на шарі BrightnessLayer цього автолоада, поверх світу й UI.
## На 50 шар вимкнений: типова яскравість нічого не коштує.
func set_brightness(value: int) -> void:
	brightness = clampi(value, 0, BRIGHTNESS_MAX)
	var gamma: float = pow(2.0, float(brightness - BRIGHTNESS_DEFAULT) / BRIGHTNESS_DEFAULT)
	(_brightness.material as ShaderMaterial).set_shader_parameter(&"gamma", gamma)
	_brightness.visible = brightness != BRIGHTNESS_DEFAULT
	brightness_changed.emit(brightness)


## Применить настройки отображения из словаря
## Усі ключі є в SettingsModule.default_settings (load_data зливає їх з файлом) — без запасних значень.
## Порядок важливий: спершу режим вікна, потім його розмір.
func apply_display_settings(settings: Dictionary) -> void:
	set_display_mode(String(settings["display_mode"]))
	set_vsync(bool(settings["vsync"]))
	set_resolution(String(settings["resolution"]))
	set_fps_limit(int(settings["fps_limit"]))
	set_brightness(int(settings["brightness"]))
	graphics_quality.apply(String(settings["graphics_quality"]))

