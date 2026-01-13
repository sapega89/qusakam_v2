# Рекомендации по структуре каньона и спавну персонажа

## Как MetSys работает со спавном персонажа

### Текущая реализация:

1. **SavePoint для спавна:**
   - SavePoint добавляется в группу `"save_points"`
   - `Game._position_player_at_save_point()` ищет первый SavePoint из группы
   - При новой игре игрок спавнится на позиции SavePoint
   - SavePoint имеет `spawn_offset` для настройки точной позиции

2. **RoomInstance для MetSys:**
   - Каждая сцена должна иметь RoomInstance (из `addons/MetroidvaniaSystem/Nodes/RoomInstance.tscn`)
   - RoomInstance хранит `room_id` и `cells` для интеграции с MetSys
   - RoomInstance должен быть на позиции (0, 0) в сцене

3. **Позиционирование:**
   ```gdscript
   # В Game.gd
   func _position_player_at_save_point() -> void:
       var save_points = get_tree().get_nodes_in_group("save_points")
       if save_points.size() > 0:
           var save_point = save_points[0]
           player.global_position = save_point.position
           MetSys.set_player_position(player.position)
   ```

## ⚠️ Текущая ситуация

**Каньон уже состоит из более чем 4 сцен/комнат в MetSys.**

Это означает, что структура каньона уже разделена на несколько зон. Нужно:
1. Проверить MetSys Editor для просмотра всех комнат каньона
2. Определить, какие сцены используются
3. Решить: использовать существующую структуру или объединить

## Рекомендации по структуре каньона

### Вариант 1: Одна сцена с несколькими SavePoint'ами (если объединяем)

**Структура:**
- `Canyon.tscn` - одна большая сцена
- Несколько SavePoint'ов с разными именами:
  - `SavePoint_Start` - начало игры (монолог, изучение)
  - `SavePoint_Meditation` - место медитации (катсцена)
  - `SavePoint_Relic` - место реликвии (возврат из деревни)

**Плюсы:**
- Проще в управлении
- Одна карта для MetSys
- Легче настраивать переходы

**Минусы:**
- Большая сцена может быть сложной для навигации
- Нужно управлять состоянием через Canyon.gd

### Вариант 2: Разделить на несколько сцен (рекомендуется)

**Структура:**
1. **Canyon_Start.tscn** - Начало игры
   - SavePoint: `SavePoint_Start` (позиция начала)
   - Состояния: INTRO, MONOLOGUE, EXPLORATION
   - RoomInstance с room_id: "canyon_start"

2. **Canyon_Meditation.tscn** - Место медитации
   - SavePoint: `SavePoint_Meditation` (позиция медитации)
   - Состояния: CUTSCENE_ABDUCTION, TO_VILLAGE
   - RoomInstance с room_id: "canyon_meditation"
   - Триггер зоны для катсцены

3. **Canyon_Relic.tscn** - Место реликвии
   - SavePoint: `SavePoint_Relic` (позиция реликвии)
   - Состояния: RELIC_PICKUP, TO_DESERT_ROAD
   - RoomInstance с room_id: "canyon_relic"
   - Объект реликвии для подбора

**Плюсы:**
- Четкое разделение ответственности
- Легче управлять состояниями
- Каждая сцена имеет свою точку спавна
- Проще настраивать переходы между частями

**Минусы:**
- Нужно настраивать переходы между сценами
- Больше файлов для управления

## Настройка SavePoint для разных состояний

### Для Canyon_Start.tscn:
```gdscript
# SavePoint_Start
position = Vector2(100, 300)  # Начальная позиция
spawn_offset = Vector2(0, -20)  # Небольшой offset
```

### Для Canyon_Meditation.tscn:
```gdscript
# SavePoint_Meditation
position = Vector2(500, 300)  # Позиция места медитации
spawn_offset = Vector2(0, -20)
```

### Для Canyon_Relic.tscn:
```gdscript
# SavePoint_Relic
position = Vector2(800, 300)  # Позиция реликвии
spawn_offset = Vector2(0, -20)
```

## Настройка переходов между сценами

### Использование Portal для переходов:

1. **Из Canyon_Start в Canyon_Meditation:**
   - Portal в Canyon_Start.tscn
   - Target: "canyon_meditation"
   - Position: правая граница сцены

2. **Из Canyon_Meditation в Village:**
   - Portal в Canyon_Meditation.tscn
   - Target: "village"
   - Position: выход из каньона

3. **Из Village обратно в Canyon_Relic:**
   - Portal в Village.tscn
   - Target: "canyon_relic"
   - Position: вход в каньон

4. **Из Canyon_Relic в DesertRoad:**
   - Portal в Canyon_Relic.tscn
   - Target: "desert_road"
   - Position: выход из каньона

## Вариант 3: Несколько RoomInstance в одной сцене (РЕКОМЕНДУЕТСЯ)

**Структура:**
- `Canyon.tscn` - одна сцена с несколькими RoomInstance
- 2-3 RoomInstance для разных зон каньона:
  - `RoomInstance_Start` - начало (room_id: "canyon_start")
  - `RoomInstance_Meditation` - место медитации (room_id: "canyon_meditation")
  - `RoomInstance_Relic` - место реликвии (room_id: "canyon_relic")

**Плюсы:**
- Одна сцена для управления
- Несколько зон в одной карте
- Легче настраивать переходы между зонами
- Можно использовать один скрипт Canyon.gd

**Минусы:**
- Нужно правильно настроить позиции RoomInstance
- MetSys может использовать только один RoomInstance как current_room

### Настройка нескольких RoomInstance:

```gdscript
# В Canyon.tscn:
# RoomInstance_Start на позиции (0, 0) - начало каньона
# RoomInstance_Meditation на позиции (2000, 0) - место медитации
# RoomInstance_Relic на позиции (4000, 0) - место реликвии
```

**Важно:** MetSys использует только один RoomInstance как `current_room`. При переходе между зонами нужно обновлять `MetSys.current_room`.

## Интерактивные объекты

### RelicArmor - Обладунки/Реліквія

**Файл:** `SampleProject/Scripts/Gameplay/RelicArmor.gd`

**Функционал:**
- Показывает подсказку "Натисніть E щоб оглянути обладунки" при приближении
- Запускает диалог `RelicArmor_Examine.dqd` при нажатии E
- Можно использовать несколько раз или только один раз

**Использование:**
1. Добавить Area2D в сцену
2. Присвоить скрипт `RelicArmor.gd`
3. Настроить `dialogue_id` (по умолчанию "RelicArmor_Examine")
4. Добавить CollisionShape2D для области взаимодействия

## Рекомендация

**Если каньон уже разделен на несколько сцен в MetSys:**
- Использовать существующую структуру
- Добавить RelicArmor в сцену с реликвией
- Настроить SavePoint'ы для каждой сцены
- Обновить Canyon.gd для работы с несколькими сценами

**Если нужно объединить в одну сцену:**
- Использовать Вариант 3 (несколько RoomInstance в одной сцене)
- Упрощение управления (одна сцена)
- Разделение на зоны через RoomInstance
- Легкая настройка переходов
- Использование интерактивных объектов (RelicArmor)

## Следующие шаги

1. ✅ Создать `RelicArmor.gd` для интерактивных обладунков
2. ✅ Создать диалог `RelicArmor_Examine.dqd`
3. Обновить `Canyon.tscn` с несколькими RoomInstance:
   - RoomInstance_Start (начало)
   - RoomInstance_Meditation (место медитации)
   - RoomInstance_Relic (место реликвии)
4. Добавить RelicArmor в зону реликвии
5. Настроить SavePoint'ы для каждой зоны
6. Настроить переходы между зонами через Portal'ы или Area2D
