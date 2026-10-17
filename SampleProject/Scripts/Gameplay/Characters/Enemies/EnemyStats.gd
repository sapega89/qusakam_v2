extends Resource
class_name EnemyStats

## Resource для зберігання статистики ворога
## Використовується для уніфікації всіх типів ворогів (Melee, Tank, Fast, Ranged)

@export_group("Basic Info")
@export var enemy_type: String = "default"

@export_group("Movement")
@export var speed: float = 70.0

@export_group("Combat")
@export var base_damage: float = 10.0
@export var attack_cooldown: float = 1.5
## D198 (мок): замах перед ударом, потім хітбокс у бік погляду живий attack_active_time секунд.
@export var attack_windup: float = 0.4
@export var attack_active_time: float = 0.2

@export_group("Detection")
@export var detection_range: float = 300.0
@export var attack_range: float = 100.0
@export var chase_range: float = 400.0

@export_group("Health")
@export var max_health: int = 100
