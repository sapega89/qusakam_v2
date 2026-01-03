# Настройка Collision Layers для боевой системы

## Рекомендуемые настройки в Project Settings

Откройте Project → Project Settings → Layer Names → 2D Physics

### Layer Names (2D Physics):

1. **Layer 1**: `Player` - для физической коллизии игрока
2. **Layer 2**: `Enemies` или `Hurtboxes` - для врагов и зон получения урона
3. **Layer 3**: `Environment` - для окружения (стены, платформы)
4. **Layer 4**: `Hitboxes` - для зон нанесения урона

### Настройка групп узлов

Откройте Project → Project Settings → Groups

Добавьте следующие группы:
- `player` - для игрока
- `enemies` - для врагов
- `health_bar` - для HP баров
- `ui_elements` - для UI элементов

## Применение к нодам

### Player CollisionShape2D:
- **Layer**: 1 (Player)
- **Mask**: 1 (Player) + 3 (Environment) = 5

### Player Hurtbox (Area2D):
- **Layer**: 2 (Hurtboxes)
- **Mask**: 4 (Hitboxes)
- **Monitoring**: true
- **Monitorable**: true

### Player Hitbox (Area2D):
- **Layer**: 4 (Hitboxes)
- **Mask**: 2 (Hurtboxes)
- **Monitoring**: true
- **Monitorable**: false

### Enemy CollisionShape2D:
- **Layer**: 2 (Enemies)
- **Mask**: 2 (Enemies) + 3 (Environment) = 6

### Enemy Hurtbox (Area2D):
- **Layer**: 2 (Hurtboxes)
- **Mask**: 4 (Hitboxes)
- **Monitoring**: true
- **Monitorable**: true

### Enemy Hitbox (Area2D):
- **Layer**: 4 (Hitboxes)
- **Mask**: 2 (Hurtboxes)
- **Monitoring**: true
- **Monitorable**: false

