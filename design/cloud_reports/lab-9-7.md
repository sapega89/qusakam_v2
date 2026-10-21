---
type: report
tags: [cloud, queue-9.7]
---

# Cloud report — queue row 9.7, the fire djinn's boss hall (`cloud/lab-9-7`)

Branch `cloud/lab-9-7` off `origin/feature/backlog` (8811363f). Godot 4.6.2 ran headless here. There is no display, so
there are no captures; the layout is described in words below. `LabCells.*` was not touched (`cloud/lab-9-5` owns it).
Nothing was committed from the do-not-commit list (project.godot, MainMenu.tscn, GameUITheme.tres, playthrough.gd), and
nothing went into BUGS / BACKLOG / the queue / the decision register.

## What was built

| What | Where |
|---|---|
| The hall's script: WAIT → TALK → FIGHT → CLOAK (lost) or OPEN (won); the state on entry comes from flags (B53) | `SampleProject/Scripts/Gameplay/Scenes/LabBoss.gd` (started from the WIP in `wip/row9-drafts`) |
| Entry state: `lab_boss_fight_complete` → OPEN, `lab_boss_talk_complete` → FIGHT at once (no talk replay), else WAIT | `LabBoss.gd:44` |
| The talk is one D308 cutscene: the arena locks, the camera pans to the djinn, `Lab_Boss_Talk`, the camera comes back → fight. A hold of Tab / pad Y gives the same end state | `LabBoss.gd:87` |
| The fight: west `ArenaWall` on, gates down, `Player.defeat_handler` set, the djinn awake with detection / chase / leash covering the whole hall, the boss bar shown at once | `LabBoss.gd:100` |
| The djinn wins: it floats up to the hero, `Lab_Boss_TakesCloak`, then the **normal** `GameOverScreen.present` | `LabBoss.gd:116` |
| The djinn loses: `lab_boss_fight_complete` → `Laboratory_AfterBoss` (Kusakam's line + the gates narration), the camera goes to the gates, the portcullis rises 200 px and its collision is switched off, `lab_after_boss_complete`, objective "Leave the laboratory" | `LabBoss.gd:133`, `:140`, `:164`, `:177` |
| Scene nodes: script on the root, `FireDjinn` (instance of `fire_djinn.tscn` at x 1060, asleep), `TalkTrigger` (x 400, 32×320), `ArenaWall` (x −8, disabled), `Gates/Body/Collision` (x 1560, 32×320), `Marks/Look`, `Marks/GatesLook` | `SampleProject/Maps/LabBoss.tscn` |
| **B83** for the hall: the two dodge bridges moved from row 8 to row 9, so they are 96 px above the floor (a held jump peaks at ~107 px); the slab art moves with them | `Scripts/Tools/build_laboratory.gd:184` (layout) → rebuilt `LabBoss.tscn` |
| Builder: prop groups now keep their hand-placed children (`Gates/Body` survives a rebuild); rooms are instantiated in edit state (`GEN_EDIT_STATE_MAIN`), so the djinn instance is saved as a reference rather than having all its properties baked in (this also drops a redundant script override on `RoomInstance`) | `build_laboratory.gd:215`, `:347`. Run the builder, then `git checkout` LabCells / Laboratory if you only want LabBoss — I committed only LabBoss |
| The cloak line `.dqd`, `[ЧЕРНЕТКА]`, Ukrainian like the other files, speaker `KUSAKAM`: «Не знаю, чи віддали б ви плащ, а я — ні.» + the gates narration | `dialogue_quest/Laboratory_AfterBoss.dqd` (from `wip/row9-tracked`). `Lab_Boss_Talk` / `Lab_Boss_TakesCloak` were already right and are unchanged |
| `verify_lab_boss.gd` — every step with real input (below) | `SampleProject/UI/verify_lab_boss.gd` |
| `verify_lab_rooms.gd` [3]: the door walk now goes through a beaten hall (the boss flags are set first), because a live hall locks | `SampleProject/UI/verify_lab_rooms.gd:85` |
| Plan notes: slice 8 marked built, with the D307 calls | `design/lab_story_plan.md` slice 8, `design/lab_boss_plan.md` header |

**The hall in words:** one storey, 1728 px wide. The hero comes in at the west door (x ≈ 40–120). At x 400 the talk
starts and an invisible wall closes the west edge. The djinn floats at x 1060, facing west. The two dodge bridges sit
96 px above the floor, at x 352–544 and 1216–1408. The portcullis (the generated `gen_gates` art) stands down at x 1560
until the djinn is dead. Then it rises 200 px: its bottom edge ends at y 184, above the hero's head, and the east door
on rows 6–11 leads out to LaboratoryOutside.

**The 9.8 hook:** the flag `lab_after_boss_complete` means the way east is open. `LaboratoryOutside` does not read it
yet, because its EXIT_LAB talk starts on entry anyway.

## Decisions — ready to paste (agent call, Sapega to confirm)

> **D307 — the fire djinn's boss hall (queue row 9.7)** — *agent call, Sapega to confirm.* The arena locks when the
> cloak talk starts. The talk trigger is at x 400, just inside the west door. An invisible `ArenaWall` closes the west
> edge (like the Mayor Hall's `BarrierWest`; it has no art). The gates are down from the start, so the Laboratory cannot
> be left east until the djinn is dead. Walking back west before the talk is allowed. The talk (`Lab_Boss_Talk`: who
> are you — ready to bargain — give me the cloak — it is my grandfather's) is one D308 cutscene: HUD hidden, the camera
> on the djinn, and a hold of Tab / pad Y gives the same fight state. The djinn sleeps (it floats, no AI) until the
> fight. In the fight it sees and chases the hero anywhere in the hall, so there is no safe corner. Re-entry after the
> talk starts the fight at once with no replay, and the djinn always starts at full HP. **Djinn wins:** it floats up to
> the hero, `Lab_Boss_TakesCloak`, then the normal Game Over screen. Nothing is removed from the save: there is no cloak
> item and no art of the hero without it, and "Resume from last save" restores the run. **Djinn loses:** +500 XP from
> its stats and no loot. `Laboratory_AfterBoss` plays (Kusakam: «Не знаю, чи віддали б ви плащ, а я — ні.» + narration),
> the camera goes to the gates, the portcullis rises 200 px and its collision goes, and the objective becomes "Leave the
> laboratory". Flags: `lab_boss_talk_complete`, `lab_boss_fight_complete`, `lab_after_boss_complete` (the 9.8 hook).

> **D-? — B83 in the boss hall** (fold into D307 if preferred) — *agent call, Sapega to confirm.* The two dodge bridges
> are lowered one tile (row 8 → row 9) and are now 96 px above the floor. One held jump (~107 px peak) lands on them.
> Steps were not added: one tile lower was enough, and it keeps the floor clear for the fight.

## Bugs

> **B-? — `godot_locked.sh` and `run_verify.sh` have no exec bit in git** — *Where:* `Scripts/Tools/*.sh` (mode 100644).
> *Expected:* `Scripts/Tools/run_verify.sh` runs on Linux as the docs say. *Got:* "Permission denied", and all 70
> verifies report "no RESULT line". *Fix:* `git update-index --chmod=+x Scripts/Tools/*.sh`. I did not do it on this
> branch, to keep the diff to the task; here I used a local `chmod +x`. *Severity:* tooling (cloud runs only).

**B82, seen again (not new):** after a load the hero stands at the `Game.tscn` default (368, 264). In the boss hall that
happens to be inside the locked arena, right over bridge 1, so the mid-fight resume still works. In other rooms it is a
lottery, as B82 says.

## Verifies run (RESULT lines)

| Verify | RESULT |
|---|---|
| `verify_lab_boss` (new) | `RESULT: ALL PASS` |
| `verify_bosses` | `RESULT: ALL PASS` |
| `verify_lab_rooms` (updated [3]) | `RESULT: ALL PASS` (before the update: 2 FAIL — the live hall's talk stopped the door walk, as expected) |
| `verify_map_geometry` (incl. [6] art on every standable top) | `RESULT: ALL PASS` |
| Full suite `Scripts/Tools/run_verify.sh` | `SUITE: ALL PASS` — 70 / 70 PASS (run with a local `chmod +x` on the two scripts, see the bug below) |

What `verify_lab_boss` checks, with real input:
1. Arriving: WAIT, the djinn asleep, no bar, the way west open, the gates down.
2. A real `move_right` walks into the talk: the arena locks, `Lab_Boss_Talk` plays, the HUD hides, the skip prompt shows.
   Played through, it ends in FIGHT (locked, gates down, bar shown, the defeat handler set, the objective).
3. A real `move_left` stops at the arena wall and a real `move_right` stops at the gates.
4. The same beat skipped with a real one-second Tab hold gives the same flags, objective, and hero and djinn positions.
5. Claws, fireball and pillar all come and hurt; the bar follows HP; a real `assist` press calls a companion. The
   assist flags are set test-only, as 9.5 does.
6. Save mid-fight and reload: FIGHT at once, no talk, the djinn at full HP, the hero inside the arena.
7. Lose: the djinn floats to the hero, `Lab_Boss_TakesCloak`, then the Game Over screen (paused), and no win flag.
8. Win: the last blow is a real `attack`, +500 XP, the line, OPEN, the gates up with no collision, the objective "Leave
   the laboratory".
9. Each bridge is reached by one real held jump (feet land at y 288, peak 277).
10. A real `move_right` goes through the gates into LaboratoryOutside.

## What is left

- **Register:** D307 (+ the B83 note) into `figma_decision_register.md`; B83 marked fixed for LabBoss in `BUGS.md`. B83
  still stands for `Laboratory.tscn` (the corridors' bridges, row 22 / row 38), which is the 9.6 lane. The queue row
  9.7 gets struck through.
- **Merge note for 9.5:** this branch only sets the assist flags inside the test. 9.5's `LabCells.gd` sets them in play.
  If 9.5 rebuilds the rooms with the builder, it picks up my builder changes (props keep children, edit-state pack).
  Those are harmless to LabCells, but its `.tscn` will differ in node ids.
- **`story.json`:** no `laboratory` zone objectives or chronicle for LabBoss (the title falls back to "Lab Boss"). That
  is 9.5's list.
- **9.8:** the demo end reads `lab_after_boss_complete`. `verify_lab_route.gd` should cover the cloak Game Over through
  the menu's "Resume".
- **Art:** the ArenaWall has none (an invisible edge, like the Mayor Hall). The cloak is not taken off the hero's sprite
  (there is no art for that).
