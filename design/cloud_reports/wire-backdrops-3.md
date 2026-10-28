---
type: cloud-report
branch: cloud/wire-backdrops-3
date: 2026-10-28
---
# Cloud report: wire-backdrops-3

**Summary**
- **Done:** the painted City backdrops are now in their rooms: **Craft Quarter, Palace Square, Rooftops, Pigeon Loft, Tavern Attic, Mayor's Archive, Cistern and Cistern Stash**. They are wired in `Scripts/Tools/build_world_rooms.py` (`PAINTED`), so a rebuild keeps them. 15 doors are now painted openings: the 12 in these rooms, the market's two ladders (`RooftopsLadder`, `AtticStall`) and the gate's rope (`RooftopsRope`). The forge, anvil and Blacksmith, and the chapel and the priestess of Samal, moved from the market to the Craft Quarter (D773). `ForgeDoor` moved with them. Kesh's tent and the dervish moved into the forge's old place, which clears the ladder behind the stall. Doors, gates, the cistern grate, covers, secrets, NPCs, shops and quests all still work.
- **Not done:** the room atmosphere the READMEs list (smoke, spray, banners, light dust). Two old captures still look for the smith or the priestess in the market (Left, below).
- **D-IDs:** D894–D896 below (numbered on `feature/backlog` 28.10 from the placeholders D894…D896).
- **B rows fixed:** **B207** (B-ct1): the City pigeons were drawn under the street.
- **Full suite:** `SUITE: 3 FAIL in 20 min 21 s, J=4`. verify_difficulty (17) and verify_lab_boss (2) are the known balance reds (Q114, Q116–Q118), as on integrate-32 and wire-backdrops-2. verify_weapon_animations (1, under J=4 load) passed on its one re-run alone. verify_camera_transitions and verify_room_entrances PASS.

This branch is `origin/cloud/rooms-finish` (its final report `c6c96fc3`, 12:26Z) with `origin/feature/backlog` merged in. It keeps feature/backlog's text in `design/HANDOFF.md` and `MASTER_PLAN.md`. The two conflicts were in those files only. It is a replacement run (Sapega 28.10). T = 12:26Z is after 11:38Z, and the original session had pushed nothing after T, so this is case (c). The stale «not started» report commit `d414ce76` (10:47Z) on this branch is merged in, not force-overwritten, and this file replaces it. Godot 4.6.2 was downloaded and ran here. The `room-content` skill is not in this checkout (`.claude/` is gitignored). I worked from the nine READMEs plus D750/D773/D814/D830.

## D-ID text (for the orchestrator)

| D | Kind | Text |
|---|---|---|
| D894 | ROUTINE CALL (`wire-backdrops-3`, D773/D844 as built) | **The City's side rooms and its new street wear their painted art** (M6c-1…3). The Craft Quarter, Palace Square, Rooftops, Pigeon Loft, Tavern Attic, Mayor's Archive, Cistern and Cistern Stash are wired in `build_world_rooms.py` `PAINTED`, at the READMEs' positions. The street's shared planes (sky/mesas `Plan3`, the `City/gen_far` skyline) continue the market through `scroll_offset`. Every door in these rooms is a painted opening (`PAINTED` in `verify_room_entrances`). So are the market's two ladders and the gate buttress's rope. The palace's double door replaces the `palace_door` sheet. The Rooftops' `Wall_Loft` shows the boarded dovecote door, and the Cistern's `Wall_Stash` shows the cracked breach. The Cistern's cellar grate (`FlagGrate`) stands until `cistern_cellar_open` is set. |
| D895 | ROUTINE CALL (`wire-backdrops-3`, D773) | **The forge and the chapel stand in the Craft Quarter** (D773: «the craft quarter (forge and chapel fronts)»). The `gen_forge` front, the anvil, the Blacksmith and the `ForgeDoor` marker go to the Craft Quarter at x 813 / 979 / 979 / 1109. The `gen_chapel` front and the priestess of Samal (`OathPriest`) go to x 2235 / 2395. The priest of contracts and the dervish stay in the market. |
| D896 | ROUTINE CALL (`wire-backdrops-3`, City README conflict) | **Kesh's tent moves, not the attic ladder.** `DervishTent` 2076…2532 → 1000…1456 (the forge's freed place, between the Rooftops ladder house and the well). `OathDervish` 2330 → 1254 stands at the tent's opening as before. `TavernAtticDoor` stays at 2450, behind the painted stall as the graph says («the ladder behind the market stall»). The forge's walker doorway (x 1407, Porter1/Porter2) is dropped: the forge has left, and a doorway there would send townsfolk into Kesh's tent. The doorways at x 95 remain (two walkers still go in, verify_city_life [3]). |

## B rows fixed

| B | Fix |
|---|---|
| B207 (B-ct1) City pigeons sunk in the street | `Maps/City.tscn`: `Critters` now comes after `Terrain` in the tree, so the pigeons (y 384, the walk line) stand on the cobbles whole. `Pigeon2` moved 560 → 1060, off the meditation slab, which covered its lower half. Shot: `design/shots/wire_backdrops_3/city_pigeons.png`. |

## What changed

**Generator** `Scripts/Tools/build_world_rooms.py`
- The `PAINTED` entries for the eight rooms. `PAINTED_SIZE` for their art. `CITY_FAR` = the market's skyline plane (region rows 48…, `depth_blur_mid`, `shared`: placed on the market's `scroll_offset` without the view fix).
- `ROOMS`: the doors of the eight rooms now have art `None` and the README centres (`y` 300 / 322.5 / 330). Covers carry their painted art. The Craft Quarter gets `markers` (`ForgeDoor`) and `npcs` (Blacksmith, OathPriest). Both are new spec keys, built in `content()`.
- `EXISTING_DOORS`: the City's two ladders and the CityGates rope are `None` with y 322.5 (those scenes are hand-patched; see below).
- `painted()`: a front can be a scene (`palm.tscn`, the Palace Square's `OccluderPalm`). A plain ground's `Under` now uses its region (the City terrain strip). A sprite may take a `res://` path (the anvil).
- The run is idempotent, and the Laboratory rooms come out byte-identical (`git status` after the run shows only the eight City rooms).

**Hand-patched scenes** (not generated)
- `City.tscn`: removed `Forge`, `ForgeDoor`, `Chapel`, `Anvil`, `Blacksmith`, `OathPriest`, `RooftopsDoorEntrance` and `TavernAtticDoorEntrance`. Added `RooftopsLadder` (733.5, −24) and `AtticStall` (2136, −24) before `Terrain`. Doors at (880, 322.5) and (2450, 322.5). The tent and dervish moved (D896), and so did the pigeons (B207).
- `CityGates.tscn`: `RooftopsDoorEntrance` → `RooftopsRope` (547.5, 18) before `Terrain`. `RooftopsDoor` at (638, 322.5).

**Tests and captures** (they followed the NPCs and `ForgeDoor`)
- `verify_room_entrances` `PAINTED`: +15 doors. `verify_city_life`: starts at the market's `SavePoint`, and the blockers drop `ForgeDoor` and `Anvil` (≥ 6). `verify_oath`: the priestess is in the Craft Quarter, and the priest of contracts and the dervish in the market. A `_check_keeper` helper was added, and the sworn-talk check now runs in the right room. `verify_npc_activity` (station table, [5] smith at `ForgeDoor`), `verify_npc_arrival` [3b] (Craft Quarter, start x 719) and `verify_blacksmith` (the smith's scene is in the Craft Quarter) were updated too.
- Captures `capture_city_life` and `capture_living_world` (market → `SavePoint`); `capture_world_fixes`, `capture_ui_moments`, `capture_npc_flow`, `capture_ui_critic`, `capture_city_merchant` [3], `capture_npc_activity`, `capture_npcs_in_world`, `capture_art_fixes` (→ Craft Quarter). `measure_performance` (City → `SavePoint`).
- `capture_wire_backdrops.gd`: `SHOTS_3` (third argument `3`). The market has no `Arrival`, so its frames start at `RooftopsDoor`.

## Tests (each alone, Godot 4.6.2 headless)

verify_world_rooms, verify_room_entrances, verify_map_geometry, verify_city_life, verify_city_gates_raid, verify_mayor_hall,
verify_shop, verify_blacksmith, verify_oath, verify_ambient_critters, verify_scripts_compile, verify_npc_activity,
verify_npc_arrival: **all PASS** (after the fixes above; the first runs of city_life, blacksmith and npc_activity failed
only on the moved NPCs/blockers). verify_camera_transitions: PASS in the full suite (serial slot, 388 s).

## Shots

Contact sheet `design/shots/wire_backdrops_3.png` (24 frames). Full frames are in `design/shots/wire_backdrops_3/`:
- Market and gate: `city_pigeons`, `city_ladder`, `city_tent`, `city_stall`, `gates_rope`.
- Craft Quarter and Palace Square: `craft_1`, `craft_forge`, `craft_chapel`, `palace_fountain`, `palace_door`.
- Rooftops, Pigeon Loft, Tavern Attic and Archive: `roofs_rope`, `roofs_loft`, `roofs_ladder`, `loft`, `attic_hatch`, `attic_2`, `archive`.
- Cistern and Stash: `cistern_grate`, `cistern_open` (after `cistern_cellar_open`), `cistern_dragon`, `cistern_well`, `cistern_breach`, `stash_breach`, `stash_2`.

To recapture: `capture_wire_backdrops.gd -- design/shots/wire_backdrops_3 design/shots/wire_backdrops_3.png 3`.

Compared with the READMEs:
- The doors sit in their painted openings: the palace door between the guards, the dovecote's boards, the archive's bookcase, the cistern arch with and without its grate, the well and the breach.
- The street continues the market's skyline.
- Fronts are darkened as D750 says.
- The streets' floor `Under` (the City terrain's last row stretched to the room bottom) shows as faint vertical streaks under the HUD. This is the same mechanism as the Canyon rooms, not a new defect.

## Left

- **Atmosphere** from the READMEs: smoke from the kiln and forge, fountain spray, swaying banners and laundry, the light column down the cistern well, candle flicker. The archive's chest (floor 495…630 kept clear) is also not placed.
- `capture_skill_trees.gd` frames the priestess and the priest of contracts together in the market at x 1420/2000. They now stand in two rooms, so the capture needs a new layout. `capture_city_gates_passage.gd` waits for the smith's walk-out, which has been gone since B81, and was already stale. Neither is a test.
- `City/CisternDoor` (the hatch, x 2540) keeps its `door_elder` placeholder, as the City README says (not in M6c-3).
- The Rooftops' `Chimney1` front sits mid-screen when the camera is at the room's west end (the rope). The README expected it off-screen there. `verify_room_entrances` (B177 frame-edge check) passes, so I left it at the README position.
