---
type: report
tags: [cloud, routines, ui, game-menu]
---

# Cloud report: menu-qa (B129–B132, D493)

**Summary**
- **Done:** B129 (Kusakam's dialogue portrait in the Status header, the Equipment "Current character", the party card and the Skills header), B130 (Primary Job = Holy Warrior; Secondary Job = the sworn oath, empty until then; 7 weapon-type icons; crossed-swords stat-row icons; Path Action / Talent hidden), B131 (**removed** the empty frame, the cheaper option), B132 (unexplored cells are not drawn), D493 (arrow-shaped tab plates in Figma's order, "Miscellaneous", Inventory tab "WEAPONS").
- **Not done:** the Status big illustration (waits on art, no placeholder, as asked). There was no Figma MCP in this session, so measurements come from the QA side-by-side shots in `design/shots/menu_qa/`.
- **D-IDs for the register:** D523–D526 (below).
- **B rows fixed:** B129, B130, B131, B132.
- **Theme:** `GameUITheme.tres` regenerated; `verify_game_ui_theme` prints **ALL CHECKS PASSED**.
- **Full suite:** one run, 98 tests, `SUITE: ALL PASS`.

## D-ID text (for `figma_decision_register.md`)

| D523 | ROUTINE CALL | **B131: Equipment loses the empty frame above Attributes** (`cloud/menu-qa`). The two choices were to show the hero in his current gear or to drop the frame. Showing him needs a SubViewport rig of the player body with `WeaponView` and the worn armour, kept in sync with equipping. That is a small system, so the frame (`ArtFrame`, an empty `InsetPanel`) is removed and Attributes moves up. If Sapega wants the hero there, it becomes a BACKLOG row. |
| D524 | ROUTINE CALL | **How B130 is built** (`cloud/menu-qa`). **Primary Job:** the trunk class from `skills.json` → `class.name` (Holy Warrior, D260), through `tr()`. **Secondary Job:** the sworn oath's name (`SkillManager.get_oath()` → `oaths.<id>.name`, D280); until an oath is sworn the column keeps its width but shows nothing (no caption, no box), so the Primary box keeps Figma's width. Status refreshes on `EventBus.oath_sworn`. **Weapon Types:** one box per type the hero can equip, which is every weapon slot of Equipment (`EquipmentManager.WEAPON_SLOTS`: sword, polearm, dagger, axe, mace, bow, staff), each with a 16 px line glyph tinted `UITokens.ACCENT` and the slot's name ("SWORDS" …) as a tooltip. The glyphs are agent-drawn SVGs in the stroke style of Figma's shop sword icon (`Assets/UI/Icons/weapon_*.svg`; the sword is a copy of `shop_cat_sword.svg`, 153:1819). Figma shows two generic icons and no set per type exists, so a designer may redraw them. **Stat rows:** Figma's crossed-swords glyph (`stat_crossed_swords.svg`, agent-drawn) in accent, replacing the grey `IconSlot` squares. **Path Action / Talent:** no such system exists, so the whole "Unique Actions & Talents" section is hidden in the scene; the `%ActionCard` template stays for when one is built. |
| D525 | ROUTINE CALL | **How D493's sidebar is built** (`cloud/menu-qa`). The plate is a scripted StyleBox (`UI/Components/arrow_plate_style.gd`): a rectangle whose right edge meets in a point. The fill is `UITokens.SIDEBAR_TAB_BG` (= BACKGROUND #111118, opaque as in Figma), the line is `BORDER` 1 px, and the tip is `SIDEBAR_TAB_TIP` = 14 px, measured from frame 94:609. Hover and hover-pressed use a gold `BORDER_STRONG` line. Focus is the shared Q33 ring (`FOCUS_RING`, `FOCUS_RING_WIDTH`) in the arrow shape, and `verify_game_ui_theme` [3c] accepts that shape. The active tab is marked only by the ▶ pointer, as in Figma (it used to have a gold left edge). The order is World Map, Journal, Inventory, Equipment, Skills, Status, Miscellaneous. The menu still opens on Inventory (unchanged), and the story locks (D151) are unchanged. Labels come from `metadata/label`; `metadata/tab` keeps the internal names ("Misc"), so code and tests that switch tabs are unchanged. New keys: "Miscellaneous" (uk "Різне"); the Inventory filter key "EQUIPMENT" is replaced by "WEAPONS" (uk "ЗБРОЯ"). The filter still shows weapons **and** armour, because D493 changes only the label. |
| D526 | ROUTINE CALL | **B129: one hero portrait everywhere in the Game Menu** (`cloud/menu-qa`). `CharacterManager.HERO_PORTRAIT` = `Sprites/Player/portrait.tres`, the texture `dialogue_quest/characters/KUSAKAM.tres` uses. It is shown, nearest-filtered, inside the existing frames: Status `AvatarFrame` 96 px, Equipment `AvatarChip` 32 px, the party card `PortraitFrame` 56 px, and the Skills header `AvatarChip` 48 px. B129 does not name Skills, but it had the same purple square. The character's `avatar_color` is no longer drawn in the menu; the frames keep the theme's `ICON_SLOT_BG`. |

## Details

**B129**: `CharacterManager.gd` (HERO_PORTRAIT); `stats_component.tscn`, `equipment_component.tscn`, `skills_component.tscn` (an `Art` TextureRect inside `Avatar`); their scripts lose the `_avatar_box` colour override; `party_status_panel.gd/.tscn` (`_fill_card` without a colour; `Art` always visible). Tests: `verify_party_panel` (hero card shows the portrait), `verify_skill_screen` (no overrides at all now).

**B130**: `stats_component.gd` (`_update_jobs`, `_update_weapon_slots`, `WEAPON_ICONS`, `WEAPON_NAMES`, `oath_sworn`), `stats_component.tscn` (WeaponBox `Icon`, AttrRow `Icon` TextureRect, `%SecondaryJob`, `%ActionsSection` hidden), 8 new SVGs in `Assets/UI/Icons/`.

**B131**: `equipment_component.tscn`, `ArtFrame` removed.

**B132**: `metsys_map_component.gd`: `map_view.skip_empty = true` and `update_all()` after `make_map_view`. The MetSys theme's `empty_space_texture` (`Themes/Exquisite/Empty.png`) was tiled over every cell in view. The addon and its theme are untouched; the HUD minimap keeps its look.

**D493**: `game_menu.tscn` (order, `metadata/label`), `game_menu.gd` (`_apply_localized_labels` reads `label`), `UITokens.gd` (`SIDEBAR_TAB_BG`, `SIDEBAR_TAB_TIP`), `build_game_ui_theme.gd` (`_sidebar_tab`, `_arrow_plate`), `arrow_plate_style.gd`, `inventory_component.gd` ("WEAPONS"), `en.po` / `uk.po`, `verify_inventory`, `verify_game_ui_theme`.

**Tests run on the way:** status, game_menu, party_panel, inventory, skill_screen, world_map, locale, misc_modal, responsive, equipment, game_ui_theme: all `RESULT: ALL PASS` / ALL CHECKS PASSED.

**Shots:** `design/shots/menu_qa/before_after_<tab>.png` for world_map, journal, inventory, equipment, skills, status, misc (left before, right after, 1920×1080 halved). They are made by the new `SampleProject/UI/capture_menu_qa.gd -- <dir>`. Blue item icons in Inventory are the known missing-icon noise (`test_baseline.md`).

**Commit trailer:** this session's own link, not the one in ROUTINE_RULES.
