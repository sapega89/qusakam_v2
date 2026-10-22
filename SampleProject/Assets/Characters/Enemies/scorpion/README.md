# Scorpion — the tank enemy (D208, D229)

`sheet.png` — Crusenho's `3 Scorpio` (CC BY 4.0, credit **Crusenho Agus Hennihuno**, https://crusenho.itch.io — see
`../README.md` and `../CRUSENHO_LICENSE.txt`), 96×72 cells, feet on row 71.

`stagger.png` — **new (remaining_work Art 4)**, 192×72: **not generated** — Crusenho's own death frames 1 and 2
(row 3, the tail sinking) copied into two 96×72 cells by `Scripts/Tools/comfy_art_fixes.py stagger_scorpion`; same
licence and credit as the sheet. Two rounds with Qwen-Image-Edit-2511 (seeds 41, 42) came out off-model for this
48-px sprite (a second claw drawn as a ring, an eye on the claw, a longer body) and were rejected. Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).
