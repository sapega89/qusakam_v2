# The alchemist — LabCells scientist (D303)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
First made by `Scripts/Tools/comfy_sprite.py alchemist` from the hero's `Sprites/Player/Walk/1.png`; see
`../README.md`. `sheet.png`: 64×96 cells, row 0 idle 0–1, row 1 walk 4–7, row 2 inject 8, row 3 front 12–13;
feet row 91; faces right.

**Fix (remaining_work Art 4):** his long black cloth mask read as a beard. Every frame was edited from itself by
`Scripts/Tools/comfy_art_fixes.py alchemist` (same model, seed 39): a short **pale grey cloth surgical mask** over
mouth and nose with a thin strap to the ear, ending at the chin, neck and collar visible. Idle 1 and front 1 are the
1-px breathing copies (`BOB:56`) of frames 0. A first try — a short black mask — still read as a short beard next to
Malik and was dropped. Pose, coat, syringe, cells and feet row unchanged; the portrait region shows the new face.
Rerunning `comfy_sprite.py alchemist` would bring the old mask back — run `comfy_art_fixes.py alchemist` after it.
