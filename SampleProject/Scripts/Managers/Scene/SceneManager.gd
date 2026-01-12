extends ManagerBase
class_name SceneManager

## 🚪 SceneManager - Управление сценами и переходами
## Отвечает только за управление сценами и переходами между ними
## Согласно SRP: одна ответственность - управление сценами

# Scene and area
var current_area: int = 1
var area_path: String = ""  # Legacy path - no longer used (moved to legacy/)

# Portal system
# NOTE: portal_entry_side был удалён - MetSys сам управляет направлением порталов
var previous_scene_name: String = ""
var is_new_game_session: bool = false
var returning_from_menu: bool = false

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

func transition_to_scene(scene_path: String, duration: float = 0.2) -> void:
	"""Плавный переход к сцене с анимацией"""
	transition_started.emit()
	
	# Емітуємо подію через EventBus
	if Engine.has_singleton("EventBus"):
		var current_scene_name = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		EventBus.scene_transition_started.emit(current_scene_name, scene_path)
	
	var use_transition = _should_use_transition(scene_path)
	if not use_transition:
		_set_transition_blocking(false)
		_cleanup_previous_scene()
		GameGroups.clear_cache()
		print("🚪 SceneManager: Переход к сцене без затемнения: ", scene_path)
		get_tree().call_deferred("change_scene_to_file", scene_path)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		if Engine.has_singleton("EventBus"):
			EventBus.scene_loaded.emit(scene_path)
			EventBus.scene_transition_completed.emit(scene_path)
		transition_completed.emit()
		scene_changed.emit(scene_path)
		return
	
	# Принудительно скрываем UI элементы перед переходом
	hide_ui_elements()
	
	# Проверяем, существует ли overlay
	if not transition_overlay or not transition_canvas_layer:
		await create_transition_overlay()
	
	# Убеждаемся, что overlay начинается с прозрачного состояния и покрывает весь экран
	if transition_overlay:
		transition_overlay.modulate.a = 0.0
		_set_transition_blocking(true)
		transition_overlay.visible = true
		# Обновляем размер перед анимацией
		update_overlay_size()
		# Ждем один кадр, чтобы размер применился
		await get_tree().process_frame
	
	# Создаем tween для анимации
	if transition_tween:
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# Анимация затемнения (уменьшена длительность для более быстрого перехода)
	transition_tween.tween_property(transition_overlay, "modulate:a", 1.0, duration)
	
	# Ждем завершения анимации затемнения
	await transition_tween.finished
	
	# Убеждаемся, что overlay полностью темный перед сменой сцены
	if transition_overlay:
		transition_overlay.modulate.a = 1.0
		print("🚪 SceneManager: Transition overlay fade-out completed, overlay is opaque")
	
	# Очищаем предыдущую сцену из памяти перед переходом
	_cleanup_previous_scene()
	
	# Очищаем кэш групп перед сменой сцены (для оптимизации)
	GameGroups.clear_cache()
	
	# Меняем сцену
	print("🚪 SceneManager: Меняем сцену на: ", scene_path)
	get_tree().call_deferred("change_scene_to_file", scene_path)
	
	# Ждем несколько кадров для полной загрузки новой сцены
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # Дополнительный кадр для надежности
	
	# Емітуємо подію через EventBus
	if Engine.has_singleton("EventBus"):
		EventBus.scene_loaded.emit(scene_path)
		EventBus.scene_transition_completed.emit(scene_path)
	
	print("🚪 SceneManager: Новая сцена загружена, проверяем overlay")
	
	# Проверяем, существует ли overlay после смены сцены
	var root = get_tree().root
	if root:
		var existing_layer = root.get_node_or_null("TransitionCanvasLayer")
		if existing_layer:
			transition_canvas_layer = existing_layer
			var overlay = existing_layer.get_node_or_null("TransitionOverlay")
			if overlay:
				transition_overlay = overlay
				print("🚪 SceneManager: Найден существующий overlay после смены сцены")
			else:
				print("⚠️ SceneManager: CanvasLayer найден, но overlay отсутствует, пересоздаем")
				await create_transition_overlay()
		else:
			print("⚠️ SceneManager: CanvasLayer не найден после смены сцены, пересоздаем")
			await create_transition_overlay()
	
	# Убеждаемся, что overlay существует и видим
	if not transition_overlay or not is_instance_valid(transition_overlay):
		print("❌ SceneManager: Overlay не найден после всех попыток!")
		await create_transition_overlay()
	
	# Обновляем размер overlay для новой сцены (важно после смены сцены)
	update_overlay_size()
	# Ждем один кадр, чтобы размер применился
	await get_tree().process_frame
	
	# Убеждаемся, что overlay непрозрачен перед fade-in
	if transition_overlay:
		transition_overlay.modulate.a = 1.0
		print("🚪 SceneManager: Overlay установлен как непрозрачный перед fade-in, alpha: ", transition_overlay.modulate.a)
	
	# Проверяем, видим ли overlay перед анимацией осветления
	if transition_overlay and is_instance_valid(transition_overlay):
		# Создаем новый tween для анимации осветления
		if transition_tween:
			transition_tween.kill()
		transition_tween = create_tween()
		
		print("🚪 SceneManager: Запускаем fade-in анимацию, текущий alpha: ", transition_overlay.modulate.a)
		
		# Анимация осветления (уменьшена длительность)
		transition_tween.tween_property(transition_overlay, "modulate:a", 0.0, duration)
		await transition_tween.finished
		
		# Убеждаемся, что overlay полностью прозрачный
		if transition_overlay and is_instance_valid(transition_overlay):
			transition_overlay.modulate.a = 0.0
			_set_transition_blocking(false)
			transition_overlay.visible = false
			print("🚪 SceneManager: Transition overlay fade-in completed, overlay is transparent, alpha: ", transition_overlay.modulate.a)
		else:
			print("⚠️ SceneManager: Overlay стал невалидным во время fade-in")
	else:
		print("❌ SceneManager: Overlay не найден для fade-in анимации!")
	
	transition_completed.emit()
	scene_changed.emit(scene_path)

func next_level() -> void:
	"""Переход на следующий уровень"""
	current_area += 1
	# Всегда используем одну базовую сцену, номер области хранится в current_area
	print("🔄 SceneManager: Переход на область #", current_area)
	await transition_to_scene(area_path, 0.5)

func previous_level() -> void:
	"""Переход на предыдущий уровень"""
	current_area -= 1
	if current_area < 1:
		current_area = 1  # Не возвращаемся назад, остаемся на первой области
	
	print("🔄 SceneManager: Переход на область #", current_area)
	await transition_to_scene(area_path, 0.5)

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
		var location_manager = current_scene.get_node_or_null("LocationManager")
		if location_manager and location_manager.has_method("cleanup"):
			location_manager.cleanup()
			print("🧹 SceneManager: LocationManager очищен")
		
		# Также ищем LocationManager через группу или ServiceLocator (используем GameGroups)
		var location_managers = GameGroups.get_nodes_in_group(GameGroups.LOCATION_MANAGER)
		for lm in location_managers:
			if is_instance_valid(lm) and lm.has_method("cleanup"):
				lm.cleanup()
		
		# Очищаем все спавненные враги напрямую (на случай, если LocationManager не найден) (используем GameGroups)
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

func get_completed_village_areas() -> int:
	"""Возвращает количество завершенных деревенских областей"""
	# Если current_area = 1, значит игрок еще не завершил ни одной области
	# Если current_area = 2, значит завершена 1 область, и т.д.
	return max(0, current_area - 1)

func get_total_completed_scenes() -> Dictionary:
	"""Возвращает информацию о завершенных сценах"""
	var result = {
		"completed_village_areas": get_completed_village_areas(),
		"current_village_area": current_area,
		"completed_prolog_scenes": 0
	}
	
	# Проверяем пройденные диалоги для определения завершенных пролог-сцен
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		var save_system = service_locator.get_save_system() if service_locator and service_locator.has_method("get_save_system") else null
		if save_system and save_system.has("player_data") and save_system.player_data.has("completed_dialogues"):
			var completed_dialogues = save_system.player_data.completed_dialogues
			
			# Ключевые диалоги, которые означают завершение каждой пролог-сцены:
			# P01 - prolog1 (начало)
			# P02 или P03 - prolog2 (налёт)
			# P05 - prolog3 (возврат)
			# P06 - prolog4 (бой с бандитом)
			# P07 - prolog5 (дед)
			
			var prolog_completed = {
				"prolog1": false,
				"prolog2": false,
				"prolog3": false,
				"prolog4": false,
				"prolog5": false
			}
			
			# Проверяем каждый диалог
			for dialogue_id in completed_dialogues:
				var dialogue_path = dialogue_id
				if dialogue_path is String:
					# P01 - prolog1
					if "p01_cliff_intro" in dialogue_path:
						prolog_completed["prolog1"] = true
					# P02 или P03 - prolog2
					elif "p02_raid_scene" in dialogue_path or "p03_raid_continuation" in dialogue_path:
						prolog_completed["prolog2"] = true
					# P05 - prolog3
					elif "p05_return_path" in dialogue_path:
						prolog_completed["prolog3"] = true
					# P06 - prolog4
					elif "p06_village_bandit_fight" in dialogue_path or "p06_bandit_defeated" in dialogue_path:
						prolog_completed["prolog4"] = true
					# P07 - prolog5
					elif "p07_grandfather_healing" in dialogue_path:
						prolog_completed["prolog5"] = true
			
			# Подсчитываем завершенные пролог-сцены
			var completed_count = 0
			for scene_name in prolog_completed:
				if prolog_completed[scene_name]:
					completed_count += 1
			
			result.completed_prolog_scenes = completed_count
	
	result.total_completed = result.completed_village_areas + result.completed_prolog_scenes
	return result

func print_scene_progress() -> void:
	"""Выводит информацию о прогрессе по сценам в консоль"""
	var progress = get_total_completed_scenes()
	print("📊 SceneManager: Прогресс по сценам:")
	print("   - Завершено деревенских областей: ", progress.completed_village_areas)
	print("   - Текущая деревенская область: ", progress.current_village_area)
	print("   - Завершено пролог-сцен: ", progress.completed_prolog_scenes)
	print("   - Всего завершено сцен: ", progress.total_completed)

func position_player_from_portal(player: Node2D, is_new_game: bool, player_state = null) -> void:
	"""Позиционирует игрока и камеру в соответствии со стороной портала или для новой игры
	
	Args:
		player: Узел игрока для позиционирования
		is_new_game: Если true, позиционирует для новой игры
		player_state: Resource класс с состоянием игрока (PlayerStateResource) или Dictionary (опционально)
	"""
	if not player:
		return
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		player.global_position.x = 100
		player.global_position.y = 549
		return
	
	# Проверяем, является ли текущая сцена прологом
	var current_scene_name = get_current_scene_name()
	var is_prolog_scene = current_scene_name.begins_with("prolog") or current_scene_name.contains("prolog")
	
	# Если это пролог-сцена, используем позицию из player_state (позиция установлена в сцене)
	var player_position = Vector2.ZERO
	if player_state:
		if player_state is Dictionary:
			var pos_dict = player_state.get("player_position", {})
			if pos_dict is Dictionary:
				player_position = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
			elif pos_dict is Vector2:
				player_position = pos_dict
		elif player_state.has("player_position"):
			player_position = player_state.player_position
	
	if is_prolog_scene and player_position != Vector2.ZERO:
		player.global_position = player_position
		camera.global_position = player_position
		print("🚪 SceneManager: Пролог-сцена обнаружена, используем позицию из сцены: ", player_position)
		return
	
	# Используем значения из GameSettings для согласованности
	var left_spawn_x = GameSettings.LEFT_SPAWN_X
	var _right_spawn_x = 1100  # Не используется - MetSys управляет порталами
	var new_game_spawn_x = 300  # Можно вынести в GameSettings если нужно
	
	if is_new_game or is_new_game_session:
		player.global_position.x = new_game_spawn_x
		camera.global_position.x = new_game_spawn_x
	elif returning_from_menu:
		if player_position != Vector2.ZERO:
			player.global_position.x = player_position.x
			camera.global_position.x = player_position.x
		else:
			player.global_position.x = left_spawn_x
			camera.global_position.x = left_spawn_x
		returning_from_menu = false
	elif is_new_game == false and previous_scene_name == "":
		if player_position != Vector2.ZERO and player_position.x != 100:
			player.global_position.x = player_position.x
			camera.global_position.x = player_position.x
		else:
			player.global_position.x = left_spawn_x
			camera.global_position.x = left_spawn_x
	else:
		# TODO: Эта логика должна быть заменена на MetSys room borders/connections
		# MetSys автоматически позиционирует игрока при переходах между комнатами
		# Сейчас используем дефолтную позицию слева
		player.global_position.x = left_spawn_x
		camera.global_position.x = left_spawn_x
		print("🚪 SceneManager: Используем дефолтную позицию (x=", left_spawn_x, ", y=549)")
	
	player.global_position.y = 549
	camera.global_position.y = 549
	
	# Финальная проверка позиции
	print("🚪 SceneManager: Финальная позиция игрока: ", player.global_position, ", камеры: ", camera.global_position)
