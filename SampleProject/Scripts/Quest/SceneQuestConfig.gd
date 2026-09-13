extends Resource
class_name SceneQuestConfig

## 🎯 SceneQuestConfig - Конфігурація квестів для сцени
## Містить список етапів та їх послідовність

@export_group("Scene Info")
@export var scene_name: String = ""  # Назва сцени (Canyon, Village, etc.)

@export_group("Stages")
# Лінійні етапи (один за одним)
# Етапи виконуються послідовно від першого до останнього
@export var stages: Array[QuestStageResource] = []

@export_group("Settings")
# Чи потрібно завершити всі етапи перед переходом до інших сцен
@export var require_all_stages: bool = true

# Чи дозволити перехід після завершення поточного етапу
@export var allow_progressive_unlock: bool = false

func _init():
	"""Ініціалізація за замовчуванням"""
	pass

func get_stage_count() -> int:
	"""Повертає кількість етапів"""
	return stages.size()

func get_stage_by_index(index: int) -> QuestStageResource:
	"""Повертає етап за індексом"""
	if index >= 0 and index < stages.size():
		return stages[index]
	return null

func get_stage_by_id(stage_id: String) -> QuestStageResource:
	"""Повертає етап за ID"""
	for stage in stages:
		if stage and stage.stage_id == stage_id:
			return stage
	return null

func get_all_required_dialogues() -> Array[String]:
	"""Повертає всі обов'язкові діалоги з усіх етапів"""
	var all_dialogues: Array[String] = []
	for stage in stages:
		if stage:
			for dialogue in stage.required_dialogues:
				if not dialogue in all_dialogues:
					all_dialogues.append(dialogue)
	return all_dialogues

func get_all_available_scenes() -> Array[String]:
	"""Повертає всі доступні сцени з усіх етапів"""
	var all_scenes: Array[String] = []
	for stage in stages:
		if stage:
			for scene in stage.available_scenes:
				if not scene in all_scenes:
					all_scenes.append(scene)
	return all_scenes
