extends Node
class_name CombatSystem

# Боевая система для управления боем между игроком и врагами

signal combat_started
signal combat_ended
signal player_died
signal enemy_died
signal entity_died(entity: Node)  # Добавляем сигнал, который ожидает combat_test_scene

var is_combat_active: bool = false
var player: Node
var enemies: Array = []
var combatants: Array = []  # Массив всех бойцов

func _ready():
	# Подключаемся к сигналам EventBus для автоматической регистрации
	if Engine.has_singleton("EventBus"):
		# Подписываемся на события спавна врагов (вместо постоянного поиска)
		if not EventBus.enemy_spawned.is_connected(_on_enemy_spawned):
			EventBus.enemy_spawned.connect(_on_enemy_spawned)
		if not EventBus.enemy_died.is_connected(_on_enemy_died_from_event):
			EventBus.enemy_died.connect(_on_enemy_died_from_event)
		if not EventBus.player_died.is_connected(_on_player_died):
			EventBus.player_died.connect(_on_player_died)
	
	# Подключаемся к существующим бойцам (один раз при инициализации)
	connect_to_combatants()

func connect_to_combatants():
	"""Подключается к существующим бойцам (вызывается один раз при инициализации)"""
	# Находим игрока (используем кэшированный метод)
	player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	if player:
		if player.has_signal("died"):
			if not player.died.is_connected(_on_player_died):
				player.died.connect(_on_player_died)
		elif player.has_signal("entity_died"):
			if not player.entity_died.is_connected(_on_player_died):
				player.entity_died.connect(_on_player_died)
	
	# Находим всех врагов (используем кэшированный метод)
	enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES)
	for enemy in enemies:
		_register_enemy(enemy)

func _register_enemy(enemy: Node) -> void:
	"""Регистрирует врага в системе боя"""
	if not enemies.has(enemy):
		enemies.append(enemy)
		if enemy.has_signal("died"):
			if not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)
		elif enemy.has_signal("entity_died"):
			if not enemy.entity_died.is_connected(_on_enemy_died):
				enemy.entity_died.connect(_on_enemy_died)

func _on_enemy_spawned(enemy_id: String, position: Vector2) -> void:
	"""Обработчик сигнала спавна врага из EventBus (вместо постоянного поиска)"""
	# Инвалидируем кэш врагов
	GameGroups.invalidate_cache(GameGroups.ENEMIES)
	
	# Находим нового врага (используем кэшированный метод с принудительным обновлением)
	var new_enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES, true)
	for enemy in new_enemies:
		if not enemies.has(enemy):
			_register_enemy(enemy)
			break

func _on_enemy_died_from_event(enemy_id: String, position: Vector2) -> void:
	"""Обработчик сигнала смерти врага из EventBus"""
	# Инвалидируем кэш врагов
	GameGroups.invalidate_cache(GameGroups.ENEMIES)
	
	# Находим и удаляем врага из списка
	var updated_enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES, true)
	enemies = updated_enemies
	
	# Проверяем, остались ли живые враги
	var alive_enemies = enemies.filter(func(e): return not e.is_dead if e.has("is_dead") else true)
	if alive_enemies.is_empty():
		end_combat()

func register_combatant(combatant: Node):
	"""Регистрирует бойца в системе"""
	if not combatants.has(combatant):
		combatants.append(combatant)
		print("Registered combatant: ", combatant.name)

func start_combat():
	if not is_combat_active:
		is_combat_active = true
		combat_started.emit()
		print("Combat started!")

func end_combat():
	if is_combat_active:
		is_combat_active = false
		combat_ended.emit()
		print("Combat ended!")

func _on_player_died():
	player_died.emit()
	entity_died.emit(player)  # Эмитим общий сигнал
	print("Player died!")
	end_combat()

func _on_enemy_died(enemy):
	enemy_died.emit()
	entity_died.emit(enemy)  # Эмитим общий сигнал
	print("Enemy died: ", enemy.name)
	
	# Проверяем, остались ли живые враги
	var alive_enemies = enemies.filter(func(e): return not e.is_dead)
	if alive_enemies.is_empty():
		end_combat()

func add_enemy(enemy):
	"""Добавляет врага в систему боя (использует _register_enemy для единообразия)"""
	_register_enemy(enemy)

func remove_enemy(enemy):
	"""Удаляет врага из системы боя и отписывается от его сигналов"""
	if enemies.has(enemy):
		# Отписываемся от сигналов врага перед удалением
		if enemy.has_signal("died") and enemy.died.is_connected(_on_enemy_died):
			enemy.died.disconnect(_on_enemy_died)
		elif enemy.has_signal("entity_died") and enemy.entity_died.is_connected(_on_enemy_died):
			enemy.entity_died.disconnect(_on_enemy_died)
		enemies.erase(enemy)

func _exit_tree() -> void:
	"""Отписывается от всех сигналов при удалении узла (предотвращение утечек памяти)"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Отписывается от всех сигналов для предотвращения утечек памяти"""
	# Отписываемся от сигналов EventBus
	if Engine.has_singleton("EventBus"):
		if EventBus.enemy_spawned.is_connected(_on_enemy_spawned):
			EventBus.enemy_spawned.disconnect(_on_enemy_spawned)
		if EventBus.enemy_died.is_connected(_on_enemy_died_from_event):
			EventBus.enemy_died.disconnect(_on_enemy_died_from_event)
		if EventBus.player_died.is_connected(_on_player_died):
			EventBus.player_died.disconnect(_on_player_died)
	
	# Отписываемся от сигналов игрока
	if player and is_instance_valid(player):
		if player.has_signal("died") and player.died.is_connected(_on_player_died):
			player.died.disconnect(_on_player_died)
		elif player.has_signal("entity_died") and player.entity_died.is_connected(_on_player_died):
			player.entity_died.disconnect(_on_player_died)
	
	# Отписываемся от сигналов всех врагов
	for enemy in enemies:
		if is_instance_valid(enemy):
			if enemy.has_signal("died") and enemy.died.is_connected(_on_enemy_died):
				enemy.died.disconnect(_on_enemy_died)
			elif enemy.has_signal("entity_died") and enemy.entity_died.is_connected(_on_enemy_died):
				enemy.entity_died.disconnect(_on_enemy_died)
	
	# Очищаем ссылки
	player = null
	enemies.clear()
	combatants.clear()

