# Enemy art by type (D208, D229)

| Type | Sheet | Source |
|---|---|---|
| tank | `scorpion/sheet.png` | Crusenho desert enemies, `3 Scorpio` (idle, walk, attack, death) |
| fast | `jackal_pack/sheet.png` | AI-generated, the pack jackal in the pack leader's style (D692/D693), see `jackal_pack/README.md` |
| melee | `Scripts/Systems/character-spritesheet (4).png` (unchanged, `default_enemy.tscn`) | — |
| flying, outdoors | `vulture/sheet.png` | AI-generated (D445, D637), see `vulture/README.md` |
| flying, caves | `bat/sheet.png` | AI-generated (D445, D637), see `bat/README.md` |

**Licence: CC BY 4.0** — art by **Crusenho Agus Hennihuno** (https://crusenho.itch.io), from the pack found in
`assets/Complete_UI_Essential_Pack_Free/` (`License.txt`, copied here as `CRUSENHO_LICENSE.txt`).
Changes: frames mirrored to face right and laid into the game's sheet grid. Credit them in the game's credits.

Stagger poses (remaining_work Art 4): `scorpion/stagger.png` (its own death frames 1–2, see `scorpion/README.md`); the bandit's in
`bandit/stagger.png`. The jackal's is the hurt frame (12) of its own sheet.

Sheets are built by `Scripts/Tools/build_desert_enemy_sheets.py`: rows idle / walk / attack / death, 96×72 cells,
feet on the bottom row, facing right; frames unscaled (48×48), the scenes scale them ×1.5 like the hero.
Attack frames: scorpion 1 = tail raised (wind-up), 2 = sting (lands at 0.7 s with the tank's wind-up).

The drawn turtle and centipede (D218) are gone; their shared drawing helpers live in `Scripts/Tools/pixel_kit.py`.
