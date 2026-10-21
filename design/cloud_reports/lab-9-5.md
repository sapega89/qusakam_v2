---
type: report
tags: [cloud, lab, cutscene]
---

# Cloud report — queue row 9.5 (branch `cloud/lab-9-5`)

The Laboratory cells: cutscene, wake, acquaintance, Малік, assists ([[lab_story_plan]] slices 5–6, D304/D305,
[[play_feedback_queue]] row 9.5). Godot 4.6.2 ran headless in the cloud; no display, so no captures — layouts are
described below in words. Sapega was not reachable: every call below is an **agent call, Sapega to confirm**.

## What was built

- `SampleProject/Scripts/Gameplay/Scenes/LabCells.gd` — new, written from the plan (the `refs/wip/row9^3` draft is not
  in this clone). States `CUTSCENE → AWAKE → ACQUAINTANCE → FREE` (`:22`), entry state from flags only (B53, `_ready` `:53`):
  - `_cells_cutscene` (`:84`) — the cells cutscene on the shared `Cutscene` (D308), started deferred so the Mayor Hall's
    `cs.end()` after its teleport runs first.
  - `_acquaintance` (`:161`) — fired by `StepOutTrigger` in AWAKE (`_on_step_out` `:156`).
  - `_lay_out_awake` (`:198`) / `_lay_out_free` (`:210`) — the room after each beat; a skip and a load land in the same layout.
  - `_open_door` (`:215`), `_walk` (`:227`, lab NPC scenes), `_run` (`:235`, `CompanionNPC`).
- `SampleProject/Maps/LabCells.tscn` — script attached; new nodes `CellLock` (StaticBody2D, east wall of the hero's
  cell, x 266), `StepOutTrigger` (Area2D, x 300), `ExitDoor` (StaticBody2D at the east edge, x 1712, + `Sprite` = the
  generated portcullis `Lab/gen_gates` ×0.85, z −2), `Marks/*` (Look, Table, ScientistTable, PrisonerEnter,
  PrisonerTable, DjinnUp, Blast1–4, Meet, MeetLook, MalikMeet, Exit); the three `CompanionNPC_*` placed by the builder.
- `Scripts/Tools/build_laboratory.gd:95` — LabCells `npcs`: Астрит cell 2 (x 400), Алісия + cat cell 3 (x 650, next
  to the table), Уризен cell 4 (x 1200); Малік stays in cell 5 (x 1450). Corridors: companion triggers and NPCs
  removed, `StateChangeTrigger_LimitTest` → `StateChangeTrigger_Fight`. (Re-ran the builder; `LabBoss.tscn` only got
  `unique_id` churn and was restored.)
- `SampleProject/Scenes/FX/Bosses/explosion.tscn` — new, the `wall_burst.tscn` pattern on the generated
  `Assets/FX/Bosses/explosion.png` (D316): scale 1 → 3.2 and fade over 0.9 s, frees itself.
- `SampleProject/Resources/Data/quests.json` — task `malik_escort` "The Humble Place".
- `SampleProject/Resources/Data/story.json` — zone `lab_cells` (scene `LabCells`) + zone `laboratory` trimmed.
- `SampleProject/Scripts/Gameplay/Scenes/Laboratory.gd` — companion states, limit test and their dialogue handling
  removed: EXPLORE → (fight trigger) BOSS_FIGHT → AFTER_BOSS until row 9.6 rewrites the corridors.
- Deleted `dialogue_quest/Lab_Companion_01..03.dqd`, `Lab_LimitTest.dqd`; `lab_limit_test_complete` no longer set or read
  anywhere (only `game.twee`, the legacy story export, still names them).
- Dialogue: the eight `[ЧЕРНЕТКА]` drafts from `5e79691c` were already in the tree (Ukrainian, speaker in the speaker
  field) and are used unchanged: `Lab_Cells_Arrival`, `_Injection`, `_Prisoner` (the Q64 incantation), `_Djinn`,
  `_Faint`, `_Awake`, `Lab_Acquaintance`, `Lab_Malik_Quest`.
- Tests: new `SampleProject/UI/verify_lab_cells.gd`; updated `verify_laboratory.gd` ([2]–[4]), `verify_lab_rooms.gd`
  (enters the cells after the acquaintance — doors only), `verify_mayor_hall.gd` (`_in_lab` meets the cells cutscene
  and skips it with a real Tab hold), `verify_demo_end.gd` (flag list).
- `design/lab_story_plan.md` — slices 5–6 struck, *Built — slices 5–6* section.

### The cells room in words (no capture possible)

One floor, 1728 px. Five cell niches along the back wall, bars drawn over whoever stands in them; the operating table
in the middle (x 925). The hero lands in cell 1 (far west) behind bars. The camera drifts to the table; the bars of
cell 3 vanish, Алісия (with her cat) runs to the table, the alchemist walks up and plays his injection frames, she runs
back and her bars return. The bandit-like prisoner walks in from the east door to the table, shouts the incantation,
the screen shakes, he collapses; the fire djinn fades in over him and lifts 40 px, says its two lines, then flies up
out of the top of the screen while four explosions go off across the room (by the table, right of it, left of it, by
the east cells) with shakes, then a long earthquake shake; the alchemist runs out east. Camera back to the hero, he
staggers (Hurt), his thought cloud, black. Light: every bar is gone, the alchemist too, the prisoner lies by the
table, the others stand in their open cells. Two thought clouds. When he walks out of his cell the camera frames the
cells, the acquaintance talk; Малік walks over from the last cell, his talk; the three run to Kusakam and vanish (three
"joined the party" notices); Малік walks east and fades into the dark; the portcullis at the east edge rises.

## Decisions (ready to paste into [[figma_decision_register]])

| D304 | GAP | **The Laboratory cells cutscene** (BACKLOG 17, queue row 9.5, [[lab_story_plan]] beat 4; agent call, Sapega to confirm). One `Cutscene` (D308) the moment `LabCells` loads without `lab_cells_cutscene_complete` (teleport from the Mayor Hall, either outcome, or a load); a hold of Tab / pad Y runs it at ×8 to the wake, same end state. Kusakam lands behind bars in cell 1 (`CellLock` keeps him in); `Lab_Cells_Arrival`; Алісия (cell 3, next to the table) is led to the operating table and injected by the alchemist (`inject` frames), then back into her cell; the bandit-like prisoner is led in from the east door; `Lab_Cells_Prisoner` ends on the **invented incantation «Варра-кхесс ум-тал! Шакраз-ідуун! Тахмі-ракх аш-зарра!»** (Q64 answered); he shouts (small shake) and collapses; the **fire djinn** — the real `fire_djinn.tscn` as a puppet (AI off, only its animation) — fades in over him, `Lab_Cells_Djinn`, flies out through the ceiling; **four explosions** (generated `explosion.png`, new `explosion.tscn`, no flash) with shakes and a 1.6 s **earthquake** (`Cutscene.shake`); the alchemist runs off east; Kusakam staggers (`Hurt`), `Lab_Cells_Faint` as a timed thought cloud (D178), black → `lab_cells_cutscene_complete`. The djinn does not stay in the room (it waits in `LabBoss`, row 9.7); the prisoner stays lying by the table (decor, no talk). Drafts `[ЧЕРНЕТКА]`. Test `verify_lab_cells.gd`. |
| D305 | GAP | **Wake, acquaintance, Малік, all assists at once** (BACKLOG 17, queue row 9.5, [[lab_story_plan]] beats 5–6; agent call, Sapega to confirm). After the black: every bar gone, cell 1 open, the alchemist gone, belongings untouched (the inventory is never changed), Астрит (cell 2), Алісия (cell 3), Уризен (cell 4) and Малік (cell 5) still in their cells; `Lab_Cells_Awake` (timed cloud); objective "Step out of the cell". **Stepping out** (`StepOutTrigger`, just east of cell 1) starts the second cutscene (skippable the same way): `Lab_Acquaintance`, Малік walks over, `Lab_Malik_Quest`; the task **`malik_escort` "The Humble Place"** is taken with no menu (it cannot be refused; `needs_flag` `lab_outside_complete`, **no reward set** until Малік's humble place exists — BACKLOG 17 "appears later as an NPC"); **all three assists unlock at once** (`lab_companion_01..03_complete` + `join_on_unlock`, D209/D220 — all three join the party of 3), each runs to Kusakam and vanishes (D230); Малік walks east and fades out "in the shadows"; `lab_acquaintance_complete`; the east portcullis (`ExitDoor`, generated `gen_gates`) rises, objective "Fight through the laboratory". Flags-only resume (B53): cutscene flag → the wake layout with the hero in his cell, no lines replayed; acquaintance flag → door open, cells empty. Retired: `Lab_Companion_01..03`, `Lab_LimitTest`, `lab_limit_test_complete` (party size 3 stays without the limit-test talk, D220). `story.json`: zone `lab_cells` ("Find out where you are" → "Step out of the cell"), zone `laboratory` ("Fight through the laboratory" → "Leave the laboratory"). Test `verify_lab_cells.gd`. |

## New bugs (ready to paste into [[BUGS]])

- **B-new — a `Cutscene` that never reaches `end()` outlives its game.** `Cutscene._init` connects `_hold_later` to the
  autoload `DialogueManager.dialogue_started` and hides `Game/UI` + `Game/UICanvas`; only `end()` undoes that. If the
  game is freed mid-cutscene (quit to the main menu or load a save during a cutscene), the next game's first dialogue
  calls `hold()` on the freed hero → **segfault** (`Cutscene.gd:54`, seen in this pass when a test abandoned a
  cutscene); a second cutscene in the same game also sees the HUD already hidden and never shows it again.
  Fix idea: the cutscene ends itself on `player.tree_exiting` (disconnect, `Engine.time_scale = 1`). Not fixed here
  (shared D308 code, outside the row).
- Note (not a bug): re-running `build_laboratory.gd` re-saves each room through `PackedScene.pack`, which writes every
  node's `unique_id` anew (diff noise in `LabBoss.tscn`, restored) and would expand an instanced *inherited* boss scene
  (`fire_djinn.tscn`) into a copy of its overrides — that is why the djinn is instanced from code, not placed.

## Verifies run (Godot 4.6.2, headless)

| Verify | RESULT |
|---|---|
| `verify_lab_cells` (new, 79 checks) | RESULT: ALL PASS |
| `verify_lab_rooms` | RESULT: ALL PASS (after the update; before it: 8 FAIL — the cells' door was shut by the new story) |
| `verify_mayor_hall` | RESULT: ALL PASS (after the `_in_lab` update) |
| `verify_companions` | RESULT: ALL PASS |
| `verify_laboratory` | RESULT: ALL PASS |
| `verify_demo_end` | RESULT: ALL PASS |

| `verify_journal` | RESULT: ALL PASS (expects 8 sub-stages now — the new "Laboratory — Cells") |
| `verify_story_journal` | RESULT: ALL PASS (same) |
| `verify_map_geometry` | RESULT: ALL PASS (after `Marks/DjinnUp` moved inside the room, y −200 → 8) |
| `verify_audio` (alone, twice) | RESULT: ALL PASS |

Full suite (`Scripts/Tools/run_verify.sh`, 70 verifies):
- first run: 67 PASS, 3 FAIL — `verify_journal`, `verify_story_journal` (the new zone), `verify_map_geometry` (a mark
  above the room) — all three caused by this row and fixed in `Row 9.5: djinn fades under the ceiling …`;
- final run on the pushed head: **SUITE: 1 FAIL — 69 PASS**, the one being `verify_audio` "focusing a button (pad
  navigation) ticks on SFX" (`verify_audio.gd:276`, a one-frame `playing` check on the menu focus sound — no Lab code
  involved). It passed in the first suite run and twice alone right after → a timing flake, not this row's.

`verify_lab_cells.gd` with real input: [1] teleport from the Mayor Hall → the cutscene plays every beat in order
(Алісия led to the table and back, the djinn shown, explosions), lands in AWAKE with HUD / control / speed back;
[2] the same start skipped with a real **Tab** hold → identical state (flags, objective, NPC positions, bars, lock, door,
actors, party, hero position); [3] re-entering never replays it; [4] real `move_right` out of the cell → the
acquaintance and Малік, `task_malik_escort_taken`, three unlock flags, party of 3, a real **F** press calls an assist;
[5] the acquaintance skipped with a real **pad Y** hold → identical state; [6] saves carrying only flags load into the
cutscene / the wake (hero in his cell, nothing replays) / the free room; [7] real `move_right` walks east into the
corridors.

## What is left

- **Row 9.6** — the corridors: `Laboratory.gd` still runs the old single mob fight that sets
  `lab_boss_fight_complete` / plays `Laboratory_BossFight` + `Laboratory_AfterBoss`; that flag must move to the djinn
  (LabBoss, row 9.7) when the corridors get their three trigger-zone fights (D306).
- Малік as a walking NPC and the gold at his humble place (BACKLOG 17, out of scope) — `malik_escort` has no reward
  and cannot be handed in until then (`lab_outside_complete` is only its gate).
- No captures (no display in the cloud): `capture_lab_cells` / `fb17_*` sheets still to make on Sapega's machine;
  the room positions (explosion marks, door scale 0.85 — it slightly overlaps the edge of cell 5's niche) want a look.
- Boss voices / the incantation via Kokoro (D278 hook) stay with row 9.8.
- The B-new above; the `verify_audio` focus-tick flake (seen once) if it recurs.
- Local only, not committed: `chmod +x` on `Scripts/Tools/godot_locked.sh` and `run_verify.sh` (they are 644 in git, so
  `run_verify.sh` cannot call `godot_locked.sh` on Linux until someone commits the mode change).
