# Desert bandit archer — the ranged enemy (BACKLOG 40, art A4; redrawn at adult size in A10)

**AI-generated** by `Scripts/Tools/comfy_sprite.py bandit_archer`: the local ComfyUI with **Qwen-Image-Edit-2511**
(Alibaba Qwen, Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0). A Steam release has
to disclose AI-generated content.

**A10 (B187, D814, D816), 2026-10-28:** the first sheet was a chibi made from the melee bandit's 64×64 frames, 49 art px
tall (73.5 px in the world). Now an adult with normal proportions, **96 art px tall** (144 px in the world, the chart's
adult): the first frame is the old idle frame (`design/shots/candidates/a10/bandit_archer_old.png`, cell 0) in a
128×112 canvas, redrawn by the model as a tall lean man (seed 210, block 12 px); `height=96` brings it to exactly 96
art px, and every other frame is made from it with the pose prompts (walk), the old bow poses (`FROM:`) and the death
fall. 16-colour palette, feet on row **105** in every cell.

`sheet.png` — 512×560: 4 columns × 5 rows of **128×112** cells, facing right (`enemy_archer.tscn`: `hframes = 4`,
`vframes = 5`, ×1.5, offset −31, so the feet stand on the body's bottom edge at y 16).

| Row | Frames | Content |
|---|---|---|
| idle | 0–1 | standing with the bow upright; 1 = breathing (`BOB:67`, below the belt) |
| walk | 4–7 | steps to the right |
| attack | 8–11 | raise the bow (8), full draw (9), hold the draw (10), release — empty bow, hand flung back (11). The arrow leaves the arrowhead of 9–10, about (99, 43) in the cell = `tell_at` (35, −13) |
| hurt | 12 | flinching back, the bow lowered |
| death | 16–19 | flinch (= hurt), staggering back, sitting collapsed, lying on his back; hold 19 |

Unused cells: 2–3, 13–15.
