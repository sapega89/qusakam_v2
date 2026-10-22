# Desert bandit archer — the ranged enemy (BACKLOG 40, art A4)

**AI-generated** by `Scripts/Tools/comfy_sprite.py bandit_archer`: the local ComfyUI with **Qwen-Image-Edit-2511**
(Alibaba Qwen, Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0). Made from the
melee bandit's own frames (`../bandit/sheet.png`): the scimitar replaced by a short wooden bow and a quiver added;
the walk, hurt and death are the bandit's frames with only the weapon changed (`ON:`), the attack is made from the
first frame. 16-colour palette, feet on row 56 like the bandit. A Steam release has to disclose AI-generated content.

Not wired into a scene yet.

`sheet.png` — 256×320: 4 columns × 5 rows of **64×64** cells, facing right, feet on row **56** in every cell (the
same cell, scale and feet line as `bandit/sheet.png`, so `default_enemy.tscn`'s ×1.5 and offset −6 fit;
`hframes = 4`, `vframes = 5`).

| Row | Frames | Content |
|---|---|---|
| idle | 0–1 | standing with the bow upright; 1 = breathing (`BOB`) |
| walk | 4–7 | the bandit's walk |
| attack | 8–11 | raise the bow (8), full draw (9), hold the draw (10), release — empty bow, hand flung back (11). Fire the arrow on frame 11; nocked arrowhead tip at about (56, 30) in the cell on 9–10 |
| hurt | 12 | recoil (the same picture as death 16) |
| death | 16–19 | recoil, standing slump, collapse, lying on his back |

Unused cells: 2–3, 13–15.
