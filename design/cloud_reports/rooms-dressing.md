---
type: report
tags: [cloud, routines, rooms]
---

# rooms-dressing (cloud routine, 2026-10-27) — R2 + R3

**Summary.**
- Branch `cloud/rooms-dressing` = `cloud/integrate-29` + `feature/backlog` (MASTER_PLAN/HANDOFF conflict: feature/backlog's plan, integrate-29's register numbers).
- **R3 done, each at the root:** B176 (eased room limits), B177 (no ×1.3 occluder parks mid-frame at a camera limit; CityGates rock), B178 (rock foot below the view: the sprites were `centered` *and* foot-offset), B180 (planes on the camera's world-pixel grid), B181 (Laboratory vertical factors), B182 (clouds in depth order), GatehouseCellar `Pillar2` off the hero (R1 tail).
- **R2 done:** critter scenes for every sheet (lark, pigeon, butterfly, blue butterfly, moth) at the exact world-scale sizes, placed in 11 rooms; one or two atmosphere effects in all 16 rooms (Low halves 16+); grass tufts along 8 outdoor walk lines. **Not done:** the mouse — its sheet has landed, but it needs a ground path and a hole (note in [[ambient_critters_plan]]).
- **Proposed D-IDs** (routine calls, text below): D-rd1 world-pixel camera, D-rd2 eased limits, D-rd3 occluders at camera limits, D-rd4 Laboratory vertical parallax, D-rd5 one wind for the clouds, D-rd6 critters, D-rd7 atmosphere per room, D-rd8 grass. **B rows fixed:** B176, B177, B178, B180, B181, B182. Q106 need not be asked (snap stays on).
- Full suite (once, at the end): `SUITE: 2 FAIL`, 136 PASS — `verify_masher` HUNG (as in integrate-29), `verify_combat_feel` «a bandit dropped on the hero slides off» flaky and not this routine's: it fails 2 of 2 on the base commit `54ffa86a`, 1 of 2 here.

## Proposed D-IDs (orchestrator: number them, do not edit the text's meaning)
| ID | Kind | Text |
|---|---|---|
| D-rd1 | ROUTINE | **The camera and every parallax plane sit on whole world pixels.** `PixelSnapCamera.gd` on `Player/Camera2D` rounds the view's top-left to whole world px after Camera2D's own update and gives every `Parallax2D` the matching `screen_offset` (Camera2D's own frame: view centre − viewport / 2). Pixel snapping stays on (Q106 not needed). Fixes B180. |
| D-rd2 | ROUTINE | **The camera eases into and out of room limits** (`limit_smoothed = true` with the existing position smoothing). Fixes B176. |
| D-rd3 | ROUTINE | **Front occluders at the camera limits:** at both limits of its room every ×1.3 occluder is off view or only in the outer 12 % of the frame, and one that reaches below the hero's feet has its painted foot below the view. Checked in `verify_room_entrances`. Fixes B177, B178 (extends D750). |
| D-rd4 | ROUTINE | **Laboratory vertical parallax:** the Far planes are one stack at y ×0.4 anchored at the middle storey; each Mid band is y ×0.75 anchored to its own storey (there it stands where it stood); the Front slabs stay y ×1 because they are the floor edges. Fixes B181. |
| D-rd5 | ROUTINE | **One wind for all clouds:** `autoscroll = −30 px/s × scroll factor` (×0.1 −3, ×0.12 −3.6, ×0.15 −4.5, ×0.2 −6). Fixes B182. |
| D-rd6 | ROUTINE | **Critters (R2):** perching critters live on the room plane behind the gameplay nodes; bats hang on FrontDark. Sizes exactly from [[world_scale_plan]] × the plane factor (lark, pigeon 36 world px perched; butterfly, moth 18; the FrontDark bat 46.5). All share 160 px scare, 30 s return. Birds and bats play `critter_flap` on take-off; butterflies and the moth are silent. Never within 96 px of a door, NPC, chest or pickup, nor within 200 px of a fight trigger. Who lives where: larks + orange butterflies outdoors (Canyon, Village, DesertRoad, CityGates, BanditCamp, MesaClimb), blue butterflies by the oasis (LaboratoryOutside), pigeons in the City, bats in the Lizard Cave and the Gatehouse Cellar, the moth in Grandfather's attic. |
| D-rd7 | ROUTINE | **Atmosphere per room (R2):** outdoors drifting pollen / sand (Canyon and DesertRoad keep their dust swirls); Lizard Cave fireflies; Dragon Mural and Gatehouse Cellar spores; ElderHouse and MayorHall window light shafts with motes; LabCells steam; Laboratory steam + sparks; LabBoss embers + steam. Glow textures from `Critters/glow_*`, low alpha, behind the hero; emitters of 16+ particles halve on Low (D554). |
| D-rd8 | ROUTINE | **Grass (A4):** `grass_tuft.tscn` (16 art px = 24 world px, 4 fps sway, random frame / speed / flip) in clusters of 1–3 every ~150 px along the outdoor walk lines (City only at its two ends, MesaClimb on the ledges), behind the hero, standing on the floor, 96 px off doors, chests and pickups. |

## R3 — what changed and why
| Item | Root cause found | Change |
|---|---|---|
| B180 parallax judder | `Parallax2D` positions its plane from a camera that is between world pixels, then the snap rounds the plane and the floor separately: even the ×0 sky moved ±1 world px a frame on a real run (Canyon, `Plan5` steps −0.6 / +1.6 / −0.8 px). | `SampleProject/Scripts/Gameplay/PixelSnapCamera.gd` (new) on `Game.tscn` `Player/Camera2D`. After: sky step 0.00 every frame; the ×0.3 plane steps exactly 0.3 × the camera's step. |
| B176 hard stop at limits | Camera2D without `limit_smoothed` follows the hero beyond the limit, so leaving it the view jumps 0 → 2.1 → 13.4 px/frame. | `limit_smoothed = true` (`Game.tscn`). After: 2.25, 4.5, 4.5, … 13.5 px — at most one world px more per frame. |
| B178 rock foot on the road | `gen_rock` occluders were `centered` (default) **and** offset by (−78, −114): the foot stood 125 px above the node, on screen at y 419 of 480. | `centered = false`, node x − 172 so the drawn x is unchanged (Canyon, Village, DesertRoad ×2, CityGates, MesaClimb, LaboratoryOutside). The foot is now 64 px below the view. |
| B177 occluder parked over the hero | Occluders were placed by eye; at a camera limit the ×1.3 plane stops too. | 16 occluders moved to the nearest x that rests off the middle at both limits and still sweeps across the frame, clearing doors, NPCs, chests and fight middles: CityGates rock 128 → 763 and palm 1700 → 1808; Canyon palm 2700 → 2112; Village palm 400 → 669; DesertRoad palms 600 → 669, 6200 → 6300; BanditCamp ropes 480 → 591, 982 → 885 (and y 300 → 302 so their ends leave the frame); MesaClimb rock → 777; LaboratoryOutside palm 300 → 669, rock → 908; GatehouseCellar `Pillar2` 1556 → 1760; LabCells `Pillar1` 1100 → 1015; Laboratory pillars 1500 → 754, 100 → 655, 1300 → 1015. |
| Cellar `Pillar2` hides the hero at x 1450–1560 | the same parked-occluder problem | moved to 1760: at the right limit only its edge shows, right of the chest (`rooms_dressing_occluders.png`, row 3). |
| B181 Laboratory slab | every Atmosphere plane had `scroll_scale.y = 1` | Far1–3 `scroll_scale.y 0.4`, `scroll_offset.y −180`; Mid1/2/3 `0.75` with `45 / −75 / −165` (camera tops of the storeys: 120 / 600 / 960). Probed: each band stands at the same screen y as before at its own storey; the Far stack covers the view at every storey. Q105 (mid-plane props' feet) stays open. |
| B182 clouds against depth | Cloud2 ×0.12 drifted −9 px/s, Cloud3 ×0.2 −4 | `drifting_clouds.tscn`: −4.5, −3.6, −6 (= −30 × factor, like HighClouds −3 at ×0.1). |

Not in this routine: B179 (one-screen rooms twitch), B173/B174 (plane cuts, art), #6/#8/#10/#12–#16/#18/#19 of the critique; MesaClimb's vertical parallax (needs the climb re-filmed, R5).

## R2 — per room
| Room | Critters | Atmosphere | Grass |
|---|---|---|---|
| Canyon | 2 larks, 1 butterfly on a tuft | dust swirls (existing, the reference) | 19 tufts |
| Village | 2 larks, 2 butterflies | pollen 24 | 35 |
| ElderHouse | the moth in the attic | window light shaft + motes | — |
| DesertRoad | 3 larks, 2 butterflies | pollen 48 + dust swirls (existing) | 40 |
| LizardCave | 2 bats (existing, now 46.5 px at ×1.3, flap sound) | fireflies 16 | — |
| DragonMural | — | spores 16 | — |
| BanditCamp | 1 lark, 1 butterfly | pollen 16 | 12 |
| MesaClimb | 1 butterfly (bottom floor) | pollen 16 | 4 |
| CityGates | 2 larks | pollen 16 | 18 |
| GatehouseCellar | 2 bats on FrontDark (x 600, 1400: 320+ px from both bat fights) | spores 16 | — |
| City | 3 pigeons | pollen 24 | 4 (the street's ends) |
| MayorHall | — | 2 light shafts + motes | — |
| LabCells | — | steam ×2 | — |
| Laboratory | — | steam ×3 (one per storey), sparks | — |
| LabBoss | — | embers 16, steam ×2 | — |
| LaboratoryOutside | 1 lark, 2 blue butterflies | pollen 16 | 21 |

New files: `Scenes/Backgrounds/Decor/critter_{bird,pigeon,butterfly,butterfly_blue,moth}.tscn`, `atmo_{fireflies,spores,pollen,motes,steam,sparks,embers,light_shaft}.tscn`, `grass_tuft.tscn`; `AmbientCritter.gd` gained `perch_animation`, `perch_flip`, `flap_sound` (the sound goes through `/root/AudioManager`: tests compile the script before autoloads). Sizes: lark perched 30 px × 1.2, pigeon 44 × 0.8182, butterfly / moth 19 × 0.9474, bat 39 × 1.1923, tuft 20 × 1.2.

**The mouse** waits: art is in (`Critters/mouse.png`), the ground run into a hole is not built — next slice written in [[ambient_critters_plan]] («Mouse — not placed yet»).

## Tests
- `verify_camera_transitions` new section [7]: canvas on whole world px, every still plane moves exactly factor × camera step, the snap keeps a ×1.3 plane where Camera2D puts it (≤ 1 world px), one wind for the clouds, eased limits both ways. Fails 4 of its checks on the old camera, passes now.
- `verify_room_entrances` new `_check_limits`: every room's occluders at both camera limits (B177) and their feet (B178).
- `verify_ambient_critters` new [5]–[7]: per room who lives there, exact perched size, clearances, flap / silence on take-off; one or two effects fitted to the place, Low halves 16+ and High restores; grass on the floor, behind the hero, off chests, pickups and doors.
- RESULT lines (touched areas, after the last change): room_entrances, ambient_critters, graphics_quality, settings_graphics, camera_transitions, camera_rooms, scripts_compile, laboratory, lab_rooms, lab_boss, lab_cells, living_world, map_geometry, bosses, desert_road, city_life, city_gates_raid, village_house, village_fight, mayor_hall, rooms_batch1, secrets — all `ALL PASS`.
- Noise seen, not this routine's: loading `DesertRoad.tscn` prints `DesertTileset.tres:190 - Parse Error` (same on the base commit `54ffa86a`).

## Shots
- `design/shots/rooms_dressing_critters.png` — Village lark + butterfly, City pigeons, Cellar bat, attic moth (before | after).
- `design/shots/rooms_dressing_atmosphere.png` — fireflies, spores, window light, Laboratory steam, LabBoss embers.
- `design/shots/rooms_dressing_grass.png` — Canyon, DesertRoad, CityGates.
- `design/shots/rooms_dressing_occluders.png` — CityGates at the left limit (B177), DesertRoad rock foot (B178), Cellar hero at x 1500 (Pillar2).
- `design/shots/rooms_dressing_lab_vertical.png` — Laboratory upper and lower storey (B181).
- `design/shots/rooms_dressing_camera.png` — per-frame steps before / after (B180, B176).
Made by `SampleProject/UI/capture_rooms_dressing.gd` (window) and `Scripts/Tools/rooms_dressing_sheet.py`; "before" from a worktree at `54ffa86a`.

## Commits
`655722a3` camera snap + eased limits · `2b000c10` planes in Camera2D's frame, Laboratory vertical, clouds ·
`ad10a694` occluders and rock feet · `b1b612ef` R2 critters, atmosphere, grass · `246b6d5a` sheets + mouse note ·
this report.
