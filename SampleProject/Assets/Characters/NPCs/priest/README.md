# The priestess of the sky — City OathPriest (D281, D295)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py priest` from the hero's `Sprites/Player/Walk/1.png`; see `../README.md`.
`sheet.png`: 64×96 cells, row 0 profile idle, row 1 front, row 2 prayer `work` 0–3; feet row 90.

**Fix (remaining_work Art 4):** the prayer frames had a stray pale-blue stick hanging from her elbow to the lower
left. The model would not remove it (seed 21, «remove the thin pale-blue stick…» kept it), so
`Scripts/Tools/comfy_art_fixes.py priest_work` erases the rectangle x 0–23, y 58–79 of each `work` cell; the robe
outline (column 24) and the hem (from row 80) are untouched. Her one staff behind the shoulder stays. No new
generation. Rerunning `comfy_sprite.py priest` would bring the stick back — run `comfy_art_fixes.py priest_work` after it.
