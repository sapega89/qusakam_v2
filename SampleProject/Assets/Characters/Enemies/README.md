# Enemy art by type (D208, D214, D218)

| Type | Sheet | Source |
|---|---|---|
| tank | `battle_turtle/sheet.png` | drawn by `Scripts/Tools/draw_enemy_sheets.py` — desert turtle in the hero's style (D218) |
| fast | `centipede/sheet.png` | drawn by the same script — centipede, rears up like a cobra in the wind-up |
| melee | `Scripts/Systems/character-spritesheet (4).png` (unchanged, `default_enemy.tscn`) | — |

Original work for this project, no third-party licence. Style matched to the hero (`Sprites/Player`): chibi
proportions, 1-px outline (40, 23, 36), three light bands from the top left, round red eye with a
white highlight, an angry brow so it reads as an enemy. Grid kept from D214 so the scenes did not change: rows
idle / walk / attack / death, 96×72 cells, feet on the bottom row, facing right; attack frames match the scene keys.

The earlier sheets came from `assets/ChatGPT Image Jul 30, 2025…-autotile/` (origin unknown, D214) —
`Scripts/Tools/build_enemy_sheets.py` is removed with them.
