---
type: report
tags: [cloud, integrator, round-13]
---

# Integrator — round 13 (2026-10-24 → 2026-10-26)

**Summary.** All eleven branches are merged into `feature/backlog` in order, none skipped: lab-curse, chibi-npcs,
rooms-1, b145, big-leader, big-scorpion, big-archer, big-vulture, big-brute, big-guard, jackal-pack. D-IDs were renumbered
to **D694–D712**, after the orchestrator's D693 picks row, and are in [[figma_decision_register]] in order with no
duplicates. B rows fixed: B127 and B147. Filed: B148, plus **B149** today. B145 stays open with better crash logging.
Q91–Q97 are filed in [[questions_for_sapega]] with defaults, none blocking.
**Full suite: 116/119, `SUITE: 3 FAIL` on the first run.** All three were merge interactions, fixed in the tests, and
each passes when re-run alone. The full suite was not run a second time.

## Merged

| Branch | D-IDs (register) | B | Q | Conflicts |
|---|---|---|---|---|
| lab-curse | D694, D695 | — | — | none |
| chibi-npcs | D696, D697 | B127 fixed | — | none |
| rooms-1 | D698–D701 | — | Q91–Q93 | `verify_enemy_variety` big-slot count |
| b145 | D702 | B145 open (+ investigation line) | — | none |
| big-leader | D703 | — | — | bestiary, sound_events, en/uk.po, `DefaultEnemy._coin_drop`, three verify scripts |
| big-scorpion | D704, D705 | B148 filed | — | enemy_variety.json, sound_events, three verify scripts |
| big-archer | D706, D707 | B147 fixed | Q94 | enemy_variety.json, sound_events, two verify scripts, the sheet's `.import` |
| big-vulture | D708 | — | Q95 | enemy_variety.json, sound_events, two verify scripts |
| big-brute | D709, D710 | — | Q96 | sound_events, three verify scripts |
| big-guard | D711 | — | Q97 | bestiary, en/uk.po, enemy_variety.json, sound_events, three verify scripts |
| jackal-pack | D712 | — | — | none in text; a duplicate `HitAreas` preload |

Every conflict was additive: each branch added its own kind, and all kinds were kept.

## Merge interactions fixed

During the merges (2026-10-24, inside the merge commits):
1. `verify_hit_areas` [3] strikes five kinds in a row, and the fifth found the hero already dead. Each strike case now
   starts the hero at full HP.
2. rooms-1's Bandit Camp slot now spawns the brute too, so the brute has four slots. `verify_enemy_variety` counts them.
3. jackal-pack and big-leader both added `const HitAreas = preload(...)`, which made a parse error. One is kept.

After the merges (2026-10-26, one commit each):
4. **`verify_main_menu`**: `RESULT: ALL PASS, 2 SCRIPT ERROR` (`Could not preload … HealingPalm.tscn` at `Village.gd:23`).
   The test freed the game and quit while the RoomPreloader was still loading the Canyon's new door target, LizardCave.
   It now waits for `room_preloader.busy()`, as `verify_graphics_quality` already did. Re-run: ALL PASS, 0 SCRIPT ERROR.
5. **`verify_skill_screen` and `verify_skill_trees_ui`**: `RESULT: HUNG — killed after 180 s`. `verify_skill_screen`
   hung in 2 of 3 runs even when run alone. gdb shows a deadlock: the main thread waits inside the `load()` that opens
   the game menu, while a worker loading the Canyon's neighbours waits on a lock the main thread holds. Round 13 gave the
   Canyon more and heavier neighbours to preload (the side rooms and the elite scenes). Both tests now wait for the
   preloader before opening the menu: 6/6 ALL PASS each. **The game itself can still hang this way, so B149 is filed**
   (major): open the menu right after a room change and it may freeze.

## What Sapega should test first in the build

1. **B145 crash log.** Walk down out of the Canyon several times. If the game crashes, send `godot.log`. Release builds
   now flush it line by line and keep GDScript call stacks (D702). The last lines `🚪 Game: room swap X → Y` and
   `… done` show which room swap died.
2. **B149.** Right after entering a room (especially the Canyon), open the game menu (Skills tab) at once. If the game
   freezes, that is B149.
3. **The new elites, and where each one stands:**
   - **Jackal pack leader**: DesertRoad `Fight_Dunes`, L2 (454 HP, hits for 41). The first elite on the road.
   - **Armoured scorpion**: DesertRoad `Fight_Caravan` (L3) and Laboratory `Fight_Lower` (L10).
   - **Heavy archer**: DesertRoad `Fight_Mesa` (L3), in a pair. The road has no ordinary archer before it (Q94). Its
     arrow is aimed down from a bow drawn above the hero's head (D707).
   - **Bandit brute**: DesertRoad `Fight_LoneElite` (alone), the Bandit Camp's `Fight_Camp`, and Laboratory
     `Fight_Upper` ×2. The camp can be reached before the lone fight (Q96). `Fight_Dunes` is an ordinary bandit again.
   - **Old vulture** and **tower shield guard**: live, but **not placed**, so nothing spawns them yet (Q95, Q97).
   - The ordinary jackal now draws the pack-jackal sheet (D712).
4. **The five side rooms** (D698):
   - **LizardCave**: a cave mouth east of the canyon exit. Its gate needs Grandfather's Old Key, which comes from his
     decision talk.
   - **DragonMural**: behind a cracked boulder on the canyon plateau, broken by a heavy blow.
   - **BanditCamp**: through a tent on the Desert Road dune top. Inside are waves of enemies, the Stockade Key and a
     shortcut out by `SavePoint_BeforeCity` (Q93).
   - **MesaClimb**: up a ladder off the Desert Road.
   - **GatehouseCellar**: at City Gates, opened by talking to the gate guard (TalkSpot, D700).

   The canyon rooms can only be reached before the descent (Q91).
5. **The cursed jackals in the Laboratory** (D695): first one alone in the new `Fight_Cursed` on the middle storey (L9),
   then a pair as the second wave of `Fight_Lower`. A fight never holds two cursed kinds.
6. **The chibi NPCs** (D696, D697): Malik, the alchemist and the companion guard on their chibi sheets, with new
   portraits. In LabCells, Alisia lies on the operating table for the injection and sits up dazed (B127).
   `village_elder.tscn` still shows Malik's old sheet.

## Not done / next

- B149: the game-side fix. One option is that the menu (or any main-thread `load()` of a heavy scene) waits while
  `RoomPreloader.busy()`, or the warm-up preloads the skills window. Not done, because it is outside an integrator's
  scope.
- Q91–Q97 are open for Sapega. The defaults are built.
