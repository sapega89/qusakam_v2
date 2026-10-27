---
type: review
status: open
tags: [art, rooms, critics, M6]
---

# Depth critique — 2026-10-27 (from film, not stills)

Slice 2 of [[depth_critics_plan]]. Input: the slice-1 packs in `design/shots/depth/<room>/` (filmstrip, slit-scan,
`layers.json`) for all 16 rooms, filmed in the game with real input ([[cloud_reports/depth-film|depth-film]]). Three
critics ran as separate read-only agents, each with only its brief and the pack paths. None saw the others' notes or
the slice-1 report: the **art director (AD)**, the **motion technician (MT)** and the **player (PL)**. Nobody
re-filmed: this session has no Godot binary and no `cv2`. Where a critic needed more motion, the finding says
«needs a re-film».

Seconds are film seconds: filmstrip cell k = k·0.5 s; in the slit-scan, 90 px down = 1 s. Triage below is
**proposed**. The orchestrator files the B and Q rows (`BUGS.md` and the registers are untouched here).
Code claims were checked in this checkout: `Game.tscn:191` Camera2D has no `limit_smoothed`;
`drifting_clouds.tscn:11-43` sets autoscroll −6/−9/−4 at scroll 0.15/0.12/0.2; every `Laboratory.tscn` Atmosphere
plane has `scroll_scale.y = 1`; `CityGates.tscn:337` puts OccluderRock1 at (300, 520).

## Per-room depth verdict

The score is the rounded mean of the three critics' scores (AD / MT / PL in brackets). 1 = flat, 5 = deep and solid.

| Room | Depth | (AD/MT/PL) | Why |
|---|---|---|---|
| LizardCave | **1** | 1/1/1 | One baked ×1.0 card: all three slit-scan bands share one slope. The sky in the openings slides with the rock, and the hero runs ~100 px below the painted ledge (B162). |
| BanditCamp | **1** | 1/1/2 | One ×1.0 plane (`Back`, 98 % of the view). Sky, tents and barrels move together, the hero runs over painted barrels, and nothing stands in front of him. |
| MesaClimb | **2** | 2/1/2 | The camera never pans. The floor is a painted boulder pile that the flat walk line crosses, and there is no foreground at all. The value depth in the painting is good. |
| MayorHall | **2** | 1/1/3 | The camera never pans. The arches repeat, the floor is a flat beige tile that reads as a placeholder, and there is no foreground. |
| DragonMural | **2** | 1/1/3 | The camera never pans. The mural reads as tiled (two dragons a view). The hero's feet do sit on the painted ledge. |
| ElderHouse | **2** | 1/1/3 | The camera never pans. The window and rug repeat, and the floor is the flat beige tile. |
| GatehouseCellar | **2** | 2/1/3 | One tiled ×1.0 backdrop (stairs, lantern and bat twice a screen) plus a flat black ×1.3 pillar. |
| CityGates | **3** | 3/3/2 | The planes layer well. At the left camera limit the ×1.3 rock parks over the walk line and hides the hero for ~2 s. |
| DesertRoad | **3** | 4/3/3 | Five planes and good overlap. The rock and the palm are in one screen, the rock's foot skates on the road, and the camera stops hard at its limit. |
| LabBoss | **3** | 3/3/4 | The floor is solid. Far ×0.4 then floor ×1.0, with no middle plane. The far furnaces are the brightest thing on screen (an inversion) and judder. |
| LabCells | **3** | 3/3/3 | Two clear slopes. The pillar is a featureless black slab, and two foregrounds run at ×1.25 and ×1.3. |
| LaboratoryOutside | **3** | 4/3/3 | Good scale cues (the palms shrink with distance). The ×0.6 plane staggers, and the palm swallows the hero at 0 s. |
| Canyon | **4** | 4/3/4 | Five planes in z order. Nothing between ×0.45 and ×1.0, the palm crown covers the resting hero, and the camera stops hard at its limit. |
| City | **4** | 4/4/4 | The best motion: nine planes, the buildings shrink, and contrast falls with distance. Only sub-pixel judder. |
| Laboratory | **4** | 4/3/4 | Value and contrast fall correctly. On the vertical camera move every plane shifts as one slab, and the far hall shows under the walkway. |
| Village | **4** | 5/4/3 | Seven planes at seven speeds, the deepest room. The rock's foot skates across the walk line at 2.5–3.0 s. |

## Findings, ranked

The ranking runs by severity, then by how many critics found the item; agreement between critics makes a finding
stronger. **[×3]**, **[×2]** and **[×1]** mark how many critics independently reported it. Merged duplicates name
every critic.

### 1. Single-plane rooms: BanditCamp, GatehouseCellar, LizardCave — **[×3] AD + MT + PL** — high
- **Where:** the whole film, all three slit-scan bands. MT measured equal per-frame shifts in all bands, e.g.
  GatehouseCellar −27, −26, −27 px/frame.
- **What:** one baked `Back` at ×1.0 is the room. In GatehouseCellar and LizardCave the only other speed is a thin
  ×1.3 FrontDark (15 % / 5 % of the view). In LizardCave the sky through the openings slides with the rock (AD).
- **Why it breaks depth:** in motion it is a single painted card scrolling past. The sky moving at world speed
  reads as a blue patch, not as distance.
- **Fix (art lane):** cut each backdrop into a far plane (×0.1–0.5: sky and distance, and in LizardCave the sky
  behind the openings, which become alpha holes in the wall), a middle plane (×0.7–0.85: BanditCamp tents,
  stockade and spear rack; GatehouseCellar dim vaults beyond the arches) and the room's wall at ×1.0 with the
  floor top on the walk line. Single props go on their own plane, placed once: barrels, crates, the wine rack, the
  lantern, the bat (as a D774 critter), the lizard shrines.
- **Triage:**
  - LizardCave: **B162** (not new), plus an amendment: the sky behind the openings becomes its own plane.
  - BanditCamp and GatehouseCellar: new **M6 art rows**. These confirm slice-1's B-new-1 and B-new-3. BanditCamp's
    foreground is already M6 Batch 0 (D774).

### 2. CityGates: the ×1.3 rock parks over the hero at the camera limit — **[×3] AD + MT + PL** — high
- **Where:** 1.5–3.7 s, filmstrip cells 2.0, 3.0 and 3.5, and a vertical dark block in slit-scan bands 55 % and
  80 %.
- **What:** the hero runs to the room's left end and the camera clamps. `FrontDark/OccluderRock1`
  (`CityGates.tscn:337`, position (300, 520)) then stops sliding and sits over screen x ≈ 280–1040 and the walk
  line for ~2 s. The hero is fully hidden where he stops.
- **Why it breaks depth:** a ×1.3 occluder reads as near only while it slides faster than the world. Parked, it
  is a black hole over the play line, against D750 and D774 («never over the middle of a fight»).
- **Fix (code):** place every FrontDark occluder so that at both camera limits it rests off-view or at an edge
  (screen x < 0 or > ~1700). Add a check that tests every ×1.3 occluder at both camera limits, next to
  `verify_room_entrances`.
- **Triage:** new **B row**.

### 3. The camera stops and starts hard at room limits — **[×1] MT**, confirmed in code — high
- **Where:** 9 of 16 rooms, each time the camera reaches a limit (e.g. BanditCamp ~1.05 s and ~4.7 s), as sharp
  corners in all slit-scan bands.
- **What:** the picture goes from ~30 px/frame to 0 in 1–2 frames (BanditCamp 29 → 20 → 0, LizardCave 30 → 6 → 0,
  GatehouseCellar 29 → 16 → 0, CityGates 28 → 20 → 0). It restarts at full speed (DesertRoad −6 → −25). City
  never touches a limit and ramps smoothly, so the limit causes this, not the input.
- **Why it breaks depth:** every plane jolts in the same frame. It reads as a camera bump, and the speed
  differences vanish at that moment.
- **Fix (code):** `SampleProject/Game.tscn:191` `Player/Camera2D`: `limit_smoothed = true`. Position smoothing
  is already on, and this property is missing.
- **Triage:** new **B row**.

### 4. FrontDark rock: its painted foot stands on the road and skates — **[×1] PL** (MT: the same rock in four rooms) — high
- **Where:** CityGates 1.5–3.5 s, DesertRoad 1.5–3.5 s, LaboratoryOutside 2.0–3.5 s, Village 2.5–3.0 s
  (filmstrip).
- **What:** `FrontDark/OccluderRock*` (gen_rock ×2.2, plane ×1.3) shows its base ~20 px below the hero's feet
  line, with road visible under it. D750 says «foot below the view».
- **Why it breaks depth:** an object touching the ground but moving at ×1.3 against a ×1.0 road turns the floor
  into a conveyor belt. It also reads as an obstacle the hero walks through.
- **Fix (code):** move each rock down until its painted foot is below the view, or crop the PNG's transparent
  bottom rows. PL suspects these rows lift the painted foot ~60 px above the node; the PNG alpha was not checked.
- **Triage:** new **B row** (contradicts D750). Medium–high confidence.

### 5. Single-screen rooms: no parallax at all, plus a camera twitch — **[×3] AD + MT + PL (static camera)** — high (depth) / medium (twitch)
- **Where:** DragonMural, ElderHouse, MayorHall and MesaClimb. Probe: feet x = 2.25 × world x, and `speed_x` is
  null for every plane. MT and AD: the whole picture jumps ~24 px within 2 frames at ~1.1–1.3 s and
  ~3.8–3.9 s.
- **What:** these rooms are ~864 world px wide against an 853 px view, so the camera has ~10 px of travel and snaps
  across it when the hero crosses the middle. FrontDark and TopShade never move against the wall.
- **Why it breaks depth:** no parallax value can produce motion depth here. The only camera motion is a twitch.
- **Fix:**
  - Twitch (code): in `Game.gd` around 530–540, where the limits are set, lock the camera to the room centre when
    the room is less than ~32 px wider than the view.
  - Depth: needs a product call.
- **Triage:** new **B row** for the twitch, and **Q for Sapega** (below: Q-a).

### 6. Featureless black pillars indoors — **[×3] AD + MT + PL** — low–medium
- **Where:** GatehouseCellar 1.5–3.5 s (it cuts into the hero at 2.0 s); LabCells 2.0–3.5 s (filmstrip).
- **What:** `fg_pillar` renders as a ~240 px uniform near-black full-height bar (value 0.02–0.03, contrast
  0.01–0.03). The camera hovers, so one is in almost every cell.
- **Why it breaks depth:** a shape with no inner form reads as a gap or a missing texture, not as a column near
  the camera. The eye has nothing to track.
- **Fix (art lane):** keep it dark, but add a faint warm rim toward the room's lamps, a capital and base, and a
  slight vertical ramp (contrast ~0.06–0.08). Narrow it and keep it off the hero's resting spots.
- **Triage:** a **Q for Sapega** (Q-c: this refines the approved D750 look), then an **M6 art row**.

### 7. Sub-pixel judder of parallax planes — **[×1] MT** — medium (medium confidence)
- **Where:** LabBoss 1.1–2.4 s (band 30 %), LaboratoryOutside 0.2–2.4 s (band 55 %), Canyon 1.3–2.0 s (band
  55 %), and City.
- **What:** the parallax planes move in uneven steps while the floor is smooth: LabBoss Far1 ×0.4 at 8, 12, 11,
  8, 12, 13, 9 px/frame; LaboratoryOutside Mid ×0.6 at 16/14 alternating; Canyon Plan3 8, 9, 6, 10, 7. The
  steps cluster at multiples of 2.25 px, which is one world pixel. `project.godot:312`
  `snap_2d_transforms_to_pixel=true` plus a camera smoothed to sub-pixel positions makes the parallax offsets
  quantise out of phase.
- **Why it breaks depth:** the planes that carry the depth shimmer against a smooth floor.
- **Fix (code):** (a) round the camera's final position to whole world pixels every frame, or (b) turn the snap
  off. Option (b) softens the pixel art in motion.
- **Triage:** new **B row**. A **Q** (Q-e) only if (b) is chosen. Needs a re-film at 60 fps to PNG to confirm.

### 8. Tile floor in ElderHouse and MayorHall; dead floor band in LabBoss and LabCells — **[×2] AD + PL** — medium
- **Where:** all cells, the bottom ~20 % of the view.
- **What:** ElderHouse and MayorHall show a flat beige noise `TileMap` (value 0.63, contrast 0.10) in another
  style from the painted room, and MayorHall's right column uses the same tile. LabBoss and LabCells show a dark
  uniform grating band.
- **Why it breaks depth:** the floor is physically right (its top is at 0 px) but reads as a debug strip under a
  painted room. It is a large repeated texture with no near cue.
- **Fix (art lane):** a painted floor strip per room (boards or stone) with a darker front lip, as the floor plane
  on the walk line. Add an occasional low near object at the sides.
- **Triage:** new **M6 art row**.

### 9. The hero's drawn feet are ~12 world px below his collision — **[×1] PL** (also slice 1's Q-new) — medium
- **Where:** every room and every screen (`hero_sprite_bottom_px` = +26.2 screen px). On flat floors with
  their top at 0 (ElderHouse, MayorHall, LabBoss, LabCells, Laboratory) the feet sink into the floor. In road rooms
  it falls inside the D559 band.
- **Fix (code):** first confirm the row is the sprite, not a child effect: the probe counts every CanvasItem under
  Player. Then align the `Sprite2D` offset or the collision shape.
- **Triage:** slice 1 filed this as a **Q** (Q-f). PL would make it a B row once a 1:1 re-film crop of the feet
  confirms it. Kept as the Q.

### 10. The palm crown at hero height; occluders bunch up — **[×2] PL + MT (the same stamp in four rooms)** — medium
- **Where:** Canyon 3.5 s (covers the resting hero), LaboratoryOutside 0.0 s (nearly hides him), DesertRoad
  1.5 s (palm and rock in one screen). The Canyon palm is in view in 7 of 8 cells.
- **What:** the palm (×3, foot below the view, correct) has its crown in the 760–1000 px band where the hero
  stands. The identical rock and palm recur in Canyon, DesertRoad, Village and LaboratoryOutside.
- **Fix:** keep the palm off arrival and rest spots and space the occluders out (layout). A shorter or taller palm
  variant, and one or two occluder variants per biome (art lane).
- **Triage:** **Q for Sapega** (Q-b) on hero cover, plus an **M6 art row** for the variants.

### 11. Laboratory: the planes move as one slab vertically — **[×2] MT + PL** — medium
- **Where:** ~0.9–1.6 s, filmstrip 1.0 → 1.5, slit-scan bands 55 % and 80 %.
- **What:** the camera rises ~64 px as the hero goes up a level. Every Atmosphere plane has
  `scroll_scale.y = 1` (`Laboratory.tscn:810-944`), so the far hall shifts exactly as much as the walkway. PL also
  saw the far vats (×0.4) continue under the walkway, so the floor reads as a thin bridge. The `Mid1` equipment
  (×0.75) has its foot 11 px above the ×1.0 floor top, so it skates on the floor.
- **Fix (code):** set `scroll_scale.y` equal to x on the Atmosphere planes, and check the texture height or
  `repeat_size.y` so no plane edge comes into view. Close the gap under the floor (a slab or a lower-storey plane).
- **Triage:** new **B row** (vertical scroll). **Q for Sapega** (Q-d) on where mid-plane props meet the floor.
  MesaClimb probably needs the same; it needs a re-film with the climb.

### 12. Landmarks tiled twice per view — **[×1] AD** (MT and PL saw the repeats in GatehouseCellar and LizardCave) — medium
- **Where:** every cell of DragonMural (two murals, two shrine arches), ElderHouse (two windows, two rugs ~1300 px
  apart), GatehouseCellar (stairs, lantern and bat twice) and LizardCave (the shrine pair twice).
- **Why it breaks depth:** the one thing to look at becomes wallpaper. This breaks M6's rule that no screen is a
  repeated texture.
- **Fix (art lane):** one non-repeating ×1.0 wall at room width, and each landmark a single prop on its own plane.
- **Triage:** new **M6 art row** (GatehouseCellar and LizardCave fold into #1). Medium confidence from 480 px
  cells.

### 13. MesaClimb: a boulder-pile floor and no foreground — **[×2] PL + AD** — medium
- **Where:** 1.5 s and 3.0 s. At 3.0 s the hero walks over the big painted boulder he stood on at 1.5 s.
- **What:** a flat collision line crosses painted bumps. `FrontDark` is missing: only TopShade is there.
  MesaClimb is not in M6 Batch 0, though D774 requires a foreground.
- **Fix (art lane):** the B162 cut, with a floor plane whose top is flat on the walk line. Move the big boulder to
  ×0.85 or make it collision. Add dark rock spurs or a dry bush low at the corners and a root at the top, ×1.3.
- **Triage:** **M6 art rows**: add MesaClimb to Batch 0 (D774) and give it the B162 cut. This confirms slice-1's
  B-new-2.

### 14. BanditCamp: painted barrels on the walk line — **[×2] AD + PL** — medium
- **Where:** 3.0–3.5 s. The hero runs in front of, or over, the barrel and sacks painted at the bottom.
- **Why it breaks depth:** these props read as nearest, yet the hero passes in front of them. The overlap
  contradicts the motion.
- **Fix (art lane):** part of #1. Move them into the side foreground (D774 arena rule), or onto the ×1.0 plane
  above the walk line.
- **Triage:** folds into #1's **M6 art row**.

### 15. LabBoss: the far plane is the loudest; no middle plane — **[×1] AD** (MT: Far1 judders most) — medium
- **Where:** 0–4.5 s, slit-scan band 55 %.
- **What:** the far fire arches (`Atmosphere/Far1` ×0.4) are the brightest and most saturated area on screen,
  while the ×1.0 walk plane is dark purple. There are two speeds only. The probe's solo value for Far1 (0.05)
  contradicts the picture: the glow is probably added later.
- **Fix (art lane):** add a ×0.75 plane (cauldrons, chains, tanks). Desaturate the far furnaces toward the violet
  air. Let firelight spill on the floor edge near the hero. PL adds that the hero's dark body on the dark floor
  (value 0.29) leaves only his head reading.
- **Triage:** **M6 art row**.

### 16. Canyon: no middle plane; far wall as saturated as the ground — **[×2] AD + MT** — low–medium
- **Where:** 1.3–2.1 s, slit-scan band 55 %. Speeds: ×0.1, 0.3, 0.45, then 1.0.
- **What:** Walls ×0.45 has saturation 0.47, against the ground's 0.50.
- **Fix (art lane):** a ×0.75 plane of nearer rocks, with small dead trees as scale cues. Desaturate Walls to ~0.30.
- **Triage:** **M6 art row** (the Batch 1 canyon kit).

### 17. Clouds drift against depth — **[×1] MT**, confirmed in code — low
- **What:** in `drifting_clouds.tscn`, Cloud2 (×0.12) has autoscroll −9 px/s and Cloud3 (×0.2) has −4. The
  farther cloud drifts more than twice as fast. Seen in all six outdoor rooms, in slit-scan band 30 %.
- **Fix (code):** make autoscroll grow with scroll_scale (e.g. ×0.12 → −3.5, ×0.15 → −5, ×0.2 → −6).
- **Triage:** new **B row**.

### 18. Outdoor road less contrasty than the plane behind it — **[×1] AD** — low
- **What:** Terrain contrast is lower than the middle plane's in four rooms: DesertRoad 0.12 vs Mid 0.19, City
  0.13 vs 0.18, Village 0.12 vs 0.16, LaboratoryOutside 0.15 vs 0.16. Value falls correctly; saturation is
  highest on the road.
- **Fix (art lane):** a crisp darker front lip with pebbles on the road band (contrast ≥ 0.20). Haze the ×0.6
  plane toward the sky.
- **Triage:** **M6 art row**.

### 19. LabCells: two foregrounds at nearly the same speed — **[×1] MT** — low
- **What:** `Atmosphere/Front1` runs at ×1.25 and FrontDark at ×1.3, so the second one adds no layer.
- **Fix (code):** move Front1 to ~×1.15 or drop one of them.
- **Triage:** folds into #6's **M6 art row**.

## Re-films the critics asked for
- The hero's feet 1:1 in a tile-floor room and in a road room (#9).
- Jitter at 60 fps, to PNG rather than JPEG (#7).
- MesaClimb with the climb, so the camera moves vertically (#11). No other room's camera moves vertically during
  the jump: `Game.gd:538` locks `limit_top` in one-screen-tall rooms.
- A run of two screens or more in Canyon and DesertRoad, to judge occluder frequency against D750 (#10). The film
  covers only ~0.7 of a screen.
