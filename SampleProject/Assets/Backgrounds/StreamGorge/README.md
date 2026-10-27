# Stream Gorge planes (M6a-2a)

**AI-generated.** Made with `design/shots/candidates/gorge_planes/gorge_planes.py` on top of
`Scripts/Tools/comfy_backdrop.py` (layers `StreamGorge/gen_plume`, `StreamGorge/gen_front`), using **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0): the far wall is outpainted to the
right of the Scree Slide's wall, the bank and the stream are painted over a drawn guide (img2img); the walk line and the
outline of the water are the script's, not the model's. A Steam release has to disclose AI-generated content.

The room: outdoor, main road, 3 cells wide (2592 × 480 world, 1728 × 320 art), no fights. Its left edge is 2592 world px
(1728 art) east of the Mountain Path's left edge and 480 world px (one cell) below the path's top, i.e. east of the
Scree Slide's lower cell. The hero comes off the scree onto the bank and walks east to the rock ledges. Review:
`design/shots/m6a2_gorge.png`.

Back to front (art px; scale 1.5; scroll factor on both axes; anchors are in the path's world, art px, camera at 0 — a
plane with factor f is drawn at anchor − f × camera; the gorge's camera is at y 316 like the scree's bottom):

- sky, `MountainPath/gen_barrier.png` (×0.1, anchor (115, 4)), `MountainPath/gen_far.png` (×0.3, tile) — shared with
  the path and the scree, so they go on from where the scree left them; the far peaks are mostly behind the wall.
- `gen_plume.png` (655×176) — the gorge's own smoke plane (D796: bigger than the path's 491×132): the same generation
  as `MountainPath/gen_plume.png` (A5, seed 733: ash grey with lit tops, ragged tip — the old near-black puff dominated
  the corner), a plain 3× reduction, hazed 0.25. ×0.35, anchor (978, 90). Sapega:
  the smoke must read as the burnt village beyond the next screen, never as a fire in the gorge — so its stem is never
  in view: at the left end the thin tip shows over the rim, in the middle the body crosses the sky, at the right end the
  puff sits in the upper right corner and the stem bends down beyond the east edge; the stem's cut bottom (frame row
  155) is off-screen east at every camera x (`gorge_planes.py build` asserts it).
- `gen_mid.png` (1440×340) — the far wall of the gorge, ×0.75, anchor (1296, 232); its rows are the Scree Slide wall's
  rows 232–572 and its columns 0–144 are that wall's columns 432–576 (the same place in the world), so the wall goes on
  at the border. The rim is 45–110 px below the frame top (a band of sky with the barrier), lower in the east (to
  ~140–190) where the smoke shows. A5 (redrawn, chunks seed 821–823): the old wall had a square rock stub with a
  straight edge at column 144 (the end of the scree's spire) and narrow slots down to the bottom between separate mesas;
  now the first 144 columns are kept exactly in the generation, the spire goes on to ~176 and slopes down (cut above
  the line (144, 0) → (176, 52)), and the wall is one continuous face (columns 190–420 repainted once, they came out
  flat sand). Same 12 colours as the path ridge, the same extra haze from row 253 as the scree's
  wall, so its ledges don't read as walkable.
- `gen_ground.png` (1728×80) — the bank and the stream, ×1.0, room-sized, anchor (1728, 570) = room row 250. Row 27
  (room y 277 art, 416 world — the same as the scree's floor) is the walk line: the lightest ground colour, a shadow row
  under it, then dirt and rock in `MountainPath/gen_ground.png`'s palette (as the scree's floor). Above it, rows ~11–26:
  the stream (scenery, behind the hero; no swimming), with a few stones in it and a low pebble edge on the far side;
  10 colours of its own. Columns 0–76: scree rubble dams the stream's west end; at the east edge the water runs on
  into the rock ledges room (room rows ~261–276).
- `gen_front.png` (188×172) — boulders with dry reeds: the D750 occluder (`foreground_dark.tscn`, ×1.3, its modulate),
  anchor (3035, 603): once, around the room's middle screen, foot ~40 art px below the view.

For the room routine: atmosphere — dragonflies and glints over the water, low and behind the hero.
