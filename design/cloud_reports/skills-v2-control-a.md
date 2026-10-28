---
type: report
tags: [cloud, skills, v2, combat]
branch: cloud/skills-v2-control-a
---

# cloud/skills-v2-control-a: skills v2 slice 6, first half (control and finishers)

**Summary**
- **Done:** Rising Slash, Ground Slam, Sweeping Arc, Shield Bash and Stone Palm are built and can be learned. Each row lost `planned` and `draft`. A new `control` block in `skills.json` holds the numbers, code reads it, and `_schema` documents it. 17 planned actives are left.
- **New enemy states, built on what exists:** `DefaultEnemy.launch` (a stagger plus an upward jump of the existing `jump_speed`) and `DefaultEnemy.knock_down` (a stagger in the stagger pose; a boss is only stunned). Guard damage goes through the existing poise bar (`take_poise`, D777). Knockback, stun and enemy stamina are left as they are.
- **No new art.** All five use a new `ControlSkill.tscn` that borrows the hero's swing smears and the slams' impact ring. The poses are existing frames. The art list per skill is below.
- **Tests:** a new `verify_skills_control_a` (7 sections, **ALL PASS**). It fails on the base branch, where the 5 skills are planned and refuse to cast. Updated: `verify_skill_rules` [11] (17 planned; the 5 built; the planned example is now Soul Harvest), `verify_skill_fx` [1] (control skills use the borrowed effect), `verify_skill_screen` [2] (the coming-later example is now Radiant Flare). The full-suite line is in **Tests**.
- No B rows fixed. The D-ID text is below (placeholder D-sv2ca1).
- **For the integrator:** slices 4, 5 and control-b change the same planned count (`verify_skill_rules` [11]) and the coming-later examples. After all four merge, set the count to the number that is really left, and pick an example that is still planned.

## D-ID text (for the orchestrator; placeholder D-sv2ca1)

| ID | Kind | Text |
|---|---|---|
| D-sv2ca1 | ROUTINE CALL | **Control skills, first half: Rising Slash, Ground Slam, Sweeping Arc, Shield Bash, Stone Palm** (skills v2 slice 6a; D535, D777, D495, D207; `cloud/skills-v2-control-a`).<br><br>**Data.** A `control` block in `skills.json`: `hits` (none = the strike zone, D142; `first` = the nearest enemy in front; `front` + `reach` = everyone in front up to `reach` px from the hero's body; `around` + `reach` = everyone within `reach` px on both sides), `launch` s, `knockdown` s, `poise_x`. A control skill needs a target in its own area to start, so Ground Slam starts with an enemy only behind the hero. With no target it does not start and costs nothing.<br><br>**Launch.** A light enemy flies up for `launch` s and lands at the same height. Light means not large, not armoured (tank, D208), not flying, and not a boss or elite that is immune to knockback. Its wind-up is broken (a stagger) and it shows its stagger pose. A heavy enemy only takes the damage.<br><br>**Knocked down.** The enemy is down for `knockdown` s in its stagger pose, and its wind-up is broken even after the tell. A boss is not knocked down: it only gets the stun, which its armour and a committed wind-up ignore (B134).<br><br>**Guard damage.** `poise_x` is guard damage measured in the hero's heavy attacks (PlayerCombat.POISE_HEAVY 5), with the poise passives (D284). It drains the existing poise bar (D777), and a full bar staggers. The shield-bearer's shield takes any skill hit, as before (D616).<br><br>**Provisional numbers** (D808 drafts):<br>• Rising Slash: launch 0.8 s (≈ 80 px up), everyone in the strike zone.<br>• Ground Slam: knockdown 1.2 s, everyone within 140 px on both sides.<br>• Sweeping Arc: knockdown 1.0 s, everyone up to 160 px in front.<br>• Shield Bash: 2.5 heavies of guard damage plus the 0.4 s stun to the first enemy. The stun breaks a wind-up before its tell. A worn guard breaks, and the break breaks a wind-up even after the tell.<br>• Stone Palm: 3 heavies of guard damage plus a 0.3 s stun to the first enemy.<br><br>SP, damage and scaling are unchanged from slice 1. Each skill has 2 synergies with passives of its own tree. The names keep `[DRAFT]` as the movement skills do (D812), because the numbers are provisional. Poses and effects are borrowed until the art lane draws their own. |

## How it works (file:line)
- `SampleProject/Scripts/Systems/SkillDefinition.gd`: the fields `control_hits`, `control_reach`, `control_launch`, `control_knockdown` and `control_poise_x`, parsed from `control` and added to `to_dict`.
- `SampleProject/Scripts/Combat/Systems/SkillTargeting.gd`:
  - `skill_targets` hands a control skill to the new `control_targets`;
  - `enemies_ahead(player, reach)` covers Sweeping Arc's low reach.
- `SampleProject/Scripts/Combat/Systems/SkillCombatExecutor.gd`: `apply_control` applies guard damage, launch and knockdown. POISE_HEAVY is read from `source.combat`, because a `PlayerCombat` class reference here makes a compile cycle.
- `SampleProject/Scripts/Managers/Gameplay/SkillManager.gd`:
  - `use_skill` calls `apply_control` after `apply_move_riders` (one line);
  - `cast_skill` checks for targets with `skill_targets` instead of `enemies_in_front`. This is the same for every skill that has no `control` block.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd`: `launch`, `can_be_thrown` and `knock_down`, placed next to `knockback`. Nothing was changed in `EnemyLogic`: the launch sets its existing `jump_speed`, and `stun_left` holds the enemy in the air.
- `SampleProject/Scripts/FX/ControlSkillFX.gd` + `Scenes/FX/Skills/ControlSkill.tscn` (markers Hand, Low, Palm and Feet; SlamRing):
  - the wind-up shows nothing;
  - on release: an upward arc (Rising Slash), a wide flat arc low in front (Sweeping Arc), the punch burst (Shield Bash, and a bigger one for Stone Palm), or the slams' impact ring (Ground Slam).
- `SampleProject/Resources/Data/skills.json`: the 5 rows (`cast`, `vfx`, `control`, `synergies`, `required_weapons: []`) and `_schema.entry.control`.
- `SampleProject/Resources/Data/sound_events.json`: `cast_<id>_windup` / `_release` for the 5 skills, reusing existing files.
- Poses: Rising Slash and Sweeping Arc use HeavyWindup → HeavyStrike. Ground Slam uses LeapSlamWindup → LeapSlamStrike. Shield Bash uses ShieldChargeWindup → ShieldChargeStrike. Stone Palm uses CastPalm.
- Synergies:
  - Rising Slash: weapon_training, keen_edge.
  - Ground Slam: heavy_hand, fortitude.
  - Shield Bash: heavy_hand, shield_block.
  - Sweeping Arc: perfect_balance, dervish_rhythm.
  - Stone Palm: sand_stance, rooted_resolve.

## Tests
- `verify_skills_control_a` (new, DesertRoad, real `default_enemy` bandits): **RESULT: ALL PASS**
  - [1] Rising Slash: hit for 160, the enemy flies up 82 px, is staggered 0.8 s and lands back on the floor; 6 SP paid.
  - [2] a large enemy is hurt but stays on the ground.
  - [3] Ground Slam: the enemies at −100 and +100 are hit and down for 1.2 s; the one at +320 is untouched; 9 SP paid. It starts with the only enemy behind the hero. With nobody around: NO_TARGET and no SP.
  - [4] Sweeping Arc: 3 enemies at 40/95/150 are hit and down for 1.0 s; −60 and +300 are untouched; 9 SP paid.
  - [5] Shield Bash: 12.5 guard damage (14 → 1.5) to the first enemy only; 5 SP paid. On a worn guard with a committed wind-up: the wind-up is broken, the enemy is staggered 0.6 s and the bar refills.
  - [6] Stone Palm: 15 guard damage, 92 HP damage; 9 SP paid.
  - [7] data.
- Also: TESTS_PLACEHOLDER

## For the art lane (ComfyUI, slice 7)
- **Rising Slash:** a hero rising-cut pose (wind-up low, strike high; it borrows HeavyWindup/HeavyStrike now), an upward crescent smear (it borrows the flipped hero `arc`), and a launch puff under the enemy.
- **Ground Slam:** a standing slam pose (weapon or fist down; it borrows the LeapSlam windup/strike frames), a ground crack and shockwave both ways to 140 px (it borrows the slams' `slam_ring`), and debris.
- **Sweeping Arc:** a low crouching sweep pose (it borrows HeavyWindup/HeavyStrike), and a long flat sand-coloured arc along the ground to 160 px (it borrows the stretched hero `arc`).
- **Shield Bash:** a shield-forward bash pose with the S19 sky shield on the arm (it borrows the ShieldCharge poses, with no shield shown), and a shield impact flash (it borrows `punch`).
- **Stone Palm:** an open-palm strike pose (CastPalm, which is the healing palm's, so it reads as a heal), a stone-grey palm burst, and a guard-crack effect on the target (it borrows the bigger `punch`).
- **Enemy states (every kind):** a **knocked-down** pose (lying, then getting up) and a **launched** pose (tumbling in the air). Both borrow the stagger pose now. Kinds without a stagger pose show only the stun tint.
- **Sounds:** a whoosh for the rising cut, a ground boom, a sweep, a shield thud and a palm hit. The current ones reuse files (knifeSlice, impactPunch_heavy, impactPlate).

## Not done / follow-ups
- Dune Quake (slice 3) still "knocks down" with `stun` 1.2. It could switch to `control.knockdown: 1.2` now (one row in skills.json). I left it alone so this branch does not edit slice 3's row.
- The execute on a broken guard (Soul Harvest) belongs to control-b / `cloud/combat-enemies`.
