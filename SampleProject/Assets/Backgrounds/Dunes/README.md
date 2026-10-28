# Dunes planes (M6b-3)

**AI-generated.** Made with `design/shots/candidates/m6b3/m6b3.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); the trailhead and
the dune were cleaned with **Qwen-Image-Edit-2511** (Apache 2.0: a stone doorway behind the poles, a sentry on the
crest and the distant dunes removed). Brought down ×3 to the game's pixel and a few colours (octree). A Steam release
has to disclose AI-generated content. Review: `design/shots/m6b3_dunes_ruins.png` (frames 1–4).

The room (`Maps/Dunes.tscn`): main road, 4 cells (2304 × 320 art = 3456 × 480 world), open both ways: west Zahra's
Rest, east the Chasm; floor y 384 world (art row 256), flat (D830), camera x 0…1728 art, y fixed. The bandits' land:
their warning post near the west end, and in the 3rd–4th screen (graph: «стежка на дюни») the **trailhead of the path up
to the bandit camp** at x 2700 world. The camp is two cells up on the map (`BanditCamp` [12,3]), so the picture shows a
big dune with the staked path climbing its face out of the top of the view, not the camp itself (its palisade at
×0.85 would be 109 art, and on top of a dune that fits the view it came out toy-sized). The Old Ruins lie right under
these dunes (cells [11…15,7]): a colossal stone head of their statues sticks out of the sand.

## The road stays anchored to the world

The far planes continue Zahra's Rest's and the Desert Road's (as `MountainPath/README.md`): the Dunes' left edge is
X = 8 × 864 = 6912 world px right of the road's (cells [4,5] → [12,5]), so a shared plane with factor f is shifted by
−f × X (mod its 864 repeat). Clouds autoscroll and need nothing.

| shared plane (`desert_backdrop_open.tscn`) | factor | `scroll_offset.x` |
|---|---|---|
| Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 518.4 |
| Plan1 (pack ground strip, under the floor) | 0.75 | 0 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera
at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` as the placeholder (6).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Far`), offsets above | — | — | 0–0.75 | (0, −3) | the road's sky, clouds and far mesas, continuing |
| `Back/Mid` (Road mid) → `Back/Dunes` | `gen_dunes.png` | 576×240 | 0.5 | (0, 105); tile | dry dune sea, crests in rows ~110–150 of the view, hazed 0.3 |
| `Back/Colossus` (new Parallax2D ×0.6, one Sprite2D) | `gen_colossus.png` | 178×154 | 0.6 | (991.5, 132) | the stone head of an ancient statue buried to the chin, a crown with a coiled winged dragon (lore: ruins of an ancient civilisation, dragons «like deities»); 4 H above the sand (256) × 0.6 = 154 (D814); its foot sinks behind the near dunes; mid-screen at camera 560 |
| `Back/Near` (new Parallax2D ×0.8) | `gen_near.png` | 576×120 | 0.8 | (0, 225); tile | low dune crests with dry tufts just above the walk line, hazed 0.1 |
| `Back/Slope` (new Parallax2D ×0.85, one Sprite2D) | `gen_slope.png` | 614×236 | 0.85 | (1498.5, 45) | the big dune: a shadowed face on the left, a staked path with red rags and a rope rail climbing it to the crest at the view's top; its foot ends 40 art right of the trailhead when the trailhead is mid-screen |
| `Back/Stake` (new Parallax2D ×0.9) | `gen_stake.png` | 77×115 | 0.9 | (603, 216) | the bandits' warning post: a crooked pole, a horned lizard skull, red rags, hanging bones; 2 H (128, a gate) × 0.9 = 115; clear of the Arrival (x 200) |
| `CampTrail` (new Sprite2D, `z_index = -2`, the painted passage) | `gen_trailhead.png` | 109×112 | 1.0 | (2619, 219) | the trailhead: two lashed poles with a crossbar, red cloth, a rope coil, a blank plank, stakes; 112 art (a passage = a door, D814), feet 2 art under the walk line, centre x 2700 world |
| `Ground/Floor1` (BanditCamp floor) | `gen_ground.png` | 576×64 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 2304, 64)`, `texture_repeat = 2` | loose rippled sand over the same orange strata as Zahra's Rest's ground; row 0 = the walk line; covers to the room's bottom (`Fill1` may go) |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Thorn1`, `Thorn2` | `gen_front.png` | 160×150 | 1.3 | (1131, 279) and (2554.5, 279) | a dead thorn bush with a horned skull, darkened by `FrontDark`'s modulate (D750); foot below the view; crosses mid-screen at camera 420 and 1150 art (630 / 1725 world), never over the Arrival or the trailhead |

**The camp path is a painted passage, wired later.** The camp still opens off the Desert Road (world-rooms Q-a): when
it moves here, add `CampDoor` (`room_door.tscn`) at (2700, 334.5) with `target_room = BanditCamp.tscn`, its arrival the
camp's door that faces the dunes, and `"Dunes/CampDoor": "the bandits' trailhead"` to `PAINTED` in
`verify_room_entrances.gd` (like the well at Zahra's Rest). `RoomEntrance.OPENINGS` is not needed: the trailhead is a
plain sprite.

Atmosphere for the room routine: sand blown off the crests and along the floor, a vulture circling far out
(`critter_bird`), a thin smoke thread rising behind the big dune's crest (the camp above).
