# Mountain Path planes (M6a-1)

**AI-generated.** Made with `Scripts/Tools/comfy_backdrop.py` (layers `MountainPath/gen_*`) using **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); the ground strip is cut to its
walk line by `design/shots/candidates/path_planes/path_planes.py`. A Steam release has to disclose AI-generated content.

The room: outdoor, main road, 2 cells (1728 × 480 world), between the bridge (west) and the Scree Slide (east). No
fights; the story is in the background: a plume of smoke blown west from the village, and the fallen barrier — a
cracked glass dome over the east (D795). Review: `design/shots/m6a1_path_scree.png`.

Back to front (art px; the scene draws them at scale 1.5; scroll factor on both axes):

- sky: the shared pack sky `DesertOasis/bg4/plan5.png` and drifting clouds, as the canyon (×0).
- `gen_barrier.png` (576×259) — the fallen barrier (Sapega: «прозорий шар в небі з тріщиною»): a huge faint glass dome
  with a jagged broken-out hole and cracks in its upper left, as wide as the screen (D797; was 456, four fifths). Drawn
  by the model as light on black (`path_planes.py gen`, seed 701) and area-averaged to 576 px (`path_planes.py
  barrier`: the same raw, reduced 2.375× instead of 3×, so the art pixels stay sharp); brightness became alpha in four
  steps — body 0.1, streaks 0.18, outline 0.3, crack edges 0.45 — in one pale cold white (236, 246, 255). ×0.1, the
  farthest plane after the sky; top-left at art (115, 4) with the camera at the path's left end: it fills the frame
  edge to edge at the Scree Slide (camera x 1152), starts at x 115 at the path's start and drifts west 0.1 px per px
  walked. Apex at frame row ~7, cut bottom at row 263, below the deepest valley of `gen_far` (223). The hole is at x
  136–272 of the image. Also used by the Scree Slide and the Stream Gorge.
- `gen_far.png` (576×324) — a continuous distant range of bare rocky peaks, hazed, filled down; seamless tile. ×0.3.
  Also used by the Scree Slide and the gorge. A5 (redrawn): the first version (seed 501) was separate rock lumps on a
  flat plain; now `path_planes.py far` paints it over a guide of two periodic ridges (img2img, seed 532), so the range
  is unbroken and the tile seamless; the deepest valley is row 213 (asserted above the barrier's cut, 263).
- `gen_plume.png` (491×132) — the smoke of the burning village as a long plume blown west across the sky (Sapega's
  sketch, 27.10): a ragged pointed tip on the left, widening, a big rounded puff, and on the right a stem bending down
  to the source, cut at the bottom (`keep`). A5 (fixed): new generation (seed 733) in ash grey and warm brownish grey
  with lit tops instead of the near-black charcoal one, its tip ragged instead of a ruler-straight line. ×0.4, in front
  of `gen_far`, behind `gen_mid`; top-left at art (572, −12) with the camera at the path's left end (the stem, column
  471, at the same world x as before). So the hero walks under it toward its source: at the path's start the tip just
  comes in at the right edge near the top, at its end the tip is mid-screen, and on the Scree Slide the whole plume
  is in view with the puff at the east edge and the stem beyond it. ×0.4, not ×0.5: between the path's start and the
  scree the camera covers 1152 × f px of the plane, and the plume is ~470 px to the stem. Also used by the Scree Slide.
- `gen_mid.png` (576×324) — a ridge of red sandstone cliffs and spires with dry thorn bushes, filled down; seamless
  tile. ×0.75.
- `gen_waymarker.png` (73×57) — a weathered sandstone standing stone with its tip broken off, a carved spiral rune and
  an arrow pointing east, flat stones and sand at its foot: the one story prop. A5 (redrawn, seed 521): the first one
  (a square pillar with a blue ribbon) read as a wrapped gift. ×0.9, 57 art px = 1 H × 0.9 (world_scale_plan; ±1 px
  rounding), feet 2 px under the walk line.
- `gen_ground.png` (576×49) — the rocky path under the hero; row 0 is the walk line (world y 416); seamless tile.
  ×1.0.
- `gen_front.png` (193×212) — a dark rock spire with a dead tree: the D750 occluder (`foreground_dark.tscn`, ×1.3,
  its modulate), scale 1.5 (1:1 art px), foot ~40 art px below the view; never over a door, an NPC or a fight.
  Also used by the Scree Slide.

**Seamless road:** the planes are anchored to the world, not to the room — in a room whose left edge is X world px
right of the path's, each plane is shifted by −factor × X (Scree Slide: X = 1728). So at the border the far plane and
the ridge go on where they were, instead of jumping back.
