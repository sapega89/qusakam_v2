# Scree Slide planes (M6a-1)

**AI-generated.** Made with `design/shots/candidates/path_planes/path_planes.py` on top of
`Scripts/Tools/comfy_backdrop.py`, using **Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA
(lightx2v, Apache 2.0): the gorge wall is inpainted under the Mountain Path ridge, the slope is painted over a drawn
guide (img2img); the outline of the slope is the script's, not the model's. A Steam release has to disclose
AI-generated content.

The room: outdoor, main road, 1 × 2 cells (864 × 960 world), east of the Mountain Path; the hero slides down to the
Stream Gorge, which continues east from the lower cell. Review: `design/shots/m6a1_path_scree.png`.

Back to front (art px; scale 1.5; scroll factor on both axes, so on the way down the far plane sinks behind the rim):

- sky, `MountainPath/gen_smoke.png` (×0.1), `MountainPath/gen_far.png` (×0.3) — shared with the path, shifted by
  −factor × 1728 world px (the path's width), so they go on from where the path left them.
- `gen_mid.png` (576×640) — the far wall of the gorge, ×0.75; drawn for this room's only camera x, no further shift.
  Rows 0–252 are `MountainPath/gen_mid.png` rolled 288 art px (the phase the path's tile reaches at the border);
  below, the gorge wall, in the same 12 colours.
- `gen_scree.png` (576×640) — the scree slope and the rock under it, ×1.0, room-sized; transparent above the surface.
  The surface, in world px (room-local) — the collision follows it: flat (0, 416) → (96, 416), slope down to
  (720, 896) (about 38°, under the 45° floor limit), flat (720, 896) → (864, 896), the gorge floor and the exit east.
  A light lip row on the surface, a shadow row under it.
- `MountainPath/gen_front.png` — the D750 occluder in the lower-left corner, inside the rock under the slope, below
  the hero's path.
