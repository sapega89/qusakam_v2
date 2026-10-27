# Tower-shield guard — the elite shield-bearer (D652, D693, D711)

**AI-generated** with the local ComfyUI: **Qwen-Image-Edit-2511** (Alibaba Qwen, Apache 2.0; GGUF Q5_K_M by unsloth)
and its Lightning LoRA (lightx2v, Apache 2.0). A Steam release has to disclose AI-generated content.

| Sheet | Made by | From |
|---|---|---|
| `sheet.png` | `Scripts/Tools/comfy_sprite.py big_tower_guard` (pick: candidate 4, seed 145, three-quarter, mirrored — D693) | the hero's artist frame `SampleProject/Sprites/Player/Walk/1.png` as the style reference |
| `sheet_noshield.png` | `Scripts/Tools/comfy_art_fixes.py noshield_tower` (seed 200, B200) — each frame is `sheet.png`'s own cell with only the tower shield removed; palette of `sheet.png`, feet on the source cell's row | `sheet.png`, cell by cell |

Both sheets: 4×5 cells of 96×96, facing right, the same frame map (the scene's `hframes = 4`, `vframes = 5`):

| Frames | Animation | `sheet.png` | `sheet_noshield.png` |
|---|---|---|---|
| 0–1 | idle | behind the shield | the same stance, front hand an empty fist |
| 4–7 | walk | shield in front | the same steps, no shield |
| 8–10 | attack | sword raised over the shield → thrust past its edge → back to guard | the same three, no shield |
| 12 | hurt / stagger | the shield knocked aside | the same recoil, no shield |
| 16–18 | death | 16–17 have no shield already; 18 lies on the shield | 16–17 copied as is; 18 lies on bare ground |

Empty cells (2, 3, 11, 13–15, 19) stay empty in both. `sheet_noshield.png` is for the guard after his shield
is broken (B200); the shield's shards are `SampleProject/Assets/FX/Hit/shield_break_1–4.png`.
