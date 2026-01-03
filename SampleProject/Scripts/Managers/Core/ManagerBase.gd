extends Node
class_name ManagerBase

## Base class for all manager systems (ЭТАП 2.3 ✅)
## Provides unified initialization pattern and error handling

func _ready():
	# Defer initialization to ensure scene tree is ready
	call_deferred("_initialize")

func _initialize():
	# Must be overridden by child classes
	push_error("ManagerBase: _initialize() must be overridden in ", get_script().resource_path)
