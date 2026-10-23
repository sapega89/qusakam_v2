extends Node

## 📖 SkillDatabase — база визначень навичок.
## Дзеркалить архітектуру ItemDatabase: JSON у Resources/Data + автозавантаження,
## індекси будуються один раз на завантаженні.
##
## Продакшн-контенту тут немає: skills.json навмисно порожній, поки навички
## не спроєктовані. Тести підвантажують власні фікстури через load_from_array().

const SKILLS_FILE := "res://SampleProject/Resources/Data/skills.json"

## id -> SkillDefinition
var skills: Dictionary = {}
## class_id -> [id]
var skills_by_class: Dictionary = {}
## "active"/"passive" -> [id]
var skills_by_type: Dictionary = {}

## Шлях класу (D260, D279): назва стовбура і клятви — oath_id -> {name, tree, level, keeper, subclasses, prestige}.
var class_name_trunk: String = ""
var oaths: Dictionary = {}
## D497: скільки JP можна вкласти в дерево базового класу (у кожній клятві — її "jp_cap").
var class_jp_cap: int = 0

## Записи, які не пройшли валідацію (для діагностики й тестів).
var rejected: Array[String] = []

signal skills_loaded


func _ready() -> void:
	load_skills()


func load_skills() -> void:
	var file := FileAccess.open(SKILLS_FILE, FileAccess.READ)
	if file == null:
		push_warning("⚠️ SkillDatabase: %s not found — starting empty" % SKILLS_FILE)
		_reset()
		skills_loaded.emit()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("❌ SkillDatabase: failed to parse %s: %s" % [SKILLS_FILE, json.get_error_message()])
		file.close()
		_reset()
		skills_loaded.emit()
		return
	file.close()

	var data = json.data
	class_name_trunk = String(data.get("class", {}).get("name", ""))
	class_jp_cap = int(data.get("class", {}).get("jp_cap", 0))
	oaths = data.get("oaths", {})
	var entries = data.get("skills", []) if data is Dictionary else []
	load_from_array(entries)
	print("✅ SkillDatabase: Loaded %d skills (%d rejected)" % [skills.size(), rejected.size()])


## Замінює вміст бази. Використовується і при читанні JSON, і в тестах.
func load_from_array(entries: Array) -> void:
	_reset()
	for entry in entries:
		if not entry is Dictionary:
			rejected.append("<non-dictionary entry>")
			continue
		var definition := SkillDefinition.from_dict(entry)
		if definition == null:
			rejected.append(String(entry.get("id", "<missing id>")))
			continue
		if skills.has(definition.id):
			rejected.append("%s <duplicate id>" % definition.id)
			continue
		_index(definition)
	skills_loaded.emit()


func _reset() -> void:
	skills.clear()
	skills_by_class.clear()
	skills_by_type.clear()
	rejected.clear()


func _index(definition: SkillDefinition) -> void:
	skills[definition.id] = definition
	var class_key := definition.class_id if not definition.class_id.is_empty() else "*"
	skills_by_class.get_or_add(class_key, []).append(definition.id)
	var type_key := "active" if definition.is_active() else "passive"
	skills_by_type.get_or_add(type_key, []).append(definition.id)


func has_oath(oath_id: String) -> bool:
	return oaths.has(oath_id)


func get_oath(oath_id: String) -> Dictionary:
	return oaths.get(oath_id, {})


## D497: ліміт JP дерева: "" — базовий клас, інакше id клятви.
func tree_cap(tree: String) -> int:
	return class_jp_cap if tree == "" else int(oaths[tree].jp_cap)


func has_skill(skill_id: String) -> bool:
	return skills.has(skill_id)


func get_skill(skill_id: String) -> SkillDefinition:
	return skills.get(skill_id)


func get_all_skills() -> Array:
	return skills.values()


## Навички класу разом із загальнодоступними (class_id == "").
func get_skills_for_class(class_id: String) -> Array:
	var result: Array = []
	for skill_id in skills_by_class.get(class_id, []):
		result.append(skills[skill_id])
	for skill_id in skills_by_class.get("*", []):
		result.append(skills[skill_id])
	return result


func get_skills_by_type(skill_type: String) -> Array:
	var result: Array = []
	for skill_id in skills_by_type.get(skill_type.to_lower(), []):
		result.append(skills[skill_id])
	return result
