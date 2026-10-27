---
type: report
tags: [cloud, routines, art, rooms, critics, M6]
---

# depth-critics — slice 2 of [[depth_critics_plan]] (three critics)

**Summary.**
- **Done:** three critics (art director, motion technician, player) ran as three separate parallel Agent-tool
  subagents. Each read only its brief and the slice-1 packs for all 16 rooms. Their findings are merged into
  [[depth_critique_2026-10-27]]: a per-room score from 1 to 5 and 19 ranked findings, with duplicates merged.
- **Five worst rooms:** LizardCave 1, BanditCamp 1, MesaClimb 2, MayorHall 2, DragonMural 2. ElderHouse and
  GatehouseCellar also score 2.
- **Not done:** no room was re-filmed. Downloading Godot was refused by this session's permission check, and `cv2` is
  not installed. The critics flagged the re-films they wanted instead.
- No game file changed, no D-ID, no B row fixed. No tests run: the change is two Markdown files.

## Proposed B rows (orchestrator: number and file them)

| Ref | Row | Critique # |
|---|---|---|
| B-a | **The camera stops dead at room limits.** `Game.tscn:191` Camera2D has no `limit_smoothed`, so 9 of 16 rooms jolt from 30 to 0 px/frame. Fix: `limit_smoothed = true`. | 3 |
| B-b | **The CityGates rock parks over the hero at the left camera limit** for ~2 s, so the hero is hidden (D750). Fix: place occluders off-view at both camera limits, and add a check for that. | 2 |
| B-c | **The FrontDark rock's painted foot stands on the road and skates** at ×1.3 (CityGates, DesertRoad, LaboratoryOutside, Village). D750 says «foot below the view». | 4 |
| B-d | **One-screen rooms twitch ~24 px** when the hero crosses the middle (~10 px of camera travel). Fix: lock the camera to the room centre when the room is less than 32 px wider than the view (`Game.gd` ~530). | 5 |
| B-e | **Parallax planes judder** in 2.25 px steps against a smooth floor (`snap_2d_transforms_to_pixel`). Fix: round the camera to world pixels. Confirm with a 60 fps re-film first. | 7 |
| B-f | **Laboratory's Atmosphere planes have `scroll_scale.y = 1`**, so they rise as one slab with the walkway. | 11 |
| B-g | **Cloud drift runs against depth**: ×0.12 drifts −9 px/s while ×0.2 drifts −4 px/s (`drifting_clouds.tscn`). | 17 |

The critics also confirm slice 1's **B-new-1** (BanditCamp, a single plane), **B-new-2** (MesaClimb and DragonMural
floors), **B-new-3** (GatehouseCellar) and **B162**. Amendment to B162: the sky behind the cave openings becomes its own
far plane.

## Proposed Q for Sapega (not asked: a routine cannot reach him)

| Ref | Question | Default until answered |
|---|---|---|
| Q-a | **One-screen rooms** (DragonMural, ElderHouse, MayorHall, MesaClimb) cannot show parallax. Should they be made ≥1.3 screens wide, or kept as still pictures whose depth comes from painting, foreground and living props? | Keep the size; fix the twitch (B-d). |
| Q-b | **The foreground palm:** may it cross the hero himself, or only the scene around him? | Not over arrival or rest spots. |
| Q-c | **Indoor pillars (D750):** keep them pure black silhouettes, or show a faint rim and their masonry? | Unchanged. |
| Q-d | **Props on a middle plane:** may their feet show sliding on the floor line, or must a floor lip always hide that join? This applies to every future M6 prop plane. | A lip hides it. |
| Q-e | Only if B-e is fixed by turning pixel snapping off: is slightly softer pixel art in motion acceptable? | — |
| Q-f | Slice 1's Q-new: the hero's drawn feet sit ~12 world px below his collision. The player critic leans toward a B row once a 1:1 re-film confirms it. | No change. |

## Proposed M6 art rows (for [[m6_backdrops]])
- Cut BanditCamp and GatehouseCellar into far, middle and wall planes. Barrels, crates, the wine rack, the lantern and
  the bat each become a single prop.
- Add MesaClimb to Batch 0 (D774, no foreground), and give it the B162 floor cut.
- Painted floor strips for ElderHouse and MayorHall, replacing the beige `TileMap`. Give LabBoss and LabCells floor
  bands a front lip.
- Repaint DragonMural and ElderHouse walls without repeats; the landmarks become single props.
- A ×0.75 middle plane for LabBoss and Canyon. Desaturate LabBoss's far furnaces and Canyon's ×0.45 wall.
- One or two occluder variants per biome, so the same rock and palm don't recur in four rooms.
- `fg_pillar` with form (if Q-c says yes).
- Give the outdoor road band a darker front lip.

## Notes
- The critics never saw one another or the slice-1 report. Five findings came from all three independently: the
  single-plane rooms, the parked CityGates rock, the one-screen rooms and the black pillars. Two critics agreed on
  six more.
- Checked in code before filing: `Game.tscn:191` (no `limit_smoothed`), `drifting_clouds.tscn:11-43`,
  `Laboratory.tscn:810-944` (`scroll_scale.y = 1`), `CityGates.tscn:337`, `project.godot:312`.
- The motion technician measured per-frame shifts with its own scripts, written to the session scratchpad and not
  committed.
- Coverage differs by critic. The art director and the player viewed every room's filmstrip. The motion technician
  did not view the images for BanditCamp, GatehouseCellar, LizardCave, MayorHall and MesaClimb; its findings there
  rest on its per-frame measurements and `layers.json`.
