# Аналіз конфліктів між менеджерами

## Проблема
Гравець повертається до спавну, коли відпускає кнопку руху після переходу між кімнатами.

## Виявлені конфлікти

### 1. ScrollingRoomTransitions vs on_enter()
**Конфлікт:**
- `ScrollingRoomTransitions._on_room_changed()` змінює позицію гравця (`_player.position -= offset`, рядок 47)
- Потім викликається `game.load_room()`, що емітить `room_loaded`
- `init_room()` викликає `player.on_enter()`
- `on_enter()` встановлює `reset_position = position` на змінену позицію

**Рішення:**
- Додано затримку в `Game.gd` перед викликом `on_enter()` (2 кадри)
- Додано захист в `Player.gd` від занадто частого виклику `on_enter()`

### 2. SceneManager vs Game.gd
**Конфлікт:**
- `SceneManager` встановлює `player.global_position` під час переходів між сценами (рядок 433)
- `Game.gd` також встановлює позицію гравця через `init_room()` → `on_enter()`

**Статус:** Не критично, оскільки `SceneManager` працює з пролог-сценами, а `Game.gd` - з MetSys кімнатами

### 3. SaveSystem vs Player.on_enter()
**Конфлікт:**
- `SaveSystem` відновлює позицію гравця з збереження
- `on_enter()` встановлює `reset_position` на поточну позицію

**Статус:** Не критично, оскільки `SaveSystem` працює тільки при завантаженні гри

## Рекомендації

1. ✅ Додано затримку в `Game.gd` перед викликом `on_enter()`
2. ⚠️ Потрібно додати змінні в `Player.gd`:
   - `last_on_enter_time: float = 0.0`
   - `on_enter_cooldown: float = 0.5`
3. ⚠️ Потрібно оновити `on_enter()` для перевірки кулдауну

## Файли для редагування

1. `SampleProject/Scripts/Player.gd` - додати змінні та оновити `on_enter()`
2. `SampleProject/Scripts/Game.gd` - вже оновлено (додано затримку)
