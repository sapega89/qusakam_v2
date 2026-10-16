---
type: status
status: reference
tags: [hub, bugs]
---

# Bugs — open defects

Things that are **built but wrong**. Unbuilt systems go to [[BACKLOG]] instead;
vault conventions in [[INDEX]].

Filed by `visual-qa` (see the `ui-screen-pipeline` skill) and by anyone who
finds a defect while doing something else. A bug found and not filed is a bug
found twice.

## What belongs here

A mismatch with Figma, or a broken behaviour, **that nobody needs to decide
about**. Triage every finding three ways before filing:

| Finding | Goes to | Not a bug because |
|---|---|---|
| An approved decision covers it | [[figma_decision_register]] — cite the D-ID | The runtime is intentionally right |
| It needs a product call (a price, a rule, keep-or-cut) | [[questions_for_sapega]] — new Q-ID | Nobody has decided yet |
| The system does not exist at all | [[BACKLOG]] + a plan note | Nothing to fix |
| **A decision approved it and nobody built it** | [[BACKLOG]] → Agreed but never built, **citing the D-ID** | Nothing is wrong; the work was dropped |
| Nothing says it is wrong — you just dislike it | **Parked observations** below, as an **O-ID** | No source to measure it against |
| **None of the above — it is simply wrong** | **here, as a B-ID** | — |

Pre-existing test failures are **not** bugs: check [[test_baseline]] first, its
six known issues are baseline noise.

## Row format

Append; never renumber. Delete the row in the commit that fixes it — git keeps
the history, this note keeps only what is open.

```markdown
### B<n> — <one-line symptom>
- **Where:** `path/to/scene.tscn` → `%NodePath` (and the script, if behaviour)
- **Screen:** [[<screen>_mapping]] · Figma `<frame> <node-id>`
- **Expected:** <value + its source: Figma variable, UITokens constant, or frame measurement>
- **Got:** <value as measured>
- **Evidence:** `design/shots/<file>.png`, or the `RESULT:` line that failed
- **Severity:** blocker | visual | cosmetic
- **Found:** <date>, <slice or task>
```

**Expected** must name its source. "Should be darker" is not a bug report;
"`UITokens.SURFACE` = `#111118` @56%, node has `#1A1A1E` @100%" is.

## Severity

| | Meaning |
|---|---|
| **blocker** | Broken behaviour, a new error in the log, or a screen that cannot be opened. Fix before the slice ships. |
| **visual** | A real mismatch with Figma: wrong token, wrong size, wrong state styling, wrong layout. |
| **cosmetic** | Visible only at a non-authoring resolution or in an edge state. |

---

## Open

> Seeded with one real finding as a format example. This list is maintained by
> whoever runs QA, not compiled in advance.

## Playtest intake — 2026-09-29 (Sapega)

Reported in one pass, terse by design. Each row is **reported, not reproduced**
unless it says otherwise. Do not fix from these rows alone — they are a queue,
not a diagnosis. Promote a row to a full B-ID when it has been reproduced.

Before treating any row as a bug, ask whether it was ever built. In play,
"agreed but never implemented" is indistinguishable from "broken" — and several
of these turned out to be exactly that. Check [[figma_decision_register]] for a
D-ID first; if one exists, the row belongs in [[BACKLOG]] → *Agreed but never
built*, not here.

| ID | Report | Status after a first look |
|---|---|---|
| P1 | Attack has no animation and deals no damage; assumed to follow from having no weapon | ⚠️ **cause is not the weapon.** `Player.tscn` already has the `Attack` animation (`:139`), all four `PlayerCombat` exports wired (`:181–184`), `DamageApplier.base_damage = 15`. `perform_attack()` also falls back to a 0.2 s damage window when no animation exists (`PlayerCombat.gd:75`). Needs reproduction — the real cause is elsewhere. |
| P2 | No weapon in the game | Unverified. Check whether the player is meant to start equipped and whether any map grants a weapon — related to **Q2 / D88** (no production map gives an inventory item). |
| P3 | Dialogues | Too terse to act on. Needs one sentence: which NPC, what happens instead. Note the dialogue presentation layer is unbuilt — [[BACKLOG]], D110. |
| P4 | "Дід" NPC never appears; should be a placeholder cube | ✅ **done 2026-10-12.** The story logic and trigger already existed (`Village.gd` `OLD_MAN_*`, `Village.tscn` → `StateChangeTrigger_OldManOutside` at (1582, 344)); only the visual was missing. Added `OldMan` `Sprite2D` under that trigger, frame 0 of `SampleProject/Assets/Characters/old_man_idle.png` (copied from the gitignored `assets/bosses/1 Old_man/` on 2026-10-14 so Village loads from a fresh clone), ×2, facing left. Static — no idle animation. |
| P5 | No merchant and no blacksmith; should be placeholder cubes somewhere on the desert | ✅ **not a bug — known unbuilt work.** Both scenes exist and are tested but are placed **only in `Maps/City.tscn`**. This is **D81** in [[BACKLOG]] → "Merchant / Blacksmith on production maps". Desert placement was never done. |

---

### B56 — Confirm modal body, divider and spacing differ from Figma 258:5332
- **Where:** `Scenes/UI/modal_dialog.tscn` → `Panel` (plain `PanelContainer`), `Panel/VBox`, `Description`.
- **Screen:** Figma `UI/Modal/Confirm 258:5332`.
- **Expected:** description Regular **14** (`SIZE_SMALL`, through `font_px`); a **1px accent divider 300 wide**
  under the title; panel padding **40 h / 28 v**; VBox gap **16** (`SPACE_LG`).
- **Got:** description is base `Label` 16 (→ 20); no divider node; padding `PANEL_PADDING` 16 on all sides;
  VBox `separation = 12` (`SPACE_MD`).
- **Note:** found while fixing the title size (#69, B34 — title now `ModalTitle`, 22 → 28). No 40 / 28
  spacing token exists yet; adding them is part of this fix, not a new decision (values are Figma's).
- **Severity:** visual; found 2026-10-16, #69.

### B55 — The HUD party card names the player "АСТРИТ", not Kusakam
- **Where:** `Scripts/Managers/Gameplay/CharacterManager.gd:51` — `active_character_id = "player_1"`,
  and `player_1` is `"Астрит"` (`:65`); Kusakam is `player_3` (`:85`). The party card reads the active character.
- **Expected:** the character the player controls — Kusakam (`KUSAKAM.tres`, the whole prologue is his).
- **Got:** "АСТРИТ  LV.1" on a new game, Canyon start.
- **Evidence:** `design/shots/speech_bubble_intro.png` (top-left card).
- **Note:** who Астрит / Уризен are in the story is open (Q51); D18 keeps the roster out for now.
- **Severity:** visual (wrong name on the main HUD); found 2026-10-15, speech-bubble capture.

### B54 — Load menu opened from the Main Menu asks a modal layer that is never built
- **Where:** `Scripts/Menus/LoadGameMenu.gd` `_modal_open()` (called from `_restore_focus()` on open and
  from `_unhandled_input()`) → `UIManager.get_modal_layer()`; `UIManager._should_skip_ui_root()` skips any
  scene under `/Menus/` and `MainMenu.tscn`.
- **Expected:** Continue → Load menu → keys work, Delete (Y) shows its modal.
- **Got (from the code, not reproduced in play):** with the Main Menu → Continue path no UIRoot exists,
  so `get_modal_layer()` is `null` and `.active_modal` errors — same shape as the Shop crash fixed
  2026-10-15 (`get_modal_layer()` now builds UIRoot lazily, but not for `/Menus/` scenes).
  Not hit from Game Over → Load Game: by then the game has built UIRoot.
- **Check:** play Main Menu → Continue, press ↑/↓ and Y; watch the Godot errors.
- **Severity:** error spam / possibly broken Delete modal; found 2026-10-15.
- **✅ Fixed 2026-10-15:** `UIManager` no longer skips UIRoot for `MainMenu.tscn` and `/Menus/` scenes
  (`_should_skip_ui_root()` removed). UIRoot holds only empty layers + the modal layer, so it is harmless
  under the menu. `verify_shop.gd` [4b] checks the modal layer exists while the Main Menu is the scene.

### B53 — Laboratory always restarts from EXPLORE, so a loaded save mid-lab skips its fight
- **Where:** `SampleProject/Scripts/Gameplay/Scenes/Laboratory.gd` — `_ready()` runs
  `_on_state_changed(current_state)` with the default `State.EXPLORE`; every later state that
  finds its flag set just `return`s without advancing.
- **Expected:** the starting state is picked from the `lab_*_complete` flags, as
  `DesertRoad._determine_initial_state()` and (since 2026-10-14) `CityGates._initial_state()` do.
- **Got:** same defect CityGates had — re-entering after the intro left the guards unspawned
  forever (fixed there). In the lab, re-entry is only by loading a save (no way back by foot), and
  the companion beats are trigger-driven, so the right starting state per flag needs reading
  the triggers first.
- **Severity:** blocker for loading a save made inside the lab; found 2026-10-14.
- **Wider, 2026-10-15:** `Maps/Laboratory.tscn` has **no `StateChangeTrigger` at all**, so nothing ever
  moves the lab out of `EXPLORE` — Companion 01–03, the limit test and the boss fight are unreachable
  even on a fresh run. Fixing the load path first needs where each beat fires (trigger x positions) —
  asked Sapega.
- **✅ Fixed 2026-10-15 (D174):** triggers added; `Laboratory._initial_state()` reads the flags.
  `verify_laboratory.gd` walks the beats and reloads mid-lab.

### B37 — Plain `HSeparator` has no theme entry, so Journal/HUD rules render engine grey
- **Root cause (named, not guessed):** `SampleProject/UI/Themes/GameUITheme.tres`
  defines only *variations* with `base_type = &"HSeparator"` — `TitleRule`,
  `TitleRuleBold`, `SaveRule`, `GameOverRule`, `GameOverFrameRule` — and **no base
  `HSeparator` style**. Any separator without a variation falls through to Godot's
  stock theme.
- **Evidence:** `journal_fixtures_1920.png` — the rule under the screen title
  (y=183, x 379–1460) and under `ACTIVE` (y=408, x 979–1460) both measure exactly
  `#7f7f7f` = `Color(0.5, 0.5, 0.5)`, the engine default.
- **Expected:** `#3a3a42` — `UITokens.BORDER`, which every other 1px line **on the
  same screen** uses: the CURRENT OBJECTIVE box, the seven sidebar tab borders, the
  party panel frame.
- **Got:** roughly twice the luminance of every neighbouring rule, from an
  untokened source. Automatic FAIL under the colour rule.
- **Scope:** also in `journal_production_1920.png` and `combat_hud_1920.png`; **zero**
  `#7f7f7f` pixels in the shop, settings and misc shots. Adding the base style fixes
  every occurrence at once.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review (agent pass).

### B38 — Highlighting a sidebar tab moves and shrinks it
- **Where:** Game Menu left nav.
- **Evidence:** `journal_fixtures_1920.png` — lit tabs (Inventory y 90–134, Journal
  y 334–378) carry their accent border at **x = 10 and x = 295** → box 286 wide.
  Unlit tabs (Equipment, World Map, Misc, Skills, Status) run **x = 0 to 295** →
  296 wide. Height 45 ✓ and gap 16 ✓ on all seven.
- **Expected:** one geometry for every row — 296 (`UITokens.SIDEBAR_TAB_WIDTH`) at a
  single x. Highlighting must not move the row.
- **Got:** the highlight shifts right 10px and shrinks 10px, so the left edge jumps
  as the cursor travels.
- **Related:** same family as **B20** (fixed, #81; Settings nav, ~4px), different screen and
  component. Nothing is clipped here.
- **Severity:** visual

### B39 — Party cards are 352 wide against a 330 token
- **Evidence:** `journal_fixtures_1920.png` — panel border x=1520/1919 (400 wide ✓
  `PARTY_PANEL_WIDTH`), card accent borders at **x=1544 and x=1895 → 352**, i.e.
  panel minus 24 padding each side.
- **Expected:** 330 — `UITokens.PARTY_CARD_WIDTH` (Figma `UI/Party Status Panel
  104:490`).
- **Got:** 352. +22px, past ±2 and not a scale step — the card is stretching to fill
  the panel instead of using its own width.
- **Correct on the same component:** height 107, pitch 123, gap 16, portrait 56 ✓
  `PORTRAIT_SIZE`, HP fill `#2ecc71` ✓ `HP_FILL`, bar height 6 ✓ `BAR_HEIGHT`.
- **Severity:** cosmetic

### B40 — NPC action menu's inter-row rule is 2px while its own border is 1px
- **Evidence:** `npc_menu_merchant_1920.png` — outer border 1px `#3a3a42` on all four
  sides; the rule between `Talk` and `Buy` measures **2px** of `#3a3a42` — two
  adjacent row borders with `NPC_MENU_GAP = 0`.
- **Expected:** 1px (`BORDER_WIDTH`). 2px is `BORDER_WIDTH_SELECTED` and reads as a
  selected edge between two unselected rows.
- **Severity:** cosmetic

### B42 — `ObjectiveHUD.tscn` is loaded by `Game.tscn` and never added to the tree
- **Where:** `SampleProject/Game.tscn:15` —
  `[ext_resource type="PackedScene" uid="uid://objectivehud001" path="res://SampleProject/Scenes/UI/ObjectiveHUD.tscn" id="10_objective"]`
- **Screen:** [[figma_coverage]] §F — ObjectiveHUD is superseded by Quest Info Panel
  `434:6580`, already implemented as `UI/Components/combat_hud_top.tscn`.
- **Expected:** every declared `ext_resource` is used by a node in the same scene.
- **Got:** `grep -c 'ExtResource("10_objective")' SampleProject/Game.tscn` = **0**.
  The scene is parsed and loaded on every `Game.tscn` load and never instantiated.
- **Evidence:** swept all 121 `.tscn` for this pattern; `10_objective` is the only
  dangling `PackedScene` `ext_resource` in the project. It is also why a plain
  path-grep reports `ObjectiveHUD.tscn` as used when it is not.
- **Severity:** cosmetic — wasted load, no visible effect. Delete the line, and the
  scene with it unless Q34's answer keeps it.
- **Found:** 2026-09-29, scene inventory audit

### B33 — Modal scrim is a `0.60` literal, not the `OVERLAY` token
- **Evidence:** linear fit of `save_load_overwrite_1920.png` against
  `save_load_load_mode_1920.png` over 350×600px of identical content
  (x 1200–1800, y 530–880): slope **0.4001**, intercept 0.02; pure-white card
  border 255 → 102.
- **Expected:** `UITokens.OVERLAY = Color("000000", 0.56)` → factor 0.44 → white
  lands on 112.
- **Got:** factor 0.40 → 102, i.e. `Color(0, 0, 0, 0.60)`. Matches no token, so it
  is a literal in the modal scene.
- **Severity:** visual (colour, zero tolerance)

### B35 — Bottom bar sits on 48px margins while the screen uses 60
- **Evidence:** `save_load_load_mode_1920.png`. Header rule spans x 59–1860,
  eyebrow ink starts x=61, "Load Game" ink x=63, card right edge 1859. Bottom-left
  hint ink starts **x=49**; the rightmost hint ends **x=1870**.
- **Expected:** 60 — `SAVE_SCREEN_MARGIN_H = 60` and `BOTTOM_BAR_PADDING = 60`,
  corroborated by the header rule at 59/1860.
- **Got:** ~48 both sides. The hint hangs 11px left of the title column and the
  right-hand hints overrun the card edge by 10px — a whole scale step, not rounding.
- **Severity:** visual

### B24 — Item detail panel goes stale; the buy confirmation identifies nothing but its own title
- **Where:** shop item detail bar and inventory description bar — one shared defect.
- **Evidence:**
  - `shop_buy_confirm_1920.png` — the modal reads *"Buy Iron Ingot? / Quantity: 1
    • Total Cost: ₹ 30"*, while the detail panel below still reads *"Potion —
    Restores 50 HP."*, **and the Iron Ingot row carries no selection fill**. Nothing
    on screen except the modal title says what is being bought.
  - `inventory_filter_key_items_1920.png` — the list shows *"No items in this
    category."* while the description bar still reads *"Iron Ore — Raw iron ore…"*,
    an item that is not even in the KEY ITEMS filter.
- **Expected:** the detail panel tracks the acting/selected item, and clears to the
  placeholder (`shop_sell_1920.png` uses *"Select an item."*) when there is none.
  The target row stays visibly selected while its modal is open, as in `shop_sell`.
- **Severity:** blocker
- **Found:** 2026-09-29, screenshot review (agent pass).

### B27 — Button normal/focus styling is inconsistent across modals
- **Where:** shop confirm modal (Yes/No) and the dialogue bar (Auto/Skip).
- **Evidence:** `shop_buy_confirm_1920.png` — `Yes` = gold 2px border, transparent
  fill; `No` = grey filled box, no border. `misc_modal_1920.png` — `Auto` = no fill
  and no border; `Skip` = grey filled box, no gold anywhere.
- **Expected:** one normal style and one focused style shared by all buttons, with
  focus marked by the accent, as `Yes` and the left-nav selection do.
- **Got:** three appearances across two modals, and grey fill means "normal" in one
  and "focused" in the other.
- **Severity:** visual
- **Partly fixed 2026-10-16 (#75):** `GameUITheme` now defines `ButtonActivated` (base `Button`, no own
  values), so the DialogueQuest Auto/Skip buttons resolve the shared `Button` normal / focus styles in both
  states (`verify_game_ui_theme.gd` [3b]); no addon edit. Modal buttons were already plain `Button`.
  **Deferred (Sapega, 2026-10-16):** a distinct tokened "on" state for Auto/Skip (criterion 2) moves to the
  D110 dialogue presentation work (#24); #89 hides those buttons in the meantime.

### B28 — Misc submenu selection ignores the accent language used everywhere else
- **Where:** Menu → Misc submenu (`misc_modal_1920.png`, x 381–846, y 533–580).
- **Expected:** accent `#d4af37` selection — the left nav in the *same screenshot*
  marks Inventory with a gold 2px border, and `shop_sell_1920.png` marks the
  selected row with a gold fill.
- **Got:** a grey bar fading left-to-right, no accent, and no 1px border on the
  submenu rows although every left-nav row has one. The selected row's cursor is
  also `←`, pointing away from its own label, while every nav row uses `❯`.
- **Severity:** visual

### B30 — Inconsistencies between the two list screens (batch, all cosmetic)
All from `shop_sell_1920.png`, `shop_buy_confirm_1920.png`,
`inventory_filter_key_items_1920.png`:
- **Header case:** Shop uses `Item Name` / `On Hand` / `Buying Price` in Title Case;
  Inventory uses `ITEM NAME` / `ON HAND` in uppercase.
- **Panel framing:** Inventory's content column has a continuous gold 1px frame;
  the Shop's identical three-column layout has none.
- **`FILTER` button** uses the gold *selection* fill, competing with the actually
  selected KEY ITEMS tab; gold fill means "current selection" everywhere else.
- **`Buying Price` is the column label on the Sell tab** — merchant's point of view,
  while `On Hand` and `All Possessions` on the same screen use the player's.
- **Inventory tab gaps** measure ≈49 / 54 / 49 / 49 px — one gap past ±2. Verify the
  container separation in the scene before acting; this is a glyph-extent estimate.
- **Severity:** cosmetic

### B19 — "Attack" row puts gamepad bindings in the keyboard columns, with two naming schemes
- **Where:** Settings → Controls, Attack row (y≈598).
- **Evidence:** `settings_controls_1920.png` — Primary = `Button #0`,
  Secondary = `Button A`, Tertiary = empty.
- **Expected:** the pattern every other row follows — keyboard in Primary/Secondary,
  gamepad in Tertiary (`W`/`Up`/`Dpad Up`, `Space`/`W`/`Left Stick Up`) — and one
  naming scheme for gamepad buttons.
- **Got:** gamepad in both keyboard columns, empty gamepad column, and the same
  input class named two different ways in a single row.
- **Note:** this is binding data and labels, not maaacks widget styling, so **D48
  does not cover it**.
- **Severity:** visual

### B22 — Volume steppers have no control chrome
- **Where:** Settings → Audio, the `-` / `+` beside each slider (x≈1076, x≈1444).
- **Evidence:** `settings_audio_1920.png` — bare glyphs directly on the background.
- **Expected:** a 1px bordered box, matching every other interactive control on
  these screens (segmented control, Reset, both footer buttons).
- **Got:** unframed characters with no visible hit target.
- **Severity:** cosmetic

### B16 — Dialogue box stays drawn on top of the open Game Menu
- **✅ Fixed 2026-10-13 (D136):** the menu no longer opens while a dialogue runs.
- **Where:** `UIManager.gd:28` — `allow_pause_during_dialogue: bool = true`.
- **Evidence:** `design/shots/journal_production_1920.png` — the Journal tab is
  open and the DialogueQuest box ("Цей дід… Він такий дурний", with Auto/Skip and
  the empty portrait frame) is rendered over it, at the bottom of the menu.
- **Cause:** the flag deliberately permits opening the menu mid-dialogue, and
  `:383` only consults it when it is `false`. **Nothing hides or dims the
  dialogue box once the menu opens** — two UI layers end up live at once.
- **Undecided, not just broken:** whether the box should hide, dim, or the menu
  should be blocked during dialogue was never settled. Raise it with D110 (the
  project-owned presentation layer) rather than patching visibility here.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.
- **Side note:** no `capture_*.gd` in the repo references `journal_production` —
  that screenshot's producing script is gone. Some shots in `design/shots/` are
  orphaned and cannot be refreshed.

### B14 — Game Over text is unreadable against the stone-wall art
- **Where:** `Scenes/UI/game_over_screen.tscn`.
- **Evidence:** `design/shots/game_over_1920.png`.
- **"Khalahas Heroes"** (`:117`) — small dark-red type on the dark wall, effectively
  invisible at 1920×1080. *(The name itself is correct — `MainMenu.tscn:77` and the
  `TitleKhalahas` / `SIZE_TITLE_KHALAHAS` tokens confirm it is the game's title.)*
- **"Game Over"** — dark red over a high-contrast stone-and-iron-door photo; the
  letterforms collide with the door bars and lose their edges.
- **Expected:** a scrim or a darker backdrop behind the type, as every other
  screen uses (`DimOverlay`), so text reads at a glance.
- **Related:** this is the same missing-scrim family as **B8** — the background
  art is intended, the darkening under the text is not there.
- **Not filed:** the missing third button (Load Game) — that is **D92**, decided
  2026-09-29, after this screenshot.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.

### B15 — Blacksmith action menu is not anchored to the NPC
- **Where:** `UI/Components/npc_action_menu.gd`, in-world placement.
- **Evidence:** `design/shots/npcs_1920.png` — the merchant's `E Shop` prompt sits
  directly above the merchant sprite, but the blacksmith's `Talk` panel floats up
  and to the right, roughly +145 / −108 px off the sprite, with a visible gap and
  no pointer connecting them.
- **Expected:** consistent anchoring with the interaction prompt — the two NPCs
  are side by side on the same screen and are positioned by different rules.
- **Narrowed by measurement, 2026-09-29.** The **merchant's menu is anchored exactly
  to the token**: sprite centre-x 899.6, menu top-left (939.75, 459.75) → offset
  **+40.2 / −139.9** against `UITokens.NPC_MENU_OFFSET = Vector2(40, -140)`. The
  blacksmith measures **+145 / −108**. Same component, so the offset value is fine —
  **it is the blacksmith's placement path that never applies it.** Point the fix at
  the anchor source, not at the offset.
- **Check against:** Figma `npc-menu-blacksmith` before moving anything.
- **Not filed:** the menu showing only `Talk` — **D115** (Craft + Enchant) was
  decided 2026-09-29, after this screenshot.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.

### B10 — Dialogue box shows an empty portrait frame and undesigned Auto/Skip buttons
- **Where:** DialogueQuest `dialogue_box.tscn` (`DQDialogueBox`), in gameplay.
- **Evidence:** `design/shots/combat_hud_1920.png`.
- **Empty portrait frame:** a blank brown square sits on the right of the box.
  **Q26's applied default was "hide the empty frame"** — it was never applied.
  D112 later replaced portraits with full-body art, so this frame has no future
  either way.
- **Auto / Skip buttons:** present top-left of the box. [[dialogue_audit]] §1
  records that Figma's `npc-dialog-simple 36:6` has **no Auto/Skip buttons**.
- **Stray glyph:** an orange `!` floats inside the box next to the portrait
  frame, matching nothing in the design.
- **Not duplicated here:** the box being entirely off-theme (no accent border,
  wrong font, magenta speaker name instead of accent gold) is the known unbuilt
  presentation layer — [[BACKLOG]], D110.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.

### B11 — Tutorial hint panel and the skill hotbar overlap
- **Where:** in-game HUD, bottom centre.
- **Evidence:** `design/shots/combat_hud_1920.png` — the hint panel
  *"Use A/D or Arrow Keys to move • Space to jump"* and the 4-slot skill hotbar
  are drawn on top of each other; the hotbar's box cuts through the hint text.
- **Expected:** the two HUD elements do not collide at 1920×1080.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.

### B8 — Menu surfaces are transparent; the parchment map bleeds through (systemic)
- **Where:** not one screen. Confirmed on three so far:
  - **Skills tab** — no surface at all, "No skills available yet." sits on the map.
  - **Shop** — parchment visible through the top of the wares panel and the
    whole left sidebar (`design/shots/shop_buy_1920.png`).
  - **Save / Load** — all four slot cards are see-through, the map runs straight
    through the slot text (`design/shots/save_load_save_mode_1920.png`).
  - **The overwrite confirmation modal** — worst instance found. Panel interior
    measures `(12,11,15)`→`(15,14,18)` and the map's "Shifting Sands" label crosses
    it at y≈522, **directly behind the body text**. Verified arithmetically:
    `0.56×(17,17,24) + 0.44×(12,10,10)` = `(14.8,13.9,17.8)` = the measured value,
    i.e. `SURFACE` `#111118` @56% is doing exactly what it says. A destructive
    confirmation is the worst surface in the app to be see-through.
  - **Inventory empty state** — "No items in this category." sits dead centre over
    the darkest part of the bleed-through in dim grey; the least legible text found
    in any shot.
- **Originally filed as:** `SkillsPanel` in the Game Menu.
- **Expected:** the menu's opaque surface (`UITokens.SURFACE`, `#111118` @56%
  over the backdrop) behind the panel content.
- **Got:** on the Skills tab only `CentralPanel`, `PanelManager` and
  `SkillsPanel` are visible — no surface panel, no `RightPanel`/`PartyStatusPanel`.
  The illustrated parchment world map fills the whole content area and the
  "No skills available yet." text sits directly on it, barely legible.
- **Evidence:** `design/shots/flow/05_tab_skills.png`; panel-visibility dump in
  the same run.
- **Note:** the parchment backdrop is **intended** — `menu_shell.gd:63` documents
  it as *"у Figma — ілюстрована мапа під затемненням"*. What is missing is the
  darkening: `menu_shell.tscn` has a `DimOverlay`, and the legacy
  `vertical_menu.tscn` the Game Menu actually uses has **none** (`grep` → 0).
- **Root cause, shared with B7:** the Game Menu never migrated to `UIMenuShell`.
  The shell carries both the `DimOverlay` this tab lacks and the `ButtonGroup`
  B7 needs. One migration closes both.
- **Severity:** visual
- **Found:** 2026-09-29, **reproduced visually.**

### B4 — `verify_misc_modal.gd` asserts navigation by grepping source; one check cannot fail
- **Where:** `SampleProject/UI/verify_misc_modal.gd:104, 111–120`
- **Expected:** a test named "Tutorial destination still resolves" presses the
  button and asserts where the player ends up.
- **Got:** three of the four Misc destinations are never pressed.
  - `:111–114` opens `game_menu.gd` with `FileAccess` and asserts
    `menu_src.find("TutorialMenuScene") != -1` — a **string search of the source
    file** — plus `ResourceLoader.exists(tutorial_path)`, a file-on-disk check.
  - `:118` Exit asserts `ResourceLoader.exists("res://SampleProject/MainMenu.tscn")`.
  - `:104` `ck(current_scene == null or true, "no scene change")` — `X or true`
    is **always true**. The assertion is incapable of failing.
- **Consequence:** [[BUGS]] **B2** (Tutorial unloads the game into a dead-end
  stub) sits directly under a check called "tutorial route still wired" that
  passes because the *string* is present. The suite cannot catch it, and never
  could. Only `[5] Settings destination` actually drives the UI.
- **Evidence:** run 2026-09-29, `RESULT: ALL PASS` (40 checks) on
  `Godot_v4.6.2-stable_win64_console.exe`. Passing is the problem.
- **Severity:** blocker — a green suite is the reason these shipped.
- **Found:** 2026-09-29, **confirmed by running the script.**
- **Note:** the test otherwise drives the real path (`ServiceLocator` →
  `UIManager.open_game_menu()` → real modal layer), so its Settings result is
  trustworthy. Fixing this means pressing the remaining three buttons and
  asserting the destination, not adding more file-existence checks.

### B1 — 1px card borders drop a row at 1280×720
- **Where:** card styleboxes from `GameUITheme.tres` (border width 1, `UITokens.BORDER_WIDTH`)
- **Screen:** multiple — visible in the slice 8 screenshot pass
- **Expected:** a continuous 1px border on all four sides at any resolution
- **Got:** one border row disappears; sub-pixel scaling of the 1920×1080 logical canvas
- **Evidence:** `design/shots/*_1280.png`
- **Severity:** cosmetic — **but one instance is worse than the label suggests**
- **Found:** 2026-09-27, [[runtime_ui_completion_plan]] slice 8
- **Scoped by pixel scan, 2026-09-29 (agent pass).** Every 1280-only difference
  across four screen pairs traces to this one bug. Nothing clips, overlaps, leaves
  the viewport or becomes unreadable. Worst instances, in order:
  1. **Shop Buy/Sell tabs — a *state* indicator degrades.** At 1920 `Buy` is a
     closed 2px gold rectangle; at 1280 only one gold row plus the left edge
     survive, so it reads as an `L`. `Sell` drops to a top hairline. Selected vs
     default still reads (gold vs grey), but neither reads as a button. This is
     the one worth fixing first — the rest lose containers, this loses meaning.
  2. **Save/Load** — 9 horizontal rules at 1920 become 4 at 1280: all four card
     bottoms and the header rule under the title vanish. Cards read as
     open-bottomed. Geometry is correct (117px card, 11px gap = exactly 0.667 ×
     the 1920 values) — only the borders drop.
  3. **Shop party cards** — bottom borders gone; the empty 4th portrait frame
     falls to a bare corner and looks cut off, though the card is complete.
- **Clean at 1280:** main menu and Game Over — pure proportional scaling, all
  elements present and legible, including the 12px copyright line and the thin red
  rule under "Game Over" (verified present at RGB 140,31,30, invisible only at
  thumbnail size).

---

## Parked observations

Things that look wrong to whoever was testing, but that **no source says are
wrong** — not in Figma, not in a token, not in a mapping, not in a decision.

Parked on purpose. **Do not act on an O-ID.** It does not block a PASS, does not
become a task, and is not a Q-ID — nobody is being asked anything yet. It sits
here until Sapega either turns it into a decision (→ D-ID), a question (→ Q-ID)
or deletes it.

The point: a tester's unsourced opinion is how a screen gets quietly redesigned
by whoever looked at it last. Writing it down costs one line and keeps the
option open without acting on it.

```markdown
### O<n> — <what you noticed>
- **Where:** <screen / node>
- **Why it bothered you:** one sentence
- **No source:** which of Figma / tokens / mapping / decisions you checked
- **Found:** <date>, <who or which run>
```

### O16 — Minimap is hidden at game start and overlaps the HUD once shown
In `shots`-style runs (`capture_tutorial_shots.gd`, 2026-10-12) the minimap is not on
screen after boot; it appears only after the full map (M) is opened and closed, because
the map script sets `minimap.visible = not visible`. When it shows, it sits under the
coin / settings icons of `combat_hud_top` in the top-right corner. The tutorial topic
"The Map" describes the minimap, so this matters to players. Parked — needs a call on
where the minimap lives next to the HUD.

### O15 — Map window toggles tracking on raw `KEY_D`, which is also `move_right`
`Game.tscn` (MapWindow inline script, `_input`): `elif event.keycode == KEY_D: show_delta = not show_delta`
runs on every D press, map open or not, so walking right flips the tracking arrow.
Found 2026-10-12 while writing the tutorial ([[tutorial_mapping]]). Parked — no
visible effect unless the map is open; fix by an InputMap action or a `visible` guard.

### O14 — World Map tab does not read as a map (Sapega, 2026-10-12)
Sapega: "карта в меню гри поки мені не ясна, але то не критично". Parked, not a
defect — no expectation was stated. What the tab shows today
(`shots/flow/06_tab_world map.png`, a fresh game with nothing explored):
- the whole viewport is a grid of **unexplored MetSys cells** drawn over the
  illustrated parchment (`menu_map_background.jpg`); the two layers are unrelated —
  the art's place names are not MetSys rooms ([[world_map_mapping]]: legend and the
  13 named markers have **no backing data**);
- `EXPLORED 000%`;
- the player marker sits at the viewport's top-left corner (x≈318, y≈50), not in a cell.
Before acting, ask Sapega what the tab is for — a MetSys room map, a world/region
overview like the Figma `94:609` art, or both — and check the marker position in a
real save with explored rooms; it may be centring on an empty start.

### O12–O13 — from the scene inventory audit, 2026-09-29
Both are "code where a scene would be conventional". See [[scene_inventory]].
- **O12 — save points are 10 hand-built `Area2D` copies and there is no
  `SavePoint.tscn`.** `Scripts/SavePoint.gd` is attached inline to an `Area2D` +
  `CollisionShape2D` + `Label` triple in each of the 8 live maps
  (`Maps/Canyon.tscn:101`, `Maps/City.tscn:22`, `Maps/DesertRoad.tscn` ×2,
  `Maps/Laboratory.tscn` ×2, `Maps/CityGates.tscn:32`, …) plus
  `Maps/Legacy/StartingRoom.tscn`. **No source requires a scene:** D75/D74 specify
  the prompt and the flow, not the object's packaging. Figma has `prop/save-pillar`
  art, which nothing uses — that is art, not a structural requirement. It bothered
  the reviewer because 10 copies means 10 places to change when the pillar art or
  the prompt label lands.
- **O13 — `NpcActionMenu` is the only `UI/Components/` member with a `.gd` and no
  `.tscn`.** `Scripts/Gameplay/NPCs/NpcBase.gd:22` does `NpcActionMenu.new()`
  against `UI/Components/npc_action_menu.gd:2`; the other ten components in that
  folder are all `.gd` + `.tscn` pairs. `CLAUDE.md` asks for shared reusable
  components and a common Theme, which the code-built menu satisfies — nothing says
  a component must be a scene. Parked, not a defect. Related to [[BUGS]] B40, which
  is a real measurement on this menu.

### O9–O11 — from the NPC / interaction pass, 2026-09-29
- **O9 — pickup modal is ~440×280 design px for ~90px of content**, leaving 84px
  above and 86px below. D100 approves *using* the shared modal family but nothing
  specifies its size. Resolved with B26/B36 (#71, #74): the shared modal now sizes to its content.
- **O10 — Journal's two content columns are ~39px apart** (list ends x=939, detail
  rule starts x=979) — off the 2/4/8/12/16/24/32/48 scale in both directions. No
  Figma measurement exists for this frame.
- **O11 — every sidebar tab sits flush at x=0** inside a 320px sidebar, putting all
  24px of slack on the right. Reads as unpadded against the window edge; no token
  covers a sidebar left inset.

> **Coverage limit, not a finding:** the NPC menu and prompt fixtures render on flat
> `#1b1916` / `#111118`, so prompt legibility **over real world art** is untested.

### O4–O8 — from the save/load pass, 2026-09-29
All measured, none with a source that makes them wrong:
- **O4 — splash prompt colour.** "PRESS ANY BUTTON" measures `#a4a4a5` = white @64%
  over `#050508`, not `TEXT_SECONDARY #a1a1a1`. Almost certainly a mid-pulse frame
  of a fade — its flanking ornaments are pure `#ffffff`.
- **O5 — no text hierarchy on the slot card.** Timestamp, "Kael", playtime, "No save
  data available" and the "SAVE DATA MANAGEMENT" eyebrow all resolve to `#ffffff`.
  `TEXT_SECONDARY` appears only in the bottom hint bar. Needs the frame to call.
- **O6 — date format.** `9/23/2026 00:05` — unpadded US M/D/YYYY beside a 24h clock.
  No format token or decision exists.
- **O7 — modal button voice and default focus.** "Yes"/"No" while the hint bar
  speaks verbs ("Confirm", "Return", "Delete"); and the **destructive** `Yes` is the
  default-focused button. No project source for either.
- **O8 — splash copyright weight.** ~11px legal microcopy renders essentially white
  (brightest `#eeeeee`).

### O1 — Party portraits are flat colour squares, and the fourth is empty
- **Where:** party status panel, all menu screens
- **Why it bothered the reviewer:** three members show flat blue / red / purple
  squares, the fourth ("Три темніх жреца") an empty black one — so even the
  placeholders are inconsistent with each other
- **No source:** placeholder portrait art is a known gap; nothing specifies what
  a missing portrait should look like
- **Found:** 2026-09-29, screenshot review (agent pass)

### O2 — Party names are Cyrillic while the UI language is English
- **Where:** party status panel, visible on every menu screen; the Game tab shows
  English selected
- **Why it bothered the reviewer:** mixed scripts in one frame
- **No source:** character names are content data. `LocalizationManager` ships two
  languages (D67), but nothing says proper nouns are translated
- **Found:** 2026-09-29, screenshot review (agent pass)

### O3 — Controls table labels look a step smaller than Audio/Game row labels
- **Where:** Settings → Controls vs Audio/Game row labels
- **Why it bothered the reviewer:** "Move Up" reads smaller than "Master Volume"
- **No source:** font size cannot be measured off a PNG with confidence, and
  **D48** may cover the widget anyway. Resolve by reading the scene, not the image
- **Found:** 2026-09-29, screenshot review (agent pass)

> **Resolved during triage, not parked:** the bright green HP bar was queried as
> off-palette. It is `UITokens.HP_FILL = #2ecc71` — a real token. Not a finding.

---

## Not in this note

- **Technical debt** — known, accepted, not a regression → [[UI_IMPLEMENTATION_STATUS]]
  § Technical debt (139 `Engine.has_singleton` sites, one of which makes
  `EventBus.player_health_changed` dead; `Player._initialize_health_bar()`
  infinite `call_deferred` recursion; `ModalLayer` has no public close method).
- **Pre-existing test failures** → [[test_baseline]].
- **Figma frames the designer must update** → [[UI_IMPLEMENTATION_STATUS]].
  A stale frame is the designer's task, not a code bug.
