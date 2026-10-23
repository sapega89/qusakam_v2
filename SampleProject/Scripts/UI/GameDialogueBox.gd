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


## B122: висота вікна з .tscn (938 × 178) — найменша; вищим його робить лише вміст (рядок імені B112, портрет).
var _base_height: float
var _refit_queued: bool = false


func _ready() -> void:
	super._ready()
	_base_height = offset_bottom - offset_top


## B122: вікно росте вгору під свій вміст і стає назад нижчим, нижній край стоїть. Покладатися на авторозмір
## Control не можна: між розмовами вікно ховають і лише потім чистять, Godot не оновлює для схованого вузла
## запам'ятований мінімальний розмір, і в наступній розмові з тим самим вмістом (ім'я + портрет) вікно
## лишалося 178 px, а портрет звисав під ним. Тому висоту задають відступи, щоразу як міняється вміст чи видимість.
func _queue_refit() -> void:
	if _refit_queued or not is_node_ready():
		return
	_refit_queued = true
	_refit.call_deferred()


func _refit() -> void:
	_refit_queued = false
	offset_top = offset_bottom - maxf(_base_height, get_combined_minimum_size().y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_queue_refit()


func set_text(value: String) -> void:
	super.set_text(value)
	_queue_refit()


## D425: Settings → Text Speed. Аддон набирає літери за settings.letters_per_second (24, D254; теги [speed] у .dqd
## теж міняють саме його) — Quick лише пришвидшує годинник набору, тож і теги [speed] лишаються пропорційними.
func _process(delta: float) -> void:
	super._process(delta * SaveSystem.settings_module.text_speed_factor())


func accept() -> void:
	if not is_finished():
		return
	super.accept()


## Рамка портрета — лише коли в мовця є портрет; без нього порожня рамка праворуч не показується.
func set_portrait_image(value: Texture2D) -> void:
	super.set_portrait_image(value)
	if is_node_ready():
		%PortraitBackground.visible = value != null
		_queue_refit()


## Рядок імені — лише коли є мовець: у репліки оповідача порожнього рядка над текстом немає (B112).
func set_name_text(value: String) -> void:
	super.set_name_text(value)
	if not is_node_ready():
		await ready
	%NameMargin.visible = value != ""
	_queue_refit()
