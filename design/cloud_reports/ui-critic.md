---
type: report
tags: [cloud, routines, ui]
branch: cloud/ui-critic
date: 2026-10-26
---

# Cloud report: ui-critic (the critic's round-13 notes, passed on by Sapega)

**Summary.** All six notes are fixed at the root, one commit each, on `cloud/ui-critic` (from `feature/backlog` de1bdb85).
**Nothing was run.** The permission classifier refused to run the downloaded Godot 4.6.2 binary, and no other Godot is installed.
That means no import, no verify, no capture and no full suite. The tests and the capture script are written but have never run.
`integrator` has to run them before merging. **D-IDs:** D731 (hint banner place and fit), D732 («?» tips like L2), D733 (training like Tails of Iron),
D734 (equipped mark + Unequip), D735 (NPC menu / choices W/S, hero held), D736 (click-through dialogue). Text below.
**B rows fixed:** B151 (hint banner overflows, sits on the hero), B152 (inventory hides what is equipped, re-equips). Text below.
**Full suite:** not run (no Godot in this session). **MASTER_PLAN** §3: rows UC1–UC6 added as 👀 → `integrator`.

## Commits

| # | Commit | Note |
|---|---|---|
| 1 | `9984499b` B151 / D731 | the hint banner fits its text and sits at the top, off the hero |
| 2 | `a0dbb54a` D732 | tips arrive as glowing «?» at the left edge |
| 3 | `35a0d27c` D733 | combat training as a short sparring |
| 4 | `7e3ebbe5` B152, D734 | Equipped badge, Unequip on a worn item |
| 5 | `9de4c3f6` D735 | W/S / arrows / pad in NPC menus and choices; the hero stays still |
| 6 | `a5fe5d85` D736 | press completes the line, hold runs to the next choice |
| — | `75a412b3` | `capture_ui_critic.gd` |

## D-IDs for the register (orchestrator applies them)

| ID | Kind | Text |
|---|---|---|
| D731 | ROUTINE CALL | **Where the in-game hint banner sits and how it grows** (B151; critic, round 13, passed on by Sapega 2026-10-26: «Текст підказки не влазить, це дивно, і чому він на персонажі»). Figma has no in-game hint frame (`tutorial_mapping.md`: `135:1260` is the menu page). The banner now sits **top-centre, under the quest panel** (`TutorialHintDisplay.tscn` → `Banner/Panel`, top 112 px). It has a fixed width `UITokens.HINT_BANNER_WIDTH` (720) and grows **down** to fit its text. It slides in from above by `HINT_BANNER_SLIDE`. It no longer sits bottom-centre, where the camera keeps the hero. Root of the overflow: the text was set while the node was hidden, and Godot keeps the old minimum size for a hidden node (the same root as B122). So the panel's offsets are refit to the text on every text or visibility change. |
| D732 | OVERRIDE (of D289's "every hint is a tutorial window") | **Tutorial tips as «?», like Lineage II** (critic, round 13: «Дуже багато туторіалів вискакує, може не так прям на весь екран, а питаннями, як в L2?»; Sapega passed it on 2026-10-26). A first-time hint topic no longer opens the tutorial window over a paused game. It adds a glowing «?» to `UI/Components/tip_tray` at the left edge, under the hero panel (24, 246). The style is the theme's `KeyBadge`, and tokens `TIP_ICON_SIZE`, `TIP_TRAY_GAP`, `TIP_GLOW`, `TIP_GLOW_TIME` set the size, gap and pulse. Several «?» stack, oldest on top, and the game keeps running. A click on a «?», or the new action **`open_tip`** (keyboard T, pad D-pad left; the key shows on the top «?»), opens the D126 tutorial window on that topic, paused, and that «?» goes. Only **movement and attack** still show directly: a brief banner (4 s) once no dialogue, modal or menu is up. Sticky prompts (Healing Palm, call the guard, grandfather's gift) stay banners until done, because they ask for an action now. Settings → Game → Tutorial Windows **Off** turns every tip into a banner, as before. Every topic keeps its text and its trigger, and it still joins the Tutorial list when it fires. `open_tip` is on the Controls page and in the remap list. Pending «?» are not saved: the topics are already in the Tutorial list. |
| D733 | OVERRIDE (of D-28d "back mid-fight → lessons from the first") | **Combat training as a sparring, like Tails of Iron** (critic, round 13: «Тренування роздратує, подивись як в Tails of Iron — там тренування як тренування»; Sapega passed it on 2026-10-26). The same four lessons, checks, no-death rule and immediate move to the next lesson (D503). New: each lesson shows **one line** on the banner (`prompt` in `tutorial.json`, en/uk: «1/4 · Left Mouse three times quickly · Tab: skip», «2/4 · His weapon glints: dash Shift or hold Ctrl», «3/4 · Yellow glint: tap Ctrl as the blow lands», «4/4 · R while he is not swinging»). The full lesson text stays in the Tutorial list. A passed lesson sets the quest flag `training_<lesson>_done` (saved) and **never repeats**. Leaving the Village mid-training, or skipping it (cutscene_skip), and coming back to the live bandit picks the training up at the first lesson not yet passed. A training with every lesson passed ends at once. Other tips during the fight are «?» (D732), so nothing pops up over the sparring. |
| D734 | GAP (the kit's UI/Badge `222:4746` reused) | **The inventory shows what is worn and offers Unequip** (B152; critic, round 13: «Не видно в інвентарі, що спорядження споряджене, але коли клацаю, то постійно «споряджено», хоча воно і так споряджене»; Sapega passed it on 2026-10-26). Worn items stay in the bag (as before). Their row now carries an **Equipped** badge (`item_row.tscn` → `Row/EquippedBadge`, the theme's `LevelBadge` = UI/Badge: accent fill, bold caption) before the count. Its use hint reads "Equipped — double-click or Enter to unequip (slot)". Enter, a double click or pad A on it **unequips** it through `EquipmentManager.unequip_item`, and the bar says "… unequipped — slot.". Once more equips it again ("… equipped — slot."). The badge follows `equipment_equipped` / `equipment_unequipped` at once. No confirmation step, the same as equipping (D286). |
| D735 | OVERRIDE (amends D155 and D454) | **NPC menus and dialogue choices from the keyboard; the hero stays still** (critic, round 13: «Меню NPC — треба дати можливість з клавіатури перемикатись по ньому (W/S або вгору/вниз), при чому не задіювати анімації персонажа»; Sapega passed it on 2026-10-26). New shared helper `UI/Components/menu_nav_keys.gd`: **W/S, the arrows and the D-pad** step the focus in a vertical list. The left stick stays the hero's (D155). The NPC action menu still opens by itself (D454) with the first row focused, while the hero runs past (A/D, stick, Space / A jump). **The first menu key takes the menu**: the focus moves, and until a row is picked (E / Y, Enter, Space, A) or the menu is closed (Esc / B), the hero takes **no movement or action input**. No walking, jumping, attack or dash animations play behind the menu: `NpcBase` holds him with the dialogue lock, `set_movement_enabled`. It lets go on close, on leaving the room, and never while a dialogue has already started. The Quest list and the oath confirmation are taken at once. W/S also step dialogue choices (the addon's choice menu) and the rows of the shop, crafting and enchanting screens. Confirm / back as before. Trade-off, recorded: near an NPC, W takes the menu instead of jumping; Space still jumps. |
| D736 | OVERRIDE (of D254 "while a line types, Next does nothing") | **Dialogue can be clicked through** (critic, round 13: «Якщо ми хочемо проклацати діалог, то треба дати можливість його проклацати»; Sapega passed it on 2026-10-26). In every dialogue window (talks and replays), a press of Next while a line is typing shows the whole line at once, and the next press goes to the next line. **Holding** Next (`dq_accept`: Enter, left click, pad A) for `UITokens.DIALOGUE_HOLD_SKIP` (0.45 s) runs the lines every `DIALOGUE_SKIP_STEP` (0.08 s) **up to the next choice**. A choice is never skipped. Once a choice has shown during a hold, only a new press goes on. The release after a run is swallowed. A hold counts only from a press made with the box open, so the A that picked Talk does not run the talk. The Controls page says "Next line of dialogue (hold: run to the next choice)". The Auto/Skip buttons stay out (B10). Speech bubbles are unchanged. |

## B rows (for BUGS.md, both fixed)

| ID | Sev | Where | Text | Status |
|---|---|---|---|---|
| B151 | P2 | `Scenes/UI/TutorialHintDisplay.tscn`, `Scripts/UI/TutorialHintDisplay.gd` | The tutorial hint banner overflowed its box (long uk texts hung out) and was drawn over the hero, e.g. the block/parry hint on DesertRoad and the combo lesson in the Village. Critic, round 13: «Текст підказки не влазить, це дивно, і чому він на персонажі». Root: the text was set while the node was hidden, so its minimum size was stale (as in B122), and its fixed place was bottom-centre, where the camera keeps the hero. | ✅ fixed in `cloud/ui-critic` 9984499b (D731); `verify_tutorial_hints` [6] written, not run |
| B152 | P2 | `Scripts/Menus/Game/inventory_component.gd`, `UI/Components/item_row.*` | The inventory did not show which gear is worn. Enter on a worn item equipped it again and said "… equipped" every time. Critic, round 13: «Не видно в інвентарі, що спорядження споряджене, але коли клацаю, то постійно «споряджено»». | ✅ fixed in `cloud/ui-critic` 7e3ebbe5 (D734); `verify_use_item` [5b] written, not run |

## What is not done / for integrator

- **Run everything:** the touched verifies first, then `Scripts/Tools/run_verify.sh | grep -v '^PASS'`. They are
  `verify_tutorial_hints`, `verify_companions`, `verify_onboarding`, `verify_use_item`, `verify_npc_arrival`, `verify_npc_flow`,
  `verify_npc_recall`, `verify_gamepad_parity`, `verify_dialogue_speaker` and `verify_locale` (new en/uk keys, the `prompt` data field,
  the Equipped badge, the «?»). Also `verify_game_ui_theme`: no theme change, only reused variations `KeyBadge`, `TutorialKeyLabel`,
  `LevelBadge`, `LevelBadgeLabel`, so no regeneration was needed. And `verify_settings`: the dialogue box `_process` is now also called
  standalone.
- **Captures:** `capture_ui_critic.gd` → `design/shots/ui_critic/` (hint_tray in uk, lesson, inventory, npc_menu, dialogue). Not taken.
  Compare against the D731 placement; Figma has no in-game hint frame.
- **Figma:** not reachable from the cloud. Two things to look at on the PC: the «?» look (KeyBadge + bold «?», pulse to warm gold),
  and the Equipped badge (UI/Badge `222:4746`).
- The rows UC1–UC6 in `MASTER_PLAN.md` §3 are 👀 until the tests run green.

## Files

- New: `UI/Components/tip_tray.gd|tscn`, `UI/Components/menu_nav_keys.gd`, `UI/capture_ui_critic.gd`.
- Changed: `Scripts/UI/TutorialHintDisplay.gd`, `Scenes/UI/TutorialHintDisplay.tscn`, `Scripts/UI/tutorial_topics.gd`
  (`prompt`), `Resources/Data/tutorial.json`, `Resources/Translations/{en,uk}.po`, `data_fields.json`, `UI/Tokens/UITokens.gd`
  (`HINT_BANNER_*`, `TIP_*`, `DIALOGUE_HOLD_SKIP`, `DIALOGUE_SKIP_STEP`), `project.godot` (`open_tip`),
  `Scripts/Menus/Game/controls_component.gd`, `Scenes/Menus/Game/input_options_menu.tscn`,
  `Scripts/Gameplay/CombatTraining.gd`, `Scripts/Gameplay/Scenes/Village.gd` (comment), `UI/Components/item_row.*`,
  `Scripts/Menus/Game/inventory_component.gd`, `UI/Components/npc_action_menu.gd`, `Scripts/Gameplay/NPCs/NpcBase.gd`,
  `OathKeeper.gd`, `Merchant.gd`, `Scripts/Shop/shop_ui.gd`, `Scripts/Crafting/{crafting,enchanting}_ui.gd`,
  `addons/dialogue_quest/.../choice_menu.gd`, `Scripts/UI/GameDialogueBox.gd`, `Scenes/DialogueSystem.tscn`.
- Not touched: `SampleProject/Maps/*`, the HUD unspent-points buttons, the attributes panel, `playthrough.gd`,
  and the registers (BUGS / decision register / BACKLOG / remaining_work), per ROUTINE_RULES.

## RESULT lines

None. Godot could not be started in this session.
