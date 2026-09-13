# ✅ MetSys автоматичні переходи - Як це працює

## 🎯 Головне правило

**MetSys вже обробляє ВСІ переходи між кімнатами автоматично!**

Ви НЕ потрібно викликати `Game.load_room()` вручну в Scene Managers.

## 🔄 Як працює MetSys

### 1. **Room Connections (Налаштування в MetSys Editor)**

MetSys використовує **room connections** для визначення, які кімнати з'єднані:

```
Canyon (room_id: :d2qxq8pgs28p4)
  ↓ border connection (Right)
Village (room_id: :village_room_id)
```

### 2. **Автоматичне виявлення переходу**

Коли гравець доходить до межі кімнати (border):
1. MetSys виявляє, що гравець перетнув border
2. Перевіряє room connections для поточної кімнати
3. Знаходить з'єднану кімнату
4. **Автоматично викликає `load_room()` для наступної кімнати**
5. Позиціонує гравця в правильній позиції
6. Емітує сигнал `room_loaded`

### 3. **Що робить Scene Manager**

Scene Manager тільки:
- ✅ Керує станом сцени (State Machine)
- ✅ Запускає діалоги
- ✅ Встановлює об'єктиви
- ✅ Відкриває/закриває ворота
- ❌ **НЕ викликає `Game.load_room()`** - це робить MetSys автоматично!

## 🚫 Чому ручні переходи були проблемою?

### **Конфлікт між ручними та автоматичними переходами:**

```
Гравець доходить до межі кімнати
  ↓
MetSys виявляє перехід → викликає load_room("NextRoom.tscn")
  ↓
Scene Manager також викликає load_room("NextRoom.tscn")  ← КОНФЛІКТ!
  ↓
Результат: подвійна телепортація, неправильне позиціонування
```

### **Приклад проблеми:**

```gdscript
# ❌ Погано - ручний перехід конфліктує з MetSys
func _on_to_desert_road_state() -> void:
    Game.get_singleton().load_room("DesertRoad.tscn")  # Конфлікт!
    # MetSys ТАКОЖ викликає load_room() автоматично → подвійна телепортація
```

## ✅ Правильний підхід

### **Scene Manager тільки керує станом:**

```gdscript
# ✅ Добре - тільки керування станом, MetSys обробляє перехід
func _on_to_desert_road_state(run_id: int) -> void:
    # Запускаємо катсцену (якщо потрібно)
    await _play_dialogue("Canyon_ExitCutscene", run_id)
    
    # Встановлюємо об'єктив
    _set_objective("Спуститися до дороги")
    
    # НЕ викликаємо Game.load_room() - MetSys обробить перехід автоматично!
    # Гравець йде до межі кімнати → MetSys виявляє room connection → автоматичний перехід
```

## 🎮 Як налаштувати автоматичні переходи

### **Крок 1: Налаштуйте Room Connections в MetSys**

1. Відкрийте MetSys Editor (або налаштуйте через MapData)
2. Для кожної пари кімнат налаштуйте connection:
   ```
   Canyon → Village:
     - Border: Right (гравець йде вправо)
     - Coordinates: (x, y) - координати переходу
   
   Canyon → DesertRoad:
     - Border: Down (гравець спускається вниз)
     - Coordinates: (x, y) - координати переходу
   ```

### **Крок 2: Переконайтеся, що ворота відкриті**

```gdscript
# Canyon.gd
func _update_gates_for_state(state: State) -> void:
    match state:
        State.TO_VILLAGE:
            gate_exit.open_gate()  # Ворота до Village відкриті
            # Гравець може пройти → MetSys обробить перехід автоматично
        
        State.TO_DESERT_ROAD:
            gate_inner.open_gate()  # Ворота до дороги відкриті
            # Гравець може пройти → MetSys обробить перехід автоматично
```

### **Крок 3: НЕ викликайте Game.load_room() в Scene Managers**

```gdscript
# ❌ НЕ робіть це:
func advance_state() -> void:
    if current_state == State.TRANSITION_TO_CITY:
        Game.get_singleton().load_room("CityGates.tscn")  # НЕ ПОТРІБНО!

# ✅ Робіть це:
func advance_state() -> void:
    if current_state == State.TRANSITION_TO_CITY:
        _set_objective("Дійти до воріт міста")
        # MetSys обробить перехід автоматично через room connections
```

## 📊 Порівняння

| Підхід | Хто обробляє перехід | Коли використовувати |
|--------|---------------------|---------------------|
| **MetSys Room Connections** | MetSys автоматично | ✅ Звичайні переходи між кімнатами (99% випадків) |
| **Game.load_room()** | Вручну через код | ⚠️ Тільки для спеціальних випадків (телепорт, катсцена) |

## 🎯 Висновок

**MetSys вже обробляє переходи автоматично!**

Ви НЕ потрібно:
- ❌ Викликати `Game.load_room()` в Scene Managers
- ❌ Створювати ручні функції переходів
- ❌ Додавати логіку переходів в Scene Managers

Ви ПОВИННІ:
- ✅ Налаштувати room connections в MetSys Editor
- ✅ Відкривати/закривати ворота в залежності від стану сцени
- ✅ Встановлювати об'єктиви для гравця
- ✅ Дозволити MetSys обробляти переходи автоматично

**Просто налаштуйте room connections в MetSys, і все працюватиме автоматично!**
