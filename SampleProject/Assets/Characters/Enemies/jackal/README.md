# Jackal — the fast enemy (D208, D229)

`sheet.png` — Crusenho's `2 Hyena` (CC BY 4.0, credit **Crusenho Agus Hennihuno**, https://crusenho.itch.io — see
`../README.md` and `../CRUSENHO_LICENSE.txt`), 96×72 cells, feet on row 71.

`stagger.png` — **new (remaining_work Art 4), AI-generated** (a Steam release has to disclose it), 192×72: two 96×72
cells made by `Scripts/Tools/comfy_art_fixes.py stagger_jackal` with the local ComfyUI, **Qwen-Image-Edit-2511**
(Alibaba Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) + Lightning LoRA, seed 41, from Crusenho's idle
frame 0 — a derivative of CC BY art, so the Crusenho credit applies to it too. Colours from `sheet.png`, feet on
row 71, facing right. 0 = pushed back onto its haunches, front legs braced, head jerked up; 1 = dazed, head hanging
low. Both have 20–35 % more pixels than idle (the model draws it a little larger; seed 43 with «exactly as small»
was no smaller). A first frame 0 reared up on its hind legs looking left and was redrawn. Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).
