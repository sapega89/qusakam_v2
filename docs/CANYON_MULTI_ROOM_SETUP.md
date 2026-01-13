# Настройка нескольких RoomInstance в Canyon.tscn

## ⚠️ Важно: Текущая ситуация

**Каньон сейчас состоит из более чем 4 сцен/комнат в MetSys.**

Это означает, что каньон уже разделен на несколько зон в Metroidvania System. Нужно проверить настройки MetSys Editor, чтобы увидеть все комнаты каньона.

## Структура (рекомендуемая)

Одна сцена `Canyon.tscn` с 2-3 RoomInstance для разных зон:

1. **RoomInstance_Start** - начало каньона (INTRO, MONOLOGUE, EXPLORATION)
2. **RoomInstance_Meditation** - место медитации (CUTSCENE_ABDUCTION)
3. **RoomInstance_Relic** - крайняя сцена каньона, место реликвии (RELIC_PICKUP)
   - Обладунки находятся у края каньона, перед выходом в пустыню

## Шаги настройки

### 1. Добавить RoomInstance в сцену

В Godot Editor:
1. Открыть `SampleProject/Maps/Canyon.tscn`
2. Добавить несколько `RoomInstance` из `addons/MetroidvaniaSystem/Nodes/RoomInstance.tscn`
3. Переименовать их:
   - `RoomInstance_Start`
   - `RoomInstance_Meditation`
   - `RoomInstance_Relic`

### 2. Настроить позиции RoomInstance

**RoomInstance_Start:**
- Position: (0, 0)
- room_id: "canyon_start" (в MetSys Editor)

**RoomInstance_Meditation:**
- Position: (2000, 0) - правее начала
- room_id: "canyon_meditation"

**RoomInstance_Relic:**
- Position: (4000, 0) - крайняя сцена каньона (у выхода в пустыню)
- room_id: "canyon_relic" или "canyon_end" или "canyon_exit"
- Обладунки находятся здесь, у края каньона

### 3. Добавить SavePoint'ы для каждой зоны

**SavePoint_Start:**
- Position: (100, 300)
- Группа: "save_points"
- Для спавна в начале игры

**SavePoint_Meditation:**
- Position: (2100, 300)
- Группа: "save_points"
- Для спавна после возврата из деревни (опционально)

**SavePoint_Relic:**
- Position: (4100, 300)
- Группа: "save_points"
- Для спавна при возврате за реликвией

### 4. Добавить RelicArmor (обладунки)

**RelicArmor:**
- Position: (4200, 300) - у края каньона, перед выходом в пустыню
- Script: `SampleProject/Scripts/Gameplay/RelicArmor.gd`
- dialogue_id: "RelicArmor_Examine"
- CollisionShape2D: CircleShape2D (radius: 50)
- **Важно:** Разместить в крайней сцене каньона, у выхода в пустыню

### 5. Добавить триггеры зон

**AbductionZoneTrigger:**
- Position: (1900, 300) - перед RoomInstance_Meditation
- Script: `SampleProject/Scripts/Gameplay/AbductionZoneTrigger.gd`
- Для активации катсцены при входе в зону

### 6. Настроить переходы между зонами

Можно использовать:
- **Portal'ы** - для автоматических переходов
- **Area2D триггеры** - для ручного управления переходами
- **Прямое перемещение** - игрок просто идет между зонами

## Важно о MetSys

⚠️ **MetSys использует только один RoomInstance как `current_room`**

При переходе между зонами нужно обновлять:
```gdscript
# В Canyon.gd при переходе между зонами
func _switch_to_room_instance(room_instance: Node2D) -> void:
    if room_instance is RoomInstance:
        MetSys.current_room = room_instance
        DebugLogger.info("Canyon: Switched to room %s" % room_instance.room_id, "Canyon")
```

## Пример структуры Canyon.tscn

```
Canyon (Node2D)
├── TileMap
│   ├── Foreground
│   └── Gate
├── RoomInstance_Start (room_id: "canyon_start")
├── RoomInstance_Meditation (room_id: "canyon_meditation")
├── RoomInstance_Relic (room_id: "canyon_relic")
├── SavePoint_Start
├── SavePoint_Relic
├── AbductionZoneTrigger
├── RelicArmor
└── [другие объекты]
```

## Проверка

После настройки проверить:
1. ✅ Игрок спавнится на SavePoint_Start при новой игре
2. ✅ При входе в AbductionZoneTrigger запускается катсцена
3. ✅ При нажатии E на RelicArmor запускается диалог
4. ✅ При возврате из деревни игрок спавнится на SavePoint_Relic
5. ✅ Переходы между зонами работают корректно
