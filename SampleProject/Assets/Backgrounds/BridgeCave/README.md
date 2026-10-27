# Cave under the bridge planes (M6b-1)

**AI-generated.** Made with `design/shots/candidates/m6b1/m6b1.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0): the wall is an
img2img over a drawn guide whose rock is a separate sandstone generation, so its outline is the script's, not the
model's; the floor strip is `../LizardCave/gen_floor.png` (the Lizard Cave is a side tunnel of this cave, same
sandstone). Props generated alone on a chroma key, brought to exact art heights (D814) in the wall's palette. A Steam
release has to disclose AI-generated content. Review: `design/shots/m6b1_cave_attic.png`.

The room: underground, 1 × 3 cells (576 × 960 art = 864 × 1440 world), under the Bridge. The hero drops in from the
Bridge through the **cave mouth** in the ceiling (top left: daylight and the bridge's underside), lands on the top
shelf, falls off its east end onto the middle shelf, off its west end onto the floor, and goes on **down through the
pit** in the floor (bottom left) to the cave exit room below. Both falls are 320 art (480 world): no way back up the
first time («вперше — лише вниз»). End-game: two rope ladders are lowered on the falls (`gen_ladder.png`, hidden until
the flag). Camera: x fixed (one screen wide), y 0 (top) to 636 art (954 world).

## Collision (`gen_wall.png` is opaque exactly on the rock)

| piece | art x | art top y | world x | world top y |
|---|---|---|---|---|
| top shelf (walk line) | 0–330 | 277 | 0–495 | 416 |
| middle shelf | 246–576 | 597 | 369–864 | 896 |
| floor | 0–60, 150–576 | 917 | 0–90, 225–864 | 1376 |
| pit (exit down) | 60–150 | — | 90–225 | — |
| cave mouth (entry from the Bridge, open) | 70–210 at the top | — | 105–315 | — |

Side walls ~26 art (39 world) thick, ceiling ~58 art (87 world), both ragged ±9 art; shelves are 46–76 art thick
(wedge, thickest at the wall). Walk edges carry a 1-row light lip.

## Planes, back to front

Art px, room-local; scale 1.5; scroll factor on y only. A plane with factor f is drawn at anchor − f × camera
(camera = view top, 0…636 art).

| file | size | factor | anchor (x, y) | what |
|---|---|---|---|---|
| `gen_far.png` | 576×648 | 0.5 | (0, 0) | the dark depths of the cave: rock columns, stalactites, glowing blue mushrooms, a crack of light; no transparency |
| `gen_wall.png` | 576×960 | 1.0 | (0, 0) | rock walls, ceiling, shelves, floor, the mouth with sky and the bridge; the air is transparent |
| `gen_waymark.png` | 58×56 | 0.9 | (236, 223) | the shaman family's waymark: a standing stone with a carved lizard and prayer cloths, an offering bowl; stands on the top shelf at camera 0 |
| `gen_ladder.png` | 34×332 | 1.0 | (292, 265) and (250, 585) | end-game only: rope ladder, hooks 12 art above the shelf lip; 1 = top shelf east edge → middle shelf, 2 = middle shelf west edge → floor |
| `gen_front.png` | 245×91 | 1.3 | (400, 0) | foreground (D774): stalactites hanging into the top frame at the right, shaded dark; leaves the view as the camera goes down |

Atmosphere for the room routine: dust in the light under the mouth, glinting drips, a few glowing spores near the
floor (the far plane's mushrooms).
