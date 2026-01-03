extends HBoxContainer
class_name CoinCounter

## Coin Counter UI Component
## Displays player's current coin count with bounce animation

@onready var coin_label: Label = $CoinLabel
@onready var coin_icon: ColorRect = $CoinIcon

var inventory_manager: InventoryManager = null

func _ready() -> void:
	"""Initialize coin counter and connect to inventory"""
	add_to_group(GameGroups.UI_ELEMENTS)

	# Get InventoryManager
	inventory_manager = ServiceLocator.get_inventory_manager()
	if not inventory_manager:
		push_error("CoinCounter: InventoryManager not found!")
		return

	# Connect to EventBus
	EventBus.coins_changed.connect(_on_coins_changed)

	# Initialize display
	_update_display()

	DebugLogger.info("CoinCounter: Initialized", "UI")

func _on_coins_changed(new_amount: int) -> void:
	"""Called when coins change"""
	_update_display()
	_animate_bounce()

func _update_display() -> void:
	"""Updates the coin counter label"""
	if inventory_manager:
		coin_label.text = str(inventory_manager.get_coins())

func _animate_bounce() -> void:
	"""Quick scale bounce animation on coin gain"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
