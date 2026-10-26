extends DQDialogueBox

## Вікно діалогу гри (D254, D722): репліка набирається повільно (D254). D722 (критик раунду 13: «Якщо ми хочемо
## проклацати діалог, то треба дати можливість його проклацати») замість «поки не набрана — нічого»: натискання «далі»
## під час набору показує всю репліку одразу, наступне — наступна репліка; утримання «далі» (DIALOGUE_HOLD_SKIP) гонить
## репліки до наступного вибору — вибір не пропускається ніколи, після нього — лише нове натискання.
## Усі шляхи до наступної репліки (DialogueQuest.Inputs → DQDialoguePlayer.accept, повтор репліки NPC у
## DialogueManager.replay) проходять через accept() цього вікна. Швидкість — UITokens.DIALOGUE_LETTERS_PER_SECOND (D738).
## D739 (Sapega 2026-10-26: «автоматично показувати нову сторінку діалогу через 1-2 секунди»): набрана репліка йде
## далі сама після паузи auto_advance_delay(); натискання — одразу; поки видно вибір, вікно чекає гравця.
## Сцена — SampleProject/Scenes/UI/dialogue_box.tscn, копія префаба аддона (D110: показ — наш), з непрозорим
## фоном ModalPanel (D254). Кнопок Auto/Skip у грі немає (B10, Figma npc-dialog-simple 36:6; автогортання D739 —
## налаштування Settings → Game → Auto-Advance, а не кнопка й не autoplay аддона): вузли
## %AutoButton/%SkipButton лишаються прихованими лише тому, що їх вимагає базовий DQDialogueBox і DQDialoguePlayer;
## autoplay_enabled і skip_enabled вимкнені в Resources/Dialogue/dialogue_player_settings.tres.
## Хто говорить (BACKLOG 36): ім'я — по центру, перший рядок Margin/Rows над текстом (B112; у оповідача рядок прихований), портрет
## мовця — праворуч; портрети — у персонажах dialogue_quest/characters (Scripts/Tools/build_portraits.gd).


## B122: висота вікна з .tscn (938 × 178) — найменша; вищим його робить лише вміст (рядок імені B112, портрет).
var _base_height: float
var _refit_queued: bool = false
## Список відповідей діалогу (DialogueSystem.tscn): поки він видно, утримання нічого не гонить (D722).
@export var choice_menu: Control
## D722: скільки тримають «далі», натиснуте вже при відкритому вікні; утримання дійшло до вибору — далі нове натискання.
var _held: float = 0.0
var _pressed_here := false
var _hold_spent := false
var _skip_wait: float = 0.0
## D739: скільки ще чекати набраній репліці, перш ніж піти далі самій; < 0 — не чекає (набирається, вибір, сховано).
var _auto_wait: float = -1.0


func _ready() -> void:
	super._ready()
	_base_height = offset_bottom - offset_top
	# D738: одна швидкість набору для всіх розмов (ресурс налаштувань спільний; DialoguePlayer бере її як «звичайну»
	# для тегів [speed] щоразу, коли DialogueManager підключає вікно).
	settings.letters_per_second = UITokens.DIALOGUE_LETTERS_PER_SECOND
	all_text_shown.connect(_on_line_typed)
	proceed.connect(_stop_auto)


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
	_auto_wait = -1.0  # нова репліка ще набирається
	_queue_refit()


## D425: Settings → Text Speed. Аддон набирає літери за settings.letters_per_second (UITokens.DIALOGUE_LETTERS_PER_SECOND, D738; теги [speed] у .dqd
## теж міняють саме його) — Quick лише пришвидшує годинник набору, тож і теги [speed] лишаються пропорційними.
func _process(delta: float) -> void:
	super._process(delta * SaveSystem.settings_module.text_speed_factor())
	_hold_skip(delta)
	_auto_advance(delta)


## D739: пауза набраної репліки перед автогортанням — довша для довшої, у межах DIALOGUE_AUTO_MIN..MAX.
## Ту саму паузу бере облачко розмови (DialogueManager._play_bubbles).
func auto_advance_delay(line: String) -> float:
	return clampf(line.length() * UITokens.DIALOGUE_AUTO_PER_CHAR, UITokens.DIALOGUE_AUTO_MIN, UITokens.DIALOGUE_AUTO_MAX)


func _on_line_typed() -> void:
	_auto_wait = auto_advance_delay(get_text())


func _stop_auto() -> void:
	_auto_wait = -1.0


func _auto_advance(delta: float) -> void:
	if _auto_wait < 0.0 or not visible or choice_menu.visible or not SaveSystem.settings_module.auto_advance_enabled():
		return
	_auto_wait -= delta
	if _auto_wait < 0.0:
		accept()  # репліка набрана — accept() = proceed, як натискання


## D722: натискання під час набору — уся репліка (база: finish()), після — наступна (proceed).
func accept() -> void:
	super.accept()


## Утримання рахується лише з натискання при відкритому вікні: кнопка, що відкрила розмову (A в меню NPC), не гонить.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"dq_accept"):
		_pressed_here = true


func _hold_skip(delta: float) -> void:
	if not Input.is_action_pressed(&"dq_accept") or not visible or not _pressed_here:
		_held = 0.0
		_hold_spent = false
		_pressed_here = _pressed_here and Input.is_action_pressed(&"dq_accept")
		return
	if choice_menu.visible:
		_hold_spent = true
	if _hold_spent:
		return
	var before := _held
	_held += delta
	if _held < UITokens.DIALOGUE_HOLD_SKIP:
		return
	if before < UITokens.DIALOGUE_HOLD_SKIP:
		DialogueQuest.Inputs.ignore_next_press()  # відпускання після прогону — не ще одна репліка
		_skip_wait = 0.0
	_skip_wait -= delta
	if _skip_wait > 0.0:
		return
	_skip_wait = UITokens.DIALOGUE_SKIP_STEP
	accept()


func is_skipping() -> bool:
	return _held >= UITokens.DIALOGUE_HOLD_SKIP and not _hold_spent


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
