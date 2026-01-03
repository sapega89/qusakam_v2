@tool
class_name MovingPlatformConfig
extends Resource

## Enum defining different types of platform movement behaviors
enum PlatformType {
	LOOP,        # Platform loops continuously between start and end positions
	ONE_WAY,     # Platform moves one way when activated
	TRIGGERED,   # Platform moves only while triggered, pauses when deactivated
	TOGGLE       # Platform toggles between start and end positions
}

## Configuration - Core movement parameters
@export_category("Configuration")
@export var type: PlatformType = PlatformType.LOOP
@export var stopframe : float = 0.1     # Pause duration at path ends for LOOP type
@export var delay : float = 0.0
@export_group("Toggle Mode Configuration")
@export var backwards_scale := 1.0

@export_group("Subsequently Activating Platforms")
@export var subsequent_delay : float = 0.0
