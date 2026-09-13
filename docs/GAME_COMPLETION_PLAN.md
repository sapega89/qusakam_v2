# 🎯 План завершення проходження гри

## Поточний стан

### Маршрут проходження (згідно GameFlow)

1. **CANYON** → Початок, перший бій, медитація
2. **VILLAGE** → Викрадення, битва з бандитом, лікування
3. **DESERT_ROAD** → Циклічні бої на дорозі
4. **CITY_GATES** → Ворота міста, фінальна битва перед лабою
5. **LABORATORY** → Лабораторія, компаньйони, бос
6. **LAB_OUTSIDE** → Вихід, фінал демо
7. **DEMO_END** → Екран завершення

## Проблеми, які потрібно вирішити

### 1. Переходи між сценами

- ❌ **Canyon → Village**: Потрібно перевірити перехід через Portal
- ❌ **Village → DesertRoad**: Потрібно перевірити перехід
- ❌ **DesertRoad → CityGates**: `_transition_to_next_scene()` тільки логує
- ❌ **CityGates → Laboratory**: `_transition_to_next_scene()` тільки логує
- ❌ **Laboratory → LaboratoryOutside**: Немає переходу
- ❌ **LaboratoryOutside → Demo End**: Немає екрану завершення

### 2. Відсутні діалоги

- ❌ **CityGates_AfterFight.dqd**: Не знайдено
- ❌ **Laboratory_AfterBoss.dqd**: Не знайдено
- ✅ **Demo_End.dqd**: Є, але дуже короткий

### 3. Фінальний екран

- ❌ Немає UI для завершення демо
- ❌ Немає переходу на головне меню після завершення

## План виправлення

### Крок 1: Реалізувати переходи між сценами

#### 1.1 DesertRoad → CityGates
```gdscript
func _transition_to_next_scene() -> void:
    var game = Game.get_singleton()
    if game:
        game.load_room("CityGates.tscn")
```

#### 1.2 CityGates → Laboratory
```gdscript
func _transition_to_next_scene() -> void:
    var game = Game.get_singleton()
    if game:
        game.load_room("Laboratory.tscn")
```

#### 1.3 Laboratory → LaboratoryOutside
Додати перехід після бос-файту

### Крок 2: Створити відсутні діалоги

#### 2.1 CityGates_AfterFight.dqd
Діалог після битви біля воріт міста

#### 2.2 Laboratory_AfterBoss.dqd
Діалог після перемоги над босом

### Крок 3: Створити фінальний екран

#### 3.1 DemoEndScreen.tscn
Сцена з:
- Текстом "Дякуємо за гру!"
- Кнопкою "Повернутися до головного меню"
- Можливо статистикою проходження

#### 3.2 DemoEndScreen.gd
Скрипт для управління екраном завершення

### Крок 4: Додати об'єктиви для гравця

На кожному етапі встановлювати об'єктив через `Game.set_objective()`

## Пріоритети

1. **Високий**: Реалізувати переходи між сценами
2. **Високий**: Створити фінальний екран
3. **Середній**: Створити відсутні діалоги
4. **Низький**: Додати об'єктиви (якщо є час)
