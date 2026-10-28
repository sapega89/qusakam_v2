# Canyon Floor planes (M6b-6)

**AI-generated.** Made with `design/shots/candidates/m6b6/m6b6.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). The dead-end
cliff and the cave mouth are img2img over guides the script draws (the outline and the openings are the script's;
the rock under the guide is the Cave under the Bridge's sandstone, `m6b1_cave_rock_raw.png`); brick patches the model
added were repainted by Qwen-Image (masked). The hole in the floor was repainted by Qwen-Image over the room's own
picture (masked img2img). Brought down ×3 (×2 for the guides) to the game's pixel and a few colours (octree); the far
wall and the rocks are darkened toward violet (the bottom of a deep canyon is in shade). A Steam release has to
disclose AI-generated content. Review: `design/shots/m6b6_canyon_floor.png` (frames 1–4).

The room (`Maps/CanyonFloor.tscn`, «Дно каньйону»): 4 cells (2304 × 320 art = 3456 × 480 world), floor y 384 world
(art row 256), camera x 0…1728 art, y fixed. The bottom of the canyon of whispers, deep under the start: towering
layered sandstone walls, fallen boulders and dead thorn bushes, and the smugglers' way along it — an abandoned
handcart with sacks. Its passages, all painted (D747):

- **West end** — the room's wall: a dead-end cliff (`gen_cliff.png`). In it, at **x 300 world**, a tall natural
  crack: the way into the **Smugglers' Stash**. The smugglers walled it up with stacked stones and mud plaster, now
  cracked — the **cracked wall** is its own sprite (`gen_cracked.png`), the BreakableWall's picture; when it breaks,
  the crack behind it stands open (frame 2 of the sheet).
- **The hole at 2912…3104 world** (art 1941…2069, the `Foreground` gap, tiles 91…96) — broken through the floor
  into the **Lizard Caves** below ([2,6]; D834: «the canyon floor's east end into the lizard caves»). Painted in
  `gen_ground.png`: broken sandstone edges with roots round a dark void. (The m6 brief called it «a hole down to the
  cave exit»; the scene's drop goes to the lizard caves, the cave exit is through the east edge.)
- **East edge** — open into the **Cave Exit** ([3,5]): a big cave mouth in the cliff, its opening reaching x 3456
  (`gen_mouth.png`).

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false` unless noted. A
Parallax2D plane with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold
with the camera at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times = 6`.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (BanditCamp far; ×0.4 → ×0.45, `repeat_size` 1728 → 864) | `gen_far.png` | 576×324 | 0.45 | (0, 0); tile, opaque | the far canyon walls: tall layered sandstone buttresses with deep cracks, a strip of pale sky between them, dark and violet |
| `Back/Mid` (Road mid; ×0.8 → ×0.75) | `gen_mid.png` | 576×200 | 0.75 | (0, 204); tile | fallen boulders, broken slabs and dead thorn bushes in groups with wide gaps, on the canyon's bedrock; its bottom rows sit under the floor |
| `Back/Cart` (new Parallax2D ×0.9, one Sprite2D) | `gen_cart.png` | 107×58 | 0.9 | (1314, 301.5) | the smugglers' abandoned handcart with sacks, a broken wheel and a cracked jar; 1 H (64) × 0.9 = 58 (D814); mid-screen at camera 700 art (1050 world) |
| `Cliff` (new Sprite2D, `z_index = -2`) | `gen_cliff.png` | 576×264 | 1.0 | (0, 0) | the dead-end cliff, opaque on x 0…348 art (0…522 world), foot on the walk line; the **crack** centred on **x 300 world**: 50 art wide (262…338 world) at the floor, straight sides to ~70 art up, then a pointed top at art row 146 (world y 219; 112 art = a door, D814), and a fissure running on up the cliff |
| `Mouth` (new Sprite2D, `z_index = -2`) | `gen_mouth.png` | 576×264 | 1.0 | (2592, 0) | the cliff at the east end, opaque from art 405 of the image (world 3200); the cave mouth from world 3312 to the edge, its top at art rows 106–146 (world 159–219), dark inside |
| `Wall_Stash/Sprite` (its `gen_rock` boulder) | `gen_cracked.png` | 160×124 | 1.0 | `Wall_Stash` stays at (300, 384); Sprite: `texture` this file, `scale = (1.5, 1.5)`, `offset = (0, -60)`, `centered` true (default), `z_index = -1` as now | the walled-up crack: stacked stones and mud plaster with a jagged crack from top to bottom, fallen chips at its foot; 124 art tall, bottom 2 art under the walk line; covers the crack whole |
| `Ground/Floor` (new; replaces `Fill1`, `Floor1`, `Fill2`, `Floor2`) | `gen_ground.png` | 2304×64 | 1.0 | (0, 384), no region, no repeat | the rocky canyon floor (the Mountain Path's ground, same rock, row 0 = the walk line) for the whole room in one strip, the **hole** painted at art 1935…2075 (no ground line across it); opaque to the room's bottom |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Rock1`, `Rock2` (`flip_h = true`) | `../MountainPath/gen_front.png` | 193×212 | 1.3 | (1281, 228) and (2646, 228) | the canyon's dark rock spire with a dead tree (D750, the same occluder as the path and the scree), foot ~40 art below the view; mid-screen at camera 500 and 1200 art; off screen at camera 0 (the crack) and ≥ 1700 (the hole, the mouth) |

**The stash door is a painted opening.** Delete `StashDoorEntrance` (the cave mouth), move `StashDoor` to x **300**
(the crack's centre; y 330 stays; `cover` stays `Wall_Stash`), and add to `PAINTED` in `verify_room_entrances.gd`:
`"CanyonFloor/StashDoor": "the smugglers' crack in the dead-end cliff"`.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in
the generator (CanyonFloor's `doors` art and the `covers` sprite), or take `CanyonFloor` out of its list once the
scene is wired by hand.

Atmosphere for the room routine: sand trickling down the cliffs in thin streams, dust motes in the pale light from
the strip of sky, a cold draught (drifting dust) out of the hole and the cave mouth, a bat at the mouth
(`critter_bat`, D774).
