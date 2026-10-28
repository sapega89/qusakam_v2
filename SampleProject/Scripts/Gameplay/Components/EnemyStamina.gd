extends Node

## Витривалість ворога (D824, design/enemy_stamina_plan.md; Sapega 27.10: «треба, щоби у ворогів теж була стаміна»).
## Як у героя (PlayerStamina, D776): кожен удар серії, випад (D768), стрибок шакала (D769), піке й укус летючого, постріл
## лучника і хід боса коштують її в мить удару (EnemyLogic). Поки ворог не б'є, вона за [member delay] с починає
## набиратись по [member regen] за секунду. Не вистачає на наступний удар — ворог не б'є, а тримає відстань
## (EnemyLogic.handle_attack_state). Удар, що вичерпав шкалу, кінчає серію; після неї ворог видихається
## ([signal winded]: стоїть [member winded_time] с, відкритий, з тінню й позою збою, DefaultEnemy._on_winded) і знову б'є,
## лише набравши [member recover_at] від max. Бос: своя шкала без відновлення в бою (regen 0) — видихнувся, і після
## вікна вона знову повна, тож візерунок (D577) не пропускає й не переставляє жодного ходу. Числа — enemy_variety.json
## «stamina».

const EnemyVariety = preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")

## Шкала змінилась: [param current] з [param maximum]; [param exhausted] — вичерпана й ще не набрала recover_at.
signal changed(current: float, maximum: float, exhausted: bool)
## Ворог видихнувся на [param time] с (вікно для героя).
signal winded(time: float)

var max_stamina := 100.0
var current := 100.0
var regen := 35.0
var delay := 0.6
var winded_time := 0.9
## Частка max, з якої виснажений ворог знову б'є.
var recover_at := 0.4
## Ціни ударів за родом (swing, lunge, pounce; у боса — kind ходу), з даних.
var costs: Dictionary = {}
var exhausted := false
## Скільки ще стоїть видихнувшись.
var winded_left := 0.0
var _delay_left := 0.0
## Шкала вичерпалась у цьому ударі — після нього ворог видихнеться (take_winded).
var _winded_due := false


## Числа виду [param kind_id]; бос ([param boss]) — свій пул.
func setup(kind_id: String, boss: bool) -> void:
	var row := EnemyVariety.stamina(kind_id, boss)
	max_stamina = float(row.max)
	regen = float(row.regen) if not boss else 0.0
	delay = float(row.delay)
	winded_time = float(row.winded)
	recover_at = float(row.recover_at) if not boss else 1.0
	for key: String in row:
		if key not in ["max", "regen", "delay", "winded", "recover_at"]:
			costs[StringName(key)] = float(row[key])
	current = max_stamina


func cost(kind: StringName) -> float:
	return costs[kind]


## Вистачає на удар роду [param kind] (і ворог не виснажений).
func can_afford(kind: StringName) -> bool:
	return not exhausted and winded_left <= 0.0 and current >= cost(kind)


## Удар роду [param kind] у мить удару: списати; дійшла до нуля — виснажений, після удару видихнеться.
func spend(kind: StringName) -> void:
	var price := cost(kind)
	if price <= 0.0:
		return
	current = maxf(0.0, current - price)
	_delay_left = delay
	if current <= 0.0:
		exhausted = true
		_winded_due = true
	_emit()


## Удар скінчився: якщо він вичерпав шкалу — ворог видихається ([signal winded]). true — видихнувся.
func take_winded() -> bool:
	if not _winded_due:
		return false
	_winded_due = false
	winded_left = winded_time
	winded.emit(winded_time)
	_emit()
	return true


## Повна (ковток боса, D564).
func refill() -> void:
	current = max_stamina
	exhausted = false
	_winded_due = false
	_emit()


## Кадр бою; [param busy] — ворог б'є (тоді не набирається).
func tick(delta: float, busy: bool) -> void:
	if winded_left > 0.0:
		winded_left -= delta
		if winded_left <= 0.0 and regen <= 0.0:
			refill()  # бос: вікно минуло — знову повний, візерунок іде далі
		return
	if busy:
		_delay_left = delay
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current >= max_stamina or regen <= 0.0:
		return
	current = minf(max_stamina, current + regen * delta)
	if exhausted and current >= max_stamina * recover_at:
		exhausted = false
	_emit()


func _emit() -> void:
	changed.emit(current, max_stamina, exhausted)
