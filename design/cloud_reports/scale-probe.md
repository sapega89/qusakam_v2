---
type: cloud-report
branch: cloud/scale-probe
date: 2026-10-27
tags: [cloud, art, rooms, scale]
---

# Cloud report: scale-probe (world scale, slice 1 of [[world_scale_plan]])

**Summary.** Slice 1 is done: the draft chart `design/world_scale.json`, the probe `SampleProject/UI/probe_world_scale.gd`, the chart tool `Scripts/Tools/scale_chart.py`, the chart picture `design/shots/scale_chart.png` and a capture of each of the 16 rooms with a 1 H ruler (`design/shots/scale/rooms/<room>_grid.jpg`).
**The headline:** **H = 64 art px (the hero's cell) does not fit the game as it is drawn.** The hero's drawn figure is 47 art px (70.5 world px). If you measure against the figure, the NPCs come out at 1.5× H (D172 holds, median ×1.02) and most doors fit. Measured against the 96 px cell, every one of the 35 NPCs and human enemies is "too small". The real offenders under either unit:
- the **human enemies are as tall as the hero** (73.5 px, D172/D598 want ×1.5);
- **painted barrels and sacks are about 1 H** (BanditCamp, GatehouseCellar, ElderHouse: ×2–2.5);
- **the props strip, the scrub and the gates are 1.7–3.9× their row**;
- **the palms are far too small for a 4 H tree**.

Nothing is fixed yet: slice 2 is Sapega's call on the chart. No D-ID (nothing has been decided). B rows fixed: none. Proposed B rows are below. `verify_scripts_compile`: `RESULT: ALL PASS`. I did not run the full suite because no game code or scene changed.

## What was built
| File | What |
|---|---|
| `design/world_scale.json` | The plan's table, one row per category, in matching order. Each row has `h`, `art_px` (world = ×1.5), `keywords` and notes. The tolerance is ±1 art px (the plan: «не має близько, все має бути чітко»), and on a Parallax2D plane the target is × `scroll_scale.x`. Rows with no target: `marker`, `monster` (D560/D766), `sky`, `companion`, `structure` and `hanging`. I added them so that pickup sparkles, platform art, ropes and roots do not show up as "unknown" or as false offenders. The unit block records both numbers: the cell is 96 world px and the figure is 70.5. |
| `SampleProject/UI/probe_world_scale.gd` | Boots `Game.tscn` the way `film_rooms.gd` does (enemies frozen, zones muted, UI hidden) and teleports to each room. For every visible Sprite2D/AnimatedSprite2D outside the hero, it takes the opaque bbox of the current frame (`Image.get_used_rect` on the frame region) through the global transform. Parts are grouped to the nearest instanced scene or body, never across a Parallax2D. Each object also gets the plane factor, a category (keywords tried on the name's head word, then the full name, the scene file, the texture files, the full paths; room folders are ignored), the target and a verdict. Each enemy kind gets one instance created at its spawn point, measured and freed. Objects ≥ 768 world px wide count as backdrop planes and are only listed. Under xvfb it also saves one capture per room. Output: `design/shots/scale/probe.json` (+ `rooms/*.png`, not committed). |
| `Scripts/Tools/scale_chart.py` | Writes the chart (2400 px wide, 1 px = 1 world px): a 1 H grid, a green line at the hero's figure, and for each category every distinct sprite at its in-game size next to a dashed outline of the target. Offenders are boxed red, with the ratio and the rooms. It also writes the room rulers and `design/shots/scale/tables.md` (all tables, including the per-object list of 78 rows). Run it with `/usr/bin/python3`: the `/usr/local` Python on the cloud box has a broken Pillow. |

Run: `xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/probe_world_scale.gd` (about 10 min for 16 rooms, 0 SCRIPT ERROR; `--headless` works too, without captures). Then `/usr/bin/python3 Scripts/Tools/scale_chart.py`.

## Per-room table (worst first)
Judged = objects with a chart target; off = outside ±1 art px. The worst object is the largest |log ratio|.

| Room | objects | judged | off | too big | worst | worst ratio |
|---|---|---|---|---|---|---|
| ElderHouse | 10 | 4 | 4 | 1 | `Attic/Hatch_Attic` (door_locked, a floor hatch: misfiled) | ×0.22 |
| BanditCamp | 13 | 10 | 10 | 4 | `Back/Props/Sprite` (sacks strip, plane 0.9) | ×3.86 |
| DesertRoad | 42 | 20 | 20 | 4 | `Decor/Palm1..3` (tree) | ×0.27 |
| Village | 14 | 8 | 8 | 2 | `Decor/Palm1..3` (tree) | ×0.27 |
| LaboratoryOutside | 7 | 3 | 3 | 0 | `Decor/Palm1..2` (tree) | ×0.27 |
| Canyon | 49 | 6 | 6 | 0 | `Bridge/Post1` (bridge post filed as lamp post: misfiled) | ×0.36 |
| City | 33 | 21 | 21 | 4 | `FrontDark/OccluderPalm1` (tree, plane 1.3) | ×0.42 |
| CityGates | 15 | 8 | 8 | 2 | `FrontDark/OccluderPalm1` (tree, plane 1.3) | ×0.42 |
| LabCells | 22 | 3 | 3 | 1 | `Table/Sprite` (table) | ×2.25 |
| LizardCave | 18 | 11 | 11 | 11 | `FrontDark/Scrub1..4` (bush, plane 1.3) | ×1.97 |
| MesaClimb | 29 | 5 | 5 | 4 | `FrontDark/Scrub1..3` (bush, plane 1.3) | ×1.97 |
| DragonMural | 8 | 4 | 4 | 3 | `FrontDark/Scrub1..2` (bush, plane 1.3) | ×1.97 |
| Laboratory | 48 | 7 | 7 | 1 | `Fight_Middle/EnemySpawnPoint1` (bandit) | ×0.51 |
| LabBoss | 14 | 2 | 2 | 1 | `CorridorDoorEntrance` (lab door) | ×0.79 |
| GatehouseCellar | 7 | 1 | 1 | 1 | `Chest_Cellar` (chest) | ×1.21 |
| MayorHall | 10 | 1 | 1 | 0 | `CityDoorEntrance` (door) | ×0.93 |

No object anywhere is "ok" within ±1 art px. The tolerance is that strict, and the unit question below moves every human-sized row.

By category (median ratio, against the cell H and against the figure H = 70.5 px):

| Category | target px | n | too big | too small | median vs cell-H | median vs figure-H |
|---|---|---|---|---|---|---|
| npc_adult (incl. human enemies) | 144 | 35 | 0 | 35 | ×0.75 | **×1.02** |
| door | 168 | 18 | 2 | 16 | ×0.89 | ×1.21 |
| door_locked | 192 | 8 | 6 | 2 | ×1.37 | ×1.87 |
| gate_big | 240 | 3 | 3 | 0 | ×1.73 | ×2.36 |
| tent | 240 | 3 | 1 | 2 | ×0.50 | ×0.68 |
| house_storey | 216 | 6 | 6 | 0 | ×1.35 | ×1.84 |
| tree (palm) | 384 | 17 | 0 | 17 | ×0.42 | ×0.57 |
| chest | 36 | 9 | 9 | 0 | ×1.21 | ×1.65 |
| bush (fg scrub) | 36 | 9 | 9 | 0 | ×1.97 | ×2.68 |
| table/bench, crate, sack/pot | 48 / 48 / 36 | 1–2 each | — | — | ×2.25 / ×1.31 / ×3.86 | — |

Not judged (no chart value): 16 monsters (29–160 px), 8 companions (76–88 px, i.e. 1.1–1.25× the hero's figure), 34 hanging lamps and banners (lab lamps 30 px, wall banners 43.5 px, the MayorHall chandelier 144 px), 123 structure pieces, 16 markers, and 10 MesaClimb `Ledges/*/Art` pieces (structure; their head word "Art" matched nothing).

## Top 15 offenders, with a proposed fix
Ratios are against the draft (cell-H) chart unless the line says otherwise. "×0.5/×0.75" means changing the node's scale. The `gen_*` backdrop pieces are downsampled AI art and survive any scale. The sprite sheets (`palm_sheet`, `fg_scrub_sheet`, `Chest/Closed`, enemy sheets) are pixel art at an integer art grid: they survive ×2 or ×0.5 of the art scale, and any other factor means regenerating them.

| # | Object (rooms) | drawn → target | Fix |
|---|---|---|---|
| 1 | `Back/Props/Sprite` `BanditCamp/gen_sacks.png` (BanditCamp, plane 0.9). A strip of sacks and barrels, 127.5 px tall | ×3.86 vs sack 33 px | **Regenerate.** ×0.5 still leaves ×1.9. Generate the barrels at 32 art × 0.9 and the sacks at 24 art × 0.9 as separate props. |
| 2 | Human enemies `bandit`, `bandit_archer` and the shield kind (BanditCamp, CityGates, DesertRoad, Laboratory; 10 spawn points). 73.5 px = the hero's own figure | ×0.51 (×0.70 vs figure-H) | **Enemy sprite ×2 → 147 px** (integer, the grid survives) if the cell-H stays. If H = the figure, the target is 106 px and needs a **regeneration at 70 art**. Either way it breaks D172/D598 today (proposed B row). |
| 3 | Palms `Decor/Palm*` `palm_sheet.png` ×1.5 (DesertRoad, Village, LaboratoryOutside; 8) | 105 → 384 (×0.27) | **Chart change first** (4 H = 384 px is taller than any building in the game). Then ×2 → 210 px = 2.2 H. |
| 4 | Foreground palms `FrontDark/OccluderPalm*` ×3, plane 1.3 (City, CityGates, Canyon, DesertRoad, Village, LaboratoryOutside; 9) | 210 → 499.5 (×0.42) | Same chart change. As a near-plane occluder it already reads as bigger than the gameplay palms. Keep it. |
| 5 | `FrontDark/Scrub*` `fg_scrub_sheet.png` ×1.5, plane 1.3 (DragonMural, LizardCave, MesaClimb; 9) | 91.5 → 46.5 (×1.97) | **×0.5** (scale 0.75; the art grid survives at 2:1) → 45.75 px = ok. |
| 6 | `Gate_Stockade` and `Gate_Shrine`, `gen_gate.png` (BanditCamp, LizardCave). Locked gates inside a room, 415.5 px = 5.9 hero figures | ×1.73 vs big gate 240 (×2.16 vs locked door 192) | **×0.5 → 208 px** (≈ locked door 192, ×1.08). These are the plan's "gates are 416 px" example. |
| 7 | `LabCells/Table/Sprite` `Lab/gen_table.png` (a workbench with apparatus) | 108 → 48 (×2.25) | **×0.5 → 54 px.** The apparatus on top makes 1.1× of a 32-art table fine. |
| 8 | `GatePassage` `Gates/gen_passage_back.png` (CityGates, the city gate; filed as `door` by "passage") | 313 → 240 as a big gate (×1.30) | **×0.75 → 235 px** (×0.98). Change the keyword: "GatePassage" should hit `gate_big`. |
| 9 | `DesertRoad/Shrine` `Road/gen_shrine.png` (an obelisk shrine) | 280.5 → 192 (×1.46) | **×0.75 → 210 px** (×1.10), or regenerate at 128 art. |
| 10 | Buildings `Forge`, `WitchHut`, `Chapel` (City), `ElderHouse`, `GrandpaHouse` (Village) | 271–309 → 216 per storey (×1.26–1.43) | WitchHut is one storey: **×0.75 → 228**. Forge, Chapel and the houses read as 1.5 storeys: **×0.75**, or count them as two storeys (432) and leave them. That is a chart call. |
| 11 | LizardCave `Back/Shrines/ShrineA*`, `ShrineB*` (plane 0.9; 5) | 220–235 → 172.5 (×1.28–1.37) | **×0.75 → 165–177** = ok-ish. |
| 12 | DesertRoad camp tents `BanditCampTent`, `CampShortcutTent` (`gen_dervish_tent` ×0.6) | 120.6 → 240 (×0.50) | **×2 (scale 1.2) → 241 px** = ok. |
| 13 | Elite humans: `bandit_brute` 86, `tower_shield_guard` 81, `heavy_archer` 102 px | ×0.56–0.71 | Same call as #2. D766 elites are ×1.25 of their base: 1.25 × 147 = 184 with the cell-H, 132 with the figure-H. **Regenerate** whichever is chosen. |
| 14 | Chests `Props/Chest/Closed/1.png` ×1.5 (all 9 chests) | 43.5 → 36 (×1.21) | **Chart change** to chest 28 art (42 px). The art is 29 art px, and ×0.75 would break its grid. |
| 15 | BanditCamp `FrontDark/Crate1` `fg_camp/crate.png`, plane 1.3 | 82.5 → 63 (×1.31) | **×0.75 → 62 px** = ok. |

Not offenders, but filed under the wrong row: `ElderHouse/Attic/Hatch_Attic` (a floor hatch: a `LockedDoor.tscn` lying flat, 42 px tall), `Canyon/Bridge/Post*` ("post" = lamp post; these are bridge posts), `Canyon/Meditation/Shrine` (a flat meditation stone). The keyword lists should get a `hatch` row (no target), drop `post` from `lamp_pole`, and route `GatePassage` to `gate_big`. Doors: `lab_door` 132, `palisade_gate` 130.5, `door_elder` 114, `CityDoor` 156. They are ×0.68–0.93 of the 1.75 H door against the cell, and ×0.92–1.26 against the figure. With the figure-H they need nothing.

## Objects painted into backdrop planes (by eye, one capture per room)
These are estimated against the 1 H ruler and the hero in the same capture (`design/shots/scale/rooms/<room>_grid.jpg`; white lines every 1 H = 96 px from his feet, green = his figure). The target is × the plane factor.

| Room | Plane (factor) | Painted object | ≈ height | Target | ≈ ratio |
|---|---|---|---|---|---|
| BanditCamp | `Back/Mid/Sprite` (0.8) | barrels | 1.0 H (96 px) | barrel 0.5 H × 0.8 = 38 | **×2.5** |
| BanditCamp | `Back/Mid/Sprite` (0.8) | sacks | 0.8 H | sack 0.375 H × 0.8 = 29 | **×2.7** |
| BanditCamp | `Back/Mid/Sprite` (0.8) | stacked crates (each) | 0.55 H | crate 38 | ×1.4 |
| BanditCamp | `Back/Mid/Sprite` (0.8) | the big striped tent | 2.6 H | tent 2.5 H × 0.8 = 192 | ×1.3 |
| GatehouseCellar | `Back/Sprite1`/`Sprite2` (1.0) | barrels | 1.05 H | barrel 48 | **×2.1** |
| GatehouseCellar | `Back/Sprite1`/`Sprite2` (1.0) | crates (each) | 0.6 H | crate 48 | ×1.2 |
| ElderHouse | `Wall` (1.0) | floor amphorae | 0.95 H | pot 36 | **×2.5** |
| ElderHouse | `Wall` (1.0) | shelf pots | 0.35 H | pot 36 | ×0.9 (ok) |
| City | `CityNear/Sprite` (0.85) | shop doors | 0.6 H | door 1.75 H × 0.85 = 143 | **×0.4** |
| City | `CityNear/Sprite` (0.85) | one storey of the bazaar houses | 1.1 H | 2.25 H × 0.85 = 184 | ×0.6 |
| Village | `Houses/Sprite` (0.85) | house doors | 0.55 H | door 143 | **×0.37** |
| LabBoss, Laboratory | `Atmosphere/Far*` (0.4), `Mid*` (0.75) | round-top doors, big flasks | 0.9 H, 1 H | door 1.75 H × 0.75 = 126 | ×0.7 |
| LizardCave | `Back/Wall/Sprite` (0.8) | lizard statues in shrines, bowls | 1 H, 0.25 H | — | statues read fine |
| MayorHall | `Wall` (1.0) | arches | 2.6 H | — | fine |
| Canyon, CityGates, DesertRoad, DragonMural, LaboratoryOutside, MesaClimb | far planes | rock arches, walls, ruins, far palms | — | — | no obvious props at the hero's plane |

So the player's «everything is so big» is the **painted barrels, sacks and amphorae at about 1 H**, plus the 416 px gates and the props strip. The painted *doors* of City and Village are the opposite: about 0.4× too small.

## Chart values the measurements suggest changing (for slice 2, Sapega)
1. **The unit.** Either H = the drawn figure (47 art = 70.5 world px), or keep H = 64 art and multiply every human-sized row by 0.73. Against the figure, the NPCs (median ×1.02 of 1.5 H) and most doors already fit. Against the cell, all 35 humans are "too small" and "fixing" them would make the NPCs 2× the hero, not 1.5×. **Recommendation: H = the figure (70.5 px).** The probe takes this from `unit` in the json.
2. **Palm/tree 4 H → about 2.25–2.5 H.** No building in the game is 4 H. The palm sheet at ×2 gives 210 px.
3. **Chest 24 → 28 art**, to match the existing chest art (29 art).
4. **New rows**, measured today: a hanging lamp is 30 px (20 art), a wall banner 43.5 px (29 art), a companion 76–88 px (1.1–1.25× the hero's figure; D598 says the hero is the smallest), a hatch.
5. **Tolerance.** ±1 art px makes every object an offender. As a working band until the art is regenerated, ±10% would separate "slightly off" from the ×2 cases.

## Proposed B rows (not written to BUGS.md; the orchestrator numbers them)
| B | Where | Defect |
|---|---|---|
| B-new-1 | `enemy_bandit*`, `enemy_shield`, `default_enemy` sheets | Human enemies are drawn at the hero's own height (73.5 px vs his 70.5 px figure). D172/D598 want human adults ×1.5 the hero. Elites (brute 86, tower guard 81, heavy archer 102) are under that too. |
| B-new-2 | BanditCamp `Back/Mid` plane, `Back/Props/Sprite` (`gen_sacks.png`); GatehouseCellar `Back/Sprite1/2`; ElderHouse `Wall` | Painted and strip barrels, sacks and amphorae are about 1 H tall (×2–3.9 of the chart). This is the «everything is so big» the player asked about. |
| B-new-3 | `Gate_Stockade` (BanditCamp), `Gate_Shrine` (LizardCave): `gen_gate.png` | Locked gates are 416 px = 5.9 hero figures (×1.73 of a big city gate, ×2.16 of a locked door). |
| B-new-4 | `fg_scrub_sheet` on FrontDark (DragonMural, LizardCave, MesaClimb) | Foreground scrub is 91.5 px, ×1.97 of a bush even on the 1.3 plane. |
| B-new-5 | City `CityNear`, Village `Houses` backdrop planes | Painted house doors are about 0.4× the chart door (0.55–0.6 H). |

## Checks
- Probe run: 16 rooms, `SCALE done`, 0 SCRIPT ERROR. The "Can't find overlapping bodies when monitoring is off" lines come from the muted zones, the same as in `film_rooms`.
- `verify_scripts_compile`: `RESULT: ALL PASS`.
- Chart: `design/shots/scale_chart.png` (2400×8870). Room rulers: `design/shots/scale/rooms/*_grid.jpg` (16). Tables: `design/shots/scale/tables.md`. Raw data: `design/shots/scale/probe.json`.
- No game scene or game code was changed.
