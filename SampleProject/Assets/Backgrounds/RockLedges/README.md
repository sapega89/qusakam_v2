# Rock Ledges planes (M6a-2b)

**AI-generated.** Made with `design/shots/candidates/ledges_planes/ledges_planes.py` on top of
`Scripts/Tools/comfy_backdrop.py`, using **Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA
(lightx2v, Apache 2.0): the far wall is outpainted to the right of the Stream Gorge's wall, the cliff and the village
wall are painted over drawn guides whose rock is the gorge wall's own generation (img2img), the burnt houses are three
of the Village's `gen_houses.png` houses repainted "after the fire" (img2img, denoise 0.65). The outline of the ledges,
the cascade and the bank's pixels are the script's, not the model's. A Steam release has to disclose AI-generated content.

The room: outdoor, main road, the last room before the village, 1 × 2 cells (864 × 960 world, 576 × 640 art). Its left
edge is 3456 art (5184 world) east of the Mountain Path's left edge, its top at the path's top (y 0), i.e. its lower
cell is east of the gorge. The hero comes off the gorge bank at the bottom left, jumps up the ledges and leaves east at
the top across a wide plateau, past a breach in the village's outer wall, into the burnt village. Camera: x fixed (the room is one screen wide), y 0 (top) to 316 (bottom, as in the
gorge). Review: `design/shots/m6a2b_ledges.png`.

## The ledges — collision (world px, room-local)

`gen_ledges.png` is opaque exactly under this outline; each ledge runs from its x to the next ledge's x, the risers are
vertical. Steps 48–81 world px, each one jump (the hero jumps ~103 px). A5: each ledge is 60 world px wide (was
~75) so the plateau is 339 wide (was 219):

| ledge | x from | x to | top y |
|---|---|---|---|
| floor (bank, from the gorge) | 0 | 165 | 896 |
| 1 | 165 | 225 | 832 |
| 2 | 225 | 285 | 752 |
| 3 | 285 | 345 | 688 |
| 4 | 345 | 405 | 608 |
| 5 | 405 | 465 | 528 |
| 6 | 465 | 525 | 464 |
| plateau (exit east) | 525 | 864 | 416 |

(Art px: x 0/110/150/190/230/270/310/350, tops 597/555/501/459/405/352/309/277.) The walk lines match the road: 896 at
the bottom (the gorge's 416 one cell down), 416 at the top (the path's, the village's entrance). The rock is the gorge
walls' sandstone in their own 11 colours (A5; was flat violet blocks); deeper than 14 art rows under a top the three
lightest colours are dropped and the rest darkened 12 %, so nothing inside the cliff reads as a ledge and the cliff
stands in front of the paler walls.

## Planes, back to front

Art px; scale 1.5; scroll factor on both axes; anchors in the path's world, camera at 0 (a plane with factor f is drawn
at anchor − f × camera).

- sky `DesertOasis/bg4/plan5.png` (×0, tile), `MountainPath/gen_barrier.png` (×0.1, anchor (115, 4)),
  `MountainPath/gen_far.png` (×0.3, tile) — shared with the road, they go on from the gorge.
- `gen_mid.png` (576×340) — the gorge's far wall going on, ×0.75, anchor (2592, 232). Columns 0–143 are the gorge's
  `gen_mid.png` columns 1296–1439 (same pixels at the border); further east a fourth outpainted chunk, the rim falling
  toward the valley where the village is. Same 12 colours and extra haze as the gorge's wall. In the top frame it sinks
  to the bottom: the hero has climbed above the gorge.
- `gen_burnt_houses.png` (380×278) — three burnt village houses beyond the wall, ×0.6, anchor (2296, 27)
  (bottom-left at frame (222, 305) in the top frame). The Village's own houses (the blue-awning, the red-awning and the
  next one, set a little apart) repainted after the fire (Sapega: «все село спалене … з цегли, то не розбиті, але
  спалені»): walls whole, soot over doors and windows, awnings burnt to frames, roof beams charred, a glow in a window,
  and a short column of grey smoke from each roof leaning west — the room's only smoke (A5: the big plume that filled
  the top half is gone; the road's plume ends in the gorge, its stem going down right here). At the Village row's
  size: a wall ~83 art = a 144 storey × 0.6 (D814). M6a-3: rebuilt by `village_burnt.py` from the
  Village's `gen_houses_burnt.png` (the same three houses, so the ledges and the village match); its silhouette is
  the original row's, so no house is a hollow shell any more. The ground under them goes 45 rows further down so the breach
  shows a yard; their base is behind the wall at every camera y (`build` asserts it).
- `gen_village_wall.png` (384×432) — the village's outer wall of clay bricks on the cliff top behind the plateau, ×0.9,
  anchor (3302, 185) (top-left at frame (192, 185) in the top frame): a broken west end, a breach near the east end
  (frame x ~447–502) — the passage into the village — and the sandstone terrace face under it, filled down, with a
  ragged west edge. The wall shows ~50 art above the plateau, below the hero's height, so the houses read over it.
- `gen_ledges.png` (576×640) — the cliff with its ledges, ×1.0, room-sized, anchor (3456, 0). Columns 0–109 under row
  570 are the gorge's `gen_ground.png` mirrored at its east edge (column 0 = the gorge's last column: no seam), so the
  bank and the stream go on and end at a small cascade (art x 98–109, rows 559–596) falling from under ledge 1.
- front: `StreamGorge/gen_front.png` (reeds and boulders, D750 occluder, `foreground_dark.tscn`, ×1.3), anchor
  (4453, 603): bottom-left of the bottom frame, foot 40 art px below the view; out of view higher up.

For the room routine: the exit east goes through the breach (a door or transition at the plateau's east edge); a warm
fire glow on the houses near the breach (a light, not a texture) and a
few sparks / embers drifting west from behind the houses; dragonflies by the cascade at the bottom.

## In the game: `gen_ledges_ramp.png` (wire-backdrops, D830/D834)

The ledges are on the main road, and the road has no steps (D830); world-rooms built the room as one ramp (D834:
`Slope` (96, 864) → (768, 384) world, room-local, with flat landings). `Scripts/Tools/ledges_ramp.py` bends
`gen_ledges.png` onto that ramp: each art column is shifted vertically so its walk line (the table above) lands on the
ramp, with its lip, shadow and rock; nothing is repainted. The room (`Maps/RockLedges.tscn`, generated by
`Scripts/Tools/build_world_rooms.py`) draws `gen_ledges_ramp.png`; `gen_ledges.png` stays as the source. Like the other
road planes it is drawn 32 px higher than the anchors above (walk line 416 → the road's floor 384).
