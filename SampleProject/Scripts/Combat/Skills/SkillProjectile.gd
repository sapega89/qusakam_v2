extends Arrow

## Снаряд навички (v2 зріз 4, D874): Holy Javelin, Lightspear. Летить, як стріла героя (Arrow, D380–D381): по прямій
## уздовж погляду, крізь героя й NPC, застрягає в стіні; дальність, швидкість і прошивання — з SkillDefinition
## (projectile_range / _speed / _pierce, задає SkillCombatExecutor.throw). Влучання — удар навички, не стріли:
## SkillManager.projectile_hit (шкода навички, без SP за влучання, стан D207). Сцена: Scenes/Combat/skill_projectile.tscn.

var skill: SkillDefinition


## Стає біля руки героя-[member shooter], звідки лук пускає стрілу (PlayerCombat.ARROW_FROM).
func place_at_hand() -> void:
	global_position = shooter.global_position + shooter.visual_base + Vector2(PlayerCombat.ARROW_FROM.x * direction, PlayerCombat.ARROW_FROM.y)


func _strike(body: Node2D) -> void:
	_hit.append(body)
	ServiceLocator.get_skill_manager().projectile_hit(skill, shooter, body, damage)
	if not pierce:
		queue_free()
