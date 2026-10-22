# Kusakam with a dagger (BACKLOG 42, art A3)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_dagger`
with the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the
Lightning 4-step LoRA. The first frame is the sword set's `sword/CombatIdle/1.png` with the sword replaced by a
dagger; the attacks, block and hurt are made from that frame; run and air from the artist's own frames
(`Run/N`, `Jump/2–3`, `Fall/2`) with only the dagger added. The artist's colours only (24 of his 28).

Wired: `Player.tscn` → `AnimationPlayer` library `dagger` (`Resources/Player/WeaponAnimations/dagger.tres`, written by
`Scripts/Tools/weapon_libraries.py`). No `Heavy`: the heavy plays `Attack3` (wind-up `Attack3/1`, strike `Attack3/2–3`);
`Attack2` is `Attack2/1` + `Attack1/2–3`.

Palette swap (BACKLOG 42): after the tool and the fixups run `python Scripts/Tools/weapon_key_fixups.py` — it moves the
armour and eye pixels that share the blade key colours 2 RGB steps off the key, so `Shaders/weapon_palette.gdshader`
recolours only the weapon metal.

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
| `Attack2/1–3` | 3 | crouch; rising upward slash, the dagger forward and up at shoulder height; standing tall, the dagger raised before the face, blade up (2–3 added later, see below) |
| `Attack3/1–3` | 3 | coiled, deep lunging stab, recovery with the dagger at the hip (finisher) |
| `Block/1` | 1 | dagger crosswise before the face |
| `Hurt/1` | 1 | recoil, head thrown back |
| `Heavy/1–3` | 3 | wind-up: the dagger drawn back behind his head, the other hand open forward; heavy downward stab, blade down-forward at knee height; recovery, crouched, dagger before the chest (added later, see below) |

**Added later (remaining_work Art 3): `Heavy/1–3` and `Attack2/2–3`** — `Scripts/Tools/comfy_art_fixes.py
dagger_heavy dagger_attack2` (same model), each made from `Attack1/2` — the stab whose dagger is already short (the
old attempts from the first frame drew a sword) — then `weapon_key_fixups.py` as above. Feet on row 88, 96×96, the
artist's colours. Wired (`cloud/art-fixes-wire`): the `dagger` library plays them as `HeavyWindup`/`HeavyStrike` and
`Attack2`.
- Rejected: `Heavy/1` with the dagger raised over the head (seeds 52, 53 — a sword-length blade, a second knife in the
  front hand), a "coiled behind the hip" wind-up (identical to the stab) and an ice-pick grip (a spike grew on the
  head). The kept wind-up (seed 54) had a stub of the stab's blade left in the front hand; a second pass from that
  frame (seed 53) removed it (seed 52 grew a white patch on the head instead).
- `Attack2/3`: a grey squiggle the model drew beside the fist is erased (fixed rectangles in the tool); the eye glint
  there, `Heavy/2`'s eye glint and `Heavy/3`'s belt pixels that share the blade key colours are moved to the body
  twin (`twin=` in the tool), so the palette swap recolours only the blade.
- The blade is 16–20 px here, the same as `CombatIdle` / `Block`.

Earlier history: three attempts at `Heavy` (from the first frame, from `Attack1/1`, from `Attack2/3`) and six at
`Attack2/2–3` (from `Attack2/1`) all drew a second dagger or a sword-length blade.

Isolated single pixels (no 8-neighbour, keying dirt) are dropped from every frame by the tool (`Hurt/1` had four).
