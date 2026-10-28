# Zahra's Rest planes (M6b-2)

**AI-generated.** Made with `design/shots/candidates/m6b2/m6b2.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); the camp was
cleaned with **Qwen-Image-Edit-2511** (Apache 2.0, the sand platform under it removed). Brought down ×3 to the game's
pixel and a few colours (octree). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6b2_mesa_oasis.png` (frames 4–6).

The room (`Maps/ZahraRest.tscn`): the oasis stop on the main road, 2 cells (1152 × 320 art = 1728 × 480 world), open
both ways — west the Desert Road, east the Dunes; floor y 384 world (art row 256), camera x 0…576 art, y fixed. The
well at x 900 world (`WellDoor`, gate `ruins_well`) goes down into the Old Ruins: an old round well of ancient carved
blocks with green water stains (the chief's key is «green with old water»), a rusty iron grate with a padlock on its
mouth and a winch above. Around it: a pool with reeds and date palms, half-buried ruins of what lies below (a fallen
arch, broken columns), a nomads' resting place under a striped awning.

## The road stays anchored to the world

The far planes continue the Desert Road's (as `MountainPath/README.md`): Zahra's Rest's left edge is X = 6 × 864 =
5184 world px right of the road's (cells [4,5] → [10,5]), so a shared plane with factor f is shifted by −f × X
(mod its 864 repeat). Clouds autoscroll and need nothing.

| shared plane (`desert_backdrop_open.tscn`) | factor | `scroll_offset.x` |
|---|---|---|
| Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 172.8 |
| Plan1 (pack ground strip, under the floor) | 0.75 | 432 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Far`), offsets above | — | — | 0–0.75 | (0, −3) | the road's sky, clouds and far mesas, continuing |
| `Back/Mid` (Road mid) | `gen_mid.png` | 507×250 | 0.6 | (0, 25.5); `repeat_size = (760.5, 0)`, `repeat_times = 4`; material `depth_blur_near` as the road's mid | the oasis: pool with reeds, date palms, ruins; scaled so its tallest palm is 154 art = 256 × 0.6 (D814); the pool shows above the walk line; tile |
| `Back/Camp` (new Parallax2D ×0.85, one Sprite2D) | `gen_camp.png` | 175×136 | 0.85 | (183, 189) | the resting place: striped awning on poles, rug, cushions, jars, sacks, a saddle on a rail; 160 art (tent) × 0.85 = 136; near the west arrival |
| `Back/Palm` (new Parallax2D ×0.9) | `gen_palm.png` | 161×230 | 0.9 | (930, 43.5) | a date palm with dates, 256 × 0.9 = 230 art; right of the well when the hero is at it |
| `Well` (new Sprite2D, `z_index = -2`; replaces `WellDoorEntrance`) | `gen_well.png` | 97×112 | 1.0 | (828, 219) | the well: 112 art (a passage = a door, D814), feet 2 art under the walk line, centre x 900.75 world |
| `Ground/Floor1` (BanditCamp floor) | `gen_ground.png` | 576×67 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 1152, 67)`, `texture_repeat = 2` | packed sand with grass tufts and pebbles over orange strata, the road terrain's look; row 0 = the walk line; covers to the room's bottom (`Fill1` may go) |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `Reeds` | `gen_front.png` | 192×150 | 1.3 | (1684.5, 219), scale 1.5, `centered = false` | reeds, cattails and a low palm, darkened by `FrontDark`'s modulate (D750); passes through the east screen, never near the well or the west arrival |

**The well is a painted opening.** `RoomEntrance.OPENINGS` knows only door-like arts, so the well is a plain sprite:
delete `WellDoorEntrance`, add `"ZahraRest/WellDoor": "the stone well with its iron grate"` to `PAINTED` in
`verify_room_entrances.gd`, and move `WellDoor` to x 900 (was 891, the cave mouth's opening).

Atmosphere for the room routine: dragonflies and butterflies over the pool, pollen (`atmo_pollen`), a glint on the
water.
