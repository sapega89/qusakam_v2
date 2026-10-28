---
type: cloud-report
branch: cloud/wire-backdrops-2
date: 2026-10-28
---
# Cloud report: wire-backdrops-2

**Summary**
- **Done:** the rest of the painted Canyon backdrops are now in their rooms (Sapega: «every finished art must be in the game»): **Dunes, Chasm, Gate Approach, Canyon Floor, Dry Riverbed, Cave Exit, Smugglers' Stash, Old Ruins and Aqueduct**. They are wired in `Scripts/Tools/build_world_rooms.py` (`PAINTED`), so a rebuild keeps the art. Six doorways are now painted openings. The Chasm has its drawbridge art, the Gate Approach lever sits in its painted housing, and the Aqueduct cellar grate stands until `aqueduct_cellar_open` is set. Doors, gates, levers, the cover wall, the secret, holes and arrivals all still work.
- **Not done:** the room atmosphere each README lists (dust, sand trickles, bats, the lantern flicker). The Dunes `CampDoor`: the trailhead is painted, but the camp still opens off the Desert Road (world-rooms Q-a).
- **D-IDs:** D868–D870 below. The register ends at D863 and wire-backdrops used D864–D867, so the orchestrator may need to renumber.
- **B rows fixed:** none.
- **Full suite:** `SUITE: 3 FAIL in 20 min 43 s, J=4` (142 scripts, 139 PASS). verify_difficulty (17) and verify_lab_boss (2) are integrate-31's known balance reds (Q114, Q116–Q118). verify_camera_transitions (1, BanditCamp, a room this branch does not touch) fails intermittently: 2 of 4 runs here, 0 of 3 on the parents (details below).

This branch is `origin/cloud/integrate-31` with `origin/cloud/wire-backdrops` merged in. It keeps integrate-31's text in `design/HANDOFF.md` and `MASTER_PLAN.md`. Godot 4.6.2 was downloaded and ran here. The `room-content` skill is not in this checkout (`.claude/` is gitignored), so I worked from the nine READMEs and D747/D750/D814/D830/D834.

## D-ID text (for the orchestrator)

| D | Kind | Text |
|---|---|---|
| D868 | ROUTINE CALL (wire-backdrops-2) | **The rest of the Canyon takes its painted planes from each folder's README, wired in the generator.** `PAINTED` in `build_world_rooms.py` now has entries for Dunes, Chasm, GateApproach, CanyonFloor, DryRiverbed, CaveExit, SmugglersStash, OldRuins and Aqueduct. The desert road rooms continue Zahra's Rest through `desert_backdrop_open.tscn`, with `Plan3` scroll offsets 518.4 / 345.6 / 86.4. They share the Dunes' dune and near planes, shifted by the READMEs' offsets. Every Parallax2D plane scrolls only on x (y factor 1, because the camera's y is fixed in these rooms). **Painted openings:** six doors lose their cave-mouth `*DoorEntrance` and are added to `PAINTED` in `verify_room_entrances.gd`: `OldRuins/WellDoor` (x 151), `Aqueduct/ApproachDoor` (2891), `Aqueduct/CellarDoor` (3291), `GateApproach/AqueductDoor` (1291), `CanyonFloor/StashDoor` (300, still covered by `Wall_Stash`, which now shows the painted `gen_cracked.png`) and `SmugglersStash/ExitDoor`. The stash's exit and `Arrival` move from x 432 to **192**, the painted tunnel. The arrival y stays the generator's floor − 24 (360), not the README's 344. **Chasm:** the drawbridge `Plank` is `Chasm/gen_bridge.png` (×1.5, offset −384, no region): lowered it lies on the 144…720 collision, and raised it stands on the east lip. The Canyon keeps its rope bridge. **Gate Approach:** `LeverHousing` is drawn before `BridgeLever`. The lever's `Base` is hidden and its `Handle` is at y −16, on the ratchet axle. **CaveUnderBridge** keeps its bottom pit at 96–224 (D866: the art's 90–225 snapped to the tile grid), so the Cave Exit's painted ceiling hole matches it with no change. |
| D869 | ROUTINE CALL (wire-backdrops-2) | **The Aqueduct's cellar grate is a picture tied to its gate's flag.** New `SampleProject/Scripts/Gameplay/FlagGrate.gd` (a Sprite2D, the counterpart of `FlagBridge`). The grate is visible while `aqueduct_cellar_open` is unset. When the flag is set, it rises its own height and fades out over 0.6 s. If the flag was already set, it is hidden on load. The passage itself is still locked by `CellarDoor.gate_id = "aqueduct_cellar"`. Behind the grate is the arch's dark opening (`gen_cellar.png`). |
| D870 | ROUTINE CALL (wire-backdrops-2, B177) | **Occluders in one-screen rooms.** In a one-screen room the camera is always at a room limit, so B177 (`verify_room_entrances` `_check_limits`) allows a ×1.3 occluder only in the outer 12 % of the view. The Smugglers' Stash stalactites therefore move from the README's x 496.5 to **775**, a strip at the top right over the peg rail. Three one-screen occluders stay at their README positions because their rooms are not in `verify_room_entrances` `ROOMS` (no doors): the Cave Exit stalactites, the Dry Riverbed boulders and the Chasm spur. All three stay clear of the hero: the stalactites and boulders hang or sit in corners, and the spur stays below the deck. If those rooms are ever added to that test, B177 asks for the same edge move. Front sprites are named `Occluder*` (D750) instead of the READMEs' `Thorn1`, `Column1` and so on. |

## Tests

| Test | Result |
|---|---|
| verify_world_rooms | PASS (falls into the riverbed with no bridge, crossing on the lowered bridge, the cellar gate and its lever) |
| verify_room_entrances | PASS (first run: 2 FAIL, `SmugglersStash: OccluderStalactites rests off the middle at the left/right camera limit`. Fixed by D870) |
| verify_map_geometry | PASS |
| verify_camera_transitions | **Intermittent**: PASS, FAIL (suite), FAIL (alone), PASS (alone, with the steps printed). The fail is `reaching the right limit it slows down, no hard stop (biggest one-frame drop 6.75 px)` in **BanditCamp**. The same test passed once each on `integrate-31`, on `wire-backdrops` and on this branch's merge commit `5c38a28b` (clean worktrees). This branch changes nothing in BanditCamp, the camera or the player. The printed steps carry ±2.25 px (1 px × zoom) of frame jitter, and the limit is 4.5 px, so one extra jitter step fails it. A likely trigger is load and memory timing from the larger textures of the rooms visited earlier in the test, but that is not proven. The orchestrator should watch it in its next suite. |
| verify_camera_rooms | PASS when run alone. In the first run it shared 4 cores with 6 other tests and gave 1 FAIL: `CanyonFloor inside: the camera moves at most 13.2 px more than the hero in a frame (≤ 12)`, a frame hitch under load. |
| verify_secrets | PASS |
| verify_scripts_compile | PASS (includes the new `FlagGrate.gd`) |

Full suite (`run_verify.sh`, J=4, nproc = 4):

```
FAIL  verify_difficulty  8 s — RESULT: 17 FAIL, 0 SCRIPT ERROR
FAIL  verify_camera_transitions  387 s — RESULT: 1 FAIL, 0 SCRIPT ERROR
FAIL  verify_lab_boss  58 s — RESULT: 2 FAIL: balanced build: he dies in 2.3 of the mercenary's blows (351 HP; mace 129, club 206), balanced build: the mercenary takes 67 light hits (6800 HP, Phys. Atk. 89), 0 SCRIPT ERROR
SUITE: 3 FAIL in 20 min 43 s, J=4
```
verify_scripts_compile: PASS.

## Shots
Contact sheet `design/shots/wire_backdrops_2.png` (20 frames). Full frames are in `design/shots/wire_backdrops_2/`: `dunes_1/2/trail`, `chasm_raised/lowered`, `riverbed`, `aqueduct_breach/2/doors/open` (the grate before and after the flag), `ruins_well/2/arch`, `approach_lever/well`, `floor_crack/2/hole`, `cave_exit`, `stash`. To recapture: `capture_wire_backdrops.gd -- design/shots/wire_backdrops_2 design/shots/wire_backdrops_2.png 2` (new `SHOTS_2`; a fourth entry in a shot sets that flag first).

## Files
- `Scripts/Tools/build_world_rooms.py`: nine `PAINTED` entries plus their `PAINTED_SIZE`. Painted doors (`art None`) for OldRuins, Aqueduct, GateApproach, CanyonFloor and SmugglersStash. `covers` takes an optional texture, `levers` take an optional `{base, handle_y}`, and sprites take `flip`, `under: False` and `flag` (FlagGrate). `bridge()` draws `Chasm/gen_bridge.png`.
- `SampleProject/Scripts/Gameplay/FlagGrate.gd` (new).
- `SampleProject/Maps/{Dunes,Chasm,GateApproach,CanyonFloor,DryRiverbed,CaveExit,SmugglersStash,OldRuins,Aqueduct}.tscn` (generated; `MapData.txt` unchanged).
- `SampleProject/UI/verify_room_entrances.gd`: six `PAINTED` doors.
- `SampleProject/UI/capture_wire_backdrops.gd`: `SHOTS_2`.
