---
type: cloud-report
branch: cloud/living-world
date: 2026-10-22
---
# Cloud report: living world (BACKLOG 7 + 19)

Branch `cloud/living-world` (from `origin/feature/backlog`). Godot 4.6.2 on Linux. Captures were taken with Xvfb at 1920×1080
(`SampleProject/UI/capture_living_world.gd`, a selection is in `design/shots/living_*.png`).

## What was built

### 1. Foreground planes (BACKLOG 7)
- `SampleProject/Scenes/Backgrounds/foreground_plane.tscn` is one shared scene: Parallax2D ×1.25, z 20, the Village modulate,
  repeat 864 ×4, Sprite with `depth_blur_front`. Every room instances it and sets only the texture and the sprite's y.
  Village now uses it too, with the same values as before, so there is one source.
- Wired in: Village (`Village/gen_front`, y 160, unchanged), Canyon (`Canyon/gen_front`, y 160, the same depth as Village
  because the Canyon camera also goes below the floor), DesertRoad (`Road/gen_front`, y 52), CityGates (`Gates/gen_front`,
  y 32), City (**reuses `Gates/gen_front`**, since there's no City plane and the cart/crates/sacks suit the market; y 40),
  LaboratoryOutside (`LabOut/gen_front`, y 48).
- The y values were set from captures. In the single-cell rooms the camera bottom sits about 90 px below the floor, so the
  plane's first opaque row is placed a few px under the hero's platform line (384; City 396 at the anvil). Then only the
  tops of rocks, crates and reeds show at the bottom of the screen, and nothing rises over the line the hero walks on.
- **Lab rooms are not touched.** They already have `Lab/gen_front`.

### 2. Decor idle loops (BACKLOG 19)
- `SampleProject/Scenes/Backgrounds/Decor/{banner,palm,lamp,crystal,dust}.tscn`: an AnimatedSprite2D with inline SpriteFrames
  (AtlasTexture per frame, frame counts and sizes from `Decor/README.md`), `idle` loop, autoplay, nearest filter, scale 1.5.
  The offset puts the node origin on the README anchor: the banner hangs from its rod, the palm, lamp and crystal stand on
  their foot, and the dust is centred (0.75 alpha). Fps: banner 5, palm 3, lamp 8, crystal 5, dust 6.
- Placed under a `Decor` node in each room. Each instance gets its own `frame` (phase) and `speed_scale` (0.8–1.2), so
  neighbours never sway in step:
  - Village: 3 palms on the street, a banner under Grandpa's eave and one by the Elder's house.
  - Canyon: 4 dust patches over the ground and the bridge.
  - DesertRoad: palms either side of the shop and by the shrine, 4 dust patches along the road.
  - CityGates + City: two banners hang in the arch under the bridge of `gate_passage.tscn`. That scene stands in both rooms.
  - LaboratoryOutside: 2 palms.
  - Laboratory, LabCells, LabBoss: lamps and crystals on floors and slabs. In LabBoss the oil lamp sits at the far right,
    not next to the djinn, so it doesn't read as a plot item.

### 3. Drifting clouds (BACKLOG 19)
- `SampleProject/Scenes/Backgrounds/drifting_clouds.tscn`: the three `Clouds/gen_cloud_*` sprites. Each is its own Parallax2D
  (scroll 0.12–0.2 so it follows the camera, `autoscroll` −4…−9 px/s so it drifts by itself, repeat 1728 so it wraps), with
  `depth_blur_far`.
- It is instanced into both `desert_backdrop_open.tscn` and `desert_backdrop_canyon.tscn` behind the mesas. That covers
  every outdoor room. The backdrops' generated cloud band `Plan4` and the Canyon's `HighClouds` (the high sky above the Pride
  Rock) now drift too (`autoscroll` −3).
- No script was needed: it's the built-in Parallax2D autoscroll. Layout is in `.tscn`.

## Tests
- `SampleProject/UI/verify_living_world.gd` — **RESULT: ALL PASS**. It checks:
  - each of the 6 rooms has `Front` with z above the player's highest z (20 > 1), scroll > 1, repeat, `depth_blur_front`
    and a texture, and the plane's first opaque pixel is not above the platform line;
  - the expected decor kinds are present in all 9 rooms and their phases and speeds differ;
  - each decor scene loops several frames and changes frame by itself in the tree;
  - every cloud layer in both backdrops and `HighClouds` has autoscroll + repeat + parallax < 1, and on screen it moved
    4–14 px in 1.5 s with no input.
- Full suite `Scripts/Tools/run_verify.sh`: see below.

SUITE_RESULT

## D-ID text for the register (another branch edits the register)
- **D-new (living world, BACKLOG 7 + 19):** Each outdoor room has one shared foreground plane
  (`foreground_plane.tscn`: Parallax2D ×1.25, z 20, `depth_blur_front`). Its art starts just below the hero's platform
  line, and only the tops show. City reuses `Gates/gen_front`. Decor idle loops (banner, palm, lamp, crystal, dust) are
  AnimatedSprite2D scenes in `Scenes/Backgrounds/Decor/`, placed per room with their own phase and speed. Clouds drift by
  Parallax2D `autoscroll` with wrap (`drifting_clouds.tscn` in both desert backdrops, plus `Plan4` and Canyon
  `HighClouds`). `verify_living_world.gd`.

## Triage of what the captures show
- **Visual issue — dust is very subtle.** The dust motes are 1–2 game pixels in sand/haze tones, so in Canyon and
  DesertRoad they read as a few specks. That is the art; it is correct by README and not a defect of the wiring.
  If it should read stronger, it is an art call (new B/Q for Sapega, not filed here because the registers are owned by
  another branch).
- **Visual issue — decor palms are brighter than the blurred backdrop palms.** They stand at parallax 1 next to the
  buildings, so they're sharp like the houses. This was not changed.
- The LaboratoryOutside and Laboratory captures land during their cutscenes, and the camera there is the cutscene's.
  That is expected.
- There's no Figma frame for in-world art, so there's nothing to compare against Figma.

## Not done / left
- Grass sway (BACKLOG 19 mentions "grass and palm fronds move"). There's no grass idle sheet in `Decor/`; only the
  palm fronds move.
- Decor positions were set by eye from captures. Sapega may want to move some.
