# Kusakam — the hero's frames

`Walk/` (3) and `Run/` (8) are the **artist's frames** (bought; the artist no longer works on the game) — the style
reference for everything else (D239).

The rest are **new frames made from the artist's own frame** `Walk/1.png` by `Scripts/Tools/comfy_sprite.py hero_*`
(D239: the local ComfyUI, **Qwen-Image-Edit-2511**, Apache 2.0, with the artist's frame as the reference), brought to
64×64 in the artist's 28 colours with the feet on row 56. A Steam release has to disclose AI-generated content.

| Folder | Animation in `Player.tscn` | How |
|---|---|---|
| `Idle/2.png` | Idle (with `Walk/1`) | the artist's frame, head and torso one pixel lower — breathing |
| `Idle/3.png` | Idle (between `Walk/1` and `Idle/2`) | the artist's frame, only the head one pixel lower (`BOB:30`, D262) |
| `Jump/3.png`, `Fall/2.png` | Apex (top of the jump → tipping into the fall) | generated (`hero_smooth`, D262) |
| `Land/1.png` | Land (after a fall, standing still) | generated: a deep landing squat (`hero_smooth`, D262) |
| `Jump/1–2.png` | Jump | generated: the crouch before the take-off, rising in side view |
| `Fall/1.png` | Fall | generated: arms up, cape up |
| `Dash/1–3.png` | Roll (the dash; name kept for the code) | Sapega: no rolling or spinning. 1 push off low (0–0.05 s), 2 mid-dash with the cape streaming back (held to 0.25 s), 3 the braking stop (to 0.3 s); feet on row 56, offset 0 (integrator-14) |
| `Roll/1–6.png` | not used since round 14 (kept) | the old roll: generated duck and curled ball; the ball turned 90°/180°/270° |
| `Climb/1–2.png` | Climb | generated from behind, alternating arm and leg |
| `Meditate/1–2.png` | Meditate (Canyon summit cutscene, D257) | generated: sitting cross-legged, eyes closed; frame 2 = BOB breathing (`hero_meditate`) |
| `Hurt/1.png` | Hurt (stagger, D264) | generated: recoiling from a hit to the chest (`hero_combat`) |
| `Heavy/1–2.png` | HeavyWindup / HeavyStrike, AttackSmash (mace) | generated: both empty fists raised overhead; crouched, fists swung down low (`hero_combat`) |
| `Block/1.png` | Block (block and parry, D264) | generated: fists raised before the face, braced (`hero_combat`) |
| `CastPalm/1–2.png` | CastPalmWindup / CastPalmRelease (Healing Palm, D271) | generated: palms together at the chest, eyes closed; one palm pushed forward (`hero_cast`) |
| `CastFire/1–2.png` | CastFireWindup / CastFireRelease (Fire Strike, D271) | generated: crouched low; a deep lunge, fist swept up (`hero_cast`) |
| `CastStorm/1–2.png` | CastStormWindup / CastStormRelease (Electric Strike, D271) | generated: one fist raised to the sky; an arm thrust forward (`hero_cast`) |
| `Raise/1.png`, `Raise/3.png` | not wired yet (chest / item pickup, BACKLOG 33) | generated (`hero_raise`): `Raise/1` bending to reach down; `Raise/3` the overhead hold — both arms raised behind his head, the open hands meeting above it, face visible, feet on row 56, cape hanging (its own frame, no longer `Heavy/1`). **`Raise/2` (the item held low in cupped palms) is missing**: three generations put the hands right under the snout or turned him to the front (art director, artA1A2). Item anchor in the cell: hands (47, 42) → overhead, resting on the fingertips (34, 2); the palms are x 26–42, rows 3–9 |
| `Death/1–4.png` | not wired yet (MASTER_PLAN A7, D138) | generated (`hero_death`): 1 staggering backwards off balance, front foot up, head upright; 2 collapsed onto both knees, head hanging; 3 falling over backwards at 45°, legs up on the right; 4 lying flat on his back, still (head on the left, snout up). 1 and 3 redone (Sapega: «дивне обличчя» — a swirl and a red slit for the eye): his face named in the pose (`HERO_FACE`), seed 24, picked from 5 and 6 candidates. Feet (lowest pixel) on row 56; play once and hold frame 4 |
