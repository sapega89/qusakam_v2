extends RefCounted

## Вісім слотів хотбара (D549): яка подія натискає який слот і що написати на бейджі.
##   const SkillSlotInput = preload("res://SampleProject/Scripts/UI/skill_slot_input.gd")
## Клавіатура — 1–8. Геймпад — дві четвірки: RT / R3 / L3 / Back — слоти 1–4 (D272), ті самі кнопки з затиснутим
## LT — слоти 5–8. Тому в InputMap у skill_slot_5…8 ті самі події геймпада, що в 1–4, а вибір робить LT.
## LT лишається асистом: компаньйона кличе натискання LT, за яке не кинули слот 5–8 (Player._unhandled_input).

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

## Дія-зсув другої четвірки на геймпаді.
const SHIFT_ACTION := &"assist"
## Слотів у четвірці.
const GROUP := 4

## За це утримання LT уже кинули слот 5–8 — відпущений LT компаньйона не кличе.
static var shift_used := false


static func action(slot: int) -> StringName:
	return StringName("skill_slot_%d" % (slot + 1))


## Слот (0…SLOT_COUNT−1), який натискає [param event], або −1. Подія геймпада, що належить двом слотам
## (RT — і 1, і 5), дістається другій четвірці, поки тримають LT, інакше першій.
static func slot_for(event: InputEvent) -> int:
	var matches: Array[int] = []
	# Слоти — це дії skill_slot_N з InputMap (SkillManager.SLOT_COUNT); не ідентифікатор SkillManager:
	# скрипт вантажать і тести, що компілюються раніше за autoload.
	var slot := 0
	while InputMap.has_action(action(slot)):
		if event.is_action_pressed(action(slot)):
			matches.append(slot)
		slot += 1
	if matches.is_empty():
		return -1
	var shifted := Input.is_action_pressed(SHIFT_ACTION)
	var picked: int = matches[0]
	for candidate in matches:
		if (candidate >= GROUP) == shifted:
			picked = candidate
			break
	if shifted and picked >= GROUP:
		shift_used = true
	return picked


## Бейдж слота на пристрої, яким грали останнім: «5» на клавіатурі; «RT» або «LT+RT» на геймпаді.
static func badge(slot: int) -> String:
	var key := InputGlyphs.badge(action(slot))
	return "%s+%s" % [InputGlyphs.badge(SHIFT_ACTION), key] if InputGlyphs.using_gamepad and is_shifted(slot) else key


## Слот другої четвірки, кнопка геймпада якого — та сама, що в його пари з першої (тож потрібен LT).
static func is_shifted(slot: int) -> bool:
	return slot >= GROUP and InputGlyphs.names_for(action(slot), true) == InputGlyphs.names_for(action(slot - GROUP), true)
