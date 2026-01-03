extends Node

## 🖥️ DisplayManager - Управление настройками отображения
## Отвечает за fullscreen, vsync и другие настройки дисплея
## Используется SaveSystem и BaseOptionsComponent

signal fullscreen_changed(enabled: bool)
signal vsync_changed(enabled: bool)

## Установить полноэкранный режим
func set_fullscreen(enabled: bool):
	"""Устанавливает полноэкранный режим"""
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	fullscreen_changed.emit(enabled)
	print("🖥️ DisplayManager: Fullscreen ", "enabled" if enabled else "disabled")

## Получить текущий режим полноэкранного окна
func is_fullscreen() -> bool:
	"""Возвращает true, если включен полноэкранный режим"""
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

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

## Применить настройки отображения из словаря
func apply_display_settings(settings: Dictionary):
	"""Применяет настройки отображения из словаря"""
	if settings.has("fullscreen"):
		set_fullscreen(settings.fullscreen)
	if settings.has("vsync"):
		set_vsync(settings.vsync)

