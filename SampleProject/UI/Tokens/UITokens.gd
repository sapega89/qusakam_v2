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
