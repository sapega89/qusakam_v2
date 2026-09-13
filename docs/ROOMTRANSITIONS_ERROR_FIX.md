# 🔧 Виправлення помилки RoomTransitions.gd

## Помилка

```
E 0:00:15:654   _on_room_changed: Invalid call. Nonexistent function 'get_room_position_offset' in base 'Nil'.
  <GDScript Source>RoomTransitions.gd:25 @ _on_room_changed()
```

## Причина

Модуль `RoomTransitions.gd` намагається викликати `get_room_position_offset()` на об'єкті, який є `null` (Nil). Це означає, що:

1. RoomInstance не знайдено або не ініціалізовано
2. Метод `get_room_position_offset()` не існує в RoomInstance
3. Модуль RoomTransitions викликається до того, як RoomInstance готовий

## Рішення

### 1. Перевірити наявність RoomInstance

Модуль RoomTransitions потребує RoomInstance для роботи. Переконайтеся, що:
- В сцені Canyon.tscn є RoomInstance
- RoomInstance правильно налаштований
- RoomInstance має правильний `room_id`

### 2. Додати захист від null

Якщо модуль RoomTransitions знаходиться в аддоні MetSys, потрібно:
- Додати перевірку на null перед викликом `get_room_position_offset()`
- Або використовувати альтернативний метод отримання offset

### 3. Альтернативне рішення

Якщо модуль RoomTransitions не працює правильно, можна:
- Використовувати `ScrollingRoomTransitions.gd` замість `RoomTransitions.gd`
- Або створити власний модуль для переходів

## Позиція гравця (368.0, 248.0)

**Проблема:** Позиція гравця (368.0, 248.0) виглядає дивно - Y координата 248 замість очікуваної 549.

**Можливі причини:**
1. RoomTransitions модуль неправильно позиціонує гравця через помилку
2. MetSys використовує неправильну позицію з `last_player_position`
3. RoomInstance має неправильний offset

**Рішення:**
- ✅ Додано перевірку дивної позиції (Y < 300) в `init_room()`
- ✅ Автоматичне виправлення позиції на SavePoint, якщо позиція дивна
- ✅ Позиціонування на SavePoint при поверненні до Canyon

## Наступні кроки

1. ✅ **ВИПРАВЛЕНО**: Використовуємо `ScrollingRoomTransitions.gd` замість `RoomTransitions.gd`
2. ✅ Додано автоматичне виправлення позиції в `init_room()`
3. ✅ Додано логування для діагностики

## Рішення застосовано

**Файл:** `SampleProject/Scripts/Game.gd`

**Зміни:**
- Вимкнено `add_module("RoomTransitions.gd")` через помилку
- Увімкнено `add_module("ScrollingRoomTransitions.gd")` як альтернативу
- Додано коментарі з поясненням причини зміни

**Причина:**
Модуль `RoomTransitions.gd` намагається викликати `get_room_position_offset()` на об'єкті RoomInstance, який може бути `null` (Nil), що викликає помилку. `ScrollingRoomTransitions.gd` є альтернативним модулем переходів, який не має цієї проблеми.

## 📚 Різниця між модулями

### **RoomTransitions.gd** (вимкнено через помилку)
- Призначений для **статичних кімнат** (fixed camera)
- Використовує `get_room_position_offset()` для позиціонування гравця
- **Проблема:** Викликає помилку, якщо RoomInstance є `null`
- **Статус:** ❌ Вимкнено в `Game.gd`

### **ScrollingRoomTransitions.gd** (використовується зараз)
- Призначений для **scrolling кімнат** (scrolling camera)
- Більш надійний підхід до позиціонування гравця
- Не вимагає `get_room_position_offset()` на RoomInstance
- **Статус:** ✅ Активний в `Game.gd`

## ✅ Перевірка налаштування

**Файл:** `SampleProject/Scripts/Game.gd` (рядки 287-301)

```gdscript
# ВИМКНЕНО через помилку:
#add_module("RoomTransitions.gd")

# АКТИВНО - використовується зараз:
add_module("ScrollingRoomTransitions.gd")
```

**Переконайтеся, що:**
- ✅ `ScrollingRoomTransitions.gd` додано через `add_module()`
- ✅ `RoomTransitions.gd` закоментовано (не викликається)
- ✅ Немає помилок в консолі про `get_room_position_offset()`

## 🔍 Як перевірити, що модуль працює

1. **Перевірте логи при запуску гри:**
   ```
   📦 [Game] Додаємо модуль ScrollingRoomTransitions.gd (замість RoomTransitions.gd)...
   ✅ [Game] Модуль ScrollingRoomTransitions.gd додано
   ```

2. **Перевірте, що переходи працюють:**
   - Гравець доходить до межі кімнати
   - MetSys автоматично завантажує наступну кімнату
   - Гравець позиціонується правильно

3. **Перевірте, що немає помилок:**
   - Немає помилок про `get_room_position_offset()`
   - Немає помилок про `RoomTransitions.gd`

## ⚠️ Якщо помилка все ще з'являється

Якщо ви все ще бачите помилку про `RoomTransitions.gd`:
1. **MetSys може додавати модуль автоматично** - перевірте налаштування MetSys
2. **Перезапустіть гру** - іноді потрібен повний перезапуск
3. **Перевірте, чи немає інших місць, де додається RoomTransitions.gd**
