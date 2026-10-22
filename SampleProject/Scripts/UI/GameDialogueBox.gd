extends DQDialogueBox

## Вікно діалогу гри (D254): репліка набирається повільно, і поки не набрана вся, натискання
## «далі» нічого не робить — ні дописати одразу, ні перейти. Усі шляхи до наступної репліки
## (DialogueQuest.Inputs → DQDialoguePlayer.accept, повтор репліки NPC у DialogueManager.replay)
## проходять через accept() цього вікна. Швидкість — у dialogue_box_settings.tres.
## Сцена — SampleProject/Scenes/UI/dialogue_box.tscn, копія префаба аддона (D110: показ — наш), з непрозорим
## фоном ModalPanel (D254). Кнопок Auto/Skip у грі немає (B10, Figma npc-dialog-simple 36:6): вузли
## %AutoButton/%SkipButton лишаються прихованими лише тому, що їх вимагає базовий DQDialogueBox і DQDialoguePlayer;
## autoplay_enabled і skip_enabled вимкнені в Resources/Dialogue/dialogue_player_settings.tres.
## Хто говорить (BACKLOG 36): ім'я — по центру, перший рядок Margin/Rows над текстом (B112; у оповідача рядок прихований), портрет
## мовця — праворуч; портрети — у персонажах dialogue_quest/characters (Scripts/Tools/build_portraits.gd).


func accept() -> void:
	if not is_finished():
		return
	super.accept()


## Рамка портрета — лише коли в мовця є портрет; без нього порожня рамка праворуч не показується.
func set_portrait_image(value: Texture2D) -> void:
	super.set_portrait_image(value)
	if is_node_ready():
		%PortraitBackground.visible = value != null


## Рядок імені — лише коли є мовець: у репліки оповідача порожнього рядка над текстом немає (B112).
func set_name_text(value: String) -> void:
	super.set_name_text(value)
	if not is_node_ready():
		await ready
	%NameMargin.visible = value != ""
