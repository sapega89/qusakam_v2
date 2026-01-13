# StateChangeTrigger - Универсальный триггер для смены состояния и запуска диалогов

## Описание

`StateChangeTrigger` - это универсальный Area2D триггер, который можно вставлять в любую точку сцены для:
- Смены состояния в `Canyon.gd`
- Запуска диалогов
- Комбинации обоих действий

Полезен для создания точек перехода между состояниями и запуска диалогов в зависимости от позиции игрока.

## Использование

### 1. Добавление в сцену

1. Открыть сцену каньона в Godot Editor
2. Добавить `Area2D` → назвать `StateChangeTrigger` (или любое имя)
3. Присвоить скрипт: `SampleProject/Scripts/Gameplay/StateChangeTrigger.gd`
4. Добавить `CollisionShape2D` с нужной формой (RectangleShape2D, CircleShape2D и т.д.)
5. Разместить в нужной точке сцены

### 2. Настройка параметров

**State Change (Смена состояния):**

**target_state** (CanyonState enum):
- Состояние для перехода
- Доступные значения из enum:
  - `NONE` - не менять состояние
  - `INTRO` - начальное состояние
  - `MONOLOGUE` - монолог персонажа
  - `EXPLORATION` - изучение окружения
  - `CUTSCENE_ABDUCTION` - катсцена с уводом жителей
  - `TO_VILLAGE` - переход в деревню
  - `RELIC_PICKUP` - медитация возле обладунков
  - `EXIT_CUTSCENE` - катсцена спуска с каньона
  - `TO_DESERT_ROAD` - переход в пустыню
- По умолчанию: `NONE`

**require_state** (CanyonState enum):
- Требуемое текущее состояние (опционально)
- Если указано (не `NONE`), триггер сработает только если текущее состояние совпадает
- `NONE` = триггер сработает при любом состоянии
- По умолчанию: `NONE`

**Dialogue (Диалог):**

**dialogue_id** (String):
- ID диалога для запуска (имя файла без расширения)
- Пример: `"Canyon_Intro"`, `"Canyon_Monologue"`
- Файл должен находиться в `res://dialogue_quest/`

**dialogue_path** (String):
- Полный путь к .dqd файлу (опционально)
- Если указан, используется вместо `dialogue_id`
- Пример: `"res://dialogue_quest/Canyon_Intro.dqd"`
- Если не указан, используется `dialogue_id`

**Settings (Настройки):**

**action_mode** (ActionMode):
- Режим действия триггера:
  - `STATE_ONLY` - только смена состояния
  - `DIALOGUE_ONLY` - только запуск диалога
  - `BOTH` - и состояние, и диалог (по умолчанию)

**one_shot** (bool):
- Срабатывает только один раз (по умолчанию: `true`)
- Если `false`, триггер может сработать несколько раз

## Примеры использования

### Пример 1: Только смена состояния

```
StateChangeTrigger:
- Position: (500, 300)
- action_mode: STATE_ONLY
- target_state: MONOLOGUE (из enum)
- require_state: INTRO (из enum)
- one_shot: true
```

### Пример 2: Только запуск диалога

```
StateChangeTrigger:
- Position: (1000, 300)
- action_mode: DIALOGUE_ONLY
- dialogue_id: "Canyon_Intro"
- one_shot: true
```

### Пример 3: Смена состояния + диалог

```
StateChangeTrigger:
- Position: (1500, 300)
- action_mode: BOTH
- target_state: EXPLORATION (из enum)
- dialogue_id: "Canyon_Exploration"
- require_state: MONOLOGUE (из enum)
- one_shot: true
```

### Пример 4: Диалог с полным путем

```
StateChangeTrigger:
- Position: (2000, 300)
- action_mode: DIALOGUE_ONLY
- dialogue_path: "res://dialogue_quest/Canyon_Monologue.dqd"
- one_shot: true
```

## Доступные состояния

| Состояние | Описание |
|-----------|----------|
| `INTRO` | Начальное состояние - начало игры |
| `MONOLOGUE` | Монолог персонажа о деде и шамане |
| `EXPLORATION` | Изучение окружения |
| `CUTSCENE_ABDUCTION` | Катсцена с уводом жителей |
| `TO_VILLAGE` | Переход в деревню |
| `RELIC_PICKUP` | Медитация возле обладунков |
| `EXIT_CUTSCENE` | Катсцена спуска с каньона |
| `TO_DESERT_ROAD` | Переход в пустыню |

## Структура сцены

```
Canyon (Node2D)
├── RoomInstance
├── SavePoint
├── StateChangeTrigger_IntroToMonologue
│   ├── CollisionShape2D
│   ├── target_state: "MONOLOGUE"
│   └── require_state: "INTRO"
├── StateChangeTrigger_MonologueToExploration
│   ├── CollisionShape2D
│   ├── target_state: "EXPLORATION"
│   └── require_state: "MONOLOGUE"
└── [другие объекты]
```

## Важно

1. **CollisionShape2D обязателен** - без него триггер не будет работать
2. **Имена состояний чувствительны к регистру** - используйте заглавные буквы: `"EXPLORATION"`, а не `"exploration"`
3. **Проверка состояния** - если указан `require_state`, триггер сработает только при совпадении
4. **One shot** - по умолчанию триггер срабатывает только один раз

## Отладка

Если триггер не срабатывает:
1. Проверьте, что `CollisionShape2D` добавлен и настроен
2. Проверьте, что игрок входит в зону триггера
3. Проверьте `require_state` - возможно, текущее состояние не совпадает
4. Проверьте `one_shot` - возможно, триггер уже сработал
5. Проверьте логи в консоли - должны быть сообщения от StateChangeTrigger

## Методы Canyon.gd

Триггер использует методы:
- `change_state_by_name(state_name: String)` - изменение состояния
- `get_current_state_name() -> String` - получение текущего состояния
