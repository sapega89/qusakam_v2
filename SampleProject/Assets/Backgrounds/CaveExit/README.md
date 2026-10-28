# Cave Exit planes (M6b-6)

**AI-generated.** Made with `design/shots/candidates/m6b6/m6b6.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). The cave wall
is img2img over a guide the script draws (outline, ceiling hole and the mouth's edge are the script's; the rock under
the guide is the Cave under the Bridge's sandstone). The rubble is generated alone on a chroma key. Brought down ×2
(×3 for the rubble) to the game's pixel and a few colours (octree), darkened for depth. The far plane is composed from
planes already in the game: the depths of the Cave under the Bridge (`../BridgeCave/gen_far.png`, its bottom 324 rows)
and the Desert Road's sky, clouds and mesas (`../DesertOasis/bg4/plan5.png`, `../Canyon/gen_clouds.png`,
`../Canyon/gen_far.png`). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6b6_canyon_floor.png` (frame 5).

The room (`Maps/CaveExit.tscn`, «Вихід з печери»): **one cell** ([3,5], 576 × 320 art = 864 × 480 world), floor y 384
world (art row 256); the camera never moves, so every plane is one fixed composition. A low wide chamber at the foot
of the Cave under the Bridge, the same sandstone. Its passages, all painted (D747):

- **The ceiling hole at art 60…150 (world 90…225)** — the bottom of the **pit** of the Cave under the Bridge
  (`../BridgeCave/README.md`: «pit (exit down) 60–150 art, 90–225 world»), where the hero drops in. Dark above (the
  cave), broken rock with drips round it; under it a low mound of fallen rubble and sand with broken planks and a
  snapped rope end (`gen_rubble.png`): things fell this way before, and nothing climbs back (D834). **Note:** the
  generator's `CaveUnderBridge` today has its bottom hole at 320…544 world (`holes=[…, (2, 320, 544)]`), not at the
  art's 90…225; when the Cave under the Bridge is wired to its art, its holes follow the art's collision table, and
  this hole is right. If the cave keeps 320…544, change `CE_PIT` in `m6b6.py` and regenerate `ce_wall` (one
  generation).
- **West edge** — open: the chamber runs on into the dark as a tunnel toward the Canyon Floor (whose east edge paints
  the same passage as a cave mouth in the cliff).
- **East edge** — open: the cave's mouth onto the Desert Road. Right of the mouth's edge (a curtain of rock from the
  ceiling to the floor at art ~350…470) the desert shows: the road's sky, clouds and mesas, anchored as the road's
  (CaveExit is one cell west of `DesertRoad`).

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. The camera stays at
x 0, so a plane is drawn exactly at its position; no plane needs a repeat (`repeat_size` 0).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (LizardCave far; ×0.4 → any, no repeat) | `gen_far.png` | 576×324 | — | (0, 0); opaque | left of the mouth's edge: the dark depths of the cave above (rock columns, glowing blue mushrooms); right of it: the desert in daylight |
| `Back/Mid` (LizardCave wall) → `Back/Wall` (×0.8 → ×1.0, no repeat) | `gen_wall.png` | 576×264 | 1.0 | (0, 0) | the ragged ceiling (~64 art deep) with short stalactites and the **hole** at art 60…150, and the rock curtain of the mouth's edge reaching the floor at art ~440…470 (world 660…705); the air is transparent; foot on the walk line |
| `Rubble` (new Sprite2D, `z_index = -2`) | `gen_rubble.png` | 95×26 | 1.0 | (87, 348) | the low mound under the hole: rubble, sand, broken planks, a snapped rope end; centred on the hole (x 158 world), 2 art under the walk line |
| `Ground/Fill1`, `Ground/Floor1` | `../LizardCave/gen_floor.png` | 576×49 | 1.0 | as now | the flagstone floor of the Lizard Cave / the Cave under the Bridge (same sandstone), unchanged |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `Stalactites` | `../BridgeCave/gen_front.png` | 245×91 | 1.3 | (496.5, 0) | stalactites hanging into the top of the frame over the mouth, darkened by `FrontDark` (D750); clear of the hole and the fall |

`Arrival`, `ObjectiveTargets`, `RoomInstance`, `Music` and the `Foreground` tiles stay as they are.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in
the generator, or take `CaveExit` out of its list once the scene is wired by hand.

Atmosphere for the room routine: a pale shaft of dust falling from the hole onto the rubble (where the hero lands),
warm daylight and drifting sand blowing in through the mouth, a few glowing spores in the dark west half, drips that
glint.
