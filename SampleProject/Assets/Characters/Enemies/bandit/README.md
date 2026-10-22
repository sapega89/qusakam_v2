# Desert bandit — the melee enemy (D239)

**AI-generated** by `Scripts/Tools/comfy_sprite.py bandit`: the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0). The first frame is made from
the hero's own sprite (`SampleProject/Sprites/Player/Walk/1.png`, the artist's frame) as the style reference; every
other frame from that first frame, so it stays the same bandit. Brought down to 64×64 at the hero's pixel, one palette
for all frames, feet on row 56. A Steam release has to disclose AI-generated content.

`sheet.png` — 4×4 cells of 64×64, facing right: idle 0–1, walk 4–7, attack 8–11 (the cut lands at the end of the
0.4 s wind-up), death 12–15. Used by `Scenes/Characters/Enemies/default_enemy.tscn` (×1.5, offset −6).

`stagger.png` — **new (remaining_work Art 4)**, 128×64: two 64×64 cells made by `Scripts/Tools/comfy_art_fixes.py
stagger_bandit` (same model, seed 2) from idle 0, colours from `sheet.png`, feet on row 56. 0 = knocked back, head
jerked back, the scimitar arm flung up, stumbling on one foot; 1 = doubled over, head down, free hand on the stomach,
scimitar tip on the ground. (A first frame 1, «hunched, knees buckling», came out as idle and was redrawn.) Not
wired yet.
