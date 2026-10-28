# Mesa top planes (M6b-2)

**AI-generated.** Made with `design/shots/candidates/m6b2/m6b2.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); the lookout was
cleaned with **Qwen-Image-Edit-2511** (Apache 2.0, its fire and hanging ropes removed). Brought down ×3 to the game's
pixel and a few colours (octree). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6b2_mesa_oasis.png` (frames 1–3).

The room (`Maps/MesaTop.tscn`): side branch, closed, 2 cells (1152 × 320 art = 1728 × 480 world), floor y 384 world
(art row 256), camera x 0…576 art, y fixed. The hero comes up from the Mesa Climb's top ledge through the cleft at the
east end (`ClimbDoorEntrance`, `mesa_cleft`, x 1560 — kept). On top: high above the desert, the plain far below with a
caravan on the road, the neighbouring mesas lower than this one, and the bandits' lookout tower (the camp on the dunes
and the ambush on the climb are theirs; it explains a chest up here). The graph draws Mesa top 4 screens wide; the
scene is 2 — every plane but the lookout is a seamless 576 tile, so a wider room needs no new art.

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge). Tiles: `repeat_size = (864, 0)`,
`repeat_times = 3`.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (new, as DesertRoad) with **Plan3 and Plan1 `visible = false`** | — | — | 0 / 0.1 | (0, −3) | the shared sky and clouds only |
| `Back/Far` (BanditCamp far) | `gen_far.png` | 576×324 | 0.2 | (0, −3) | the desert plain far below: horizon at row ~110 with low hazy mesas, dunes, a winding road with a tiny camel caravan; tile |
| `Back/Mid` (Road mid) → `Back/Buttes` | `gen_buttes.png` | 576×300 | 0.5 | (0, 132) | the neighbouring flat-topped red sandstone buttes, hazed 0.35; their tops at row ~175, below this mesa; tile |
| `Back/Lookout` (new Parallax2D ×0.9, one Sprite2D) | `gen_lookout.png` | 83×144 | 0.9 | (588, 171) | the bandits' lookout: lashed poles, a plank platform, a tattered red flag, a stone ring with cold ashes; 160 art (2.5 H, the tent's size) × 0.9 = 144 (D814), feet 2 art under the walk line; mid-screen when the camera is at 162 art |
| `Ground/Floor1` (BanditCamp floor) | `../MesaClimb/gen_floor.png` | 876×44 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 1152, 44)`, `texture_repeat = 2` | the same sandstone ledge as the climb; row 0 = the walk line. `Fill1` stays under it |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `OccluderRock1` | `../Canyon/gen_rock.png` | 156×114 | 1.3 | (1100, 520), `scale = (2.2, 2.2)`, centered | the D750 occluder, as on the climb; crosses mid-screen at camera x 514 world, clear of the cleft and the lookout |

Atmosphere for the room routine: wind-blown sand along the floor, a vulture circling far out (`critter_bird`).
