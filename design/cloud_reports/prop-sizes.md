---
type: cloud-report
branch: cloud/prop-sizes
date: 2026-10-28
---
# Cloud report: prop-sizes

**Summary**
- **Done (A11 + A12, B192 doors, B190 gates, D814):** palms are 4 H = 256 art. Every door sheet is now 112 art, and `mesa_cleft` got its 2-row re-cut. The locked gates `gen_gate.png` (BanditCamp, LizardCave) are 128 art. The City forge is one storey (144 art). All of it is done by scaling in the scenes, no redraw. The scale probe found **63 off objects of 332 judged** (the prompt's baseline was 111; this branch's base tables said 143). **None** of the 63 is a palm, door, locked gate or the forge.
- **Not done:** the painted doors on the City `CityNear` and Village `Houses` planes (A12 lists them, the prompt does not). Scaling them means scaling a whole backdrop plane, so they stay for the art lane.
- **D-IDs:** D-new-1…D-new-4 below. The orchestrator numbers them.
- **B rows fixed:** B192 (door sheets; the painted plane doors stay open, see above) and B190 (locked gates). This also does A11.
- **Full suite:** FULLSUITE_PENDING
- No `.claude/skills/room-content/SKILL.md` exists on this branch, `feature/backlog` or `main`. I followed `ROUTINE_RULES.md` and the root `CLAUDE.md` instead.

## D-ID text (for the orchestrator)

| D | Kind | Text |
|---|---|---|
| D-new-1 | ROUTINE CALL (prop-sizes, D814, A11) | **Palms are 4 H by scaling the one palm scene:** `Decor/palm.tscn` is scaled ×5.5 (it was ×1.5). The 70-px frame is now 385 world px against 384 (±1.5 tolerance). Every plane-1.0 palm (DesertRoad, Village, LaboratoryOutside `Decor/Palm*`) inherits it, so the size is set in one place. The FrontDark `OccluderPalm*` on plane 1.3 override this with ×7.15 (= 5.5 × 1.3, 500.5 world against 499.5). ×5.5 is not an integer factor: art pixels come out 5 and 6 screen px wide, alternating. The chart's ±1 art tolerance allows nothing that is an integer (×5 = 350, ×6 = 420). |
| D-new-2 | ROUTINE CALL (prop-sizes, D814, B192) | **Door sheets are 112 art through a per-art scale in `RoomEntrance.SCALES`.** The values are door_elder 2.21, cave_mouth 1.68, palisade_gate 1.93, lab_door 1.91 and palace_door 1.615. `mesa_cleft` stays at 1.5 because its sheet was re-cut from 110 to 112 rows (rows 44 and 52 duplicated, inside the dark passage; opening 23×47 → 23×49). All of these factors are non-integer, so pixels come out uneven. Each RoomDoor stays at the old height of its opening centre, now in the lower half of the bigger opening, so the hero on the floor still reaches it (< 64 px, the `verify_room_entrances` through-door check). Only the door's x is re-centred on the new opening (shifts of 0.7–2.3 px). `Scripts/Tools/build_world_rooms.py` uses the same table (`ART_SCALE`) in `door_pos`. The painted lab shafts keep the old `LAB_DOOR_Y`. |
| D-new-3 | ROUTINE CALL (prop-sizes, D814, B190) | **The locked gates are 128 art; their collision keeps its full height.** The `gen_gate.png` sprite is scaled ×0.693 (277 → 192 world), a downscale that drops rows. The Body keeps its 416 height so the lock still holds: a double jump (~206 px) would clear a 192-px wall. The Body is narrowed to the drawn width (BanditCamp 184 → 108, LizardCave 210 → 111, centred). The interaction Area moves with the gate's left face (−105 → −77, −135 → −79.5). The cost is an **invisible wall above the drawn gate** (see the open question below). The probe now reads a `LockedDoor.tscn` instance as `door_locked` (128 art) rather than `gate_big` (the head word «Gate» picked the city-gate row). |
| D-new-4 | ROUTINE CALL (prop-sizes, D814, D800) | **The City forge is one storey:** `Forge` is scaled ×1.05 (206 → 216.3 world against 216), anchored on its door sill. Its position goes from (934, 137) to (1019.5, 220.25), and `ForgeDoor` moves from x 1230 to 1227. **The ×1.3 occluder palms moved** so that D800 holds at the new width (400 world, 900 screen px). Each is off view or only at the outer 12 % at both camera limits, and covers no door, NPC or fight middle. Moves: Canyon 2112→1900, Village 669→800 and 3000→3040, DesertRoad 669→800, 3450→3680 and 6300→6420, CityGates 1808→820, City 1910→1460, LaboratoryOutside 669→820. B199 fade is unchanged. |

**Open question (not blocking, for Sapega):** the two locked gates are now 2 H tall under an open sky (BanditCamp) or a high cave (LizardCave). The 416-px collision above them is invisible. The options are:
- paint something over the gap (a palisade wall, a rock lintel);
- lower the collision to 192 and accept that a double jump clears the gate;
- keep the gates taller than D814 says.

I chose to keep the lock and flag the look. The capture shows it (`camp_locked_gate`, `cave_locked_gate`).

## Details

### What changed
- `SampleProject/Scenes/Backgrounds/Decor/palm.tscn`: scale 1.5 → 5.5.
- `SampleProject/Maps/{Canyon,Village,DesertRoad,CityGates,City,LaboratoryOutside}.tscn`: `FrontDark/OccluderPalm*` scale 3 → 7.15, new x (D-new-4).
- `SampleProject/Scripts/Gameplay/RoomEntrance.gd`: `SCALES`, applied in `_ready`; `OPENINGS.mesa_cleft` 47 → 49 rows.
- `SampleProject/Assets/Backgrounds/Decor/mesa_cleft/mesa_cleft_sheet.png`: 110 → 112 rows.
- Every map with a RoomEntrance: the RoomDoor re-centred across the new opening. That is 18 hand-built rooms (patched), plus 14 generated rooms rewritten by `build_world_rooms.py`, whose run is idempotent.
- `Scripts/Tools/build_world_rooms.py`: `ART_SCALE`, `door_pos` (x from the art scale, y at the 1.5 height), `ART_SIZE`/`OPENING` for the re-cut cleft.
- `SampleProject/Maps/BanditCamp.tscn`, `LizardCave.tscn`: the gate sprite, Body and Area (D-new-3).
- `SampleProject/Maps/City.tscn`: `Forge`, `ForgeDoor`.
- `SampleProject/UI/probe_world_scale.gd`: a `LockedDoor.tscn` instance is `door_locked`.
- `SampleProject/UI/capture_prop_sizes.gd`: new, the before/after frames.

### Scale probe (`probe_world_scale.gd` under xvfb, then `scale_chart.py`)
`design/shots/scale/tables.md`, `design/shots/scale_chart.png`, `design/shots/scale/probe.json` and the room grids are regenerated.
- 332 judged, **63 off** (32 too big). The prompt's baseline was 111; the tables on this branch's base said 143 off.
- Off by category: npc_adult 24, chest 10, door_locked 9 (the shrines: Canyon `Meditation/Shrine`, ElderHouse `Attic/Shrine`, DesertRoad `Shrine` and `Cage_TowerStash`, LizardCave `Back/Shrines/*`), house_storey 6 (WitchHut, Chapel, ElderHouse, GrandpaHouse, Shop, RockLedges burnt houses), tent 3, table_bench 3, gate_big 2 (CityGates `GatePassage`, LabBoss `Gates`), and one each of door (CityGates `CellarArch` ×1.01), elite_human, critter_tiny, crate, barrel and sack_pot. All of these are outside A11/A12 except the houses (A12 named only the forge).
- Palms, every `*DoorEntrance`, `Gate_Stockade`, `Gate_Shrine` and `Forge` are all within ±1 art.

### Tests (Godot 4.6.2 headless; exit 139 normal)
- verify_room_entrances: `RESULT: ALL PASS`. The first run gave 89 FAIL: the doors had been lifted to the bigger openings' centres, out of the hero's reach. They were put back at the old height. Then 11 FAIL on the D800 occluder rules, fixed by moving the palms.
- verify_map_geometry, verify_living_world, verify_ambient_critters, verify_world_rooms, verify_scripts_compile: `RESULT: ALL PASS`.
- verify_camera_transitions: `RESULT: ALL PASS` on the final doors. The run with the lifted doors gave 9 FAIL, «the transition never finished».

### Capture
`design/shots/prop_sizes.png`: 12 spots, each shown as before | after. The before half is the merged base commit, captured in a worktree. The spots are:
- DesertRoad: palms, palisade gate, mesa cleft, cave mouth
- Village: palms
- City: forge, door_elder
- CityGates: occluder palm
- BanditCamp and LizardCave: locked gates
- Laboratory: lab door
- MayorHall: palace door

The 5.5× palms read chunky (the uneven factor). The City occluder palm now passes in front of the forge.
