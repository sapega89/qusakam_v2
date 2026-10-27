# Rock Ledges planes (M6a-2b)

**AI-generated.** Made with `design/shots/candidates/ledges_planes/ledges_planes.py` on top of
`Scripts/Tools/comfy_backdrop.py` (layer `RockLedges/gen_plume`), using **Qwen-Image** (Alibaba Qwen, Apache 2.0) and
the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0): the far wall is outpainted to the right of the Stream Gorge's
wall, the cliff is painted over a drawn guide (img2img), the burnt houses are the Village's `gen_houses.png` repainted
"after the fire" (img2img, denoise 0.6). The outline of the ledges, the cascade and the bank's pixels are the
script's, not the model's. A Steam release has to disclose AI-generated content.

The room: outdoor, main road, the last room before the village, 1 × 2 cells (864 × 960 world, 576 × 640 art). Its left
edge is 3456 art (5184 world) east of the Mountain Path's left edge, its top at the path's top (y 0), i.e. its lower
cell is east of the gorge. The hero comes off the gorge bank at the bottom left, jumps up the ledges and leaves east at
the top into the burnt village. Camera: x fixed (the room is one screen wide), y 0 (top) to 316 (bottom, as in the
gorge). Review: `design/shots/m6a2b_ledges.png`.

## The ledges — collision (world px, room-local)

`gen_ledges.png` is opaque exactly under this outline; each ledge runs from its x to the next ledge's x, the risers are
vertical. Steps 48–81 world px, each one jump (the hero jumps ~103 px):

| ledge | x from | x to | top y |
|---|---|---|---|
| floor (bank, from the gorge) | 0 | 195 | 896 |
| 1 | 195 | 276 | 832 |
| 2 | 276 | 351 | 752 |
| 3 | 351 | 426 | 688 |
| 4 | 426 | 501 | 608 |
| 5 | 501 | 576 | 528 |
| 6 | 576 | 645 | 464 |
| plateau (exit east) | 645 | 864 | 416 |

(Art px: x 0/130/184/234/284/334/384/430, tops 597/555/501/459/405/352/309/277.) The walk lines match the road: 896 at
the bottom (the gorge's 416 one cell down), 416 at the top (the path's, the village's entrance). The model painted lips
and cracks; inside the rock (deeper than 14 art rows under a top) only the four violet rock colours are kept, so nothing
there reads as a ledge.

## Planes, back to front

Art px; scale 1.5; scroll factor on both axes; anchors in the path's world, camera at 0 (a plane with factor f is drawn
at anchor − f × camera).

- sky `DesertOasis/bg4/plan5.png` (×0, tile), `MountainPath/gen_barrier.png` (×0.1, anchor (115, 4)),
  `MountainPath/gen_far.png` (×0.3, tile) — shared with the road, they go on from the gorge.
- `gen_plume.png` (856×223) — the road's biggest smoke (D796): the same generation as the path's plume, ×1.12 of a
  3× reduction. ×0.6, anchor (1794, 57): in the top frame its stem's cut bottom is at frame (560, 280), behind the
  burnt houses at the passage, the puff stands over them and the body streams west across the whole sky; in the bottom
  frame only the body crosses the top. The cut bottom is behind the cliff at every camera y (`build` asserts it).
- `gen_mid.png` (576×340) — the gorge's far wall going on, ×0.75, anchor (2592, 232). Columns 0–143 are the gorge's
  `gen_mid.png` columns 1296–1439 (same pixels at the border); further east a fourth outpainted chunk, the rim falling
  toward the valley where the village is. Same 12 colours and extra haze as the gorge's wall. In the top frame it sinks
  to the bottom: the hero has climbed above the gorge.
- `gen_burnt_houses.png` (424×203) — the first houses of the burnt village beyond the passage, ×0.85, anchor
  (3374, 97) (bottom-left at frame (436, 300) in the top frame, base hidden behind the plateau at every camera y —
  asserted). The Village's own houses repainted after the fire (Sapega: «все село спалене … з цегли, то не розбиті, але
  спалені»): walls whole, soot over doors and windows, awnings burnt to frames, flames in a window, smoke from the roofs.
  1.5× the Village row's size (block 2): they are nearer than the village's back row.
- `gen_ledges.png` (576×640) — the cliff with its ledges, ×1.0, room-sized, anchor (3456, 0). Columns 0–129 under row
  570 are the gorge's `gen_ground.png` mirrored at its east edge (column 0 = the gorge's last column: no seam), so the
  bank and the stream go on and end at a small cascade (art x 118–129, rows 559–596) falling from under ledge 1.
- front: `StreamGorge/gen_front.png` (reeds and boulders, D750 occluder, `foreground_dark.tscn`, ×1.3), anchor
  (4453, 603): bottom-left of the bottom frame, foot 40 art px below the view; out of view higher up.

For the room routine: a warm fire glow on the plateau rim and the houses near the passage (a light, not a texture) and a
few sparks / embers drifting west from behind the houses; dragonflies by the cascade at the bottom.
