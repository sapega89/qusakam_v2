extends ManagerBase
class_name CompanionManager

## 🤝 CompanionManager - Система компаньйонів
## Згідно з ЕТАПОМ 3: КРОК 4

@export var max_companions: int = 3
var active_companions: Array[Node] = []

func _initialize() -> void:
	print("🤝 CompanionManager: Initialized. Limit = ", max_companions)

func can_add_companion() -> bool:
	return active_companions.size() < max_companions

func add_companion(companion: Node) -> bool:
	if not can_add_companion():
		DebugLogger.warning("🤝 CompanionManager: Limit reached! Cannot add more.", "Gameplay")
		return false
	
	active_companions.append(companion)
	DebugLogger.info("🤝 CompanionManager: Companion added. Total: %d" % active_companions.size(), "Gameplay")
	return true

func remove_companion(companion: Node) -> void:
	active_companions.erase(companion)
	DebugLogger.info("🤝 CompanionManager: Companion removed.", "Gameplay")
