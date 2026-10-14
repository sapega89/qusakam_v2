extends Sprite2D
class_name OldMan

## Дід у селі (D140, D145). У кат-сцені гравець лікує його «Дланню лікування»:
## на час цього кроку дід у групі allies — і SkillTargeting бере його ціллю (D142).

signal healed(amount: int)


func heal_damage(amount: int) -> void:
	healed.emit(amount)
