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
| `Block/1.png` | Block (block and parry, D264); the shield spells of H2 (`Assets/FX/Shield/`) are drawn over it | generated (`hero_combat`). **A9 redraw** (2026-10-28, D813 «поправити»): was both fists together at the chest, grey arms without a silhouette and the cape flared out like a wing — under the shield the fists vanished. Now a braced guard: front foot forward, leaning in, the front fist at the chin, the rear fist at the chest, head ducked, the cape close behind; `WeaponView.HAND_GUARD` moved to the new fist (23, 0). A second candidate (both fists at the snout) changed his eye and was not taken |
| `CastPalm/1–2.png` | CastPalmWindup / CastPalmRelease (Healing Palm, D271) | generated: palms together at the chest, eyes closed; one palm pushed forward (`hero_cast`) |
| `CastFire/1–2.png` | CastFireWindup / CastFireRelease (Fire Strike, D271) | generated: crouched low; a deep lunge, fist swept up (`hero_cast`) |
| `CastStorm/1–2.png` | CastStormWindup / CastStormRelease (Electric Strike, D271) | generated: one fist raised to the sky; an arm thrust forward (`hero_cast`) |
| `Raise/1–3.png` | `Raise` (chest pose D404, potion drink D504): 1 → 2 → 3, 3 held | generated (`hero_raise`): `Raise/1` bending to reach down; `Raise/2` (H4) the in-between, made from `Raise/1` (`ON:`) — rising, both hands going up in front of him at snout height; `Raise/3` the overhead hold — both arms raised behind his head, the open hands meeting above it, face visible, feet on row 56, cape hanging (its own frame, no longer `Heavy/1`). The first `Raise/2` idea (the item held low in cupped palms) failed three times: hands right under the snout or a front view (art director, artA1A2). Item anchor in the cell: hands (47, 42) → overhead, resting on the fingertips (34, 2); the palms are x 26–42, rows 3–9 |
| `Death/1–4.png` | not wired yet (MASTER_PLAN A7, D138) | generated (`hero_death`): 1 staggering backwards off balance, front foot up, head upright; 2 collapsed onto both knees, head hanging; 3 falling over backwards at 45°, legs up on the right; 4 lying flat on his back, still (head on the left, snout up). 1 and 3 redone (Sapega: «дивне обличчя» — a swirl and a red slit for the eye): his face named in the pose (`HERO_FACE`), seed 24, picked from 5 and 6 candidates. Feet (lowest pixel) on row 56; play once and hold frame 4 |
| `LungeCut/1–3` | `LungeCutWindup` / `LungeCutMove` / `LungeCutStrike` (H3, D812, wired by skill-art-wire): Dash Strike, Blood Rush, Wind Step — 1 wind-up, 2 the dash (held), 3 the strike | generated (`hero_lunge`, seed 25, `specks=8` drops a 4-px motion line the model drew anyway): 1 crouched low and leaning forward, the front fist at the rear hip; 2 the low dash, both feet off the ground, cape and tail streaming back; 3 a deep lunge, the front arm swept forward at chest height. The first 1 drew a big blade («ready for a wide horizontal cut») — the hands are named empty |
| `ShieldCharge/1–3` | `ShieldChargeWindup` / `ShieldChargeMove` / `ShieldChargeStrike` (H3, wired): Shield Charge — 1 wind-up, 2 the run (held), 3 the bash | generated (`hero_charge`, seed 25): 1 braced, the front forearm raised, fist at chin height; 2 charging at a run, the forearm raised like a shield, the rear arm back; 3 a shoulder bash, the front arm thrust forward. No shield in the frame: the sky shield (H2, `Assets/FX/Shield/magic`) is drawn over the forearm |
| `LeapSlam/1–3` | `LeapSlamWindup` / `LeapSlamMove` (held through the whole leap) / `LeapSlamStrike` (H3, wired): Heaven's Anvil, Dune Quake — 1 wind-up, 2 in the air (held up and down), 3 the slam | generated (`hero_leap`, seed 25): 1 crouched deep to spring, fists low in front; 2 at the top of the jump, knees tucked, both fists overhead — made from `Heavy/1` (`ON:`), so his head is as small as in `Heavy/1` (from `Walk/1` the model drew a hammer, then a half-turn with a small head); 3 the slam, one knee down, both fists on the ground in front. Feet on row 56 in all three, including the airborne frame (as `Jump/*`) |

**H3 wiring** (done by skill-art-wire as suggested below; the hand points are `WeaponView.CAST_POSES`, also used in `CAST_MOVE`) (all three folders, 64×64, the artist's 28 colours, feet on row 56, empty hands; faces right, `flip_h` for the
left). Suggested `Player.tscn` animations: `<Pose>Windup` = frame 1, `<Pose>Move` = frame 2, `<Pose>Strike` = frame 3, each
one held frame like `CastFire*`; in `skills.json` → `cast.windup_pose` / `move_pose` / `release_pose`. The weapon is
`WeaponView`'s overlay (no per-weapon frames yet: a sword / dagger / mace / halberd / dual library falls back to these base
frames, `Player.body_animation`). Hand points for `CAST_POSES`-style entries, measured on the front fist — texture px → world
px from `WeaponMount` = ((x − 32) × 1.5, (y − 32) × 1.5); the angle is a suggestion (0 up, + forward):

| Frame | Fist (texture) | World | Angle |
|---|---|---|---|
| `LungeCut/1` | (52, 39) | (30, 10.5) | 230 (blade low behind) |
| `LungeCut/2` | (53, 35) | (31.5, 4.5) | 230 |
| `LungeCut/3` | (54, 33) | (33, 1.5) | 90 (forward) |
| `ShieldCharge/1` | (52, 31) | (30, −1.5) | 20 (`guard_angle`) |
| `ShieldCharge/2` | (54, 34) | (33, 3) | 20 |
| `ShieldCharge/3` | (54, 31) | (33, −1.5) | 60 |
| `LeapSlam/1` | (44, 41) | (18, 13.5) | 230 |
| `LeapSlam/2` | (40, 13), between the two fists | (12, −28.5) | −20 (`smash_from`) |
| `LeapSlam/3` | (52, 52) | (30, 30) | 165 (`smash_to`) |

The sky shield over `ShieldCharge/*`: its `Block/1` placement (FX README, H2) moved by the fist's offset from `Block/1`'s
guard fist (≈ (47, 32), `HAND_GUARD`): +5 / +7 / +7 texture px right and 0 / +2 / 0 down (×1.5 in world px). Left for later:
the per-weapon variants of the three poses (`Weapons/<weapon>/LungeCut|ShieldCharge|LeapSlam`, by `hero_weapon_*` as their
`Heavy/1–3` were made).
