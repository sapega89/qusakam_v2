---
type: plan
status: in-progress  # 2026-10-21: plan, B79 leftover, boss art (D309), draft lines done; code WIP in git stash; rest = queue rows 9.1–9.8
---

# The Mayor Hall and the Laboratory story — plan

BACKLOG **16** (Mayor Hall queue, the wall bursts, the "unbeatable" boss), **17** (the rewritten Laboratory story),
**6** (the Laboratory boss) and the Laboratory part of **23** (the Laboratory split into screens) as one story block.
Sapega was asleep for the whole pass ([[play_feedback_queue]] rules): every call below is an **agent call recorded as a
D-ID, Sapega to confirm**. Bosses: [[lab_boss_plan]]. Cutscene helpers, HUD and skip: [[cutscene_plan]].
Rooms: this note (supersedes the outline in [[world_expansion_plan]] and the storeys of [[lab_vertical_plan]]).
Figma: no design exists for any of it (story beats are in-world; the boss bar has no frame, [[figma_coverage]] §1).

## What exists today (2026-10-21, before this pass)

| Thing | Where | State |
|---|---|---|
| Mayor Hall | `Maps/MayorHall.tscn` (1 cell, `[11,3,0]`), `MayorHall.gd` — trigger at x 600 plays `City_MayorHall` (3 `[PLACEHOLDER]` lines) → `city_mayor_hall_complete` → teleport to `Laboratory/SavePoint_Entrance` (D130) | ⚠️ dialogue + cut |
| Laboratory | `Maps/Laboratory.tscn` 2×3 cells `[14..15,3..5,2]`, three storeys joined by ladders (D225), generated planes and slab surfaces (D246), built by `Scripts/Tools/build_laboratory.gd` | ✅ geometry; story is the old one |
| Old lab story | `Laboratory.gd` states EXPLORE → COMPANION_01..03 → LIMIT_TEST → BOSS_FIGHT → AFTER_BOSS; `Lab_Companion_01..03`, `Lab_LimitTest`, `Laboratory_BossFight`, `Laboratory_AfterBoss` `.dqd` | replaced by this plan |
| Old lab flags | `lab_companion_01..03_complete` (also the assist unlock keys, `CompanionManager.UNLOCK_FLAGS`), `lab_limit_test_complete`, `lab_boss_fight_complete`, `lab_after_boss_complete` | unlock keys kept; limit test retired |
| Companions | `CompanionNPC.gd` (idle / run, `join()` runs to the hero and vanishes, D230); art two views D243–D245; assists D201/D209/D213, one button F / pad LT | ✅ |
| "Boss" | `Laboratory.tscn` `EnemySpawner`: tank, melee, fast, tank (four ordinary enemies) | ⚠️ not a boss (Q52) |
| `DemoBoss.gd` | `Characters/Bosses/DemoBoss.gd` 316 lines, instanced nowhere, hits through `safe_take_damage` around the hitbox | ❌ dead code → replaced by `BossEnemy` |
| Boss HP bar | `DefaultEnemy._initialize_health_bar` skips bosses ("a full-screen bar" that never existed) | ❌ |
| End of the demo | `LaboratoryOutside.gd` EXIT_LAB → DEMO_CLOSING → `DemoEndScreen` (B43, B66 fixed; `verify_demo_end`) | ✅ kept |
| Hero defeat | `Player.die()` → `GameOverScreen.present()` | ✅; no hook for a scripted defeat |
| Cutscene code | inline camera/lock/walk in `Canyon.gd` (meditation, descent), `CityGates.gd` (raid), `NpcArrival.gd`; no skip; HUD stays | ⚠️ |

## The new rooms (D303)

MetSys layer 2, cell 864×480 (`Resources/Settings.tres`). Each room is its own `.tscn`, built by
`build_laboratory.gd` from an ASCII layout (hidden collision tiles + generated slab surfaces + generated planes).

| Room | Cells | What happens |
|---|---|---|
| `LabCells.tscn` (new) | `[12..13,3,2]`, one floor | the cells floor: five cells along the back wall and the operating table in the middle; the cells cutscene, the wake, the acquaintance, Малік's quest; exit door east (shut until the acquaintance) |
| `Laboratory.tscn` (kept, the corridors) | `[14..15,3..5,2]` | the three storeys stay; the companion triggers, companion NPCs and the limit test go; three trigger-zone mob fights (one per storey, D306); entrance west on the top storey from the cells, exit east on the bottom storey; `SavePoint_PreBoss` stays |
| `LabBoss.tscn` (new) | `[16..17,5,2]`, one floor | the fire djinn's hall: the cloak talk, the fight, the gates east shut until it is dead (D307) |
| `LaboratoryOutside.tscn` (moved) | `[18..19,5..6,2]` (was `[16..17,5..6,2]`) | unchanged inside: the closing talks and the demo end screen |

## Story beats, flags, resume points

| # | Beat | Room | Sets | Resume (`_initial_state`) |
|---|---|---|---|---|
| 1 | Queue: Kusakam walks in, Астрит, Уризен, Алісия stand in line for the mayor, he joins the end (D255); `City_MayorHall` (drafts) | MayorHall | — | no save point in the hall; a reload starts at the City save |
| 2 | The wall bursts (shake, dust, debris), the **Brass Collector** climbs out of the hole; the three run out west; `MayorHall_WallBurst`; the way back is barred | MayorHall | — | — |
| 3 | The fight (D301). **Lose** → no game over: the hero is knocked out, black, `MayorHall_Defeat`. **Win** → +XP and loot (D300), a gas cloud from the golem's cage, `MayorHall_Victory`, black | MayorHall | `mayor_boss_defeated` (win only), `city_mayor_hall_complete` | — |
| 4 | Teleport to the cells: Kusakam behind bars; the alchemist leads Алісия to the table and injects her; leads in a bandit-like prisoner; the prisoner shouts an **invented incantation** (Q64 default); a **fire djinn** bursts out of him and flies off through the ceiling; explosions, an earthquake; Kusakam passes out | LabCells | `lab_cells_cutscene_complete` | flag unset → the cutscene plays (the teleport is not a save) |
| 5 | Wake: the bars are gone, every belonging in place, everyone still in their cell; `Lab_Cells_Awake` (cloud) | LabCells | — | `lab_cells_cutscene_complete` → AWAKE |
| 6 | He steps out of his cell: acquaintance (`Lab_Acquaintance`), **Малік** offers gold at his "humble place" and asks to be led out — the quest cannot be refused (`Lab_Malik_Quest`, task `malik_escort` taken without a menu); all three assists unlocked at once (the three `lab_companion_0N_complete` flags), the companions run to Kusakam and vanish (D230), Малік slips off "in the shadows" (he is an NPC later, BACKLOG 17); the east door opens | LabCells | `lab_acquaintance_complete`, `lab_companion_01..03_complete`, `task_malik_escort_taken` | `lab_acquaintance_complete` → FREE (door open, nobody in the cells) |
| 7 | Three mob fights on the three storeys (spawn on a trigger zone, remember their dead, D152) | Laboratory | room state per spawner | room state |
| 8 | The djinn waits; trigger → the cloak talk (`Lab_Boss_Talk`): who are you — I am ready to bargain — give me the cloak — it is my grandfather's; the hall seals (west barrier) | LabBoss | `lab_boss_talk_complete` | talk done → the fight starts at once on re-entry (no talk replay) |
| 9 | The fight (D302). **Djinn wins** → `Lab_Boss_TakesCloak` (it takes the cloak), game over (Game Over screen → last save). **Djinn loses** → `Laboratory_AfterBoss`: «Не знаю, чи віддали б ви плащ, а я — ні.»; the gates open | LabBoss | `lab_boss_fight_complete`, `lab_after_boss_complete` | `lab_boss_fight_complete` → OPEN (gates up) |
| 10 | Walk out → `LaboratoryOutside` (as built: `Laboratory_Outside`, `Demo_End`, the demo end screen) | LaboratoryOutside | `lab_outside_complete`, `demo_end_complete` | as built (B66) |

`story.json` → zone `laboratory`: objectives "Escape the cell" (`lab_cells_cutscene_complete`), "Step out of the cell"
(`lab_acquaintance_complete`), "Fight through the laboratory" / "Defeat the fire djinn" (`lab_boss_fight_complete`),
"Leave the laboratory" (`lab_after_boss_complete`); chronicle lines per flag. `lab_limit_test_complete` is retired
(the party size D220 stays 3 without the limit-test talk).

## Calls made (D300–D310, agent calls, Sapega to confirm)

D300 Mayor Hall beat · D301 the Brass Collector · D302 the fire djinn · D303 the room split · D304 the cells cutscene
and the Q64 incantation · D305 wake, acquaintance, Малік, assists at once · D306 the mob corridors · D307 the boss hall
lock, the cloak talk and both endings · D308 shared cutscene helpers, HUD hidden, hold-to-skip · D309 generated art ·
D310 boss voices and cutscene lines. Text of each: [[figma_decision_register]].

## State (2026-10-21, end of the first agent)

Done and committed: this plan; slice 0 (B79 leftover, `b2f50186`); boss art for both bosses (D309, sheets in
`Assets/Characters/Bosses/`); all draft `.dqd` lines of the block and five speakers (`5e79691c`). Written but never run,
kept in **`git stash` "queue row 9 WIP drafts"**: `Cutscene.gd`, the skip prompt, `BossEnemy` / `BossLogic` / hazards,
the boss bar, `MayorHall.gd`, `LabCells.gd`, `LabBoss.gd`, and the rewrites of `City_MayorHall.dqd` (the queue talk)
and `Laboratory_AfterBoss.dqd` (the cloak line). D-IDs written so far: D308 (row 9.1), D309 — D300–D307 and D310 get written by
the sub-row that builds them (texts in this note and [[lab_boss_plan]]). The remaining slices are queue rows 9.1–9.8
in [[play_feedback_queue]].

## Slices (each its own commit and verify)

0. B79 leftover — XP reset at a New Game (`Game._initialize_save_and_room`); `verify_xp_curve` [4].
1. **Cutscene helper + HUD + skip** (`Scripts/Systems/Cutscenes/Cutscene.gd`, `cutscene_skip` action in `CombatInput.gd`,
   `Scenes/UI/cutscene_skip_prompt.tscn`); Canyon meditation/descent, CityGates raid and `NpcArrival` moved onto it;
   `verify_cutscene.gd` (lock, HUD hidden, real hold of Tab / pad Y skips, control and HUD back) + the old verifies.
2. **Bosses core** — `BossEnemy` + `BossLogic` (move sets), boss HP bar, `Player.defeat_handler`; `verify_bosses.gd`.
3. ~~**Mayor Hall** — queue, wall burst, Brass Collector, both outcomes → LabCells; `verify_mayor_hall.gd` (replaces
   `verify_mayor_hall_teleport.gd`).~~ — done (D300, queue row 9.3); the teleport goes to the old Laboratory entrance until 9.4.
4. **Laboratory split** — `LabCells`, `LabBoss`, MapData, `Laboratory` corridors re-laid; `verify_map_geometry`.
5. **Cells cutscene** — injection, prisoner, djinn, explosions, faint; `verify_lab_cells.gd`.
6. **Wake + acquaintance + Малік + assists**; `verify_lab_cells.gd` [wake …].
7. **Mob corridors** — three fights; `verify_laboratory.gd` rewritten.
8. **Boss hall** — lock, cloak talk, fight, game over / win line, gates; `verify_lab_boss.gd`.
9. **Demo end** — the walk out, `verify_demo_end` updated; full route `verify_lab_route.gd` (Mayor Hall → demo end, both
   Mayor outcomes, the cloak game over, save/reload mid-Lab — B53).
10. **Art and voices** — comfy-sprite (Brass Collector, fire djinn, Малік, prisoner, alchemist), comfy-backdrop (cells,
    boss hall), generated effects (D273 practice), Kokoro lines (D278 hook).

## Out of scope for this pass

- Малік as a walking NPC and the gold at his "humble place" (BACKLOG 17: "appears later as an NPC"); the task stays open.
- A Figma boss bar (none exists); per-type mob art (D139/D196 — the corridors use the existing melee/tank/fast).
- The maze after the lab (D130 "wanted later").
