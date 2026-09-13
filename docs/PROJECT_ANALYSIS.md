# 📊 Аналіз проекту - Godot Metroidvania Game

**Дата аналізу:** 2026-01-XX  
**Версія Godot:** 4.5  
**Мова програмування:** GDScript  
**Тип проекту:** Metroidvania-style RPG з діалогами та бойовою системою

---

## 🎯 Загальний огляд

### Статус проекту
- **Фаза розробки:** Persistent Prototype → Production Ready
- **Тестування:** 154 тести (100% pass rate) через GUT framework
- **Документація:** Детальна документація в `docs/`
- **Архітектура:** Service Locator Pattern + EventBus + Manager Pattern

### Основні характеристики
- **Жанр:** Metroidvania RPG
- **Стиль:** 2D платформер з бойовою системою
- **Системи:** Combat, Inventory, Dialogue, Save/Load, XP/Level, Quest Flags
- **Аддони:** MetroidvaniaSystem, DialogueQuest, GUT, та інші (18+ аддонів)

---

## 📁 Структура проекту

### Основні директорії

```
new-game-project/
├── SampleProject/          # Основна логіка гри
│   ├── Scripts/           # GDScript файли
│   │   ├── Core/          # Ядро системи (EventBus, ServiceLocator)
│   │   ├── Managers/      # Менеджери (GameManager, UIManager, тощо)
│   │   ├── Systems/       # Системи (Inventory, Dialogue, Save)
│   │   ├── Gameplay/      # Ігрова логіка (Player, Enemies, Combat)
│   │   └── UI/            # UI компоненти
│   ├── Maps/              # Кімнати/локації (MetSys)
│   ├── Scenes/            # Сцени (.tscn)
│   └── Resources/         # Ресурси (.tres)
├── addons/                # Аддони Godot
├── dialogue_quest/         # Діалоги (.dqd)
└── docs/                  # Документація
```

### Ключові файли

| Файл | Призначення | Розмір |
|------|-------------|--------|
| `Game.gd` | Головна логіка гри, збереження | ~485 рядків |
| `Player.gd` | Контролер гравця | ~511 рядків |
| `EventBus.gd` | Система подій (Observer Pattern) | ~338 рядків |
| `GameManager.gd` | Координатор менеджерів | ~186 рядків |
| `ServiceLocator.gd` | Доступ до менеджерів | ~200+ рядків |

---

## 🏗️ Архітектура системи

### 1. Core Systems (Ядро)

#### ServiceLocator Pattern
- **Призначення:** Централізований доступ до менеджерів
- **Реалізація:** 5 категорій Registry (Core, UI, Gameplay, System, Data)
- **Використання:** `ServiceLocator.get_*_manager()`

**Категорії сервісів:**
- **CoreServiceRegistry:** GameManager, SaveSystem
- **UIServiceRegistry:** UIManager, UIUpdateManager, MenuManager, DisplayManager
- **GameplayServiceRegistry:** CharacterManager, EquipmentManager, InventoryManager, DialogueManager, XPManager
- **SystemServiceRegistry:** TimeManager, AudioManager, MusicManager, DebugManager, SceneManager
- **DataServiceRegistry:** ItemDatabase, SettingsManager, LocalizationManager

#### EventBus (Observer Pattern)
- **Призначення:** Глобальна система подій
- **Сигнали:** 25+ подій (player_health_changed, enemy_died, item_added, тощо)
- **Переваги:** Розв'язаність систем, легке тестування

#### GameGroups
- **Призначення:** Централізовані константи груп нод з кешуванням
- **Використання:** `GameGroups.get_player()`, `GameGroups.get_enemies()`

---

### 2. Manager Hierarchy

```
GameManager (autoload)
├── CharacterManager
├── EquipmentManager
├── InventoryManager
├── DialogueManager
├── XPManager
├── TutorialManager
├── UIManager
├── MenuManager
├── TimeManager
├── SceneManager
├── EnemyStateManager
├── PlayerStateManager
├── CompanionManager
├── GameFlow
└── [+ 5 більше менеджерів]
```

**Всі менеджери:**
- Розширюють `ManagerBase`
- Мають метод `_initialize()`
- Реєструються в ServiceLocator через Registry систему

---

### 3. Gameplay Systems

#### Combat System
- **Базовий клас:** `CombatBody2D` (extends CharacterBody2D)
- **Компоненти:**
  - `HealthComponent` - здоров'я
  - `HurtboxComponent` - зона отримання урону
  - `DamageApplier` - нанесення урону
- **Інтерфейси:** `ICombatant`, `IDamageable`, `IDamageDealer`
- **VFX:** SlashTrail, HitImpact, DeathParticles

#### Inventory System
- **InventoryManager:** Додавання/видалення предметів
- **ItemDatabase:** База даних предметів (JSON)
- **LootSystem:** Система дропа з ворогів
- **Coin System:** Монети як вторинна валюта

#### XP & Level System
- **XPManager:** Управління досвідом та рівнями
- **Прогресія:** Лінійна (Level × 100 XP)
- **Бонуси:** +20 HP, +5 Damage на рівень
- **UI:** XPBar, LevelUpNotification

#### Dialogue System
- **Інтеграція:** DialogueQuest addon
- **DialogueManager:** Управління діалогами
- **Файли:** `.dqd` в `dialogue_quest/`
- **Тригери:** DialogueTrigger (Area2D)

#### Save/Load System
- **Два механізми:**
  1. MetSys SaveManager (карти, позиція)
  2. Custom SaveSystem (інвентар, флаги)
- **Координація:** `Game.gd` синхронізує обидва
- **Автозбереження:** При переході між кімнатами

---

### 4. Map System (MetroidvaniaSystem)

#### Структура карт
- **Кімнати:** `.tscn` файли в `SampleProject/Maps/`
- **Локації:** Canyon, Village, City, Laboratory, тощо
- **Порти:** Portal система для переходів
- **SavePoints:** Точки збереження/респавну

#### MapData
- **Файл:** `SampleProject/Maps/MapData.txt`
- **Формат:** MetSys формат для зв'язків кімнат
- **Мінімапа:** Вбудована в UI

---

## 🎮 Ігрові механіки

### Player Mechanics
- **Рух:** WASD/Arrow Keys + Space для стрибка
- **Атака:** Ліва кнопка миші / X на контролері
- **Double Jump:** Здобуття через abilities
- **Coyote Time:** 0.1s для стрибка після зійдення з платформи
- **Short Hop:** Скорочення стрибка при відпусканні Space

### Combat Mechanics
- **Урон:** Базується на статах + рівень
- **Health Bars:** Для гравця та ворогів
- **VFX:** SlashTrail, HitImpact, DeathParticles
- **AI:** EnemyLogic для ворогів

### Progression Mechanics
- **XP:** За вбивство ворогів
- **Coins:** Дроп з ворогів (2-6 монет)
- **Level Up:** Автоматичне збільшення HP та Damage
- **Tutorial:** Автоматичні підказки для нових гравців

---

## 📊 Статистика коду

### Розмір проекту
- **Скрипти:** 171+ GDScript файлів
- **Сцени:** 67+ .tscn файлів
- **Діалоги:** 30+ .dqd файлів
- **Тести:** 154 тести (134 unit + 20 integration)

### Autoload Singletons
**18 autoloads:**
- MetSys, GameManager, EventBus, SaveSystem
- ServiceLocator, AudioManager, DisplayManager
- MusicManager, ItemDatabase, LocalizationManager
- SettingsData, ModalDialogGlobal, ModalWindowManager
- AppConfig, SceneLoader, ProjectMusicController
- ProjectUISoundController, LongSceneManager
- TrajectoryRegister, DialogueQuest

---

## ✅ Сильні сторони

### 1. Архітектура
- ✅ **Service Locator Pattern:** Чіткий доступ до менеджерів
- ✅ **EventBus:** Розв'язаність систем через події
- ✅ **Manager Pattern:** Розділення відповідальностей
- ✅ **Registry System:** Категорізація сервісів (5 реєстрів)

### 2. Документація
- ✅ **Детальна документація:** `docs/CLAUDE.md`, `CLAUDE_FULL.md`
- ✅ **Технічні гайди:** Combat, UI, Save System
- ✅ **Аналіз архітектури:** `SENIOR_DEV_ANALYSIS.md`

### 3. Тестування
- ✅ **154 тести:** 100% pass rate
- ✅ **GUT framework:** Автоматизоване тестування
- ✅ **Покриття:** XP, Coins, Tutorial, VFX, UI, Combat

### 4. Системи
- ✅ **Модульність:** Кожна система окремо
- ✅ **Розширюваність:** Легко додавати нові менеджери
- ✅ **Збереження:** Повна підтримка save/load

---

## ⚠️ Проблеми та рекомендації

### 1. Технічний борг (згідно SENIOR_DEV_ANALYSIS.md)

#### ❌ God Objects
- **Player.gd (~600 рядків):** Обробляє input, physics, animation, combat, UI
- **Game.gd (~350 рядків):** Обробляє save/load, scene management, flags, input
- **Рекомендація:** Розбити на компоненти (PlayerMover, PlayerCombat, PlayerAnimator)

#### ❌ Duplicate Save Logic
- **Проблема:** Два механізми збереження (MetSys + Custom SaveSystem)
- **Ризик:** Десинхронізація даних
- **Рекомендація:** Уніфікувати в один source of truth

#### ❌ Initialization Race Conditions
- **Проблема:** `ServiceLocator` має `MAX_REGISTRATION_RETRIES = 10`
- **Рекомендація:** Використовувати signal-based ініціалізацію

### 2. Структура проекту

#### 🚩 Root Directory Chaos
- **Проблема:** Багато файлів в корені (`.bat`, `.md`, `.txt`)
- **Рекомендація:** Перемістити в `Tools/` та структурувати `docs/`

#### 🚩 "SampleProject" Ambiguity
- **Проблема:** Неясно, чи це основний проект чи демо
- **Рекомендація:** Перейменувати в `Src/` або `Game/`

### 3. Code Quality

#### 🚩 Hardcoded Preloads
- **Проблема:** `Player.gd` preloads VFX scenes напряму
- **Рекомендація:** Використовувати `@export` змінні

#### 🚩 Naming Inconsistency
- **Проблема:** Змішування `PascalCase`, `snake_case`, `SHOUTY_SNAKE_CASE`
- **Рекомендація:** Прийняти єдиний стиль (GDScript: `snake_case`)

#### 🚩 Autoload Overuse
- **Проблема:** 18 autoloads (глобальний стан)
- **Рекомендація:** Використовувати тільки для справді глобальних систем

### 4. SOLID Principles

#### ❌ Single Responsibility Principle (SRP)
- **Проблема:** Player.gd та Game.gd роблять занадто багато
- **Рекомендація:** Розбити на компоненти

#### ❌ Open-Closed Principle (OCP)
- **Проблема:** `GameManager._create_managers()` - список ручних preloads
- **Рекомендація:** Використовувати registration system

#### ❌ Dependency Inversion Principle (DIP)
- **Проблема:** Service Locator "smell" - класи досягають ServiceLocator замість injection
- **Рекомендація:** Dependency Injection через `init()` або `@export`

---

## 🔧 Відомі проблеми

### 1. Player Spawning
- ⚠️ **Проблема:** Позиція гравця НЕ зберігається між сесіями
- **Поточна поведінка:** Спавн на MetSys starting coords при завантаженні
- **Статус:** Відомо, потребує виправлення

### 2. Portal Infinite Loop (ВИПРАВЛЕНО)
- ✅ **Було:** Нескінченний цикл при переході через портал
- ✅ **Виправлення:** Статичний cooldown для порталів

### 3. Enemy Spawning/Physics (ВИПРАВЛЕНО)
- ✅ **Було:** Проблеми зі спавном та фізикою ворогів
- ✅ **Виправлення:** Оновлено систему спавну

---

## 📈 Пріоритети рефакторингу

### Високий пріоритет
1. **Decouple Player:** Винести рух та бій в компоненти
2. **Unify Save System:** Вибрати один метод збереження
3. **Fix Initialization:** Прибрати retry логіку, використати signals
4. **Clean up Root:** Перемістити скрипти та docs в підпапки

### Середній пріоритет
5. **Naming Consistency:** Прийняти єдиний стиль коду
6. **Reduce Autoloads:** Перемістити менеджери в scene hierarchy
7. **Animation Tree:** Замінити if/else на AnimationTree StateMachine

### Низький пріоритет
8. **Dependency Injection:** Замінити Service Locator на DI де можливо
9. **Component System:** Розширити компонентну архітектуру

---

## 🎯 Оцінка проекту

### Architecture Grade: **C+**
- **Функціональність:** ✅ Працює
- **Модульність:** ⚠️ Частково (God Objects)
- **Розширюваність:** ✅ Добре (Manager Pattern)
- **Тестування:** ✅ Відмінно (154 тести)

### Maintainability Grade: **D**
- **Tight Coupling:** ❌ Player.gd та Game.gd занадто пов'язані
- **Global State:** ⚠️ 18 autoloads
- **Code Duplication:** ⚠️ Два save systems
- **Documentation:** ✅ Відмінна

### Overall Status: **Persistent Prototype → Production Ready**
- Проект функціональний, але має технічний борг
- Потребує рефакторингу перед масштабуванням
- Документація та тестування на високому рівні

---

## 📚 Документація

### Основні документи
- `CLAUDE.md` - Швидкий довідник для Claude Code
- `CLAUDE_FULL.md` - Повна технічна документація
- `SENIOR_DEV_ANALYSIS.md` - Аналіз архітектури
- `SYSTEMS_OVERVIEW.md` - Огляд систем
- `PROJECT_METHODS_DOCUMENTATION.txt` - Документація методів

### Технічні гайди
- `Combat/COMBAT_SYSTEM_ARCHITECTURE.md`
- `Combat/COMBAT_SETUP_GUIDE.md`
- `TESTS_COMPLETE.md` - Гайд по тестуванню
- `DEMO_TEST_PLAN.md` - План тестування демо

---

## 🚀 Наступні кроки

### Короткострокові
1. Виправити Player Spawning (збереження позиції)
2. Уніфікувати Save System
3. Очистити root directory

### Середньострокові
4. Рефакторинг Player.gd (компоненти)
5. Рефакторинг Game.gd (розділення відповідальностей)
6. Зменшити кількість autoloads

### Довгострокові
7. Повний перехід на Dependency Injection
8. Component-based architecture
9. Animation Tree замість if/else

---

## 📝 Висновки

Проект знаходиться в стадії **Persistent Prototype** з хорошим фундаментом:
- ✅ Сильна архітектура (Service Locator + EventBus)
- ✅ Детальна документація
- ✅ Комплексне тестування
- ⚠️ Технічний борг потребує уваги
- ⚠️ God Objects потребують рефакторингу

**Рекомендація:** Перед масштабуванням провести рефакторинг ключових компонентів (Player, Game) та уніфікувати системи збереження.

---

**Останнє оновлення:** 2026-01-XX  
**Версія документа:** 1.0
