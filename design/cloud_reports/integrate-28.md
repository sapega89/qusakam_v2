---
type: report
tags: [cloud, routines, integration]
---

# integrate-28 (cloud routine, 2026-10-27)

**Summary.**
- All ten merges are done, in order: `enemy-ai`, `stamina-poise-2`, `room-story-flow`, `plugins-fsm`, `journal-hints`, `decision-audit-2`, `story-dialogue`, `secrets`, `secrets-icon`, `map-pan`, `ambient-critters`, then `feature/backlog` again.
- `stamina-poise` → **`stamina-poise-2`**: the branch named in the prompt holds only an 8-hour «not started» report. The re-run is on `-2`, built on enemy-ai, and its report asks to merge `-2` and drop the old one.
- New D-IDs: **D775–D786**. B rows: **B163–B166** (fixed, enemy-ai), **B167** (fixed by journal-hints), **B168** and **B169** (open).
- Godot ran in this session (integrate-27's could not get it).
- Fixed at the root: the save tests now account for D764's hop. `verify_save_load`, `verify_save_load_room` and `verify_progression` were red on `feature/backlog`.
- Fixed at the root: story-dialogue never ran on its branch and came in with 3 FAILs.
- Full suite: SUITE_LINE

## Setup
- Godot 4.6.2 downloaded, `--import` run. The import rewrote `heavy_battle.mp3.import` (uid/path/dest_files, integrate-27's open item); it is committed with the missing `.uid` files (`77ebb9c0`).
- Base checks before any merge, on `origin/cloud/integrate-27`:
  - green: `verify_city_gates_raid`, `verify_flying_enemies` (integrate-27's unrun flier fix works), `verify_scripts_compile`;
  - red: `verify_save_load` 2 FAIL + `SavePoint.gd:62` null, `verify_progression` 4 FAIL, `verify_save_load_room` 2 FAIL.
- Those three are D764's: `SavePoint._meditate` reads `$Seat` and hops 0.3 s before the Meditate pose.
  - `verify_save_load` [7] builds a bare save point with no `Seat`. It now gets a `Seat` Marker2D, as every room's save point has.
  - The waits count `HOP_TIME`.
  - `verify_progression` [3] now checks the Jump pose of the hop first, then Meditate, and the hop back to Idle.
  - All three: ALL PASS (`ac8206d9`). No check was dropped.

## Per branch

### 1. cloud/enemy-ai — merged
- **Ancestry:** `enemy-ai` is not an ancestor of `stamina-poise`, so it was merged first.
- **Conflicts:** BossLogic, ArcherLogic, EnemyStats, EnemyLogic, verify_combat_stats, MASTER_PLAN, `capture_enemy_sizes.gd.uid`; CombatTraining.gd was deleted here and modified there.
  - **BossLogic:** integrate-27 kept boss-fix's BossLogic (`_must_close` / `_rest_reach`), while enemy-ai was written on hard-fights-2's (`_combo_reach` / `_next_kind` / `COMBO_MARGIN`).
    - Kept: boss-fix's structure.
    - Added from enemy-ai: `REACH_PATIENCE` / `_reach_wait` (B166), the punish of an opening (`_hero_opened`, `tactic punish`), `_rest_after_swing`, `_combo_reach()` (written on boss-fix's `_reach`) and `COMBO_STEP_IN` (punish range only).
    - Dropped: hard-fights-2's step-in branch and `COMBO_MARGIN`.
  - **EnemyLogic, ArcherLogic, EnemyStats, verify_combat_stats:** enemy-ai's side. ArcherLogic's old height check was replaced by enemy-ai's `_hero_y_at`.
  - **CombatTraining.gd:** stays deleted (D743 removed the training). enemy-ai's `in_training` flag had no setter left, so it was removed from `EnemyLogic` rather than left as dead code.
  - **MASTER_PLAN:** both sides' rows, plus enemy-ai's B-ai row.
- **IDs:**
  - D764 → **D775**.
  - B162 → **B163**, B163 → **B164**, B164 → **B165**, B165 → **B166**.
  - hard-fights-2's own placeholders in enemy-ai's new lines got the numbers integrate-27 gave them: D713 → D754, D741 → D770, B154 → B159.
- **Tests:** all ALL PASS — scripts_compile, combat_enemies, souls_combat, combat_stats, combat_player, bosses, lab_boss, mayor_boss, mayor_hall, archer, combat_flow, enemy_variety, flying_enemies, hit_areas, enemy_stagger, onboarding, rooms_batch1, difficulty, combat_feel, skills_combat, companions. `verify_masher`: MASHER_LINE

### 2. cloud/stamina-poise → cloud/stamina-poise-2 — merged (`-2`)
- **Why `-2`:** see the summary. `enemy-ai` is not an ancestor of either branch by commit: `-2` was built on enemy-ai's `d7be2355` and lacks only its import-file commit.
- **Report:** `-2`'s §7 «Full suite» still read «(filled below)» at merge time (its last commit was 08:35 UTC). If the routine pushes a suite line later, the next integrator picks it up.
- **Conflicts:**
  - enemy_variety.json, verify_combat_player, verify_enemy_variety, verify_masher: `-2`'s side, with integrate-27's numbers restored on its old lines (D741 → D770).
  - GameUITheme.tres: regenerated after all merges (`build_game_ui_theme.gd`).
  - MASTER_PLAN: both sides plus `-2`'s B-stamina and B-poise rows.
  - `capture_enemy_sizes.gd.uid`: ours.
- **IDs:**
  - D775 → **D776** (stamina), D776 → **D777** (poise bar), D777 → **D778** (no third-hit stagger).
  - In its new lines: D764 → D775, D713 → D754, D739 → D768, D740 → D769, B154 → B159.
- **Not filed:** its non-blocking question (bring back the four D535 stamina skills?) is left in its report §6 for `questions_for_sapega.md`.
- **Tests:** STAMINA_TESTS

### 3. cloud/room-story-flow — merged
- **Conflicts:** only `verify_masher.gd.uid` (ours).
- **IDs:** «D?» → **D779** (register, and the report's §5).
- **Tests:** ROOM_TESTS

### 4. cloud/plugins-fsm — merged
- **Conflicts:** none. No scene or script refers to `addons/fsm`, `addons/interaction_system` or `FSMState` after the merge.
- **IDs:** **D780** (its unnumbered D-ID text).
- **Not edited:** `design/BACKLOG.md:358` still names fsm/interaction_system as next work.
- **Tests:** PLUGIN_TESTS

### 5. cloud/journal-hints — merged
- **Conflicts:** GameUITheme.tres (regenerated).
- **IDs:** D766 → **D781**.
- **Tests:** journal, story_journal ALL PASS; JOURNAL_TESTS

### 6. cloud/decision-audit-2 — merged
- **Conflicts:** none.
- **B rows:**
  - D181 not built → **B167**, closed by journal-hints (D781).
  - D459 not built (the prisoner does not burst into flame, `LabCells.gd:134`) → **B168**, open.
- **Tests:** documents only.

### 7. cloud/story-dialogue — merged
- **Conflicts:** none.
- **IDs:** proposed D774 → **D782**.
- **First run of its code (the branch never ran Godot):** `verify_story_dialogue` 3 FAIL.
  1. «the title sits top-left» and «the hero is on the left, the speaker on the right» measured against `root.size`, which is 64×64 in headless. They now measure against the view's canvas (1920×1080). Layout as built: title (64, 64), cards at x 168 and 1536, box y 678–820.
  2. «the advance marker shows once the line is typed»: the story box used the plain box's `dialogue_box_settings.tres`, which turns the marker off (B10, the old orange «!»). The story box now has `story_dialogue_box_settings.tres`, the same with `text_finished_marker_enabled = true`, so its gold diamond (Figma `36:65`) shows. The plain box is unchanged.
- **Tests:** after the fix, all ALL PASS — story_dialogue, dialogue_speaker, npc_recall, dialogue_triggers, interaction, game_ui_theme (ALL CHECKS PASSED). The capture `capture_story_dialogue.gd` was not run (CAPTURE_NOTE).

### 8. cloud/secrets → 9. cloud/secrets-icon → 10. cloud/map-pan — merged
- **Ancestry:** `map-pan` holds `secrets` and `secrets-icon` except their last report-only commits, so all three were merged in turn.
- **Conflicts:**
  - DesertRoad.tscn: the ext_resource block. This side's D764 meditation-spot texture is kept (the old `meditation_stone.tscn` is gone), and secrets' `secret_area` is added.
  - `verify_masher.gd.uid`: ours.
- **IDs:**
  - secrets' «builds D765» text → **D783**;
  - secrets-icon → **D784**, and its legend finding → **B169** (open);
  - map-pan D766 → **D785**.
- **Tests:** SECRETS_TESTS

### 11. cloud/ambient-critters — merged
- **Conflicts:** LizardCave.tscn ext_resources, both kept (secrets' `secret_area` and the bat `x5`).
- **IDs:** D775 → **D786**.
- **Note:** its four pre-existing failures (save point `$Seat`, city_gates_raid) were fixed or green before the merge, see Setup.
- **Tests:** CRITTER_TESTS

### 12. origin/feature/backlog — merged
- **Contents:** B162 (Lizard Cave on four planes) and HANDOFF lines.
- **Conflicts:** none. LizardCave.tscn auto-merged; the bats and the shrine secret are still there.
- **Duplicate-ID check:** no new duplicates. D89–D91, D104, D105 and D108 repeat, as before.

## Registers
- `figma_decision_register.md`: D775–D786 appended.
- `BUGS.md`: B163–B166 (fixed), B167 (fixed), B168, B169 (open).
- `MASTER_PLAN.md`: «✅ злито (integrate-28)» on B-ai, B-stamina, B-poise, S3, S4 (slice 1), S5, S6, S7, S15, S16, Q98 (secrets + map), A21 (slice 1), plus one journal line.

## Failures and the full suite
FAILURES
