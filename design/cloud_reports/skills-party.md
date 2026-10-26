---
type: cloud-report
branch: cloud/skills-party
date: 2026-10-26
tags: [cloud, ui, skills, status, hud]
---

# Cloud report: skills-party (attributes in Status, the party column over Skills, glowing new-points buttons)

**Summary.** All three parts are built and tested at 1920×1080 and at the smallest window, 1280×720.
**B151 is fixed.** The party column covered the Skills side panel because Status, as it hid after Skills was shown, turned the column back on. Now `game_menu._show_only` alone sets the column, from `metadata/hide_party_column` on the panel.
**D722:** attribute points are spent in Status, next to the stats they change. The rows were moved there from the Skills side panel, along with their logic and signals. The Skills tab keeps only skills.
**D723:** while points wait, two glowing Diablo II-style buttons sit on the HUD under the hero panel («Нові вміння» / «Нові атрибути»). They are opened by a click, K / C, or D-pad left. The Skills and Status sidebar tabs also glow, with a count. Everything goes dark once the points are spent.
**Not done:** no Figma frame was read, because Figma MCP is local-only (MASTER_PLAN rules). The design docs say that neither frame has attribute spending (D691: «not in the frame»; Status `58:719` predates D335), and D716 makes Figma an inspiration only.
D-ID text: D722, D723 (below). B rows fixed: B151 (below). No Q.
Full suite: SUITE_LINE

Base: `origin/feature/backlog` at `bcdc05ea`. `integrator-14` had not merged `cloud/world-map` with a merge commit. Its work is already in `feature/backlog`, rebased and integrated in round 14 (`764ceea3` … `090cb098`, D714/D715). This branch builds on that. Merging `origin/cloud/world-map` again only conflicted on its own report and pin scene, so it was aborted. There is no newer orchestrator note on this task in `MASTER_PLAN.md` or `figma_decision_register.md`; it is only the launch line on 2026-10-26.

## For the registers (the orchestrator applies them)

**B151** (BUGS, fixed): *The party column covers the Skills side panel* (Sapega, playtest 2026-10-26, exported Windows build: «панель скілів закрила панель атрибутів … атрибутів не видно … там наче її закриває паті-панель з Кусакамом»).
- **Repro:** game → Esc → Status → Skills. The party column stayed visible (x 1520–1920) over the side panel (x 1085–1533, squeezed left), so the attribute panel behind «Attributes» could not be seen. Opening Skills straight away, or coming from World Map, was fine.
- **Cause:** `game_menu._show_only` walks `ContentRoot` in child order, showing one panel and hiding the rest. Skills (shown) hid the column, then StatusScroll (being hidden, and later in the order) showed it again. World Map had worked around the same race with a deferred hide.
- **Fix:** the column is set in one place, `game_menu._show_only`, after the switch, from `metadata/hide_party_column = true` on `MetSysMapComponent`, `SkillsComponent` and `StatusScroll` in `game_menu.tscn`. The handlers in `skills_component.gd`, `stats_component.gd` and `metsys_map_component.gd` are removed.
- **Tests:** `verify_new_points` [1] checks six tab paths at both window sizes. `verify_status` [4d] checks that nothing covers the attribute rows.

**D722** (OVERRIDE): **Attribute points are spent in Status** (Sapega, 2026-10-26: «панель скілів закрила панель атрибутів … атрибутів не видно, може через те, що не вміщується», «ну або атрибути треба в статусі виставляти»).
- **Status:** the Attributes section has the four `%AttributeRow`s moved from the Skills side panel: name, what one point gives, spent (+ picked), − / +. They sit in a 2 × 2 grid right above the HP / SP meters and the stat rows they change.
- **Header:** «Attribute Points: N» counts the picks; Cancel / Accept appear while something is picked.
- **Rules, as D330:** + marks; − / pad X / Backspace undoes; Accept (button, pad Y, F) spends; Esc / B with picks drops them; leaving the tab drops them. Reset all (the paid respec, D628) stays on Skills.
- **Skills tab:** keeps only skills. The AttrPanel and the «Attributes N» button are gone. The points bar says «Attribute points: N · in Status» while some wait.
- **Unchanged:** D691's «Attributes behind an Attributes button» is replaced; D335's rules are unchanged.
- **Figma:** neither `533:6472` nor `58:719` has attribute spending, so the layout is an agent call.

**D723** (OVERRIDE): **New points glow, Diablo II style** (Sapega, 2026-10-26: «і треба підсвічувати, щоб воно якось горіло: ось дивись, тут в тебе нові скіл-поінти і очки атрибутів», «може кнопку як в Діабло 2? або як в якихось інших іграх: просто на екрані з'являється підсвічена кнопка, куди натискаєш і переміщуєшся в меню»).
- **HUD buttons:**
  - While the hero has unspent JP, a button «+N Нові вміння [K]» is on the HUD; while he has unspent attribute points, «+N Нові атрибути [C]».
  - They sit under the hero panel at (32, 240), clear of the HP plate, the quick slots, the quest panel and the loot feed.
  - Each is a dark pill (`HUD_INK` 90 %, `HUD_RIM` border) with a soft gold halo (`HUD_GLOW_COLOR`, the ready-slot gold) that pulses every 1.6 s.
  - A click opens the Game Menu right on Skills / Status (the cursor is shown with Alt, as everywhere in play, D417). So do K / C. D-pad left opens the first tab that waits, and the pad glyph shows only on that button.
- **Menu tabs:** the Skills and Status sidebar tabs glow (the arrow plate in gold) with a gold count badge.
- **When nothing shows:**
  - Spent points: everything goes dark and the HUD buttons disappear.
  - Locked tabs: no button while the tab is still locked by the story (`metadata/unlock_flag`).
  - Dialogue: the buttons are hidden, as tutorial hints are.
  - Cutscenes: the buttons are hidden with the whole UICanvas.
  - Fights: the buttons stay, because the HUD hides no hints in fights.
- **Shared component:** `UI/Components/points_glow.tscn`, used by the HUD buttons and both tabs. Tokens are `POINTS_*` / `NEW_POINTS_*`; theme types are `PointsGlow`, `PointsGlowTab`, `PointsBadge(Label)`, `NewPointsButton`, `NewPoints*`.
- **Figma / mapping:** no existing badge or highlight style for this. The only kit glow, «Panel Glow», has no theme counterpart (D623), so the glow reuses the HUD v2 ready-slot gold.
- **Controls:** the actions `open_skills_tab` / `open_status_tab` appear on the Controls page and on the remap list.

## What was done

| Step | Files |
|---|---|
| Party column per tab, one place (B151) | `Scripts/Menus/Game/game_menu.gd` `_show_only`, `Scenes/Menus/Game/game_menu.tscn` (meta on 3 panels); handlers removed from `skills_component.gd`, `stats_component.gd`, `metsys_map_component.gd` |
| Attribute rows moved Skills → Status (D722) | `skills_component.tscn` (AttrPanel out, `AttrPointsHint` in place of `AttributesButton`), `stats_component.tscn` (`AttrHeader` with Cancel / Accept, `AttrRows` grid with the moved `%AttributeRow`; `PointAttrs` gone), `skills_component.gd` (attribute code out), `stats_component.gd` (`_build_attribute_rows`, `_gives_text`, `_refresh_attributes`, pick / unpick / accept / cancel, Esc, F / Y — moved, with its own `SkillPlan`) |
| Shared glow + HUD buttons (D723) | `UI/Components/points_glow.tscn/.gd`, `new_points_button.tscn/.gd`, `hud_new_points.tscn/.gd` (new); `Game.tscn` (under `UICanvas/CombatHUD`); `game_menu.tscn/.gd` (glow on SkillsButton / StatusButton, `is_tab_unlocked()` reads the tab's `unlock_flag` from the scene) |
| Open the menu on a tab | `Scripts/Managers/UI/UIManager.gd` `open_game_menu_on(tab)` |
| Input | `project.godot` `open_skills_tab` (K, D-pad left), `open_status_tab` (C, D-pad left); `controls_component.gd`, `input_options_menu.tscn` |
| Tokens and theme | `UI/Tokens/UITokens.gd` (POINTS_* / NEW_POINTS_*, `FIGMA_FONT_TYPES` + NewPoints*), `UI/build_game_ui_theme.gd` `_new_points()`, `GameUITheme.tres` regenerated |
| uk / en | «Нові вміння», «Нові атрибути», «Очки атрибутів: %d · у вкладці «Стан»», Controls rows, remap names |
| Tests | `verify_new_points.gd` (new), `verify_status.gd` [3b] [4b] [4c] [4d], `verify_attributes.gd` [4]–[6] on Status, `verify_skill_screen.gd` [9], `verify_game_ui_theme.gd` (NewPoints* sizes) |
| Captures | `capture_skills_party.gd` (new: HUD with both buttons, Status opened from the HUD button with a pick, then a click on Skills; at 1920×1080 and 1280×720); `capture_skill_trees.gd` opens the menu with Esc and clicks the tabs, the Paladin shot by Sapega's route Status → Skills (the after-oath «Dark Knight tab» shot is dropped: the player cannot open it, D489, and `show_tree()` from code crashed on it) |

## Tests (RESULT lines)

- `verify_new_points` — ALL PASS (B151 six paths × 2 sizes; HUD only with an open tab; +N / caption / K / C; clear of vitals, hotbar, quest panel, loot feed at both sizes; click (Alt), K, C, D-pad left; pad glyph on one button; tabs glow and badge; stop after Accept / JP spent; buttons gone; hidden in dialogue).
- `verify_status` — ALL PASS ([4b] Accept → Max. HP 290 → 294 on Status, F → Phys. Atk. +1, Esc drops; [4c] D-pad from the tab lands on a row, every − / + of the 4 rows reachable, A / Enter / X / Backspace / Left; [4d] 17 controls in view and uncovered at 1920×1080 and 1280×720).
- `verify_attributes`, `verify_skill_screen`, `verify_skills_ui`, `verify_world_map`, `verify_game_menu`, `verify_locale`, `verify_game_ui_theme`, `verify_scripts_compile` — ALL PASS.
- Full suite: SUITE_LINE

## Shots (`design/shots/skills_party/`)

- `skills_party_hud_1920x1080.png`, `skills_party_hud_1280x720.png` — both buttons under the hero panel (+2 / +10).
- `skills_party_status_*.png` — Status opened by «Нові атрибути»: rows with a pending Vitality pick, Cancel / Accept, the Skills and Status tabs glowing with badges, no party column.
- `skills_party_skills_after_status_*.png`, `fb22_skills_paladin_after_status.png` — Status → Skills: the whole side panel visible, «Attribute points: N · in Status» in the points bar.

## Calls made (Sapega to confirm)

- Keys K (skills, common in many games) and C (character, Diablo II). The pad has one free button, D-pad left, which opens the first tab that waits.
- The glow stays during fights, because the HUD hides no other hint in a fight. Monologue bubbles do not hide it either; only window dialogue does, as with tutorial hints.
- «Нові вміння» uses Sapega's wording, while the tab itself is «Навички».
- A JP that cannot be spent right now (every tree capped, or everything locked by level) still glows, because the prompt says «while he has unspent skill points».
