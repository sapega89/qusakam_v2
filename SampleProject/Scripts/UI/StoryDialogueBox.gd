extends "res://SampleProject/Scripts/UI/GameDialogueBox.gd"

## Вікно репліки сюжетної подачі (D110, Figma 36:65): та сама поведінка, що й звичайне вікно (набір D738, клік —
## уся репліка D736/D753, утримання — до вибору, автогортання D739), інша розкладка — ім'я ліворуч над лінією, без
## портрета: хто говорить, показують картки на весь зріст (D112, story_dialogue.gd).

## Мовець наступної репліки змінився: id персонажа DialogueQuest, "" — оповідач.
signal speaker_changed(speaker: String)


## Портрета у вікні немає — мовця показує картка.
func set_portrait_image(_value: Texture2D) -> void:
	super.set_portrait_image(null)


func set_name_text(value: String) -> void:
	super.set_name_text(value)
	speaker_changed.emit(AudioManager.hooks.speaker_from_name(value))
