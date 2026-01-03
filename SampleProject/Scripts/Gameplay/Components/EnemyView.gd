extends Node
class_name EnemyView

## 🎨 EnemyView - Відображення ворога
## Відповідає за: анімації, спрайти, візуальні ефекти
## НЕ відповідає за: AI, рух, бій, стан
## Дотримується принципу розділення Simulation & View

# Посилання на ворога та спрайт
var enemy: CharacterBody2D = null
var sprite: AnimatedSprite2D = null
var sprite2d: Sprite2D = null
var anim_player: AnimationPlayer = null

# Поточний стан для анімацій
var current_animation: String = "idle"
var facing_direction: int = 1  # -1 left, 1 right

func _ready():
	"""Ініціалізація EnemyView"""
	print("🎨 EnemyView: Initialized")

func initialize(enemy_node: CharacterBody2D, sprite_node: AnimatedSprite2D = null):
	"""Ініціалізує EnemyView з посиланнями на ворога та спрайт"""
	enemy = enemy_node
	sprite = sprite_node
	
	if not enemy:
		push_error("❌ EnemyView: Enemy node is null!")
		return
	
	# Пробуємо знайти Sprite2D + AnimationPlayer (нова структура)
	if not sprite:
		sprite2d = enemy.get_node_or_null("Sprite2D")
		anim_player = enemy.get_node_or_null("AnimationPlayer")
		if sprite2d and anim_player:
			print("🎨 EnemyView: Using Sprite2D + AnimationPlayer for enemy: ", enemy.name)
			return
	
	# Пробуємо знайти AnimatedSprite2D (стара структура)
	if not sprite:
		sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if not sprite:
			# Шукаємо в дочірніх нодах (для копій сцен)
			for child in enemy.get_children():
				if child is AnimatedSprite2D:
					sprite = child
					break
	
	# Если спрайт не найден - это нормально, анимации управляются через AnimationPlayer
	if not sprite and not sprite2d:
		print("⚠️ EnemyView: Sprite node not found for enemy: ", enemy.name, " (using AnimationPlayer instead)")
		return
	
	print("🎨 EnemyView: Initialized with enemy: ", enemy.name)

func update_state(new_state: EnemyLogic.AIState):
	"""Оновлює анімацію на основі стану"""
	var animation_name = ""
	match new_state:
		EnemyLogic.AIState.IDLE:
			animation_name = "idle"
		EnemyLogic.AIState.CHASE:
			animation_name = "walk"
		EnemyLogic.AIState.ATTACK:
			animation_name = "attack"
		EnemyLogic.AIState.RETREAT:
			animation_name = "walk"  # Використовуємо анімацію ходьби для відступу
		_:
			animation_name = "idle"  # Fallback
	
	if animation_name != current_animation:
		current_animation = animation_name
		
		# Работаем с AnimationPlayer (новая структура)
		if anim_player and anim_player.has_animation(animation_name):
			anim_player.play(animation_name)
		# Работаем с AnimatedSprite2D (стара структура)
		elif sprite:
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation_name):
				sprite.play(animation_name)
			elif sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
		
		# Емітуємо подію через EventBus
		if Engine.has_singleton("EventBus"):
			EventBus.animation_changed.emit(enemy, current_animation, animation_name)

func update_direction(direction: int):
	"""Оновлює напрямок спрайта"""
	facing_direction = direction
	
	# Перевертаємо спрайт
	if direction != 0:
		if sprite:
			sprite.flip_h = (direction < 0)
		elif sprite2d:
			sprite2d.flip_h = (direction < 0)

func on_attack_started():
	"""Обробляє початок атаки"""
	# Работаем с AnimationPlayer (новая структура)
	if anim_player and anim_player.has_animation("attack"):
		anim_player.play("attack")
	# Работаем с AnimatedSprite2D (стара структура)
	elif sprite:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
			sprite.play("attack")
		elif sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
	
	# Емітуємо подію через EventBus
	if Engine.has_singleton("EventBus"):
		EventBus.animation_started.emit(enemy, "attack")

func on_attack_ended():
	"""Обробляє завершення атаки"""
	# Повертаємося до попередньої анімації
	if current_animation != "attack":
		if anim_player and anim_player.has_animation(current_animation):
			anim_player.play(current_animation)
		elif sprite:
			sprite.play(current_animation)

func on_player_detected():
	"""Обробляє виявлення гравця"""
	# Можна додати візуальні ефекти (наприклад, червоне світіння)
	pass

func on_player_lost():
	"""Обробляє втрату гравця"""
	# Можна додати візуальні ефекти
	pass

func update_visuals(_delta: float):
	"""Оновлює візуальні ефекти"""
	# Можна додати логіку для візуальних ефектів
	pass

func get_facing_direction() -> int:
	"""Отримує напрямок, в який дивиться ворог"""
	return facing_direction
