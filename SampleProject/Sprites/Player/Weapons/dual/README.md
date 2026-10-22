# Kusakam dual-wielding a sword and a dagger (BACKLOG 42, art A3, D267)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_dual`
with the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the
Lightning 4-step LoRA. The first frame is the sword set's `sword/CombatIdle/1.png` with the model's short dagger
from `Attack1/1` pasted into his raised far fist (`Scripts/Tools/dual_fixups.py`; two model attempts shortened the
sword too); run, air and the sword swings (`Attack1`, `Attack3`) are the sword set's own frames with only the
dagger added (`ON:`); the dagger stabs, heavy and block are made from the first frame or from already good frames
of this set (`FROM:`). The artist's colours only.

Wired: `Player.tscn` → `AnimationPlayer` library `dual_sword_dagger` (sword in hand + dagger in the off hand;
`Resources/Player/WeaponAnimations/dual_sword_dagger.tres`, written by `Scripts/Tools/weapon_libraries.py`); its `Hurt` is
its own `Hurt/1` below (`cloud/art-fixes-wire`).

Palette swap (BACKLOG 42): after the tool and the fixups run `python Scripts/Tools/weapon_key_fixups.py` — it moves the
armour and eye pixels that share the blade key colours 2 RGB steps off the key, so `Shaders/weapon_palette.gdshader`
recolours only the weapon metal.

- Cell **96×96**, the same as the sword set: the hero's body sits where it does in the sword frames, feet on row
  **88** (= row 56 of the 64×64 frames + 32). Faces right; flip for the left.
- Sword in the near (front) hand, dagger in the far (back) hand. Both blades in the sword's metal key colours
  (`#F8F8E4`, `#C2C2C2`, `#87878C`, dark outline) with brown grips — the colours a palette-swap shader recolours
  per item (BACKLOG 42). The dagger is short everywhere (about 9–13 px of blade, the sword about 20–24 px).
- 4-swing alternating combo: `Attack1` sword, `Attack2` dagger, `Attack3` sword, `Attack4` dagger finisher.

| Folder | Frames | Pose |
|---|---|---|
| `CombatIdle/1–4` | 4 | the sword set's stance (sword low at the hip) + short dagger in the raised far fist; 2–3 = breathing (`BOB:76`) |
| `Run/1–7` | 7 | the sword set's run + the dagger in a reverse grip at his hip; feet follow the bounce (rows 88–90, same as the sword) |
| `Air/1–3` | 3 | the sword set's jump rise, apex, fall + reverse-grip dagger |
| `Attack1/1–3` | 3 | sword: the sword set's overhead slash (`sword/Attack1`) + dagger |
| `Attack2/1–3` | 3 | dagger stab: coil (full-length sword low at the hip, dagger drawn back at the shoulder), straight stab with the far hand, coil again (frame 3 = frame 1) |
| `Attack3/1–3` | 3 | sword: the sword set's rising slash (`sword/Attack2`) + dagger |
| `Attack4/1–3` | 3 | dagger finisher: the `Attack2/1` coil, a long fencing lunge (back leg stretched, sword trailing low behind), the coil again |
| `Heavy/1–3` | 3 | the sword set's overhead wind-up (`sword/Heavy/1`) + dagger low at the belly, swung forward, a low forward sweep with the sword (dagger hidden; made `ON:` frame 2, same maroon cape) |
| `Block/1` | 1 | sword up-forward and dagger up-back crossed in a small X just above the fists, in front of the chest |
| `Hurt/1` | 1 | recoil from a hit to the chest, head thrown back, staggering back on one foot; the sword low pointing down and back, the short dagger pointing up and forward in the far fist (added later, see below) |

**`Hurt/1` added later (remaining_work Art 3)** by `Scripts/Tools/comfy_art_fixes.py dual_hurt` (same model, seed 52)
from this set's `CombatIdle/1` — both blades already the right size there — then `weapon_key_fixups.py`. Feet on
row 88. The earlier three attempts (from other frames: dagger flung back, reverse grip, knife pressed to the chest)
all drew a sword-length second blade. So did this one (19 px of blade, normal grip, the two blades read as two swords
in an X), so the job's `post=dagger_trim` moves the model's outlined point 7 px back along the blade toward the guard,
the way `dual_fixups.py --after` trims `Attack4/2`, and narrows the model's flat end to a 2-px outlined point: 9 px
of blade now, the same as `CombatIdle/1`; the sword is untouched. Then `weapon_key_fixups.py` again. The grip stays
the model's normal grip, blade up and forward, as the dagger is held in `CombatIdle`.

Fixups: `python Scripts/Tools/dual_fixups.py` before `comfy_sprite.py hero_weapon_dual` (builds `CombatIdle/1`), and
`python Scripts/Tools/dual_fixups.py --after` after it — `Attack4/2`'s dagger came out sword-length in all three
attempts, so its blade is trimmed to 10 px. In `Block/1` the two fists overlap at the crossing.
