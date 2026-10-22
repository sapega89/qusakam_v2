# Kusakam with a one-handed sword (BACKLOG 42, art A3)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_sword`
with the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the
Lightning 4-step LoRA, from the artist's own frames in `SampleProject/Sprites/Player` (`Walk/1.png`; the run and
jump frames from `Run/N`, `Jump/2–3`, `Fall/2`, with only the sword added). The artist's 28 colours.

Wired: `Player.tscn` → `AnimationPlayer` library `sword` (in the scene).

Palette swap (BACKLOG 42): after the tool and the fixups run `python Scripts/Tools/weapon_key_fixups.py` — it moves the
armour and eye pixels that share the blade key colours 2 RGB steps off the key, so `Shaders/weapon_palette.gdshader`
recolours only the weapon metal.

- Cell **96×96** (the sword reaches past 64×64). The artist's 64×64 frame sits in it at offset **(16, 32)**, so
  the hero's body is in the same place as in the 64×64 frames: feet on row **88** (= row 56 + 32). Faces right;
  flip for the left.
- Same sword in every frame (a short straight steel blade, cross-guard, brown grip), held in the near hand.

| Folder | Frames | Pose |
|---|---|---|
| `CombatIdle/1–4` | 4 | combat stance, sword forward and up; 2–3 = breathing (`BOB:76`) |
| `Run/1–7` | 7 | the artist's run with the sword raised; feet follow the artist's bounce (rows 88–90). The artist's `Run/2` with a sword came out dark three times — dropped |
| `Air/1–3` | 3 | jump rise, apex, fall (from `Jump/2`, `Jump/3`, `Fall/2`) |
| `Attack1/1–3` | 3 | overhead wind-up, slash forward, follow-through low |
| `Attack2/1–3` | 3 | low wind-up, rising slash, blade straight up |
| `Attack3/1–3` | 3 | blade back, full lunge thrust, low sweep (finisher) |
| `Heavy/1–3` | 3 | two-handed overhead wind-up, swing, blade tip on the ground |
| `Block/1` | 1 | sword upright before the face |
| `Hurt/1` | 1 | recoil, head thrown back, sword low |
