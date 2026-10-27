---
type: cloud-report
branch: cloud/scale-exact
date: 2026-10-27
tags: [cloud, art, rooms, scale]
---

# Cloud report: scale-exact (R4, first half; [[world_scale_plan]])

**Summary.**
- **Done:** `design/world_scale.json` now holds the plan's exact table. That is H = 64 art px (Sapega's call), one art-px height and a `world_px` (×1.5) per category, `plane_rule`, and a tolerance of ±1 art px. All 19 rows were checked against the plan. The chart `design/shots/scale_chart.png` and `design/shots/scale/tables.md` were redrawn against those exact targets. **111 objects are judged and 0 are within ±1 art px.** That is 52 distinct sprites. Only one can be fixed by rescaling (the foreground scrub, ×0.5). The other 51 need regenerating at the exact height.
- **Not done: Godot could not run.** The cloud's auto-mode classifier blocked running the downloaded Godot binary ("Code from External"). So `probe_world_scale.gd` was **not** re-run, and **`verify_scripts_compile` was not run** (this branch changes no `.gd`). Instead, the new `Scripts/Tools/scale_exact.py` started from scale-probe's Godot-measured `probe.json`. It statically re-measured the 5 rooms whose scenes changed since then (DragonMural, ElderHouse, GatehouseCellar, MayorHall, MesaClimb), then re-filed and re-judged all 16 rooms. Its static numbers match Godot exactly on every unchanged sprite I compared (height, width, plane; 23 sprites). The Lizard Cave and Bandit Camp planes, the gates and the foreground pieces had not changed since scale-probe, so their Godot numbers stand.
- **No D-ID.** Sapega's two quotes are already in the plan, and the category values stay a draft until he answers the chart. **B rows fixed:** none. Six proposed B rows are listed below. **Full suite:** not run (no Godot; no game code or scene changed).

## What changed
| File | What |
|---|---|
| `design/world_scale.json` | `_note` now records Sapega 2026-10-27: H = 64 art px is exact and no sizes are approximate. Every category has `world_px` = `art_px` × 1.5. The new `plane_rule` is `round(art_px × scroll_scale.x)` art px, then ×1.5. Keyword fixes from the scale-probe report: `post` dropped from `lamp_pole` (the Canyon bridge posts are now `structure`); `passage` dropped from `door` (`GatePassage` is now `gate_big`); `hatch`, `stair` and `art` added to `structure` (the ElderHouse hatch, the new cellar stairs, the MesaClimb `Ledges/*/Art`). The plan's table values are unchanged. |
| `Scripts/Tools/scale_exact.py` (new) | Re-files and re-judges `probe.json` against the json. It ports `_haystacks`/`_category` from `probe_world_scale.gd` 1:1: re-run on the old json, it gave 0 category, verdict or target differences over 339 objects. It statically measures new plain `Sprite2D`s in the rooms named on the command line, and drops objects that are gone from the scene. Each offender gets an exact `target_art` and a `fix`: ×0.5, ×0.75 or ×2, but only when the result lands within ±1 art px **and** one texel stays a whole number of art px. Otherwise the fix is `regenerate at N art px`. Run: `/usr/bin/python3 Scripts/Tools/scale_exact.py DragonMural ElderHouse GatehouseCellar MayorHall MesaClimb`, then `/usr/bin/python3 Scripts/Tools/scale_chart.py`. |
| `Scripts/Tools/scale_chart.py` | The title now says "exact" with H = 64 art px. The "vs figure-H" columns are gone (Sapega settled the unit). The offender table has `target art px` and `fix` columns. |
| `design/shots/scale/probe.json`, `tables.md`, `design/shots/scale_chart.png` (2400×8966) | Regenerated. The room rulers `design/shots/scale/rooms/*_grid.jpg` were **not** redrawn: they need fresh Godot captures, so the 5 changed rooms' rulers still show the old planes. |

When Godot can run, the exact re-run is: `xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/probe_world_scale.gd`, then `scale_exact.py` with no rooms named, then `scale_chart.py`.

## Per-room table (worst first)
Judged = objects with a chart value. Off = outside ±1 art px. Every judged object is off.

| Room | objects | judged | off | too big | worst | worst ratio |
|---|---|---|---|---|---|---|
| BanditCamp | 13 | 10 | 10 | 4 | `Back/Props/Sprite` (`gen_sacks`, sack_pot, plane 0.9) | ×3.86 |
| DesertRoad | 42 | 20 | 20 | 4 | `Decor/Palm1..3` (tree) | ×0.27 |
| Village | 14 | 8 | 8 | 2 | `Decor/Palm1..3` (tree) | ×0.27 |
| LaboratoryOutside | 7 | 3 | 3 | 0 | `Decor/Palm1..2` (tree) | ×0.27 |
| Canyon | 49 | 4 | 4 | 0 | `Meditation/Shrine` (door_locked: misfiled, a flat stone) | ×0.39 |
| City | 33 | 21 | 21 | 4 | `FrontDark/OccluderPalm1` (tree, plane 1.3) | ×0.42 |
| CityGates | 15 | 8 | 8 | 2 | `FrontDark/OccluderPalm1` (tree, plane 1.3) | ×0.42 |
| LabCells | 22 | 3 | 3 | 1 | `Table/Sprite` (table_bench) | ×2.25 |
| LizardCave | 18 | 11 | 11 | 11 | `FrontDark/Scrub1..4` (bush, plane 1.3) | ×1.97 |
| MesaClimb | 30 | 5 | 5 | 4 | `FrontDark/Scrub1..3` (bush, plane 1.3) | ×1.97 |
| DragonMural | 9 | 4 | 4 | 3 | `FrontDark/Scrub1..2` (bush, plane 1.3) | ×1.97 |
| Laboratory | 48 | 7 | 7 | 1 | `Fight_Middle/EnemySpawnPoint1` (bandit) | ×0.51 |
| ElderHouse | 10 | 3 | 3 | 1 | `ExitDoorEntrance` (`door_elder`) | ×0.68 |
| LabBoss | 14 | 2 | 2 | 1 | `CorridorDoorEntrance` (`lab_door`) | ×0.79 |
| GatehouseCellar | 11 | 1 | 1 | 1 | `Chest_Cellar` (chest) | ×1.21 |
| MayorHall | 10 | 1 | 1 | 0 | `CityDoorEntrance` (`palace_door`) | ×0.93 |

By category: npc_adult 35/35 too small (median ×0.75); door 16 too small and 1 too big (×0.79); door_locked 6 big and 1 small (×1.37); gate_big 4 big (×1.73); house_storey 6 big (×1.35); tree 17 small (×0.42); chest 9 big (×1.21); bush 9 big (×1.97); tent 1 big and 2 small; table/bench, crate and sack 1–2 each.

**New sprites in the changed rooms** (static, no chart value): GatehouseCellar `Back/Props/Stairs` 192 px (structure), `Back/Props/Lantern` 172.5 px including its chain (hanging; README: body 24 art), `FrontDark/Pillar1/2` 520 px (structure, plane 1.3). MesaClimb `FrontDark/OccluderRock1` 250.8 px (structure, plane 1.3). DragonMural `Back/Dragon` 202.5 px is **unknown**: a painted mural dragon, and no keyword fits. New backdrop planes, listed only: DragonMural `Back/Wall`, `Back/Frame` (864×402), `Back/Floor`; GatehouseCellar `Back/Far`, `Back/Mid`, `Back/Floor`; MesaClimb `Back/Mesa`, `Back/Boulders` (1707×196), `Back/Floor`; ElderHouse and MayorHall `Floor`.

## Top 20 offenders: exact target and fix
Each row is one distinct sprite (texture, scale and plane). Target = round(art px × plane) art px, ×1.5 for world px. The **fix rule**: ×0.5 / ×0.75 / ×2 only when the result lands within ±1 art px *and* a texel stays a whole number of art px. Everything here is drawn at 1 texel = 1 art px (scale 1.5), except where noted.

| # | Object (rooms, count) | drawn → exact target | ratio | Fix |
|---|---|---|---|---|
| 1 | `Back/Props/Sprite` `BanditCamp/gen_sacks.png`, a strip of sacks and barrels (BanditCamp, plane 0.9) | 127.5 → sack **22 art = 33 px** (barrel 29 art = 43.5 px) | ×3.86 | **Regenerate**: separate props, the sacks at 22 art and the barrels at 29 art (plane 0.9). |
| 2 | `Decor/Palm*` `palm_sheet` (DesertRoad, Village, LaboratoryOutside; 8) | 105 → **256 art = 384 px** | ×0.27 | **Regenerate at 256 art.** ×2 would only reach 210. The 4 H palm row is the plan's draft (the scale-probe report asked Sapega to lower it). |
| 3 | `FrontDark/OccluderPalm*` `palm_sheet` ×3 (6 rooms, 9; plane 1.3) | 210 → **333 art = 499.5 px** | ×0.42 | **Regenerate at 333 art**, or the same palm at 256 art drawn ×1.3 on the plane. Same chart call as #2. |
| 4 | `LabCells/Table/Sprite` `Lab/gen_table.png` | 108 → **32 art = 48 px** | ×2.25 | **Regenerate at 32 art.** ×0.5 gives 54 px, 4 art px over. |
| 5 | `BanditCampTent`, `CampShortcutTent` `gen_dervish_tent` ×0.6 (DesertRoad) | 120.6 → **160 art = 240 px** | ×0.50 | **Regenerate at 160 art.** ×2 (scale 1.2) gives 241.2 px, inside the tolerance, but 1 texel = 0.8 art px. It is already off the grid today. |
| 6 | `FrontDark/Scrub*` `fg_scrub_sheet` (DragonMural, LizardCave, MesaClimb; 9; plane 1.3) | 91.5 → **31 art = 46.5 px** | ×1.97 | **×0.5**: a 2:1 downsample of the sheet keeps 1 texel = 1 art px, giving 30.5 art = 45.75 px (ok). The only rescale fix. |
| 7 | Human enemies `bandit`, `bandit_archer` (BanditCamp, CityGates, DesertRoad, Laboratory, Village; 10) | 73.5 → **96 art = 144 px** | ×0.51 | **Regenerate at 96 art.** ×2 gives 147 px, 2 art px over. |
| 8 | `BigSlot_TowerShieldGuard` `shield_tower` scale 1.0 (Laboratory) | 81 → **96 art = 144 px** | ×0.56 | **Regenerate at 96 art.** The chart has no elite row: D766 ×1.25 would make it 120 art, which needs Sapega. |
| 9 | `Gate_Stockade` `BanditCamp/gen_gate.png` | 415.5 → big gate **160 art = 240 px** (as a locked door in a room: 128 art = 192 px) | ×1.73 (×2.16) | **Regenerate at 128 art** (the plan's "shrine gate in a room" row). ×0.5 gives 207.75 px, 10.5 art over. |
| 10 | `Gate_Shrine` `LizardCave/gen_gate.png` | same as #9 | ×1.73 (×2.16) | Same as #9. |
| 11 | `BigSlot_BanditBrute` `bandit_brute` scale 1.0 (BanditCamp, DesertRoad, Laboratory; 3) | 86 → **96 art = 144 px** | ×0.60 | **Regenerate at 96 art** (elite size: same call as #8). |
| 12 | `ElderHouse/ExitDoorEntrance` `door_elder` | 114 → **112 art = 168 px** | ×0.68 | **Regenerate at 112 art.** |
| 13 | `DesertRoad/Shrine` `Road/gen_shrine.png` (obelisk) | 280.5 → **128 art = 192 px** | ×1.46 | **Regenerate at 128 art.** ×0.75 gives 210, 12 art over. |
| 14 | `City/Forge` `gen_forge.png` | 309 → **144 art = 216 px** per storey | ×1.43 | **Regenerate at 144 art** (one storey), or at 288 art if Sapega counts it as two storeys. |
| 15 | `City/WitchHut` `gen_witch_hut.png` | 304.5 → **144 art = 216 px** | ×1.41 | **Regenerate at 144 art.** |
| 16 | `BigSlot_HeavyArcher` `archer_heavy` scale 1.2 (BanditCamp) | 102 → **96 art = 144 px** | ×0.71 | **Regenerate at 96 art** (elite call). |
| 17 | `Back/Shrines/ShrineB*` `gen_shrine_b` (LizardCave; 3; plane 0.9) | 235.5 → **115 art = 172.5 px** | ×1.37 | **Regenerate at 115 art.** ×0.75 gives 176.6, 2.7 art over. |
| 18 | `LabCells/Prisoner` `prisoner` | 105 → **96 art = 144 px** | ×0.73 | **Regenerate at 96 art.** |
| 19 | `City/Chapel` `gen_chapel.png` | 291 → **144 art = 216 px** | ×1.35 | **Regenerate at 144 art** (or 288 for two storeys). |
| 20 | `Crowd/OldMan1/2` `townsfolk_old_man` (City) | 108 → **96 art = 144 px** | ×0.75 | **Regenerate at 96 art.** |

Not in the top 20 but in the same pattern (full list in `design/shots/scale/tables.md`):
- **All 35 adult NPCs** are 105–130.5 px against 144 (×0.73–0.91), so every NPC sheet needs regenerating at 96 art.
- **All door sheets** are off: `palisade_gate` 130.5, `lab_door` 132, `cave_mouth` 150, `palace_door` 156, `mesa_cleft` 165, `CellarArch` 170, against 168. `mesa_cleft` and `CellarArch` are only 2 and 1.3 art px off: re-cutting a few rows would do, rather than a full regeneration.
- **Chests**: 29 art against 24, all 9.
- **Houses**: `ElderHouse` 286.5, `GrandpaHouse` 271.5, `Shop` 259.5, `DervishTent` 301.5, `LabBoss Gates` 265.5. `GatePassage` (now a big gate) is 313 against 240.
- **Other props**: `FrontDark/Crate1` 82.5 against 42 art = 63 px; `Anvil` 45 against 48.

**Misfiled, not offenders:** `Canyon/Meditation/Shrine`, a flat meditation stone, is filed as `door_locked` because the head word "Shrine" wins. A keyword cannot route it while the head word wins. The probe needs a name exception, or the node should be renamed in the art pass.

## Objects painted into backdrop planes (by eye, exact targets)
The probe cannot separate objects inside a full plane. New this run: the GatehouseCellar `Back/Mid` plane (`gen_mid.png`, ×0.8), measured on the texture's own 8-art-px grid, ±2 art px. The other rows are scale-probe's by-eye estimates, re-judged against exact targets.

| Room | Plane (factor) | Painted object | ≈ drawn | Exact target | ≈ ratio |
|---|---|---|---|---|---|
| GatehouseCellar | `Back/Mid` (0.8) **new** | barrels | 84–87 art = 128 px (1.3 H) | barrel 26 art = 39 px | **×3.3** |
| GatehouseCellar | `Back/Mid` (0.8) **new** | crates (each in a stack) | 40–48 art | crate 26 art = 39 px | **×1.6–1.8** |
| GatehouseCellar | `Back/Mid` (0.8) **new** | wine bottles on the crates | 38 art | pot 19 art = 28.5 px | ×2.0 |
| BanditCamp | `Back/Mid` (0.8) | barrels | 1.0 H = 96 px | 26 art = 39 px | **×2.5** |
| BanditCamp | `Back/Mid` (0.8) | sacks | 0.8 H | 19 art = 28.5 px | **×2.7** |
| BanditCamp | `Back/Mid` (0.8) | crates | 0.55 H | 26 art = 39 px | ×1.35 |
| BanditCamp | `Back/Mid` (0.8) | the striped tent | 2.6 H | 128 art = 192 px | ×1.3 |
| ElderHouse | `Wall` (1.0) | floor amphorae | 0.95 H | 24 art = 36 px | **×2.5** |
| City | `CityNear` (0.85) | shop doors | 0.6 H | 95 art = 142.5 px | **×0.40** |
| City | `CityNear` (0.85) | one bazaar storey | 1.1 H | 122 art = 183 px | ×0.58 |
| Village | `Houses` (0.85) | house doors | 0.55 H | 95 art = 142.5 px | **×0.37** |
| Laboratory, LabBoss | `Mid*` (0.75) | round-top doors | 0.9 H | 84 art = 126 px | ×0.68 |

The new cellar plane made its barrels **bigger** than the old one did (1.3 H against the old 1.05 H): the cellar is now the worst painted-barrel room. The new DragonMural (wall, frame, dragon), MesaClimb (mesa, boulders) and floor planes hold no charted props.

## Proposed B rows (not written to BUGS.md; the orchestrator numbers them)
| B | Where | Defect |
|---|---|---|
| B-new-1 | `enemy_bandit*`, `bandit_archer`, `shield_tower`, `bandit_brute`, `archer_heavy` sheets | Human enemies are 73.5–102 px. The exact chart wants 96 art = 144 px (D172 ×1.5), and the elites have no exact row yet. Fix: regenerate at 96 art. |
| B-new-2 | All 35 adult NPC sheets (City crowd, guards, merchant, scribe, priests, dervish, old man, prisoner) | 105–130.5 px against the exact 144 px (96 art). Fix: regenerate at 96 art. |
| B-new-3 | BanditCamp `Back/Mid` + `Back/Props/Sprite` (`gen_sacks`); **GatehouseCellar `Back/Mid` (`Cellar/gen_mid.png`, new)**; ElderHouse `Wall` | Painted barrels, sacks and amphorae are 1–1.3 H, ×2.5–3.9 of the chart (barrel 26 art on a 0.8 plane). This is the player's «everything is so big». Fix: repaint the planes without props and add props at the exact size. |
| B-new-4 | `Gate_Stockade` (BanditCamp), `Gate_Shrine` (LizardCave): `gen_gate.png` | 415.5 px against a locked gate in a room, 128 art = 192 px (×2.16). Fix: regenerate at 128 art. |
| B-new-5 | `fg_scrub_sheet` on FrontDark (DragonMural, LizardCave, MesaClimb) | 91.5 px against 31 art = 46.5 px on the 1.3 plane. Fix: a 2:1 downsample of the sheet gives 45.75 px (exact within ±1 art). |
| B-new-6 | City `CityNear`, Village `Houses` planes; every door sheet (`palisade_gate`, `lab_door`, `cave_mouth`, `palace_door`, `door_elder`) | Painted doors are about 0.4× the exact door (95 art on a 0.85 plane). The door sheets are 114–156 px against 168 (112 art). Fix: regenerate at 112 art. `mesa_cleft` needs only a 2-row re-cut. |

## Open for Sapega (not blocking, carried from scale-probe)
The exact values are the plan's draft. Four rows decide most of the regeneration list:
- the palm: 4 H = 384 px is taller than any building;
- the elite humans: D766 ×1.25 → 120 art?;
- the companions: no row; they are 76–88 px;
- whether the Forge, Chapel and houses are one storey or two.

## Checks
- `scale_exact.py`: the port matches `probe_world_scale.gd`, with 0 differences in category, verdict or target over 339 objects on the old json. The static measures equal Godot's on the 23 unchanged sprites I compared (height, width, plane).
- `scale_chart.py`: `chart -> design/shots/scale_chart.png (2400x8966)`, `tables -> design/shots/scale/tables.md`.
- **Not run:** `probe_world_scale.gd`, `verify_scripts_compile`, the full suite. The auto-mode classifier denied running the Godot 4.6.2 binary ("Code from External") after the download and unzip succeeded. No `.gd` or `.tscn` changed on this branch.
