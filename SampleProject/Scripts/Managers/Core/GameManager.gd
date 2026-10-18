extends ManagerBase

## 🎮 GameManager - Главный менеджер игры (Autoload Singleton)
## Создает и управляет всеми менеджерами как дочерними узлами
## АДАПТИРОВАНО: Исключена система уровней/опыта (используется система из текущего проекта)

# Preload managers
const CharacterManagerScript = preload("res://SampleProject/Scripts/Managers/Gameplay/CharacterManager.gd")
const EquipmentManagerScript = preload("res://SampleProject/Scripts/Managers/Gameplay/EquipmentManager.gd")
const SkillManagerScript = preload("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd")
const SceneManagerScript = preload("res://SampleProject/Scripts/Managers/Scene/SceneManager.gd")
const MenuManagerScript = preload("res://SampleProject/Scripts/Managers/UI/MenuManager.gd")
const UIManagerScript = preload("res://SampleProject/Scripts/Managers/UI/UIManager.gd")
const TimeManagerScript = preload("res://SampleProject/Scripts/Managers/TimeManager.gd")
const PlayerStateManagerScript = preload("res://SampleProject/Scripts/Managers/Gameplay/PlayerStateManager.gd")
const LootSystemScript = preload("res://SampleProject/Scripts/Systems/LootSystem.gd")
const DialogueManagerScript = preload("res://SampleProject/Scripts/Systems/DialogueManager.gd")
const InventoryManagerScript = preload("res://SampleProject/Scripts/Systems/InventoryManager.gd")
const VFXHooksScript = preload("res://SampleProject/Scripts/Systems/VFXHooks.gd")
const XPManagerScript = preload("res://SampleProject/Scripts/Managers/XPManager.gd")
const TutorialManagerScript = preload("res://SampleProject/Scripts/Managers/TutorialManager.gd")
const GameFlowScript = preload("res://SampleProject/Scripts/Managers/Story/GameFlow.gd")
const CompanionManagerScript = preload("res://SampleProject/Scripts/Managers/Gameplay/CompanionManager.gd")

# Signals
signal managers_ready

# InventoryManager (создается в _initialize_inventory_manager)
var inventory_manager: InventoryManager = null

func _initialize() -> void:
	"""Инициализация GameManager"""
	_initialize_inventory_manager()
	_create_managers()
	print("🎮 GameManager: Initialized")

func _initialize_inventory_manager() -> void:
	"""Инициализирует InventoryManager"""
	inventory_manager = InventoryManagerScript.new()
	inventory_manager.name = "InventoryManager"
	add_child(inventory_manager)
	print("📦 GameManager: InventoryManager created")

func _create_managers() -> void:
	"""Создает менеджеры для разделения ответственностей"""
	# LootSystem
	var loot_system = LootSystemScript.new()
	if loot_system is Node:
		loot_system.name = "LootSystem"
		add_child(loot_system)
		print("💰 GameManager: LootSystem created")
	else:
		push_error("❌ GameManager: LootSystemScript must extend Node, not RefCounted!")

	# CharacterManager
	var character_manager = CharacterManagerScript.new()
	character_manager.name = "CharacterManager"
	add_child(character_manager)
	# Инициализируем персонажей после создания менеджера
	character_manager.initialize_characters()
	print("👤 GameManager: CharacterManager created")

	# SkillManager
	var skill_manager = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	add_child(skill_manager)
	print("🎓 GameManager: SkillManager created")

	# EquipmentManager
	var equipment_manager = EquipmentManagerScript.new()
	equipment_manager.name = "EquipmentManager"
	add_child(equipment_manager)
	print("⚔️ GameManager: EquipmentManager created")

	# SceneManager
	var scene_manager = SceneManagerScript.new()
	scene_manager.name = "SceneManager"
	add_child(scene_manager)
	print("🌍 GameManager: SceneManager created")

	# MenuManager
	var menu_manager = MenuManagerScript.new()
	menu_manager.name = "MenuManager"
	add_child(menu_manager)
	print("📋 GameManager: MenuManager created")


	# DialogueManager
	var dialogue_manager = DialogueManagerScript.new()
	dialogue_manager.name = "DialogueManager"
	add_child(dialogue_manager)
	print("💬 GameManager: DialogueManager created")

	# UIManager
	var ui_manager = UIManagerScript.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	print("🖥️ GameManager: UIManager created")

	# TimeManager
	var time_manager = TimeManagerScript.new()
	time_manager.name = "TimeManager"
	add_child(time_manager)
	print("⏰ GameManager: TimeManager created")

	# PlayerStateManager
	var player_state_manager = PlayerStateManagerScript.new()
	player_state_manager.name = "PlayerStateManager"
	add_child(player_state_manager)
	print("👤 GameManager: PlayerStateManager created")


	# XPManager
	var xp_manager = XPManagerScript.new()
	xp_manager.name = "XPManager"
	add_child(xp_manager)
	print("⭐ GameManager: XPManager created")

	# TutorialManager
	var tutorial_manager = TutorialManagerScript.new()
	tutorial_manager.name = "TutorialManager"
	add_child(tutorial_manager)
	print("📚 GameManager: TutorialManager created")

	# GameFlow
	var game_flow = GameFlowScript.new()
	game_flow.name = "GameFlow"
	add_child(game_flow)
	print("🎭 GameManager: GameFlow created")

	# CompanionManager
	var companion_manager = CompanionManagerScript.new()
	companion_manager.name = "CompanionManager"
	add_child(companion_manager)
	print("🤝 GameManager: CompanionManager created")

	# VFXHooks
	print("🔧 GameManager: Creating VFXHooks...")
	var vfx_hooks = VFXHooksScript.new()
	vfx_hooks.name = "VFXHooks"
	add_child(vfx_hooks)
	print("✨ GameManager: VFXHooks created and added as child")
	print("🔧 GameManager: VFXHooks enabled = ", vfx_hooks.enabled)

	# Регистрируем менеджеры в ServiceLocator сразу после создания
	# ServiceLocator - это autoload экземпляр, используем call_deferred для безопасности

	# Оповещаем о готовности менеджеров
	managers_ready.emit()

var player_state: Dictionary:
	get:
		return get_node(^"PlayerStateManager").player_state

var characters: Dictionary:
	get:
		return get_node(^"CharacterManager").get_all_characters()

var active_character_id: String:
	get:
		return get_node(^"CharacterManager").get_active_character_id()

var active_character:
	get:
		return get_node(^"CharacterManager").get_active_character()

func get_active_character():
	"""Активный персонаж (делегат к CharacterManager)."""
	return get_node(^"CharacterManager").get_active_character()


func get_all_characters() -> Dictionary:
	"""Все персонажи (делегат к CharacterManager)."""
	return get_node(^"CharacterManager").get_all_characters()

# ── Производные статы активного персонажа ──────────────────────────────────
# Формулы НЕ дублируются: всё считает StatCalculator. Здесь только тонкие
# обёртки "для активного персонажа", потому что UI вызывает их без аргументов.

func _active_attributes() -> CharacterAttributes:
	var character = get_active_character()
	return character.attributes if character else null


func _active_equipment_stats() -> Dictionary:
	var character = get_active_character()
	return character.get_equipment_stats() if character else {}


## Max HP — і в меню, і в грі (D205): витривалість, броня, бонус рівня, пасивки (Toughness).
func calculate_max_health() -> int:
	var attributes := _active_attributes()
	if not attributes:
		return 0
	return StatCalculator.calculate_max_health(attributes, _active_equipment_stats()) + level_and_passive_health()


## Частина Max HP, що не залежить від речей: бонус рівня й пасивки. Equipment рахує «без речей» з нею ж.
func level_and_passive_health() -> int:
	return ServiceLocator.get_xp_manager().get_hp_bonus() + roundi(ServiceLocator.get_skill_manager().passive_value("max_health"))


## Phys. Atk. — і в меню, і в ударі гравця (D199): сила, атака спорядження й бонус рівня.
func calculate_physical_damage() -> int:
	var attributes := _active_attributes()
	if not attributes:
		return 0
	return StatCalculator.calculate_physical_damage(attributes, _active_equipment_stats()) + ServiceLocator.get_xp_manager().get_damage_bonus()


func calculate_magic_damage() -> int:
	var attributes := _active_attributes()
	return StatCalculator.calculate_magic_damage(attributes, _active_equipment_stats()) if attributes else 0


func calculate_physical_defense() -> int:
	return StatCalculator.calculate_physical_defense(_active_equipment_stats())


func calculate_magic_defense() -> int:
	return StatCalculator.calculate_magic_defense(_active_equipment_stats())


func calculate_attack_speed() -> float:
	var attributes := _active_attributes()
	return StatCalculator.calculate_attack_speed(attributes) if attributes else 1.0


func calculate_dodge_chance() -> float:
	var attributes := _active_attributes()
	return StatCalculator.calculate_dodge_chance(attributes) if attributes else 0.0


func calculate_accuracy() -> float:
	var attributes := _active_attributes()
	return StatCalculator.calculate_accuracy(attributes) if attributes else 0.0


func calculate_critical_chance() -> float:
	var attributes := _active_attributes()
	return StatCalculator.calculate_critical_chance(attributes) if attributes else 0.0


# ── Прочие тонкие делегаты для UI ──────────────────────────────────────────

func get_class_data(class_id: String, subclass_id: String = "") -> Dictionary:
	"""Данные класса (делегат к CharacterManager; определения живут в JSON)."""
	return get_node(^"CharacterManager").get_class_data(class_id, subclass_id)


func switch_character(character_id: String) -> bool:
	"""Смена активного персонажа (делегат к CharacterManager)."""
	return get_node(^"CharacterManager").switch_character(character_id)


func get_current_player() -> Node:
	"""Узел игрока в текущей сцене. Единственный владелец — группа GameGroups.PLAYER."""
	var tree := get_tree()
	return tree.get_first_node_in_group(GameGroups.PLAYER) if tree else null

# NOTE: add_stat_point() намеренно НЕ добавлен. В этом проекте пул очков
# характеристик исключён (см. комментарии "Исключены ... stat_points" в
# CharacterManager/PlayerStateManager), поэтому трата очков не имеет бюджета.
# Кадр Figma menu-status кнопок траты тоже не содержит.
# См. design/ui_visual_qa.md → "Данные, которых нет".
