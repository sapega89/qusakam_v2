# Pack jackal — the fast enemy (D692, D693)

`sheet.png` — **AI-generated** (a Steam release has to disclose it) by `python Scripts/Tools/comfy_sprite.py jackal_pack`
with the local ComfyUI, the D693 pick: candidate 3 (seed 146, three-quarter view), the pack leader's rows
(`_pick("jackal_pack", ...)`). It replaces Crusenho's `2 Hyena` (the old `jackal/` folder is gone).

384×360, 4×5 cells of 96×72, facing right, paws on row 65:

| Row | Frames | Animation in `enemy_fast.tscn` |
|---|---|---|
| 0 idle | 0–1 | `idle` |
| 1 walk (running) | 4–7 | `walk` |
| 2 attack | 8 crouch, 9 leap, 10 bite | `attack`; the strike lands at 0.225 s, on the leap |
| 3 hurt | 12 | `stagger`, held for the whole stagger |
| 4 death | 16–18 | `death` |

The scene draws it at ×0.75 with `offset` (0, 8): the paws stand on the bandit's floor line (28.5 px below the centre)
and the jackal is about as long on screen as the old one (61 px across idle and walk), so the pack leader (×1.0) is
about 1.4× its length.
