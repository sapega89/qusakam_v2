extends RefCounted

## Кидки бою (D393): крит удару героя (PlayerCombat.hit_damage) і його ухилення (Player.mitigated_damage).
## Один генератор на гру, засіяний випадково; тест засіває його CALM_SEED — тоді перші CALM_ROLLS кидків не
## нижчі за CALM_FLOOR, і за звичайних шансів (Agility 0, спритність 10: крит 7 %, ухилення 5 %) жоден не
## спрацює: verify_combat_flow / verify_souls_combat лишаються точними. Тест, що кине більше, бачить це в rolls.

const CALM_SEED := 451095
const CALM_ROLLS := 150
const CALM_FLOOR := 0.1

static var rng := RandomNumberGenerator.new()
## Скільки кидків зроблено від останнього calm() — тест перевіряє, що не вийшов за CALM_ROLLS.
static var rolls: int = 0


## Випало з імовірністю [param chance] (0–1).
static func roll(chance: float) -> bool:
	rolls += 1
	return rng.randf() < chance


## Тест: кидки знову з CALM_SEED.
static func calm() -> void:
	rng.seed = CALM_SEED
	rolls = 0
