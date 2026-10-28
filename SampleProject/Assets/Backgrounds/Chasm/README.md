# Chasm planes (M6b-4)

**AI-generated.** Made with `design/shots/candidates/m6b4/m6b4.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). The abyss between
the lips was painted by Qwen-Image over the room's own composition (masked img2img on a dark underpainting). Brought
down ×3 to the game's pixel and a few colours (octree). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6b4_chasm_riverbed.png` (frames 1–2).

The room (`Maps/Chasm.tscn`): main road, **one screen** (576 × 320 art = 864 × 480 world), open both ways: west the
Dunes, east the Gate Approach. The camera never moves, so every plane is one fixed composition (no seam) and the
parallax factors below only set depth and order. Floor y 384 world (art row 256) on two lips: west 0…160 world, east
704…864 world; between them the road is cut by the chasm (the hero falls into the Dry Riverbed below). The way across
is the **drawbridge** (`Bridge`, `FlagBridge.gd`): hinged on the east lip at (720, 384), span 144…720 world, raised
(standing upright, π/2) until `GateApproach/BridgeLever` sets `chasm_bridge_down`. The City is the goal beyond the
chasm: its walls and towers peek over the dunes.

## The road stays anchored to the world

As in the Dunes (`Dunes/README.md`): the Chasm's left edge is X = 12 × 864 = 10368 world px right of the Desert
Road's (cells [4,5] → [16,5]) and 4 × 864 = 3456 right of the Dunes' ([12,5]), so a shared plane with factor f is
shifted by −f × X (mod its 864 repeat). Clouds autoscroll and need nothing.

| plane | factor | `scroll_offset.x` |
|---|---|---|
| `desert_backdrop_open.tscn` → Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 345.6 |
| `desert_backdrop_open.tscn` → Plan1 (pack ground strip; hidden under the floor) | 0.75 | 0 |
| `Back/Dunes` (`Dunes/gen_dunes.png`) | 0.5 | 0 |
| `Back/Near` (`Dunes/gen_near.png`) | 0.8 | 691.2 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. The camera stays at
x 0, so a plane is drawn exactly at its position.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Far`), offsets above | — | — | 0–0.75 | (0, −3) | the road's sky, clouds and far mesas, continuing |
| `Back/City` (new Parallax2D ×0.4, one Sprite2D) | `gen_city.png` | 262×115 | 0.4 | (433.5, 69) | the City far away: walls with square towers, the gatehouse, domes and the palace tower, red banners; walls two storeys (288) × 0.4 = 115 (D814); hazed 0.35; its foot sinks behind the dune sea |
| `Back/Mid` (Road mid) → `Back/Dunes` (×0.8 → ×0.5) | `Dunes/gen_dunes.png` | 576×240 | 0.5 | (0, 105); tile | the Dunes' dune sea, continuing |
| `Back/Near` (new Parallax2D ×0.8) | `Dunes/gen_near.png` | 576×120 | 0.8 | (0, 225); tile | the Dunes' low crests, continuing |
| `Ground/Chasm` (replaces `Fill1`, `Floor1`, `Fill2`, `Floor2`) | `gen_ground.png` | 576×64 | 1.0 | (0, 384), no region | both lips in the Dunes' ground (rippled sand over orange strata) and, between them (art 107…469), the abyss: broken sandstone cliff faces, dry roots, the far wall fading to black; row 0 = the walk line, opaque to the room's bottom; no ground line crosses the gap |
| `Bridge/Plank` (texture `Canyon/gen_bridge.png` → this) | `gen_bridge.png` | 384×28 | 1.0 | node (720, 384); Plank `scale = (1.5, 1.5)`, `offset = (−384, 0)`, `region_enabled = false` | the drawbridge: heavy timber deck on squared beams with iron plates and bolts, the hinge bracket at its east end; row 0 is the deck top, so lowered it lies exactly on the collision (144…720, top y 384); `FlagBridge` turns it π/2 → it stands up on the east lip, x 678…720 world, top at y −192 (out of view); no hand-rail (raised, its posts read as a ladder) |
| `Winch` (new Sprite2D, `z_index = -2`) | `gen_winch.png` | 105×96 | 1.0 | (714, 243) | the bridge winch on the east lip: two timber posts, a drum with an iron chain, a crank; the chain runs off east toward the lever in the Gate Approach; a man's height (96, 1.5 H) |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `Spur` | `gen_front.png` | 181×150 | 1.3 | (315, 393) | a jagged rock spur with a dead root rising out of the abyss, darkened by `FrontDark`'s modulate (D750); its tip stays below the deck; never over the Arrival (x 80) or the east lip |

`Bridge/CollisionShape2D`, `Arrival`, `ObjectiveTargets`, `RoomInstance` and `Music` stay as they are.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in
the generator (its `bridge()` writes `Plank` with `Canyon/gen_bridge.png` at 1:1 and a 576×46 region — change it to
this texture, `scale` and `offset`), or take `Chasm` out of its list once the scene is wired by hand. The Canyon keeps
its own rope bridge (`Canyon/gen_bridge.png`).

Atmosphere for the room routine: sand trickling over both lips into the abyss, dust blown along the road, a vulture
circling high (`critter_bird`), a faint draught of dust rising from the dark.
