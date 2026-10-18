# Enemy art by type (D208, D210, D214)

| Type | Sheet | Source | Licence |
|---|---|---|---|
| tank | `battle_turtle/sheet.png` | `assets/ChatGPT Image Jul 30, 2025, 06_51_40 PM-autotile/2 Battle turtle/` idle, walk, attack2, death | **not found** in the folder (looks like a craftpix desert-enemies pack) — verify before release |
| fast | `centipede/sheet.png` | same folder, `1 Centipede/` idle, walk, attack3, death | **not found** — verify |
| melee | `Scripts/Systems/character-spritesheet (4).png` (unchanged, `default_enemy.tscn`) | — | — |

Sheets are built by `Scripts/Tools/build_enemy_sheets.py`: rows idle / walk / attack / death, 96×72 cells,
frames mirrored (the pack draws them facing left, the game expects right), the idle body centred.
Unused in the same folder: `3 Big bloated`, the turtle's cannon shot (`attack3`, for a ranged type, Q35).
