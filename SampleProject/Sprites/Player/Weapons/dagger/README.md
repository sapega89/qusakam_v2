# Kusakam with a dagger (BACKLOG 42, art A3)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_dagger`
with the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the
Lightning 4-step LoRA. The first frame is the sword set's `sword/CombatIdle/1.png` with the sword replaced by a
dagger; the attacks, block and hurt are made from that frame; run and air from the artist's own frames
(`Run/N`, `Jump/2–3`, `Fall/2`) with only the dagger added. The artist's colours only (24 of his 28).

Not wired into `Player.tscn` yet.

- Cell **96×96**, the same as the sword set: the hero's body sits where it does in the sword frames, feet on row
  **88** (= row 56 of the 64×64 frames + 32). Faces right; flip for the left.
- The blade is drawn in the sword's metal key colours (`#F8F8E4`, `#C2C2C2`, `#87878C`, dark outline) with a brown
  grip — the colours a palette-swap shader recolours per item (BACKLOG 42). The blade length varies 9–15 px
  between frames (the model draws a dagger, not a fixed sprite).
- Attacks stab instead of arcing.

| Folder | Frames | Pose |
|---|---|---|
| `CombatIdle/1–4` | 4 | combat stance, dagger low and forward; 2–3 = breathing (`BOB:76`) |
| `Run/1–7` | 7 | the artist's run (no `Run/2`, as for the sword); feet follow his bounce (rows 88–90, same as the sword) |
| `Air/1–3` | 3 | jump rise, apex, fall (from `Jump/2`, `Jump/3`, `Fall/2`) |
| `Attack1/1–3` | 3 | dagger drawn back at the hip, quick straight stab, pull back |
| `Attack2/1–3` | 3 | crouch, upward stab, dagger raised high |
| `Attack3/1–3` | 3 | coiled, deep lunging stab, low recovery (finisher) |
| `Block/1` | 1 | dagger crosswise before the face |
| `Hurt/1` | 1 | recoil, head thrown back |

**Missing: `Heavy`.** Three attempts (from the first frame, from `Attack1/1`, from `Attack2/3`) all drew a second
dagger or a sword-length blade.
