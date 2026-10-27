# Mountain Path planes (M6a-1)

**AI-generated.** Made with `Scripts/Tools/comfy_backdrop.py` (layers `MountainPath/gen_*`) using **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); the ground strip is cut to its
walk line by `design/shots/candidates/path_planes/path_planes.py`. A Steam release has to disclose AI-generated content.

The room: outdoor, main road, 2 cells (1728 × 480 world), between the bridge (west) and the Scree Slide (east). No
fights; the story is in the background: smoke over the village to the east. The fallen barrier is **not** drawn
(the lore never says what it looks like). Review: `design/shots/m6a1_path_scree.png`.

Back to front (art px; the scene draws them at scale 1.5; scroll factor on both axes):

- sky: the shared pack sky `DesertOasis/bg4/plan5.png` and drifting clouds, as the canyon (×0).
- `gen_smoke.png` (100×141) — two columns of dark smoke from the burning village. ×0.1, **behind** `gen_far`; its foot
  at art row 226 (world y 339), below the deepest valley of `gen_far` (row 223), so the mountains hide where it rises.
  On the review sheet it sits at art x 380 with the camera at the path's left end. Also used by the Scree Slide.
- `gen_far.png` (576×324) — distant bare rocky mountains, hazed, filled down; seamless tile. ×0.3. Also used by the
  Scree Slide.
- `gen_mid.png` (576×324) — a ridge of red sandstone cliffs and spires with dry thorn bushes, filled down; seamless
  tile. ×0.75.
- `gen_waymarker.png` (42×57) — a broken stone waymarker with a carved spiral and a blue ribbon, the one story prop.
  ×0.9, 57 art px = 1 H × 0.9 (world_scale_plan; ±1 px rounding), feet 2 px under the walk line.
- `gen_ground.png` (576×49) — the rocky path under the hero; row 0 is the walk line (world y 416); seamless tile.
  ×1.0.
- `gen_front.png` (193×212) — a dark rock spire with a dead tree: the D750 occluder (`foreground_dark.tscn`, ×1.3,
  its modulate), scale 1.5 (1:1 art px), foot ~40 art px below the view; never over a door, an NPC or a fight.
  Also used by the Scree Slide.

**Seamless road:** the planes are anchored to the world, not to the room — in a room whose left edge is X world px
right of the path's, each plane is shifted by −factor × X (Scree Slide: X = 1728). So at the border the far plane and
the ridge go on where they were, instead of jumping back.
