---
type: report
tags: [cloud, skills, ui]
branch: cloud/skills-dn
---

# cloud/skills-dn: the Dragon Nest skills window and skill ranks (D674)

**Summary**
- **Done:** ranks per skill from data: actives up to 5, passives up to 3. Each rank costs the skill's `rank.jp` and adds `rank.bonus` of its rank-1 effect (damage, heal, burn, passive value). Ranks are saved per skill. Respec (D628) refunds them. Old saves with ranks over the cap are trimmed, and the extra JP comes back.
- **Done:** the Skills screen is rebuilt as the Figma 533:6472 window: four tree tabs, the base and oath panels side by side, cells by `slot`, gold lines, level badges (red while the hero is below), ranks, "+" badges, a detail panel (rank, effect now → next, SP, cooldown, level, Learn +1 / Reset), and a bar with skill points, budgets and Reset all. Layout is in the `.tscn`, the sizes and colours are new `UITokens`, and the theme is regenerated. Mouse, keyboard and gamepad all work.
- **Kept:** prerequisites, the JP caps (D627), the oath choice, hotbar equip, attributes (D335) and pick-then-Accept (D330). Accept, Cancel, Attributes and the hotbar row are additions that the frame does not have (D676).
- **Not done:** the daze growing per rank (the frame's "0.3 s → 0.4 s"): stun does not scale with rank. The heading epithet ("Oath of the Sky") has no data.
- D-ID text: D675, D676 below. No B rows fixed.
- verify_difficulty: the same 2 FAIL as on `feature/backlog` before this branch (Brass Collector, B144). The ranks did not change any number in it.
- **Full suite:** `SUITE: 3 FAIL`, 111 PASS. The 3 are verify_difficulty (2, B144), verify_lab_boss (2) and verify_mayor_boss (1). Each fails identically on `origin/feature/backlog` without this branch, so none is caused here.

## D-ID text (next free numbers; the orchestrator renumbers)

| D675 | ROUTINE CALL | **Skill ranks in the data** (D674; `cloud/skills-dn`). Each skill in `skills.json` has `rank: {max, jp, bonus}`. **max** is 5 for actives (ultimates and Healing Palm too) and 3 for passives. **jp** is the price of each rank above the first: the skill's learning cost, at least 1 (1 JP for skills up to level 10, 2 JP from level 12). **bonus** is the share of the rank-1 effect that each rank above the first adds: **+15 %** for actives (damage, heal and burn, so ×1.6 at rank 5) and **+25 %** for passives (so ×1.5 at rank 3). This replaces D150 (rank 20, +10 %, 1 JP) and D626's "+10 % per rank" for passives. `SkillManager.MAX_RANK / RANK_BONUS / UPGRADE_COST` are gone; `check_upgrade`, `tree_spent`, `spent_points`, `SkillPlan` and `SkillTooltip` read the data. Old saves: `SkillManager.fit_ranks()` (called by `PlayerDataModule` on load) trims a rank above the cap and refunds 1 JP per trimmed rank, the price under D150. The JP caps (14 / 12, D627) now bound ranks too, so maxing is a choice: the whole base tree's ranks would cost far more than 14. D642 still holds: the skill build of `verify_difficulty` ranks its actives with leftover JP, and its results are unchanged (the 2 Brass Collector fails predate this branch, B144). Numbers provisional. |
| D676 | ROUTINE CALL | **The Dragon Nest window, as built** (D674, Figma 533:6472; agent calls where the frame is silent). **Grid:** each tree has 4 × 5 cells, and `skills.json` `slot: [column, row]` is hand-laid so that each in-tree prerequisite sits in the row right above (checked by `verify_skill_ranks`). A prerequisite in another tree (Bulwark ← Shield Block, Iron Body ← Toughness) gets no line. **Tabs:** the base tree and the shown oath are pressed. Before the oath, an oath tab shows that tree on the right with "Swear an oath in the City (level N)". After the oath, the other oaths' tabs are disabled (D489). A tab moves focus into its panel. **Right heading:** "Paladin · Light" (oath name · tree). The frame's "Oath of the Sky" has no data. **Cells:** the gold frame means learned or picked. The "+" shows on an owned skill that can take another rank (as in the frame). A learnable skill shows a bright icon, a locked one is at 45 % (D605). The level badge shows on unowned skills, red below the hero's level. **D330 kept:** Learn +1 (button, Enter, pad A) marks a rank. Reset in the detail panel drops that skill's marks. Accept and Cancel show in the bottom bar only while something is marked (not in the frame). Esc / B drop the marks. **Reset all** = the paid respec (D628), enabled only while meditating (D629), with a confirm modal ("Forget every skill and attribute point for N coins"). **Attributes (D335)** stay on this screen behind an "Attributes N" button in the bottom bar, which swaps the detail panel (not in the frame). **Hotbar slots (D331)** show in the detail panel for a learned active (not in the frame). The header line is "Lv N · Name": D280's class title is no longer in the header, and the right panel names the oath. The window ends 64 px above the screen bottom, above the hint bar. The daze per rank of the frame is not built: stun does not scale with rank. |

## Files

- Data: `SampleProject/Resources/Data/skills.json`: `rank` and `slot` on all 76 skills, plus the schema text.
- Ranks: `Scripts/Systems/SkillDefinition.gd` (`max_rank`, `rank_jp`, `rank_bonus`, `slot`, `rank_factor()`), `Scripts/Managers/Gameplay/SkillManager.gd` (`check_upgrade`, `upgrade_skill`, `tree_spent`, `spent_points`, `fit_ranks`), `Scripts/Systems/SkillPlan.gd`, `Scripts/Systems/SkillTooltip.gd` (the top rank and the burn per rank), `Scripts/Systems/Save/Modules/PlayerDataModule.gd` (`fit_ranks` on load).
- Window: `Scenes/Menus/Game/skills_component.tscn` (rewritten), `Scripts/Menus/Game/skills_component.gd` (rewritten), `Scripts/Menus/Game/skill_tree_links.gd` (an elbow at mid-gap, token colours), `Scripts/UI/modal_templates.gd` (`confirm_respec`).
- Theme: `UI/Tokens/UITokens.gd` (the "Вікно навичок Dragon Nest" block), `UI/build_game_ui_theme.gd` `_skill_window()`, regenerated `UI/Themes/GameUITheme.tres`. Its types: SkillWindow, SkillSlot / SkillSlotLearned, SkillLevelBadge(+Label/Low), SkillPlusBadge, SkillTreeTab, SkillLearnButton / SkillResetButton / SkillTextButton, and the labels.
- Strings: 23 new keys in `en.po` / `uk.po`.

## Tests

- `verify_skill_ranks` (new): RESULT: ALL PASS. It covers the data of all 76 skills, the slot grid and the rows under prerequisites, the caps 5 / 3, the rank JP from data, the tree spend, the effect per rank (damage, burn, passive, heal), the plan, save/load, an old save at rank 12 (trimmed to 5, 7 JP back), and the respec refund.
- `verify_skill_screen` (rewritten for the window): RESULT: ALL PASS. It covers the fit, the token sizes, cells by slot, lines, cell states, the detail facts now → next, Learn +1 / Reset / right click, keys and pad (row-wise focus across panels), the cascade, Esc / B / Accept, the passive cap at 3 / 3, the hotbar, attributes and Reset all.
- `verify_skill_trees_ui`, `verify_skills_ui`, `verify_attributes`, `verify_kusakam_skills`, `verify_skill_rules` (updated for ranks / layout): ALL PASS.
- `verify_locale`, `verify_responsive`, `verify_game_ui_theme`, `verify_skill_trees`, `verify_skill_icons`: ALL PASS.
- `verify_difficulty`: RESULT: 2 FAIL. These are the same two as before the branch: "Brass Collector at level 5: 9 hits kill the hero ([3, 4]), 27 hits kill it ([34, 46])" and "Brass Collector at level 5, STRENGTH: wins". Both are B144, not this branch.

## Full suite

`Scripts/Tools/run_verify.sh`: 111 PASS, 3 FAIL. All 3 reproduce on a clean `origin/feature/backlog` worktree with the same lines:
- `verify_difficulty`: 2 FAIL, Brass Collector (B144).
- `verify_lab_boss`: "balanced build: he dies in 2.6 of the mercenary's blows (406 HP; mace 129, club 206)" and "the mercenary takes 60 light hits (6800 HP, Phys. Atk. 100)".
- `verify_mayor_boss`: "the boss (2600 HP) takes 50 light hits of 53 (D642: about 40)".

## Shots

- `design/shots/skills_dn_vs_figma.png`: the Figma frame (left) and the game (right), from `capture_skills_dn.gd`: level 15, Paladin, Radiant Smite selected with one rank picked.
- `design/shots/skills_dn_paladin.png`: the game shot alone.
- The visual differences from the frame are all listed in D676: hotbar slots, Accept / Cancel / Attributes in the bar, the heading epithet, and the daze row. The panels are slightly narrower because the game menu's sidebar takes 296 px.
