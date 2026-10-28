extends RefCounted

## Рівень ворога за рівнем героя (D840): одна формула для звичайних, еліти й босів.
##   const EnemyScaling = preload("res://SampleProject/Scripts/Gameplay/EnemyScaling.gd")
##   EnemyScaling.scaled_level(room_level, hero_level, "elite")  # max(room_level, hero_level + 1), не вище MAX_LEVEL
## Рівень кімнати (RoomEnemySpawner.enemy_level, D670; у боса — рівень, під який зроблено його числа) — підлога:
## ворог ніколи не слабший за свій бій. Зсув виду — enemy_variety.json scaling.offsets.
## HP і шкода йдуть за рівнем через ті самі таблиці levels (EnemyVariety.level); досвід рівня не має (D670), тож
## маршрут качається так само, як до D840 (verify_xp_curve).

const EnemyVariety := preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
const KINDS: Array[String] = ["ordinary", "elite", "boss"]


## Рівень ворога виду [param kind] (KINDS) з підлогою [param room_level] для героя рівня [param hero_level].
static func scaled_level(room_level: int, hero_level: int, kind: String) -> int:
	var offset: int = int(EnemyVariety.data().scaling.offsets[kind])
	return clampi(maxi(room_level, hero_level + offset), 1, XPManager.MAX_LEVEL)


## Рівень героя зараз — від нього рахується рівень кожного ворога, що зʼявляється.
static func hero_level() -> int:
	return ServiceLocator.get_xp_manager().current_level


## Множники HP і шкоди боса, чиї числа зроблено під рівень [param authored_level], на рівні [param level]:
## відношення тих самих таблиць levels, тож бос росте разом зі звичайними ворогами.
static func boss_growth(authored_level: int, level: int) -> Dictionary:
	var at: Dictionary = EnemyVariety.level(authored_level)
	var now: Dictionary = EnemyVariety.level(level)
	return {"health": now.health / at.health, "damage": now.damage / at.damage}


## Рівень, під який зроблено числа боса [param enemy_type] (enemy_variety.json scaling.boss_levels) — його підлога.
static func boss_level(enemy_type: String) -> int:
	return int(EnemyVariety.data().scaling.boss_levels[enemy_type])
