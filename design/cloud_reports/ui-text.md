---
type: report
tags: [cloud, routines, ui, theme]
---

# Cloud report: ui-text (D474, D475)

**Summary**
- **D474 done:** text on the four in-game surfaces is now ×1.5 over Figma, with a 20 px floor. That gives 24 px body text, 20–27 px labels and keys, and titles unchanged. The dialogue, tutorial-window, banner and NPC-menu boxes grow to fit, and the tests check that nothing is clipped. The Game Menu screens stay at ×1.25. `GameUITheme.tres` is regenerated and `verify_game_ui_theme` prints **ALL CHECKS PASSED**.
- **D475 done:** the weapon-switch action is gone from `project.godot` (Q/Z, pad D-pad ←/→), from Player input, from `EquipmentManager.cycle_weapon`, from the hotbar (no weapon slot and no "Unarmed"), from Controls, from the `oldman_gift` tutorial hint and from both `.po` files. Equipping a weapon now puts it in hand (D486).
- **Not done:** the D453 v2 hotbar (hex slots, SP gem). This branch only removes the weapon slot from the current hotbar. The `ui-theme-tokens` skill named in the prompt does not exist in the repo; the theme was edited following CLAUDE.md.
- **D-IDs for the register:** D484, D486, D487 (below). D485 already exists on feature/backlog, so it is skipped.
- **B rows fixed:** none.
- **Full suite:** one run of 93 tests: 91 PASS, 2 FAIL. The two failures, `verify_combat_hud` and `verify_full_regression`, still expected the ×1.25 HUD sizes (VitalsName 23, BindBadge 14). Both were updated to `font_px(…, true)` and now print ALL PASS on their own re-run.

## D-ID text (for `figma_decision_register.md`)

| D484 | ROUTINE CALL | **How D474 is built** (`cloud/ui-text`). `UITokens.INGAME_FONT_SCALE = 1.5`, `INGAME_BODY_MIN = 24`, `INGAME_LABEL_MIN = 20`. `font_px(size, in_game)` returns ×1.5 with the 20 px floor for in-game text. Sizes above `FONT_SCALE_MAX` (28, titles) are unchanged. `UITokens.INGAME_FONT_TYPES` lists the theme types that `build_game_ui_theme._scale_fonts` scales this way: DialogueName, DialogueText (RichTextLabel), DialogueChoice (ChoiceMenu buttons, through the new `DQChoiceMenu.button_type_variation`), NpcMenuItem/On, VitalsName/Label/Value, BindBadge, CooldownLabel, HudQuestCaption/Title, TutorialBody, TutorialHint, TutorialKeyLabel and TutorialBanner. The speech bubble uses `font_px(SIZE_BODY, true)`. Some types were shared with other screens, so the in-game surface got its own copy and the other screen keeps ×1.25: the Journal keeps QuestCaption, the boss bar keeps QuestTitle, Controls keeps KeyBadgeLabel, and Game Over gets its own copy, GameOverItem/On. The currency chip in the top bar is not one of the four surfaces and stays ×1.25. The tutorial window is one scene (`tutorial_menu.tscn`), so it is also ×1.5 when opened from the Game Menu's Tutorial list. The hint banner is now a PanelContainer that grows upward with its text. Its label uses GameUITheme (`TutorialBanner`, so the theme font replaces Godot's default font) and keeps its old light-blue colour. |
| D486 | ROUTINE CALL | **Equipping a weapon puts it in hand** (D475 «змінюється лише в Equipment»; `cloud/ui-text`). With the switch gone, `EquipmentManager._on_equipped` makes every newly equipped weapon the one in hand, not only when the hands were empty. Unequipping the weapon in hand still takes the next equipped one, else bare hands. Dual-wield (D250) is unchanged: the off-hand is still the first other one-handed weapon equipped. `weapon_in_hand` is still saved (D202). Q, Z and pad D-pad ←/→ are now free. |
| D487 | ROUTINE CALL | **The hotbar keeps the companion assist slot** (D475 "the hotbar shows only skills 1–4"; `cloud/ui-text`). That phrase was read as "no weapon slot". The assist slot (D209, only when a companion is unlocked) stays to the right of the skills, because removing it would take away a working feature that D475 does not mention. If Sapega means "skills only", the assist slot moves elsewhere in the D453 redraw. |

## Details

**Tokens and theme**
- `SampleProject/UI/Tokens/UITokens.gd`: D474 block, `INGAME_FONT_TYPES`, `font_px(figma_size, in_game := false)`.
- `SampleProject/UI/build_game_ui_theme.gd`: new types HudQuestCaption/Title, DialogueName, TutorialKeyLabel, TutorialBanner, DialogueChoice, DialogueText and GameOverItem/On. `_scale_fonts` passes `in_game`.
- Resulting sizes at 1080p: dialogue text, name, choices and NPC items 24; hotbar keys (BindBadge, was 14) 20; cooldown 24; vitals name 27, labels 24, values 21; quest caption 21, title 24; tutorial body 33, hint 27, key 21; banner 24.

**Scenes and scripts**
- `dialogue_box.tscn` (Name → DialogueName, DialogueText → DialogueText), `DialogueSystem.tscn` (ChoiceMenu `button_type_variation`), `addons/dialogue_quest/.../choice_menu.gd` (export plus one line).
- `combat_hud_top.tscn` (HudQuest*), `tutorial_menu.tscn` (TutorialKeyLabel), `game_over_screen.{gd,tscn}` (GameOverItem).
- `TutorialHintDisplay.{tscn,gd}`: PanelContainer, themed label, no hard-coded 16 px. The slide animation now moves the root node, because the panel's own y changes as it grows.
- `speech_bubble.gd`: `font_px(SIZE_BODY, true)`.
- D475: `Player.gd` (switch input removed), `EquipmentManager.gd` (`cycle_weapon` removed, `_on_equipped` draws), `skill_hotbar.gd` (`_build_weapon_bind`, weapon label and badge refresh removed), `controls_component.gd`, `input_options_menu.tscn`, `project.godot`, `tutorial.json` (`oldman_gift`: last sentence cut, key `{game_menu}`), `en.po` / `uk.po` (Next/Previous weapon, Unarmed and "Button to switch weapons." removed; the oldman_gift msgid updated).

**Tests**
- New `SampleProject/UI/text_fit.gd`: no visible text is below its minimum size or outside its box.
- `verify_game_ui_theme`: 32 D474 checks (floors, body ≥ 24, ×1.25 kept on Controls, Game Over and the boss bar, titles unchanged). Result: `=== ALL CHECKS PASSED ===`.
- `verify_dialogue_speaker` (24 px plus fit for every speaker), `verify_tutorial_hints` (window body, key and fit; banner 24 px and fit), `verify_npc_recall` (item 24 px and fit): ALL PASS.
- Tests that used the switch now equip instead: `verify_combat_flow` (also checks that `weapon_next` and `weapon_prev` are gone), `verify_kusakam_skills`, `verify_skill_casts`, `verify_souls_combat`, `verify_weapon_animations`, `verify_audio`, `verify_gamepad`, `verify_onboarding` (no weapon rows), `verify_game_over` (GameOverItemOn). Captures `capture_skill_casts` and `capture_bow` are updated the same way. `verify_combat_hud` and `verify_full_regression` now expect the HUD's ×1.5 sizes.

**Captures** (`SampleProject/UI/capture_ui_text.gd -- before|after`, 1920×1080)
- `design/shots/ui_text/ui_text_before_after.png`: rows are the dialogue box, NPC menu, HUD, tutorial window and tutorial banner; before on the left, after on the right. Per-surface files are `design/shots/ui_text/<surface>_{before,after}.png`.
- Seen: the dialogue text and name are larger and the box is taller; Talk and Buy are larger and the menu is taller; the hotbar has no "Unarmed/Q" slot, only 1–4; the vitals, quest and key labels are larger; the tutorial body is larger; the banner wraps on 3 lines and its text no longer says "Q switches weapons".
- Figma: every in-game surface is now larger than Figma on purpose (D474). There are no new visual differences to triage.
