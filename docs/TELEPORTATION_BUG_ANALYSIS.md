# 🔍 Аналіз проблеми подвійної телепортації при поверненні з Village

## Проблема

При поверненні з Village до Canyon:
1. Гравець телепортується в кінець каньйону (не туди, де стоїть сейв поінт)
2. Потім знову телепортує в село
3. Це пов'язано з MetSys

## ⚠️ ВАЖЛИВО: Врахування всіх аддонів

При розробці виправлень обов'язково враховувати всі аддони, які можуть впливати на позиціонування гравця та переходи між сценами:

### Основні аддони, що впливають на телепортацію:

1. **MetroidvaniaSystem (MetSys)** - основний аддон для управління кімнатами
   - `MetSys.load_room()` - завантаження кімнат
   - `MetSys.last_player_position` - остання позиція гравця
   - `MetSys.set_player_position()` - встановлення позиції гравця
   - `MetSys.room_loaded` - сигнал завантаження кімнати
   - `MetSys.room_changed` - сигнал зміни кімнати
   - Модуль `RoomTransitions.gd` - обробка переходів між кімнатами
   - Модуль `ScrollingRoomTransitions.gd` - альтернативний модуль переходів (не використовується зараз)

2. **DialogueQuest** - для діалогів
   - Може впливати на стан сцени та переходи

3. **long_scene_manager** - для управління довгими сценами
   - Може впливати на завантаження сцен

4. **SceneManager** (внутрішній менеджер) - для переходів між сценами
   - Може конфліктувати з MetSys при позиціонуванні гравця

5. **SaveSystem** - для збереження/завантаження
   - Відновлює позицію гравця при завантаженні

6. **ServiceLocator** - для доступу до менеджерів
   - Надає доступ до різних систем

### Взаємодія аддонів:

- **MetSys** використовує `RoomTransitions.gd` модуль для обробки переходів
- **MetSys** автоматично позиціонує гравця при завантаженні кімнати через room connections
- **SceneManager** також намагається позиціонувати гравця, що може викликати конфлікт
- **SaveSystem** відновлює позицію гравця при завантаженні, але не при переходах
- **Player.on_enter()** зберігає позицію як `reset_position` при вході в кімнату

## Можливі причини

### 1. ❌ Проблема з позицією спавну в MetSys

**Причина:**
- MetSys використовує `last_player_position` для позиціонування гравця при завантаженні кімнати
- Якщо гравець був в кінці каньйону перед переходом до Village, MetSys зберігає цю позицію
- При поверненні MetSys використовує цю збережену позицію для спавну, а не позицію SavePoint

**Файли:**
- `SampleProject/Scripts/Game.gd` - `init_room()` викликає `player.on_enter()`, який зберігає `reset_position = position`
- `SampleProject/Scripts/Player.gd` - `on_enter()` зберігає поточну позицію як `reset_position`
- MetSys використовує `last_player_position` для позиціонування при завантаженні кімнати

**Рішення:**
- Додати логіку в `Game.init_room()` для позиціонування гравця на SavePoint при поверненні до Canyon
- Перевірити, чи правильно встановлюється позиція через MetSys room connections

### 2. ❌ Конфлікт між MetSys room connections та логікою переходів

**Причина:**
- При переході через room connections MetSys автоматично позиціонує гравця
- Але якщо є якась логіка в `Canyon.gd`, яка також намагається позиціонувати гравця, може виникнути конфлікт
- Можливо, `init_room()` викликається кілька разів, що призводить до подвійної телепортації

**Файли:**
- `SampleProject/Scripts/Game.gd` - `init_room()` викликається при завантаженні кімнати
- `SampleProject/Scripts/Gameplay/Scenes/Canyon.gd` - може мати логіку, яка впливає на позицію гравця

**Рішення:**
- Перевірити, чи `init_room()` викликається кілька разів
- Додати захист від повторного виклику
- Переконатися, що тільки одна система позиціонує гравця

### 3. ❌ Автоматичний перехід при стані RELIC_PICKUP

**Причина:**
- При поверненні з Village стан встановлюється як `RELIC_PICKUP`
- Можливо, є якась логіка, яка автоматично викликає перехід назад до Village при цьому стані
- Або є конфлікт між станом `RELIC_PICKUP` та станом `TO_VILLAGE`

**Файли:**
- `SampleProject/Scripts/Gameplay/Scenes/Canyon.gd` - `_determine_initial_state()` встановлює стан `RELIC_PICKUP`
- `_on_state_changed()` може мати логіку, яка викликає перехід

**Рішення:**
- Перевірити, чи немає автоматичного переходу при стані `RELIC_PICKUP`
- Переконатися, що стан `RELIC_PICKUP` не викликає перехід до Village

### 4. ❌ Неправильна позиція в MetSys.last_player_position

**Причина:**
- MetSys зберігає останню позицію гравця в `last_player_position`
- Якщо ця позиція не оновлюється правильно при переході до Village, при поверненні використовується стара позиція
- Можливо, позиція встановлюється на кінець каньйону замість позиції SavePoint

**Файли:**
- `SampleProject/Scripts/Game.gd` - `init_room()` встановлює `MetSys.set_player_position(player.position)` тільки якщо `last_player_position.x == Vector2i.MAX.x`
- `SampleProject/Scripts/SavePoint.gd` - оновлює `MetSys.set_player_position()` при збереженні

**Рішення:**
- Перевірити, чи правильно оновлюється `MetSys.last_player_position` при переході до Village
- Додати логіку для позиціонування гравця на SavePoint при поверненні до Canyon

### 5. ❌ Конфлікт між SceneManager та MetSys

**Причина:**
- `SceneManager` має свою логіку позиціонування гравця
- MetSys також має свою логіку позиціонування
- Можливо, обидві системи намагаються позиціонувати гравця одночасно, що призводить до конфлікту

**Файли:**
- `SampleProject/Scripts/Managers/Scene/SceneManager.gd` - має логіку позиціонування гравця
- MetSys використовує room connections для позиціонування

**Рішення:**
- Переконатися, що тільки одна система позиціонує гравця
- Якщо використовується MetSys room connections, SceneManager не повинен позиціонувати гравця

### 6. ❌ **КРИТИЧНО: Гра перестворюється (recreation)**

**Причина:**
- Якщо гра перестворюється (викликається `Game._ready()` кілька разів), це може викликати подвійну телепортацію
- `init_room()` може викликатися кілька разів для тієї ж кімнати
- `load_room()` може викликатися кілька разів, що призводить до повторного завантаження сцени
- MetSys `room_loaded` сигнал може емітуватися кілька разів

**Файли:**
- `SampleProject/Scripts/Game.gd` - `_ready()` має захист через `_bootstrapped`, але може викликатися при перестворенні сцени
- `init_room()` підключений до `room_loaded` через `CONNECT_DEFERRED`, що може викликатися кілька разів
- `Canyon._ready()` викликається кожного разу при завантаженні сцени Canyon

**Рішення:**
- ✅ Додано захист від повторного виклику `init_room()` для тієї ж кімнати
- ✅ Додано логування для діагностики перестворення гри
- ✅ Перевірка, чи `_ready()` викликається кілька разів
- ⚠️ Перевірити, чи `load_room()` не викликається кілька разів
- ⚠️ Перевірити, чи MetSys не емітує `room_loaded` кілька разів

## Рекомендовані виправлення

### 1. Додати позиціонування на SavePoint при поверненні до Canyon

**Файл:** `SampleProject/Scripts/Game.gd`

**ВАЖЛИВО:** Враховувати взаємодію з MetSys та RoomTransitions модулем!

```gdscript
func init_room():
	var room_instance = MetSys.get_current_room_instance()
	if is_instance_valid(room_instance):
		room_instance.adjust_camera_limits($Player/Camera2D)
	else:
		push_warning("Game: No RoomInstance found in current room!")
	
	# ВАЖЛИВО: Чекаємо, поки MetSys RoomTransitions модуль завершить позиціонування
	# MetSys використовує RoomTransitions.gd для обробки переходів між кімнатами
	await get_tree().process_frame
	await get_tree().process_frame
	
	player.on_enter()
	
	# ВАЖЛИВО: При поверненні до Canyon позиціонуємо гравця на SavePoint
	# Але тільки якщо це не автоматичний перехід через MetSys room connections
	var current_room = MetSys.get_current_room_name()
	if "Canyon" in current_room:
		# Перевіряємо, чи гравець повернувся з Village
		var game = Game.get_singleton()
		if game and game.get_quest_flag("village_left_complete", false):
			# Перевіряємо, чи MetSys вже позиціонував гравця
			# Якщо позиція далеко від SavePoint, позиціонуємо на SavePoint
			var save_points = get_tree().get_nodes_in_group("save_points")
			if save_points.size() > 0:
				var save_point = save_points[0]
				var distance_to_save_point = player.global_position.distance_to(save_point.global_position)
				# Якщо гравець далеко від SavePoint (більше 500 пікселів), позиціонуємо на SavePoint
				if distance_to_save_point > 500:
					_position_player_at_save_point()
					# Оновлюємо MetSys позицію
					MetSys.set_player_position(player.position)
	
	# Initializes MetSys.get_current_coords(), so you can use it from the beginning.
	if MetSys.last_player_position.x == Vector2i.MAX.x:
		MetSys.set_player_position(player.position)
```

### 2. Перевірити, чи немає автоматичного переходу при стані RELIC_PICKUP

**Файл:** `SampleProject/Scripts/Gameplay/Scenes/Canyon.gd`

Переконатися, що стан `RELIC_PICKUP` не викликає автоматичний перехід до Village.

### 3. Додати захист від повторного виклику `init_room()`

**Файл:** `SampleProject/Scripts/Game.gd`

**ВАЖЛИВО:** MetSys може викликати `init_room()` кілька разів через `room_loaded` сигнал! Також гра може перестворюватися!

**✅ ВИПРАВЛЕНО:**
- Додано захист від повторного виклику `init_room()` для тієї ж кімнати
- Додано лічильник викликів для діагностики
- Додано детальне логування позицій гравця
- Додано позиціонування на SavePoint при поверненні до Canyon
- Додано перевірку відстані до SavePoint перед позиціонуванням

```gdscript
var _init_room_called_for_room: String = ""
var _init_room_call_count: int = 0

func init_room():
	_init_room_call_count += 1
	var current_room = MetSys.get_current_room_name()
	
	# Захист від повторного виклику для тієї ж кімнати
	if _init_room_called_for_room == current_room:
		DebugLogger.warning("Game: ⚠️ init_room() вже викликано для кімнати %s (виклик #%d), пропускаємо" % [current_room, _init_room_call_count], "Game")
		return
	
	_init_room_called_for_room = current_room
	DebugLogger.info("Game: ✅ init_room() викликано для кімнати %s (виклик #%d)" % [current_room, _init_room_call_count], "Game")
	
	# ... решта логіки з позиціонуванням на SavePoint
```

### 4. Додати логування для діагностики

Додати детальне логування в:
- `Game.init_room()` - позиція гравця до та після позиціонування
- `Player.on_enter()` - збережена позиція
- `Canyon._determine_initial_state()` - визначений стан
- MetSys room loading - позиція, яку використовує MetSys

## Діагностика перестворення гри

**ВАЖЛИВО:** Перевірте, чи гра перестворюється!

### Перевірка в логах:

1. **Якщо бачите:**
   ```
   Game: ⚠️ _ready() вже викликано (_bootstrapped=true), пропускаємо ініціалізацію
   Game: ⚠️ ЦЕ МОЖЕ БУТИ ПРИЧИНОЮ ПОДВІЙНОЇ ТЕЛЕПОРТАЦІЇ - гра перестворюється!
   ```
   **Це означає:** Гра перестворюється, `Game._ready()` викликається кілька разів!

2. **Якщо бачите:**
   ```
   Game: ⚠️ init_room() вже викликано для кімнати X (виклик #2), пропускаємо
   ```
   **Це означає:** `init_room()` викликається кілька разів для тієї ж кімнати!

3. **Якщо бачите:**
   ```
   Canyon: ========== _ready() ВИКЛИКАНО ==========
   ```
   **Кілька разів** - це означає, що сцена Canyon перестворюється!

### Для діагностики проблеми додайте логування з урахуванням всіх аддонів:

```gdscript
# В Game.init_room()
DebugLogger.info("Game: init_room() викликано, поточна позиція гравця: %s" % player.global_position, "Game")
DebugLogger.info("Game: MetSys.last_player_position: %s" % MetSys.last_player_position, "Game")
DebugLogger.info("Game: Поточна кімната: %s" % MetSys.get_current_room_name(), "Game")
DebugLogger.info("Game: MetSys.current_room: %s" % (MetSys.get_current_room_instance().name if MetSys.get_current_room_instance() else "null"), "Game")

# В Player.on_enter()
DebugLogger.info("Player: on_enter() викликано, reset_position = %s, position = %s" % [reset_position, position], "Player")

# В Canyon._determine_initial_state()
DebugLogger.info("Canyon: _determine_initial_state() викликано, village_left_complete = %s" % game.get_quest_flag("village_left_complete", false), "Canyon")

# Перевірка SavePoint
var save_points = get_tree().get_nodes_in_group("save_points")
DebugLogger.info("Game: Знайдено SavePoint'ів: %d" % save_points.size(), "Game")
if save_points.size() > 0:
	DebugLogger.info("Game: Перший SavePoint позиція: %s" % save_points[0].global_position, "Game")
```

### Перевірка MetSys модулів:

```gdscript
# Перевірка, який модуль використовується для переходів
var modules = MetSys.get_modules()
DebugLogger.info("Game: MetSys модулі: %s" % str(modules), "Game")
```

### ⚠️ ВАЖЛИВО: DebugLogger рівень логування

**Проблема:** DebugLogger за замовчуванням має рівень `WARNING`, тому `DebugLogger.info()` не виводиться в консоль!

**Рішення:** 
- ✅ Додано `print()` для критичних повідомлень (завжди виводяться)
- ✅ Залишено `DebugLogger.info()` для сумісності
- ⚠️ Можна змінити рівень: `DebugLogger.set_level(DebugLogger.LogLevel.INFO)`

**Повідомлення, які завжди виводяться:**
- `✅ [Game] _ready() викликано вперше` - нормальний запуск
- `⚠️ [Game] _ready() вже викликано` - гра перестворюється!
- `✅ [Game] init_room() викликано для кімнати X` - нормальне завантаження
- `⚠️ [Game] init_room() вже викликано` - повторний виклик!
- `🚪 [Game] load_room() викликано #N` - завантаження кімнати
- `⚠️ [Game] load_room() викликано ДРУГИЙ РАЗ` - повторне завантаження!

## Наступні кроки

1. ✅ Додати логування для діагностики (з урахуванням всіх аддонів)
2. ✅ Перевірити, чи правильно встановлюється позиція при завантаженні кімнати (MetSys + RoomTransitions)
3. ✅ Додати позиціонування на SavePoint при поверненні до Canyon (з урахуванням MetSys)
4. ✅ Перевірити, чи немає автоматичного переходу при стані RELIC_PICKUP
5. ✅ Додати захист від повторного виклику `init_room()` (з урахуванням MetSys сигналів)
6. ✅ Перевірити взаємодію з RoomTransitions модулем MetSys
7. ✅ Перевірити, чи SceneManager не конфліктує з MetSys при позиціонуванні
8. ✅ Перевірити, чи SaveSystem правильно відновлює позицію при переходах
