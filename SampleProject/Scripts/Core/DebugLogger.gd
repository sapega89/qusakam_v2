class_name DebugLogger

## 🐛 DebugLogger - Система логирования с уровнями и throttling
## Предотвращает спам в консоли из _physics_process и других высокочастотных функций

## Уровни логирования
enum LogLevel {
	NONE = 0,      # Логи отключены
	ERROR = 1,     # Только ошибки
	WARNING = 2,   # Ошибки + предупреждения
	INFO = 3,      # Ошибки + предупреждения + информация
	VERBOSE = 4    # Все логи (включая physics)
}

## Текущий уровень логирования (по умолчанию WARNING)
static var current_level: LogLevel = LogLevel.WARNING

## Флаг для включения/выключения логов в _physics_process
static var enable_physics_logs: bool = false

## Throttling для physics логов (сколько секунд между сообщениями)
static var physics_log_interval: float = 1.0

## Последнее время логирования для каждого ключа
static var _last_log_times: Dictionary = {}

## Счетчики пропущенных логов (для отчетов)
static var _skipped_logs: Dictionary = {}

## ============================================================================
## ERROR LOGS
## ============================================================================

static func error(message: String, context: String = "") -> void:
	"""Логирует ошибку (всегда, если level >= ERROR)"""
	if current_level >= LogLevel.ERROR:
		var prefix = "[ERROR]" if context.is_empty() else "[ERROR:%s]" % context
		push_error("%s %s" % [prefix, message])

## ============================================================================
## WARNING LOGS
## ============================================================================

static func warning(message: String, context: String = "") -> void:
	"""Логирует предупреждение (если level >= WARNING)"""
	if current_level >= LogLevel.WARNING:
		var prefix = "[WARNING]" if context.is_empty() else "[WARNING:%s]" % context
		push_warning("%s %s" % [prefix, message])

## ============================================================================
## INFO LOGS
## ============================================================================

static func info(message: String, context: String = "") -> void:
	"""Логирует информацию (если level >= INFO)"""
	if current_level >= LogLevel.INFO:
		var prefix = "[INFO]" if context.is_empty() else "[INFO:%s]" % context
		print("%s %s" % [prefix, message])

## ============================================================================
## VERBOSE LOGS
## ============================================================================

static func verbose(message: String, context: String = "") -> void:
	"""Логирует подробности (если level >= VERBOSE)"""
	if current_level >= LogLevel.VERBOSE:
		var prefix = "[VERBOSE]" if context.is_empty() else "[VERBOSE:%s]" % context
		print("%s %s" % [prefix, message])

## ============================================================================
## PHYSICS LOGS (с throttling для предотвращения спама)
## ============================================================================

static func physics_verbose(message: String, key: String = "default") -> void:
	"""Логирует из _physics_process с throttling (макс. 1 раз в N секунд)

	Args:
		message: Сообщение для логирования
		key: Уникальный ключ для throttling (разные ключи логируются независимо)

	Example:
		func _physics_process(delta):
			DebugLogger.physics_verbose("Player position: %s" % position, "player_pos")
	"""
	if not enable_physics_logs:
		return

	if current_level < LogLevel.VERBOSE:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_log_times.get(key, 0.0)

	if (current_time - last_time) >= physics_log_interval:
		_last_log_times[key] = current_time

		# Показываем количество пропущенных логов
		var skipped = _skipped_logs.get(key, 0)
		if skipped > 0:
			print("[PHYSICS:%s] %s (skipped %d logs)" % [key, message, skipped])
			_skipped_logs[key] = 0
		else:
			print("[PHYSICS:%s] %s" % [key, message])
	else:
		# Увеличиваем счетчик пропущенных логов
		_skipped_logs[key] = _skipped_logs.get(key, 0) + 1

static func physics_warning(message: String, key: String = "default") -> void:
	"""Логирует предупреждение из _physics_process с throttling"""
	if not enable_physics_logs:
		return

	if current_level < LogLevel.WARNING:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_log_times.get(key, 0.0)

	if (current_time - last_time) >= physics_log_interval:
		_last_log_times[key] = current_time
		push_warning("[PHYSICS:%s] %s" % [key, message])

static func physics_error(message: String, key: String = "default") -> void:
	"""Логирует ошибку из _physics_process с throttling"""
	if not enable_physics_logs:
		return

	if current_level < LogLevel.ERROR:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_log_times.get(key, 0.0)

	if (current_time - last_time) >= physics_log_interval:
		_last_log_times[key] = current_time
		push_error("[PHYSICS:%s] %s" % [key, message])

## ============================================================================
## UTILITY METHODS
## ============================================================================

static func set_level(level: LogLevel) -> void:
	"""Устанавливает уровень логирования"""
	current_level = level
	info("DebugLogger level set to: %s" % LogLevel.keys()[level], "DebugLogger")

static func enable_physics_logging(enable: bool = true) -> void:
	"""Включает/выключает логи из _physics_process"""
	enable_physics_logs = enable
	info("Physics logging %s" % ("enabled" if enable else "disabled"), "DebugLogger")

static func set_physics_interval(interval: float) -> void:
	"""Устанавливает интервал между physics логами (в секундах)"""
	physics_log_interval = max(0.1, interval)
	info("Physics log interval set to: %.2fs" % physics_log_interval, "DebugLogger")

static func clear_throttle_cache() -> void:
	"""Очищает кэш throttling (полезно при смене сцен)"""
	_last_log_times.clear()
	_skipped_logs.clear()
	verbose("Throttle cache cleared", "DebugLogger")
