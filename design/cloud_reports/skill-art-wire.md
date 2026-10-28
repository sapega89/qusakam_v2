---
type: report
tags: [cloud, skills, v2, art, combat]
branch: cloud/skill-art-wire
---

# cloud/skill-art-wire: the movement skills' own art, wired (H3, D812, D828)

**Summary**
- **Done:** the six movement skills have their own poses and effects. The poses are `LungeCut` / `ShieldCharge` / `LeapSlam` Windup/Move/Strike, in `Player.tscn` and in `skills.json`. Leaps hold `LeapSlamMove` the whole way up and down. The effects are in `MoveSkill.tscn`: dash trail, sky shield over Shield Charge, Blood Rush arc + drain, Wind Step streak, Heaven's Anvil pillars, Dune Quake waves and the slam ring. No borrowed Skyfall beam or LandingDust is left.
- **D279 "no shared frames" is on for them** (`verify_skill_fx` [1]). The shared move layer is the dash trail for all dashes and the slam ring for both slams. The FX README calls for that sharing, and the test checks the layer separately.
- **Not done:** per-weapon variants of the three poses (next art batch). Dash Strike and Shield Charge still have **no strike art of their own**: they play the hero's swing arc / punch. The check passes because those belong to no skill.
- **Weapons:** the WeaponView overlay draws over the base poses at the README's fist points. With an iron sword it reads well: blade low behind in the wind-ups, upright beside the shield, forward on the cuts, overhead in the leap. On `LeapSlamStrike` it points into the ground and is half hidden. Shot `design/shots/skill_art_wire.png`.
- **D-ID text:** below (placeholder D-SAW). **B rows fixed:** none.
- **Full suite:** `SUITE: 4 FAIL in 19 min 29 s, J=4`. `verify_archer` and `verify_camera_transitions` passed on re-run. `verify_difficulty` (17 FAIL) and `verify_lab_boss` (2 FAIL) fail the same way on `origin/feature/backlog` without this branch: balance numbers this diff does not touch.

## D-ID text (for the orchestrator; placeholder D-SAW)

| ID | Kind | Text |
|---|---|---|
| D-SAW | ROUTINE CALL | **The movement skills' own art, wired** (H3; D812, D828, D279; `cloud/skill-art-wire`).<br><br>**Poses.** Dash Strike, Blood Rush and Wind Step use `LungeCut*`. Shield Charge uses `ShieldCharge*`. Heaven's Anvil and Dune Quake use `LeapSlam*`. Each pose has Windup → Move → Strike, one held frame each. A leap now holds `LeapSlamMove` both up and down (the Jump/Fall switch is gone). `move_pose` is now required with `move`.<br><br>**Effects.** Every dash trails `Smear/dash` behind the hero: 1 ↔ 2 while he moves, 3 when he stops. Shield Charge reuses it. Both slams show `Smear/slam_ring` on landing.<br><br>**Shield Charge** always carries Shield Block's magic shield over its poses. It is not tied to having learned Shield Block, because it is part of the skill's look. The shield drops in during the wind-up, holds through the run and the bash, and fades 0.3 s after the strike.<br><br>**Blood Rush** shows its drain from the drained target to the hero's chest. A new `EventBus.skill_drained` carries it.<br><br>**Strike art.** The skills' own strike art (blood arc, wind streak) plays at 20 fps at the hero's scale. The plain swing smears play at 30 fps and ×1.3.<br><br>**D279 for movement skills.** A skill's own frames are everything it plays except the move layer (dash trail, slam ring), which the move kind shares. Dash Strike's own frames are the hero's swing arc and Shield Charge's are the punch plus the sky shield. They still lack their own strike art (next art batch, with the per-weapon pose variants). |

## How it works (file:line)
- `SampleProject/Player.tscn`: 9 animations `LungeCut|ShieldCharge|LeapSlam` + `Windup|Move|Strike` (one held frame, offset 0, length 0.3), in `AnimationLibrary_player`. The weapon libraries have none, so `Player.body_animation` falls back to these.
- `SampleProject/Resources/Data/skills.json`: the poses for the 6 rows. The `_schema` text now says `move_pose` is required with `move`.
- `SampleProject/Scripts/Player/Components/PlayerCombat.gd:618` `_start_move`: plays `move_pose` for both kinds and calls `_cast_fx.move()` (:632). Line :641: in the air it holds the pose.
- `SampleProject/Scripts/FX/SkillCastFX.gd:21` `move()`: an empty virtual; only `MoveSkillFX` shows something.
- `SampleProject/Scripts/Player/Components/WeaponView.gd:49`: `CAST_POSES` for the 9 frames (the README's fist points and angles). Line :224: `CAST_MOVE` uses them too (it used to be the rest pose).
- `SampleProject/Scenes/FX/Skills/MoveSkill.tscn`: markers `Hand`, `Art` (×1.5), `Feet`, `Chest`, `ShieldWindup/Move/Strike` (Block's magic placement + 5/7/7 px right, 0/2/0 down, ×1.5, under Player's −13.5). Sprites `DashTrail` (behind the hero), `SkyShield` (Glow, unshaded), `Drain`, `PillarBack/Front`, `WaveBack/Front`, `SlamRing`. All anchors are from `Assets/FX/README.md`.
- `SampleProject/Scripts/FX/MoveSkillFX.gd`: `RELEASE` maps each skill to its strike. `sprites()` lists the nodes a skill plays (used by verify_skill_fx). Waves tween to ±`move_reach` in 0.4 s. The drain is rotated and stretched to the target.
- `SampleProject/Scenes/FX/SlashTrail.tscn` + `Scripts/FX/SlashTrail.gd`: animations `blood_rush` (right-anchored on `arc`'s edge) and `wind_step` (grows from the grip like `thrust`).
- `SampleProject/Scripts/Core/EventBus.gd:228` `skill_drained`, emitted in `SkillCombatExecutor.apply_move_riders` (:53).

## Tests (RESULT lines)
- `verify_skill_fx`: ALL PASS. [1] now runs D279 for all 6. Each one plays its move layer, its own frames are non-empty and shared with no skill, and the 6 move-layer frames are no skill's own. The borrowed-effect exemption is gone.
- `verify_skill_moves`: ALL PASS. The pose checks are now exact: `LungeCut*` in [1]; `ShieldCharge*` in [4] (was "Run somewhere in it"); `[LeapSlamWindup, LeapSlamMove, LeapSlamStrike]` in [7] and [9]. New in [5]: the drain wisp is visible and its far end is 0.0 px from the target.
- `verify_skill_casts`, `verify_skill_rules`, `verify_hero_feet`, `verify_combat_player`, `verify_scripts_compile`: ALL PASS.
- `verify_weapon_animations`: 1 FAIL on the first run ("each strike frame shows with the hitbox on", `[false, true, true]`, the sword's first combo swing, a timing check this diff does not touch). ALL PASS on the re-run.
- Full suite: see the summary.

## Capture
`SampleProject/UI/capture_skill_art_wire.gd` (xvfb) → `design/shots/skill_art_wire.png`. It has 12 rows (6 skills bare-handed, then with an iron sword) and 3 columns (wind-up, mid-move, strike).
- All poses and effects show.
- The back Heaven's Anvil pillar (−96 px) and the far ends of the Dune Quake waves (±240 px) fall outside the 480-px crop. A headless check shows both pillars visible at ±96.
- The old `capture_skill_moves.gd` no longer casts. It lacks `awaken_skills()` (D815). It is left as is, and this capture replaces it.

## Open
- Per-weapon variants `Weapons/<weapon>/LungeCut|ShieldCharge|LeapSlam` (next art batch).
- Own strike art for Dash Strike and Shield Charge (a bash impact).
- Dedicated sounds (still reused files, skills-v2-move).
