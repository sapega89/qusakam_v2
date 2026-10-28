# Rooftops planes (M6c-2)

**AI-generated.** Made with `design/shots/candidates/m6c2/m6c2.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). Brought down ×3 to
the game's pixel and a few colours (octree). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6c2_rooftops.png` (frames 1–3).

The room (`Maps/Rooftops.tscn`): side branch, 3 cells (1728 × 320 art = 2592 × 480 world) at [19,4], over the City Gate
(cells 19–20) and the market (cell 21); walls at both ends; floor y 384 world (art row 256), flat, camera x 0…1152 art,
y fixed. The hero runs on the flat roofs of one row of houses joined wall to wall: the walk line is their roof edge,
whole from end to end, nothing floats (A15). Around him, at roof level, the City's roofs: domes, a minaret, striped
canopies, laundry lines, carpets over the parapets, water jars, and the desert beyond (the rooftops are over the gate, at
the City's west edge). The market itself is a storey below the view and can't show in a side view at roof level.

Three passages, all painted, none cutting the floor (B201):
- **East, `LadderDoor` x 2400** — the top of the ladder from the market (`City/RooftopsDoor`, «драбина на стіні
  будинку»): 40 art above the roof edge, standing against the whole facade strip down to the bottom of the view.
- **Middle, `LoftDoor` x 1300** — the **dovecote** on the roof, its door boarded up: the boards are `Wall_Loft`'s
  picture (`gen_boards.png`); a heavy hit breaks them and the dark doorway behind leads into the Pigeon Loft. At the
  exact door (112 art) the tower is 432 art tall: it rises out of the view into the loft the map puts above it.
- **West, `SlideDoor` x 150** — the drop back to the City Gate («зіскочити до медитації брами»): a thick rope tied to a
  mooring post on the roof edge, hanging down the house wall out of the view.

## Shared planes continue the market

The Rooftops' left edge is X = −2 × 864 = −1728 world px from the market's (cells [21,5] → [19,4]); a shared plane with
factor f is shifted by −f × X (mod 864). Clouds autoscroll and need nothing.

| plane | factor | `scroll_offset.x` |
|---|---|---|
| `desert_backdrop_open.tscn` → Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 518.4 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera
at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` as the placeholder (5). Everything at ×1.0 or
behind goes under `Back` (z −10), so the roof strip covers the feet sunk below the walk line.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Sky`), offset above | — | — | 0–0.75 | (0, 0) | the market's sky, clouds and far mesas |
| `Back/Far` (`City/gen_far.png`) — **delete** | — | — | — | — | the City's skyline would stand behind the desert the new mid plane shows beyond the roofs |
| `Back/Mid` (`City/gen_near.png` ×0.8 → **×0.6**) | `gen_mid.png` | 576×180 | 0.6 | (0, 123); tile | the City's roofs at roof level: white domes, a minaret with a balcony, striped canopies on poles, laundry lines, carpets over parapets, big water jars, the desert beyond; hazed 0.3; its foot 6 art under the roof strip |
| `Back/Laundry` (new Parallax2D ×0.9, Sprite2Ds `Laundry1`, `Laundry2` with `flip_h = true`) | `gen_laundry.png` | 151×90 | 0.9 | (591, 252) and (1731, 252) | a line between two poles with a linen tunic, a sheet, a striped rug and trousers; poles 100 art × 0.9; mid-screen at camera 300 and 1000 art |
| `Back/Loft` (new Sprite2D, ×1.0) | `gen_loft.png` | 267×256 | 1.0 | (1102.5, 0) | the dovecote: mud brick, a whitewashed band, rows of pigeon holes with perches and painted pigeons; cut at the view's top. Its **door: opening 112 art centred on x 1300 world**, threshold on the walk line (the model's step and sand cut off, D830) |
| `Ground/Floor1` (`City_Terrain` → this; `texture_repeat` stays) | `gen_roof.png` | 576×64 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 1728, 64)` | the walk line: the roof's pale coping (row 0), round beam ends under it, the upper walls with arched shuttered windows, a lantern and a hung carpet; opaque to the room's bottom (`Fill1` stays, covered) |
| `Props` (new Node2D, `z_index = -8`: in front of the roof strip, behind the hero) / `Rope` | `gen_rope.png` | 19×112 | 1.0 | (135, 316.5) | the mooring post (46 art) on the roof edge at `SlideDoor`, its rope running down the wall to the view's bottom |
| `Props/Ladder` | `gen_ladder.png` | 25×104 | 1.0 | (2382, 324) | the ladder's top at `LadderDoor`: 40 art above the roof, foot at the room's bottom (also the Tavern Attic's) |
| `Wall_Loft/Sprite` (its `gen_rock` boulder) | `gen_boards.png` | 66×124 | 1.0 | `Wall_Loft` stays at (1300, 384); Sprite: `texture` this file, `scale = (1.5, 1.5)`, `offset = (0, -60)`, `centered` true, `z_index = -1` as now | weathered planks nailed over the dovecote's door, one hanging by a nail; covers the opening whole, bottom 2 art under the walk line |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Chimney1`, `Chimney2` (`flip_h = true`) | `gen_front.png` | 131×230 | 1.3 | (723, 189) and (2088, 189) | a sandstone chimney stack with a clay pot cowl, a cracked water jar, a coiled rope on a hook, darkened (D750); its foot below the view; mid-screen at camera 200 and 900 art, off screen at the rope (camera 0), the boarded door and the ladder (camera 1152) |

**The doors are painted.** Delete `LadderDoorEntrance`, `SlideDoorEntrance` and `LoftDoorEntrance` (placeholder
`door_elder` / `cave_mouth` art); `LadderDoor` → (2400, 322.5), `SlideDoor` → (150, 322.5), `LoftDoor` → (1300, 300)
(the painted door's centre; `cover` stays `Wall_Loft`). Add to `PAINTED` in `verify_room_entrances.gd`:
`"Rooftops/LadderDoor": "the ladder's top over the roof edge"`, `"Rooftops/SlideDoor": "the rope down the house wall"`,
`"Rooftops/LoftDoor": "the dovecote's boarded door"`.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes there
(the three doors' art becomes `None`), or take `Rooftops` out of its list once the scene is wired by hand. `python -B
design/shots/candidates/m6c2/m6c2.py wiring` prints these positions again.

Not in this slice: the other ends of the two ladders and the rope are in the market and at the gate (`City/RooftopsDoor`
x 880 and `City/TavernAtticDoor` x 2450 still show `door_elder`; `CityGates/RooftopsDoor` x 300 too) — City art.

Atmosphere for the room routine: pigeons on the roof edge and the dovecote's perches that fly off when the hero comes
near (`critter_pigeon`, [[ambient_critters_plan]]), the laundry and the rugs swaying in the wind, dust and a few
feathers drifting across, thin smoke from the chimney front; sound: wind, pigeons cooing, the market's murmur from
below (no sunbeams: D196).
