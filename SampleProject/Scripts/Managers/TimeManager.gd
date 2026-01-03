extends ManagerBase
class_name TimeManager

## ⏱️ TimeManager - Централізоване управління часом
## Відповідає за паузу, відтворення та time scale
## Дотримується принципу Single Responsibility

# Налаштування часу
var time_scale: float = 1.0
var is_paused: bool = false
var pause_stack: Array[String] = []  # Стек пауз для підтримки вкладених пауз

# Сигнали
signal game_paused(reason: String)
signal game_resumed(reason: String)
signal time_scale_changed(new_scale: float)

func _initialize():
	"""Ініціалізація TimeManager"""
	print("⏱️ TimeManager: Initialized")
	# Встановлюємо початковий time scale
	Engine.time_scale = time_scale

# ============================================
# УПРАВЛІННЯ ПАУЗОЮ
# ============================================

func pause(reason: String = "unknown"):
	"""Ставить гру на паузу"""
	if is_paused:
		# Якщо вже на паузі, додаємо до стеку
		pause_stack.append(reason)
		print("⏱️ TimeManager: Additional pause requested: ", reason, " (stack size: ", pause_stack.size(), ")")
		return
	
	is_paused = true
	pause_stack.append(reason)
	Engine.time_scale = 0.0
	get_tree().paused = true
	game_paused.emit(reason)
	print("⏱️ TimeManager: Game paused - ", reason)

func resume(_reason: String = "unknown"):
	"""Знімає гру з паузи"""
	if pause_stack.is_empty():
		print("⚠️ TimeManager: Resume called but game is not paused")
		return
	
	# Видаляємо з стеку
	var last_reason = pause_stack.pop_back()
	print("⏱️ TimeManager: Resuming from pause: ", last_reason, " (remaining: ", pause_stack.size(), ")")
	
	# Якщо стек порожній, знімаємо паузу
	if pause_stack.is_empty():
		is_paused = false
		Engine.time_scale = time_scale
		get_tree().paused = false
		game_resumed.emit(last_reason)
		print("⏱️ TimeManager: Game resumed - ", last_reason)
	else:
		print("⏱️ TimeManager: Game still paused (", pause_stack.size(), " reasons remaining)")

func force_resume():
	"""Примусово знімає гру з паузи (очищає весь стек)"""
	if not is_paused:
		return
	
	var reasons = pause_stack.duplicate()
	pause_stack.clear()
	is_paused = false
	Engine.time_scale = time_scale
	get_tree().paused = false
	game_resumed.emit("force_resume")
	print("⏱️ TimeManager: Force resumed (cleared ", reasons.size(), " pause reasons)")

func is_game_paused() -> bool:
	"""Перевіряє, чи гра на паузі"""
	return is_paused

func get_pause_reasons() -> Array[String]:
	"""Отримує список причин паузи"""
	return pause_stack.duplicate()

# ============================================
# УПРАВЛІННЯ TIME SCALE
# ============================================

func set_time_scale(scale: float):
	"""Встановлює time scale (швидкість часу)"""
	if scale < 0.0:
		push_warning("⏱️ TimeManager: Time scale cannot be negative, setting to 0.0")
		scale = 0.0
	
	time_scale = scale
	
	# Оновлюємо тільки якщо гра не на паузі
	if not is_paused:
		Engine.time_scale = time_scale
	
	time_scale_changed.emit(time_scale)
	print("⏱️ TimeManager: Time scale set to ", time_scale)

func get_time_scale() -> float:
	"""Отримує поточний time scale"""
	return time_scale

func slow_motion(factor: float = 0.5, duration: float = 1.0):
	"""Запускає slow motion ефект"""
	if factor <= 0.0 or factor >= 1.0:
		push_warning("⏱️ TimeManager: Slow motion factor should be between 0 and 1")
		return
	
	var original_scale = time_scale
	set_time_scale(time_scale * factor)
	
	# Відновлюємо через duration секунд
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		set_time_scale(original_scale)
		print("⏱️ TimeManager: Slow motion ended, restored to ", original_scale)

# ============================================
# ДОПОМІЖНІ МЕТОДИ
# ============================================

func get_delta_time() -> float:
	"""Отримує delta time з урахуванням time scale"""
	return get_process_delta_time() * time_scale

func get_unscaled_delta_time() -> float:
	"""Отримує delta time без урахування time scale"""
	return get_process_delta_time()

