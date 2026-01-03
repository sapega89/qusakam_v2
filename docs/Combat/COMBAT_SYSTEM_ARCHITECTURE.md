# Архітектура бойової системи для демо

## 1. Архітектура компонентів

### Інтерфейси (вже реалізовані)
- **IDamageable** - об'єкти, які можуть отримувати ушкодження
- **IDamageDealer** - об'єкти, які можуть наносити ушкодження
- **ICombatant** - комбінація обох (для бойових сутностей)

### Компоненти
- **HealthComponent** - управління здоров'ям (окремий компонент)
- **DamageApplier** - застосування ушкоджень (висить на Hitbox)
- **HurtboxComponent** - зона отримання ушкоджень

### Принципи
- Компоненти підвішуються через сцени (ноди розміщені вручну)
- Мінімальне логування (тільки критичні помилки)
- Використання існуючих інтерфейсів
- Розділення відповідальностей (SOLID)

---

## 2. Структура нод для Player

```
Player (PlayerController extends CombatBody2D)
├── Sprite2D / AnimatedSprite2D
├── CollisionShape2D (фізична колізія)
├── HealthComponent (Node)
│   └── (скрипт HealthComponent.gd)
├── Hurtbox (Area2D)
│   ├── CollisionShape2D
│   └── HurtboxComponent (Node зі скриптом)
├── Hitbox (Area2D) - для атаки
│   ├── CollisionShape2D
│   └── DamageApplier (Node зі скриптом)
└── AnimationPlayer / AnimationTree
```

### Налаштування колізій
- **Player CollisionShape2D**: Layer 1 (bit 0) - Player
- **Hurtbox**: Layer 2 (bit 1) - Hurtboxes, Mask 4 (bit 2) - Hitboxes
- **Hitbox**: Layer 4 (bit 2) - Hitboxes, Mask 2 (bit 1) - Hurtboxes

---

## 3. Структура нод для Enemy (MeleeEnemy)

```
MeleeEnemy (DefaultEnemy extends CombatBody2D)
├── Sprite2D / AnimatedSprite2D
├── CollisionShape2D (фізична колізія)
├── HealthComponent (Node)
│   └── (скрипт HealthComponent.gd)
├── Hurtbox (Area2D)
│   ├── CollisionShape2D
│   └── HurtboxComponent (Node зі скриптом)
├── Hitbox (Area2D) - для атаки
│   ├── CollisionShape2D
│   └── DamageApplier (Node зі скриптом)
└── AnimationPlayer / AnimationTree
```

### Налаштування колізій
- **Enemy CollisionShape2D**: Layer 2 (bit 1) - Enemies
- **Hurtbox**: Layer 2 (bit 1) - Hurtboxes, Mask 4 (bit 2) - Hitboxes
- **Hitbox**: Layer 4 (bit 2) - Hitboxes, Mask 2 (bit 1) - Hurtboxes

---

## 4. Collision Layers (рекомендовані)

```
Layer 1 (bit 0): Player
Layer 2 (bit 1): Enemies / Hurtboxes
Layer 3 (bit 2): Environment
Layer 4 (bit 2): Hitboxes
Layer 8 (bit 3): Dialogue Triggers
```

---

## 5. Інтеграція з анімаціями

### AnimationPlayer - Call Method Track

#### Крок 1: Відкрити анімацію
1. Виберіть AnimationPlayer
2. Відкрийте анімацію "attack" (або іншу бойову анімацію)
3. Додайте новий трек: **"Call Method Track"**

#### Крок 2: Налаштувати виклик enable_damage()
1. Виберіть трек "Call Method Track"
2. Клацніть правою кнопкою → "Insert Key"
3. Встановіть час, коли удар має спрацювати (наприклад, 0.2 секунди)
4. В Inspector:
   - **Method**: `enable_damage`
   - **Target Node**: `/Hitbox/DamageApplier` (шлях до DamageApplier)
   - **Args**: (залишити порожнім)

#### Крок 3: Налаштувати виклик disable_damage()
1. Додайте ще один ключ на тому ж треку
2. Встановіть час після завершення удару (наприклад, 0.5 секунди)
3. В Inspector:
   - **Method**: `disable_damage`
   - **Target Node**: `/Hitbox/DamageApplier`

### AnimationTree - Signals

Якщо використовуєте AnimationTree з StateMachine:

```gdscript
# В скрипті Player або Enemy додати:
func _ready():
    var animation_tree = $AnimationTree
    if animation_tree:
        # Підключаємося до сигналів StateMachine
        var state_machine = animation_tree.get("parameters/playback")
        if state_machine:
            # Додати сигнали в StateMachine через редактор
            # або підключити через код:
            state_machine.connect("state_changed", _on_state_changed)

func _on_state_changed(state_name: String):
    if state_name == "attack":
        # Знаходимо DamageApplier та увімкнути
        var damage_applier = $Hitbox/DamageApplier
        if damage_applier:
            damage_applier.enable_damage()
    elif state_name == "idle" or state_name == "walk":
        # Вимкнути при виході з атаки
        var damage_applier = $Hitbox/DamageApplier
        if damage_applier:
            damage_applier.disable_damage()
```

### Альтернатива: Animation Events через Timer

Якщо не використовуєте AnimationPlayer/AnimationTree:

```gdscript
# В скрипті Player/Enemy
func start_attack():
    var damage_applier = $Hitbox/DamageApplier
    if damage_applier:
        damage_applier.enable_damage()
        
        # Вимкнути через час (наприклад, 0.3 секунди)
        await get_tree().create_timer(0.3).timeout
        damage_applier.disable_damage()
```

---

## 6. Порядок ініціалізації

1. CombatBody2D._ready() - ініціалізує базові параметри
2. HealthComponent._ready() - підключається до CombatBody2D
3. HurtboxComponent._ready() - підключається до HealthComponent
4. DamageApplier._ready() - налаштовує посилання на власника

---

## 7. Приклад використання

### Player атакує Enemy
1. Player виконує атаку (AnimationPlayer)
2. На кадрі удару викликається `DamageApplier.enable_damage()`
3. Hitbox Area2D виявляє перетин з Enemy Hurtbox
4. DamageApplier викликає `HealthComponent.apply_damage()` на Enemy
5. Enemy HealthComponent оновлює здоров'я через CombatBody2D
6. Якщо здоров'я <= 0, викликається `die()`

### Enemy атакує Player
1. Enemy AI визначає атаку
2. Enemy AnimationPlayer відтворює атаку
3. На кадрі удару викликається `DamageApplier.enable_damage()`
4. Hitbox виявляє перетин з Player Hurtbox
5. DamageApplier викликає `HealthComponent.apply_damage()` на Player
6. Player отримує ушкодження та невразливість

