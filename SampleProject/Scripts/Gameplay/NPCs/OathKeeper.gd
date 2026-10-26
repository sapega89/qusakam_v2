extends NpcBase

## Жрець шляху в місті (D726, oath_affinity_plan «The keepers become ordinary people»): жриця Самаля — шлях Паладина,
## жрець бога контрактів (у чорному й золоті) — Темного Лицаря, дервіш — Вартового Рівноваги, без бога. Клятви вони
## більше не дають і меню клятви не мають — шлях обирають на переписі біля брами (CensusScribe, D727). Лише розмова:
## про свій шлях, а тому, хто йде їхнім шляхом, — інша (sworn_dialogue).
## Фас — коли стоїть, молитва / читання / кружляння — коли сам (D295); профіль до героя — поки говорить (NpcBase).

## Шлях цього жерця (skills.json → oaths).
@export var oath_id: String = ""
## Розмова з тим, хто йде його шляхом (замість talk_dialogue).
@export var sworn_dialogue: String = ""
var _first_talk: String = ""


func _ready() -> void:
	_first_talk = talk_dialogue
	super._ready()
	if is_queued_for_deletion():
		return
	EventBus.oath_sworn.connect(func(_id: String) -> void: _sync_talk())
	_sync_talk()


## Герой іде шляхом цього жерця — жрець говорить інше.
func _sync_talk() -> void:
	talk_dialogue = sworn_dialogue if ServiceLocator.get_skill_manager().get_oath() == oath_id else _first_talk
