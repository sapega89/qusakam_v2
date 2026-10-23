---
type: report
status: done
tags: [cloud, hud, ui, combat]
---

# Cloud report — `cloud/hud-v2` (2026-10-23)

**Summary.** HUD v2 is built (pillars 3 and 4). The hero panel v2 is top left with the F chip (the assist) and the Q
chip (potions). The 8-slot hotbar is at the bottom centre, and the full-width XP bar runs along the bottom edge.
`SkillManager.SLOT_COUNT` is 8, on keys 1–8. On the pad, slots 5–8 are LT held plus RT / R3 / L3 / Back, and the
assist is an LT tap. The ready glow is drawn by the engine. Old 4-slot saves are padded to 8 with no special path.
**Not done:** painted skill icons (D550, the slots keep today's placeholder square); the Skills screen's "Put on the
hotbar" grid now has 8 buttons in 2 columns (4 rows), and it has no Figma frame. D-ID text: D603–D607 below, plus one
Q-ID. No B rows fixed. **Full suite:** 101 PASS / 1 FAIL. The one failure is `verify_onboarding` "keyboard: a light hit does not pass Heavy", which fails the same way on `origin/feature/backlog`.

Branch `cloud/hud-v2` from `origin/feature/backlog` @ `62dd198f`. Spec: [[combat_hud_mapping]] → *HUD v2 hero panel*,
*HUD v2 hotbar, 8 slots*, *HUD v2 XP bar*.

## D-ID text (for the orchestrator, next free numbers)

| ID | Kind | Text |
|---|---|---|
| D603 | ROUTINE CALL | **The hero panel v2 as built** (`cloud/hud-v2`; D453, D476, D485, Figma `501:6611`). `player_vitals_panel.tscn` is a 520 × 198 Control at (24, 24). Every element sits at its Figma px: plate, the portrait clipped to the hexagon by a `Polygon2D` (`clip_children`) over `HUD_PORTRAIT_BG`, the ring, the level diamond with the bare number (no "LV."), the name, the class (the sworn oath's name, before the oath the trunk class, as Status D532, refreshed on `oath_sworn`), the 60 % rule, the HP and SP rows and the mirrored curl. There is no ST row (D551) and no XP row (D552). The bars are theme types `HudHpBar` / `HudSpBar`: black 60 % track, 1 px `HUD_RIM` border, the fill inset 1 px with a 3 px top band of white 25 % mixed into the fill colour. The hurt shake of the HP row (4b) is kept. **Q chip:** `chip.svg` with the healing potion item icon (`Icons/Items/potion.png`; Figma's line flask has no asset), the count `×N` in the `HudCountPill` pill (all healing potions, `QuickPotion.count()`, D538), and the key badge from the device. The old `Q  Potions ×N` line is gone. |
| D604 | ROUTINE CALL | **The F chip: the assist moved off the hotbar** (D549, D525). `hud_assist_chip.gd` on `AssistChip` keeps the three D525 states. **Ready:** the next companion's portrait, clipped to the inner hexagon, and a gold badge. **Active:** the companion on the field and an engine glow around the chip that pulses over `ASSIST_PULSE_TIME` (0.8 s); the badge dims to `HUD_BADGE_NEUTRAL` 0.45. **Cooldown:** the next one, dimmed to 0.55, with the seconds. A refused press shakes the portrait and the seconds ±4 px for 0.24 s, as before. With nobody in the party, the chip is hidden. |
| D605 | ROUTINE CALL | **The 8-slot hotbar as built** (D549, Figma `497:6587`). `skill_hotbar.tscn` is 780 × 124, anchored bottom centre and 14 px off the bottom edge, so at 1080p it sits at (570, 942), 4 px above the XP bar. It holds the plate, both curls, the centre diamond and 8 instances of `hotbar_slot.tscn` at Figma x 78…306 and 410…638. Per slot: `slot.svg`; the icon at (18, 14) 28 × 28 (today's placeholder square until D550, hidden when empty); the SP gem at (50, −6) with the cost (hidden at 0 SP); the key badge at (21, 55); `cooldown.svg` with the seconds in Figma's format ("2.1" below 10 s, whole seconds above). **Ready** (the `SkillManager.can_use_skill` verdict is OK) shows `slot_ready.svg` plus a soft gold glow drawn by the engine (`hud_hex_glow.gd`: the hexagon outline in 6 layered antialiased strokes, `HUD_GLOW_*`, matched to `figma_hotbar_slot_ready_2x.png`). **Unavailable** dims the whole slot to 0.4, as before. **Empty** is the bare hexagon. Figma draws an ⊗ in empty slots; the spec says nothing in it, so the spec wins. `SkillManager.SLOT_COUNT` = 8. A 4-slot save is padded by the existing `_loadout()` normalisation. |
| D606 | ROUTINE CALL | **Slots 5–8 on the gamepad: LT is the shift** (provisional, D549 "two sets of four behind the triggers"). Every pad input is taken in play (D272), and face-button chords would also jump or attack, because `PlayerMover` polls `jump`. So slots 1–4 stay on **RT / R3 / L3 / Back** (D272), and the same four buttons with **LT held** are slots 5–8. `skill_slot_5…8` have keys 5–8 and the same pad events as 1–4 in `project.godot`. `Scripts/UI/skill_slot_input.gd` decides: a pad event that belongs to two slots goes to 5–8 while LT is held, otherwise to 1–4. A rebound slot with its own button just works. **The assist** on the pad fires when LT is released, if no slot 5–8 was cast during that hold. The F key still fires on press. Badges read `LT+RT` … `LT+Back` while a pad is in use. Misc → Controls reads "LT + RT". Settings → Controls lists Skill Slot 5–8. The Skills screen assigns with the same rule. |
| D607 | ROUTINE CALL | **The XP bar as built** (D552, Figma `515:6662`). `hud_xp_bar.tscn` is a `ProgressBar` under `UICanvas/CombatHUD`, anchored to the bottom edge across the full width, 10 px tall (`HUD_XP_HEIGHT`). The theme type `HudXpBar` gives a black 60 % track with a 1 px `HUD_RIM` top rim and an `ACCENT` fill under the rim with a 2 px band of white 25 %. No label, no numbers, no texture. The value is `XPManager.get_xp_percentage()`, which is full at the cap (D541), refreshed on `xp_gained` (`restore` emits it too) and `level_up`. **HUD v2 text is at Figma size:** the nine HUD v2 label types are listed in `UITokens.FIGMA_FONT_TYPES` and skip the D166 ×1.25 and D474 ×1.5 scaling. At ×1.5 the name ran into the class and "100 / 100" overlapped the bar (first capture). The tiles are drawn for these sizes at 1080p. See Q below. |

**Q-ID (non-blocking, for `questions_for_sapega.md`):** "Should the HUD v2 text be bigger than Figma? D474 asked for
×1.5 on the HUD, but the v2 tiles are drawn for Figma sizes, so ×1.5 makes the text collide. Default as built: Figma
sizes. The alternative is to scale the whole hero panel and hotbar together (for example ×1.25), which needs a new
placement (the hotbar would no longer fit 4 px above the XP bar)."

## What changed (file:line)

- `SampleProject/UI/Tokens/UITokens.gd`, end of file: the HUD v2 block (`HUD_GOLD_LIGHT`, `HUD_TEXT_SOFT`, `HUD_RIM`,
  `HUD_INK`, `HUD_PORTRAIT_BG`, `HUD_RULE`, `HUD_BAR_*`, `HUD_XP_HEIGHT`, `HUD_GLOW_*`, `HUD_BADGE_NEUTRAL`,
  `SIZE_HUD_*`, `FIGMA_FONT_TYPES`). `STAMINA_FILL` is removed (its only user was the ST row, D551). The HUD types leave
  `INGAME_FONT_TYPES`.
- `SampleProject/UI/build_game_ui_theme.gd`: the label roles `VitalsName` (spaced Bold 26, gold light), `VitalsLabel`,
  `VitalsValue`, `BindBadge`, `CooldownLabel` and the new `HudClass`, `HudLevel`, `HudSpCost`, `HudCount`. `_hud_v2()`
  adds `HudHpBar`, `HudSpBar`, `HudXpBar` and `HudCountPill`. `_scale_fonts` skips `FIGMA_FONT_TYPES`. The theme is
  regenerated.
- `SampleProject/UI/Components/player_vitals_panel.tscn` / `.gd`: the hero panel v2 (D603).
  `hud_assist_chip.gd`: the F chip (D604). `hud_hex_glow.gd`: the engine glow.
- `SampleProject/UI/Components/skill_hotbar.tscn` / `.gd` and `hotbar_slot.tscn`: the hotbar (D605). The assist code
  left the hotbar.
- `SampleProject/UI/Components/hud_xp_bar.tscn` / `.gd`, placed in `SampleProject/Game.tscn` → `UICanvas/CombatHUD/XpBar`
  (D607). The `SkillHotbar` instance's old offset overrides are dropped, so the scene's own anchors apply.
- `SampleProject/Scripts/UI/skill_slot_input.gd` (new, preloaded): event → slot and badges (D606).
  `Scripts/Player.gd` `_unhandled_input`: the assist on an LT tap. `Scripts/Menus/Game/skills_component.gd`
  `_unhandled_input`: assignment through the helper. `controls_component.gd`: rows for slots 5–8, pad "LT + RT".
- `project.godot`: `skill_slot_5…8`. `Scenes/Menus/Game/input_options_menu.tscn`: the four actions in Settings → Controls.
  `en.po` / `uk.po`: "Skill slot 5…8" and "Skill Slot 5…8" («Слот навички 5…8»).
- `Scripts/Managers/Gameplay/SkillManager.gd:625` `SLOT_COUNT := 8`.

## Tests

- `verify_hotbar`: 8 slots and 8 loadout entries, slots 0–7 valid, keys 1–8, a 4-slot save padded to 8 with the first
  four kept, slot 8 equips and slot 9 is invalid. The hotbar is 780 × 124 with the two groups at Figma x, the centre
  diamond, the mirrored curl and the bare empty slot. Ready ring and glow, the SP gem cost, the cooldown seconds.
  **[11b]**: RT → slot 1, LT + RT → slot 5 (and the LT hold is spent), LT + Back → 8, Back → 4, key 6 → 6, and the pad
  badges `RT` / `LT+RT` / `LT+Back`. RESULT: ALL PASS.
- `verify_combat_hud` [9]: no XP or ST row. The XP bar is in the HUD, full width, 10 px on the bottom edge, with no
  label and themed styleboxes; it follows `xp_gained`, equals `get_xp_percentage()` and is full at the cap. The level
  diamond follows the level-up. The hotbar is centred 4 px above the bar. **[9b]**: the panel at (24, 24) 520 × 198,
  the hero portrait nearest and clipped, the class text, the mirrored curl, the Q chip count and key, the chip
  positions and the HP fill highlight. RESULT: ALL PASS.
- `verify_companions`: reads the F chip (`%AssistChip`, `shown_state()`, `shake_offset()`). RESULT: ALL PASS.
- `verify_game_ui_theme`: the HUD v2 types carry their Figma sizes. `verify_gamepad_parity`: slot 5 reads `LT+RT` and
  the F chip reads `LT`. `verify_combat_player`: no ST row; the Q chip counts the potions. `verify_full_regression`:
  the name size token.

Full suite (`run_verify.sh`, once at the end): 99 PASS / 3 FAIL on the first run.
- `verify_progression` read the old HUD XP row. It now checks that the new XP bar is full at the cap.
- `verify_skill_trees` compared the loadout with four empties. It now checks that every slot is empty.
- Both pass on a re-run, so the suite stands at **101 PASS / 1 FAIL**.
- The one failure is `verify_onboarding` [lesson_heavy] "keyboard: a light hit does not pass Heavy". It fails identically
  on a clean `origin/feature/backlog` worktree, so it is pre-existing and not caused by this branch.
- Also touched for the v2 HUD: `verify_progression` [1] and `verify_skill_trees` (respec).

## Shots

- `design/shots/hud_v2_vs_figma.png`: Figma (`figma_hud_v2_context.png`, stretched to 1080p) on the left, the game on
  the right, for the hero panel and the hotbar. Slot 1 is ready (with the glow), slot 2 is cooling down, slot 5 has no
  weapon for Electric Strike (dimmed), 4 and 8 are empty, and the F chip shows Alisia ready.
- `design/shots/hud_v2_1920x1080.png` and `hud_v2_1280x720.png`: the whole HUD (`capture_hud_v2.gd`). At 720 it scales
  with `canvas_items`.
- **Remaining visual differences.**
  - Figma draws one state per slot. The game shows the ring on every usable slot, which is the spec's "Ready".
  - Figma shows line glyphs for the skills; the game keeps the placeholder square until D550.
  - The Q chip shows the item's potion icon, not Figma's line flask. It is grey here because the item icons are missing
    in this checkout (the `test_baseline` noise).
