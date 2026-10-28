# Kusakam with a one-handed mace (BACKLOG 42, art A3)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_mace`
with the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the
Lightning 4-step LoRA. The first frame is the sword set's `sword/CombatIdle/1.png` with the sword replaced by a
mace; the attacks, block and hurt are made from that frame (`Heavy/1` from `Attack1/1`); run and air from the
artist's own frames (`Run/N`, `Jump/2–3`, `Fall/2`) with only the mace added. The artist's colours only (27 of his 28).

Wired: `Player.tscn` → `AnimationPlayer` library `mace` (`Resources/Player/WeaponAnimations/mace.tres`, written by
`Scripts/Tools/weapon_libraries.py`).

Palette swap (BACKLOG 42): after the tool and the fixups run `python Scripts/Tools/weapon_key_fixups.py` — it moves the
armour and eye pixels that share the blade key colours 2 RGB steps off the key, so `Shaders/weapon_palette.gdshader`
recolours only the weapon metal.

- Cell **96×96**, the same as the sword set: the hero's body sits where it does in the sword frames, feet on row
  **88** (= row 56 of the 64×64 frames + 32). Faces right; flip for the left.
- The mace head is drawn in the sword's metal key colours (`#F8F8E4`, `#C2C2C2`, `#87878C`, dark outline) on a
  brown wooden handle — the colours a palette-swap shader recolours per item (BACKLOG 42). The handle length
  varies between frames (the model draws a mace, not a fixed sprite); it is longest in the overhead poses.
- **Hand fixes after the tool** (art review): `Scripts/Tools/mace_fixups.py` pastes one fixed mace head (the ball
  from `Run/2`) on all seven run frames, and trims the handle behind the rear hand in `Heavy/1`. Run it after every
  `comfy_sprite.py hero_weapon_mace`, which rewrites all frames.
- Attacks are overhead smashes and swings that end with the head on or near the ground.

| Folder | Frames | Pose |
|---|---|---|
| `CombatIdle/1–4` | 4 | combat stance, mace forward and up; 2–3 = breathing (`BOB:76`) |
| `Run/1–7` | 7 | the artist's run (no `Run/2`, as for the sword); feet follow his bounce (rows 88–90, same as the sword) |
| `Air/1–3` | 3 | jump rise, apex, fall (from `Jump/2`, `Jump/3`, `Fall/2`) |
| `Attack1/1–3` | 3 | mace raised over the head, smash forward, head just above the ground |
| `Attack2/1–3` | 3 | mace low, rising swing, mace straight up |
| `Attack3/1–3` | 3 | mace far back behind the head, full forward smash, head slammed on the ground (finisher) |
| `Heavy/1–3` | 3 | two-handed overhead wind-up, swing, head slammed on the ground |
| `Block/1` | 1 | mace upright before the face |
| `Hurt/1` | 1 | recoil, head thrown back, mace flung back |
| `LungeCut/1–3` | 3 | H3 (below): crouched, mace low forward-down, the ball by the front foot; the dash, the same; the cut, mace level straight forward at chest height |
| `ShieldCharge/1–3` | 3 | H3: braced, mace level forward at chin height; the run, the same; the bash, mace forward-up, the ball above the snout |
| `LeapSlam/1–3` | 3 | H3: crouched to spring, mace low forward-down; in the air, mace overhead in both hands (from `Heavy/1`); the slam, kneeling, the ball on the ground in front |

**H3 movement-skill poses (D812, not wired)** — `Scripts/Tools/comfy_sprite.py hero_weapon_mace_h3` (same model, seed 52),
each frame `ON:` the hero's bare-handed pose (`SampleProject/Sprites/Player/LungeCut|ShieldCharge|LeapSlam/N`, the 64×64
frame at (16, 32) of the 96×96 cell) with only the mace added; `LeapSlam/2` `ON:` this set's `Heavy/1`. The smooth ball of
`MACE_BALL` (the flanged wording drew spikes and hammers), `MACE_SHORT` for the size, the empty front hand named in
`LungeCut/1`, the hero's face named in `ShieldCharge/1–2`. Then `python Scripts/Tools/h3_eye_fixups.py` (the
`ShieldCharge/2` eye came out a target — copied from the hero's own frame, one row lower), then `weapon_key_fixups.py`
(`MANUAL`: the `LungeCut/1–2` ball, which touches the body, back to the key; eye glint, chest plates, belts and boots off
the key). Feet on row 88, the artist's colours. Contact sheet: `design/shots/h3_weapon_variants_2.png`.

- Rejected: `ShieldCharge/1` «forward and up at a steep angle … clear of his face» — the ball covered the snout; kept the
  level wording of `ShieldCharge/2` (as the dagger).
- The handle runs back past the fist in `LungeCut/1–2` and `ShieldCharge/1` (held mid-handle); the ball is 10–12 px.
