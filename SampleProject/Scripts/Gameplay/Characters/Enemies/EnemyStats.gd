extends Resource
class_name EnemyStats

## Resource для зберігання статистики ворога
## Використовується для уніфікації всіх типів ворогів (Melee, Tank, Fast, Ranged)

@export_group("Basic Info")
@export var enemy_type: String = "default"

@export_group("Movement")
@export var speed: float = 70.0
## Під яку швидкість намальовано крок анімації walk, px/с (D767): темп walk — speed / stride_speed, щоб ноги не ковзали,
## коли ворог ходить швидше. 0 — та сама, що speed.
@export var stride_speed: float = 0.0

@export_group("Combat")
@export var base_damage: float = 10.0
@export var attack_cooldown: float = 1.5
## D198 (мок): замах перед ударом, потім хітбокс у бік погляду живий attack_active_time секунд.
@export var attack_windup: float = 0.4
@export var attack_active_time: float = 0.2
## D208: ривок уперед під час удару, px (fast); броня — оглушення не зриває замах (tank).
@export var lunge: float = 0.0
@export var super_armor: bool = false
## Множник шкоди від удару спереду (tank: панцир, бити треба зі спини після перекату).
@export var front_damage: float = 1.0
## Souls-lite (D265): стійкість — скільки ударів героя ворог витримує до збою (легкий удар 1, фінішер 2, важкий 3).
@export var poise: int = 3
## Скільки секунд збиває героя звичайний удар цього ворога (D264).
@export var stagger_time: float = 0.25
## Комбо (D265): найбільше ударів у серії й шанс кожного наступного.
@export var combo_hits: int = 1
@export var combo_chance: float = 0.5
## Підказка удару (D504): block — білий (блокувати), parry — жовтий (парирувати), dodge — червоний (лише ухилитись).
## tell — звичайний удар, finisher_tell — останній удар серії.
@export_enum("block", "parry", "dodge") var tell: String = "parry"
@export_enum("block", "parry", "dodge") var finisher_tell: String = "dodge"
## Поза відновлення після серії, с (D504: вікно для відповіді героя).
@export var recovery: float = 0.5
## На скільки px ворог відходить після серії (D504, critique §B); 0 — лишається на місці (tank).
@export var back_off: float = 0.0
## Як вид відповідає на удар героя (D775): trade — приймає (броня, кара по відновленню); evade — легкий: бачить замах
## важкого й відскакує з-під нього, потім карає відновлення; guard — щитоносець: на замах героя стає щитом до нього й
## не лізе під удар, а відповідає, щойно удар скінчився.
@export_enum("trade", "evade", "guard") var answer_swing: String = "trade"
## Відповідь на удари (D754): стільки ударів героя, поки ворог чекає перерви між серіями, — і він б'є одразу, не
## чекаючи її кінця (0 — ніколи). Той, хто б'є без упину, наривається на удар; хто б'є у вікно й захищається — ні.
@export var answer_hits: int = 0
## Випад (D768): з середньої відстані (lunge_from–lunge_to px від героя) — короткий замах lunge_windup з підказкою
## lunge_tell, тоді ривок з ударом туди, де герой стояв у мить підказки. Стояти трохи поза досяжністю вже не безпечно;
## ухилитись — перекотитись крізь ривок або заблокувати його. lunge_chance — шанс обрати випад, коли ворог готовий
## бити, а герой на цій відстані (0 — випаду немає).
@export var lunge_from: float = 0.0
@export var lunge_to: float = 0.0
@export var lunge_windup: float = 0.5
@export_enum("block", "parry", "dodge") var lunge_tell: String = "block"
@export var lunge_chance: float = 0.0
## Шакал (D769): випад — стрибок; влучив — учепився й кусає (EnemyLogic._latch): герой стоїть, укус, тоді відштовхує.
@export var pounce: bool = false

@export_group("Flight")
## Летючий ворог (D445, D558): без гравітації, тіло не зупиняє героя й інших ворогів (лише стіни), логіка —
## FlyingLogic. flight_attack: dive — кружляє поза досяжністю й пікірує (гриф), bite — підлітає хвилею й кусає (кажан).
@export var flying: bool = false
@export_enum("dive", "bite") var flight_attack: String = "dive"
## На скільки px над ногами героя тримається летючий ворог, коли переслідує.
@export var hover_height: float = 0.0
## Швидкість піке, px/с (dive).
@export var dive_speed: float = 0.0

@export_group("Detection")
@export var detection_range: float = 300.0
@export var attack_range: float = 100.0
@export var chase_range: float = 400.0

@export_group("Health")
@export var max_health: int = 100

@export_group("Reward")
## Досвід за вбивство (D297, design/world_expansion_plan.md): melee 30, fast 25, tank 70.
@export var xp_reward: int = 0
