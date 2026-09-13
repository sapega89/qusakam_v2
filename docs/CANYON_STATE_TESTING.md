# 🧪 Тестування Canyon State Prototype

## Огляд

Цей документ описує тести для перевірки компонентної архітектури управління стейтами сцени Canyon.

## Структура тестів

### Unit Tests (`test/unit/test_canyon_state_manager.gd`)

Тести окремих компонентів без залежностей:

1. **test_state_manager_initialization** - Перевірка ініціалізації стейт-менеджера
2. **test_state_mapping** - Перевірка маппінгу стейтів
3. **test_change_state_by_name** - Перевірка зміни стейту за назвою
4. **test_invalid_state_name** - Перевірка обробки невалідної назви стейту
5. **test_state_changed_signal** - Перевірка емітування сигналу state_changed
6. **test_interface_implementation** - Перевірка реалізації інтерфейсу ISceneStateManager
7. **test_dialogue_trigger_initialization** - Перевірка ініціалізації DialogueStateTrigger
8. **test_dialogue_trigger_reset** - Перевірка скидання тригера

### Integration Tests (`test/integration/test_canyon_dialogue_state_integration.gd`)

Тести інтеграції компонентів:

1. **test_dialogue_trigger_finds_state_manager** - Перевірка знаходження стейт-менеджера тригером
2. **test_state_change_after_dialogue_completion** - Перевірка зміни стейту після завершення діалогу
3. **test_require_state_validation** - Перевірка валідації require_state
4. **test_one_shot_behavior** - Перевірка поведінки one_shot

## Запуск тестів

### Через GUT в Godot Editor

1. Відкрити Godot Editor
2. Перейти на вкладку GUT
3. Вибрати тести:
   - `test/unit/test_canyon_state_manager.gd`
   - `test/integration/test_canyon_dialogue_state_integration.gd`
4. Натиснути "Run All" або "Run Selected"

### Через командний рядок

```bash
godot --path . -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_canyon_state_manager.gd
```

## Ручне тестування

### Тест 1: Перевірка зміни стейту через діалог

1. Запустити гру
2. Зайти в зону тригера `DialogueStateTrigger_Intro`
3. Перевірити в консолі:
   - Діалог запустився
   - Після завершення діалогу стейт змінився на MONOLOGUE
   - EventBus.scene_state_changed емітується з правильними параметрами

### Тест 2: Перевірка require_state

1. Встановити стейт на EXPLORATION (через консоль або код)
2. Зайти в зону тригера з `require_state: "INTRO"`
3. Перевірити, що тригер НЕ спрацював

### Тест 3: Перевірка one_shot

1. Зайти в зону тригера (діалог запустився)
2. Завершити діалог
3. Зайти в зону тригера знову
4. Перевірити, що тригер НЕ спрацював (one_shot=true)

## Очікувані результати

### Успішні тести

- ✅ Всі unit тести проходять
- ✅ Інтеграційні тести проходять (після налаштування систем)
- ✅ Стейт змінюється після завершення діалогу
- ✅ require_state працює правильно
- ✅ one_shot працює правильно

### Можливі проблеми

- ⚠️ DialogueManager не ініціалізовано - перевірити ServiceLocator
- ⚠️ Файли діалогів не знайдено - перевірити шляхи до .dqd файлів
- ⚠️ Стейт не змінюється - перевірити підключення сигналів

## Наступні кроки

1. Створити прототип сцени Canyon з компонентами
2. Додати всі DialogueStateTrigger для кожного діалогу
3. Протестувати зміну стейтів через діалоги вручну
4. Додати повні інтеграційні тести з реальними діалогами
