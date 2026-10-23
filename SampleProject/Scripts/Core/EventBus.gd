extends Node

## 📡 EventBus - Централізована система подій для бойової системи
## Замінює прямі виклики та залежності між системами
## Дотримується принципу Observer Pattern
##
## Примітка: Сигнали в EventBus не використовуються безпосередньо в цьому класі,
## але вони призначені для використання іншими класами через EventBus.signal_name.connect()
## Тому перед кожним сигналом додано @warning_ignore("unused_signal") для придушення попереджень

# ============================================
# PLAYER EVENTS
# ============================================

## Емітується при зміні здоров'я гравця.
##
## Args:
##     new_health (int): Поточне здоров'я гравця
##     max_health (int): Максимальне здоров'я гравця
##
## Приклади:
##     EventBus.player_health_changed.connect(_on_player_health_changed)
##     EventBus.player_health_changed.emit(80, 100)
signal player_health_changed(new_health: int, max_health: int)

## Емітується при смерті гравця.
##
## Приклади:
##     EventBus.player_died.connect(_on_player_died)
##     EventBus.player_died.emit()
@warning_ignore("unused_signal")
signal player_died()

## Емітується при приземленні гравця.
##
## Args:
##     fall_height (float): Висота падіння в пікселях
##
## Приклади:
##     EventBus.player_landed.connect(_on_player_landed)
##     EventBus.player_landed.emit(100.0)
@warning_ignore("unused_signal")
signal player_landed(fall_height: float)

## Емітується при початку атаки гравця (незалежно від того, чи є ціль).
##
## Args:
##     player (Node): Гравець, який атакує
##     direction (int): Напрямок атаки (1 = вправо, -1 = вліво)
##
## Приклади:
##     EventBus.player_attacked.connect(_on_player_attacked)
##     EventBus.player_attacked.emit(player, 1)
@warning_ignore("unused_signal")
signal player_attacked(player: Node, direction: int)

## Емітується при підвищенні рівня гравця.
##
## Args:
##     new_level (int): Новий рівень гравця
##     old_level (int): Попередній рівень гравця
##
## Приклади:
##     EventBus.player_leveled_up.connect(_on_player_leveled_up)
##     EventBus.player_leveled_up.emit(2, 1)
@warning_ignore("unused_signal")
signal player_leveled_up(new_level: int, old_level: int)

## Емітується при зміні кількості монет гравця.
##
## Args:
##     new_amount (int): Нова кількість монет
##
## Приклади:
##     EventBus.coins_changed.connect(_on_coins_changed)
##     EventBus.coins_changed.emit(150)
@warning_ignore("unused_signal")
signal coins_changed(new_amount: int)

# ============================================
# ENEMY EVENTS
# ============================================

## Емітується при спавні ворога.
##
## Args:
##     enemy_id (String): ID ворога (зазвичай enemy.name)
##     position (Vector2): Позиція спавна ворога
##
## Приклади:
##     EventBus.enemy_spawned.connect(_on_enemy_spawned)
##     EventBus.enemy_spawned.emit("enemy_1", Vector2(500, 500))
@warning_ignore("unused_signal")
signal enemy_spawned(enemy_id: String, position: Vector2)

## Емітується при смерті ворога.
##
## Args:
##     enemy_id (String): ID ворога
##     position (Vector2): Позиція смерті ворога
##
## Приклади:
##     EventBus.enemy_died.connect(_on_enemy_died)
##     EventBus.enemy_died.emit("enemy_1", Vector2(500, 500))
signal enemy_died(enemy_id: String, position: Vector2)

## Емітується при зміні здоров'я ворога.
##
## Args:
##     enemy_id (String): ID ворога
##     new_health (int): Поточне здоров'я ворога
##     max_health (int): Максимальне здоров'я ворога
##
## Приклади:
##     EventBus.enemy_health_changed.connect(_on_enemy_health_changed)
##     EventBus.enemy_health_changed.emit("enemy_1", 50, 100)
@warning_ignore("unused_signal")
signal enemy_health_changed(enemy_id: String, new_health: int, max_health: int)

# ============================================
# COMBAT EVENTS
# ============================================

## Емітується при нанесенні ушкоджень.
##
## Args:
##     source (Node): Джерело ушкоджень (той, хто наніс ушкодження)
##     target (Node): Ціль ушкоджень (той, хто отримав ушкодження)
##     amount (int): Кількість ушкоджень
##
## Приклади:
##     EventBus.damage_dealt.connect(_on_damage_dealt)
##     EventBus.damage_dealt.emit(player, enemy, 25)
signal damage_dealt(source: Node, target: Node, amount: int)

## Емітується при отриманні ушкоджень.
##
## Args:
##     target (Node): Ціль ушкоджень (той, хто отримав ушкодження)
##     source (Node): Джерело ушкоджень (той, хто наніс ушкодження)
##     amount (int): Кількість ушкоджень
##     critical (bool): Крит героя (D393) — цифра урону більша (DamageNumbers)
##
## Приклади:
##     EventBus.damage_received.connect(_on_damage_received)
##     EventBus.damage_received.emit(player, enemy, 25, false)
@warning_ignore("unused_signal")
signal damage_received(target: Node, source: Node, amount: int, critical: bool)

## Емітується при початку атаки.
##
## Args:
##     attacker (Node): Той, хто атакує
##     target (Node): Ціль атаки
##
## Приклади:
##     EventBus.attack_started.connect(_on_attack_started)
##     EventBus.attack_started.emit(enemy, player)
@warning_ignore("unused_signal")
signal attack_started(attacker: Node, target: Node)

## Souls-lite (D264): ворога збито (стійкість вичерпано або парировано), героя збито ударом,
## герой парирував удар, каст навички зірвано ударом (D259 — SP і кулдаун усе одно списано).
@warning_ignore("unused_signal")
signal enemy_staggered(enemy: Node, duration: float)
@warning_ignore("unused_signal")
signal player_staggered(duration: float)
@warning_ignore("unused_signal")
signal player_parried(attacker: Node)
@warning_ignore("unused_signal")
signal player_blocked(attacker: Node)
## Герой ухилився від удару (D393, Player.mitigated_damage): шкоди немає — слово над ним (DamageNumbers).
@warning_ignore("unused_signal")
signal player_evaded(attacker: Node)
## Почався / скінчився бій героя (D268): зброя з-за спини в руку й назад.
@warning_ignore("unused_signal")
signal combat_state_changed(in_combat: bool)
## Бій з босом у його залі почався / скінчився (D414): LabBoss і MayorHall; [param arena] — сама зала.
## Кінець — смерть боса або поразка героя; зала, що зникла посеред бою, теж його кінчає (SoundHooks).
@warning_ignore("unused_signal")
signal boss_fight_changed(arena: Node, active: bool)
## Замах важкого удару героя (D264) — WeaponView піднімає зброю.
@warning_ignore("unused_signal")
signal player_heavy_windup(player: Node, direction: int)
## Лук героя (D380): почався натяг; стріла вилетіла (charged — заряджений постріл). Звуки — SoundHooks.
@warning_ignore("unused_signal")
signal player_bow_drawn(player: Node)
@warning_ignore("unused_signal")
signal player_shot(player: Node, charged: bool)
@warning_ignore("unused_signal")
signal skill_interrupted(skill_id: String)
## Почався замах касту навички (D271) — звук замаху (D276).
@warning_ignore("unused_signal")
signal skill_cast_started(skill_id: String)

## Емітується при завершенні атаки.
##
## Args:
##     attacker (Node): Той, хто атакував
##
## Приклади:
##     EventBus.attack_finished.connect(_on_attack_finished)
##     EventBus.attack_finished.emit(player)
@warning_ignore("unused_signal")
signal attack_finished(attacker: Node)

# ============================================
# EQUIPMENT EVENTS
# ============================================

## Емітується при запиті на экипування предмета.
##
## Args:
##     character_id (String): ID персонажа
##     slot_id (String): ID слота (sword, shield, head, etc.)
##     item_id (String): ID предмета
##     item_data (Dictionary): Данные предмета
##
## Приклади:
##     EventBus.equipment_equip_requested.connect(_on_equip_requested)
##     EventBus.equipment_equip_requested.emit("player_1", "sword", "iron_sword", {...})
@warning_ignore("unused_signal")
# ============================================================================
# НАВЫКИ (Skills)
# ============================================================================

## Навык разблокирован.
##
## Пример:
##     EventBus.skill_unlocked.connect(_on_skill_unlocked)
##     EventBus.skill_unlocked.emit("shadow_strike")
signal skill_unlocked(skill_id: String)
## Навичку покращено до рівня rank (D150).
signal skill_upgraded(skill_id: String, rank: int)
## Герой присягнув клятві (D280): "paladin" / "dark_knight" / "warden". Назавжди.
signal oath_sworn(oath_id: String)
## Навички скинуто за монети (D282) чи безкоштовно (D490): усе забуто, refunded очок повернуто, клятва лишилась.
signal skills_reset(refunded: int)
## Невкладених очок атрибутів стало current (D335): рівень, вкладення, скидання.
signal attribute_points_changed(current: int, previous: int)
## Змінилось, скільки очок вкладено в атрибути (D335) — Max HP, SP, атака перераховуються.
signal attributes_changed()

## Активный навык успешно применён: проверки пройдены, SP списан,
## боевой эффект выполнен, перезарядка запущена. Ошибочные попытки сюда НЕ попадают.
##
## Пример:
##     EventBus.skill_used.emit("shadow_strike")
signal skill_used(skill_id: String)

## Навык НЕ был применён. reason — значение SkillManager.Result.
## Гарантия: при этом событии SP не списан, перезарядка не запущена,
## урон не нанесён. Предназначено для UI-обратной связи и звука ошибки.
##
## Пример:
##     EventBus.skill_failed.emit("shadow_strike", SkillManager.Result.NOT_ENOUGH_SP)
signal skill_failed(skill_id: String, reason: int)

## Изменился боевой лоадаут (equipped_skills). Передаётся копия массива слотов.
## Прогресс (unlocked_skills) этим сигналом НЕ затрагивается.
##
## Пример:
##     EventBus.equipped_skills_changed.emit(["fireball", "", "dash", ""])
signal equipped_skills_changed(loadout: Array)

## Изменилось количество Job Points.
##
## Пример:
##     EventBus.job_points_changed.emit(920, 1000)
signal job_points_changed(current: int, previous: int)

## Изменился SP активного персонажа.
##
## Пример:
##     EventBus.sp_changed.emit(80, 120)
signal sp_changed(current_sp: int, max_sp: int)

## Заряди фляги змінились (D504, Healing Palm): ковток, зірваний каст, поповнення при збереженні.
signal skill_charges_changed(skill_id: String, charges: int, max_charges: int)

## Гравець зберігає гру на екрані збереження (точка збереження / медитація, D447): фляга поповнюється (D504)
## до запису, тож сейв уже з повною флягою. Автозбереження при переході кімнатою (D413) цього не емітує.
@warning_ignore("unused_signal")
signal game_saving(slot: int)

signal equipment_equip_requested(character_id: String, slot_id: String, item_id: String, item_data: Dictionary)

## Емітується при успешному экипировании предмета.
##
## Args:
##     character_id (String): ID персонажа
##     slot_id (String): ID слота
##     item_id (String): ID предмета
##
## Приклади:
##     EventBus.equipment_equipped.connect(_on_equipped)
##     EventBus.equipment_equipped.emit("player_1", "sword", "iron_sword")
@warning_ignore("unused_signal")
signal equipment_equipped(character_id: String, slot_id: String, item_id: String)

## Емітується при запиті на снятие предмета.
##
## Args:
##     character_id (String): ID персонажа
##     slot_id (String): ID слота
##
## Приклади:
##     EventBus.equipment_unequip_requested.connect(_on_unequip_requested)
##     EventBus.equipment_unequip_requested.emit("player_1", "sword")
@warning_ignore("unused_signal")
signal equipment_unequip_requested(character_id: String, slot_id: String)

## Емітується при успешном снятии предмета.
##
## Args:
##     character_id (String): ID персонажа
##     slot_id (String): ID слота
##
## Приклади:
##     EventBus.equipment_unequipped.connect(_on_unequipped)
##     EventBus.equipment_unequipped.emit("player_1", "sword")
@warning_ignore("unused_signal")
signal equipment_unequipped(character_id: String, slot_id: String)

## Асист компаньйона (D209): викликано / знову готовий.
@warning_ignore("unused_signal")
signal assist_called(companion_id: String)
@warning_ignore("unused_signal")
signal assist_ready(companion_id: String)

## Склад або порядок загону змінився (Status, лабораторія — D220).
@warning_ignore("unused_signal")
signal companion_party_changed()

## Компаньйона щойно відкрито (лабораторія, D230): тепер його можна взяти в загін у Status (D464) — сповіщення на екрані.
@warning_ignore("unused_signal")
signal companion_joined(companion_id: String)

## Зброя в руці змінилась (D202): слот зброї або "" — голі руки.
@warning_ignore("unused_signal")
signal weapon_in_hand_changed(slot_id: String)

# ============================================
# SCENE EVENTS
# ============================================

## Емітується при початку переходу між сценами.
##
## Args:
##     from_scene (String): Шлях до поточної сцени
##     to_scene (String): Шлях до цільової сцени
@warning_ignore("unused_signal")
signal scene_transition_started(from_scene: String, to_scene: String)

## Емітується при завершенні переходу між сценами.
##
## Args:
##     scene_name (String): Шлях до завантаженої сцени
@warning_ignore("unused_signal")
signal scene_transition_completed(scene_name: String)

## Емітується при завантаженні сцени.
##
## Args:
##     scene_name (String): Шлях до завантаженої сцени
@warning_ignore("unused_signal")
signal scene_loaded(scene_name: String)

## Гравець у новій кімнаті MetSys (Game.init_room): ім'я файлу кімнати без розширення («DesertRoad»). Звук кімнати (D276).
@warning_ignore("unused_signal")
signal room_entered(room_name: String)

## Емітується при зміні стану сцени (наприклад, Canyon, Village).
##
## Args:
##     scene_name (String): Назва сцени (наприклад, "Canyon")
##     old_state (String): Попередній стан
##     new_state (String): Новий стан
##
## Приклади:
##     EventBus.scene_state_changed.connect(_on_scene_state_changed)
##     EventBus.scene_state_changed.emit("Canyon", "INTRO", "MONOLOGUE")
@warning_ignore("unused_signal")
signal scene_state_changed(scene_name: String, old_state: String, new_state: String)

# ============================================
# DIALOGUE EVENTS
# ============================================

## Емітується при початку діалогу.
##
## Args:
##     dialogue_id (String): ID діалогу
@warning_ignore("unused_signal")
signal dialogue_started(dialogue_id: String)

## Емітується при завершенні діалогу.
##
## Args:
##     dialogue_id (String): ID діалогу
@warning_ignore("unused_signal")
signal dialogue_finished(dialogue_id: String)

# ============================================
# INVENTORY EVENTS
# ============================================

## Емітується при додаванні предмета в інвентар.
##
## Args:
##     item_id (String): ID предмета
##     quantity (int): Кількість предметів
@warning_ignore("unused_signal")
signal item_added(item_id: String, quantity: int)

## Герой підібрав здобич переможеного моба (монети з ворога, монети LootSystem) — уже в інвентарі.
## Слухає стрічка здобичі на HUD (BACKLOG 33, loot_feed.gd). Дарунки й нагороди сюди не йдуть — у них модалка.
##
## Args:
##     item_id (String): ID предмета
##     amount (int): Кількість
@warning_ignore("unused_signal")
signal loot_picked_up(item_id: String, amount: int)

## Емітується при видаленні предмета з інвентаря.
##
## Args:
##     item_id (String): ID предмета
##     quantity (int): Кількість предметів
@warning_ignore("unused_signal")
signal item_removed(item_id: String, quantity: int)

## Емітується при використанні предмета.
##
## Args:
##     item_id (String): ID предмета
@warning_ignore("unused_signal")
signal item_used(item_id: String)

## Емітується при оновленні інвентаря.
@warning_ignore("unused_signal")
signal inventory_updated()

## Емітується при воскресінні гравця.
@warning_ignore("unused_signal")
signal player_respawned()

## Останній пристрій вводу змінився (InputGlyphs.note_event): підказки й бейджі перемальовують назви кнопок (BACKLOG 24).
@warning_ignore("unused_signal")
signal input_device_changed(using_gamepad: bool)

# ============================================
# UTILITY METHODS
# ============================================

func _ready() -> void:
	"""Ініціалізація EventBus"""
	print("📡 EventBus: Initialized")

func emit_player_health_changed(new_health: int, max_health: int) -> void:
	"""Емітує сигнал зміни здоров'я гравця"""
	player_health_changed.emit(new_health, max_health)

func emit_enemy_died(enemy_id: String, position: Vector2 = Vector2.ZERO) -> void:
	"""Емітує сигнал смерті ворога"""
	enemy_died.emit(enemy_id, position)

func emit_damage_dealt(source: Node, target: Node, amount: int) -> void:
	"""Емітує сигнал нанесення ушкоджень"""
	damage_dealt.emit(source, target, amount)
