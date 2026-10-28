# Palace Square planes (M6c-1)

**AI-generated.** Made with `design/shots/candidates/m6c1/m6c1.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). Brought down ×3 to
the game's pixel and a few colours (octree). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6c1_craft_palace.png` (frames 5–7).

The room (`Maps/PalaceSquare.tscn`): main street's end, 2 cells (1152 × 320 art = 1728 × 480 world), open west to the
Craft Quarter, a wall east; floor y 384 world (art row 256), flat, camera x 0…576 art, y fixed. The Mayor's palace
closes the square: its front at the east end with the door between the two gate guards (`MayorHallDoor` x 1560,
`GuardLeft` 1500, `GuardRight` 1620 — world-rooms' D836). Before it, the palace's outer wing with an arcade and red
banners (plain golden disc until the coat of arms is decided, Q57), and the square's fountain: a stone dragon on a
column pouring water into a bowl and a knee-high basin. The aqueduct that fed the City ends here, and its spout is a
dragon's head like the Aqueduct's (lore: dragons «like deities», the ancient builders' sign); the mayor's fountain
still runs while the market drinks from a well.

## The street continues the market

The Palace Square's left edge is X = 6 × 864 = 5184 world px right of the market's (cells [21,5] → [27,5]); shared
planes are shifted by −f × X (mod 864). Clouds autoscroll and need nothing.

| plane | factor | `scroll_offset.x` |
|---|---|---|
| `desert_backdrop_open.tscn` → Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 172.8 |
| `Back/Far` = the market's `CityFar` (`City/gen_far.png`, the skyline) | 0.4 | 518.4 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge). Tiles: `repeat_size = (864, 0)`,
`repeat_times` as the placeholder (4). Everything at ×1.0 or behind goes under `Back` (z −10).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Sky`), offset above | — | — | 0–0.75 | (0, 0) | the market's sky, clouds and far mesas, continuing |
| `Back/Far` (keep `City/gen_far.png`; as the market's `CityFar`: `region_rect = Rect2(0, 48, 576, 276)`, `offset = (0, 48)`, `depth_blur_mid`), offset above | `City/gen_far.png` | 576×324 | 0.4 | (0, 0); tile | the City's towers and domes, continuing |
| `Back/Mid` (×0.8 → **×0.6**) | `gen_mid.png` | 576×220 | 0.6 | (0, 79.5); tile | the palace's outer wing: an arcade of pointed arches on slender columns, an upper storey with screened windows, a crenellated parapet with red banners; hazed 0.25. Its arches measure 67 art = 112 × 0.6 (D814) |
| `Back/Fountain` (new Parallax2D ×0.9, one Sprite2D) | `gen_fountain.png` | 133×158 | 0.9 | (630, 151.5) | the dragon fountain: 176 art with the dragon (1.2 storeys) × 0.9, the basin 32 × 0.9 (knee-high to an adult); mid-screen at camera 220 art (330 world), clear of the Arrival and the door |
| `Back/Palace` (new Sprite2D, replaces `MayorHallDoorEntrance`) | `gen_palace.png` | 258×324 | 1.0 | (1366.5, −102) | the palace front: two slender towers, a carved central block with a balcony and screened windows rising out of the view, two red banners, a closed double door of dark studded wood under a pointed arch — **door 112 art centred on x 1560 world**, threshold on the walk line (the model's steps and path were cut off: no steps, D830). Its right 16 art lie beyond the east wall (x 1728), never seen |
| `Ground/Floor1` (keep) | `Terrain/City_Terrain.png` | — | 1.0 | (0, 384), `region_rect = Rect2(0, 256, 1152, 43)` | the market's cobbles, continuing |
| `FrontDark` = `foreground_dark.tscn` (new) + `palm.tscn` instance `OccluderPalm` (`scale = (3, 3)`, as the market's) | `Decor/palm/palm_sheet.png` | 56×70 frame | 1.3 | (1017, 520) | the market's swaying palm, darkened (D750); mid-screen at camera 300 art, off-screen when the camera is at the door (east end) or the Arrival |

**The door is a painted opening.** Delete `MayorHallDoorEntrance` (the `palace_door` sheet, 74-art opening — A12's
undersized door), add `Back/Palace`, keep `MayorHallDoor` (1560, 300) — the painted door's centre is (1560, 300) —
and the guards where they stand (their 96-art frames flank the 112-art door, in the sheet's frame 7). Add
`"PalaceSquare/MayorHallDoor": "the palace's painted double door"` to `PAINTED` in `verify_room_entrances.gd`.

**The alley down** (graph: «провулок ↓» to the East Gate, closed until after the Laboratory) is not in the map yet
(world-rooms: the East Gate is not built); no art for it here. When it comes, it is a door art of its own west of the
fountain.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in the
generator (the `palace_door` art of `MayorHallDoor` becomes the painted palace), or take `PalaceSquare` out of its list
once the scene is wired by hand. `python -B design/shots/candidates/m6c1/m6c1.py wiring` prints these positions again.

Atmosphere for the room routine: pigeons around the fountain's basin (`critter_pigeon`), droplets glinting where the
stream falls into the bowl and the basin, the banners swaying (`Decor/banner.tscn`), dust drifting in the light over
the paving (no sunbeams: D196), a cool shimmer of spray by the fountain; sound: running water, the guards' spears
shifting.
