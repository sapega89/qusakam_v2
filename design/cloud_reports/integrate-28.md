---
type: report
tags: [cloud, routines, integration]
---

# integrate-28 (cloud routine, 2026-10-27)

**Summary.**
- All merges are done. Order: `enemy-ai`, `stamina-poise-2` (twice, see §2), `room-story-flow`, `plugins-fsm`, `journal-hints`, `decision-audit-2`, `story-dialogue`, `secrets`, `secrets-icon`, `map-pan`, `ambient-critters`, then `feature/backlog` (twice, it moved during the run).
- `stamina-poise` → **`stamina-poise-2`**: the branch named in the prompt holds only an 8-hour «not started» report. The real work is on `-2`, built on enemy-ai, and its report asks to merge `-2` and drop the old one.
- New D-IDs: **D775–D786**.
- B rows: **B163–B166** fixed (enemy-ai), **B167** fixed (by journal-hints), **B168**, **B169** and **B170** (a combat_flow flake) open.
- Godot ran in this session (integrate-27's could not get it).
- Fixed at the root: three save tests red on `feature/backlog` since D764's hop; story-dialogue's 3 FAILs (the branch never ran Godot); and 5 interplay failures from the first full suite.
- Full suite #2, final head: `SUITE: 3 FAIL`, 132 PASS.
  - `verify_masher`: HUNG at the 180 s limit, as always.
  - `verify_audio`: passes alone.
  - `verify_combat_flow` [2c]: flaky, about 2 of 10 runs → **B170**, open.
- `verify_masher` alone: `RESULT: 1 FAIL`. GOOD: longest idle in reach 1.30 s against ≤ 1.0 (Lab middle, a jackal). This is the bound stamina-poise-2 reported as flaking ±0.4 s; its other open row (the Caravan) passed in this run.

## Setup
- Godot 4.6.2 downloaded and `--import` run.
  - The import rewrote `heavy_battle.mp3.import` (uid/path/dest_files), integrate-27's open item.
  - That rewrite is committed with the missing `.uid` files (`77ebb9c0`).
- Base checks on `origin/cloud/integrate-27`, before any merge:
  - green: `verify_city_gates_raid`, `verify_flying_enemies` (integrate-27's unrun flier fix works), `verify_scripts_compile`;
  - red: `verify_save_load` (2 FAIL, plus `SavePoint.gd:62` null), `verify_progression` (4 FAIL), `verify_save_load_room` (2 FAIL).
- Why the three were red (D764): `SavePoint._meditate` reads `$Seat` and hops for 0.3 s before the Meditate pose.
- The fix (`ac8206d9`), no check dropped:
  - `verify_save_load` [7] builds a bare save point. It now gets a `Seat` Marker2D, as every room's save point has.
  - The waits count `HOP_TIME`.
  - `verify_progression` [3] checks the hop's Jump pose, then Meditate, then the hop back to Idle.
  - All three: ALL PASS.

## Per branch

### 1. cloud/enemy-ai — merged
- **Ancestry:** enemy-ai is not an ancestor of `stamina-poise` (nor, by commit, of `-2`), so it was merged first.
- **Conflicts:** BossLogic, ArcherLogic, EnemyStats, EnemyLogic, verify_combat_stats, MASTER_PLAN, a `.uid`; CombatTraining.gd deleted here, modified there.
  - **BossLogic.** integrate-27 kept boss-fix's BossLogic (`_must_close` / `_rest_reach`). enemy-ai was written on hard-fights-2's (`_combo_reach` / `_next_kind` / `COMBO_MARGIN`).
    - Kept: boss-fix's structure.
    - Added from enemy-ai:
      - `REACH_PATIENCE` / `_reach_wait` (B166);
      - the punish of an opening (`_hero_opened`, `tactic punish`);
      - `_rest_after_swing`;
      - `_combo_reach()`, written on boss-fix's `_reach`;
      - `COMBO_STEP_IN`, now the punish range only.
    - Dropped: hard-fights-2's step-in branch and `COMBO_MARGIN`.
  - **EnemyLogic, ArcherLogic, EnemyStats, verify_combat_stats:** enemy-ai's side. In ArcherLogic, the old height check gives way to enemy-ai's `_hero_y_at`.
  - **CombatTraining.gd:** stays deleted (D743 removed the training). enemy-ai's `in_training` flag had nothing left to set it, so it was removed from `EnemyLogic`.
  - **MASTER_PLAN:** both sides' rows plus B-ai.
- **IDs:**
  - D764 → **D775**.
  - B162 → **B163**, B163 → **B164**, B164 → **B165**, B165 → **B166**.
  - In its new lines, hard-fights-2's own placeholders get integrate-27's numbers: D713 → D754, D741 → D770, B154 → B159.
- **Tests (21), all ALL PASS:** scripts_compile, combat_enemies, souls_combat, combat_stats, combat_player, bosses, lab_boss, mayor_boss, mayor_hall, archer, combat_flow, enemy_variety, flying_enemies, hit_areas, enemy_stagger, onboarding, rooms_batch1, difficulty, combat_feel, skills_combat, companions.

### 2. cloud/stamina-poise → cloud/stamina-poise-2 — merged (`-2`, twice)
- **Why twice:** the first merge (at `58a95aca`) was made while `-2`'s §7 still read «(filled below)». Its routine then pushed 5 more commits:
  - the final report;
  - an exhausted hero is an opening enemies punish;
  - the stamina refill tuned;
  - the skill_trees dummy fix.
  
  They were merged after suite #1. Register D776 took the final text.
- **Conflicts:**
  - enemy_variety.json, verify_combat_player, verify_enemy_variety, verify_masher: `-2`'s side, with integrate-27's numbers restored on its old lines (D741 → D770, D764 → D775).
  - GameUITheme.tres: regenerated after the merges.
  - EnemyLogic (2nd merge): `-2`'s exhausted-hero opening plus this side's comment.
  - MASTER_PLAN: both sides' rows, plus B-stamina and B-poise.
  - Its report: `-2`'s final version, renumbered as a whole.
- **IDs:**
  - D775 → **D776** (stamina), D776 → **D777** (poise bar), D777 → **D778** (no third-hit stagger).
  - In its new lines: D764 → D775, D713 → D754, D739 → D768, D740 → D769, B154 → B159.
- **Open, per its report:**
  - GOOD vs the Caravan is a coin flip.
  - No stamina skills: a non-blocking question for Sapega, in its §6; not filed as a Q-ID here.
- **Tests:** combat_player, skill_trees, combat_hud, combat_enemies, souls_combat, oath_census: ALL PASS on the final head. The rest are in the suite.

### 3. cloud/room-story-flow — merged
- **Conflicts:** a `.uid` (ours).
- **IDs:** «D?» → **D779** (register and the report's §5).
- **Tests:** suite (its rooms: desert_road, canyon_exit, village_*, city_gates_raid, oath_census, demo_end, lab_*, save_load_room).

### 4. cloud/plugins-fsm — merged
- **Conflicts:** none. Nothing in the tree refers to `addons/fsm`, `addons/interaction_system` or `FSMState` any more.
- **IDs:** **D780**.
- **Not edited:** `design/BACKLOG.md:358` still lists fsm/interaction_system as next work.
- **Tests:** suite.

### 5. cloud/journal-hints — merged
- **Conflicts:** GameUITheme.tres (regenerated).
- **IDs:** D766 → **D781**.
- **Tests:** journal and story_journal ALL PASS; the rest in the suite.
- **Left as it was:** en.po still has 8 keys uk.po lacks (its report), so `po_sync.py` was not run here either.

### 6. cloud/decision-audit-2 — merged
- **Conflicts:** none.
- **B rows:**
  - D181 not built → **B167**, closed by journal-hints (D781).
  - D459 not built (the prisoner does not burst into flame, `LabCells.gd:134`) → **B168**, open.
- **Tests:** documents only.

### 7. cloud/story-dialogue — merged
- **Conflicts:** none.
- **IDs:** proposed D774 → **D782**.
- **First run of its code:** `verify_story_dialogue` 3 FAIL.
  1. «the title sits top-left» and «the hero is on the left, the speaker on the right» were measured against `root.size`, which is 64×64 headless. They now use the view's 1920×1080 canvas.
     - As built: title (64, 64), cards at x 168 and 1536, box y 678–820.
  2. «the advance marker shows»: the story box shared `dialogue_box_settings.tres`, which turns the marker off (B10). The story box now has `story_dialogue_box_settings.tres` with the marker on, so its gold diamond (Figma `36:65`) shows. The plain box is unchanged.
- **Tests after the fix, all ALL PASS:** story_dialogue, dialogue_speaker, npc_recall, dialogue_triggers, interaction, game_ui_theme.
- **Not run:** `capture_story_dialogue.gd`, so the shot against Figma is still owed.

### 8–10. cloud/secrets → cloud/secrets-icon → cloud/map-pan — merged
- **Ancestry:** map-pan holds secrets and secrets-icon except their last report-only commits, so all three were merged in turn.
- **Conflicts:**
  - DesertRoad.tscn ext_resources: this side's D764 meditation-spot texture (the old `meditation_stone.tscn` is gone) plus secrets' `secret_area`.
  - A `.uid`: ours.
- **IDs:**
  - secrets' «builds D765» text → **D783**;
  - secrets-icon → **D784**, and its legend finding → **B169** (open);
  - map-pan D766 → **D785**.
- **Tests:** suite (secrets, world_map, map_geometry, save_load, desert_road).

### 11. cloud/ambient-critters — merged
- **Conflicts:** LizardCave.tscn ext_resources, both kept (secrets' `secret_area` and the bat).
- **IDs:** D775 → **D786**.
- **Its 4 pre-existing failures:** the save point's `$Seat` was fixed in Setup; city_gates_raid is green.
- **Tests:** suite (ambient_critters, room_entrances).

### 12. origin/feature/backlog — merged twice
- **1st merge:** B162 (the Lizard Cave on four planes), HANDOFF.
- **2nd merge:** bird art and the flap sound (A21 slice 2, not wired yet), A23, A24, P1, the hero's Death frames.
- **MASTER_PLAN conflicts:**
  - A20: that side's;
  - A21: that side's text, with slice 1 merged here;
  - S14: that side's (perf-check);
  - S15 and S16: this side's;
  - change log: both sides.
- **Duplicate-ID check:** none new. D89–D91, D104, D105 and D108 repeat, as before.

## Registers
- `figma_decision_register.md`: D775–D786.
- `BUGS.md`:
  - B163–B166 fixed (enemy-ai);
  - B167 fixed (journal-hints);
  - B168 and B169 open.
- `MASTER_PLAN.md`: «✅ злито (integrate-28)» on:
  - combat: B-ai, B-stamina, B-poise;
  - systems: S3, S4 (slice 1), S5, S6, S7, S15, S16;
  - map and world: Q98 (secrets and the map canvas), A21 (slice 1);
  - plus one journal line.

## Full suite #1 (after the merges, before stamina-poise-2's last commits): `SUITE: 6 FAIL`, 129 PASS
Each failure, fixed at the root and then passing alone:
- **`verify_new_points`** «SkillPoints on PlayerVitalsPanel».
  - Cause: D776's ST row made the hero panel taller (bottom 222 → 244).
  - Fix: `hud_new_points.tscn` moves down 22 px (top 240 → 262), the same 18 px gap as before.
- **`verify_map_geometry`** «LizardCave: all 54 tops of hidden Foreground are drawn».
  - Cause: B162 (feature/backlog) draws the cave floor as a world-locked `Parallax2D` (scroll 1, repeated), and the check skipped every Parallax2D.
  - Fix: the check now counts a plane with scroll_scale 1 and no offset as drawn, its repeat copies included. Moving planes are still not counted.
- **`verify_skill_trees`** «Blood Pact», plus a SCRIPT ERROR.
  - Cause: the test's dummy had the old `take_poise(amount, from_x)`.
  - Fix: it takes D777's `source` (stamina-poise-2 made the same fix on its side).
- **`verify_gates`** «Chest_TowerGuard offers Open».
  - Cause: the woken tower guard punishes a hero who just landed (D775). It shoved the teleported hero 88 px off the chest within the 20-frame settle.
  - Fix: the test holds the guard still while it checks the prompt, as enemy-ai did in verify_combat_player. Every later check of that chest runs as before.
- **`verify_oath_census`** «a bot that blocks and parries drifts to Samal (samal 3, none 3)». Deterministic.
  - Cause: since D775 a series stops before swinging into a front block. A 150-HP bandit gave the blocker only 3 blocks, tied with the untouched-kill bonus (+3 none).
  - Fix: the fixture bandit has 300 HP (7 blocks: samal 5, none 3). The assertion is unchanged.
  - **For Sapega (not blocking):** in a short real fight, a pure blocker who is never hit now gets as much «none» as «Samal».
- **`verify_masher`:** HUNG at the suite's 180 s limit, as in every routine's run. It is run alone (see the top).

## Full suite #2 (final head, after stamina-poise-2's last commits and feature/backlog's 2nd merge): `SUITE: 3 FAIL`, 132 PASS
- **`verify_masher`:** HUNG at 180 s. Alone: 1 FAIL, the D775 idle-in-reach bound (1.30 s against ≤ 1.0), already reported as flaky by stamina-poise-2. Not loosened.
- **`verify_audio`:** 1 FAIL under suite load; ALL PASS alone. Known flaky under load (`test_baseline.md`).
- **`verify_combat_flow`** [2c]: 2 FAIL.
  - Flaky: the 2 FAIL in about 2 of 10 runs alone; ALL PASS in suite #1 and in the other runs.
  - Not caused by the stamina refill retune: with the old values it fails too.
  - Narrowed to the «fast» enemy's scripted swing landing no hit (see **B170**). Left open rather than guarded in the test.
- After the 5 fixes from suite #1, these also passed alone on the final head: `verify_combat_player`, `skill_trees`, `combat_hud`, `oath_census`, `combat_enemies`, `souls_combat`, `scripts_compile`.

## Not done
- `verify_masher` is not green alone: the 1.30 s idle bound.
- B170 (combat_flow flake): no deterministic repro.
- No captures were taken: story dialogue against Figma `36:65`, and the D782/D785 shots.
- `design/BACKLOG.md` was not edited (S4 slice 1 is done, BACKLOG:358).
- The old `cloud/stamina-poise` branch was not merged; it holds only the stale report.
