---
type: report
tags: [cloud, routines, ui]
---

# ui-moments — level-up notification, journal character card, demo finale

**Summary.** All three are built, tested and captured at 1920×1080 on `cloud/ui-moments`. (1) The level-up notification is the
Figma `484:6490` kit panel, top centre, showing one level's real rewards. It queues, fades in and out, and stays silent at the cap.
(2) Journal → Characters is a character card: the lit parchment with the place name, the D321 portrait (nearest), the epithet
and name. ←/→ and ‹ › move between people, and Confirm or a click shows the description. (3) The demo finale fades the HUD,
pans the camera 4 s up into a new deep-blue sky over LaboratoryOutside under a low swell, then shows the main menu's title,
the thanks and a HexButton. **Not done:** the painted illustrations (D486; the portrait stands in, layout unchanged).
**D-IDs:** D623, D624, D625 (text below). **B rows fixed:** none.
**Full suite:** `SUITE: 2 FAIL` on the first run: `verify_locale` (mine, now fixed and `ALL PASS`) and `verify_onboarding` ("keyboard: a light hit does not pass Heavy", which fails the same on `origin/feature/backlog`, so it is not this branch). With the fix that leaves 1 FAIL, already present on the base.

## D-ID text (for the register; next free numbers after D602)

| D623 | ROUTINE CALL | **How D436 is built** (`cloud/ui-moments`). `Scenes/UI/level_up_notification.tscn` is now the kit panel: `LevelUpPanel` (`color/background`, `color/border`, padding 32/24, 320 px), `LevelUpTitle` "LEVEL UP" (Bold 24 + tracking 3, accent, uppercase; uk «НОВИЙ РІВЕНЬ»), `LevelUpRule` 1 px accent 240 px, `LevelUpLevel` "Level N" (Bold 36), and four rows `LevelUpRowLabel` (Regular 16, text-secondary) / `LevelUpRowValue` (SemiBold 16, status/increase). The theme comes from `UITokens` (`LEVEL_UP_*`), with no overrides in the scene. The rows read the real per-level grant every time: Max HP and Damage from `XPManager.stat_bonuses`, Attribute Points from `AttributeManager.points_per_level` (`attributes.json`), Job Points from `SkillManager.JP_PER_LEVEL`. Top centre, 120 px down, clicks pass through. Fade in 0.3 s, hold 3 s, fade out 0.3 s, and the game is not paused. Each `player_leveled_up` is queued, so a two-level jump shows Level 3 then Level 4. Reaching level 20 shows once, and XP at the cap emits nothing (D541), so nothing shows. **Calls:** the Figma "Panel Glow" has no theme counterpart yet, so the panel is flat like the shot. The text uses the menu font scale (×1.25), not the HUD's ×1.5 (D474 lists only the vitals, hotbar and quest panels). Test `verify_level_up.gd`. |
| D624 | ROUTINE CALL | **How D486 is built** (`cloud/ui-moments`). Journal → Characters no longer shows the list and text pane; it shows `%PersonCard` inside the Game Menu shell. The tabs, heading and bottom bar stay, so Q/E and LB/RB still switch sections. The Figma frame is full-screen; here the card fills the journal's content area. **Left (55 %):** the parchment `menu_map_background.jpg` at 1.6× cover, slid so the meeting place sits as near the centre as the edges allow. Over it, `journal_map_light.gdshader` darkens everything (`CARD_SHADE`) outside a soft circle around the place (`CARD_LIGHT_RADIUS` 0.16, softness 0.20). Top left is the place name (`CardPlace`, SemiBold 14, accent, uppercase); top right is the pager "‹ 2 / 4 ›". **Right (45 %):** the illustration slot. Until the painted art exists it shows the D321 portrait, scaled with nearest filtering, and the art can later replace the texture without layout changes. Under it, right-aligned, are the epithet (`CardEpithet`, SemiBold 16, tracking 6, accent, uppercase; the `title` from `journal_people.json`) and the name (`CardName`, Bold 48). **Input:** the card is one focus stop. ←/→ step through the people met (it wraps), A/Enter or a click opens and closes the description (`SidePanel` over the parchment, 560 px), ↑ goes to the tabs and ↓ comes back. The mouse uses ‹ ›. Bottom bar: "Left / Right: another person. Confirm: read about them." **Where you met them** is story data, not saved state. Each person in `journal_people.json` gets `met_in`, and `places` maps the place to a title and a parchment point (fraction 0..1): Village — Zahra's Rest (0.69, 0.47); Desert Road (0.63, 0.40); City Gates (0.60, 0.56); City — Oasis of Qadira (0.56, 0.52); Laboratory — Cells — the lower Al-Kazar ruin (0.74, 0.63). Malik, the prisoner, the alchemist and the three companions are met in the cells; the grandfather in the Village; the guard at the gates; the merchant on the Desert Road; the smith and the oath keepers in the City. The parchment is decorative (D42), so the points are an agent call, placed to follow the story's order. Test `verify_journal_sections.gd` [2], [6] and [7]. |
| D625 | ROUTINE CALL | **How D473 is built, in D587's tone** (`cloud/ui-moments`). `DemoEndScreen.play_finale(music, sky_top)` is called by `LaboratoryOutside`. (1) Control is already off (the screen holds the hero), and every other node in the `UI` and `UICanvas` layers fades to 0 over 0.5 s. (2) The camera leaves the hero (as `Cutscene.detach_camera`), and `limit_top` drops to the new `HighSky`. Over 4 s, with sine in-out, it rises until the sky's top is the top of the frame. Meanwhile the room's music (`dunes_of_silence`) swells only +4 dB and drops in pitch to 0.94: a low, slightly darker swell, not a fanfare. (3) A dark shade (`UITokens.OVERLAY`) and the main menu's title block ("KHALAHAS / HEROES" between the gold rules, the same theme types) fade in over 2 s. (4) Then come the thanks, "Thank you for playing — you have finished the demo" (`FinaleMessage`, Regular 20; uk «Дякуємо за гру — ви пройшли демо»), and the kit HexButton "RETURN TO MAIN MENU" (`ModalButton`/`ModalButtonOn`). The button is off and unfocused until then, and gets focus at the end (`finale_shown`). **The sky:** `LaboratoryOutside.tscn` gets `HighSky`, a gradient 720 px tall above the backdrop. It runs from the backdrop's own top colour (#C4DBE7) up to a deep cursed blue (0.13, 0.24, 0.52). Above it are thin `HighClouds` (Canyon's cloud strip at 60 %). The deep blue and the dark shade give the quiet, ominous ending D587 asks for; Sapega to confirm the tone. Instancing the screen alone (tests, locale scan) still gives the plain card with focus. **Seen while testing:** a pending tutorial window that opens after the closing talk pauses the game, and the finale waits behind it until it is closed. That is correct, but worth knowing. Tests `verify_demo_end.gd` [1b], `verify_lab_route.gd` [6]. |

## Details

### 1. Level-up notification (D436)
- `SampleProject/Scenes/UI/level_up_notification.tscn` — rebuilt on theme types; `notification_panel.tres` and the hardcoded
  colours/sizes are gone from it (the companion notification still uses that stylebox).
- `SampleProject/Scripts/UI/LevelUpNotification.gd` — queue, real rewards, fade 0.3 / 3 / 0.3, translation refresh.
- `SampleProject/UI/build_game_ui_theme.gd` `_level_up_kit()`, `UITokens.gd` `LEVEL_UP_*`.
- Test: `verify_level_up.gd` — `RESULT: ALL PASS` (hidden at start; values = XPManager / attributes.json / SkillManager;
  fade; 120 px, centred, 320 wide; not paused; two levels queue; level 20 once, nothing at the cap; no overrides).
- Shots: `design/shots/ui_moments_level_up.png` (City, next to `figma_level_up_notification.png`). Matches the frame;
  the text is ×1.25 larger than Figma, as on every menu surface (D166).

### 2. Journal character card (D486)
- `SampleProject/Scenes/Menus/Game/journal_component.tscn` — new `PersonCard` (MapView / Parchment / Light / PlaceMargin /
  AboutPanel, PortraitSide / Illustration / NameBlock).
- `SampleProject/Scripts/Menus/Game/journal_component.gd` — `_show_person`, `_place_parchment`, `show_next_person`,
  `toggle_description`, `_on_card_input`; Quests and Bestiary keep the list + text pane.
- `SampleProject/Scripts/Systems/journal_records.gd` `people()` → `place {title, map}`; `journal_people.json` `met_in` + `places`.
- `SampleProject/Shaders/journal_map_light.gdshader`; theme `_person_card_kit()`; tokens `CARD_*`.
- Tests: `verify_journal_sections.gd` — `RESULT: ALL PASS`; `verify_journal.gd`, `verify_story_journal.gd` — `ALL PASS`.
- Shots: `design/shots/ui_moments_journal_card.png` (Grandfather, Village), `ui_moments_journal_card_description.png`
  (Merchant, Desert Road, description open). Against `figma_journal_character_detail.png`, the differences are all
  listed in D624 (in the shell, not full-screen; the portrait stands in for the illustration; the pager row is added).

### 3. Demo finale (D473, D587)
- `SampleProject/Scenes/UI/DemoEndScreen.tscn` / `Scripts/UI/DemoEndScreen.gd` — the title block, farewell, HexButton,
  `play_finale()`; `Scripts/Gameplay/Scenes/LaboratoryOutside.gd` calls it; `Maps/LaboratoryOutside.tscn` HighSky + HighClouds.
- Tests: `verify_demo_end.gd` — `RESULT: ALL PASS` (HUD faded, camera detached and up to the sky top, music louder and
  lower, title + farewell shown, main-menu title size, focus on the HexButton); `verify_lab_route.gd` — `ALL PASS`
  (waits for the finale, then pad A → main menu).
- Shots: `design/shots/ui_moments_finale_pan.png` (mid-pan), `ui_moments_finale_end.png` (title over the cursed sky).

### Suite fixes along the way
- `verify_locale` failed 4 checks after the first run. (a) `uk.po` had no blank line after "This tree's JP cap is reached (%d JP).", so
  `po_sync.py` swallowed the key and dropped it from `en.po`. The separator is restored and the key is back in both files.
  (b) The card's placeholder texts ("CITY GATES", "THE COMPANION", "Name") are removed from the scene, since the script fills them.
  (c) The locale walk calls `show_notification(level)`, which is kept as the public entry point (it queues).

### Other
- `SampleProject/UI/capture_ui_moments.gd -- journal|level_up|finale` makes all the shots.
- New po keys (en + uk): LEVEL UP, Max HP, Damage, Attribute Points, Job Points, City, the thanks line, the card hint.
