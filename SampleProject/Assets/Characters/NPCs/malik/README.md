# Malik — the merchant in the Laboratory cells (D303)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py malik` from the hero's `Sprites/Player/Walk/1.png` (style reference); see
`../README.md`. `sheet.png`: 64×96 cells, row 0 idle 0–1, row 1 walk 4–7, row 2 front 8–9; feet row 91; faces right.

**Fix (remaining_work Art 4):** the robe showed see-through (white in the game) patches, most in the walk. The tool's
cut of the model's magenta floor shadow also cut the dark purple of his robe. `malik` now sets `magenta_cut_min=170`
(only bright magenta is cut) and the whole sheet was rebuilt from the same cached model images — no new generation,
the same poses, the robe solid. Same size, cells and feet row as before.
