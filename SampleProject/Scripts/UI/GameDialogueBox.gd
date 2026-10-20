extends DQDialogueBox

## Вікно діалогу гри (D254): репліка набирається повільно, і поки не набрана вся, натискання
## «далі» нічого не робить — ні дописати одразу, ні перейти. Усі шляхи до наступної репліки
## (DialogueQuest.Inputs → DQDialoguePlayer.accept, повтор репліки NPC у DialogueManager.replay)
## проходять через accept() цього вікна. Швидкість — у dialogue_box_settings.tres.
## Сцена — SampleProject/Scenes/UI/dialogue_box.tscn, копія префаба аддона (D110: показ — наш), з непрозорим
## фоном ModalPanel (D254).


func accept() -> void:
	if not is_finished():
		return
	super.accept()
