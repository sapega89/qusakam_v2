extends ManagerBase
class_name SceneManager

## 🚪 SceneManager - Управление сценами и переходами
## Отвечает только за управление сценами и переходами между ними
## Согласно SRP: одна ответственность - управление сценами

# Scene and area

# Portal system
# NOTE: portal_entry_side был удалён - MetSys сам управляет направлением порталов

# Scene transition animation
var transition_overlay: ColorRect = null
var transition_canvas_layer: CanvasLayer = null  # CanvasLayer для overlay
var transition_tween: Tween = null
var _transition_blocking: bool = false

# Сигналы
signal scene_changed(scene_path: String)
signal transition_started()
signal transition_completed()

func _initialize() -> void:
	"""Инициализация SceneManager"""
	# Создаем overlay для анимации переходов
	create_transition_overlay()

# DEPRECATED: set_portal_entry_side() удалён - MetSys сам управляет направлением порталов
# Если нужно управление спавном, используйте MetSys borders и room connections

func create_transition_overlay() -> void:
	"""Создает overlay для анимации переходов"""
	if transition_overlay and transition_canvas_layer:
		# Проверяем, что overlay все еще в дереве
		if transition_canvas_layer.is_inside_tree():
			return
		else:
			# Overlay потерян после смены сцены, пересоздаем
			transition_overlay = null
			transition_canvas_layer = null

	# Создаем CanvasLayer для overlay, чтобы он был поверх всего
	transition_canvas_layer = CanvasLayer.new()
	transition_canvas_layer.name = "TransitionCanvasLayer"
	transition_canvas_layer.layer = 100  # Очень высокий слой, поверх всего

	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = Color.BLACK
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.visible = false

	# Добавляем overlay в CanvasLayer
	transition_canvas_layer.add_child(transition_overlay)

	# Добавляем CanvasLayer в корень дерева (root не меняется при смене сцены)
	var root = get_tree().root
	if root:
		# Проверяем, нет ли уже такого CanvasLayer
		var existing_layer = root.get_node_or_null("TransitionCanvasLayer")
		if existing_layer:
			print("🚪 SceneManager: Найден существующий TransitionCanvasLayer, удаляем старый")
			existing_layer.queue_free()
			# Ждем один кадр для удаления
			await get_tree().process_frame

		# Используем call_deferred для безопасного добавления
		root.call_deferred("add_child", transition_canvas_layer)

		# Ждем, чтобы CanvasLayer был добавлен
		await get_tree().process_frame

		# Устанавливаем anchors для полного покрытия экрана
		if transition_overlay and is_instance_valid(transition_overlay):
			transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			transition_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
			transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if _transition_blocking else Control.MOUSE_FILTER_IGNORE
			transition_overlay.visible = false
			transition_overlay.modulate.a = 0.0  # Начинаем прозрачным

			# Обновляем размер после добавления
			await get_tree().process_frame
			update_overlay_size()
			print("🚪 SceneManager: Transition overlay created with CanvasLayer, alpha: ", transition_overlay.modulate.a)
		else:
			print("❌ SceneManager: Не удалось создать overlay!")

func update_overlay_size() -> void:
	"""Обновляет размер overlay на весь экран, включая области за пределами сцены"""
	if transition_overlay and is_instance_valid(transition_overlay):
		var viewport = get_viewport()
		if not viewport:
			return

		# Используем call_deferred если overlay еще не готов
		if transition_overlay.is_inside_tree():
			# Устанавливаем anchors для полного покрытия экрана
			transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			transition_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
			transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if _transition_blocking else Control.MOUSE_FILTER_IGNORE
		else:
			transition_overlay.call_deferred("set_anchors_preset", Control.PRESET_FULL_RECT)
			transition_overlay.call_deferred("set_offsets_preset", Control.PRESET_FULL_RECT)
			var filter_value = Control.MOUSE_FILTER_STOP if _transition_blocking else Control.MOUSE_FILTER_IGNORE
			transition_overlay.call_deferred("set_mouse_filter", filter_value)

		var viewport_size = viewport.get_visible_rect().size
		print("🚪 SceneManager: Overlay size updated to cover full screen: ", viewport_size)

func _set_transition_blocking(blocking: bool) -> void:
	_transition_blocking = blocking
	if transition_overlay and is_instance_valid(transition_overlay):
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE

func _should_use_transition(scene_path: String) -> bool:
	if scene_path.is_empty():
		return true
	if scene_path.find("/Menus/") != -1:
		return false
	if scene_path.ends_with("MainMenu.tscn"):
		return false
	return true

func hide_ui_elements() -> void:
	"""Скрывает UI элементы перед переходом"""
	# Ищем все UI элементы в сцене (используем GameGroups для ui_canvas)
	var ui_canvas = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
	if ui_canvas and is_instance_valid(ui_canvas):
		ui_canvas.visible = false

func _cleanup_previous_scene() -> void:
	"""Очищает предыдущую сцену из памяти перед переходом"""
	print("🧹 SceneManager: Очищаем предыдущую сцену из памяти...")

	# Находим LocationManager в текущей сцене и очищаем его
	var current_scene = get_tree().current_scene
	if current_scene:
		# Очищаем все спавненные враги (используем GameGroups)
		var enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES)
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.remove_from_group(GameGroups.ENEMIES)
				enemy.remove_from_group(GameGroups.BOSS)
				enemy.remove_from_group(GameGroups.MINIBOSS)
				enemy.queue_free()
		print("🧹 SceneManager: Очищено ", enemies.size(), " врагов напрямую")

		# Очищаем торговцев (используем GameGroups)
		var merchants = GameGroups.get_nodes_in_group(GameGroups.MERCHANT)
		for merchant in merchants:
			if is_instance_valid(merchant):
				merchant.remove_from_group(GameGroups.MERCHANT)
				merchant.queue_free()
		print("🧹 SceneManager: Очищено ", merchants.size(), " торговцев")

		# Очищаем кэш всех групп после очистки сцены (для оптимизации)
		GameGroups.clear_cache()

	print("🧹 SceneManager: Очистка предыдущей сцены завершена")

func _exit_tree() -> void:
	"""Очищает ресурсы при удалении узла (предотвращение утечек памяти)"""
	_cleanup_resources()

func _cleanup_resources() -> void:
	"""Очищает все ресурсы SceneManager для предотвращения утечек памяти"""
	# Останавливаем и освобождаем tween
	if transition_tween:
		transition_tween.kill()
		transition_tween = null

	# Очищаем overlay (он будет удален вместе с CanvasLayer)
	# Но мы очищаем ссылки, чтобы избежать висячих указателей
	if transition_overlay:
		transition_overlay = null

	# CanvasLayer будет удален автоматически при смене сцены, но очищаем ссылку
	if transition_canvas_layer:
		transition_canvas_layer = null

func get_current_scene_name() -> String:
	"""Получает имя текущей сцены"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.scene_file_path.get_file().get_basename()
	return "Unknown"
