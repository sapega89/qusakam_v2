---
type: report
tags: [cloud, routines, sky, D864]
---

# yellow-sky — the sky is yellow until the hero leaves the Laboratory (D864)

- **Done:** every outdoor sky is now a warm, dusty yellow with cream clouds and no sun disc. It turns blue (the sky as
  painted) when the hero leaves the Laboratory. All of it is in one place, `SampleProject/Scripts/Gameplay/SkyTint.gd`
  (a MetSys module that Game adds), driving shared materials. No `Maps/*.tscn` was edited.
- **Lab-exit flag:** `lab_outside_complete`. Entering the courtyard sets it (D437). The sky turns blue in that same room,
  not only from the next room on.
- **D-ID text (D864, as implemented):** *Before `lab_outside_complete` every sky plane (both backdrops' Plan5, the rooms'
  `Back/Sky` and `HighSky`, and the canyon sky baked into the cave far walls) is retinted to the duotone
  `UITokens.SKY_DUST_DEEP` (#c9a55e) → `SKY_DUST_PALE` (#f3e2ad). Clouds use `SKY_CLOUD_SHADE` (#d8bc8c) →
  `SKY_CLOUD_CREAM` (#fff0cc). From the flag on, the sky is the painted blue and the clouds are as painted. Interiors are
  unchanged.*
- **B rows fixed:** none.
- **Tests:** new `verify_yellow_sky` ALL PASS. `verify_canyon_exit`'s "sky up there is blue" check is now "dusty
  yellow (D864)". Full suite: see the end of this note.
- **Not done / for others:** see "For the room routine" and "Open" below.

## How it works

- `SampleProject/Shaders/sky_tint.gdshader` + `Resources/Materials/sky_tint.tres` recolour any sky plane (a texture, a
  gradient, or a Polygon2D colour) into the duotone, keyed by lightness plus warmth so the painted bands survive.
  `yellow = 0` passes the painted sky through. `sky_tint_keyed.tres` is the same shader with `keyed = true`: it recolours
  only light, bluish pixels (b > r), for textures with sky baked into rock art.
- `SampleProject/Shaders/sky_clouds.gdshader` handles the clouds: the same 3x3 depth blur, now shared through
  `depth_blur.gdshaderinc` (`depth_blur.gdshader` behaves the same), plus a cream duotone (`cream = 0`: as painted).
  `sky_clouds_far.tres` (radius 1.6) replaces `depth_blur_far.tres` on the clouds of `drifting_clouds.tscn` and on both
  backdrops' Plan4. `sky_clouds.tres` (radius 0) goes on the rooms' own `HighClouds`. The clouds need their own shader,
  because Low quality (D554) strips `depth_blur` materials, and that would turn the clouds pink again.
- `SkyTint.gd` (`Game.gd` → `modules.append(SkyTint.new(self))`):
  - On `room_loaded` and on `quest_flag_changed(lab_outside_complete)` it sets `yellow`/`cream` and the token colours on
    the four shared materials.
  - It gives the room's own sky nodes their material: `Back/Sky`, `HighSky`, `HighClouds` sprites (`Canyon/gen_clouds.png`
    with no material), and the baked-sky textures (`BAKED_SKY`: `LizardCave/gen_far.png`, `BanditCamp/gen_far.png`).
- The backdrop Plan5 sprites have `sky_tint.tres` set in `desert_backdrop_open.tscn` / `desert_backdrop_canyon.tscn`.
- `UITokens.gd` adds the four `SKY_*` colours.

## Rooms covered

- Backdrop (shared scene): Village, Canyon, DesertRoad, CityGates, City, LaboratoryOutside.
- `Back/Sky` Polygon2D (runtime): CraftQuarter, MountainPath, PalaceSquare, RockLedges, Rooftops, ScreeSlide, StreamGorge.
- `HighSky` gradient (runtime): Canyon (exit cutscene), LaboratoryOutside (finale; always after the flag, so blue).
- Baked sky (runtime, keyed): BanditCamp, CanyonFloor, CaveExit, CaveUnderBridge, Chasm, DryRiverbed, Dunes,
  GateApproach, LizardCave, LizardCaves, MesaTop, SmugglersStash, ZahraRest.
- Not touched: the main menu sky (outside the story), and interiors. A scan of every background texture for light-blue
  pixels found water, crystals, glass and blue domes (ZahraRest's oasis, crystal_sheet, City/gen_chapel…). These are
  not sky and are left alone.

## For the room routine (optional, nothing is broken)

- The seven `Back/Sky` rooms and Canyon / LaboratoryOutside `HighSky`: if `material = sky_tint.tres` is put in the
  `.tscn`, the runtime assignment becomes a no-op. The same goes for `HighClouds` → `sky_clouds.tres` in Canyon /
  LaboratoryOutside. That is cosmetic, and `ROOM_SKIES` / the `CLOUD_BANK` rule can stay.
- BanditCamp's far dunes (`BanditCamp/gen_far.png`) have a lilac-and-pink sky painted in. The keyed tint turns the
  lilac yellow, but the pink bands stay as a dusk glow. A repaint of that texture's sky would be cleaner.

## Open

- On Low quality the clouds keep their 3x3 blur, because `sky_clouds.gdshader` is not in
  `GraphicsQuality.LOW_DROPS_SHADERS`. That covers only a few small sprites plus Plan4. If it matters, Low could set
  `radius = 0` on `sky_clouds_far.tres`.
- The flat `Back/Sky` polygons come out on the deeper ochre side (MountainPath row in the shot). This is readable, but a
  little darker than the backdrop rooms.

## Readability (captures)

`design/shots/yellow_sky.png` has one row per room: Canyon, DesertRoad, City, MountainPath, CaveUnderBridge, and the
courtyard. The left column is yellow (before the flag) and the right is blue (after). The courtyard has the flag set by
its own entry, so both of its frames are blue. The hero (pale head, dark armour), the red-hooded bandit, NPCs and the
dark HUD panels stay clearly readable against the pale yellow. Contrast is best near the horizon, where the characters
stand.

## Tests

- `verify_yellow_sky` (new) — RESULT: ALL PASS. It checks the token colours, DesertRoad's backdrop planes and clouds,
  MountainPath's `Back/Sky`, CaveUnderBridge (keyed baked sky only), the courtyard (its own flag turns the sky blue at
  once, HighSky still painted blue), and City after the flag.
- `verify_canyon_exit`: the sky check was updated (yellow, D864).
- Full suite: FULL_SUITE_LINE
