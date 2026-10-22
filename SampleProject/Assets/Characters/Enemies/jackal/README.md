# Jackal — the fast enemy (D208, D229)

`sheet.png` — Crusenho's `2 Hyena` (CC BY 4.0, credit **Crusenho Agus Hennihuno**, https://crusenho.itch.io — see
`../README.md` and `../CRUSENHO_LICENSE.txt`), 96×72 cells, feet on row 71.

`stagger.png` — **remaining_work Art 4, AI-generated** (a Steam release has to disclose it), 192×72: two 96×72
cells made by `python Scripts/Tools/comfy_art_fixes.py "stagger_jackal*"` with the local ComfyUI,
**Qwen-Image-Edit-2511** (Alibaba Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) + Lightning LoRA, from
Crusenho's frames — a derivative of CC BY art, so the Crusenho credit applies to it too. Colours from `sheet.png`,
feet on row 71, facing right. The model draws the hyena bigger than the sheet and «exactly as small» in the prompt
does not help, so the job scales its picture down before the reduction to the cell (`scale`).

- 0 = recoiling from the blow: crouched back on bent hind legs, front legs braced, head tossed up with the mouth
  open in a yelp. Seed 43 from idle 0, scale 0.83: 33×29 px, 486 opaque pixels (idle 0: 35×28, 521). The model's
  tail ran 11 px down to the ground; `post=jackal_tail_stub` cuts it to the sheet's short dark stub (~7 px).
- 1 = dazed, head hanging low, legs splayed, the short dark tail hanging. Seed 41 from death frame 20 (row 3,
  cell 2), scale 0.9: 38×20 px, 530 pixels.

Redrawn earlier: a frame 0 that reared up on its hind legs looking left; a pair that was a bigger, lankier animal
with a long bushy tail (frame 0 42×33, 707 pixels); frames that sat like a dog and howled. The model never managed
«sitting back on its haunches» at the sheet's height. Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).
