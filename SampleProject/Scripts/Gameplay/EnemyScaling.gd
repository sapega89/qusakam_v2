extends RefCounted

## Рівень ворога за рівнем героя (D840): одна формула для звичайних, еліти й босів — часткова (Sapega: «скейл мобів
## не великий, але має бути»):
##   рівень = рівень кімнати + зсув зони + зсув виду + ⌊max(0, герой − рівень кімнати) × HERO_LEAD_SHARE⌋, не вище MAX_LEVEL
##   const EnemyScaling = preload("res://SampleProject/Scripts/Gameplay/EnemyScaling.gd")
##   EnemyScaling.scaled_level(room_level, zone_offset, hero_level, "elite")
## Рівень кімнати (RoomEnemySpawner.enemy_level, D670; у боса — рівень, під який зроблено його числа) — підлога:
## ворог ніколи не слабший за свій бій. Зсув виду — enemy_variety.json scaling.offsets; зсув зони (Sapega: «є зони, які
## з самого початку складніші для рівня героя») — scaling.zone_offsets за кімнатою (імʼя сцени), решта кімнат 0.
## HP і шкода йдуть за рівнем через ті самі таблиці levels (EnemyVariety.level); досвід рівня не має (D670), тож
## маршрут качається так само, як до D840 (verify_xp_curve).

const EnemyVariety := preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
const KINDS: Array[String] = ["ordinary", "elite", "boss"]
## Яку частку відриву героя над рівнем кімнати ворог набирає (D840): перекачаність окупається, а старий край не стає
## тривіальним.
const HERO_LEAD_SHARE := 0.5


## Рівень ворога виду [param kind] (KINDS) з кімнати рівня [param room_level] і зсуву зони [param zone_offset] для героя
## рівня [param hero_level].
static func scaled_level(room_level: int, zone_offset: int, hero_level: int, kind: String) -> int:
	var offset: int = int(EnemyVariety.data().scaling.offsets[kind])
	var lead: int = floori(maxi(0, hero_level - room_level) * HERO_LEAD_SHARE)
	return clampi(room_level + zone_offset + offset + lead, 1, XPManager.MAX_LEVEL)


## Зсув зони кімнати [param room] — імʼя сцени без .tscn, як у locations.json (scaling.zone_offsets): необовʼязкові
## й важкі місця стоять вище свого рівня вже з першого приходу. Кімнати без запису — 0.
static func zone_offset(room: String) -> int:
	return int(EnemyVariety.data().scaling.zone_offsets.get(room, 0))


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
