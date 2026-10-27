extends Area2D

## Секрет мапи (D765, Q98): невидима зона в кімнаті — кімната за тріснутою стіною, схованка на виступі, бічний прохід
## (D562). Знайдено, коли герой уперше в неї входить: стан кімнати "found_<імʼя вузла>" (D152 → сейв, як відкрита
## скриня), тихий дзвін (AudioManager "secret_found") і тост «Secret found» у стрічці HUD (EventBus.secret_found).
## Картка локації World Map рахує ці вузли в кімнатах локації (LocationMap → «Secrets c/d»).
##   const SecretArea := preload("res://SampleProject/Scripts/Gameplay/SecretArea.gd")
## Розмір зони — форма CollisionShape2D у кімнаті; ставити туди, куди герой дістається лише знайшовши секрет.

signal found

const STATE_PREFIX := "found_"


func _ready() -> void:
	if is_found():
		monitoring = false
		return
	body_entered.connect(_on_body_entered)


func is_found() -> bool:
	return Game.get_singleton().get_room_state(_room(), state_key(name), false)


## Ключ у стані кімнати для секрету з імʼям вузла [param node_name].
static func state_key(node_name: String) -> String:
	return STATE_PREFIX + node_name


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(GameGroups.PLAYER):
		return
	body_entered.disconnect(_on_body_entered)
	set_deferred(&"monitoring", false)
	Game.get_singleton().set_room_state(_room(), state_key(name), true)
	AudioManager.play(&"secret_found")
	EventBus.secret_found.emit(_room(), String(name))
	found.emit()


func _room() -> String:
	return get_node(^"/root/MetSys").map_data.get_room_from_scene_path(owner.scene_file_path, false)
