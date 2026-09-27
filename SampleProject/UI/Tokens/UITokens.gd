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

# Figma type scale: 12 · 14 · 16 · 20 · 24 · 36
const SIZE_DISPLAY := 36   # Bold    — hero, splash
const SIZE_TITLE := 24     # Bold    — заголовки екранів
const SIZE_HEADING := 20   # SemiBold — заголовки секцій, назви предметів
const SIZE_LABEL := 16     # SemiBold — таби, кнопки, навігація
const SIZE_BODY := 16      # Regular — основний текст
const SIZE_SMALL := 14     # Regular — вторинний текст, описи
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
const SIZE_NAME := 48       # Bold — ім'я персонажа на екрані Status

# ── Розміри шелу (Figma: menu-* frames, 1920×1080) ──────────────────────────
const SIDEBAR_WIDTH := 320
const TOP_BAR_HEIGHT := 50
const BOTTOM_BAR_HEIGHT := 64
const BOTTOM_BAR_PADDING := 60
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

# ── Розміри екрана Settings (Figma: settings-* 17:280 / 17:409 / 17:632) ────
const SIZE_OPTIONS_TITLE := 38  # Bold — "OPTIONS" у верхній секції
const SETTINGS_SIDEBAR_WIDTH := 56
const SETTINGS_TAB_HEIGHT := 40
const SETTINGS_TAB_BOX := 36
const SETTINGS_POINTER := 16
const SETTINGS_ROW_PAD_H := 16
const SETTINGS_ROW_PAD_V := 14
const SETTINGS_STEPPER_WIDTH := 280
const SETTINGS_SEGMENT_MIN_WIDTH := 120
const SETTINGS_SLIDER_WIDTH := 320
const SETTINGS_HEADER_ICON := 64
const SETTINGS_ON_ACCENT := Color("050508")  # текст на акцентному сегменті

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
