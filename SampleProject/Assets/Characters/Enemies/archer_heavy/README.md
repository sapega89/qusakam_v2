# Heavy archer — the archer's elite (D652, D678)

**AI-generated** by `Scripts/Tools/comfy_sprite.py big_crossbowman`: the local ComfyUI with **Qwen-Image-Edit-2511**
(Alibaba Qwen, Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0). A Steam release has
to disclose AI-generated content.

First made in 96×96 cells from the hero's artist frame `SampleProject/Sprites/Player/Walk/1.png` (candidate seed 137,
three-quarter view, D678), 85 art px tall. **A10 (B187, D814), 2026-10-28:** redrawn at the chart's adult height,
**96 art px** (144 px in the world at the scene's ×1.5): the first frame is the old idle frame
(`design/shots/candidates/a10/archer_heavy_old.png`, cell 0) in a 128×112 canvas, redrawn bigger by the model (seed 210,
block 12 px) and brought to exactly 96 art px (`height=96`); the other frames are made from it with the same pose
prompts as before. The game grows him as an elite by `enemy_variety.json` elite.scale on top of that (D859); the sheet
holds no elite size. 16-colour palette, feet on row **105**.

`sheet.png` — 512×560: 4 columns × 5 rows of **128×112** cells, facing right (`enemy_heavy_archer.tscn`: `hframes = 4`,
`vframes = 5`, ×1.5, offset −31, feet on the body's bottom edge at y 16).

| Frames | Animation | Content |
|---|---|---|
| 0–1 | idle | bow held low; 1 = breathing (`BOB`, below the belt) |
| 4–7 | walk | steps to the right |
| 8–10 | attack | full draw, aiming (8 — the wind-up; the arrowhead is `tell_at`), the shot just loosed (9), upright again reaching for the quiver (10) |
| 12 | hurt / stagger | flinching back, the bow lowered |
| 16–18 | death | staggering back, on his knees, lying on his back |

Empty cells: 2, 3, 11, 13–15, 19.
