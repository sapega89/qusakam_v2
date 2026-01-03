# Гайд по налаштуванню бойової системи

## Покрокова інструкція для Player

### 1. Структура нод Player

```
Player (PlayerController)
├── Sprite2D / AnimatedSprite2D
├── CollisionShape2D (фізична колізія)
│   └── Shape: CapsuleShape2D або RectangleShape2D
├── HealthComponent (Node)
│   └── Script: HealthComponent.gd
│   └── Owner Body: .. (автоматично знайде Player)
├── Hurtbox (Area2D)
│   ├── CollisionShape2D
│   │   └── Shape: CapsuleShape2D (трохи більше ніж фізична колізія)
│   ├── HurtboxComponent (Node)
│   │   └── Script: HurtboxComponent.gd
│   │   └── Health Component: ../HealthComponent (встановити вручну)
│   └── Collision Layers:
│       └── Layer: 2 (bit 1) - Hurtboxes
│       └── Mask: 4 (bit 2) - Hitboxes
├── Hitbox (Area2D)
│   ├── CollisionShape2D
│   │   └── Shape: RectangleShape2D (розмір зони атаки)
│   ├── DamageApplier (Node)
│   │   └── Script: DamageApplier.gd
│   │   └── Base Damage: 25 (або інше значення)
│   │   └── Owner Body: ../.. (встановити вручну)
│   └── Collision Layers:
│       └── Layer: 4 (bit 2) - Hitboxes
│       └── Mask: 2 (bit 1) - Hurtboxes
└── AnimationPlayer / AnimationTree
```

### 2. Налаштування колізій Player

#### CollisionShape2D (фізична колізія)
- **Layer**: 1 (bit 0) - Player
- **Mask**: 3 (bit 0 + bit 1) - Player + Environment

#### Hurtbox (Area2D)
- **Layer**: 2 (bit 1) - Hurtboxes
- **Mask**: 4 (bit 2) - Hitboxes
- **Monitoring**: true
- **Monitorable**: true

#### Hitbox (Area2D)
- **Layer**: 4 (bit 2) - Hitboxes
- **Mask**: 2 (bit 1) - Hurtboxes
- **Monitoring**: true (увімкнути через анімацію)
- **Monitorable**: false

### 3. Підключення скриптів

1. **HealthComponent**:
   - Створіть Node як дочірній ноду Player
   - Назвіть "HealthComponent"
   - Призначте скрипт `HealthComponent.gd`
   - Owner Body встановиться автоматично

2. **HurtboxComponent**:
   - Створіть Node як дочірній ноду Hurtbox
   - Назвіть "HurtboxComponent"
   - Призначте скрипт `HurtboxComponent.gd`
   - Health Component: встановіть посилання на `../HealthComponent`

3. **DamageApplier**:
   - Створіть Node як дочірній ноду Hitbox
   - Назвіть "DamageApplier"
   - Призначте скрипт `DamageApplier.gd`
   - Owner Body: встановіть посилання на `../..` (Player)
   - Base Damage: встановіть значення (наприклад, 25)

### 4. Інтеграція з анімаціями

#### Варіант A: AnimationPlayer Call Method Track

1. Відкрийте AnimationPlayer
2. Виберіть анімацію "attack"
3. Додайте трек "Call Method Track"
4. Додайте ключ на момент удару (наприклад, 0.2с):
   - Method: `enable_damage`
   - Target: `/Hitbox/DamageApplier`
5. Додайте ключ після удару (наприклад, 0.5с):
   - Method: `disable_damage`
   - Target: `/Hitbox/DamageApplier`

#### Варіант B: Через код

```gdscript
# В Player.gd
func start_attack():
    var damage_applier = $Hitbox/DamageApplier
    if damage_applier:
        damage_applier.enable_damage()
        await get_tree().create_timer(0.3).timeout
        damage_applier.disable_damage()
```

---

## Покрокова інструкція для Enemy (MeleeEnemy)

### 1. Структура нод Enemy

```
MeleeEnemy (DefaultEnemy)
├── Sprite2D / AnimatedSprite2D
├── CollisionShape2D (фізична колізія)
├── HealthComponent (Node)
│   └── Script: HealthComponent.gd
├── Hurtbox (Area2D)
│   ├── CollisionShape2D
│   ├── HurtboxComponent (Node)
│   │   └── Script: HurtboxComponent.gd
│   └── Collision Layers:
│       └── Layer: 2 (bit 1) - Hurtboxes
│       └── Mask: 4 (bit 2) - Hitboxes
├── Hitbox (Area2D)
│   ├── CollisionShape2D
│   ├── DamageApplier (Node)
│   │   └── Script: DamageApplier.gd
│   │   └── Base Damage: 10 (або інше значення)
│   └── Collision Layers:
│       └── Layer: 4 (bit 2) - Hitboxes
│       └── Mask: 2 (bit 1) - Hurtboxes
└── AnimationPlayer / AnimationTree
```

### 2. Налаштування колізій Enemy

Аналогічно до Player, але:
- **CollisionShape2D Layer**: 2 (bit 1) - Enemies
- Решта налаштувань такі ж

### 3. Підключення скриптів

Аналогічно до Player

### 4. Інтеграція з анімаціями Enemy

В `DefaultEnemy.gd` оновити `perform_attack()`:

```gdscript
func perform_attack():
    if get_tree().paused:
        return
    
    $AnimatedSprite2D.play("attack")
    
    # Увімкнути DamageApplier через анімацію або код
    var damage_applier = $Hitbox/DamageApplier
    if damage_applier:
        damage_applier.enable_damage()
        await get_tree().create_timer(0.3).timeout
        damage_applier.disable_damage()
```

---

## Перевірка роботи

### Тест 1: Player атакує Enemy
1. Запустіть сцену
2. Підійдіть до ворога
3. Натисніть кнопку атаки
4. Перевірте, чи ворог отримав ушкодження

### Тест 2: Enemy атакує Player
1. Запустіть сцену
2. Підійдіть до ворога
3. Дочекайтеся атаки ворога
4. Перевірте, чи гравець отримав ушкодження

### Тест 3: Перевірка невразливості
1. Запустіть сцену
2. Отримайте ушкодження
3. Перевірте, чи є невразливість після ушкодження
4. Перевірте, чи можна отримати ушкодження під час невразливості

---

## Troubleshooting

### Проблема: Ушкодження не застосовуються
- Перевірте, чи `DamageApplier.is_active == true` під час атаки
- Перевірте collision layers/masks
- Перевірте, чи `HurtboxComponent` знайшов `HealthComponent`

### Проблема: Ушкодження застосовуються кілька разів
- Перевірте, чи `hit_targets` в `DamageApplier` працює правильно
- Перевірте, чи `disable_damage()` викликається після атаки

### Проблема: Невразливість не працює
- Перевірте `invulnerability_timer` в `CombatBody2D`
- Перевірте, чи `is_invulnerable` встановлюється правильно

