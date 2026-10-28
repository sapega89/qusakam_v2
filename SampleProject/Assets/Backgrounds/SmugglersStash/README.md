# Smugglers' Stash planes (M6b-6)

**AI-generated.** Made with `design/shots/candidates/m6b6/m6b6.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); two spots of the
wall were repainted by Qwen-Image (masked img2img: ropes on the pegs that came out as nooses, and floor sacks as tall
as the hero, D814). The goods are generated alone on a chroma key. Brought down ×3 to the game's pixel and a few
colours (octree). A Steam release has to disclose AI-generated content. Review: `design/shots/m6b6_canyon_floor.png`
(frame 6).

The room (`Maps/SmugglersStash.tscn`, «Схованка контрабандистів»): secret, **one cell** ([−1,6], 576 × 320 art =
864 × 480 world), floor y 384 world (art row 256), walls at both edges; the camera never moves. The smugglers' den
behind the cracked wall at the west end of the Canyon Floor: a small sandstone hollow with a timber prop beam, a
lantern in a niche, tally marks and a scratched map on the rock, a peg rail with a hanging sack, and their goods —
crates, sacks, an amphora, a strongbox, a rug and a lantern. (The game has no smugglers' lore yet; the room tells it
by its things. The grandfather's key opens the lizard shrine's gate, `gates.json` → `lizard_shrine`, not this
stash — the graph's red key label sits at the shrine.)

**The way out is the tunnel the wall painted** (D747): a dark passage at art 93…160 (dark core), ~100 art tall with
its rim, its floor on the walk line — the short tunnel back to the broken wall. So the exit moves from x 432 to the
tunnel's centre, **x 192 world**.

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. The camera stays at
x 0, so a plane is drawn exactly at its position.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (LizardCave far; no repeat) | `gen_wall.png` | 576×324 | — | (0, 0); opaque | the whole hollow including its sandy floor (the walk line lands on the sand; the floor's back edge is at art ~245) |
| `Back/Mid` (LizardCave wall) | — | — | — | — | **delete** |
| `Ground/Fill1`, `Ground/Floor1` | — | — | — | — | **delete**: the wall paints the floor |
| `Goods` (new Sprite2D, `z_index = -2`) | `gen_goods.png` | 120×80 | 1.0 | (405, 267) | the smuggled goods: two tiers of crates (32–40 art), a burlap sack, an amphora, a strongbox, a rug, a lantern on top; centred on art 330, 2 art under the walk line; between the tunnel and the secret's corner |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `Stalactites` | `../BridgeCave/gen_front.png` | 245×91 | 1.3 | (496.5, 0) | stalactites hanging into the top right, darkened (D750; the same cave sandstone); clear of the tunnel and the goods |

**Doors:** delete `ExitDoorEntrance` (the cave mouth); `ExitDoor` → (192, 330); `Arrival` → (192, 344). Add to
`PAINTED` in `verify_room_entrances.gd`: `"SmugglersStash/ExitDoor": "the dark tunnel back to the broken wall"`.
`SecretArea_Stash` (640, 336) stays: the corner with the peg rail and the hanging sack. In the generator:
`doors=[("ExitDoor", 0, 192, …)]`, `arrival=(0, 192)`.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in
the generator, or take `SmugglersStash` out of its list once the scene is wired by hand.

Atmosphere for the room routine: the lantern's warm flicker (a soft pulsing light on the niche), dust motes in it,
a draught from the tunnel; no critters on the goods (they must not be mistaken for a pickup).
