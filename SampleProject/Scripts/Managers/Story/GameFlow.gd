extends ManagerBase
class_name GameFlow

## 🎭 GameFlow - Менеджер глобального прогресу демо-версії
## Керує переходами між ключовими ігровими зонами та станом сюжету.
## Згідно з ЕТАПОМ 3: КРОК 1

enum StoryState {
	CANYON,      # Початок, перший бій, медитація
	VILLAGE,     # Викрадення, битва з бандитом, лікування
	DESERT_ROAD, # Циклічні бої на дорозі
	CITY_GATES,  # Ворота міста, фінальна битва перед лабою
	LABORATORY,  # Лабораторія, компаньйони, бос
	LAB_OUTSIDE, # Вихід, фінал демо
	DEMO_END     # Екран завершення
}

@export var current_state: StoryState = StoryState.CANYON:
	set(val):
		current_state = val
		_on_state_changed(val)

signal state_changed(new_state: StoryState)
@warning_ignore("unused_signal")
signal scene_state_changed(scene_name: String, old_state: String, new_state: String)  # Событие смены состояния конкретной сцены

func _initialize() -> void:
	print("🎭 GameFlow: Initialized at state ", StoryState.keys()[current_state])
	# Тут можна додати логіку відновлення стану зі збереження, якщо потрібно

func advance_story() -> void:
	"""Переводить сюжет на наступний етап"""
	if current_state < StoryState.DEMO_END:
		current_state = (current_state + 1) as StoryState
		DebugLogger.info("🎭 GameFlow: Story advanced to %s" % StoryState.keys()[current_state], "Story")

func set_story_state(state: StoryState) -> void:
	"""Встановлює конкретний стан сюжету (наприклад, при завантаженні)"""
	current_state = state
	DebugLogger.info("🎭 GameFlow: Story state manually set to %s" % StoryState.keys()[current_state], "Story")

func _on_state_changed(new_state: StoryState) -> void:
	state_changed.emit(new_state)
	
	if new_state == StoryState.DEMO_END:
		_show_demo_end_screen()

func _show_demo_end_screen() -> void:
	"""Жорстка зупинка демо (КРОК 5)"""
	DebugLogger.info("🎭 GameFlow: DEMO STOP REACHED.", "Story")
	# Логіка показу екрану завершення демо
	if Engine.has_singleton("ServiceLocator"):
		var menu_manager = Engine.get_singleton("ServiceLocator").get_menu_manager()
		if menu_manager:
			# Припустимо, у MenuManager є такий метод або ми його додамо
			# menu_manager.show_demo_end() 
			pass
