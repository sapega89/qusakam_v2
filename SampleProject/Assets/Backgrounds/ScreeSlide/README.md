# Scree Slide planes (M6a-1)

**AI-generated.** Made with `design/shots/candidates/path_planes/path_planes.py` on top of
`Scripts/Tools/comfy_backdrop.py`, using **Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA
(lightx2v, Apache 2.0): the gorge wall is inpainted under the Mountain Path ridge, the slope is painted over a drawn
guide (img2img); the outline of the slope is the script's, not the model's. A Steam release has to disclose
AI-generated content.

The room: outdoor, main road, 1 × 2 cells (864 × 960 world), east of the Mountain Path; the hero slides down to the
Stream Gorge, which continues east from the lower cell. Review: `design/shots/m6a1_path_scree.png`.

Back to front (art px; scale 1.5; scroll factor on both axes, so on the way down the far plane sinks behind the rim):

- sky, `MountainPath/gen_barrier.png` (×0.1), `MountainPath/gen_far.png` (×0.3), `MountainPath/gen_plume.png` (×0.4) —
  shared with the path, shifted by −factor × 1728 world px (the path's width), so they go on from where the path left
  them. Here the whole smoke plume is in view, its puff at the east edge and its stem beyond the edge; on the way down
  it rises out of the frame.
- `gen_mid.png` (576×640) — the far wall of the gorge, ×0.75; drawn for this room's only camera x, no further shift.
  Rows 0–252 are `MountainPath/gen_mid.png` rolled 288 art px (the phase the path's tile reaches at the border);
  below, the gorge wall, in the same 12 colours, hazed further so its ledges don't read as walkable (D795): +0.35
  toward the sky haze, reached in 8 steps over the 64 rows under row 253, so there is no seam with the ridge.
- `gen_scree.png` (576×640) — the scree slope and the rock under it, ×1.0, room-sized; transparent above the surface.
  The surface, in world px (room-local) — the collision follows it: flat (0, 416) → (96, 416), slope down to
  (720, 896) (about 38°, under the 45° floor limit), flat (720, 896) → (864, 896), the gorge floor and the exit east.
  A light lip row on the surface, a shadow row under it. A5 (fixed): on the slope itself (not the flat ends, which
  carry the path's and the gorge's floor) the solid bright orange band read as a lava stream; up to three quarters of
  its orange pixels became 2×2 specks of light sandstone and grey-violet stone from the same palette — loose gravel.
- `MountainPath/gen_front.png` — the D750 occluder in the lower-left corner, inside the rock under the slope, below
  the hero's path.
