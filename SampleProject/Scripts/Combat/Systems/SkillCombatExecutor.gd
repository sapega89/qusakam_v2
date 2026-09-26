extends RefCounted
class_name SkillCombatExecutor

## Виконавчий шар навичок: єдине місце, де навичка перетворюється на бойову дію.
##
## Свого пайплайну ушкоджень тут НЕМАЄ. Використовується той самий примітив,
## що й у звичайної атаки: HealthComponent.apply_damage() → CombatBody2D.take_damage()
## → EventBus. DamageApplier не залучається, бо він працює від зіткнення з хітбоксом,
## а навичка б'є по вже відомій цілі.
##
## SkillManager нічого не знає про бій і викликає лише execute().
## Формул ушкоджень немає ні тут, ні в SkillManager: значення береться з
## SkillDefinition.damage (конфігурація), а застосування — з наявної системи.

## Наносить ушкодження цілі. Повертає true, якщо ефект справді застосовано.
func execute(definition: SkillDefinition, source: Node, target: Node) -> bool:
	if definition == null or target == null:
		return false
	if definition.damage <= 0:
		# Навичка без прямого ушкодження — інші типи ефектів з'являться пізніше.
		return false
	if not is_instance_valid(target):
		return false

	var health := find_health_component(target)
	if health == null:
		return false
	if health.has_method("is_alive") and not health.is_alive():
		return false

	health.apply_damage(definition.damage, source)
	return true


## Пошук HealthComponent у цілі — та сама стратегія, що й у DamageApplier
## (сам вузол → батько → CombatBody2D), винесена сюди без зміни поведінки.
static func find_health_component(target: Node) -> HealthComponent:
	if target == null:
		return null
	for child in target.get_children():
		if child is HealthComponent:
			return child
	var parent := target.get_parent()
	if parent:
		for child in parent.get_children():
			if child is HealthComponent:
				return child
	return null
