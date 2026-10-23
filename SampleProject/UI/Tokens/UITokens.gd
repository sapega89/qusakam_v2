extends RefCounted
class_name UITokens

## Дизайн-токени UI, імпортовані з Figma (UI KIT / DESIGN SYSTEM, node 222:4288).
## Єдине джерело правди для кольорів, відступів і типографіки.
##
## Ці значення відповідають Figma Variables один-до-одного. Не хардкодь кольори
## чи розміри в сценах — використовуй ці константи або GameUITheme.tres.
##
## Після зміни токенів перегенеруй тему:
##   godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd

# ── Кольори ─────────────────────────────────────────────────────────────────
# Figma: color/background
const BACKGROUND := Color("111118")
# Figma: color/surface (#111118 @ 56%)
const SURFACE := Color("111118", 0.56)
# Поверхня панелей меню, на яких лежить текст (центральна панель, бічні колонки, картки, дерево навичок,
# слоти збереження). Непрозора, як ModalPanel (D195) і ScreenPanel: крізь 56% SURFACE проступала
# мапа-пергамент і її написи лягали під текст (B8). Мапа лишається видимою в проміжках між панелями.
const MENU_SURFACE := BACKGROUND
# Figma: Surface Hover (#111118 @ 30%)
const SURFACE_HOVER := Color("111118", 0.30)
# Figma: color/accent
const ACCENT := Color("d4af37")
# Figma: color/border
const BORDER := Color("3a3a42")
# Figma: color/border-strong (== accent)
const BORDER_STRONG := Color("d4af37")
# Figma: color/text-primary
const TEXT_PRIMARY := Color("ffffff")
# Figma: color/text-secondary (змінна дає a1a1a1, документація каже a0a0a0 — беремо змінну)
const TEXT_SECONDARY := Color("a1a1a1")
# Figma: Text Muted
const TEXT_MUTED := Color("666666")
# Figma: Disabled
const TEXT_DISABLED := Color("404040")
# Figma: color/overlay (#000000 @ 56%)
const OVERLAY := Color("000000", 0.56)

## Колір тексту поверх акцентної заливки (виділений рядок, primary-кнопка).
const ON_ACCENT := Color("111118")

# ── Форма ───────────────────────────────────────────────────────────────────
# Figma: shape/radius-sm — гострі кути всюди
const RADIUS := 0
# Figma: shape/border-default
const BORDER_WIDTH := 1
# Figma: shape/border-selected
const BORDER_WIDTH_SELECTED := 2

# ── Фокус (Q33, BACKLOG 41: один вигляд вибраного рядка в кожному меню) ─────
# Рядок під фокусом (клавіатура, геймпад, наведення мишею) — 2px акцентна рамка без заливки,
# намальована поверх власного стану кнопки. Будівник теми бере ЛИШЕ ці токени для "focus".
const FOCUS_RING := ACCENT
# На акцентній заливці золота рамка зникає — там рамка біла (як у Primary-кнопки).
const FOCUS_RING_ON_ACCENT := TEXT_PRIMARY
const FOCUS_RING_WIDTH := BORDER_WIDTH_SELECTED

# ── Відступи ────────────────────────────────────────────────────────────────
const SPACE_2XS := 2
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24
const SPACE_2XL := 32
const SPACE_3XL := 48

# Семантичні відступи (Figma: Semantic Spacing)
const PANEL_PADDING := 16
const LIST_ROW_PADDING := 12
const ICON_TEXT_GAP := 8
const SECTION_GAP := 24
const SCREEN_MARGIN := 48

# ── Типографіка ─────────────────────────────────────────────────────────────
const FONT_PATH := "res://SampleProject/Assets/Fonts/CormorantGaramond.ttf"

const WEIGHT_REGULAR := 400
const WEIGHT_MEDIUM := 500
const WEIGHT_SEMIBOLD := 600
const WEIGHT_BOLD := 700

# D166 (Sapega, 2026-10-15): увесь текст більший за Figma. Константи SIZE_* нижче лишаються
# Figma-розмірами; build_game_ui_theme.gd проганяє кожен розмір теми через font_px().
const FONT_SCALE := 1.25
## Більші за це — заголовки й дисплейні написи; вони вже великі й не масштабуються.
const FONT_SCALE_MAX := 28


# D474 (Sapega, 2026-10-23): на чотирьох ігрових поверхнях — вікно діалогу й облачка, меню дій NPC,
# панелі HUD (герой, хотбар, квест) і підказка та вікно туторіалу — текст ×1.5, а не ×1.25.
# Пороги при 1080p: тіло ≥ 24 px, підписи й клавіші ≥ 20 px. Заголовки (> FONT_SCALE_MAX) — як були.
const INGAME_FONT_SCALE := 1.5
const INGAME_BODY_MIN := 24
const INGAME_LABEL_MIN := 20
## Типи теми цих поверхонь; build_game_ui_theme.gd масштабує їх через font_px(…, true).
const INGAME_FONT_TYPES: Array[StringName] = [
	&"DialogueName", &"DialogueText", &"DialogueChoice",
	&"NpcMenuItem", &"NpcMenuItemOn",
	&"VitalsName", &"VitalsLabel", &"VitalsValue", &"BindBadge", &"CooldownLabel", &"HudQuestCaption", &"HudQuestTitle",
	&"TutorialBody", &"TutorialHint", &"TutorialKeyLabel", &"TutorialBanner",
]


## Розмір, який реально потрапляє в тему, для Figma-розміру; [param in_game] — ігрові поверхні (D474).
static func font_px(figma_size: int, in_game: bool = false) -> int:
	if figma_size > FONT_SCALE_MAX:
		return figma_size
	if in_game:
		return maxi(roundi(figma_size * INGAME_FONT_SCALE), INGAME_LABEL_MIN)
	return roundi(figma_size * FONT_SCALE)


# Figma type scale: 12 · 14 · 16 · 20 · 24 · 36
const SIZE_DISPLAY := 36   # Bold    — hero, splash
const SIZE_TITLE := 24     # Bold    — заголовки екранів
const SIZE_HEADING := 20   # SemiBold — заголовки секцій, назви предметів
const SIZE_LABEL := 16     # SemiBold — таби, кнопки, навігація
const SIZE_BODY := 16      # Regular — основний текст
const SIZE_SMALL := 14     # Regular — вторинний текст, описи
const SIZE_TUTORIAL_BODY := 22  # Regular — текст теми туторіалу (Figma 135:1260)
const SIZE_VALUE := 14     # SemiBold — числові значення, стати
const SIZE_CAPTION := 12   # Bold    — метадані, теги

# ── Розміри поза задекларованою шкалою ──────────────────────────────────────
# Документація Figma заявляє шкалу 12·14·16·20·24·36, але самі кадри
# використовують ще й ці розміри. Кадр — візуальне джерело правди, тому
# беремо виміряні значення. Розбіжність зафіксована в design/ui_visual_qa.md.
const SIZE_MICRO := 11      # Bold — PLAYTIME / GOLD / бейдж рівня
const SIZE_ROW_TITLE := 18  # Medium — назва предмета; Bold — таб інвентарю
const SIZE_TOPBAR := 28     # Bold — заголовок "MENU"
const SIZE_MAP_TITLE := 44  # Bold — назва світу на карті
const SIZE_CAPTION_SM := 13 # Regular — підписи секцій ("PRIMARY JOB")
const SIZE_BODY_SM := 15    # Regular — текст карток талантів
const SIZE_LEVEL := 22      # Bold — "Lv.46" біля імені
# Figma UI/Modal/Confirm (258:5332): заголовок модалки — Regular 22, text-primary, по центру (B34).
const SIZE_MODAL_TITLE := 22
const SIZE_NAME := 48       # Bold — ім'я персонажа на екрані Status

# ── Розміри шелу (Figma: menu-* frames, 1920×1080) ──────────────────────────
const SIDEBAR_WIDTH := 320
const TOP_BAR_HEIGHT := 50
const BOTTOM_BAR_HEIGHT := 64
const BOTTOM_BAR_PADDING := 60
const BOTTOM_BAR_BG := Color("111118", 0.85)  # Figma UI/Bottom Bar (121:1073): фон шелу на 85 %
## Значок дії в нижній панелі (Figma UI/Action Button 276:467) — коло 24 px.
const ACTION_BADGE_SIZE := 24
const SIDEBAR_ITEM_HEIGHT := 45

# ── Розміри інвентарю (Figma: UI/Inventory Center Panel 355:6423) ───────────
const ICON_SLOT := 36
const ICON_SLOT_BG := Color("2a2a35")
const CENTER_PANEL_PADDING := 48

# ── Розміри екрана Status (Figma: menu-status 58:719) ──────────────────────
const STATUS_CENTER_WIDTH := 940
const STATUS_PORTRAIT_WIDTH := 640
const STATUS_AVATAR := 96
const METER_HEIGHT := 4
const ATTR_ICON := 16

# ── Розміри панелі партії (Figma: UI/Party Status Panel 104:490) ────────────
const PARTY_PANEL_WIDTH := 400
const PARTY_CARD_WIDTH := 330
const PORTRAIT_SIZE := 56
const BAR_HEIGHT := 6
const BAR_WIDTH := 180
const HP_FILL := Color("2ecc71")
const SP_FILL := Color("3498db")
const STAMINA_FILL := Color("e67e22")  # витривалість (D504), панель героя в HUD

# ── Розміри екрана Settings (Figma: settings-* 17:280 / 17:409 / 17:632) ────
const SIZE_OPTIONS_TITLE := 38  # Bold — "OPTIONS" у верхній секції
const SETTINGS_SIDEBAR_WIDTH := 56
const SETTINGS_TAB_HEIGHT := 40
const SETTINGS_TAB_BOX := 36
const SETTINGS_POINTER := 16
const SETTINGS_ROW_PAD_H := 16
# Figma settings-audio 17:409 / settings-gameplay 17:632: висота рядка, мітка по центру (B21).
const SETTINGS_SLIDER_ROW_HEIGHT := 50
const SETTINGS_CHOICE_ROW_HEIGHT := 68
const SETTINGS_ROW_GAP := 2   # лінія між рядками (крок 52 / 70)
const SETTINGS_STEPPER_WIDTH := 280
const SETTINGS_STEPPER_BOX := 32  # квадратна рамка кнопок −/+ і ‹/› (B22)
const SETTINGS_SEGMENT_MIN_WIDTH := 120
const SETTINGS_SLIDER_WIDTH := 320
const SETTINGS_READOUT_WIDTH := 36  # 0–100 праворуч від повзунка
const SETTINGS_HEADER_ICON := 64
const SETTINGS_ON_ACCENT := Color("050508")  # текст на акцентному сегменті
# D428: зразки під Screen Brightness — компас ледь видно на чорному і на білому; правильна яскравість — видно обидва.
const SETTINGS_PREVIEW_SIZE := Vector2(208, 96)
const SETTINGS_PREVIEW_ICON := 40
const SETTINGS_PREVIEW_DARK_BG := Color("050508")
const SETTINGS_PREVIEW_DARK_MARK := Color("1a1a20")
const SETTINGS_PREVIEW_BRIGHT_BG := Color("f5f5f5")
const SETTINGS_PREVIEW_BRIGHT_MARK := Color("dedede")
# Figma: UI/Scrollbar 222:4768 — 10px, без заокруглень
const SCROLLBAR_WIDTH := 10

# ── Підказка взаємодії (Figma: UI/Interaction/Prompt 461:6479, D74/D84) ────
# Покращений варіант (D84): ширина за вмістом, текст 14–16 px (беремо Label 16),
# стиль як у Figma. Фон — чорний з альфою за станом.
const PROMPT_BG := Color("000000", 0.56)           # State=Default
const PROMPT_BG_FOCUSED := Color("000000", 0.72)   # State=Focused (+ рамка accent 1px)
const PROMPT_BG_DISABLED := Color("000000", 0.32)  # State=Disabled
const PROMPT_DISABLED_CONTENT_ALPHA := 0.4         # бейдж і текст у Disabled
const PROMPT_BADGE := 28                           # icon/input/* 28×28
const PROMPT_PAD_H := 8
const PROMPT_PAD_V := 4
const PROMPT_OFFSET_Y := -56                       # над об'єктом взаємодії

# ── Save / Load (Figma: load-game-screen 150:1278, save-game-screen 17:5) ─────
const SAVE_SCREEN_MARGIN_H := 60
const SAVE_SCREEN_MARGIN_TOP := 40
const SAVE_OVERLAY := Color("07070b", 0.90)       # поверх карти-фону
const SAVE_TOP_GAP := 8
const SAVE_TOP_PAD_BOTTOM := 24
const SAVE_ORNAMENT_LINE := 100
const SAVE_ORNAMENT_GAP := 12
const SAVE_LIST_GAP := 16
const SAVE_CURSOR_COLUMN := 60
const SAVE_CARD_HEIGHT := 176
const SAVE_CARD_PAD_H := 32
const SAVE_CARD_PAD_V := 20
const SAVE_CARD_BORDER := Color("ffffff")          # невибраний слот
const SAVE_INFO_GAP := 4                           # left-info, VERTICAL gap
const SAVE_RIGHT_GAP := 40                         # right-info, HORIZONTAL gap
const SAVE_PLAYTIME_GAP := 8
const SAVE_WATERMARK_SPACE := 80                # місце під номер (Figma: 40–65px + повітря)
const SAVE_WATERMARK_COLOR := Color(1, 1, 1, 0.08) # номер слота
const SIZE_SAVE_SYSTEM := 11                       # "SAVE DATA MANAGEMENT"
const SIZE_SAVE_WATERMARK := 160
const SIZE_SAVE_LOCATION := 28                     # location-name / "Empty Slot"
const SIZE_SAVE_LEVEL := 26                        # "Lv. 26"
const SIZE_SAVE_NAME := 18                         # char-name, time-value
const SAVE_CLOCK_ICON := 16

# ── Головне меню / Splash (Figma: main-menu 9:26, UI/Splash Screen 258:5140) ─
const SPLASH_BG := Color("050508")
const MAIN_MENU_OVERLAY := Color("000000", 0.56)
const SIZE_TITLE_KHALAHAS := 100   # Bold, UPPER, letter-spacing 6
const SIZE_TITLE_HEROES := 90      # Bold, UPPER, letter-spacing 8
const TITLE_SPACING_KHALAHAS := 6
const TITLE_SPACING_HEROES := 8
const TITLE_BLOCK_WIDTH := 800
const TITLE_BLOCK_GAP := 10
const TITLE_RULE_OUTER := 600      # верхня і нижня лінії
const TITLE_RULE_MIDDLE := 650
const TITLE_RULE := 2              # Figma 1.5 → 2 (StyleBoxLine лише цілі)
const TITLE_RULE_BOLD := 3         # Figma 2.5 → 3
const MAIN_MENU_CENTER_GAP := 50
const MAIN_MENU_LIST_GAP := 12
const MENU_ITEM_WIDTH := 300
const MENU_ITEM_PAD_H := 16
const MENU_ITEM_PAD_V := 12
const MENU_ITEM_GAP := 8           # вказівник → текст
const MENU_ITEM_POINTER := 12
const MENU_INACTIVE_ALPHA := 0.70
const SPLASH_CENTER_GAP := 100
const SPLASH_PROMPT_GAP := 24
const SIZE_SPLASH_PROMPT := 18     # SemiBold, UPPER, letter-spacing 4
const SPLASH_PROMPT_SPACING := 4
const DIVIDER_LINE := 80           # UI/Diamond Divider
const COPYRIGHT_SPACING := 1       # Regular 12
const SCREEN_PAD_BOTTOM := 64

# ── Магазин (Figma: shop-buy 153:1289, shop-sell 153:1523, shop-buy-confirm 153:1760) ─
const SHOP_PANEL_BG := Color("161310")  # непрозора: крізь 0.90 проступала мапа-фон (B8)
const SHOP_ROW_BG := Color("000000", 0.56)
const SHOP_ICON_TINT := Color("bfb8a6", 0.70)
const SHOP_CATEGORY_COLUMN := 64
const SHOP_CATEGORY_SIZE := 48
const SHOP_CATEGORY_GAP := 8
const SHOP_CATEGORY_PAD_V := 16
const SHOP_CATEGORY_ICON := 18
const SHOP_LIST_PAD := 24
const SHOP_LIST_GAP := 12
const SHOP_HEADER_PAD_V := 8
const SHOP_ROW_HEIGHT := 44
const SHOP_ROW_GAP := 2
const SHOP_ROW_PAD_H := 12
const SHOP_ROW_PAD_V := 10
## Figma menu-skills 58:453: рядок навички — py 10 + Medium 18 (skills_ui_mapping); Button без тексту сам такої висоти не має.
const SKILL_ROW_HEIGHT := 44
const SHOP_ROW_ICON := 22
const SHOP_COL_COUNT := 120
const SHOP_COL_PRICE := 150
const SHOP_DESC_PAD := 16
const SHOP_DESC_GAP := 8
const SIZE_SHOP_TITLE := 22        # "All Wares" — SemiBold, accent
## D433: рядок, на який не вистачає золота, — сірі і назва, і ціна. На вибраному рядку (заливка ACCENT)
## TEXT_MUTED (2.7:1) не читається; Figma Disabled дає ≈ 4.9:1 до ACCENT і тьмяніший за ON_ACCENT (8.9:1).
const SHOP_TEXT_DISABLED_ON_ACCENT := TEXT_DISABLED
const MIN_TEXT_CONTRAST := 4.5
# Крафт (Figma crafting-list 160:1291): рядок у два рядки — назва + "Requires: …" (13 Regular).
const CRAFT_ROW_HEIGHT := 60
const CRAFT_ROW_NAME_GAP := 2
const FADE_TIME := 0.6  # затемнення кат-сцени (ScreenFade), секунд
const ROOM_FADE_TIME := 0.25  # зміна кімнати й старт гри з меню: згасання і поява, секунд (D434)
# Облачко над головою (D178). Арт тимчасовий: Assets/UI/Dialogue/bubble_*.png (D160).
const BUBBLE_MARGIN := 24          # поле 9-slice у bubble_body.png
const BUBBLE_PADDING := 14         # від контуру до тексту
const BUBBLE_TAIL_OVERLAP := 10    # хвіст заходить на нижній контур тіла
const BUBBLE_MAX_WIDTH := 360      # ширше — перенос рядка
const BUBBLE_OFFSET_Y := -56       # над головою гравця, світові px
const BUBBLE_INK := Color("141018")
const BUBBLE_SECONDS_MIN := 2.0    # репліка висить: min + довжина × per_char, не довше max
const BUBBLE_SECONDS_PER_CHAR := 0.05
const BUBBLE_SECONDS_MAX := 6.0
# Плашка цілі на HUD (BACKLOG 37, Q39): з'являється, тримається, гасне; знову — після будь-якого меню.
const OBJECTIVE_PLAQUE_HOLD := 5.0   # секунд видно після появи / зміни цілі
const OBJECTIVE_PLAQUE_FADE := 0.6   # згасання і поява, секунд
# Стрічка здобичі з мобів на HUD (BACKLOG 33): тост «Coin × 7» під валютою; той самий предмет додається до живого тосту.
const LOOT_TOAST_HOLD := 2.5         # секунд видно після останнього поповнення
const LOOT_TOAST_FADE := 0.4         # поява і згасання, секунд
const LOOT_FEED_MAX := 4             # більше тостів — найстаріший іде одразу
const STATUS_INCREASE := Color("2ecc71")  # Figma status/increase — ✓ матеріалу вистачає
const CURRENCY_SYMBOL := "₹"       # ціни в рядках магазину (Figma)
# NPC-меню (Figma: npc-interaction-menu у 164:1302 / 176:1357, UI/Menu Item 248:62)
const NPC_MENU_WIDTH := 200
const NPC_MENU_GAP := -BORDER_WIDTH  # рядки перекривають спільну рамку: між ними 1px, не 2 (B40)
const NPC_MENU_OFFSET := Vector2(40, -140)  # праворуч над NPC, як у 164:1302
# Знак над NPC, у якого є що взяти (D442, D452): піксельний «!» чи герб, розмір екранний (world_ui.gd).
const QUEST_MARK_STORY := ACCENT           # сюжетний квест — жовтий «!»
const QUEST_MARK_SIDE := Color("4a9cff")   # побічний — синій «!»
const QUEST_MARK_OATH := Color("c9cdd8")   # клятва (професія) — срібний герб
const QUEST_MARK_OUTLINE := BACKGROUND
const QUEST_MARK_PIXEL := 3                # сторона «пікселя» знака, px
const QUEST_MARK_GAP := SPACE_XS           # від верху спрайта до низу знака, px
const LG_TAB_GAP := 16            # UI/Sidebar Tab: gap 16 у category-list
const SIDEBAR_TAB_HEIGHT := 45

# ── Удар по героєві (4b, Sapega «відчуття, що тебе вдарили»): червона віньєтка лише по краях екрана
# (центр прозорий — не повноекранний спалах) і короткий червоний спалах рядка HP. Колір@альфа → позиція від центру.
const HURT_RED := Color("e0281e")
const HURT_VIGNETTE := [[Color("e0281e", 0.0), 0.72], [Color("e0281e", 0.55), 1.0]]

# ── Реакції NPC у кат-сценах (D460, Cutscene.react): піксельний значок над головою і червоний спалах болю.
# Figma кадру не має — агентське рішення, див. design/cloud_reports/story-text.md. Значки — Assets/UI/Icons/emote_*.svg
# (білий гліф, фарбується цими кольорами; контур — BUBBLE_INK).
const EMOTE_SURPRISE := ACCENT          # «!»
const EMOTE_CONFUSION := TEXT_PRIMARY   # «?»
const EMOTE_SILENCE := TEXT_SECONDARY   # «…»
const EMOTE_FEAR := SP_FILL             # крапля поту
const EMOTE_SCALE := 3.0                # значок 10–12 px × 3: читається поруч зі спрайтами акторів (×1.5 від 64 px)
const EMOTE_GAP := 4.0                  # світові px між маківкою і низом значка
const EMOTE_POP := 0.12                 # значок вискакує, секунд
const EMOTE_HOLD := 0.9                 # тримається
const EMOTE_FADE := 0.25                # гасне
const REACT_PAIN_FLASH := HURT_RED      # біль — актор червоніє, як від удару

# ── Цифри урону (D66; Sapega 2026-10-22 «цифри урону по мені і ворогу»): над тілом, піднімаються й гаснуть.
# Figma кадру не має — агентське рішення, див. design/cloud_reports/combat-stats.md.
const DAMAGE_NUMBER_ENEMY := TEXT_PRIMARY     # удар героя по ворогу
const DAMAGE_NUMBER_HERO := HURT_RED          # удар по героєві — інший колір, ніж по ворогу
const DAMAGE_NUMBER_CRIT := ACCENT            # крит героя (D393) — золото, більший
const DAMAGE_NUMBER_EVADED := TEXT_SECONDARY  # слово «Evade» над героєм замість 0
const DAMAGE_NUMBER_OUTLINE := BACKGROUND
# Растр шрифту; сцена DamageNumber зменшує вузол ×0.4, камера гри ×2.25 — на екрані ≈ 0.9 цього розміру
# (цифри Cormorant старого стилю, низькі — тому розмір більший за текст HUD).
const DAMAGE_NUMBER_SIZE := 52
const DAMAGE_NUMBER_CRIT_SIZE := 72
const DAMAGE_NUMBER_WORD_SIZE := 40
const DAMAGE_NUMBER_OUTLINE_SIZE := 16
const DAMAGE_NUMBER_RISE := 28.0              # світові px угору за час життя
const DAMAGE_NUMBER_TIME := 0.8               # с; друга половина — згасання
const DAMAGE_NUMBER_CRIT_POP := 1.4           # крит з'являється більшим і за DAMAGE_NUMBER_POP_TIME стискається
const DAMAGE_NUMBER_POP_TIME := 0.15
const DAMAGE_NUMBER_GAP := 18.0               # світові px над верхом тіла: над смужкою HP ворога
const DAMAGE_NUMBER_SPREAD: Array[float] = [0.0, -10.0, 10.0]  # цифри поспіль не лягають одна на одну

# ── Game Over (Figma: game-over-screen 41:83) ─────────────────────────────────
const GAME_OVER_RED := Color("9e1b1b")
const GAME_OVER_FRAME := Color("5c5655")
const GAME_OVER_FRAME_INNER_ALPHA := 0.40
# Радіальна віньєтка поверх фото: колір@альфа → позиція
const GAME_OVER_VIGNETTE := [[Color("140a0a", 0.0), 0.10], [Color("090303", 0.85), 0.75], [Color("000000", 1.0), 1.0]]
const GAME_OVER_INSET := 60        # рамка 1800×960 з відступом 60
const GAME_OVER_INSET_INNER := 12
const GAME_OVER_CORNER := 48
const SIZE_GAME_OVER := 144        # "Game Over" — Bold, червоний, тінь
const SIZE_GAME_OVER_EYEBROW := 14 # "Khalahas Heroes" — SemiBold, колір рамки
const GAME_OVER_COLUMN_GAP := 48
const GAME_OVER_EYEBROW_GAP := 8
const GAME_OVER_OPTIONS_GAP := 32
const GAME_OVER_RULE := 320
const GAME_OVER_RULE_ALPHA := 0.80
const GAME_OVER_EYEBROW_LINE := 32
const GAME_OVER_FOOTER_BOTTOM := 100
const GAME_OVER_SHADOW := Color("000000", 0.40)

# ── Підменю Miscellaneous (Figma: menu-miscellaneous 58:1246 → misc-sub-menu) ─
# Рядки мають горизонтальний градієнт, що згасає у прозорість праворуч.
const MISC_ROW_WIDTH := 500
const MISC_ROW_PAD_H := 24
const MISC_ROW_PAD_V := 14
const MISC_ROW_GAP := 4
const MISC_ROW_ON := [
	Color(0.1216, 0.1216, 0.1412, 0.95),
	Color(0.1490, 0.1490, 0.1686, 0.85),
	Color(0.1804, 0.1804, 0.2000, 0.50),
	Color(0.2000, 0.2000, 0.2196, 0.0),
]
const MISC_ROW_OFF := [
	Color(0.0784, 0.0784, 0.1020, 0.70),
	Color(0.1020, 0.1020, 0.1216, 0.50),
	Color(0.1216, 0.1216, 0.1412, 0.25),
	Color(0.1490, 0.1490, 0.1686, 0.0),
]
const MISC_ROW_STOPS := [0.0, 0.5, 0.75, 1.0]


# ── Модалка підтвердження (Figma UI/Modal/Confirm 258:5332, shop-buy-confirm 153:1760; B119) ─
const MODAL_PAD_H := 40
const MODAL_PAD_V := 28
const MODAL_GAP := 16              # заголовок → лінія → опис → кнопки
const MODAL_RULE_WIDTH := 300      # 1 px акцентна лінія під заголовком
const MODAL_RULE := 1
const MODAL_BUTTON_COLUMN := 300   # колонка кнопок
const MODAL_BUTTON_GAP := 12
const MODAL_BUTTON_WIDTH := 260    # UI/HexButton
const MODAL_BUTTON_HEIGHT := 36
const MODAL_BUTTON_POINT := 17     # ширина загостреного кінця (Figma 16.2): margin текстури, кінці не тягнуться
const MODAL_POINTER_X := 49        # шеврон «›» вибраної кнопки
const MODAL_POINTER := 16
const SIZE_MODAL_BODY := 14        # Regular
const SIZE_MODAL_BUTTON := 18      # SemiBold, UPPER
const MODAL_BUTTON_SPACING := 2    # tracking 2 px
const MODAL_BUTTON_TEXTURE := "res://SampleProject/Assets/UI/Icons/hex_button.svg"
const MODAL_BUTTON_SELECTED_TEXTURE := "res://SampleProject/Assets/UI/Icons/hex_button_selected.svg"
const MODAL_POINTER_TEXTURE := "res://SampleProject/Assets/UI/Icons/chevron.svg"
